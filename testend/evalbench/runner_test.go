package evalbench

// runner_test.go holds the real-model plumbing shared by the build and repair lanes. It mirrors
// golden's evalWS/say helpers on purpose (golden shares no helpers across packages) and is gated
// by EVALS=1 exactly like golden, so `go test ./...` never spends a token.
//
// runner_test.go 放建图与修复两条车道共用的真模型管线。它有意镜像 golden 的 evalWS/say（golden 不跨包
// 共享 helper），并与 golden 一样以 EVALS=1 门控，`go test ./...` 永不花 token。

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

//go:embed echo_mcp.py
var echoMCP string

func TestMain(m *testing.M) {
	if os.Getenv("EVALS") == "" {
		// Offline: only the pure scorer tests run, with no server boot. 离线：只跑纯计分单测，不拉 server。
		os.Exit(m.Run())
	}
	harness.RunTests(m)
}

// requireEvals keeps the two real-model lanes out of an ordinary `go test ./...`: without EVALS=1
// they skip, the pure scorer tests still run. requireEvals 让两条真模型车道不进入普通 go test：没有
// EVALS=1 时跳过，纯计分单测照常跑。
func requireEvals(t *testing.T) {
	t.Helper()
	if os.Getenv("EVALS") == "" {
		t.Skip("real-model lane: run via make -C backend evalbench (EVALS=1)")
	}
}

func realModel(t *testing.T) (provider, baseURL, model, key string) {
	t.Helper()
	provider = strings.TrimSpace(os.Getenv("EVALS_PROVIDER"))
	if provider == "" || provider == "anselm" {
		return "anselm", firstNonEmpty(os.Getenv("ANSELM_GATEWAY_URL"), "https://api.anselm.website/v1"),
			firstNonEmpty(os.Getenv("EVALS_MODEL"), "anselm-auto"), ""
	}
	key = firstNonEmpty(os.Getenv("EVALS_KEY"), os.Getenv(strings.ToUpper(provider)+"_API_KEY"))
	if key == "" {
		t.Skip("no real-model key (set EVALS_KEY or the provider API key); make evalbench loads repo-root .env")
	}
	baseURL = firstNonEmpty(os.Getenv("EVALS_BASE_URL"), map[string]string{
		"deepseek": "https://api.deepseek.com",
		"qwen":     "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
	}[provider])
	model = firstNonEmpty(os.Getenv("EVALS_MODEL"), map[string]string{"deepseek": "deepseek-v4-flash"}[provider])
	return provider, baseURL, model, key
}

