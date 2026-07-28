// llmmock.go is the OpenAI-compatible fake model server driving the LLM face of black-box
// scenarios at zero token cost. It speaks the REAL wire (POST /chat/completions SSE stream +
// GET /models probe), so the backend's whole provider HTTP path — request building, stream
// parsing, tool-call assembly, usage accounting — is exercised, not bypassed. Turns are
// scripted PER MODEL ID (dialogue vs utility queues never race), and every request is
// captured as a PromptDump: what the model actually saw on the wire IS the experience audit.
//
// llmmock.go 是 OpenAI 兼容的假模型 server，以零 token 驱动黑盒场景的 LLM 面。它讲真线缆
// （POST /chat/completions SSE 流 + GET /models 探测），后端整条 provider HTTP 链——请求构造、
// 流解析、tool-call 组装、usage 记账——全被压到，而非绕过。脚本按 MODEL ID 排队（dialogue 与
// utility 队列互不抢帧）；每个请求捕获为 PromptDump：模型在线缆上真看到了什么，本身就是体验审计。
package harness

import (
	"encoding/base64"
	binaryenc "encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

// MockToolCall is one scripted tool invocation. Args should carry the framework-standard
// fields a real LLM would self-report (summary / danger / execution_group) alongside the
// tool's own arguments.
//
// MockToolCall 是一次脚本化工具调用。Args 应像真 LLM 一样自报框架标准字段（summary /
// danger / execution_group）+ 工具自身参数。
type MockToolCall struct {
	ID   string
	Name string
	Args map[string]any
}

// LLMTurn is one scripted completion. Zero-value fields are defaulted: empty turn → a
// plain "ok." text reply with nominal usage.
//
// LLMTurn 是一次脚本化补全。零值字段有默认：空 turn → 一句 "ok." 文本 + 名义 usage。
type LLMTurn struct {
	Text             string
	Reasoning        string
	ToolCalls        []MockToolCall
	PromptTokens     int // default 100
	CompletionTokens int // default 10
	StallMS          int // flush the first text chunk, then stall this long (cancel scenarios)
	Status           int // non-zero → respond with this HTTP status + OpenAI error envelope

	// ErrorMessage overrides the scripted-failure envelope's message. It exists so a scenario can
	// script a rejection the CLIENT will CLASSIFY, not merely receive: `requestRejectionReason`
	// (backend/internal/infra/llm/transport.go) reads this text to decide whether a failure is a
	// recoverable context-length overflow. Without it every scripted failure looks like a generic
	// provider fault, which is why "provider first overflow → transparent recovery" had no
	// black-box coverage at all. Empty → the generic message.
	//
	// ErrorMessage 覆写脚本化失败信封的 message。它的存在是为了让场景能脚本化一次**会被客户端分类**的
	// 拒绝、而不只是被收到:`requestRejectionReason` 正是读这段文本来判定失败是否为可恢复的上下文超限。
	// 没有它,一切脚本化失败都长得像泛化 provider 故障——这正是「provider 首次 overflow → 透明恢复」
	// 此前在黑盒侧零覆盖的原因。空 → 泛化文案。
	ErrorMessage string

	// EchoLastToolResult replies with the request's last tool message verbatim (Text is ignored).
	// It exists because a REAL model, told to hand an artifact downstream, copies the tool's
	// receipt into its own answer — and only that copy makes the reference reach the next
	// workflow node (an agent node's result IS its final text). A static script cannot spell an
	// attachment id the run only just minted, so without this the media pipeline across nodes is
	// untestable end to end.
	//
	// EchoLastToolResult 原样回请求里最后一条 tool 消息(忽略 Text)。它的存在是因为**真**模型被要求把
	// 产物交给下游时,会把工具 receipt 抄进自己的答案——而恰是这次抄写让引用抵达下一个 workflow 节点
	// (agent 节点的结果**就是**它的终答文本)。静态脚本拼不出这次运行刚铸出的附件 id,没有它,跨节点
	// 的媒体流水线就无法端到端被测。
	EchoLastToolResult bool
}

// PromptDump is one captured request — the model's-eye view of the conversation.
//
// PromptDump 是一次捕获的请求——模型视角的对话。
type PromptDump struct {
	Model    string
	System   string
	Messages []DumpMsg
	Tools    []string
	Raw      json.RawMessage
}

// DumpMsg is one wire message in a captured request (content flattened to string
// best-effort; multimodal arrays stay in Raw).
//
// DumpMsg 是捕获请求里的一条线缆消息（content 尽力拍平成 string；多模态数组留在 Raw）。
type DumpMsg struct {
	Role       string
	Content    string
	ToolCallID string
	ToolNames  []string // assistant tool_calls names
}

// HasMessage reports whether any wire message of the role contains the substring.
//
// HasMessage 报告某 role 的线缆消息是否含子串。
func (d *PromptDump) HasMessage(role, substr string) bool {
	for _, m := range d.Messages {
		if m.Role == role && strings.Contains(m.Content, substr) {
			return true
		}
	}
	return false
}

// LLMMock is the scripted fake provider. Start with NewLLMMock; point an apikey's baseUrl
// at URL().
//
// LLMMock 是脚本化假供应商。NewLLMMock 启动；apikey 的 baseUrl 指向 URL()。
type LLMMock struct {
	t   *testing.T
	srv *httptest.Server

	dumpLog // captured requests — shared verbatim with Recorder. 捕获的请求——与 Recorder 逐字共用。

	mu           sync.Mutex
	queues       map[string][]LLMTurn
	imagePrompts []string
	speechInputs []string
	videoPrompts []string
	// videoPhase is what the next poll answers. Scenarios drive it directly: a real generation
	// takes minutes and a test must not.
	// videoPhase 是下一次轮询的答案。场景直接驱动它:真生成要几分钟,而测试不可以。
	videoPhase string
}

// NewLLMMock starts the fake provider on a loopback port and registers cleanup.
//
// NewLLMMock 在回环端口启动假供应商并注册清理。
func NewLLMMock(t *testing.T) *LLMMock {
	t.Helper()
	m := &LLMMock{t: t, queues: map[string][]LLMTurn{}}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /models", m.handleModels)
	mux.HandleFunc("POST /chat/completions", m.handleCompletions)
	mux.HandleFunc("POST /images/generations", m.handleImages)
	mux.HandleFunc("POST /audio/speech", m.handleSpeech)
	// The MANAGED video wire (WRK-082 H1): two routes, because the video family has no synchronous
	// form. This mock plays the GATEWAY, not DashScope — the desktop's anselm dialect talks to the
	// gateway's own contract (202 + a signed handle, then a four-word phase), and mocking the vendor
	// instead would test a conversation this code never has.
	// **受管**视频线缆(H1):两条路由,因为视频族没有同步形态。本 mock 扮的是**网关**、不是 DashScope
	// ——桌面端的 anselm 方言讲的是网关自己的契约(202 + 签名句柄,然后一个四字状态),去 mock 厂商
	// 等于测一场这段代码从未发生过的对话。
	mux.HandleFunc("POST /videos/generations", m.handleVideoSubmit)
	mux.HandleFunc("GET /videos/{videoId}", m.handleVideoStatus)
	// GATEWAY MODE (WRK-082 H4). The managed `anselm` provider does not send a bearer token — it
	// signs every request with a device proof, and the transport refuses to send anything at all
	// until it has fetched a challenge. So a mock that only serves the business routes cannot be
	// reached by the managed dialect: the very first probe dies on a 404 challenge.
	//
	// The proof itself is NOT verified here, deliberately. Whether a signature is valid is the
	// gateway's business, and the gateway's own e2e proves it against the real verifier. What this
	// mock has to do is let the handshake COMPLETE, so that the thing under test — the desktop's
	// managed dialect — actually gets to speak.
	//
	// **网关模式**(H4)。受管 `anselm` provider 不送 bearer token——它给每个请求签一份 device proof,
	// 而 transport 在拿到 challenge 之前**什么都不发**。故一个只伺候业务路由的 mock **根本够不着**:
	// 第一次探测就死在 404 challenge 上。
	//
	// 这里刻意**不验**那份 proof。签名对不对是**网关**的事,网关自己的 e2e 已在真验证器上证过。本 mock
	// 要做的是让握手**走完**,好让真正被测的那个东西——桌面端的受管方言——真的开得了口。
	// The free-tier lifecycle, so a scenario can point ANSELM_GATEWAY_URL here and get a REAL managed
	// key instead of a workspace with none. After H11 that is the only way to exercise generation at
	// all — the tools are managed-only now, so a scenario without an install is a scenario where they
	// honestly do not exist. Like the proof handshake above, this fakes the gateway's ANSWERS, never
	// its judgement: quota and billing are the gateway's own e2e's business.
	// 免费档生命周期,使场景可以把 ANSELM_GATEWAY_URL 指到这里、真的拿到一把**受管** key,而不是一个
	// 一把 key 都没有的 workspace。H11 之后这是**唯一**能跑起生成的路子——那些工具现在只在受管档,故
	// 一个没有 install 的场景就是「它们诚实地不存在」的场景。与上面的握手同理:这里假的是网关的**回答**、
	// 绝不是它的**判断**;配额与计费是网关自己 e2e 的事。
	mux.HandleFunc("POST /v1/install", m.handleInstall)
	mux.HandleFunc("GET /v1/quota", m.handleQuota)
	mux.HandleFunc("GET /v1/proof/challenge", m.handleProofChallenge)
	mux.HandleFunc("GET /v1/models", m.handleModels)
	mux.HandleFunc("POST /v1/chat/completions", m.handleCompletions)
	mux.HandleFunc("POST /v1/images/generations", m.handleImages)
	mux.HandleFunc("POST /v1/audio/speech", m.handleSpeech)
	mux.HandleFunc("POST /v1/videos/generations", m.handleVideoSubmit)
	mux.HandleFunc("GET /v1/videos/{videoId}", m.handleVideoStatus)
	m.srv = httptest.NewServer(mux)
	t.Cleanup(m.srv.Close)
	return m
}

// URL is the base URL to put on the apikey (provider openai appends /chat/completions).
//
// URL 是放进 apikey 的 base URL（openai provider 自行拼 /chat/completions）。
func (m *LLMMock) URL() string { return m.srv.URL }

// GatewayURL is the base URL to put on a MANAGED (`anselm`) api-key. It carries the `/v1` prefix
// the real gateway serves under, because the device-proof transport derives the challenge URL from
// the request's ORIGIN and appends `/v1/proof/challenge` — a base URL without the prefix would send
// business calls to one path family and the handshake to another.
//
// GatewayURL 是放进**受管**(`anselm`)api-key 的 base URL。它带着真网关服务所在的 `/v1` 前缀,因为
// device-proof transport 从请求的 **origin** 推 challenge URL 并拼上 `/v1/proof/challenge`——一个不带
// 前缀的 base URL 会让业务调用走一族路径、握手走另一族。
func (m *LLMMock) GatewayURL() string { return m.srv.URL + "/v1" }

// Enqueue scripts the next turns for one model id (FIFO). An exhausted queue serves the
// default turn — scenarios fail on content, not on hangs.
//
// Enqueue 给一个 model id 排下一批 turn（FIFO）。队列耗尽即发默认 turn——场景在内容上失败、
// 不在挂起上失败。
func (m *LLMMock) Enqueue(model string, turns ...LLMTurn) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.queues[model] = append(m.queues[model], turns...)
}

