// Package golden holds the real-model LLM journeys (make evals): the same black-box harness,
// but the model is REAL (deepseek-v4-flash) — gated behind EVALS=1 so the suite never burns
// tokens by accident. These are 柱C of the acceptance program: prove the product's tool surface
// really drives a real model end to end. Assertions check OUTCOMES (entity created, function ran,
// memory recalled) not exact text — a real model is non-deterministic, so we judge "did it reach
// the goal state", never "did it say these words".
//
// Package golden 放真模型 LLM 旅程（make evals）：同一套黑盒 harness，但模型是真的
// （deepseek-v4-flash）——EVALS=1 门控，绝不意外烧钱。验收计划柱C：证明产品工具面真能端到端驱动真
// 模型。断言只看**结果状态**（实体建了、function 跑了、memory 记住了），不看逐字文本——真模型非
// 确定，只判"是否到达目标态"。
package golden

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

func TestMain(m *testing.M) {
	if os.Getenv("EVALS") == "" {
		os.Exit(0) // gated: only runs via make evals. 门控：仅 make evals 触发。
	}
	// Same scratch containment as scenarios: this package boots the same harness, so it leaks the
	// same server binary + data dirs without it. 与 scenarios 同款 scratch 收容：本包拉的是同一套
	// harness，没有它就会漏同样的 server 二进制与数据目录。
	harness.RunTests(m)
}

// realModel resolves the real-model wire config from the environment. EVALS_* win; otherwise
// fall back to DeepSeek (key from DEEPSEEK_API_KEY, the repo-root .env name). EVALS_PROVIDER
// selects the wire dialect; it defaults to deepseek so existing golden commands do not change.
//
// realModel 从环境解析真模型线缆配置。EVALS_* 优先；否则落 DeepSeek（key 取 DEEPSEEK_API_KEY，
// 仓库根 .env 的名字）。EVALS_PROVIDER 选 wire dialect，默认 deepseek 保持既有命令行为。key 空 → skip。
func realModel(t *testing.T) (provider, baseURL, model, key string) {
	t.Helper()
	key = firstNonEmpty(os.Getenv("EVALS_KEY"), os.Getenv("DEEPSEEK_API_KEY"))
	if key == "" {
		t.Skip("no real-model key (set DEEPSEEK_API_KEY or EVALS_KEY); make evals loads repo-root .env")
	}
	provider = firstNonEmpty(os.Getenv("EVALS_PROVIDER"), "deepseek")
	baseURL = firstNonEmpty(os.Getenv("EVALS_BASE_URL"), "https://api.deepseek.com")
	model = firstNonEmpty(os.Getenv("EVALS_MODEL"), "deepseek-v4-flash")
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

// evalWS boots a server, registers the real model with its actual provider dialect, probes it, and sets
// it as the default for the requested scenarios. Returns the workspace-bound client.
//
// evalWS 拉起 server、把真模型按实际 provider 注册为 key、探活、设为所点 scenario 的默认，返回绑
// workspace 的 client。
func evalWS(t *testing.T, scenarios ...string) *harness.Client {
	t.Helper()
	provider, baseURL, model, key := realModel(t)
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "eval-ws", "language": "en"}).Field(t, "id")
	wc := c.WS(wsID)
	// 外部模型的静态目录只辅助能力渲染，绝不作为上下文预算权威；长对话金标会让它自然撞真实上游
	// 窗口，再验证透明恢复与运行时学习。C2 Qwen 金标必须经 qwen provider，不能借 OpenAI renderer。
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": provider, "displayName": provider, "key": key, "baseUrl": baseURL,
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	if len(scenarios) == 0 {
		scenarios = []string{"dialogue", "utility", "agent"}
	}
	for _, sc := range scenarios {
		wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/"+sc,
			map[string]any{"apiKeyId": keyID, "modelId": model}).OK(t, nil)
	}
	return wc
}

// evalMsg is one turn in GET /conversations/{id}/messages (minimal wire shape; golden is a
// separate package and shares no helpers with scenarios).
//
// evalMsg 是消息历史里一个回合（最小线缆形状；golden 独立包、不与 scenarios 共享 helper）。
type evalMsg struct {
	ID          string         `json:"id"`
	Role        string         `json:"role"`
	Status      string         `json:"status"`
	StopReason  string         `json:"stopReason"`
	ErrorCode   string         `json:"errorCode"`
	InputTokens int            `json:"inputTokens"`
	Attrs       map[string]any `json:"attrs"`
	Blocks      []struct {
		Type    string `json:"type"`
		Content string `json:"content"`
	} `json:"blocks"`
}

// longContextConfig is intentionally opt-in: this golden sends a genuinely
// large prompt to a billable provider. Its job is to prove the actual provider
// usage, not an application's byte estimate. The explicit byte and minimum
// observed-token inputs make the run reproducible across tokenizers/providers.
type longContextConfig struct {
	bytes          int
	minInputTokens int
}