func firstNonEmpty(vs ...string) string {
	for _, v := range vs {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func envInt(key string, def int) int {
	if v, err := strconv.Atoi(strings.TrimSpace(os.Getenv(key))); err == nil && v > 0 {
		return v
	}
	return def
}

// laneSlots caps how many (task, rep) cases a lane runs at once. The isolation unit is already the
// workspace (evalWS), and the lane deliberately shares ONE sidecar, so concurrency needs no new
// isolation — only a ceiling, because every concurrent case holds a Python sandbox and a model
// stream. Default 1 keeps the serial behaviour byte for byte, so a measured run stays comparable to
// an earlier serial one until a control run proves concurrency does not move the numbers. The
// returned acquire/release pair is a semaphore; nil means serial.
//
// laneSlots 限定一条车道同时跑多少个 (task, rep)。隔离单元本就是 workspace（evalWS），且车道**有意**
// 共享唯一 sidecar，故并发不需要新隔离、只需要上限——每个并发例都占一个 Python 沙箱和一条模型流。
// 默认 1 使串行行为逐字节不变，故在对照运行证明并发不挪动数字之前，测得的结果仍与早先的串行轮次可比。
// 返回的 acquire/release 是信号量；nil 表示串行。
func laneSlots() chan struct{} {
	n := envInt("EVALBENCH_PARALLEL", 1)
	if n <= 1 {
		return nil
	}
	return make(chan struct{}, n)
}

// parallelCase opts the subtest into Go's parallel scheduler and takes one lane slot, releasing it
// when the subtest ends. Call it first inside the subtest, before any workspace is created.
// NOTE: Go caps parallel subtests at -parallel (default GOMAXPROCS), so a slot count above that
// needs `-parallel N` on the command line to take effect.
//
// parallelCase 让子测试加入 Go 的并行调度并占用一个车道槽位，子测试结束时释放。必须在子测试内最先调用、
// 早于任何 workspace 创建。注意：Go 以 -parallel（默认 GOMAXPROCS）为并行子测试上限，槽位数超过它时
// 需在命令行加 `-parallel N` 才生效。
func parallelCase(t *testing.T, slots chan struct{}) {
	if slots == nil {
		return
	}
	t.Parallel()
	slots <- struct{}{}
	t.Cleanup(func() { <-slots })
}

// rowMu serializes the JSONL appends. Each row is one short line and O_APPEND would almost always
// be atomic anyway, but "almost" is not a property a results file may rest on.
//
// rowMu 串行化 JSONL 追加。每行很短、O_APPEND 几乎总是原子的，但结果文件不能建立在「几乎」上。
var rowMu sync.Mutex

// evalServer boots the one server a lane shares. Every server is a fresh managed install, and the
// gateway rate-limits install registration (429), so a server per case starves a long lane; the
// workspace, not the process, is the isolation unit. evalServer 拉起一条车道共享的唯一 server：每个
// server 都是一次新的受管 install，网关对 install 登记限流（429），每例一个 server 会饿死长车道；
// 隔离单元是 workspace 而不是进程。
func evalServer(t *testing.T) *harness.Server {
	t.Helper()
	provider, baseURL, _, _ := realModel(t)
	if provider == "anselm" {
		return harness.Start(t, "ANSELM_GATEWAY_URL="+baseURL)
	}
	return harness.Start(t)
}

// evalWS creates a fresh workspace on the lane's server, wired to the real model. One workspace
// per (task, rep) is the isolation unit: the model can never see another run's entities, so
// "reuse" is a real retrieval, never a leak. evalWS 在车道 server 上新建 workspace 接真模型；每个
// (task, rep) 独立 workspace 作为隔离单元：模型看不到别的 run 的实体，"复用"只能是真检索，不可能是泄漏。
func evalWS(t *testing.T, srv *harness.Server) (*harness.Client, string) {
	t.Helper()
	provider, baseURL, model, key := realModel(t)
	c := srv.Client(t)
	// Workspace names are unique per server; the subtest name (lane/task/rep or fault) is unique per lane.
	// workspace 名在 server 内唯一；子测试名（车道/任务/重复或故障）在车道内唯一。
	wsName := "evalbench " + strings.ReplaceAll(t.Name(), "/", " ")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": wsName, "language": "en"}).Field(t, "id")
	wc := c.WS(wsID)
	if provider == "anselm" {
		harness.Eventually(t, 30000, "the managed free-tier key lands", func() bool {
			var keys []struct {
				Provider string `json:"provider"`
			}
			wc.GET("/api/v1/api-keys").OK(t, &keys)
			for _, k := range keys {
				if k.Provider == "anselm" {
					return true
				}
			}
			return false
		})
		var ws struct {
			DefaultDialogue *struct {
				APIKeyID string `json:"apiKeyId"`
				ModelID  string `json:"modelId"`
			} `json:"defaultDialogue"`
		}
		wc.GET("/api/v1/workspaces/"+wsID).OK(t, &ws)
		if ws.DefaultDialogue == nil || ws.DefaultDialogue.APIKeyID == "" {
			t.Fatalf("managed key visible before the dialogue default was ready: %+v", ws)
		}
		return wc, model
	}
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": provider, "displayName": provider, "key": key, "baseUrl": baseURL,
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	for _, sc := range []string{"dialogue", "utility", "agent"} {
		wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/"+sc,
			map[string]any{"apiKeyId": keyID, "modelId": model}).OK(t, nil)
	}
	return wc, model
}

func installEchoMCP(t *testing.T, wc *harness.Client) {
	t.Helper()
	script := filepath.Join(t.TempDir(), "echo_mcp.py")
	if err := os.WriteFile(script, []byte(echoMCP), 0o644); err != nil {
		t.Fatalf("write mcp script: %v", err)
	}
	var st struct {
		Status string `json:"status"`
	}
	wc.PUT("/api/v1/mcp-servers/evalecho", map[string]any{
		"description": "evalbench echo server", "command": "python3", "args": []string{script},
	}).OK(t, &st)
	if st.Status != "ready" {
		t.Fatalf("evalecho must be ready, got %s", st.Status)
	}
}

type evalMsg struct {
	ID     string `json:"id"`
	Role   string `json:"role"`
	Status string `json:"status"`
	Blocks []struct {
		Type    string         `json:"type"`
		Content string         `json:"content"`
		Attrs   map[string]any `json:"attrs,omitempty"`
	} `json:"blocks"`
	// StopReason / ErrorCode carry the turn's own abort reason. A provider refusal
	// (LLM_QUOTA_EXHAUSTED, rate limit, upstream 5xx) ends the turn with zero tool calls, which is
	// indistinguishable from "the model answered without building" unless we read it — and scoring
	// it as a failure would silently report a dead run as product weakness.
	//
	// StopReason / ErrorCode 带着本回合自己的中止原因。供方拒绝（配额耗尽、限流、上游 5xx）会让回合
	// 零工具调用结束，不读这两个字段就与"模型没建图"无从区分——把它算作失败等于把一次死跑谎报成产品弱点。
	StopReason   string `json:"stopReason,omitempty"`
	ErrorCode    string `json:"errorCode,omitempty"`
	ErrorMessage string `json:"errorMessage,omitempty"`
}

// drainInteractions auto-resolves the BUILD conversation's human-in-the-loop gates (a self-reported
// danger or an ask_user). This is the chat the harness is "the user" of; workflow approval nodes
// are a different thing and are decided per task by decideParked. drainInteractions 自动放行**建图对话**
// 的人在环门；workflow 审批节点另由 decideParked 按任务裁决。
func drainInteractions(wc *harness.Client, convID string) {
	r, err := wc.Try("GET", "/api/v1/conversations/"+convID+"/interactions", nil)
	if err != nil || r.Status != 200 || len(r.Data) == 0 {
		return
	}
	var pend []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
	}
	if json.Unmarshal(r.Data, &pend) != nil {
		return
	}
	for _, p := range pend {
		action, answer := "approve_always", ""
		if p.Kind == "ask" {
			action, answer = "accept", "Yes, proceed with a sensible default."
		}
		_, _ = wc.Try("POST", "/api/v1/conversations/"+convID+"/interactions/"+p.ToolCallID,
			map[string]any{"action": action, "answer": answer})
	}
}