// Clear drops any unserved turns for one model — sub-scenarios within a test must not
// poison each other with leftovers (e.g. spare scripted failures).
//
// Clear 丢弃某 model 未消费的 turn——同测试内的子场景不得拿残留（如多排的故障帧）毒到彼此。
func (m *LLMMock) Clear(model string) {
	m.mu.Lock()
	delete(m.queues, model)
	m.mu.Unlock()
}

func (m *LLMMock) handleModels(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	// Catalog-known ids so capability probing works; scenarios may still use any id.
	// 用目录认识的 id 使能力探测可用；场景仍可用任意 id。
	_ = json.NewEncoder(w).Encode(map[string]any{
		"object": "list",
		"data": []map[string]string{
			// gpt-4o-2024-11-20 is here for one reason: it is a catalog-known VISION model that does
			// NOT read PDF inline, which is the only way to exercise the sandbox-extraction route now
			// that plain `gpt-4o` gained `pdf` in the models.dev catalog. A model absent from this
			// list probes as unknown and falls back to conservative capabilities — which reads as
			// "the feature is broken" rather than "the fixture is short an id".
			// gpt-4o-2024-11-20 在这里只为一件事:它是目录已知的**视觉**模型且**不原生读 PDF**,而在
			// 普通 gpt-4o 于 models.dev 目录里获得 `pdf` 之后,那是唯一还能跑通 sandbox 抽取那条路的办法。
			// 不在此列表里的模型探测为未知、回落保守能力——读起来像「功能坏了」,其实是夹具少了一个 id。
			{"id": "gpt-4o"}, {"id": "gpt-4o-2024-11-20"},
			{"id": "mock-dialogue"}, {"id": "mock-utility"}, {"id": "mock-agent"},
		},
	})
}