func requireLongContext(t *testing.T) longContextConfig {
	t.Helper()
	if os.Getenv("EVALS_LONG_CONTEXT") != "1" {
		t.Skip("set EVALS_LONG_CONTEXT=1 to run the billable long-context golden")
	}
	return longContextConfig{
		// 2.4 MB of unique ASCII records calibrated to ~967K actual DeepSeek
		// prompt tokens on 2026-07-24. It leaves a small, honest margin for the
		// system prompt and exact sentinel reply while proving that the usable
		// 1M route is not silently compressed at a much smaller local estimate.
		// This remains a byte target; provider usage is the acceptance truth.
		bytes:          positiveEnvInt(t, "EVALS_LONG_CONTEXT_BYTES", 2_400_000),
		minInputTokens: positiveEnvInt(t, "EVALS_LONG_CONTEXT_MIN_INPUT_TOKENS", 950_000),
	}
}

func positiveEnvInt(t *testing.T, key string, fallback int) int {
	t.Helper()
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		t.Fatalf("%s must be a positive integer, got %q", key, raw)
	}
	return n
}

func longContextFixture(bytes int, sentinel string) string {
	var b strings.Builder
	b.Grow(bytes + len(sentinel) + 256)
	b.WriteString("This is a long-context admission probe. Treat each record as data; do not summarize it.\n")
	for i := 0; b.Len() < bytes; i++ {
		// Vary every record so provider-side repetition compression cannot turn a
		// nominal 1M test into a tiny prompt.
		fmt.Fprintf(&b, "record=%08x category=%08x payload=anselm-context-evidence-%08x\n", i, i*2654435761, i^0x5a5a5a5a)
	}
	fmt.Fprintf(&b, "\nAUTHORITATIVE_SENTINEL=%s\n", sentinel)
	return b.String()
}

func observedPromptTokens(m evalMsg) int {
	if m.Attrs != nil {
		if usage, ok := m.Attrs["contextUsage"].(map[string]any); ok {
			switch n := usage["lastPromptInputTokens"].(type) {
			case float64:
				return int(n)
			case int:
				return n
			}
		}
	}
	return m.InputTokens
}

// drainInteractions auto-resolves any human-in-the-loop gate so eval journeys never hang: a real
// model may self-report a tool as dangerous (→ approve_always, whitelisting it for the rest of the
// run) or call ask_user (→ accept with a generic go-ahead). Best-effort; a resolve that 404s
// (already handled) is fine.
//
// drainInteractions 自动放行任何人在环门，使金标旅程不挂：真模型可能自报工具危险（→approve_always、
// 本次运行白名单它）或调 ask_user（→accept + 通用放行答复）。best-effort；resolve 404（已处理）无妨。
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

// say sends a user message and waits for the assistant turn to reach a terminal state, returning
// the concatenated text of that turn. Real-model turns can take a while (multi-step tool loops),
// hence the generous timeout; human-loop gates are auto-resolved each poll so a danger/ask gate
// never stalls the journey.
//
// say 发一条用户消息并等 assistant 回合到终态，返回该回合文本拼接。真模型回合可能较久（多步工具
// 循环），故超时给得宽；每轮自动放行人在环门，使 danger/ask 门绝不卡住旅程。
func say(t *testing.T, wc *harness.Client, convID, content string, timeoutMS int) string {
	t.Helper()
	msgID := wc.POST("/api/v1/conversations/"+convID+"/messages",
		map[string]any{"content": content}).Field(t, "id") // 异步动作返新资源 id 统一 {id}(MD3)
	var text string
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
			for _, blk := range m.Blocks {
				if blk.Type == "text" {
					b.WriteString(blk.Content)
				}
			}
			text = b.String()
			return true
		}
		return false
	})
	return text
}

func newConv(t *testing.T, wc *harness.Client, title string) string {
	t.Helper()
	return wc.POST("/api/v1/conversations", map[string]any{"title": title}).Field(t, "id")
}

// ── J1 自举引导：空 workspace 的第一句对话 ─────────────────────────────────────
// 真模型在零实体、有完整工具面的 workspace 里对一个开放问题给出连贯、非报错的引导。
func TestGolden_J1_Bootstrap(t *testing.T) {
	wc := evalWS(t)
	conv := newConv(t, wc, "getting started")
	out := say(t, wc, conv, "I'm new here. In one short paragraph, what can you help me build?", 90000)
	if strings.TrimSpace(out) == "" {
		t.Fatal("bootstrap turn produced no text")
	}
}

// ── J2 旗舰：从零建 function 并调通 ───────────────────────────────────────────
// 真模型必须 create_function 再 run_function——结果状态：functions 列出 ≥1，且最终答复报出和 5。
func TestGolden_J2_BuildAndRunFunction(t *testing.T) {
	wc := evalWS(t)
	conv := newConv(t, wc, "build add")
	out := say(t, wc, conv,
		"Create a Python function named add that takes two integers a and b and returns a+b. "+
			"Then run it with a=2 and b=3 and tell me the result.", 180000)

	var fns []json.RawMessage
	wc.GET("/api/v1/functions").OK(t, &fns)
	if len(fns) == 0 {
		t.Fatalf("model did not create any function (create_function not driven); answer was:\n%s", out)
	}
	if !strings.Contains(out, "5") {
		t.Errorf("model created a function but final answer lacks the result 5 (run_function may not have driven):\n%s", out)
	}
}