// say sends one user turn and returns (final text, number of tool blocks the turn produced).
// say 发送一轮用户消息，返回（终答文本，该轮产生的工具块数）。
func say(t *testing.T, wc *harness.Client, convID, content string, timeoutMS int) (string, int, []string, string, string) {
	t.Helper()
	msgID := wc.POST("/api/v1/conversations/"+convID+"/messages", map[string]any{"content": content}).Field(t, "id")
	needles := contaminationNeedles(t)
	var text string
	tools := 0
	var names []string
	hit := ""
	llmErr := ""
	harness.Eventually(t, timeoutMS, "assistant turn reaches terminal", func() bool {
		drainInteractions(wc, convID)
		var msgs []evalMsg
		wc.GET("/api/v1/conversations/"+convID+"/messages?limit=80").OK(t, &msgs)
		for _, m := range msgs {
			if m.ID != msgID {
				continue
			}
			if m.Status == "pending" || m.Status == "streaming" {
				return false
			}
			var b strings.Builder
			tools = 0
			names = names[:0]
			hit = ""
			llmErr = ""
			if m.StopReason == "error" || m.ErrorCode != "" {
				llmErr = m.ErrorCode
				if llmErr == "" {
					llmErr = "LLM_ERROR"
				}
				if m.ErrorMessage != "" {
					llmErr += ": " + m.ErrorMessage
				}
			}
			for _, blk := range m.Blocks {
				if blk.Type == "text" {
					b.WriteString(blk.Content)
					continue
				}
				if !strings.Contains(blk.Type, "tool") {
					continue
				}
				tools++
				// The tool name lives in the block's attrs (loop sets attrs["tool"]); recording the
				// call sequence is the only way a failed attempt can be attributed, since Anselm
				// tools execute in-process and never appear in the HTTP log.
				//
				// 工具名在块 attrs（loop 写 attrs["tool"]）；记下调用序列是失败 attempt 唯一可归因的途径——
				// Anselm 工具是进程内执行，不出现在 HTTP 日志里。
				if blk.Type == "tool_call" {
					if n, ok := blk.Attrs["tool"].(string); ok && n != "" {
						names = append(names, n)
					}
					if hit == "" {
						hit = looksContaminated(blk.Content, needles)
					}
				}
			}
			text = b.String()
			return true
		}
		return false
	})
	return text, tools, names, hit, llmErr
}