// handleCompletions captures the dump, pops the model's next scripted turn, and streams it
// back in OpenAI SSE chunks (or one non-streaming body when stream=false).
//
// handleCompletions 捕获 dump、弹出该 model 的下一个脚本 turn、按 OpenAI SSE chunk 流回
// （stream=false 时单体返回）。
func (m *LLMMock) handleCompletions(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Model    string          `json:"model"`
		Stream   bool            `json:"stream"`
		Messages json.RawMessage `json:"messages"`
		Tools    []struct {
			Function struct {
				Name string `json:"name"`
			} `json:"function"`
		} `json:"tools"`
	}
	raw := json.RawMessage{}
	if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
		http.Error(w, "bad body", http.StatusBadRequest)
		return
	}
	if err := json.Unmarshal(raw, &req); err != nil {
		http.Error(w, "bad shape", http.StatusBadRequest)
		return
	}

	dump := parsePromptDump(raw)

	m.mu.Lock()
	q := m.queues[req.Model]
	var turn LLMTurn
	if len(q) > 0 {
		turn, m.queues[req.Model] = q[0], q[1:]
	} else {
		turn = LLMTurn{Text: "ok."}
	}
	m.mu.Unlock()
	m.add(dump)

	if turn.EchoLastToolResult {
		for i := len(dump.Messages) - 1; i >= 0; i-- {
			if dump.Messages[i].Role == "tool" {
				turn.Text = dump.Messages[i].Content
				break
			}
		}
	}
	if turn.PromptTokens == 0 {
		turn.PromptTokens = 100
	}
	if turn.CompletionTokens == 0 {
		turn.CompletionTokens = 10
	}
	if turn.Status != 0 {
		message := turn.ErrorMessage
		if message == "" {
			message = "scripted provider failure"
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(turn.Status)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"error": map[string]any{"message": message, "type": "mock_error"},
		})
		return
	}
	if req.Stream {
		m.streamTurn(w, turn)
		return
	}
	m.plainTurn(w, turn)
}

