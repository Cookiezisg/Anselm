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

// TestGenerateImage_OfferedAndReachesTheUpstream covers the half a MOCK can honestly prove, and it
// stops exactly where a mock stops being evidence.
//
// **Why it no longer asserts the artifact.** Generation is managed-only (H11), and the managed image
// contract hands back an **https URL** that the desktop then fetches — the gateway never returns
// bytes (its handler has one field, `url`). A plain-http mock therefore cannot stand in: teaching
// the desktop to also accept `b64_json` would be inventing a contract no gateway speaks, which is
// the precise mistake this campaign has paid for twice this week. The artifact half — receipt,
// first-class attachment, byte round-trip, the model really seeing pixels — is asserted for real
// money in `live_media_test.go`.
//
// TestGenerateImage_OfferedAndReachesTheUpstream 覆盖**假件能诚实证明**的那一半,并在假件不再算证据的
// 地方**恰好停住**。
//
// **它为什么不再断言产物。** 生成只在受管档(H11),而受管图像契约交回的是一个 **https URL**、由桌面随后
// 去取——网关**从不**返回字节(它的 handler 只有 `url` 一个字段)。故一个纯 http 的假件顶替不了:教桌面
// 端「也收 b64_json」等于发明一个**没有任何网关会说**的契约,而那正是本战役这一周付过两次学费的错误。
// 产物那一半——receipt、一等附件、字节往返、模型**真的看见**像素——在 `live_media_test.go` 里用真钱断言。
func TestGenerateImage_OfferedAndReachesTheUpstream(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetupManaged(t)

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
	// ① Injection: the tool is offered BECAUSE a managed install exists — the H11 law, and the one
	//    thing about availability a mock can prove. 注入:工具之所以被 offer,是因为**有受管 install**
	//    ——H11 的律,也是关于可用性、假件唯一证得了的事。
	offered := false
	for _, name := range dumps[0].Tools {
		if name == "generate_image" {
			offered = true
		}
	}
	if !offered {
		t.Fatalf("generate_image absent despite a managed install: %v", dumps[0].Tools)
	}
	// ② The call really left the desktop and arrived at the managed image route with the prompt
	//    intact. 调用真的离开了桌面、带着完好的 prompt 抵达受管图像路由。
	if prompts := mock.ImagePrompts(); len(prompts) != 1 || prompts[0] != "a lighthouse at dusk" {
		t.Fatalf("image upstream prompts = %v", prompts)
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