// ── workflow / run observation ────────────────────────────────────────────────

type wfRow struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// findWorkflow picks the task's workflow: exact name first, else the only one, else the newest.
// findWorkflow 选任务的 workflow：先精确名，其次唯一者，最后最新者。
func findWorkflow(wc *harness.Client, name string) (wfRow, bool) {
	r, err := wc.Try("GET", "/api/v1/workflows?limit=50", nil)
	if err != nil || r.Status != 200 {
		return wfRow{}, false
	}
	var wfs []wfRow
	if json.Unmarshal(r.Data, &wfs) != nil || len(wfs) == 0 {
		return wfRow{}, false
	}
	for _, w := range wfs {
		if strings.EqualFold(w.Name, name) {
			return w, true
		}
	}
	return wfs[0], true
}

type activeGraph struct {
	Nodes   []GraphNode
	Version int
}

func readGraph(t *testing.T, wc *harness.Client, wfID string) activeGraph {
	t.Helper()
	var detail struct {
		ActiveVersion struct {
			Version     int `json:"version"`
			GraphParsed *struct {
				Nodes []GraphNode `json:"nodes"`
			} `json:"graphParsed"`
		} `json:"activeVersion"`
	}
	r := wc.GET("/api/v1/workflows/" + wfID)
	if r.Status != 200 {
		return activeGraph{}
	}
	_ = json.Unmarshal(r.Data, &detail)
	g := activeGraph{Version: detail.ActiveVersion.Version}
	if detail.ActiveVersion.GraphParsed != nil {
		g.Nodes = detail.ActiveVersion.GraphParsed.Nodes
	}
	return g
}

// triggerKind returns the catalog kind of the graph's first trigger node, its id, and (for a
// webhook) the mounted sub-path from config.path. triggerKind 返回首个 trigger 节点的目录种类、id，
// 以及 webhook 的挂载子路径（config.path）。
func triggerKind(wc *harness.Client, g activeGraph) (kind, trgID, hookPath string) {
	for _, n := range g.Nodes {
		if n.Kind != "trigger" {
			continue
		}
		r, err := wc.Try("GET", "/api/v1/triggers/"+n.Ref, nil)
		if err != nil || r.Status != 200 {
			return "manual", n.Ref, ""
		}
		var trg struct {
			Kind   string         `json:"kind"`
			Config map[string]any `json:"config"`
		}
		_ = json.Unmarshal(r.Data, &trg)
		hookPath, _ = trg.Config["path"].(string)
		return TriggerKindOf(trg.Kind), n.Ref, hookPath
	}
	return "", "", ""
}

// fireWebhook posts the task payload to the trigger's inbound URL with a raw client (no workspace
// header, exactly like an external caller). The listener mounts /api/v1/webhooks/{id}/{config.path}.
// fireWebhook 用裸客户端（无 workspace 头，和外部调用方一样）向 trigger 入站 URL 投递任务 payload；
// listener 挂载在 /api/v1/webhooks/{id}/{config.path}。
func fireWebhook(t *testing.T, wc *harness.Client, trgID, hookPath string, payload map[string]any) {
	t.Helper()
	body, _ := json.Marshal(payload)
	url := wc.BaseURL() + "/api/v1/webhooks/" + trgID + "/" + strings.TrimPrefix(hookPath, "/")
	resp, err := http.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("webhook post: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != 202 {
		t.Logf("webhook post returned %d (listener may not be active)", resp.StatusCode)
	}
}

type runDetail struct {
	Flowrun struct {
		ID     string `json:"id"`
		Status string `json:"status"`
		Error  string `json:"error"`
		// StartedAt scopes the sink ledger to this run, so the model's own pre-wiring probes are
		// not judged. StartedAt 把 sink 台账切到本次 run，使模型接线前自己的试探不被裁决。
		StartedAt time.Time `json:"startedAt"`
	} `json:"flowrun"`
	Nodes []struct {
		NodeID string `json:"nodeId"`
		Status string `json:"status"`
	} `json:"nodes"`
}

