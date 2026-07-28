// speech_test.go — WRK-082 批C 黑盒:出语音的两条路,在真二进制上。
//
// ①`generate_speech` 工具:诚实缺席(无能说话的 key 连 tools 列表都没有它)与端到端(合成 → 一等
// 附件字节往返 → receipt 进模型下一轮视野)。②**朗读**:零 token(整场不产生任何 chat 请求)+
// **缓存命中零上游花费**——后者是本批唯一真正会花钱的行为,故它的断言不是「返回了正确字节」而是
// **上游被调用了几次**:一个照样付钱的缓存能通过任何关于音频的断言,却输掉全部意义。
package scenarios

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestSpeech_HonestAbsence: deepseek (text-only) is the ONLY key — neither the tool nor the
// read-aloud affordance may claim to exist.
func TestSpeech_HonestAbsence(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "tts-absent-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "deepseek", "displayName": "llmmock-ds", "key": "sk-mock", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": dlgModel}).OK(t, nil)

	// The read-aloud availability probe says no — the button must not exist on the client.
	var avail struct {
		Available bool `json:"available"`
	}
	wc.GET("/api/v1/read-aloud/availability").OK(t, &avail)
	if avail.Available {
		t.Fatal("read-aloud reports itself available with no speech-capable key")
	}

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "plain answer"})
	convID := convCreate(t, wc, "no-speech-route")
	mid := sendMsg(t, wc, convID, "say something")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, name := range mock.DumpsFor(dlgModel)[0].Tools {
		if name == "generate_speech" {
			t.Fatal("generate_speech offered to a workspace with no speech-capable key — honest absence violated")
		}
	}
}

// TestSpeech_GenerateEndToEnd: the whole 批C tool chain on the real binary — injection, the
// OpenAI-form upstream really receiving the text, a first-class audio attachment whose bytes
// round-trip exactly, and the receipt in the model's next view.
func TestSpeech_GenerateEndToEnd(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetupManaged(t)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "generate_speech",
			Args: fw(map[string]any{"text": "海内存知己"})}}},
		harness.LLMTurn{Text: "念好了。"},
	)
	convID := convCreate(t, wc, "speak")
	mid := sendMsg(t, wc, convID, "把这句念出来")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	dumps := mock.DumpsFor(dlgModel)
	offered := false
	for _, name := range dumps[0].Tools {
		if name == "generate_speech" {
			offered = true
		}
	}
	if !offered {
		t.Fatalf("generate_speech absent despite a speech-capable key: %v", dumps[0].Tools)
	}
	if inputs := mock.SpeechInputs(); len(inputs) != 1 || inputs[0] != "海内存知己" {
		t.Fatalf("tts upstream inputs = %v", inputs)
	}

	var receiptJSON string
	for _, b := range turn.Blocks {
		if b.Type == "tool_result" && strings.Contains(b.Content, `"source":"generate_speech"`) {
			receiptJSON = b.Content
		}
	}
	if receiptJSON == "" {
		t.Fatalf("no generate_speech receipt in blocks: %+v", turn.Blocks)
	}
	attID := extractField(t, receiptJSON, "attachmentId")
	if !strings.HasPrefix(attID, "att_") {
		t.Fatalf("receipt attachmentId = %q", attID)
	}
	// The artifact is a FIRST-CLASS attachment whose bytes round-trip exactly.
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, harness.MockWAV) {
		t.Fatalf("stored audio differs: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	if len(dumps) < 2 || !dumps[1].HasMessage("tool", attID) {
		t.Fatalf("second model view lacks the receipt: dumps=%d", len(dumps))
	}
}

// TestReadAloud_SecondListenCostsNothing is the batch's money assertion, on the wire.
//
// The first press synthesizes; the second press of the SAME text must not reach the upstream at
// all. Counting `SpeechInputs()` is the only way to see that: the response bodies are identical
// either way, so a cache that quietly paid twice would satisfy every assertion about the audio.
// The scenario also proves read-aloud spends no tokens — the chat model is never called.
//
// 本批的钱断言,在线缆上。第一次按下合成;**同一段文字**的第二次按下必须完全不碰上游。数
// `SpeechInputs()` 是唯一能看见这件事的方式:两种情形响应体一模一样,故一个悄悄付了两次钱的缓存
// 能满足关于音频的每一条断言。本场景同时证明朗读**不花 token**——chat 模型一次都没被调用。
func TestReadAloud_SecondListenCostsNothing(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetupManaged(t)

	var avail struct {
		Available bool `json:"available"`
	}
	wc.GET("/api/v1/read-aloud/availability").OK(t, &avail)
	if !avail.Available {
		t.Fatal("a speech-capable key exists, yet read-aloud reports itself unavailable")
	}

	type readResp struct {
		AttachmentID string `json:"attachmentId"`
		MimeType     string `json:"mimeType"`
		SizeBytes    int64  `json:"sizeBytes"`
		Cached       bool   `json:"cached"`
	}
	read := func(text string) readResp {
		t.Helper()
		var out readResp
		wc.POST("/api/v1/read-aloud:read", map[string]any{"text": text}).OK(t, &out)
		return out
	}

	first := read("落霞与孤鹜齐飞")
	if first.Cached || first.AttachmentID == "" {
		t.Fatalf("first read = %+v, want a fresh synthesis with an artifact", first)
	}
	if got := len(mock.SpeechInputs()); got != 1 {
		t.Fatalf("upstream calls after the first read = %d, want 1", got)
	}

	second := read("落霞与孤鹜齐飞")
	if !second.Cached {
		t.Fatal("the second identical read must report itself cached")
	}
	if second.AttachmentID != first.AttachmentID {
		t.Fatalf("a repeat listen minted a second artifact (%s vs %s)", second.AttachmentID, first.AttachmentID)
	}
	if got := len(mock.SpeechInputs()); got != 1 {
		t.Fatalf("upstream calls after a REPEAT listen = %d, want still 1 — the cache did not prevent the spend", got)
	}

	// Different text is a different artifact and DOES pay. 不同文本是另一件产物,该付就付。
	other := read("秋水共长天一色")
	if other.Cached || other.AttachmentID == first.AttachmentID {
		t.Fatalf("different text served the cached artifact: %+v", other)
	}
	if got := len(mock.SpeechInputs()); got != 2 {
		t.Fatalf("upstream calls after new text = %d, want 2", got)
	}

	// Zero tokens: read-aloud never touches the chat model.
	if dumps := mock.DumpsFor(dlgModel); len(dumps) != 0 {
		t.Fatalf("read-aloud made %d chat requests — it must cost no tokens at all", len(dumps))
	}

	// The artifact is playable audio whose bytes round-trip.
	content := wc.DoRaw("GET", "/api/v1/attachments/"+first.AttachmentID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, harness.MockWAV) {
		t.Fatalf("read-aloud artifact differs: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestReadAloud_ClosedShapeRejections: empty and oversized text die before any spend.
func TestReadAloud_ClosedShapeRejections(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	wc.POST("/api/v1/read-aloud:read", map[string]any{"text": "   "}).
		Fail(t, 400, "READALOUD_TEXT_REQUIRED")

	long, _ := json.Marshal(strings.Repeat("字", 4001))
	wc.POST("/api/v1/read-aloud:read", map[string]any{"text": json.RawMessage(long)}).
		Fail(t, 400, "READALOUD_TEXT_TOO_LONG")

	if got := len(mock.SpeechInputs()); got != 0 {
		t.Fatalf("upstream called %d times for input that never should have left the door", got)
	}
}
