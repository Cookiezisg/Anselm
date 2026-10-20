// Package evalbench is the measured lane behind the product claims about Anselm: "a sentence
// builds a workflow that runs" (Pass@1 / Pass@3), "a failed run gets repaired into a new version"
// (repair success / regression / false-repair), and the two deterministic lanes (crash recovery,
// danger floors) that the existing scenarios already prove but never counted. It reuses the golden
// harness (real model, EVALS=1 gated) and judges OUTCOMES through a loopback HTTP sink: what the
// workflow actually sent to the outside world is the only truth, never the model's prose.
//
// Package evalbench 是产品结论背后的测量车道："一句话建出能跑的 workflow"（Pass@1 / Pass@3）、
// "失败 run 被修成新版本"（修复成功 / 回归 / 误修复），以及两条确定性车道（崩溃恢复、危险下限）——
// 现有 scenarios 早已证明但从未计数。它复用 golden harness（真模型、EVALS=1 门控），并通过回环 HTTP
// sink 裁决**结果**：workflow 真正发给外界的东西才是唯一事实，模型的叙述从不算数。
package evalbench

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

//go:embed tasks.json
var tasksJSON []byte

//go:embed faults.json
var faultsJSON []byte

// SinkPlaceholder is substituted in every prompt with the live sink base URL before the turn is
// sent; the model never sees a placeholder. SinkPlaceholder 在发送前替换为 sink 真实基址。
const SinkPlaceholder = "{{SINK}}"

// WatchPlaceholder is replaced with a per-run empty temp directory before the prompt is sent, so an
// fsnotify task can name a real watchable path that only this run owns. The harness then creates a
// file inside it to make the trigger fire — the model never runs the workflow itself.
//
// WatchPlaceholder 在发出提示词前被替换为该次运行独占的空临时目录，使 fsnotify 任务能给出一个真实可监听
// 的路径。随后由 harness 在其中建文件令触发器 fire——模型自己不跑这个工作流。
const WatchPlaceholder = "{{WATCHDIR}}"

// Task is one benchmark item: a natural-language build request plus the deterministic verdict.
// Task 是一条基准项：自然语言建图请求 + 确定性裁决。
type Task struct {
	ID     string `json:"id"`
	Tier   int    `json:"tier"`
	Name   string `json:"name"`
	Prompt string `json:"prompt"`
	Expect struct {
		Nodes   map[string]int `json:"nodes"`   // kind → count on the active version
		Trigger string         `json:"trigger"` // manual | cron | webhook | fsnotify | sensor
	} `json:"expect"`
	// Run selects who starts the run: model (the prompt asks the model to call trigger_workflow),
	// webhook (the harness posts to the mounted inbound URL), fsnotify (the harness creates a file
	// under WatchPlaceholder's directory), sensor (nobody — the trigger's own probe must fire it).
	// The last two are the autonomous kinds: they pass only if the trigger listener really runs,
	// which in turn requires the model to have ACTIVATED the workflow.
	//
	// Run 选择谁起 run：model（提示词要求模型调 trigger_workflow）、webhook（harness 投递入站 URL）、
	// fsnotify（harness 在 WatchPlaceholder 目录内建文件）、sensor（无人——须由触发器自己的探测 fire）。
	// 后两种是自主型：只有 listener 真的在跑才可能通过，而那又要求模型**激活**了工作流。
	Run              string          `json:"run"`
	WebhookPayload   map[string]any  `json:"webhookPayload,omitempty"`
	ApprovalDecision string          `json:"approvalDecision,omitempty"` // yes | no; harness decides every parked node
	Setup            *TaskSetup      `json:"setup,omitempty"`
	Assert           TaskAssert      `json:"assert"`
	raw              json.RawMessage // kept for diagnostics dumps
}

// TaskSetup is harness-side preparation the prompt presumes. TaskSetup 是提示词预设的 harness 侧准备。
type TaskSetup struct {
	MCP bool `json:"mcp"` // install the local evalecho MCP server before the turn
}

