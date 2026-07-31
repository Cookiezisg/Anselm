// contract_anthropic_test.go — 原生 Anthropic provider 的黑盒线缆闭环。
//
// 这个场景故意不走 llm 包的单元测试：它把一台只会 Anthropic 原生协议的本地上游放在
// 真实 backend 外面，验证探测、能力目录、x-api-key、/v1/messages block body、命名 SSE
// 与 usage 落盘在产品 API 上能连成一条用户可见的链。
package scenarios

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

const anthropicContractModel = "claude-opus-4-8"

const anthropicContractSSE = `event: message_start
data: {"type":"message_start","message":{"id":"msg_contract_1","type":"message","role":"assistant","content":[],"model":"claude-opus-4-8","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":3,"output_tokens":0}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"anthropic-native-ok"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":4}}

event: message_stop
data: {"type":"message_stop"}

`

type anthropicContractCapture struct {
	mu sync.Mutex

	probeCount         int
	probePath          string
	probeAPIKey        string
	probeVersion       string
	probeAuthorization string

	messageCount         int
	messagePath          string
	messageAPIKey        string
	messageVersion       string
	messageAuthorization string
	messageBody          []byte
}

// TestContractProvider_AnthropicNativeHTTPAndPersistence exercises the real product path against
// a local Anthropic-shaped upstream. It catches a regression where the app probes with one dialect
// but invokes with OpenAI-compatible headers/body, and it also proves named SSE usage reaches the
// durable assistant turn rather than only producing an ephemeral stream.
func TestContractProvider_AnthropicNativeHTTPAndPersistence(t *testing.T) {
	t.Parallel()
	capture := &anthropicContractCapture{}
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capture.mu.Lock()
		defer capture.mu.Unlock()

		switch {
		case r.Method == http.MethodGet && r.URL.Path == "/v1/models":
			capture.probeCount++
			capture.probePath = r.URL.Path
			capture.probeAPIKey = r.Header.Get("x-api-key")
			capture.probeVersion = r.Header.Get("anthropic-version")
			capture.probeAuthorization = r.Header.Get("Authorization")
			w.Header().Set("Content-Type", "application/json")
			_, _ = io.WriteString(w, `{"data":[{"id":"claude-opus-4-8","type":"model","display_name":"Claude Opus 4.8","created_at":"2026-01-01T00:00:00Z"}],"has_more":false}`)

		case r.Method == http.MethodPost && r.URL.Path == "/v1/messages":
			capture.messageCount++
			capture.messagePath = r.URL.Path
			capture.messageAPIKey = r.Header.Get("x-api-key")
			capture.messageVersion = r.Header.Get("anthropic-version")
			capture.messageAuthorization = r.Header.Get("Authorization")
			body, _ := io.ReadAll(r.Body)
			capture.messageBody = append(capture.messageBody[:0], body...)
			w.Header().Set("Cache-Control", "no-cache")
			w.Header().Set("Content-Type", "text/event-stream")
			_, _ = io.WriteString(w, anthropicContractSSE)

		default:
			http.NotFound(w, r)
		}
	}))
	defer upstream.Close()

	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "anthropic-native-contract"}).Field(t, "id")
	wc := c.WS(wsID)

	const fakeKey = "anthropic-contract-key"
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "anthropic", "displayName": "anthropic-contract", "key": fakeKey, "baseUrl": upstream.URL,
	}).Field(t, "id")
	var probe struct {
		OK bool `json:"ok"`
	}
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, &probe)
	if !probe.OK {
		t.Fatal("Anthropic-shaped /v1/models probe must be accepted")
	}

	// The real capability path must retain the live model id and Anthropic-native knobs/docs facts.
	var caps []struct {
		APIKeyID   string `json:"apiKeyId"`
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		Vision     bool   `json:"vision"`
		NativeDocs bool   `json:"nativeDocs"`
		Knobs      []struct {
			Key string `json:"key"`
		} `json:"knobs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	var capFound bool
	for _, cap := range caps {
		if cap.APIKeyID != keyID || cap.Provider != "anthropic" || cap.ModelID != anthropicContractModel {
			continue
		}
		capFound = true
		if !cap.Vision || !cap.NativeDocs {
			t.Fatalf("Anthropic capability projection lost catalog modalities: %+v", cap)
		}
		keys := map[string]bool{}
		for _, knob := range cap.Knobs {
			keys[knob.Key] = true
		}
		if !keys["thinking"] || !keys["effort"] {
			t.Fatalf("Anthropic native knobs missing from capability projection: %+v", cap.Knobs)
		}
	}
	if !capFound {
		t.Fatalf("live Anthropic model was not exposed by capabilities: %+v", caps)
	}

	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": anthropicContractModel}).OK(t, nil)
	convID := convCreate(t, wc, "Anthropic native wire")
	msgID := sendMsg(t, wc, convID, "Return the fixed native protocol proof.")
	turn := waitTurn(t, wc, convID, msgID, 30000)
	if turn.Status != "completed" {
		t.Fatalf("Anthropic native turn must complete, got status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if text, ok := blockOfType(turn, "text"); !ok || text != "anthropic-native-ok" {
		t.Fatalf("named Anthropic SSE text was not persisted verbatim: %+v", turn.Blocks)
	}
	if turn.StopReason != "end_turn" || turn.InputTokens != 3 || turn.OutputTokens != 4 {
		t.Fatalf("Anthropic SSE finish/usage did not reach durable turn: stop=%q input=%d output=%d", turn.StopReason, turn.InputTokens, turn.OutputTokens)
	}

	capture.mu.Lock()
	probeCount, probePath, probeAPIKey, probeVersion, probeAuthorization := capture.probeCount, capture.probePath, capture.probeAPIKey, capture.probeVersion, capture.probeAuthorization
	messageCount, messagePath, messageAPIKey, messageVersion, messageAuthorization := capture.messageCount, capture.messagePath, capture.messageAPIKey, capture.messageVersion, capture.messageAuthorization
	body := append([]byte(nil), capture.messageBody...)
	capture.mu.Unlock()
	if probeCount != 1 || probePath != "/v1/models" || probeAPIKey != fakeKey || probeVersion != "2023-06-01" || probeAuthorization != "" {
		t.Fatalf("Anthropic probe wire drifted: count=%d path=%q version=%q authorization-present=%v", probeCount, probePath, probeVersion, probeAuthorization != "")
	}
	if messageCount != 1 || messagePath != "/v1/messages" || messageAPIKey != fakeKey || messageVersion != "2023-06-01" || messageAuthorization != "" {
		t.Fatalf("Anthropic message wire drifted: count=%d path=%q version=%q authorization-present=%v", messageCount, messagePath, messageVersion, messageAuthorization != "")
	}

	var request struct {
		Model     string `json:"model"`
		Stream    bool   `json:"stream"`
		MaxTokens int    `json:"max_tokens"`
		Messages  []struct {
			Role    string          `json:"role"`
			Content json.RawMessage `json:"content"`
		} `json:"messages"`
	}
	if err := json.Unmarshal(body, &request); err != nil {
		t.Fatalf("Anthropic message body is not JSON: %v", err)
	}
	if request.Model != anthropicContractModel || !request.Stream || request.MaxTokens <= 0 || len(request.Messages) == 0 {
		t.Fatalf("Anthropic message body missing native request fields: model=%q stream=%v max_tokens=%d messages=%d", request.Model, request.Stream, request.MaxTokens, len(request.Messages))
	}
	if request.Messages[len(request.Messages)-1].Role != "user" {
		t.Fatalf("Anthropic message body must end with the user turn, got role=%q", request.Messages[len(request.Messages)-1].Role)
	}
	var blocks []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	}
	if err := json.Unmarshal(request.Messages[len(request.Messages)-1].Content, &blocks); err != nil || len(blocks) != 1 || blocks[0].Type != "text" || !strings.Contains(blocks[0].Text, "fixed native protocol proof") {
		t.Fatalf("Anthropic user content must be block-form text, got %s (err=%v)", request.Messages[len(request.Messages)-1].Content, err)
	}
	if bytes.Contains(body, []byte(`"role":"prompt"`)) {
		t.Fatal("Anthropic body used an invalid prompt role")
	}
}

const customAnthropicContractSSE = `event: message_start
data: {"type":"message_start","message":{"id":"msg_custom_contract_1","type":"message","role":"assistant","content":[],"model":"custom-claude","stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":5,"output_tokens":0}}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"custom-anthropic-ok"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":6}}

event: message_stop
data: {"type":"message_stop"}

`

// TestContractProvider_CustomAnthropicCompatibleRoutesNativeWire proves the user-defined endpoint
// branch keeps its conservative capability contract (no invented catalog knobs) while APIFormat
// still selects the full native Anthropic transport for both probe and chat.
func TestContractProvider_CustomAnthropicCompatibleRoutesNativeWire(t *testing.T) {
	t.Parallel()
	var mu sync.Mutex
	var probeCount, messageCount int
	var probePath, messagePath, probeKey, messageKey, probeVersion, messageVersion string
	var probeAuthorization, messageAuthorization string
	var messageBody []byte
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		switch {
		case r.Method == http.MethodGet && r.URL.Path == "/v1/models":
			probeCount++
			probePath, probeKey, probeVersion = r.URL.Path, r.Header.Get("x-api-key"), r.Header.Get("anthropic-version")
			probeAuthorization = r.Header.Get("Authorization")
			w.Header().Set("Content-Type", "application/json")
			_, _ = io.WriteString(w, `{"data":[{"id":"custom-claude","type":"model","display_name":"Custom Claude","created_at":"2026-01-01T00:00:00Z"}]}`)
		case r.Method == http.MethodPost && r.URL.Path == "/v1/messages":
			messageCount++
			messagePath, messageKey, messageVersion = r.URL.Path, r.Header.Get("x-api-key"), r.Header.Get("anthropic-version")
			messageAuthorization = r.Header.Get("Authorization")
			messageBody, _ = io.ReadAll(r.Body)
			w.Header().Set("Content-Type", "text/event-stream")
			_, _ = io.WriteString(w, customAnthropicContractSSE)
		default:
			http.NotFound(w, r)
		}
	}))
	defer upstream.Close()

	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "custom-anthropic-contract"}).Field(t, "id")
	wc := c.WS(wsID)

	const fakeKey = "custom-anthropic-contract-key"
	var keyRow struct {
		ID        string `json:"id"`
		APIFormat string `json:"apiFormat"`
	}
	wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "custom", "displayName": "custom-anthropic-contract", "key": fakeKey,
		"baseUrl": upstream.URL, "apiFormat": "anthropic-compatible",
	}).OK(t, &keyRow)
	if keyRow.ID == "" || keyRow.APIFormat != "anthropic-compatible" {
		t.Fatalf("custom Anthropic key must preserve APIFormat on the product surface: %+v", keyRow)
	}
	wc.POST("/api/v1/api-keys/"+keyRow.ID+":test", nil).OK(t, nil)

	// A custom endpoint has no catalog facts. It must still expose the probed id, but not invent
	// image/PDF windows or Anthropic knobs merely because its APIFormat selects the Anthropic wire.
	var caps []struct {
		APIKeyID   string `json:"apiKeyId"`
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		Vision     bool   `json:"vision"`
		NativeDocs bool   `json:"nativeDocs"`
		Knobs      []struct {
			Key string `json:"key"`
		} `json:"knobs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	var found bool
	for _, cap := range caps {
		if cap.APIKeyID != keyRow.ID || cap.Provider != "custom" || cap.ModelID != "custom-claude" {
			continue
		}
		found = true
		if cap.Vision || cap.NativeDocs || len(cap.Knobs) != 0 {
			t.Fatalf("custom endpoint must not fabricate catalog capabilities: %+v", cap)
		}
	}
	if !found {
		t.Fatalf("custom Anthropic model id missing from capabilities: %+v", caps)
	}

	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyRow.ID, "modelId": "custom-claude"}).OK(t, nil)
	convID := convCreate(t, wc, "custom Anthropic native wire")
	msgID := sendMsg(t, wc, convID, "Prove the custom native route.")
	turn := waitTurn(t, wc, convID, msgID, 30000)
	if turn.Status != "completed" {
		t.Fatalf("custom Anthropic-compatible turn must complete, got status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if text, ok := blockOfType(turn, "text"); !ok || text != "custom-anthropic-ok" {
		t.Fatalf("custom native SSE text missing: %+v", turn.Blocks)
	}
	if turn.InputTokens != 5 || turn.OutputTokens != 6 || turn.StopReason != "end_turn" {
		t.Fatalf("custom native SSE usage/finish missing: stop=%q input=%d output=%d", turn.StopReason, turn.InputTokens, turn.OutputTokens)
	}

	mu.Lock()
	gotProbeCount, gotMessageCount := probeCount, messageCount
	gotProbePath, gotMessagePath := probePath, messagePath
	gotProbeKey, gotMessageKey := probeKey, messageKey
	gotProbeVersion, gotMessageVersion := probeVersion, messageVersion
	gotProbeAuthorization, gotMessageAuthorization := probeAuthorization, messageAuthorization
	body := append([]byte(nil), messageBody...)
	mu.Unlock()
	if gotProbeCount != 1 || gotMessageCount != 1 || gotProbePath != "/v1/models" || gotMessagePath != "/v1/messages" || gotProbeKey != fakeKey || gotMessageKey != fakeKey || gotProbeVersion != "2023-06-01" || gotMessageVersion != "2023-06-01" || gotProbeAuthorization != "" || gotMessageAuthorization != "" {
		t.Fatalf("custom APIFormat did not select the native Anthropic wire: probe=%d/%s message=%d/%s versions=%q/%q authorization-present=%v/%v", gotProbeCount, gotProbePath, gotMessageCount, gotMessagePath, gotProbeVersion, gotMessageVersion, gotProbeAuthorization != "", gotMessageAuthorization != "")
	}
	var request struct {
		Model    string `json:"model"`
		Stream   bool   `json:"stream"`
		Messages []struct {
			Role    string          `json:"role"`
			Content json.RawMessage `json:"content"`
		} `json:"messages"`
	}
	if err := json.Unmarshal(body, &request); err != nil || request.Model != "custom-claude" || !request.Stream || len(request.Messages) == 0 {
		t.Fatalf("custom Anthropic request body did not use native shape: err=%v model=%q stream=%v messages=%d", err, request.Model, request.Stream, len(request.Messages))
	}
	var blocks []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	}
	if err := json.Unmarshal(request.Messages[len(request.Messages)-1].Content, &blocks); err != nil || len(blocks) != 1 || blocks[0].Type != "text" || !strings.Contains(blocks[0].Text, "custom native route") {
		t.Fatalf("custom Anthropic message content was not block-form text: %s (err=%v)", request.Messages[len(request.Messages)-1].Content, err)
	}
}