// streamTurn emits the turn as OpenAI SSE chunks: reasoning → text (2 chunks) → tool_calls
// → finish_reason → usage → [DONE].
//
// streamTurn 把 turn 按 OpenAI SSE chunk 发出：reasoning → text（两片）→ tool_calls →
// finish_reason → usage → [DONE]。
func (m *LLMMock) streamTurn(w http.ResponseWriter, turn LLMTurn) {
	w.Header().Set("Content-Type", "text/event-stream")
	flusher, _ := w.(http.Flusher)
	emit := func(v any) {
		b, _ := json.Marshal(v)
		fmt.Fprintf(w, "data: %s\n\n", b)
		if flusher != nil {
			flusher.Flush()
		}
	}
	delta := func(d map[string]any) map[string]any {
		return map[string]any{"choices": []map[string]any{{"delta": d}}}
	}

	if turn.Reasoning != "" {
		emit(delta(map[string]any{"reasoning_content": turn.Reasoning}))
	}
	if turn.Text != "" {
		half := len(turn.Text) / 2
		emit(delta(map[string]any{"content": turn.Text[:half]}))
		if turn.StallMS > 0 {
			time.Sleep(time.Duration(turn.StallMS) * time.Millisecond)
		}
		emit(delta(map[string]any{"content": turn.Text[half:]}))
	} else if turn.StallMS > 0 {
		time.Sleep(time.Duration(turn.StallMS) * time.Millisecond)
	}
	finish := "stop"
	if len(turn.ToolCalls) > 0 {
		finish = "tool_calls"
		for i, tc := range turn.ToolCalls {
			args, _ := json.Marshal(tc.Args)
			id := tc.ID
			if id == "" {
				id = fmt.Sprintf("call_%d", i+1)
			}
			emit(delta(map[string]any{"tool_calls": []map[string]any{{
				"index": i, "id": id,
				"function": map[string]any{"name": tc.Name, "arguments": string(args)},
			}}}))
		}
	}
	emit(map[string]any{"choices": []map[string]any{{"delta": map[string]any{}, "finish_reason": finish}}})
	emit(map[string]any{"choices": []map[string]any{}, "usage": map[string]int{
		"prompt_tokens": turn.PromptTokens, "completion_tokens": turn.CompletionTokens,
	}})
	fmt.Fprint(w, "data: [DONE]\n\n")
	if flusher != nil {
		flusher.Flush()
	}
}

