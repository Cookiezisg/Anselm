//go:build pipeline

// fake_llm.go — FakeLLMServer: an httptest.Server that speaks the OpenAI
// chat completions streaming API. Lets pipeline tests drive the full chat
// runner (real SSE parsing, real tool dispatch) without touching provider
// networks.
//
// Scripts are consumed FIFO; PushDefault provides an unlimited fallback.
// Inject via harness option: h := New(t, WithFakeLLMBaseURL(fake.URL())).
//
// fake_llm.go — 说 OpenAI chat completions 流式 API 的 httptest server。
// 让 pipeline 测试驱动完整 chat runner（真 SSE 解析、真 tool dispatch），
// 而不触及 provider 网络。脚本按 FIFO 消费；PushDefault 作无限兜底。
// 通过 harness option 注入：h := New(t, WithFakeLLMBaseURL(fake.URL()))。
package harness

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

// FakeLLMServer is an httptest.Server that speaks OpenAI-compatible streaming
// chat completions. Scripts are consumed FIFO; PushDefault sets the fallback.
//
// FakeLLMServer 说 OpenAI 兼容流式 chat completions 的 httptest server。
// 脚本 FIFO 消费，PushDefault 设兜底。
type FakeLLMServer struct {
	t      *testing.T
	server *httptest.Server

	mu           sync.Mutex
	queue        []Script
	dflt         *Script
	calls        int
	modelsStatus int // HTTP status for GET /v1/models; default 200
}

// Script describes what one streaming completion call should emit.
//
// Script 描述一次流式 completion 调用应发出什么。
type Script struct {
	// HTTPStatus, if non-zero, returns this status immediately without streaming.
	// Use for testing auth failures (401), rate limits (429), etc.
	//
	// HTTPStatus 非零时直接返回此状态码，不流式——用于测试 401 / 429 等错误路径。
	HTTPStatus int

	// Actions is the ordered sequence of SSE events to emit.
	// Actions 是依序发出的 SSE 动作列表。
	Actions []ChunkAction

	// FinishReason is emitted in the terminal chunk. Defaults to "stop".
	// FinishReason 在末尾 chunk 里发出，默认 "stop"。
	FinishReason string

	InputTokens  int
	OutputTokens int
}

// ChunkAction is one step in a Script sequence.
//
// ChunkAction 是 Script 序列里的一步。
type ChunkAction struct {
	// Kind: "text" | "reasoning" | "tool_call_start" | "tool_call_delta" | "delay"
	Kind string

	Content string        // text/reasoning: delta text; tool_call_delta: args fragment
	ToolID  string        // tool_call_start: the call id (e.g. "call_abc123")
	Name    string        // tool_call_start: function name (e.g. "search_forges")
	Index   int           // tool_call_start and tool_call_delta: call index
	Delay   time.Duration // delay: how long to sleep before the next action
}

// NewFakeLLMServer creates and starts a fake OpenAI-compatible server.
// The server is registered for cleanup via t.Cleanup.
//
// NewFakeLLMServer 创建并启动 fake LLM server，通过 t.Cleanup 注册清理。
func NewFakeLLMServer(t *testing.T) *FakeLLMServer {
	t.Helper()
	f := &FakeLLMServer{t: t, modelsStatus: http.StatusOK}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/chat/completions", f.handle)
	mux.HandleFunc("GET /v1/models", f.handleModels)
	f.server = httptest.NewServer(mux)
	t.Cleanup(f.server.Close)
	return f
}

// SetModelsStatus overrides the HTTP status returned by GET /v1/models.
// Default 200; set to 401 to simulate an invalid key for connectivity tests.
//
// SetModelsStatus 覆盖 GET /v1/models 的响应状态，默认 200。
// 设 401 可模拟 key 无效供 connectivity test 用。
func (f *FakeLLMServer) SetModelsStatus(status int) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.modelsStatus = status
}

// URL returns the OpenAI-compatible base URL to pass to WithFakeLLMBaseURL.
// The real openAIClient appends "/chat/completions" to this URL.
//
// URL 返回传给 WithFakeLLMBaseURL 的 OpenAI 兼容 base URL。
// 真实 openAIClient 会在此 URL 后追加 "/chat/completions"。
func (f *FakeLLMServer) URL() string { return f.server.URL + "/v1" }

// PushScript enqueues one script. Scripts are popped FIFO on each request.
//
// PushScript 入队一条脚本，每次请求 FIFO 弹出。
func (f *FakeLLMServer) PushScript(s Script) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.queue = append(f.queue, s)
}

// PushDefault sets the fallback script used when the queue is empty.
//
// PushDefault 设置队列为空时的兜底脚本（可无限复用）。
func (f *FakeLLMServer) PushDefault(s Script) {
	f.mu.Lock()
	defer f.mu.Unlock()
	cp := s
	f.dflt = &cp
}

// CallCount returns the total number of completions requests received.
//
// CallCount 返回已收到的 completions 请求总数。
func (f *FakeLLMServer) CallCount() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