// ── J5 AI 自愈：埋雷 function 让模型诊断修好 ─────────────────────────────────
// 预置一个会抛错的 function，请模型修；结果状态：active 版本号前进（>1，说明 edit_function 真改了）。
func TestGolden_J5_DebugFunction(t *testing.T) {
	wc := evalWS(t)
	// 预置 bug：引用未定义变量。create 现返裸实体(MD1):data 顶层即 id。
	fnID := wc.POST("/api/v1/functions", map[string]any{
		"name": "buggy_double", "description": "double a number (has a bug)",
		"code": "def buggy_double(n: int) -> dict:\n    return {\"out\": n * undefined_factor}\n",
	}).Field(t, "id")

	conv := newConv(t, wc, "fix bug")
	say(t, wc, conv,
		"The function buggy_double is broken — it references an undefined variable. "+
			"Fix it so it returns n doubled (n*2), then verify it works on n=4.", 180000)

	// active 版本前进 = edit_function 真落了新版本。
	var versions []struct {
		Version int `json:"version"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/versions").OK(t, &versions)
	maxV := 0
	for _, v := range versions {
		if v.Version > maxV {
			maxV = v.Version
		}
	}
	if maxV < 2 {
		t.Fatalf("model did not produce a new version (edit_function not driven); max version=%d", maxV)
	}
}

// ── J3 常驻服务：从零建 handler 并调其方法 ───────────────────────────────────
// 真模型 create_handler（有状态服务）再 call_handler；结果状态：handlers 列出 ≥1。
func TestGolden_J3_BuildAndCallHandler(t *testing.T) {
	wc := evalWS(t)
	conv := newConv(t, wc, "build handler")
	say(t, wc, conv,
		"Create a handler named Greeter with a method 'hello' that takes a name string and returns "+
			"a dict {\"msg\": \"Hello, <name>!\"}. Then call hello with name='Ada' and tell me what it returned.",
		240000)

	var handlers []json.RawMessage
	wc.GET("/api/v1/handlers").OK(t, &handlers)
	if len(handlers) == 0 {
		t.Fatal("model did not create any handler (create_handler not driven)")
	}
}

// ── J7 积木检索：搜到一个已构建的 function ───────────────────────────────────
// 预置一个 function，请真模型用搜索找到它并报出确切名字（驱动 search_tools/search_blocks）。
func TestGolden_J7_SearchBuildingBlocks(t *testing.T) {
	wc := evalWS(t)
	wc.POST("/api/v1/functions", map[string]any{
		"name": "celsius_to_fahrenheit", "description": "convert a Celsius temperature to Fahrenheit",
		"code": "def celsius_to_fahrenheit(c: float) -> dict:\n    return {\"f\": c * 9 / 5 + 32}\n",
	}).OK(t, nil)

	conv := newConv(t, wc, "find block")
	out := say(t, wc, conv,
		"I built a function earlier that converts Celsius to Fahrenheit but I forget its exact name. "+
			"Search my workspace and tell me its exact name.", 180000)
	if !strings.Contains(out, "celsius_to_fahrenheit") {
		t.Errorf("model did not find the built function by search:\n%s", out)
	}
}

// ── J9 记忆：写入一条 memory，新对话里召回 ───────────────────────────────────
// 真模型在对话 A 写 memory（write_memory），对话 B（全新、靠 system prompt 注入的 memory）召回。
func TestGolden_J9_MemoryWriteRecall(t *testing.T) {
	wc := evalWS(t)
	a := newConv(t, wc, "tell")
	say(t, wc, a, "Please remember this for later: my project's deploy target is codename Polaris.", 120000)

	// memory 真落库（write_memory 驱动）。
	var mems []json.RawMessage
	wc.GET("/api/v1/memories").OK(t, &mems)
	if len(mems) == 0 {
		t.Fatal("model did not persist any memory (write_memory not driven)")
	}

	// 新对话召回（memory 经 system prompt 注入）。
	b := newConv(t, wc, "recall")
	out := say(t, wc, b, "What is my project's deploy target codename?", 120000)
	if !strings.Contains(strings.ToLower(out), "polaris") {
		t.Errorf("model did not recall the memory in a fresh conversation:\n%s", out)
	}
}

// ── J12 降级态：utility 未配，主对话链路（dialogue）仍完成 ───────────────────
// 只配 dialogue（不配 utility）——起标题/压缩静默缺席，但主问答照常完成、不报错。
func TestGolden_J12_DegradedMainPath(t *testing.T) {
	wc := evalWS(t, "dialogue") // 仅 dialogue
	conv := newConv(t, wc, "degraded")
	out := say(t, wc, conv, "In one sentence, what is durable workflow execution?", 90000)
	if strings.TrimSpace(out) == "" {
		t.Fatal("degraded main path produced no answer")
	}
}