// TaskAssert is the outcome verdict. Every field is checked with exact, machine-decidable rules:
//   - Calls: each (path, method) must have been received exactly Count times and every body must
//     contain all BodyContains substrings.
//   - Absent: these paths must never have been called (a control branch that must not fire, an
//     approval that said no).
//   - Ordered: "path#substr" entries; the bodies received on path, in arrival order, must contain
//     the substrings in this order.
//
// There is deliberately NO document assertion. Nothing inside a workflow can create a Library
// document: an agent's tool universe is exactly its mounts, and the sys: mount registry holds only
// the generate/edit media tools. An assertion no workflow can satisfy only invites unsatisfiable
// tasks, and the one that existed was satisfiable instead by the CHAT assistant filing the document
// by hand — a workspace-wide name check, not an execution verdict.
//
// **刻意没有**文档断言。工作流内部无法创建 Library 文档：agent 的工具宇宙恰是其挂载，而 sys: 挂载表只有
// 生成/编辑类媒体工具。没有工作流能满足的断言只会招来无解任务；而曾存在的那条反而可由**主对话助手**手工
// 建档满足——那是全 workspace 的名字检查，不是执行裁决。
//   - MCPCalls: the MCP ledger must hold a call with this tool/status.
//
// TaskAssert 是结果裁决；每一项都是精确、机器可判的规则（见英文注释逐条）。
type TaskAssert struct {
	Calls    []CallAssert `json:"calls,omitempty"`
	Absent   []string     `json:"absent,omitempty"`
	Ordered  []string     `json:"ordered,omitempty"`
	MCPCalls []MCPAssert  `json:"mcpCalls,omitempty"`
}

type CallAssert struct {
	Path   string `json:"path"`
	Method string `json:"method"`
	Count  int    `json:"count"`
	// AtLeast relaxes Count to a floor. An autonomous trigger cannot be asserted with an exact
	// count: a sensor keeps probing on its cadence while its condition holds, and one file write can
	// surface as create+modify, so either may legitimately fire more than once inside the window.
	// Exactness still applies everywhere it is meaningful — AtLeast is only set on those tasks.
	//
	// AtLeast 把 Count 放宽为下限。自主型触发器无法用精确次数断言：sensor 在条件成立期间按节拍持续探测，
	// 而一次写文件可能呈现为 create+modify，两者都可能在窗口内合法地多次 fire。精确性在一切有意义处仍然
	// 保留——AtLeast 只设在这类任务上。
	AtLeast      bool     `json:"atLeast,omitempty"`
	BodyContains []string `json:"bodyContains,omitempty"`
}

type MCPAssert struct {
	Tool   string `json:"tool"`
	Status string `json:"status"`
}

// Fault is one entry of the repair catalog. Fault 是修复目录的一条。
type Fault struct {
	ID   string `json:"id"`
	Kind string `json:"kind"` // sink | harness
	Sink *struct {
		Status        int    `json:"status,omitempty"`
		Body          string `json:"body,omitempty"`
		StallMS       int    `json:"stallMs,omitempty"`
		RequireHeader string `json:"requireHeader,omitempty"` // "Name: value"; once the request carries it the fault clears
	} `json:"sink,omitempty"`
	ExpectRepair string `json:"expectRepair"`
}

// LoadTasks decodes the embedded task set and validates the invariants the scorer relies on
// (60 tasks, 15 per tier, unique IDs). LoadTasks 解码内嵌题集并校验计分器依赖的不变量。
func LoadTasks() ([]Task, error) {
	var file struct {
		Tasks []json.RawMessage `json:"tasks"`
	}
	if err := json.Unmarshal(tasksJSON, &file); err != nil {
		return nil, fmt.Errorf("tasks.json: %w", err)
	}
	tasks := make([]Task, 0, len(file.Tasks))
	seen := map[string]bool{}
	perTier := map[int]int{}
	for _, raw := range file.Tasks {
		var t Task
		if err := json.Unmarshal(raw, &t); err != nil {
			return nil, fmt.Errorf("tasks.json: %w", err)
		}
		t.raw = raw
		if seen[t.ID] {
			return nil, fmt.Errorf("tasks.json: duplicate id %s", t.ID)
		}
		seen[t.ID] = true
		perTier[t.Tier]++
		if !strings.Contains(t.Prompt, SinkPlaceholder) {
			return nil, fmt.Errorf("tasks.json: %s has no %s in its prompt", t.ID, SinkPlaceholder)
		}
		tasks = append(tasks, t)
	}
	// The set grows by whole product surfaces, so a fixed total and a fixed per-tier count would
	// have to be edited on every batch — a check that moves with the data checks nothing. What the
	// scorer actually relies on is: unique IDs (above), every tier populated (it reports per-tier
	// rates), and a floor that catches a truncated or half-written file.
	//
	// 题集按整块产品面增长，故写死总数与每档条数只会每批都要改——跟着数据走的校验什么也没校验。计分器
	// 真正依赖的是：ID 唯一（上方）、每档非空（它按档报率）、以及一个能抓住文件被截断/写坏的下限。
	for tier := 1; tier <= 4; tier++ {
		if perTier[tier] == 0 {
			return nil, fmt.Errorf("tasks.json: tier %d is empty", tier)
		}
	}
	if len(tasks) < 60 {
		return nil, fmt.Errorf("tasks.json: want at least the original 60 tasks, got %d", len(tasks))
	}
	return tasks, nil
}