func (f *FakeLLMServer) handle(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	var (
		script Script
		ok     bool
	)
	if len(f.queue) > 0 {
		script = f.queue[0]
		f.queue = f.queue[1:]
		ok = true
	} else if f.dflt != nil {
		script = *f.dflt
		ok = true
	}
	if ok {
		f.calls++
	}
	f.mu.Unlock()

	if !ok {
		f.t.Errorf("FakeLLMServer: request received but no script in queue and no default set")
		http.Error(w,
			`{"error":{"message":"no script configured","type":"test_error"}}`,
			http.StatusInternalServerError)
		return
	}

	if script.HTTPStatus != 0 {
		http.Error(w,
			`{"error":{"message":"fake provider error","type":"test_error"}}`,
			script.HTTPStatus)
		return
	}

	flusher, isFlusher := w.(http.Flusher)
	if !isFlusher {
		f.t.Errorf("FakeLLMServer: ResponseWriter does not implement http.Flusher")
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)

	for _, action := range script.Actions {
		switch action.Kind {
		case "delay":
			flusher.Flush()
			time.Sleep(action.Delay)
		case "text":
			f.emitSSE(w, flusher, fakeChunk{
				Choices: []fakeChoice{{Delta: fakeDelta{Content: action.Content}}},
			})
		case "reasoning":
			f.emitSSE(w, flusher, fakeChunk{
				Choices: []fakeChoice{{Delta: fakeDelta{ReasoningContent: action.Content}}},
			})
		case "tool_call_start":
			f.emitSSE(w, flusher, fakeChunk{
				Choices: []fakeChoice{{Delta: fakeDelta{
					ToolCalls: []fakeToolCall{{
						Index:    action.Index,
						ID:       action.ToolID,
						Function: fakeFuncDelta{Name: action.Name},
					}},
				}}},
			})
		case "tool_call_delta":
			f.emitSSE(w, flusher, fakeChunk{
				Choices: []fakeChoice{{Delta: fakeDelta{
					ToolCalls: []fakeToolCall{{
						Index:    action.Index,
						Function: fakeFuncDelta{Arguments: action.Content},
					}},
				}}},
			})
		}
	}

	// Terminal chunk: finish reason + token usage.
	// 末尾 chunk：finish reason + token 用量。
	fr := script.FinishReason
	if fr == "" {
		fr = "stop"
	}
	f.emitSSE(w, flusher, fakeChunk{
		Choices: []fakeChoice{{FinishReason: fr}},
		Usage: &fakeUsage{
			PromptTokens:     script.InputTokens,
			CompletionTokens: script.OutputTokens,
		},
	})
	fmt.Fprintf(w, "data: [DONE]\n\n")
	flusher.Flush()
}

func (f *FakeLLMServer) emitSSE(w http.ResponseWriter, fl http.Flusher, chunk fakeChunk) {
	data, _ := json.Marshal(chunk)
	fmt.Fprintf(w, "data: %s\n\n", data)
	fl.Flush()
}

// handleModels serves GET /v1/models. Returns a minimal OpenAI-compatible
// models list (used by apikey connectivity tests via HTTPTester.testGetModels).
// Status is controlled by SetModelsStatus (default 200).
//
// handleModels 提供 GET /v1/models，返回最小 OpenAI 兼容 models 列表。
// 状态由 SetModelsStatus 控制（默认 200）。
func (f *FakeLLMServer) handleModels(w http.ResponseWriter, _ *http.Request) {
	f.mu.Lock()
	status := f.modelsStatus
	f.mu.Unlock()

	if status != http.StatusOK {
		http.Error(w,
			`{"error":{"message":"invalid API key","type":"authentication_error"}}`,
			status)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"data":[{"id":"fake-model-1"},{"id":"fake-model-2"}]}`)
}

// ── wire types matching openai.go parsing structs ────────────────────────────
// Field names and json tags must match exactly what openAIClient parses.
// openai.go 的解析结构对应的 wire 类型，field 名和 json tag 必须完全匹配。

type fakeChunk struct {
	Choices []fakeChoice `json:"choices"`
	Usage   *fakeUsage   `json:"usage,omitempty"`
}

type fakeChoice struct {
	Delta        fakeDelta `json:"delta"`
	FinishReason string    `json:"finish_reason,omitempty"`
}

type fakeDelta struct {
	Content          string         `json:"content,omitempty"`
	ReasoningContent string         `json:"reasoning_content,omitempty"`
	ToolCalls        []fakeToolCall `json:"tool_calls,omitempty"`
}

type fakeToolCall struct {
	Index    int           `json:"index"`
	ID       string        `json:"id,omitempty"`
	Function fakeFuncDelta `json:"function"`
}

type fakeFuncDelta struct {
	Name      string `json:"name,omitempty"`
	Arguments string `json:"arguments,omitempty"`
}

type fakeUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
}
