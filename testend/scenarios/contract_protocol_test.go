// contract_protocol_test.go — Phase 2 · SSE 深协议 / cron dedup / webhook plain-secret / 真进程
// SSE 鉴权门 的 testend 黑盒（零 token，llmmock 驱动）。
//
// 断言 = docs/references/backend/events.md + domains/{messages,trigger}.md 说的线缆事实，不是
// 「代码碰巧做的」：三流各持独立 per-workspace 单调 seq + 256 深 replay 环（sseBufSize=256）——
// 灌爆环拿 410 SEQ_TOO_OLD 后 REST 全量重取再以新 seq 重订、后续 durable 不漏不重（E2 durable/
// ephemeral 分级）；同流多订阅者收同一 durable seq 序（Bus 锁内保序扇出）；三流物理隔离（messages/
// entities/notifications 各一 Bus，帧永不串流）；interaction 是 messages 流上的 ephemeral signal
// （seq=0、pending 带 kind=danger、resolve 后对称发 resolved:true）；cron dedupKey 截断到分钟
// （D3 idx_trf_dedup：同分钟重复材化折叠成一行，崩溃重启不复制）；webhook 明文 secret 门（signatureAlgo
// 空 → X-Webhook-Secret / ?token= 直比，坏/缺 401、正确 202+run）；ANSELM_AUTH_TOKEN 下三条 SSE 订阅
// 端点的 bearer 门（无 token 401 / 有 token 200，workspace 走 ?workspaceID=）。
//
// helper 一律 protoC_ 前缀，绝不碰既有 helper（platformC_startTokenServer / platformC_raw 直接复用）。
package scenarios

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// ── 共享 helper（protoC_ 前缀）─────────────────────────────────────────────────

// protoC_frame is the on-wire SSE Envelope shape (events.md): {seq, scope:{kind,id}, id,
// frame:{kind, node:{type,content}}}. Restated here — testend never imports backend.
//
// protoC_frame 是 SSE Envelope 线缆形状（events.md）。此处复述——testend 不 import backend。
type protoC_frame struct {
	Seq   int64 `json:"seq"`
	Scope struct {
		Kind string `json:"kind"`
		ID   string `json:"id"`
	} `json:"scope"`
	ID    string `json:"id"`
	Frame struct {
		Kind string `json:"kind"` // open | delta | close | signal
		Node *struct {
			Type    string          `json:"type"`
			Content json.RawMessage `json:"content"`
		} `json:"node"`
		Result *struct {
			Type string `json:"type"`
		} `json:"result"`
	} `json:"frame"`
}

// protoC_parseFrame decodes one collected SSE data payload into the wire envelope.
//
// protoC_parseFrame 把一帧收集到的 SSE data 解成线缆信封。
func protoC_parseFrame(data json.RawMessage) protoC_frame {
	var f protoC_frame
	_ = json.Unmarshal(data, &f)
	return f
}

// protoC_durableSeqs returns, in arrival order, the seq of every durable frame (seq>0) a
// subscriber received. For a single continuously-connected subscriber arrival order == seq
// order, so a gap/dup is directly visible.
//
// protoC_durableSeqs 按到达序返回订阅者收到的每个 durable 帧（seq>0）的 seq。对一个持续连接的
// 订阅者，到达序 == seq 序，故缺口/重复可直接暴露。
func protoC_durableSeqs(sse *harness.SSE) []int64 {
	var out []int64
	for _, ev := range sse.Snapshot() {
		if f := protoC_parseFrame(ev.Data); f.Seq > 0 {
			out = append(out, f.Seq)
		}
	}
	return out
}

// protoC_assertContiguous fails unless seqs strictly increase by exactly 1 (no gap, no dup) —
// the durable-delivery invariant a connected subscriber must see.
//
// protoC_assertContiguous 断言 seqs 严格 +1 递增（无缺口无重复）——连接订阅者必见的 durable 投递不变量。
func protoC_assertContiguous(t *testing.T, label string, seqs []int64) {
	t.Helper()
	if len(seqs) == 0 {
		t.Fatalf("%s: no durable seqs collected", label)
	}
	for i := 1; i < len(seqs); i++ {
		if seqs[i] != seqs[i-1]+1 {
			t.Fatalf("%s: durable seq gap/dup at %d→%d (want strictly +1 contiguous): %v", label, seqs[i-1], seqs[i], seqs)
		}
	}
}