// startRun starts a manual run the way "Run now" does. POST /flowruns answers with the run envelope
// ({flowrun, nodes}), not a bare id. startRun 以「Run now」方式起 run；响应是 run 信封而非裸 id。
func startRun(t *testing.T, wc *harness.Client, wfID string, payload map[string]any) string {
	t.Helper()
	var d runDetail
	wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": payload}).OK(t, &d)
	if d.Flowrun.ID == "" {
		t.Fatalf("POST /flowruns returned no flowrun id")
	}
	return d.Flowrun.ID
}

func latestRun(wc *harness.Client, wfID string) (string, bool) {
	r, err := wc.Try("GET", "/api/v1/flowruns?workflowId="+wfID+"&limit=20", nil)
	if err != nil || r.Status != 200 {
		return "", false
	}
	var runs []struct {
		ID string `json:"id"`
	}
	if json.Unmarshal(r.Data, &runs) != nil || len(runs) == 0 {
		return "", false
	}
	return runs[0].ID, true // newest-first
}

func readRun(wc *harness.Client, runID string) (runDetail, bool) {
	var d runDetail
	r, err := wc.Try("GET", "/api/v1/flowruns/"+runID, nil)
	if err != nil || r.Status != 200 {
		return d, false
	}
	return d, json.Unmarshal(r.Data, &d) == nil
}

// settleRun waits for the run to leave `running`, deciding every parked approval with the task's
// decision as soon as it parks (that IS the human; the harness just answers instantly). Returns
// the terminal detail. settleRun 等 run 离开 running，并在审批节点一挂起就按任务决定裁决（harness 即
// 人，只是立刻作答）。返回终态详情。
func settleRun(t *testing.T, wc *harness.Client, runID, decision string, timeoutMS int) runDetail {
	t.Helper()
	if decision == "" {
		decision = "yes"
	}
	var last runDetail
	decided := map[string]bool{}
	harness.Eventually(t, timeoutMS, "flowrun "+runID+" settles", func() bool {
		d, ok := readRun(wc, runID)
		if !ok {
			return false
		}
		last = d
		for _, n := range d.Nodes {
			if n.Status == "parked" && !decided[n.NodeID] {
				decided[n.NodeID] = true
				_, _ = wc.Try("POST", "/api/v1/flowruns/"+runID+"/approvals/"+n.NodeID+":decide",
					map[string]any{"decision": decision})
			}
		}
		return d.Flowrun.Status != "running" && d.Flowrun.Status != ""
	})
	return last
}

// contaminationNeedles are the substrings whose appearance in a tool call's arguments proves the run
// read the benchmark itself. The model holds Bash/Grep/Read and the prompt tells it it may read any
// absolute path on the machine, so the task definitions and the grading doc are reachable: a run that
// touched them cannot be counted, because its pass is unattributable.
//
// The repo root is derived from the test's own working directory (go test runs in the package dir) so
// the check keeps working on another checkout.
//
// contaminationNeedles 是一组子串：出现在工具调用参数里即证明该次运行读了基准自身。模型持有
// Bash/Grep/Read，且提示词告知它可读机器上任意绝对路径，故任务定义与评分文档对它可达；碰到它们的运行
// 不能计数，因为通过与否无从归因。仓库根由测试自身工作目录推出（go test 在包目录运行），换检出仍有效。
func contaminationNeedles(t *testing.T) []string {
	t.Helper()
	needles := []string{"tasks.json", "evalbench", "eval-benchmark"}
	if root, err := filepath.Abs("../.."); err == nil {
		needles = append(needles, root)
	}
	return needles
}

func looksContaminated(args string, needles []string) string {
	for _, n := range needles {
		if n != "" && strings.Contains(args, n) {
			return n
		}
	}
	return ""
}