// plainTurn emits the turn as one non-streaming completion body.
//
// plainTurn 把 turn 作为单条非流式补全返回。
func (m *LLMMock) plainTurn(w http.ResponseWriter, turn LLMTurn) {
	finish := "stop"
	var calls []map[string]any
	for i, tc := range turn.ToolCalls {
		args, _ := json.Marshal(tc.Args)
		id := tc.ID
		if id == "" {
			id = fmt.Sprintf("call_%d", i+1)
		}
		calls = append(calls, map[string]any{
			"index": i, "id": id, "type": "function",
			"function": map[string]any{"name": tc.Name, "arguments": string(args)},
		})
	}
	if len(calls) > 0 {
		finish = "tool_calls"
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"choices": []map[string]any{{
			"message": map[string]any{
				"role": "assistant", "content": turn.Text,
				"reasoning_content": turn.Reasoning, "tool_calls": calls,
			},
			"finish_reason": finish,
		}},
		"usage": map[string]int{
			"prompt_tokens": turn.PromptTokens, "completion_tokens": turn.CompletionTokens,
		},
	})
}

// MockPNG is the 1×1 PNG every mocked image generation returns — scenarios assert the stored
// attachment's bytes equal it, proving the whole artifact pipeline end to end.
//
// MockPNG 是每次 mock 生成返回的 1×1 PNG——场景断言落库附件字节与之相等,整条产物管线得证。
var MockPNG = []byte{
	0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
	0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
	0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
	0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
	0x42, 0x60, 0x82,
}

// ImagePrompts returns every prompt POST /images/generations received (order preserved).
//
// ImagePrompts 返回 /images/generations 收到的全部 prompt(保序)。
func (m *LLMMock) ImagePrompts() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]string(nil), m.imagePrompts...)
}

// handleImages speaks the OpenAI images wire (the desktop's openai dialect): records the prompt,
// returns MockPNG as b64_json — WRK-082 批B's zero-token image upstream.
//
// handleImages 讲 OpenAI images 线缆(桌面 openai 方言):记 prompt、返 b64 的 MockPNG——批B 的
// 零 token 图像上游。
func (m *LLMMock) handleImages(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Prompt string `json:"prompt"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	m.mu.Lock()
	m.imagePrompts = append(m.imagePrompts, req.Prompt)
	m.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"created": 1,
		"data": []map[string]any{{
			"b64_json": base64.StdEncoding.EncodeToString(MockPNG),
		}},
	})
}

// MockWAV is the tiny 24kHz/16-bit/mono WAV every mocked synthesis returns — scenarios assert the
// stored attachment's bytes against it, which proves the whole artifact pipeline end to end. It is
// a REAL RIFF stream rather than arbitrary bytes because the desktop rejoins chunks at the PCM
// level: a fake payload would make a multi-chunk test pass for the wrong reason (or fail for one).
//
// MockWAV 是每次 mock 合成返回的极小 24kHz/16bit/mono WAV——场景据它断言落库附件字节,整条产物管线
// 得证。它是**真** RIFF 流而非随便一段字节,因为桌面端在 PCM 层重接块:假载荷会让多块测试因错误的
// 理由通过(或因错误的理由失败)。
var MockWAV = buildMockWAV(240) // 240 samples ≈ 10ms

func buildMockWAV(samples int) []byte {
	pcm := make([]byte, samples*2)
	out := make([]byte, 44, 44+len(pcm))
	copy(out[0:4], "RIFF")
	binaryenc.LittleEndian.PutUint32(out[4:8], uint32(36+len(pcm)))
	copy(out[8:12], "WAVE")
	copy(out[12:16], "fmt ")
	binaryenc.LittleEndian.PutUint32(out[16:20], 16)
	binaryenc.LittleEndian.PutUint16(out[20:22], 1)
	binaryenc.LittleEndian.PutUint16(out[22:24], 1)
	binaryenc.LittleEndian.PutUint32(out[24:28], 24000)
	binaryenc.LittleEndian.PutUint32(out[28:32], 48000)
	binaryenc.LittleEndian.PutUint16(out[32:34], 2)
	binaryenc.LittleEndian.PutUint16(out[34:36], 16)
	copy(out[36:40], "data")
	binaryenc.LittleEndian.PutUint32(out[40:44], uint32(len(pcm)))
	return append(out, pcm...)
}

// handleSpeech speaks the OpenAI `/audio/speech` wire (shared by the desktop's openai and zhipu
// dialects): records the input text and answers RAW audio bytes, exactly as both providers do.
//
// handleSpeech 讲 OpenAI `/audio/speech` 线缆(桌面 openai 与智谱两方言共用):记下输入文本、返
// **裸**音频字节,与两家的真实行为一致。
func (m *LLMMock) handleSpeech(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Input string `json:"input"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	m.mu.Lock()
	m.speechInputs = append(m.speechInputs, req.Input)
	m.mu.Unlock()
	w.Header().Set("Content-Type", "audio/wav")
	_, _ = w.Write(MockWAV)
}