// protoC_maxSeq returns the highest durable seq a subscriber has seen so far (0 if none).
//
// protoC_maxSeq 返回订阅者迄今见过的最高 durable seq（无则 0）。
func protoC_maxSeq(sse *harness.SSE) int64 {
	var mx int64
	for _, s := range protoC_durableSeqs(sse) {
		if s > mx {
			mx = s
		}
	}
	return mx
}

// protoC_floodCalls scripts n parallel (same execution_group) run_function calls at a
// non-existent function id — each fails fast (not-found, no sandbox), and EVERY call still
// emits a tool_call block (open+close) + tool_result block (open+close) = 4 durable frames.
// n≈80 → ~320 durable frames on the messages stream in one exchange, enough to evict the
// 256-deep replay ring without waiting on the sandbox.
//
// protoC_floodCalls 脚本化 n 个并行（同 execution_group）指向不存在 function id 的 run_function
// 调用——每个快速失败（not-found、无 sandbox），且每个仍发 tool_call 块（open+close）+ tool_result 块
// （open+close）= 4 durable 帧。n≈80 → 一次交换在 messages 流出 ~320 durable 帧，够把 256 深 replay
// 环挤爆而无需等 sandbox。
func protoC_floodCalls(n int) []harness.MockToolCall {
	calls := make([]harness.MockToolCall, n)
	for i := range calls {
		calls[i] = harness.MockToolCall{
			ID:   fmt.Sprintf("flood_%d", i),
			Name: "run_function",
			Args: map[string]any{
				"functionId":      "fn_deadbeefcafe0000",
				"args":            map[string]any{},
				"summary":         "flood probe",
				"danger":          "safe",
				"execution_group": 1,
			},
		}
	}
	return calls
}