// LoadFaults decodes the embedded fault catalog. LoadFaults 解码内嵌故障目录。
func LoadFaults() ([]Fault, error) {
	var file struct {
		Faults []Fault `json:"faults"`
	}
	if err := json.Unmarshal(faultsJSON, &file); err != nil {
		return nil, fmt.Errorf("faults.json: %w", err)
	}
	if len(file.Faults) != 5 {
		return nil, fmt.Errorf("faults.json: want 5 faults, got %d", len(file.Faults))
	}
	return file.Faults, nil
}

// GraphNode is the slice of a workflow active version the structure check reads.
// GraphNode 是结构检查读取的 active version 节点切片。
type GraphNode struct {
	ID   string `json:"id"`
	Kind string `json:"kind"`
	Ref  string `json:"ref"`
}

// StructureScore is the multiset Jaccard between expected and actual node kinds: |min|/|max| over
// per-kind counts. 1.0 means the kinds and their counts match exactly; it is reported, never gated,
// because a passing run with a different shape is still a pass — the number only explains failures.
//
// StructureScore 是期望与实际节点类型多重集的 Jaccard（逐类 min 之和 / max 之和）。只报告不门控：
// 形状不同但跑通的 run 仍算通过，这个数只用来解释失败。
func StructureScore(expected map[string]int, nodes []GraphNode) float64 {
	actual := map[string]int{}
	for _, n := range nodes {
		actual[n.Kind]++
	}
	kinds := map[string]bool{}
	for k := range expected {
		kinds[k] = true
	}
	for k := range actual {
		kinds[k] = true
	}
	minSum, maxSum := 0, 0
	for k := range kinds {
		e, a := expected[k], actual[k]
		if e < a {
			minSum += e
			maxSum += a
		} else {
			minSum += a
			maxSum += e
		}
	}
	if maxSum == 0 {
		return 0
	}
	return float64(minSum) / float64(maxSum)
}

// TriggerKindOf maps a trigger entity's kind (cron | webhook | fsnotify | sensor) to the catalog's vocabulary.
// TriggerKindOf 把 trigger 实体的 source 映射到目录词汇。
// Every known kind maps to ITS OWN name — the benchmark speaks the product's vocabulary, never a
// private one. fsnotify used to map to "file", a word that exists nowhere in the product, which made
// every fsnotify task report triggerOk=false while the task itself passed (the run could only have
// happened because the watcher fired). The switch survives for its default: an unreadable or absent
// trigger reads as "manual", which TriggerMatches treats as "any trigger will do".
//
// 每种已知 kind 映射到**自己的名字**——基准说产品的词汇，绝不自造。fsnotify 曾被映射成 "file"，一个
// 产品里根本不存在的词，于是每条 fsnotify 任务都报 triggerOk=false 而任务本身却通过（那次 run 只可能
// 是 watcher 真的 fire 才发生）。switch 保留是为了 default：读不到或没有 trigger 读作 "manual"，
// 由 TriggerMatches 当作「有任意 trigger 即可」。
func TriggerKindOf(source string) string {
	switch strings.ToLower(source) {
	case "cron":
		return "cron"
	case "webhook":
		return "webhook"
	case "fsnotify":
		return "fsnotify"
	case "sensor":
		return "sensor"
	default:
		return "manual"
	}
}