const customOpenAIContractSSE = `data: {"choices":[{"delta":{"role":"assistant","content":"custom-openai-ok"},"finish_reason":null}]}

data: {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":7,"completion_tokens":8}}

data: [DONE]

`

// TestContractProvider_CustomOpenAICompatibleRoutesCompatWire is the other half of the custom
// dialect split: explicit openai-compatible must retain the generic Bearer/chat-completions wire,
// not inherit the native Anthropic branch merely because the key provider is named "custom".
func TestContractProvider_CustomOpenAICompatibleRoutesCompatWire(t *testing.T) {
	t.Parallel()
	var mu sync.Mutex
	var probeCount, messageCount int
	var probePath, messagePath, probeAuthorization, messageAuthorization, probeKey, messageKey string
	var messageBody []byte
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		switch {
		case r.Method == http.MethodGet && r.URL.Path == "/models":
			probeCount++
			probePath, probeAuthorization, probeKey = r.URL.Path, r.Header.Get("Authorization"), r.Header.Get("x-api-key")
			w.Header().Set("Content-Type", "application/json")
			_, _ = io.WriteString(w, `{"data":[{"id":"custom-gpt","object":"model","owned_by":"custom"}]}`)
		case r.Method == http.MethodPost && r.URL.Path == "/chat/completions":
			messageCount++
			messagePath, messageAuthorization, messageKey = r.URL.Path, r.Header.Get("Authorization"), r.Header.Get("x-api-key")
			messageBody, _ = io.ReadAll(r.Body)
			w.Header().Set("Content-Type", "text/event-stream")
			_, _ = io.WriteString(w, customOpenAIContractSSE)
		default:
			http.NotFound(w, r)
		}
	}))
	defer upstream.Close()

	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "custom-openai-contract"}).Field(t, "id")
	wc := c.WS(wsID)

	const fakeKey = "custom-openai-contract-key"
	var keyRow struct {
		ID        string `json:"id"`
		APIFormat string `json:"apiFormat"`
	}
	wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "custom", "displayName": "custom-openai-contract", "key": fakeKey,
		"baseUrl": upstream.URL, "apiFormat": "openai-compatible",
	}).OK(t, &keyRow)
	if keyRow.ID == "" || keyRow.APIFormat != "openai-compatible" {
		t.Fatalf("custom OpenAI key must preserve APIFormat on the product surface: %+v", keyRow)
	}
	wc.POST("/api/v1/api-keys/"+keyRow.ID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Knobs    []struct {
			Key string `json:"key"`
		} `json:"knobs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	found := false
	for _, cap := range caps {
		if cap.APIKeyID == keyRow.ID && cap.Provider == "custom" && cap.ModelID == "custom-gpt" {
			found = true
			if len(cap.Knobs) != 0 {
				t.Fatalf("custom OpenAI endpoint must not fabricate knobs: %+v", cap.Knobs)
			}
		}
	}
	if !found {
		t.Fatalf("custom OpenAI model id missing from capabilities: %+v", caps)
	}

	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyRow.ID, "modelId": "custom-gpt"}).OK(t, nil)
	convID := convCreate(t, wc, "custom OpenAI compat wire")
	msgID := sendMsg(t, wc, convID, "Prove the custom compat route.")
	turn := waitTurn(t, wc, convID, msgID, 30000)
	if turn.Status != "completed" {
		t.Fatalf("custom OpenAI-compatible turn must complete, got status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if text, ok := blockOfType(turn, "text"); !ok || text != "custom-openai-ok" {
		t.Fatalf("custom compat SSE text missing: %+v", turn.Blocks)
	}
	// The OpenAI wire says finish_reason=stop; the product's durable message contract normalizes
	// every successful text turn to stopReason=end_turn (the provider-specific spelling is not
	// exposed through the chat history API).
	if turn.StopReason != "end_turn" || turn.InputTokens != 7 || turn.OutputTokens != 8 {
		t.Fatalf("custom compat SSE usage/finish missing: stop=%q input=%d output=%d", turn.StopReason, turn.InputTokens, turn.OutputTokens)
	}

	mu.Lock()
	gotProbeCount, gotMessageCount := probeCount, messageCount
	gotProbePath, gotMessagePath := probePath, messagePath
	gotProbeAuthorization, gotMessageAuthorization := probeAuthorization, messageAuthorization
	gotProbeKey, gotMessageKey := probeKey, messageKey
	body := append([]byte(nil), messageBody...)
	mu.Unlock()
	if gotProbeCount != 1 || gotMessageCount != 1 || gotProbePath != "/models" || gotMessagePath != "/chat/completions" || gotProbeAuthorization != "Bearer "+fakeKey || gotMessageAuthorization != "Bearer "+fakeKey || gotProbeKey != "" || gotMessageKey != "" {
		t.Fatalf("custom openai-compatible wire drifted: probe=%d/%s message=%d/%s bearer=%v/%v x-api-key=%v/%v", gotProbeCount, gotProbePath, gotMessageCount, gotMessagePath, gotProbeAuthorization == "Bearer "+fakeKey, gotMessageAuthorization == "Bearer "+fakeKey, gotProbeKey != "", gotMessageKey != "")
	}
	var request struct {
		Model         string `json:"model"`
		Stream        bool   `json:"stream"`
		StreamOptions struct {
			IncludeUsage bool `json:"include_usage"`
		} `json:"stream_options"`
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
	}
	if err := json.Unmarshal(body, &request); err != nil || request.Model != "custom-gpt" || !request.Stream || !request.StreamOptions.IncludeUsage || len(request.Messages) == 0 {
		t.Fatalf("custom OpenAI request body did not use compat shape: err=%v model=%q stream=%v usage=%v messages=%d", err, request.Model, request.Stream, request.StreamOptions.IncludeUsage, len(request.Messages))
	}
	if request.Messages[len(request.Messages)-1].Role != "user" || !strings.Contains(request.Messages[len(request.Messages)-1].Content, "custom compat route") {
		t.Fatalf("custom OpenAI user message missing: %+v", request.Messages)
	}
}