// protoC_streamProbe issues ONE raw GET to a stream endpoint and returns (status, error-code)
// WITHOUT hanging on a 200 SSE (the body is an infinite stream — we read only the status, then
// the deferred cancel/close tears the connection down). Workspace rides ?workspaceID= (the SSE
// identity path — EventSource can't set headers); token rides Authorization when non-empty.
//
// protoC_streamProbe 发一次裸 GET 到某 stream 端点，返回 (status, error-code) 且不在 200 SSE 上挂死
// （body 是无限流——只读 status，defer 的 cancel/close 拆连接）。workspace 走 ?workspaceID=（SSE 身份
// 路径——EventSource 设不了 header）；token 非空时走 Authorization。
func protoC_streamProbe(t *testing.T, base, token, wsID, stream string, fromSeq int64) (int, string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	url := base + "/api/v1/" + stream + "/stream?workspaceID=" + wsID
	if fromSeq >= 0 {
		url += fmt.Sprintf("&fromSeq=%d", fromSeq)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("streamProbe: new request: %v", err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return 0, ""
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return http.StatusOK, "" // live SSE — do NOT read the infinite body.
	}
	var env struct {
		Error *struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&env)
	code := ""
	if env.Error != nil {
		code = env.Error.Code
	}
	return resp.StatusCode, code
}

// protoC_authedField does one bearer-authed JSON request against a token-guarded server and
// returns a top-level string field from the N1 data envelope (used to mint a workspace on the
// token server, where the header-only harness Client can't reach).
//
// protoC_authedField 对 token 门控的 server 发一次带 bearer 的 JSON 请求，返回 N1 data 顶层的一个
// string 字段（用于在 token server 上开 workspace——只带 header 的 harness Client 够不到那里）。
func protoC_authedField(t *testing.T, base, token, method, path string, body any, field string) string {
	t.Helper()
	var rdr *strings.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rdr = strings.NewReader(string(b))
	} else {
		rdr = strings.NewReader("")
	}
	req, err := http.NewRequest(method, base+path, rdr)
	if err != nil {
		t.Fatalf("authedField: new request: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("authedField: do: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		t.Fatalf("authedField %s %s: want 2xx, got %d", method, path, resp.StatusCode)
	}
	var env struct {
		Data map[string]json.RawMessage `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&env); err != nil {
		t.Fatalf("authedField: decode: %v", err)
	}
	var s string
	_ = json.Unmarshal(env.Data[field], &s)
	if s == "" {
		t.Fatalf("authedField %s %s: field %q empty in data", method, path, field)
	}
	return s
}

// ── C-sse-4：灌爆 replay 环 → 410 SEQ_TOO_OLD → REST 全量重取 → 以新 seq 重订 → 不漏不重 ──

// TestContractProtocol_ReplayRingEvictionAndRecovery:
// ① 一条持续订阅者 S1 收到的 durable seq 序严格 +1 连续（无缺口无重复，全程）。
// ② 灌爆 256 深 replay 环（~320 durable 帧）后，用被淘汰的旧 seq 重连 → 410 SEQ_TOO_OLD
//    （events.md：环外 fromSeq 转 410，让客户端 REST 重取后重连）。
// ③ 410 后 REST 全量重取（GET .../messages）拿回历史。
// ④ 以当前最高 seq「重订」→ 后续回合的 durable 帧从 newSeq+1 起严格 +1 连续（不漏不重、不重放旧帧）。
func TestContractProtocol_ReplayRingEvictionAndRecovery(t *testing.T) {
	wc, mock := chatSetup(t, false)
	wsID := wsOf(t, wc)
	s1 := wc.Subscribe(t, "messages")
	conv := convCreate(t, wc, "replay-ring")

	// 回合 A：一句短文本，给一个会被挤出环的低位 durable seq。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "FLOODSTART"})
	midA := sendMsg(t, wc, conv, "start")
	if turn := waitTurn(t, wc, conv, midA, 30000); turn.Status != "completed" {
		t.Fatalf("turn A must complete, got %s", turn.Status)
	}
	s1.WaitFor(t, 8000, "S1 caught turn A", "FLOODSTART")
	firstSeq := protoC_durableSeqs(s1)[0] // 首个 durable seq（=1）——之后会被淘汰。

	// 灌爆：一回合 80 个并行 run_function（失败快、不碰 sandbox）→ ~320 durable 帧。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: protoC_floodCalls(80)},
		harness.LLMTurn{Text: "FLOODEND"},
	)
	midB := sendMsg(t, wc, conv, "flood")
	// 只需回合达终态 + 帧已出（final 状态无关紧要——帧无论终态都已发）。
	waitTurn(t, wc, conv, midB, 45000)
	s1.WaitFor(t, 30000, "S1 caught the flood tail", "FLOODEND")

	// ② 用被淘汰的旧 seq 重连 → 410 SEQ_TOO_OLD。
	if st, code := protoC_streamProbe(t, wc.BaseURL(), "", wsID, "messages", firstSeq); st != 410 || code != "SEQ_TOO_OLD" {
		t.Fatalf("reconnect from evicted seq %d must 410 SEQ_TOO_OLD, got %d/%s", firstSeq, st, code)
	}

	// ③ REST 全量重取拿回历史（410 后的恢复第一步）。
	var msgs []chatMsg
	wc.GET("/api/v1/conversations/" + conv + "/messages?limit=50").OK(t, &msgs)
	if len(msgs) == 0 {
		t.Fatal("REST refetch after 410 must return conversation history")
	}

	// ④ 以当前最高 seq 重订 → 后续 durable 从 newSeq+1 起、不漏不重。
	newSeq := protoC_maxSeq(s1)
	r := wc.SubscribeFrom(t, "messages", newSeq)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "RECOVERTOKEN"})
	midC := sendMsg(t, wc, conv, "recover")
	if turn := waitTurn(t, wc, conv, midC, 30000); turn.Status != "completed" {
		t.Fatalf("recovery turn must complete, got %s", turn.Status)
	}
	r.WaitFor(t, 10000, "resubscribed stream delivers the recovery turn", "RECOVERTOKEN")

	rSeqs := protoC_durableSeqs(r)
	protoC_assertContiguous(t, "resubscribed R", rSeqs)
	if rSeqs[0] != newSeq+1 {
		t.Fatalf("resubscribe from %d must deliver next durable as %d (no gap, no replay of old), got %d", newSeq, newSeq+1, rSeqs[0])
	}

	// ① 全程 S1 的 durable 序无缺口无重复。
	protoC_assertContiguous(t, "continuous S1", protoC_durableSeqs(s1))
}

// ── C-sse-9：同 ws 同流 3 订阅者并发收同一 durable seq 序 ────────────────────────

// TestContractProtocol_ThreeSubscribersSameDurableOrder: 三个从起点就连着的订阅者收到**同一条**
// durable seq 序（Bus 锁内保序扇出——seq 顺序 == 投递顺序，对每个订阅者一致）。用尾随帧的时序竞态
// 免疫的最小公共前缀比对。
func TestContractProtocol_ThreeSubscribersSameDurableOrder(t *testing.T) {
	wc, mock := chatSetup(t, false)
	s1 := wc.Subscribe(t, "messages")
	s2 := wc.Subscribe(t, "messages")
	s3 := wc.Subscribe(t, "messages")

	mock.Enqueue(dlgModel, harness.LLMTurn{Reasoning: "reasoning nine", Text: "NINETOKEN"})
	conv := convCreate(t, wc, "fanout")
	mid := sendMsg(t, wc, conv, "speak to all")
	if turn := waitTurn(t, wc, conv, mid, 30000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s", turn.Status)
	}
	for i, s := range []*harness.SSE{s1, s2, s3} {
		s.WaitFor(t, 8000, fmt.Sprintf("subscriber %d got the turn", i+1), "NINETOKEN")
	}

	a, b, c := protoC_durableSeqs(s1), protoC_durableSeqs(s2), protoC_durableSeqs(s3)
	// 每个订阅者自身连续。
	protoC_assertContiguous(t, "s1", a)
	protoC_assertContiguous(t, "s2", b)
	protoC_assertContiguous(t, "s3", c)
	// 最小公共前缀逐位相等（尾帧到达时序竞态不算 bug）。
	n := len(a)
	if len(b) < n {
		n = len(b)
	}
	if len(c) < n {
		n = len(c)
	}
	if n < 3 {
		t.Fatalf("expected ≥3 shared durable frames (reasoning+text), got common len %d", n)
	}
	for i := 0; i < n; i++ {
		if a[i] != b[i] || b[i] != c[i] {
			t.Fatalf("subscribers diverged at index %d: s1=%d s2=%d s3=%d (all must see the same durable seq order)", i, a[i], b[i], c[i])
		}
	}
}

// ── C-sse-11：三流物理隔离（messages / entities / notifications 各一 Bus，帧永不串流）──

// TestContractProtocol_ThreeStreamSeparation: 并订三流，跑一次 chat（出 messages 帧）+ 一次
// function create（env 物化出 entities build 帧 + 一条 function.created notification）。断言每类帧
// 只现于所属流：messages 只见 conversation 帧、绝无 build/function-scope；entities 只见 function-scope
// build、绝无 chat 文本/conversation-scope；notifications 见 function.created。
func TestContractProtocol_ThreeStreamSeparation(t *testing.T) {
	wc, mock := chatSetup(t, false)
	sMsg := wc.Subscribe(t, "messages")
	sEnt := wc.Subscribe(t, "entities")
	sNot := wc.Subscribe(t, "notifications")

	// chat 面：一句独特文本，落 messages 流。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "MSGSEPTOKEN"})
	conv := convCreate(t, wc, "sep-chat")
	mid := sendMsg(t, wc, conv, "say the token")
	if turn := waitTurn(t, wc, conv, mid, 30000); turn.Status != "completed" {
		t.Fatalf("chat turn must complete, got %s", turn.Status)
	}
	sMsg.WaitFor(t, 8000, "messages stream carries the chat text", "MSGSEPTOKEN")

	// entities 面：function create 同步物化 env，其 build 终端开+关 → build 帧锚 function scope。
	// （env sink 每次 attempt 必写一行，故 build open+close 无论 env 成败都发——见 envfix.writerSink。）
	fnID := fnCreate(t, wc, "sep_fn", "def sep_fn() -> dict:\n    return {}\n")
	sEnt.WaitFor(t, 30000, "entities stream carries the function build node", `"type":"build"`, `"kind":"function"`)
	sNot.WaitFor(t, 30000, "notifications stream carries function.created", "function.created", fnID)

	// 隔离：messages 绝不见 entities build / function scope；entities 绝不见 chat 文本 / conversation scope。
	sMsg.Never(t, 1500, "messages must not carry entities build frames", `"type":"build"`)
	sMsg.Never(t, 1, "messages must not carry function-scoped frames", `"kind":"function"`)
	sEnt.Never(t, 1500, "entities must not carry the chat text", "MSGSEPTOKEN")
	sEnt.Never(t, 1, "entities must not carry conversation-scoped frames", `"kind":"conversation"`)
}

// ── C-sse-15：interaction 是 messages 流上的 ephemeral signal（pending / resolved 帧本体）──

// TestContractProtocol_InteractionEphemeralSignals: 自报 dangerous 的工具阻塞 → messages 流推一条
// **ephemeral**（seq=0）interaction signal（scope=conversation、node.type=interaction、载 kind=danger
// 的 humanloop.Request）；resolve(approve) 后对称推一条 resolved:true 的 ephemeral signal（清提示）。
// 锁的是 SSE 帧本体（rail REST 面已由 TestChat_RailAwaitingInput 锁）。
func TestContractProtocol_InteractionEphemeralSignals(t *testing.T) {
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "gate_fn", "def gate_fn() -> dict:\n    return {\"did\": \"it\"}\n")
	sMsg := wc.Subscribe(t, "messages")

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_function", Args: map[string]any{
			"functionId": fnID, "args": map[string]any{},
			"summary": "gated probe", "danger": "dangerous", "execution_group": 1,
		}}}},
		harness.LLMTurn{Text: "done after approve"},
	)
	conv := convCreate(t, wc, "interaction-sse")
	mid := sendMsg(t, wc, conv, "do the dangerous thing")

	// pending interaction 帧：ephemeral signal，node.type=interaction，kind=danger。
	pendEv := sMsg.WaitFor(t, 15000, "pending interaction signal", `"type":"interaction"`, `"kind":"danger"`)
	pend := protoC_parseFrame(pendEv.Data)
	if pend.Seq != 0 {
		t.Fatalf("pending interaction must be EPHEMERAL (seq 0), got seq=%d", pend.Seq)
	}
	if pend.Frame.Kind != "signal" {
		t.Fatalf("pending interaction must be a signal frame, got kind=%q", pend.Frame.Kind)
	}
	if pend.Scope.Kind != "conversation" || pend.Scope.ID != conv {
		t.Fatalf("pending interaction must be conversation-scoped to %s, got %s:%s", conv, pend.Scope.Kind, pend.Scope.ID)
	}
	if pend.Frame.Node == nil || pend.Frame.Node.Type != "interaction" {
		t.Fatalf("pending frame node.type must be interaction, got %+v", pend.Frame.Node)
	}
	if !strings.Contains(string(pendEv.Data), `"tool":"run_function"`) {
		t.Fatalf("pending interaction must carry the gated tool name: %s", pendEv.Data)
	}
	toolCallID := pend.ID // Event.ID == the tool_call block id == the interaction/resolve key.
	if toolCallID == "" {
		t.Fatalf("pending interaction frame must carry the tool_call id: %s", pendEv.Data)
	}

	// resolve(approve) → 对称 ephemeral resolved:true 信号。
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+toolCallID, map[string]any{"action": "approve"}).OK(t, nil)
	resEv := sMsg.WaitFor(t, 10000, "resolved interaction signal", `"type":"interaction"`, `"resolved":true`)
	res := protoC_parseFrame(resEv.Data)
	if res.Seq != 0 {
		t.Fatalf("resolved interaction must be EPHEMERAL (seq 0), got seq=%d", res.Seq)
	}
	if res.Frame.Kind != "signal" || res.Frame.Node == nil || res.Frame.Node.Type != "interaction" {
		t.Fatalf("resolved frame must be an interaction signal, got kind=%q node=%+v", res.Frame.Kind, res.Frame.Node)
	}
	if !strings.Contains(string(resEv.Data), toolCallID) {
		t.Fatalf("resolved signal must reference the same tool_call id %s: %s", toolCallID, resEv.Data)
	}

	if turn := waitTurn(t, wc, conv, mid, 20000); turn.Status != "completed" {
		t.Fatalf("approved turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
}

// ── C-cron-3：cron dedup 同分钟（D3 idx_trf_dedup）+ 崩溃重启不复制 ──────────────

// TestContractProtocol_CronDedupAcrossRestart: cron `* * * * *` 到点触发写一条 Firing（dedupKey
// 截断到分钟）；kill -9 + 同数据目录重启后，断言每个 dedupKey 恰对应一条 Firing——同分钟重复材化
// （或重启重注册）不产生第二行（D3：UNIQUE(dedup_key) 折叠）。分钟边界真等待，故超时放宽（对标
// TestTrigger_CronEveryFires）。
func TestContractProtocol_CronDedupAcrossRestart(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "cron-dedup"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	trgID := trgCreate(t, wc, "tick", "cron", map[string]any{"expression": "* * * * *"})
	wfID, _ := wfWithTrigger(t, wc, "cron_dedup_pipe", trgID)

	// 等首条 firing（下一个分钟边界，最多 ~75s）。
	harness.Eventually(t, 75000, "cron produced its first firing", func() bool {
		return len(protoC_firings(t, wc, trgID)) >= 1
	})
	waitRunCompleted(t, wc, wfID, 30000)
	protoC_assertOneFiringPerDedup(t, wc, trgID) // 崩溃前：每 dedupKey 一行。

	// kill -9 + 同数据目录重启（新端口）——active trigger 应重注册、绝不复制既有分钟的 firing。
	srv.Kill9(t)
	srv.Restart(t)
	c = srv.Client(t)
	wc = c.WS(wsID)

	// 重启后稳定态：仍是每 dedupKey 恰一行（idx_trf_dedup 铁律不被重启破坏）。
	// 短暂轮询让 trigger 服务重载完，再核 dedup 不变式。
	harness.Eventually(t, 15000, "firings readable after restart", func() bool {
		return len(protoC_firings(t, wc, trgID)) >= 1
	})
	protoC_assertOneFiringPerDedup(t, wc, trgID)
}

// protoC_firingRow is the firing wire projection (dedupKey + status — the D3 dedup evidence).
//
// protoC_firingRow 是 firing 线缆投影（dedupKey + status——D3 去重证据）。
type protoC_firingRow struct {
	ID       string `json:"id"`
	DedupKey string `json:"dedupKey"`
	Status   string `json:"status"`
}

func protoC_firings(t *testing.T, wc *harness.Client, trgID string) []protoC_firingRow {
	t.Helper()
	var rows []protoC_firingRow
	wc.GET("/api/v1/triggers/" + trgID + "/firings?limit=200").OK(t, &rows)
	return rows
}

// protoC_assertOneFiringPerDedup fails if any dedupKey maps to >1 Firing (the idx_trf_dedup
// invariant): same-minute cron fires — from a re-materialization or a restart re-registration —
// must collapse onto one row. Robust to test duration: distinct minutes carry distinct keys.
//
// protoC_assertOneFiringPerDedup 若任一 dedupKey 对应 >1 条 Firing 即失败（idx_trf_dedup 不变量）：
// 同分钟 cron fire（重复材化或重启重注册）必折叠成一行。对测试时长鲁棒：不同分钟自带不同 key。
func protoC_assertOneFiringPerDedup(t *testing.T, wc *harness.Client, trgID string) {
	t.Helper()
	rows := protoC_firings(t, wc, trgID)
	if len(rows) == 0 {
		t.Fatal("expected at least one firing")
	}
	byKey := map[string]int{}
	for _, r := range rows {
		byKey[r.DedupKey]++
	}
	for key, n := range byKey {
		if n != 1 {
			t.Fatalf("idx_trf_dedup violated: dedupKey %q has %d firings (must be exactly 1); rows=%+v", key, n, rows)
		}
	}
}

// ── C-sec-10：webhook 明文 secret 门（signatureAlgo 空 → 直比，坏/缺 401、正确 202+run）──

// TestContractProtocol_WebhookPlainSecret: signatureAlgo 缺省的 webhook trigger 用明文 secret 门——
// X-Webhook-Secret（或 ?token=）与配置 secret 直比：坏 secret / 缺 secret → 401；正确 → 202 accepted
// → run 真跑、activation fired + firing started。webhook 入站是公共面，绝不带 workspace 头。
func TestContractProtocol_WebhookPlainSecret(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hook-plain"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	secret := "plain-secret-abc123"
	trgID := trgCreate(t, wc, "plain_hook", "webhook", map[string]any{
		"path": "inbound", "secret": secret, // 无 signatureAlgo → 明文直比模式
	})
	wfID, _ := wfWithTrigger(t, wc, "plain_hook_pipe", trgID)
	url := srv.BaseURL + "/api/v1/webhooks/" + trgID + "/inbound"

	post := func(hdr map[string]string, urlSuffix, body string) int {
		req, _ := http.NewRequest("POST", url+urlSuffix, strings.NewReader(body))
		for k, v := range hdr {
			req.Header.Set(k, v)
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("webhook post: %v", err)
		}
		resp.Body.Close()
		return resp.StatusCode
	}

	// 坏 secret → 401。
	if st := post(map[string]string{"X-Webhook-Secret": "wrong"}, "", `{"event":"push"}`); st != 401 {
		t.Fatalf("bad plain secret must 401, got %d", st)
	}
	// 缺 secret → 401。
	if st := post(nil, "", `{"event":"push"}`); st != 401 {
		t.Fatalf("missing plain secret must 401, got %d", st)
	}
	// 正确 header secret → 202 accepted → run。
	if st := post(map[string]string{"X-Webhook-Secret": secret}, "", `{"event":"push"}`); st < 200 || st >= 300 {
		t.Fatalf("correct plain secret must accept (2xx), got %d", st)
	}
	// 正确 ?token= secret（明文门的第二通道）→ 202（不同 body 免与上一发同分钟去重）。
	if st := post(nil, "?token="+secret, `{"event":"push2"}`); st < 200 || st >= 300 {
		t.Fatalf("correct ?token= plain secret must accept (2xx), got %d", st)
	}

	waitRunCompleted(t, wc, wfID, 30000)
	if r := wc.GET("/api/v1/triggers/" + trgID + "/activations"); !strings.Contains(string(r.Data), `"fired":true`) {
		t.Fatalf("activation ledger must record the fire: %s", r.Data)
	}
	if r := wc.GET("/api/v1/triggers/" + trgID + "/firings"); !strings.Contains(string(r.Data), `"status":"started"`) {
		t.Fatalf("firing must be started: %s", r.Data)
	}
}

// ── C-sec-15：ANSELM_AUTH_TOKEN 下三条 SSE 订阅端点的 bearer 门 ──────────────────

// TestContractProtocol_SSEStreamsBearerGate: 起带 ANSELM_AUTH_TOKEN 的真进程（复用
// platformC_startTokenServer），断言三条 SSE 订阅端点 /api/v1/{messages,entities,notifications}/stream
// 皆受 bearer 门：无 token → 401 UNAUTH_BAD_TOKEN；有 token → 200（SSE 订阅走 ?workspaceID= + Authorization 头）。
func TestContractProtocol_SSEStreamsBearerGate(t *testing.T) {
	const token = "proto-sse-bearer-token"
	base := platformC_startTokenServer(t, token)
	wsID := protoC_authedField(t, base, token, "POST", "/api/v1/workspaces", map[string]any{"name": "sse-gate-ws"}, "id")

	for _, stream := range []string{"messages", "entities", "notifications"} {
		// 无 token → 401 UNAUTH_BAD_TOKEN（bearer 门在 workspace 解析之前）。
		if st, code := protoC_streamProbe(t, base, "", wsID, stream, -1); st != 401 || code != "UNAUTH_BAD_TOKEN" {
			t.Fatalf("%s/stream without token must 401 UNAUTH_BAD_TOKEN, got %d/%s", stream, st, code)
		}
		// 有 token + ?workspaceID= → 200（SSE 连接建立）。
		if st, _ := protoC_streamProbe(t, base, token, wsID, stream, -1); st != http.StatusOK {
			t.Fatalf("%s/stream with token must connect (200), got %d", stream, st)
		}
	}
}