// TriggerMatches reports whether an observed trigger kind satisfies the catalog's expectation. The
// trigger domain has no manual kind (running by hand is the workflow's own ability), yet a graph
// needs one trigger node, so "manual" is met by any trigger the graph carries.
//
// TriggerMatches 判断观测到的 trigger 种类是否满足目录期望。trigger 域没有 manual 种类（手动跑是
// workflow 自身能力），但图必须有一个 trigger 节点，所以 "manual" 由图上任意 trigger 满足。
func TriggerMatches(expected, observed string) bool {
	if expected == "manual" {
		return observed != ""
	}
	return expected == observed
}

// Verdict is the outcome of checking one task's assertions against observed state.
// Verdict 是把一条任务断言对照观测状态后的裁决。
type Verdict struct {
	Pass    bool     `json:"pass"`
	Reasons []string `json:"reasons,omitempty"`
}

// Judge checks the sink ledger, Library names and MCP ledger against the task's assertions. It is
// pure so the scorer's unit tests can exercise every rule without a server.
//
// Judge 对照任务断言检查 sink 台账、Library 名称和 MCP 台账。纯函数，便于无 server 单测每条规则。
func Judge(task Task, ledger []SinkCall, mcp []MCPLedgerRow) Verdict {
	var v Verdict
	// Calls/Ordered judge deliveries, so requests the armed fault answered are left out; Absent judges
	// any attempt, faulted or not. Calls/Ordered 裁决送达，被故障应答的请求不计；Absent 裁决任何尝试。
	byPath := map[string][]SinkCall{}
	attempts := map[string]int{}
	for _, c := range ledger {
		attempts[c.Path]++
		if !c.Faulted {
			byPath[c.Path] = append(byPath[c.Path], c)
		}
	}
	for _, a := range task.Assert.Calls {
		got := 0
		for _, c := range byPath[a.Path] {
			if a.Method != "" && !strings.EqualFold(c.Method, a.Method) {
				continue
			}
			got++
			for _, sub := range a.BodyContains {
				if !strings.Contains(c.Body, sub) {
					v.Reasons = append(v.Reasons, fmt.Sprintf("%s %s body lacks %q: %s", a.Method, a.Path, sub, truncate(c.Body, 200)))
				}
			}
		}
		if (a.AtLeast && got < a.Count) || (!a.AtLeast && got != a.Count) {
			want := "want %d call(s), got %d"
			if a.AtLeast {
				want = "want at least %d call(s), got %d"
			}
			v.Reasons = append(v.Reasons, fmt.Sprintf("%s %s: "+want, a.Method, a.Path, a.Count, got))
		}
	}
	for _, p := range task.Assert.Absent {
		if n := attempts[p]; n > 0 {
			v.Reasons = append(v.Reasons, fmt.Sprintf("%s must not be called, got %d", p, n))
		}
	}
	if len(task.Assert.Ordered) > 0 {
		path, _, _ := strings.Cut(task.Assert.Ordered[0], "#")
		calls := byPath[path]
		i := 0
		for _, c := range calls {
			if i < len(task.Assert.Ordered) {
				_, sub, _ := strings.Cut(task.Assert.Ordered[i], "#")
				if strings.Contains(c.Body, sub) {
					i++
				}
			}
		}
		if i != len(task.Assert.Ordered) {
			v.Reasons = append(v.Reasons, fmt.Sprintf("%s: expected order %v, matched %d of %d", path, task.Assert.Ordered, i, len(task.Assert.Ordered)))
		}
	}
	for _, m := range task.Assert.MCPCalls {
		found := false
		for _, r := range mcp {
			if r.Tool == m.Tool && (m.Status == "" || r.Status == m.Status) {
				found = true
			}
		}
		if !found {
			v.Reasons = append(v.Reasons, fmt.Sprintf("no MCP call %s/%s in ledger", m.Tool, m.Status))
		}
	}
	v.Pass = len(v.Reasons) == 0
	sort.Strings(v.Reasons)
	return v
}

// MCPLedgerRow mirrors GET /mcp-servers/{name}/calls rows. MCPLedgerRow 镜像 MCP 调用台账行。
type MCPLedgerRow struct {
	Tool   string `json:"tool"`
	Status string `json:"status"`
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