// SpeechInputs returns every text the mocked TTS upstream was asked to speak — the count IS the
// money assertion for read-aloud caching (a cached listen must add nothing here).
//
// SpeechInputs 返回 mock TTS 上游被要求念过的每段文本——**次数**就是朗读缓存的钱断言(命中缓存的
// 一次收听不得在此多出一条)。
func (m *LLMMock) SpeechInputs() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]string, len(m.speechInputs))
	copy(out, m.speechInputs)
	return out
}

// handleVideoSubmit answers the gateway's 202 + opaque handle. The handle is deliberately NOT the
// prompt or any derivable value: the desktop must treat it as opaque, and a mock that returned
// something guessable would let a bug that parses the handle pass.
//
// handleVideoSubmit 答网关的 202 + 不透明句柄。句柄刻意**不是** prompt、也不是任何可推导的值:桌面端
// 必须把它当不透明物,而一个返回可猜之物的 mock 会放过一个去解析句柄的 bug。
func (m *LLMMock) handleVideoSubmit(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Prompt  string `json:"prompt"`
		Seconds int    `json:"seconds"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	m.mu.Lock()
	m.videoPrompts = append(m.videoPrompts, req.Prompt)
	m.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"id": "aGFuZGxl.c2ln", "object": "video.generation", "status": "pending", "created": 1,
	})
}

// handleVideoStatus answers whatever phase the scenario armed, defaulting to `failed` so a test
// that forgets to arm one ends in seconds with a clear message instead of polling for minutes.
//
// handleVideoStatus 答场景装好的那个 phase,默认 `failed`——这样一个忘了装 phase 的测试会在几秒内
// 带着明确信息结束,而不是轮询几分钟。
func (m *LLMMock) handleVideoStatus(w http.ResponseWriter, r *http.Request) {
	m.mu.Lock()
	phase := m.videoPhase
	m.mu.Unlock()
	if phase == "" {
		phase = "failed"
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"id": r.PathValue("videoId"), "object": "video.generation", "status": phase,
	})
}

// SetVideoPhase arms what the next poll answers.
//
// SetVideoPhase 装好下一次轮询的答案。
func (m *LLMMock) SetVideoPhase(phase string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.videoPhase = phase
}

// VideoPrompts returns every prompt POST /videos/generations received (order preserved).
//
// VideoPrompts 返回 /videos/generations 收到的全部 prompt(保序)。
func (m *LLMMock) VideoPrompts() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]string(nil), m.videoPrompts...)
}

// handleProofChallenge issues a nonce the desktop's device-proof transport can sign against. The
// expiry is far enough out that no scenario can outlive it.
//
// handleProofChallenge 发一个 nonce 供桌面端 device-proof transport 签名。有效期足够长,任何场景都
// 活不过它。
func (m *LLMMock) handleProofChallenge(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"nonce":     "testend-proof-nonce",
		"expiresAt": time.Now().Add(time.Hour).UTC().Format(time.RFC3339),
	})
}

// handleInstall registers any device that asks. The gateway's real anti-Sybil gates are its own
// business; refusing here would only stop the desktop's managed dialect from ever speaking.
// handleInstall 来者不拒。网关真正的防 Sybil 闸是它自己的事;在这里拒绝,只会让桌面端的受管方言永远
// 开不了口。
func (m *LLMMock) handleInstall(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = io.WriteString(w, `{"installId":"ins_mock000000001","monthlyQuota":1000000,"resetAt":"2099-01-01T00:00:00Z"}`)
}

// handleQuota answers a generous, always-available quota: a scenario that wanted to test exhaustion
// would have to say so, and none does — the gateway owns that logic and tests it for real.
// handleQuota 答一个宽裕且恒可用的配额:想测耗尽的场景得自己说,而没有场景这么说——那套逻辑归网关,
// 它自己真测。
func (m *LLMMock) handleQuota(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = io.WriteString(w, `{"limit":1000000,"used":0,"remaining":1000000,"resetAt":"2099-01-01T00:00:00Z","available":true}`)
}
