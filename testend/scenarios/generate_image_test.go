// generate_image_test.go — WRK-082 批B black-box: the generation tool over the REAL binary.
// Two batteries: (1) honest absence — a workspace whose only key has no image capability never
// even SEES generate_image in its tools list; (2) end-to-end — an image-capable key makes the
// tool appear, the mocked upstream returns a real PNG, the artifact lands as a first-class
// attachment whose bytes round-trip, and the LLM's second turn sees the receipt.
//
// generate_image 黑盒(批B):真二进制上跑生成工具。两电池:①诚实缺席——唯一 key 无图像能力的
// workspace 连 tools 列表都见不到 generate_image;②端到端——图像家 key 让工具出现,mock 上游返
// 真 PNG,产物落一等附件且字节往返一致,第二轮 LLM 看到 receipt。
package scenarios

import (
	"bytes"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestGenerateImage_HonestAbsence: deepseek (text-only per the generation catalog) is the ONLY
// key — the tool must not exist for the model. The tools list on the wire is the proof.
func TestGenerateImage_HonestAbsence(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "img-absent-ws"}).OK(t, nil)
	wsID := ws.Field(t, "id")
	wc := c.WS(wsID)

	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "deepseek", "displayName": "llmmock-ds", "key": "sk-mock", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": dlgModel}).OK(t, nil)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "plain answer"})
	convID := convCreate(t, wc, "no-image-route")
	mid := sendMsg(t, wc, convID, "draw me a cat")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, name := range mock.DumpsFor(dlgModel)[0].Tools {
		if name == "generate_image" {
			t.Fatalf("generate_image offered to a workspace with no image-capable key — honest absence violated")
		}
	}
}

// TestGenerateImage_EndToEnd: the whole 批B chain on the real binary — injection, execution
// against the mocked OpenAI images wire, first-class attachment persistence with byte-exact
// round-trip, the receipt in the tool_result block, and the receipt in the model's next view.
func TestGenerateImage_EndToEnd(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false) // openai key + llmmock → image-capable route 图像家路由

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "generate_image",
			Args: map[string]any{"prompt": "a lighthouse at dusk", "aspect": "square"}}}},
		harness.LLMTurn{Text: "画好了,请看。"},
	)
	convID := convCreate(t, wc, "draw")
	mid := sendMsg(t, wc, convID, "画一座黄昏的灯塔")
	turn := waitTurn(t, wc, convID, mid, 60000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	dumps := mock.DumpsFor(dlgModel)
	// ① Injection: the tool was offered on the first request. 注入:首请求即 offer。
	offered := false
	for _, name := range dumps[0].Tools {
		if name == "generate_image" {
			offered = true
		}
	}
	if !offered {
		t.Fatalf("generate_image absent from tools despite an image-capable key: %v", dumps[0].Tools)
	}
	// ② The mocked upstream really got the prompt. mock 上游真收到 prompt。
	if prompts := mock.ImagePrompts(); len(prompts) != 1 || prompts[0] != "a lighthouse at dusk" {
		t.Fatalf("image upstream prompts = %v", prompts)
	}
	// ③ The tool_result block carries the receipt with the attachment id. tool_result 带 receipt。
	var receiptJSON string
	for _, b := range turn.Blocks {
		if b.Type == "tool_result" && strings.Contains(b.Content, `"source":"generate_image"`) {
			receiptJSON = b.Content
		}
	}
	if receiptJSON == "" {
		t.Fatalf("no generate_image receipt in blocks: %+v", turn.Blocks)
	}
	attID := extractField(t, receiptJSON, "attachmentId")
	if !strings.HasPrefix(attID, "att_") {
		t.Fatalf("receipt attachmentId = %q", attID)
	}
	// ④ The artifact is a FIRST-CLASS attachment whose bytes round-trip exactly. 一等附件字节往返。
	// DoRaw: /content is an N1-exempt raw-bytes endpoint — the enveloped GET would fatal on it.
	// DoRaw:/content 是 N1 豁免的裸字节端点——走 envelope 的 GET 会在它上 fatal。
	contentResp := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if contentResp.Status != 200 {
		t.Fatalf("attachment content: HTTP %d", contentResp.Status)
	}
	got := contentResp.Raw
	if !bytes.Equal(got, harness.MockPNG) {
		t.Fatalf("stored artifact bytes differ: got %d bytes, want the mock PNG (%d)", len(got), len(harness.MockPNG))
	}
	// ⑤ The model's SECOND view contains the receipt (the LLM can reference the artifact). 第二请求见 receipt。
	if len(dumps) < 2 || !dumps[1].HasMessage("tool", attID) {
		t.Fatalf("second model view lacks the receipt: dumps=%d", len(dumps))
	}
}

// extractField pulls a string field from a flat JSON object without a full decode dance.
//
// extractField 从扁平 JSON 里取一个字符串字段(免整套解码舞步)。
func extractField(t *testing.T, jsonStr, field string) string {
	t.Helper()
	marker := `"` + field + `":"`
	i := strings.Index(jsonStr, marker)
	if i < 0 {
		t.Fatalf("field %q absent in %s", field, jsonStr)
	}
	rest := jsonStr[i+len(marker):]
	j := strings.IndexByte(rest, '"')
	if j < 0 {
		t.Fatalf("field %q unterminated", field)
	}
	return rest[:j]
}
