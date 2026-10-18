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

// Task is one benchmark item: a natural-language build request plus the deterministic verdict.
// Task 是一条基准项：自然语言建图请求 + 确定性裁决。
type Task struct {
	ID     string `json:"id"`
	Tier   int    `json:"tier"`
	Name   string `json:"name"`
	Prompt string `json:"prompt"`
	Expect struct {
		Nodes   map[string]int `json:"nodes"`   // kind → count on the active version
		Trigger string         `json:"trigger"` // manual | cron | webhook
	} `json:"expect"`
	Run              string          `json:"run"` // model: the prompt asks the model to run once; webhook: harness posts
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
//   - Documents: a Library document whose name contains the substring must exist.
//   - MCPCalls: the MCP ledger must hold a call with this tool/status.
//
// TaskAssert 是结果裁决；每一项都是精确、机器可判的规则（见英文注释逐条）。
type TaskAssert struct {
	Calls     []CallAssert `json:"calls,omitempty"`
	Absent    []string     `json:"absent,omitempty"`
	Ordered   []string     `json:"ordered,omitempty"`
	Documents []DocAssert  `json:"documents,omitempty"`
	MCPCalls  []MCPAssert  `json:"mcpCalls,omitempty"`
}

type CallAssert struct {
	Path         string   `json:"path"`
	Method       string   `json:"method"`
	Count        int      `json:"count"`
	BodyContains []string `json:"bodyContains,omitempty"`
}

type DocAssert struct {
	NameContains string `json:"nameContains"`
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
	if len(tasks) != 60 {
		return nil, fmt.Errorf("tasks.json: want 60 tasks, got %d", len(tasks))
	}
	for tier := 1; tier <= 4; tier++ {
		if perTier[tier] != 15 {
			return nil, fmt.Errorf("tasks.json: tier %d has %d tasks, want 15", tier, perTier[tier])
		}
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
func TriggerKindOf(source string) string {
	switch strings.ToLower(source) {
	case "cron":
		return "cron"
	case "webhook":
		return "webhook"
	case "fsnotify":
		return "file"
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
func Judge(task Task, ledger []SinkCall, docNames []string, mcp []MCPLedgerRow) Verdict {
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
		if got != a.Count {
			v.Reasons = append(v.Reasons, fmt.Sprintf("%s %s: want %d call(s), got %d", a.Method, a.Path, a.Count, got))
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
	for _, d := range task.Assert.Documents {
		found := false
		for _, n := range docNames {
			if strings.Contains(n, d.NameContains) {
				found = true
			}
		}
		if !found {
			v.Reasons = append(v.Reasons, fmt.Sprintf("no Library document containing %q", d.NameContains))
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