// dumpConversation writes the whole build conversation (every block: tool_call args, tool_result
// bodies, reasoning) next to the results file when EVALBENCH_DUMP is set. firstTools gives the
// call sequence but not the arguments or the errors the tools returned, and those are what a
// failure diagnosis actually turns on.
//
// dumpConversation 在设置 EVALBENCH_DUMP 时把整个建图对话（每个块：tool_call 参数、tool_result 正文、
// reasoning）写到结果文件旁边。firstTools 只给调用序列，不给参数和工具返回的错误，而失败诊断恰恰靠后者。
func dumpConversation(t *testing.T, wc *harness.Client, convID, taskID string, rep, attempt int) {
	t.Helper()
	if os.Getenv("EVALBENCH_DUMP") == "" {
		return
	}
	r, err := wc.Try("GET", "/api/v1/conversations/"+convID+"/messages?limit=200", nil)
	if err != nil || r.Status != 200 {
		t.Logf("dump %s rep%d attempt%d: messages fetch failed (err=%v)", taskID, rep, attempt, err)
		return
	}
	dir := filepath.Join(filepath.Dir(resultsPath(t)), "dumps")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Logf("dump %s: mkdir: %v", taskID, err)
		return
	}
	path := filepath.Join(dir, fmt.Sprintf("%s-rep%d-attempt%d.json", taskID, rep, attempt))
	if err := os.WriteFile(path, r.Data, 0o644); err != nil {
		t.Logf("dump %s: write: %v", taskID, err)
		return
	}
	t.Logf("dump %s rep%d attempt%d -> %s", taskID, rep, attempt, path)
}

func mcpLedger(wc *harness.Client) []MCPLedgerRow {
	r, err := wc.Try("GET", "/api/v1/mcp-servers/evalecho/calls", nil)
	if err != nil || r.Status != 200 {
		return nil
	}
	var calls struct {
		Calls []MCPLedgerRow `json:"calls"`
	}
	_ = json.Unmarshal(r.Data, &calls)
	return calls.Calls
}

// maxFunctionVersion returns the highest version among the functions the graph references, which
// is how "a new version was published" is observed without trusting the model's words.
// maxFunctionVersion 返回图所引用函数的最高版本号——不信模型口述，直接观察"发了新版本"。
func maxFunctionVersion(wc *harness.Client, g activeGraph) int {
	maxV := 0
	for _, n := range g.Nodes {
		if n.Kind != "action" || !strings.HasPrefix(n.Ref, "fn_") {
			continue
		}
		r, err := wc.Try("GET", "/api/v1/functions/"+n.Ref+"/versions", nil)
		if err != nil || r.Status != 200 {
			continue
		}
		var versions []struct {
			Version int `json:"version"`
		}
		_ = json.Unmarshal(r.Data, &versions)
		for _, v := range versions {
			if v.Version > maxV {
				maxV = v.Version
			}
		}
	}
	return maxV
}

// ── results sink ──────────────────────────────────────────────────────────────

func resultsPath(t *testing.T) string {
	t.Helper()
	p := strings.TrimSpace(os.Getenv("EVALBENCH_OUT"))
	if p == "" {
		p = filepath.Join("out", "results.jsonl")
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatalf("results dir: %v", err)
	}
	return p
}

func appendRow(t *testing.T, row any) {
	t.Helper()
	rowMu.Lock()
	defer rowMu.Unlock()
	f, err := os.OpenFile(resultsPath(t), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		t.Fatalf("open results: %v", err)
	}
	defer f.Close()
	b, _ := json.Marshal(row)
	fmt.Fprintln(f, string(b))
}

// selectTasks applies EVALBENCH_TASKS: empty = all; "T2" = that tier; "T1-03,T4-07" = those ids.
// selectTasks 应用 EVALBENCH_TASKS：空=全部；"T2"=该档；"T1-03,T4-07"=指定 id。
func selectTasks(t *testing.T, tasks []Task) []Task {
	t.Helper()
	sel := strings.TrimSpace(os.Getenv("EVALBENCH_TASKS"))
	if sel == "" {
		return tasks
	}
	want := map[string]bool{}
	tier := 0
	for _, part := range strings.Split(sel, ",") {
		part = strings.TrimSpace(part)
		if len(part) == 2 && part[0] == 'T' {
			tier, _ = strconv.Atoi(part[1:])
			continue
		}
		want[part] = true
	}
	var out []Task
	for _, task := range tasks {
		if want[task.ID] || (tier > 0 && task.Tier == tier) {
			out = append(out, task)
		}
	}
	if len(out) == 0 {
		t.Fatalf("EVALBENCH_TASKS=%q matched no task", sel)
	}
	return out
}

func elapsedMS(start time.Time) int64 { return time.Since(start).Milliseconds() }
