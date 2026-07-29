// live_managed_test.go — the product-level real-money acceptance for the managed default path.
//
// Unlike infra/llm's gateway-client acceptance, this file starts the real Anselm backend, creates
// a workspace, waits for its asynchronous managed install, and drives the normal conversation API.
// It therefore proves the product seam: provision → default model → chat loop → durable turn.
//
// It deliberately needs no provider secret. The user-facing backend has only the deployed Anselm
// API Serve; provider credentials and routing remain on that service.
package scenarios

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

const liveManagedGateway = "https://api.anselm.website/v1"

// liveManagedPNG is a decoder-valid 32×32 RGB PNG. A 1×1 fixture is below real visual providers'
// useful-size floor, so it is unsuitable for a production multimodal acceptance.
var liveManagedPNG = func() []byte {
	b, err := base64.StdEncoding.DecodeString("iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKUlEQVR4nO3NMQ0AAAgDsEmZf5OggoOkSf9m2lMRCAQCgUAgEAgEX4IFDbP8PQv8HGkAAAAASUVORK5CYII=")
	if err != nil {
		panic(err)
	}
	return b
}()

// liveManagedAnimationPNG is deliberately larger than the ordinary vision fixture. Video
// providers commonly impose a minimum first-frame geometry even when their chat vision route
// accepts tiny images; 512×512 keeps this writer acceptance inside that envelope.
var liveManagedAnimationPNG = func() []byte {
	img := image.NewRGBA(image.Rect(0, 0, 512, 512))
	for y := 0; y < 512; y++ {
		for x := 0; x < 512; x++ {
			img.SetRGBA(x, y, color.RGBA{R: uint8(40 + x/4), G: uint8(90 + y/4), B: 180, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		panic(err)
	}
	return buf.Bytes()
}()

func liveManagedWorkspace(t *testing.T, name string) *harness.Client {
	t.Helper()
	if os.Getenv("EVALS_MANAGED") != "1" {
		t.Skip("set EVALS_MANAGED=1 to run the real-money managed product acceptance")
	}

	srv := harness.Start(t, "ANSELM_GATEWAY_URL="+liveManagedGateway)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": name}).Field(t, "id")
	wc := c.WS(wsID)

	// A workspace creation intentionally provisions in the background. Do not let a missing managed
	// row turn this into an accidental "honest absence" pass: this scenario accepts the successful
	// product path, not the offline fallback.
	harness.Eventually(t, 30000, "the managed free-tier key lands", func() bool {
		var keys []struct {
			Provider string `json:"provider"`
		}
		wc.GET("/api/v1/api-keys").OK(t, &keys)
		for _, key := range keys {
			if key.Provider == "anselm" {
				return true
			}
		}
		return false
	})

	// The key becoming visible is the user's first observable sign that onboarding is ready. The
	// dialogue default must already be present at that exact boundary: waiting for it here would
	// hide a window where the first send fails with LLM_RESOLVE_ERROR.
	var ws struct {
		DefaultDialogue *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultDialogue"`
	}
	wc.GET("/api/v1/workspaces/"+wsID).OK(t, &ws)
	if ws.DefaultDialogue == nil || ws.DefaultDialogue.APIKeyID == "" || ws.DefaultDialogue.ModelID == "" {
		t.Fatalf("managed key became visible before the dialogue default was ready: %+v", ws)
	}
	return wc
}

func TestLiveManaged_DefaultChat(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-default-chat")
	conv := convCreate(t, wc, "managed default")
	msg := sendMsg(t, wc, conv, "请用一句简洁的中文向我问好。不要调用工具。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed default chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, block := range turn.Blocks {
		if block.Type == "text" && block.Content != "" {
			return
		}
	}
	t.Fatalf("managed default chat completed without an assistant text block: %+v", turn.Blocks)
}

// TestLiveManaged_GenerateImageArtifact is the smallest managed-write acceptance: the default
// Anselm dialogue model must discover and call generate_image once, the managed gateway must return
// a decoder-valid image, and the tool receipt must land as a first-class attachment owned by Anselm.
// The two-step cap prevents a model-side redraw loop from turning this probe into unbounded spend.
func TestLiveManaged_GenerateImageArtifact(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-image-generation")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	conv := convCreate(t, wc, "managed image generation")
	msg := sendMsg(t, wc, conv,
		"请调用 generate_image 恰好一次，画一个白底红色圆形。工具成功后只用一句简短中文确认，绝不再次调用生成工具。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed image-generation turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	attID := attachmentFrom(t, turn, "generate_image")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) || len(content.Raw) < 1000 {
		t.Fatalf("managed image-generation artifact must be a real image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	count := 0
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_image"`) {
			count++
			if !strings.Contains(block.Content, `"provider":"anselm"`) {
				t.Fatalf("managed image-generation receipt must name anselm: %s", block.Content)
			}
		}
	}
	if count != 1 {
		t.Fatalf("managed image-generation turn produced %d generate_image receipts, want exactly one", count)
	}
}

// TestLiveManaged_EditImageArtifact proves the managed X→X path: the model must first create an
// image, pass that attachment id to edit_image, and receive a distinct sibling artifact. Four steps
// permit generate → edit → confirmation while bounding accidental redraws.
func TestLiveManaged_EditImageArtifact(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-image-edit")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	conv := convCreate(t, wc, "managed image edit")
	msg := sendMsg(t, wc, conv,
		"先调用 generate_image 恰好一次，画一个白底红色圆形；然后必须把刚生成的 attachmentId 传给 edit_image 恰好一次，把它改成蓝色圆形。两次工具都成功后只用一句简短中文确认，不要再次调用生成工具。")
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed image-edit turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	var generatedID, editedID string
	generateCount, editCount := 0, 0
	for _, block := range turn.Blocks {
		if block.Type != "tool_result" {
			continue
		}
		switch {
		case strings.Contains(block.Content, `"source":"generate_image"`):
			generateCount++
			if !strings.Contains(block.Content, `"provider":"anselm"`) {
				t.Fatalf("managed generate receipt must name anselm: %s", block.Content)
			}
			if generatedID == "" {
				generatedID = attIDShape.FindString(block.Content)
			}
		case strings.Contains(block.Content, `"source":"edit_image"`):
			editCount++
			if !strings.Contains(block.Content, `"provider":"anselm"`) {
				t.Fatalf("managed edit receipt must name anselm: %s", block.Content)
			}
			if editedID == "" {
				editedID = attIDShape.FindString(block.Content)
			}
			if generatedID != "" && !strings.Contains(block.Content, `"sourceAttachmentId":"`+generatedID+`"`) {
				t.Fatalf("managed edit receipt must point to generated source %s: %s", generatedID, block.Content)
			}
		}
	}
	if generateCount != 1 || editCount != 1 || generatedID == "" || editedID == "" {
		t.Fatalf("managed edit must produce one generate and one edit receipt: generate=%d edit=%d genID=%q editID=%q", generateCount, editCount, generatedID, editedID)
	}
	if generatedID == editedID {
		t.Fatalf("managed edit must create a sibling attachment, got the same id %q", generatedID)
	}
	generated := wc.DoRaw("GET", "/api/v1/attachments/"+generatedID+"/content", "", nil)
	edited := wc.DoRaw("GET", "/api/v1/attachments/"+editedID+"/content", "", nil)
	if generated.Status != 200 || !bytes2IsImage(generated.Raw) || edited.Status != 200 || !bytes2IsImage(edited.Raw) {
		t.Fatalf("managed edit artifacts must both be real images: source HTTP %d/%d bytes, edited HTTP %d/%d bytes", generated.Status, len(generated.Raw), edited.Status, len(edited.Raw))
	}
	if bytes.Equal(generated.Raw, edited.Raw) {
		t.Fatal("managed edit returned byte-identical source; edit input was ignored")
	}
}

// TestLiveManaged_WorkflowGenerateImageToViewer reprobes the managed workflow value path after
// the generation route changes: an upstream agent generates one image, hands its MediaRef receipt
// through the node result, and a separate downstream agent completes against that input.
func TestLiveManaged_WorkflowGenerateImageToViewer(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-workflow-image")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	var ws struct {
		DefaultAgent *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultAgent"`
	}
	wc.GET("/api/v1/workspaces/"+wc.WorkspaceID()).OK(t, &ws)
	if ws.DefaultAgent == nil || ws.DefaultAgent.APIKeyID == "" || ws.DefaultAgent.ModelID == "" {
		t.Fatalf("managed workflow probe requires a ready default agent model: %+v", ws.DefaultAgent)
	}

	painter := agCreate(t, wc, map[string]any{
		"name": "Managed Workflow Painter", "description": "generates one image and hands its receipt on",
		"prompt": "请调用 generate_image 恰好一次，画一个白底红色圆形；工具成功后把工具 receipt 原样写进最终回答，不要再次调用工具。",
		"tools":  []map[string]any{{"ref": "sys:generate_image", "name": "generate image"}},
	})
	viewer := agCreate(t, wc, map[string]any{
		"name": "Managed Workflow Viewer", "description": "receives the upstream image receipt",
		"prompt": "请用一句简短中文确认你已收到上游产物。不要调用工具。",
	})
	wfID := wfCreate(t, wc, "managed_image_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "paint", "kind": "agent", "ref": painter,
			"input": map[string]any{"task": "start.topic"}}},
		{"op": "add_node", "node": map[string]any{"id": "look", "kind": "agent", "ref": viewer,
			"input": map[string]any{"picture": "paint.text"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "paint"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "paint", "to": "look"}},
	})
	_, status, nodes := runAndWait(t, wc, wfID, map[string]any{"topic": "a red circle on white"}, 360000)
	if status != "completed" {
		t.Fatalf("managed image workflow must complete, got %s nodes=%s", status, nodes)
	}
	attID := attIDShape.FindString(string(nodes))
	if attID == "" {
		t.Fatalf("managed workflow node result must carry an image MediaRef: %s", nodes)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) || len(content.Raw) < 1000 {
		t.Fatalf("managed workflow artifact must be a real image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	nodeText := string(nodes)
	if !strings.Contains(nodeText, "generate_image") || !strings.Contains(nodeText, "provider") || !strings.Contains(nodeText, "anselm") {
		t.Fatalf("managed workflow node result must preserve the managed generation receipt: %s", nodes)
	}
}

// TestLiveManaged_SubagentGenerateImageArtifact covers the subagent-specific multimodal seam:
// capability tools and the tool-result media expander must survive the depth-1 delegated run, and
// the parent must receive the child's managed receipt without paying for a redraw.
func TestLiveManaged_SubagentGenerateImageArtifact(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-image")
	// Parent steps are: delegate → receive the subagent result → final confirmation. The child has
	// its own loop budget; capping the parent at two stops before it can acknowledge the result.
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	conv := convCreate(t, wc, "managed subagent image")
	msg := sendMsg(t, wc, conv,
		"请派一个 general-purpose subagent。子任务必须调用 generate_image 恰好一次，画一个白底红色圆形；工具成功后把 receipt 原样交回，不要再次调用生成工具。父回合收到后只用一句简短中文确认。")
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed subagent image turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	count := 0
	var attID string
	for _, block := range turn.Blocks {
		if block.Type != "tool_result" || !strings.Contains(block.Content, `"source":"generate_image"`) {
			continue
		}
		count++
		if !strings.Contains(block.Content, `"provider":"anselm"`) {
			t.Fatalf("subagent generation receipt must name anselm: %s", block.Content)
		}
		if attID == "" {
			attID = attIDShape.FindString(block.Content)
		}
	}
	if count != 1 || attID == "" {
		t.Fatalf("managed subagent must return exactly one image receipt: count=%d attID=%q blocks=%+v", count, attID, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) || len(content.Raw) < 1000 {
		t.Fatalf("managed subagent artifact must be a real image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_GenerateSpeechArtifact is the managed speech counterpart: the default Anselm
// dialogue model must call generate_speech once, the gateway's returned bytes must be a real WAV,
// and the tool receipt must identify the managed provider. The two-step cap bounds paid retries.
func TestLiveManaged_GenerateSpeechArtifact(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-speech-generation")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	conv := convCreate(t, wc, "managed speech generation")
	msg := sendMsg(t, wc, conv,
		"请调用 generate_speech 恰好一次，把‘海内存知己’读出来。工具成功后只用一句简短中文确认，绝不再次调用生成工具。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed speech-generation turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	attID := attachmentFrom(t, turn, "generate_speech")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsWAV(content.Raw) || len(content.Raw) < 4000 {
		t.Fatalf("managed speech-generation artifact must be real WAV audio: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	count := 0
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_speech"`) {
			count++
			if !strings.Contains(block.Content, `"provider":"anselm"`) {
				t.Fatalf("managed speech-generation receipt must name anselm: %s", block.Content)
			}
		}
	}
	if count != 1 {
		t.Fatalf("managed speech-generation turn produced %d generate_speech receipts, want exactly one", count)
	}
}

// TestLiveManaged_GenerateSpeechDeniedNoSpend proves the danger gate is a real money boundary:
// denying a managed TTS request must feed a refusal back into the same turn without reaching the
// gateway, minting an audio attachment, or consuming the speech quota.
func TestLiveManaged_GenerateSpeechDeniedNoSpend(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-speech-denied")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	var before struct {
		Limit     int64 `json:"limit"`
		Used      int64 `json:"used"`
		Remaining int64 `json:"remaining"`
		Available bool  `json:"available"`
	}
	wc.GET("/api/v1/freetier/quota").OK(t, &before)
	if !before.Available || before.Limit <= 0 || before.Used < 0 || before.Remaining < 0 || before.Used+before.Remaining > before.Limit {
		t.Fatalf("managed quota must be coherent before denial: %+v", before)
	}

	conv := convCreate(t, wc, "managed speech denied")
	msg := sendMsg(t, wc, conv,
		"请调用 generate_speech 恰好一次，把‘这次请求将被拒绝’读出来；先等待危险操作审批，不要自行批准。")
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 60000, "generate_speech asks for dangerous approval", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "generate_speech" {
		t.Fatalf("generate_speech must pause at its danger gate: %+v", pending[0])
	}
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "deny"}).OK(t, nil)
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("denied managed speech turn must complete without synthesis: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_speech"`) {
			t.Fatalf("denied generate_speech must not leave a tool receipt: %s", block.Content)
		}
	}
	var after struct {
		Limit     int64 `json:"limit"`
		Used      int64 `json:"used"`
		Remaining int64 `json:"remaining"`
		Available bool  `json:"available"`
	}
	wc.GET("/api/v1/freetier/quota").OK(t, &after)
	// The gateway's public monthly counter includes the two dialogue requests (tool proposal +
	// denial continuation), so it is not a speech-only ledger. A denied request must nevertheless
	// stay within that two-turn envelope; a TTS execution would add a third managed reservation.
	if after.Used-before.Used > 2 || after.Limit != before.Limit || after.Remaining != before.Remaining-(after.Used-before.Used) || !after.Available {
		t.Fatalf("denied speech must not add a managed synthesis reservation: before=%+v after=%+v", before, after)
	}
}

// TestLiveManaged_GenerateVideoDeniedNoSpend applies the same cost boundary to the asynchronous
// video writer: the danger gate must happen before the gateway job is submitted, not merely before
// the eventual MP4 is downloaded.
func TestLiveManaged_GenerateVideoDeniedNoSpend(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-video-denied")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	var before struct {
		Limit     int64 `json:"limit"`
		Used      int64 `json:"used"`
		Remaining int64 `json:"remaining"`
		Available bool  `json:"available"`
	}
	wc.GET("/api/v1/freetier/quota").OK(t, &before)
	if !before.Available || before.Limit <= 0 || before.Used < 0 || before.Remaining < 0 || before.Used+before.Remaining > before.Limit {
		t.Fatalf("managed quota must be coherent before denial: %+v", before)
	}

	conv := convCreate(t, wc, "managed video denied")
	msg := sendMsg(t, wc, conv,
		"请调用 generate_video 恰好一次，生成一段 5 秒横向视频：海边灯塔；先等待危险操作审批，不要自行批准。")
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 60000, "generate_video asks for dangerous approval", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "generate_video" {
		t.Fatalf("generate_video must pause at its danger gate: %+v", pending[0])
	}
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "deny"}).OK(t, nil)
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("denied managed video turn must complete without submission: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_video"`) {
			t.Fatalf("denied generate_video must not leave a tool receipt: %s", block.Content)
		}
	}
	var after struct {
		Limit     int64 `json:"limit"`
		Used      int64 `json:"used"`
		Remaining int64 `json:"remaining"`
		Available bool  `json:"available"`
	}
	wc.GET("/api/v1/freetier/quota").OK(t, &after)
	delta := after.Used - before.Used
	if delta > 2 || after.Limit != before.Limit || after.Remaining != before.Remaining-delta || !after.Available {
		t.Fatalf("denied video must not add a managed generation reservation: before=%+v after=%+v", before, after)
	}
}

// TestLiveManaged_GenerateVideoCancelAfterSubmitLeavesNoOrphan covers the opposite side of the
// danger boundary: once the user approves and the gateway has accepted the paid async job, a
// conversation cancel must stop the local wait without fabricating a video attachment or receipt.
// The gateway intentionally keeps the upstream job alive after client cancellation (submission is
// the billing point), so this is an honest "paid but no local artifact" recovery state, not a claim
// that cancellation refunds an already-submitted provider job.
func TestLiveManaged_GenerateVideoCancelAfterSubmitLeavesNoOrphan(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-video-cancel-after-submit")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	conv := convCreate(t, wc, "managed video cancel after submit")
	sse := wc.Subscribe(t, "messages")
	msg := sendMsg(t, wc, conv,
		"请调用 generate_video 恰好一次，生成一段 5 秒横向视频：雨夜街道；先等待危险操作审批。批准后开始生成，我会立刻取消等待。")
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 60000, "generate_video asks for dangerous approval", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "generate_video" {
		t.Fatalf("generate_video must pause at its danger gate: %+v", pending[0])
	}
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "approve"}).OK(t, nil)
	// This progress line is emitted only after POST /v1/videos/generations returns 202. It is the
	// product-side evidence that cancellation races with an already-paid gateway job, not the
	// cheaper no-submit path covered by TestLiveManaged_GenerateVideoDeniedNoSpend.
	sse.WaitFor(t, 60000, "managed video gateway submission", "submitted to anselm")
	wc.POST("/api/v1/conversations/"+conv+":cancel", nil).OK(t, nil)
	turn := waitTurn(t, wc, conv, msg, 120000)
	if turn.Status != "cancelled" {
		t.Fatalf("cancelled managed video turn must be terminal cancelled: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_video"`) {
			t.Fatalf("cancelled submitted video must not leave a local tool receipt: %s", block.Content)
		}
	}
	// Give a fast provider job time to finish on the gateway. The local cancellation must remain
	// terminal and must not later backfill an attachment after the conversation has ended.
	time.Sleep(3000 * time.Millisecond)
	for _, block := range waitTurn(t, wc, conv, msg, 1000).Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_video"`) {
			t.Fatalf("cancelled submitted video backfilled a late receipt: %s", block.Content)
		}
	}
}

// TestLiveManaged_ReadAloudCache is the managed read-aloud acceptance: the first press really
// synthesizes, the identical second press returns the same attachment from the local cache without
// consuming another gateway request, and a different text gets a fresh artifact. The gateway quota
// snapshot is the product-visible spend witness here; the old provider recorder remains archived
// because generation now belongs behind Anselm API Serve.
func TestLiveManaged_ReadAloudCache(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-read-aloud-cache")
	var avail struct {
		Available bool `json:"available"`
	}
	wc.GET("/api/v1/read-aloud/availability").OK(t, &avail)
	if !avail.Available {
		t.Fatal("managed speech route is available, yet read-aloud reports itself unavailable")
	}

	readQuota := func() struct {
		Limit     int64  `json:"limit"`
		Used      int64  `json:"used"`
		Remaining int64  `json:"remaining"`
		ResetAt   string `json:"resetAt"`
		Available bool   `json:"available"`
	} {
		t.Helper()
		var q struct {
			Limit     int64  `json:"limit"`
			Used      int64  `json:"used"`
			Remaining int64  `json:"remaining"`
			ResetAt   string `json:"resetAt"`
			Available bool   `json:"available"`
		}
		wc.GET("/api/v1/freetier/quota").OK(t, &q)
		if q.Limit <= 0 || q.Used < 0 || q.Remaining < 0 || q.Used+q.Remaining > q.Limit || !q.Available {
			t.Fatalf("managed quota must remain coherent and available: %+v", q)
		}
		if _, err := time.Parse(time.RFC3339, q.ResetAt); err != nil {
			t.Fatalf("managed quota resetAt must be RFC3339: %q (%v)", q.ResetAt, err)
		}
		return q
	}

	before := readQuota()
	first := liveRead(t, wc, "落霞与孤鹜齐飞,秋水共长天一色。", "")
	if first.Cached || first.AttachmentID == "" || first.SizeBytes < 4000 {
		t.Fatalf("first managed read must synthesize real audio: %+v", first)
	}
	afterFirst := readQuota()
	if afterFirst.Used <= before.Used {
		t.Fatalf("first synthesis must consume one gateway request: before=%+v after=%+v", before, afterFirst)
	}

	again := liveRead(t, wc, "落霞与孤鹜齐飞,秋水共长天一色。", "")
	if !again.Cached || again.AttachmentID != first.AttachmentID {
		t.Fatalf("identical managed read must reuse its cached artifact: first=%+v again=%+v", first, again)
	}
	afterHit := readQuota()
	if afterHit.Used != afterFirst.Used {
		t.Fatalf("cached managed read must not consume another gateway request: afterFirst=%+v afterHit=%+v", afterFirst, afterHit)
	}

	other := liveRead(t, wc, "孤帆远影碧空尽,唯见长江天际流。", "")
	if other.Cached || other.AttachmentID == "" || other.AttachmentID == first.AttachmentID {
		t.Fatalf("different managed text must produce a fresh artifact: first=%+v other=%+v", first, other)
	}
	if content := wc.DoRaw("GET", "/api/v1/attachments/"+first.AttachmentID+"/content", "", nil); content.Status != 200 || !bytes2IsWAV(content.Raw) {
		t.Fatalf("cached managed audio must remain playable: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_ReadAloudConcurrentDedup covers the money boundary the sequential cache probe
// cannot see: two browser presses can arrive before either request has written the cache row. The
// product must serialize that miss per workspace/key, so one request synthesizes and the other
// observes the same attachment; a unique DB index alone is too late because both upstream calls
// have already spent the user's managed allowance.
func TestLiveManaged_ReadAloudConcurrentDedup(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-read-aloud-concurrent-dedup")
	readQuota := func() int64 {
		t.Helper()
		var q struct {
			Used      int64 `json:"used"`
			Remaining int64 `json:"remaining"`
			Limit     int64 `json:"limit"`
			Available bool  `json:"available"`
		}
		wc.GET("/api/v1/freetier/quota").OK(t, &q)
		if !q.Available || q.Limit <= 0 || q.Used < 0 || q.Remaining < 0 || q.Used+q.Remaining > q.Limit {
			t.Fatalf("managed quota must remain coherent and available: %+v", q)
		}
		return q.Used
	}

	// Equal-length warm-up establishes the exact per-request character charge without populating
	// the target key. The warm-up is intentionally a different text so the concurrent pair is a
	// genuine miss rather than a sequential cache hit.
	warmText := "一二三四五六七八"
	targetText := "九十甲乙丙丁戊己"
	before := readQuota()
	warm := liveRead(t, wc, warmText, "")
	if warm.Cached || warm.AttachmentID == "" {
		t.Fatalf("warm-up read must synthesize a fresh artifact: %+v", warm)
	}
	afterWarm := readQuota()
	singleCost := afterWarm - before
	if singleCost <= 0 {
		t.Fatalf("warm-up synthesis must consume managed quota: before=%d after=%d", before, afterWarm)
	}

	type result struct {
		resp *harness.Resp
		err  error
	}
	start := make(chan struct{})
	results := make(chan result, 2)
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			resp, err := wc.Try("POST", "/api/v1/read-aloud:read", map[string]any{"text": targetText})
			results <- result{resp: resp, err: err}
		}()
	}
	close(start)
	wg.Wait()
	close(results)

	var outputs []struct {
		AttachmentID string `json:"attachmentId"`
		Cached       bool   `json:"cached"`
	}
	for got := range results {
		if got.err != nil {
			t.Fatalf("concurrent read-aloud request failed at transport: %v", got.err)
		}
		if got.resp.Status != 200 {
			t.Fatalf("concurrent read-aloud request must succeed: status=%d code=%s body=%s", got.resp.Status, got.resp.Code, got.resp.Raw)
		}
		var out struct {
			AttachmentID string `json:"attachmentId"`
			Cached       bool   `json:"cached"`
		}
		if err := json.Unmarshal(got.resp.Data, &out); err != nil {
			t.Fatalf("decode concurrent read-aloud response: %v", err)
		}
		if out.AttachmentID == "" {
			t.Fatalf("concurrent read-aloud response has no attachment: %+v", out)
		}
		outputs = append(outputs, out)
	}
	if len(outputs) != 2 || outputs[0].AttachmentID != outputs[1].AttachmentID {
		t.Fatalf("concurrent identical reads must share one attachment: %+v", outputs)
	}
	if outputs[0].Cached == outputs[1].Cached {
		t.Fatalf("one concurrent reader should synthesize and the other observe the cache: %+v", outputs)
	}
	afterConcurrent := readQuota()
	if afterConcurrent-afterWarm != singleCost {
		t.Fatalf("concurrent identical reads must spend once: singleCost=%d concurrentDelta=%d outputs=%+v", singleCost, afterConcurrent-afterWarm, outputs)
	}
}

// TestLiveManaged_GenerateVideoArtifact is the managed long-write acceptance: generate_video must
// stop at its dangerous-operation gate, resume after approval, walk the gateway's async route, and
// land one real MP4 attachment. A two-step cap permits only the tool call and final confirmation.
func TestLiveManaged_GenerateVideoArtifact(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-video-generation")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	conv := convCreate(t, wc, "managed video generation")
	msg := sendMsg(t, wc, conv,
		"请调用 generate_video 恰好一次，生成一段 5 秒横向视频：黄昏海边的红色灯塔，镜头缓慢向前推进。先等待危险操作审批，批准后不要再次调用生成工具，只用一句简短中文确认。")
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 60000, "generate_video asks for dangerous approval", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "generate_video" {
		t.Fatalf("generate_video must pause at its danger gate: %+v", pending[0])
	}
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "approve"}).OK(t, nil)
	turn := waitTurn(t, wc, conv, msg, 360000)
	if turn.Status != "completed" {
		t.Fatalf("managed video-generation turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	attID := attachmentFrom(t, turn, "generate_video")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsMP4(content.Raw) || len(content.Raw) < 10000 {
		t.Fatalf("managed video-generation artifact must be real MP4: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	count := 0
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_video"`) {
			count++
			if !strings.Contains(block.Content, `"provider":"anselm"`) {
				t.Fatalf("managed video-generation receipt must name anselm: %s", block.Content)
			}
		}
	}
	if count != 1 {
		t.Fatalf("managed video-generation turn produced %d generate_video receipts, want exactly one", count)
	}
}

// TestLiveManaged_AnimateImageArtifact is the managed image-to-video regression sentinel: an
// existing user attachment is supplied as the first frame while the model also receives the
// capability tools. The expected product seam is a dangerous-operation gate followed by one MP4
// receipt; a provider/gateway rejection before that gate must stay visible as a live failure rather
// than being mistaken for a successful text-only animation path.
func TestLiveManaged_AnimateImageArtifact(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-image-animation")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	sourceID := uploadAtt(t, wc, "first-frame.png", "image/png", liveManagedAnimationPNG)
	conv := convCreate(t, wc, "managed image animation")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       fmt.Sprintf("请调用 animate_image 恰好一次，把附件 %s 作为首帧生成一段 5 秒视频：镜头缓慢向前推进。先等待危险操作审批，批准后不要再次调用工具，只用一句简短中文确认。", sourceID),
		"attachmentIds": []string{sourceID},
	})
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 60000, "animate_image asks for dangerous approval", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "animate_image" {
		t.Fatalf("animate_image must pause at its danger gate: %+v", pending[0])
	}
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "approve"}).OK(t, nil)
	turn := waitTurn(t, wc, conv, msg, 360000)
	if turn.Status != "completed" {
		t.Fatalf("managed image-animation turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	outID := attachmentFrom(t, turn, "animate_image")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+outID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsMP4(content.Raw) || len(content.Raw) < 10000 {
		t.Fatalf("managed image-animation artifact must be real MP4: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	count := 0
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"animate_image"`) {
			count++
			if !strings.Contains(block.Content, `"provider":"anselm"`) ||
				!strings.Contains(block.Content, `"sourceAttachmentId":"`+sourceID+`"`) {
				t.Fatalf("managed image-animation receipt must name anselm and preserve its source: %s", block.Content)
			}
		}
	}
	if count != 1 {
		t.Fatalf("managed image-animation turn produced %d animate_image receipts, want exactly one", count)
	}
}

// TestLiveManaged_AnimateImageArtifactTextOnly isolates the managed animation writer from the
// image-plus-tools fusion sentinel above: the source is still a real uploaded image, but the
// model-facing turn carries only its attachment id in text. A pass here proves the API Serve
// async animation route and source lineage independently of the currently blocked multimodal
// tool-call request shape.
func TestLiveManaged_AnimateImageArtifactTextOnly(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-image-animation-text-only")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	sourceID := uploadAtt(t, wc, "first-frame.png", "image/png", liveManagedAnimationPNG)
	conv := convCreate(t, wc, "managed image animation text only")
	msg := sendMsg(t, wc, conv, fmt.Sprintf("请调用 animate_image 恰好一次，把附件 %s 作为首帧生成一段 5 秒视频：镜头缓慢向前推进。先等待危险操作审批，批准后不要再次调用工具，只用一句简短中文确认。", sourceID))
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 60000, "text-only animate_image asks for dangerous approval", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "animate_image" {
		t.Fatalf("text-only animate_image must pause at its danger gate: %+v", pending[0])
	}
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "approve"}).OK(t, nil)
	turn := waitTurn(t, wc, conv, msg, 360000)
	if turn.Status != "completed" {
		toolResultCount := 0
		for _, block := range turn.Blocks {
			if block.Type == "tool_result" {
				toolResultCount++
			}
		}
		t.Fatalf("text-only managed image-animation turn must complete: status=%s code=%s message=%s toolResultCount=%d", turn.Status, turn.ErrorCode, turn.ErrorMessage, toolResultCount)
	}
	outID := attachmentFrom(t, turn, "animate_image")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+outID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsMP4(content.Raw) || len(content.Raw) < 10000 {
		t.Fatalf("text-only managed image-animation artifact must be real MP4: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	count := 0
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"animate_image"`) {
			count++
			if !strings.Contains(block.Content, `"provider":"anselm"`) ||
				!strings.Contains(block.Content, `"sourceAttachmentId":"`+sourceID+`"`) {
				t.Fatalf("text-only managed image-animation receipt must name anselm and preserve its source: %s", block.Content)
			}
		}
	}
	if count != 1 {
		t.Fatalf("text-only managed image-animation turn produced %d animate_image receipts, want exactly one", count)
	}
}

// TestLiveManaged_DefaultChatWithImageAttachment exercises the product seam that cannot be reached
// by the gateway-client acceptance alone: user upload → attachment store → managed media staging /
// lease → the deployed gateway's multimodal route → durable chat turn. It deliberately asserts the
// published capability and transport outcome, not what the model claims to see.
func TestLiveManaged_DefaultChatWithImageAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-image-input")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	vision := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			vision = cap.Vision
			break
		}
	}
	if !vision {
		t.Fatalf("managed default must advertise image input before accepting an image attachment: %+v", caps)
	}

	attID := uploadAtt(t, wc, "managed-input.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed image input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请确认收到附件。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed image-input chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); got.Status != 200 || len(got.Raw) != len(liveManagedPNG) {
		t.Fatalf("uploaded image must survive the managed multimodal turn: HTTP %d, %d bytes", got.Status, len(got.Raw))
	}
}

// TestLiveManaged_DefaultChatWithAudioAttachmentDegrades covers the user-facing boundary for a
// WAV dropped into ordinary Anselm chat. The default managed model deliberately does not advertise
// chat audio (realtime ASR is a separate proof-bound route), so the attachment must become an
// honest text note and the turn must still complete; it must never be forwarded as an unsupported
// native audio part that turns into a gateway 400.
func TestLiveManaged_DefaultChatWithAudioAttachmentDegrades(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-audio-attachment-degrade")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Audio    bool   `json:"audio"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if cap.Audio {
				t.Fatalf("managed default must not advertise chat audio while realtime ASR remains separate: %+v", cap)
			}
			goto capabilityFound
		}
	}
	t.Fatal("managed default capability row anselm-auto not found")

capabilityFound:
	attID := uploadAtt(t, wc, "voice-note.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "managed audio attachment degrade")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认这个附件请求已收到。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed chat with unsupported audio attachment must complete via honest degrade: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, harness.MockOpenAIWAV) {
		t.Fatalf("audio attachment must remain byte-identical after managed degrade: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_DefaultChatWithImageAndUnsupportedAudio keeps the multimodal route alive when
// the same user turn mixes a supported image with an unsupported WAV. The image must still select
// the managed vision route; the audio must degrade independently rather than poisoning the whole
// request or being mistaken for a native audio capability.
func TestLiveManaged_DefaultChatWithImageAndUnsupportedAudio(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-image-unsupported-audio")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
		Audio    bool   `json:"audio"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if !cap.Vision || cap.Audio {
				t.Fatalf("managed default must expose vision but not chat audio for mixed downgrade: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Fatal("managed default capability row anselm-auto not found")
	}

	imageID := uploadAtt(t, wc, "mixed.png", "image/png", liveManagedPNG)
	audioID := uploadAtt(t, wc, "mixed.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "managed image and unsupported audio")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认图片已收到，并说明语音附件会如何处理。不要调用工具。",
		"attachmentIds": []string{imageID, audioID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed image+unsupported-audio turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "image", id: imageID, want: liveManagedPNG},
		{name: "audio", id: audioID, want: harness.MockOpenAIWAV},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("mixed %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// shortVideoFixture uses the canonical, SHA-verified multimodal fixture rather than a
// made-up ftyp header. A caller may reuse EVALS_FIXTURE_DIR, otherwise this opt-in test materializes
// the fixture into its own temporary directory; the materializer fails loudly if the pinned source
// drifts or ffmpeg cannot derive the rest of the fixture set.
func shortVideoFixture(t *testing.T) []byte {
	t.Helper()
	if dir := strings.TrimSpace(os.Getenv("EVALS_FIXTURE_DIR")); dir != "" {
		data, err := os.ReadFile(filepath.Join(dir, "short.mp4"))
		if err != nil {
			t.Fatalf("read short.mp4 from EVALS_FIXTURE_DIR: %v", err)
		}
		return data
	}
	root := ""
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for dir := wd; ; dir = filepath.Dir(dir) {
		if _, err := os.Stat(filepath.Join(dir, "fixtures", "cmd", "materialize", "main.go")); err == nil {
			root = dir
			break
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("could not locate testend fixture materializer")
		}
	}
	out := t.TempDir()
	cmd := exec.Command("go", "run", "./fixtures/cmd/materialize", "-out", out)
	cmd.Dir = root
	if logs, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("materialize managed video fixture: %v\n%s", err, strings.TrimSpace(string(logs)))
	}
	data, err := os.ReadFile(filepath.Join(out, "short.mp4"))
	if err != nil {
		t.Fatalf("read materialized short.mp4: %v", err)
	}
	return data
}

// TestLiveManaged_DefaultChatWithVideoAttachment is the managed MP4 counterpart to the image
// acceptance: upload → short-lived device-proof media lease → deployed gateway's video route →
// durable turn. It checks route capability and byte-preserving product state; it deliberately does
// not confuse a model's text response with proof of visual understanding.
func TestLiveManaged_DefaultChatWithVideoAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-video-input")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	video := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			video = cap.Video
			break
		}
	}
	if !video {
		t.Fatalf("managed default must advertise MP4 input before accepting a video attachment: %+v", caps)
	}

	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("managed MP4 fixture must be valid and within the published 3MiB decoded budget: %d bytes", len(clip))
	}
	attID := uploadAtt(t, wc, "short.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "managed video input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认请求已收到。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed video-input chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, clip) {
		t.Fatalf("uploaded MP4 must survive the managed multimodal turn: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_DefaultChatWithImageAndVideoAttachments proves the actual fusion seam rather
// than two isolated modality probes: one managed Anselm turn receives both a PNG and an MP4, and
// both originals remain readable after the same route has prepared and consumed them.
func TestLiveManaged_DefaultChatWithImageAndVideoAttachments(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-image-video-fusion")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" && cap.Vision && cap.Video {
			ready = true
			break
		}
	}
	if !ready {
		t.Fatalf("managed default must advertise image+video fusion before accepting both attachments: %+v", caps)
	}

	imageID := uploadAtt(t, wc, "fusion.png", "image/png", liveManagedPNG)
	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("managed MP4 fixture must be valid and within the published 3MiB decoded budget: %d bytes", len(clip))
	}
	videoID := uploadAtt(t, wc, "fusion.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "managed image and video fusion")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认同时收到图片和视频。不要调用工具。",
		"attachmentIds": []string{imageID, videoID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed image+video fusion chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	image := wc.DoRaw("GET", "/api/v1/attachments/"+imageID+"/content", "", nil)
	if image.Status != 200 || !bytes.Equal(image.Raw, liveManagedPNG) {
		t.Fatalf("fused image must survive the managed turn unchanged: HTTP %d, %d bytes", image.Status, len(image.Raw))
	}
	video := wc.DoRaw("GET", "/api/v1/attachments/"+videoID+"/content", "", nil)
	if video.Status != 200 || !bytes.Equal(video.Raw, clip) {
		t.Fatalf("fused video must survive the managed turn unchanged: HTTP %d, %d bytes", video.Status, len(video.Raw))
	}
}

// TestLiveManaged_DocumentImageReference verifies the third media-consumption entry: an image
// referenced from a document's Markdown must be discovered, expanded out of the system-prompt
// text into the managed media route, and survive a fresh conversation. A successful direct
// attachment test cannot prove this path — it bypasses document rendering entirely.
func TestLiveManaged_DocumentImageReference(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-document-image")
	attID := uploadAtt(t, wc, "evidence.png", "image/png", liveManagedPNG)
	docID := wc.POST("/api/v1/documents", map[string]any{
		"name":    "visual-evidence",
		"content": "# Evidence\n\n![attached visual](anselm://media/" + attID + ")\n",
	}).Field(t, "id")

	conv := convCreate(t, wc, "managed document image")
	wc.PATCH("/api/v1/conversations/"+conv, map[string]any{
		"attachedDocuments": []map[string]any{{"documentId": docID}},
	}).OK(t, nil)
	msg := sendMsg(t, wc, conv, "请简短确认请求已收到。不要调用工具。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed document-image chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("document-referenced image must survive its managed turn: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_Quota proves the settings-facing product seam: the sidecar retains the device
// proof privately, resolves this workspace's managed install, and proxies the deployed gateway's
// live quota rather than presenting an inferred local counter.
func TestLiveManaged_Quota(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-quota")
	var q struct {
		Limit     int64  `json:"limit"`
		Used      int64  `json:"used"`
		Remaining int64  `json:"remaining"`
		ResetAt   string `json:"resetAt"`
		Available bool   `json:"available"`
	}
	wc.GET("/api/v1/freetier/quota").OK(t, &q)
	if q.Limit <= 0 || q.Used < 0 || q.Remaining < 0 || q.Used+q.Remaining > q.Limit {
		t.Fatalf("managed quota must be a coherent live counter: %+v", q)
	}
	if _, err := time.Parse(time.RFC3339, q.ResetAt); err != nil {
		t.Fatalf("managed quota resetAt must be RFC3339: %q (%v)", q.ResetAt, err)
	}
	if !q.Available {
		t.Fatalf("a fresh managed install must expose available quota: %+v", q)
	}
}

// TestLiveBYOK_OpenAIImageInput proves the user-owned half of the read boundary through the
// product API: add a normal BYOK key, probe it, select an advertised visual model, upload an
// image, then complete an ordinary conversation. The server intentionally keeps its free-tier
// gateway on the harness's closed default for this lane, so no managed key or managed quota can
// accidentally make the result green.
//
// This is a transport/acceptance assertion, not a claim that a model's prose proves perception:
// the capability projection, a real provider accepting the multipart request, the durable turn,
// and preserved attachment are the product-side evidence available without inserting a recording
// proxy between the user and the provider. Deeper pixel-content claims need a provider-side wire
// recorder and belong in a separately scoped live lane.
func TestLiveBYOK_OpenAIImageInput(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	// No ANSELM_GATEWAY_URL override: harness.Start's closed loopback default keeps this test
	// strictly on the BYOK-read surface even though every workspace begins background provisioning.
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-image-input"}).Field(t, "id")
	wc := c.WS(wsID)

	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok", "key": key,
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	// The model is selected only after the actual probe has populated its capability projection.
	// That keeps the test honest if the provider revokes this model from the given project.
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	vision := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" && cap.Vision {
			vision = true
			break
		}
	}
	if !vision {
		t.Fatalf("probed OpenAI BYOK key must expose gpt-4.1-mini image input before selection: %+v", caps)
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	attID := uploadAtt(t, wc, "input.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "BYOK image input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认请求已收到。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("BYOK image-input chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); got.Status != 200 || len(got.Raw) != len(liveManagedPNG) {
		t.Fatalf("uploaded image must survive the BYOK multimodal turn: HTTP %d, %d bytes", got.Status, len(got.Raw))
	}
}

// TestLiveBYOK_OpenAIMultipleImages proves that a same-kind attachment list is not accidentally
// collapsed to its first item. Both source receipts must survive and both exact image parts must
// cross the real OpenAI-compatible wire in one turn.
func TestLiveBYOK_OpenAIMultipleImages(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.openai.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-multiple-images"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-multiple-images", "key": key, "baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" && cap.Vision {
			ready = true
			break
		}
	}
	if !ready {
		t.Skip("current followed OpenAI catalog does not expose gpt-4.1-mini vision capability; multiple-image reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	firstID := uploadAtt(t, wc, "first.png", "image/png", liveManagedPNG)
	secondID := uploadAtt(t, wc, "second.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "OpenAI multiple images")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认两张图片都已收到。不要调用工具。",
		"attachmentIds": []string{firstID, secondID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("OpenAI multiple-image turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, id := range []string{firstID, secondID} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
			t.Fatalf("OpenAI image attachment %s must remain byte-identical: HTTP %d, %d bytes", id, content.Status, len(content.Raw))
		}
	}

	encoded := base64.StdEncoding.EncodeToString(liveManagedPNG)
	seenTwo := false
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		if bytes.Count(call.Body, []byte(`"image_url"`)) >= 2 && bytes.Count(call.Body, []byte(encoded)) >= 2 {
			seenTwo = true
			break
		}
	}
	if !seenTwo {
		t.Fatalf("OpenAI multiple-image wire must contain two exact image parts: chatCalls=%d", rec.CallsTo("/chat/completions"))
	}
	if got := rec.CallsTo("/chat/completions"); got != 1 {
		t.Fatalf("OpenAI multiple-image turn must use one upstream chat request, got %d", got)
	}
}

// TestLiveBYOK_OpenAIImageAndUnsupportedAudio proves that a common drag-and-drop combination does
// not let an image-capable, audio-incapable BYOK model fail the entire turn. The image must remain
// an exact native part on the recorder wire while the WAV becomes an explicit text note.
func TestLiveBYOK_OpenAIImageAndUnsupportedAudio(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.openai.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-image-unsupported-audio"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-image-audio", "key": key, "baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
		Audio    bool   `json:"audio"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" {
			if !cap.Vision || cap.Audio {
				t.Fatalf("OpenAI image-only model must expose vision but not chat audio: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Skip("current followed OpenAI catalog does not expose gpt-4.1-mini image-only capability; mixed downgrade reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	image := liveManagedPNG
	audio := harness.MockOpenAIWAV
	imageID := uploadAtt(t, wc, "openai-mixed.png", "image/png", image)
	audioID := uploadAtt(t, wc, "openai-mixed.wav", "audio/wav", audio)
	conv := convCreate(t, wc, "OpenAI image and unsupported audio")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认图片已收到，并说明语音附件会如何处理。不要调用工具。",
		"attachmentIds": []string{imageID, audioID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("OpenAI image+unsupported-audio turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "image", id: imageID, want: image},
		{name: "audio", id: audioID, want: audio},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("OpenAI mixed %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}

	imageB64 := base64.StdEncoding.EncodeToString(image)
	audioB64 := base64.StdEncoding.EncodeToString(audio)
	seenImage, seenAudio, seenNote := false, false, false
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		seenImage = seenImage || bytes.Contains(call.Body, []byte(`"image_url"`)) && bytes.Contains(call.Body, []byte(imageB64))
		seenAudio = seenAudio || bytes.Contains(call.Body, []byte(`"input_audio"`)) || bytes.Contains(call.Body, []byte(audioB64))
		seenNote = seenNote || bytes.Contains(call.Body, []byte("no native audio input"))
	}
	if !seenImage || seenAudio || !seenNote {
		t.Fatalf("OpenAI image+audio wire must keep image native and explain audio downgrade: image=%v audio=%v note=%v chatCalls=%d", seenImage, seenAudio, seenNote, rec.CallsTo("/chat/completions"))
	}
}

// TestLiveBYOK_OpenAIImageAndUnsupportedVideo covers the parallel drag-and-drop boundary for an
// image-only model and an MP4. It is deliberately same-turn (not history re-projection): the image
// must be native, the video must be an explanatory note, and the provider must receive one valid
// request rather than a mixed-media 400.
func TestLiveBYOK_OpenAIImageAndUnsupportedVideo(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.openai.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-image-unsupported-video"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-image-video", "key": key, "baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" {
			if !cap.Vision || cap.Video {
				t.Fatalf("OpenAI image-only model must expose vision but not video input: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Skip("current followed OpenAI catalog does not expose gpt-4.1-mini image-only capability; mixed downgrade reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	image := liveManagedPNG
	clip := shortVideoFixture(t)
	imageID := uploadAtt(t, wc, "openai-mixed.png", "image/png", image)
	videoID := uploadAtt(t, wc, "openai-mixed.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "OpenAI image and unsupported video")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认图片已收到，并说明视频附件会如何处理。不要调用工具。",
		"attachmentIds": []string{imageID, videoID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("OpenAI image+unsupported-video turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "image", id: imageID, want: image},
		{name: "video", id: videoID, want: clip},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("OpenAI mixed %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}

	imageB64 := base64.StdEncoding.EncodeToString(image)
	videoB64 := base64.StdEncoding.EncodeToString(clip)
	seenImage, seenVideo, seenNote := false, false, false
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		seenImage = seenImage || bytes.Contains(call.Body, []byte(`"image_url"`)) && bytes.Contains(call.Body, []byte(imageB64))
		seenVideo = seenVideo || bytes.Contains(call.Body, []byte(`"video_url"`)) || bytes.Contains(call.Body, []byte(videoB64))
		seenNote = seenNote || bytes.Contains(call.Body, []byte("no native video input"))
	}
	if !seenImage || seenVideo || !seenNote {
		t.Fatalf("OpenAI image+video wire must keep image native and explain video downgrade: image=%v video=%v note=%v chatCalls=%d", seenImage, seenVideo, seenNote, rec.CallsTo("/chat/completions"))
	}
}

// TestLiveBYOK_OpenAIDocumentImageReference proves that the document renderer does not leave an
// anselm://media URL as system-prompt prose on a BYOK route: the fresh conversation must deliver
// the referenced attachment as the exact native image part on the real OpenAI wire.
func TestLiveBYOK_OpenAIDocumentImageReference(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK document-image acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	rec := harness.NewRecorder(t, "https://api.openai.com")
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-document-image"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-document", "key": key,
		"baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	vision := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" && cap.Vision {
			vision = true
			break
		}
	}
	if !vision {
		t.Fatalf("probed OpenAI BYOK model must expose gpt-4.1-mini image input: %+v", caps)
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	attID := uploadAtt(t, wc, "document-evidence.png", "image/png", liveManagedPNG)
	docID := wc.POST("/api/v1/documents", map[string]any{
		"name":    "byok-visual-evidence",
		"content": "# Evidence\n\n![attached visual](anselm://media/" + attID + ")\n",
	}).Field(t, "id")
	conv := convCreate(t, wc, "BYOK document image")
	wc.PATCH("/api/v1/conversations/"+conv, map[string]any{
		"attachedDocuments": []map[string]any{{"documentId": docID}},
	}).OK(t, nil)
	msg := sendMsg(t, wc, conv, "请简短确认请求已收到。不要调用工具。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("BYOK document-image chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("document-referenced image must survive its BYOK turn: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	dumps := rec.DumpsFor("gpt-4.1-mini")
	if len(dumps) == 0 {
		t.Fatal("BYOK document-image turn produced no recorded OpenAI request")
	}
	b64 := base64.StdEncoding.EncodeToString(liveManagedPNG)
	for _, dump := range dumps {
		if dump.HasImagePart(b64) {
			return
		}
	}
	t.Fatal("BYOK document image never reached OpenAI as the exact native image part")
}

// TestLiveBYOK_QwenVideoInput exercises a second real BYOK behavior class: the catalog-derived
// Qwen endpoint and dialect must carry a normal MP4 attachment as a video part. The harness keeps
// its managed gateway closed, so an apparent success cannot be a free-tier fallback.
func TestLiveBYOK_QwenVideoInput(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("QWEN_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires QWEN_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-qwen-video-input"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "qwen", "displayName": "live-qwen-byok", "key": key,
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	video := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "qwen" && cap.ModelID == "qwen3.7-plus" && cap.Video {
			video = true
			break
		}
	}
	if !video {
		t.Fatalf("probed Qwen BYOK key must expose qwen3.7-plus video input before selection: %+v", caps)
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "qwen3.7-plus"}).OK(t, nil)

	clip := shortVideoFixture(t)
	attID := uploadAtt(t, wc, "short.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "BYOK Qwen video input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认请求已收到。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("Qwen BYOK video-input chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, clip) {
		t.Fatalf("uploaded MP4 must survive the Qwen BYOK turn: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveBYOK_QwenImageAndVideoFusion exercises Qwen's OpenAI-compatible multimodal dialect with
// two different native media parts in one real turn. The recorder is the authority here: a text
// answer cannot prove that the image and video were both sent rather than one being silently
// reduced to a filename or an attachment note.
func TestLiveBYOK_QwenImageAndVideoFusion(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("QWEN_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires QWEN_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://dashscope-intl.aliyuncs.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-qwen-image-video-fusion"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "qwen", "displayName": "live-qwen-byok-image-video-fusion", "key": key,
		"baseUrl": rec.URL() + "/compatible-mode/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	const model = "qwen3.7-plus"
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "qwen" && cap.ModelID == model && cap.Vision && cap.Video {
			ready = true
			break
		}
	}
	if !ready {
		t.Fatalf("probed Qwen BYOK key must expose image+video fusion for %s: %+v", model, caps)
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": model}).OK(t, nil)

	image := liveManagedPNG
	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("Qwen fusion MP4 fixture must be valid and within the published 3MiB decoded budget: %d bytes", len(clip))
	}
	imageID := uploadAtt(t, wc, "qwen-fusion.png", "image/png", image)
	videoID := uploadAtt(t, wc, "qwen-fusion.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "Qwen image and video fusion")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认同时收到图片和视频。不要调用工具。",
		"attachmentIds": []string{imageID, videoID},
	})
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("Qwen image+video fusion chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "image", id: imageID, want: image},
		{name: "video", id: videoID, want: clip},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("Qwen fused %s must survive unchanged: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}

	imageB64 := base64.StdEncoding.EncodeToString(image)
	videoB64 := base64.StdEncoding.EncodeToString(clip)
	seenImage, seenVideo := false, false
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		seenImage = seenImage || bytes.Contains(call.Body, []byte(`"image_url"`)) && bytes.Contains(call.Body, []byte(imageB64))
		seenVideo = seenVideo || bytes.Contains(call.Body, []byte(`"video_url"`)) && bytes.Contains(call.Body, []byte(videoB64))
	}
	if !seenImage || !seenVideo {
		t.Fatalf("Qwen fusion wire lost one native part: image=%v video=%v chatCalls=%d", seenImage, seenVideo, rec.CallsTo("/chat/completions"))
	}
}

// TestLiveBYOK_QwenImageAndAudioFusion covers the common “photo + voice note” shape through the
// Qwen Omni dialect. Qwen3 Omni Flash advertises all three native media kinds but accepts only one
// non-text kind per turn; the product must therefore keep the turn alive, send the first native
// kind, and explain the second one instead of forwarding an upstream-invalid combination.
func TestLiveBYOK_QwenImageAndAudioFusion(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("QWEN_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires QWEN_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://dashscope-intl.aliyuncs.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-qwen-image-audio-fusion"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "qwen", "displayName": "live-qwen-byok-image-audio-fusion", "key": key,
		"baseUrl": rec.URL() + "/compatible-mode/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	const model = "qwen3-omni-flash"
	var caps []struct {
		APIKeyID              string `json:"apiKeyId"`
		Provider              string `json:"provider"`
		ModelID               string `json:"modelId"`
		Vision                bool   `json:"vision"`
		Audio                 bool   `json:"audio"`
		MaxDistinctMediaKinds int    `json:"maxDistinctMediaKinds"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "qwen" && cap.ModelID == model && cap.Vision && cap.Audio && cap.MaxDistinctMediaKinds == 1 {
			ready = true
			break
		}
	}
	if !ready {
		t.Fatalf("probed Qwen BYOK key must expose image+audio fusion for %s: %+v", model, caps)
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": model}).OK(t, nil)

	image := liveManagedPNG
	audio := harness.MockOpenAIWAV
	imageID := uploadAtt(t, wc, "qwen-fusion.png", "image/png", image)
	audioID := uploadAtt(t, wc, "qwen-fusion.wav", "audio/wav", audio)
	conv := convCreate(t, wc, "Qwen image and audio fusion")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认同时收到图片和语音。不要调用工具。",
		"attachmentIds": []string{imageID, audioID},
	})
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		for _, call := range rec.Calls() {
			if strings.Contains(call.Path, "/chat/completions") {
				t.Logf("Qwen image+audio upstream call: bodyBytes=%d imagePart=%v audioPart=%v imageBytes=%v audioBytes=%v", len(call.Body), bytes.Contains(call.Body, []byte(`"image_url"`)), bytes.Contains(call.Body, []byte(`"input_audio"`)), bytes.Contains(call.Body, []byte(base64.StdEncoding.EncodeToString(image))), bytes.Contains(call.Body, []byte(base64.StdEncoding.EncodeToString(audio))))
			}
		}
		t.Fatalf("Qwen image+audio fusion chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "image", id: imageID, want: image},
		{name: "audio", id: audioID, want: audio},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("Qwen fused %s must survive unchanged: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}

	imageB64 := base64.StdEncoding.EncodeToString(image)
	audioB64 := base64.StdEncoding.EncodeToString(audio)
	seenImage, seenAudio, seenConstraintNote := false, false, false
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		seenImage = seenImage || bytes.Contains(call.Body, []byte(`"image_url"`)) && bytes.Contains(call.Body, []byte(imageB64))
		seenAudio = seenAudio || bytes.Contains(call.Body, []byte(`"input_audio"`)) && bytes.Contains(call.Body, []byte(audioB64))
		seenConstraintNote = seenConstraintNote || bytes.Contains(call.Body, []byte("at most 1 distinct native media type"))
	}
	if !seenImage || seenAudio || !seenConstraintNote {
		t.Fatalf("Qwen image+audio wire must keep image native and explain audio constraint: image=%v audio=%v note=%v chatCalls=%d", seenImage, seenAudio, seenConstraintNote, rec.CallsTo("/chat/completions"))
	}
}

// TestLiveBYOK_ModelSwitchReprojectsHistoryMedia proves a common user action that isolated
// modality tests miss: send image+video on one BYOK model, switch the conversation's default to a
// second model, then continue the same thread. History must be re-rendered for the new model's
// capabilities — the image remains native, unsupported video becomes an explanatory text note,
// and the old video bytes never leak onto an OpenAI image-only wire.
func TestLiveBYOK_ModelSwitchReprojectsHistoryMedia(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	qwenKey := os.Getenv("QWEN_API_KEY")
	openAIKey := os.Getenv("OPENAI_API_KEY")
	if qwenKey == "" || openAIKey == "" {
		t.Skip("EVALS_BYOK=1 requires QWEN_API_KEY and OPENAI_API_KEY; key material is never logged")
	}

	const qwenModel = "qwen3.7-plus"
	const openAIModel = "gpt-4.1-mini"
	qwenRec := harness.NewRecorder(t, "https://dashscope-intl.aliyuncs.com")
	openAIRec := harness.NewRecorder(t, "https://api.openai.com")
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-model-switch-media"}).Field(t, "id")
	wc := c.WS(wsID)
	qwenID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "qwen", "displayName": "live-qwen-switch-media", "key": qwenKey,
		"baseUrl": qwenRec.URL() + "/compatible-mode/v1",
	}).Field(t, "id")
	openAIID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-switch-media", "key": openAIKey,
		"baseUrl": openAIRec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+qwenID+":test", nil).OK(t, nil)
	wc.POST("/api/v1/api-keys/"+openAIID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	qwenReady, openAIReady := false, false
	for _, cap := range caps {
		if cap.APIKeyID == qwenID && cap.Provider == "qwen" && cap.ModelID == qwenModel && cap.Vision && cap.Video {
			qwenReady = true
		}
		if cap.APIKeyID == openAIID && cap.Provider == "openai" && cap.ModelID == openAIModel && cap.Vision && !cap.Video {
			openAIReady = true
		}
	}
	if !qwenReady || !openAIReady {
		t.Fatalf("model-switch reprobe needs Qwen image+video and OpenAI image-only capabilities: qwen=%v openai=%v", qwenReady, openAIReady)
	}

	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": qwenID, "modelId": qwenModel}).OK(t, nil)
	image := liveManagedPNG
	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("model-switch MP4 fixture must be valid and within the published 3MiB budget: %d bytes", len(clip))
	}
	imageID := uploadAtt(t, wc, "switch.png", "image/png", image)
	videoID := uploadAtt(t, wc, "switch.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "BYOK model switch with media history")
	first := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认同时收到图片和视频。不要调用工具。",
		"attachmentIds": []string{imageID, videoID},
	})
	firstTurn := waitTurn(t, wc, conv, first, 240000)
	if firstTurn.Status != "completed" {
		t.Fatalf("Qwen image+video source turn must complete: status=%s code=%s message=%s", firstTurn.Status, firstTurn.ErrorCode, firstTurn.ErrorMessage)
	}
	imageB64 := base64.StdEncoding.EncodeToString(image)
	videoB64 := base64.StdEncoding.EncodeToString(clip)
	qwenImage, qwenVideo := false, false
	for _, call := range qwenRec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		qwenImage = qwenImage || bytes.Contains(call.Body, []byte(`"image_url"`)) && bytes.Contains(call.Body, []byte(imageB64))
		qwenVideo = qwenVideo || bytes.Contains(call.Body, []byte(`"video_url"`)) && bytes.Contains(call.Body, []byte(videoB64))
	}
	if !qwenImage || !qwenVideo {
		t.Fatalf("source Qwen turn must receive both exact native media parts: image=%v video=%v chatCalls=%d", qwenImage, qwenVideo, qwenRec.CallsTo("/chat/completions"))
	}

	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": openAIID, "modelId": openAIModel}).OK(t, nil)
	second := sendMsg(t, wc, conv, "我刚切换到图片模型，请简短确认仍能继续这个会话。不要调用工具。")
	secondTurn := waitTurn(t, wc, conv, second, 180000)
	if secondTurn.Status != "completed" {
		t.Fatalf("OpenAI continuation after model switch must complete: status=%s code=%s message=%s", secondTurn.Status, secondTurn.ErrorCode, secondTurn.ErrorMessage)
	}
	openAIImage, openAIVideo, openAINote := false, false, false
	for _, call := range openAIRec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		openAIImage = openAIImage || bytes.Contains(call.Body, []byte(`"image_url"`)) && bytes.Contains(call.Body, []byte(imageB64))
		openAIVideo = openAIVideo || bytes.Contains(call.Body, []byte(`"video_url"`)) || bytes.Contains(call.Body, []byte(videoB64))
		openAINote = openAINote || bytes.Contains(call.Body, []byte("no native video input"))
	}
	if !openAIImage || openAIVideo || !openAINote {
		t.Fatalf("switched OpenAI wire must keep image native and degrade history video without bytes: image=%v video=%v note=%v chatCalls=%d", openAIImage, openAIVideo, openAINote, openAIRec.CallsTo("/chat/completions"))
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "image", id: imageID, want: image},
		{name: "video", id: videoID, want: clip},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("switched %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// TestLiveBYOK_QwenChatOnlyAgentRejected proves the user-facing agent boundary for a real
// chat-only model. The key is probed and selected through the ordinary workspace API, then the
// agent invocation is rejected before any upstream generation; a text-capable model must remain
// usable for chat without pretending to be an agent.
func TestLiveBYOK_QwenChatOnlyAgentRejected(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("QWEN_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires QWEN_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-qwen-chat-only-agent"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "qwen", "displayName": "live-qwen-chat-only", "key": key,
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/agent",
		map[string]any{"apiKeyId": keyID, "modelId": "qwen-mt-plus"}).OK(t, nil)
	agID := wc.POST("/api/v1/agents", map[string]any{
		"name": "Qwen chat-only probe", "description": "capability boundary", "prompt": "Answer briefly.",
	}).Field(t, "id")
	var res struct {
		OK       bool   `json:"ok"`
		Status   string `json:"status"`
		ErrorMsg string `json:"errorMsg"`
		Steps    int    `json:"steps"`
	}
	wc.POST("/api/v1/agents/"+agID+":invoke", map[string]any{"input": map[string]any{}}).OK(t, &res)
	if res.OK || res.Status != "failed" || res.Steps != 0 || !strings.Contains(res.ErrorMsg, "cannot run as an agent") {
		t.Fatalf("chat-only Qwen agent must fail before any step: %+v", res)
	}
}

// TestLiveBYOK_TextProviderSmoke exercises two additional real read-side protocol classes
// through the product API: DeepSeek's OpenAI-compatible endpoint and Google's native Gemini
// generateContent endpoint. The managed gateway stays closed for this lane, so a completed turn
// must come from the explicitly selected BYOK key and its probed model capability.
func TestLiveBYOK_TextProviderSmoke(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}

	cases := []struct {
		name     string
		env      string
		provider string
		model    string
	}{
		{name: "deepseek", env: "DEEPSEEK_API_KEY", provider: "deepseek", model: "deepseek-v4-flash"},
		{name: "google", env: "GEMINI_API_KEY", provider: "google", model: "gemini-3-flash-preview"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			key := os.Getenv(tc.env)
			if key == "" {
				t.Skipf("EVALS_BYOK=1 requires %s; key material is never logged", tc.env)
			}

			srv := harness.Start(t)
			c := srv.Client(t)
			wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-" + tc.name + "-text"}).Field(t, "id")
			wc := c.WS(wsID)
			keyID := wc.POST("/api/v1/api-keys", map[string]any{
				"provider": tc.provider, "displayName": "live-" + tc.name + "-byok", "key": key,
			}).Field(t, "id")
			wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

			var caps []struct {
				APIKeyID string `json:"apiKeyId"`
				Provider string `json:"provider"`
				ModelID  string `json:"modelId"`
			}
			wc.GET("/api/v1/model-capabilities").OK(t, &caps)
			found := false
			for _, cap := range caps {
				if cap.APIKeyID == keyID && cap.Provider == tc.provider && cap.ModelID == tc.model {
					found = true
					break
				}
			}
			if !found {
				t.Fatalf("probed %s BYOK key must expose %s before selection: %+v", tc.provider, tc.model, caps)
			}
			wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
				map[string]any{"apiKeyId": keyID, "modelId": tc.model}).OK(t, nil)

			conv := convCreate(t, wc, tc.name+" BYOK text")
			msg := sendMsg(t, wc, conv, "请用一句简短中文回答：连接测试通过了吗？不要调用工具。")
			turn := waitTurn(t, wc, conv, msg, 180000)
			if turn.Status != "completed" {
				if turn.ErrorCode == "LLM_RATE_LIMITED" {
					t.Logf("%s BYOK text lane reached the provider's current rate window: %s", tc.provider, turn.ErrorMessage)
					t.Skip("provider rate-limited this live sample; structured LLM_RATE_LIMITED classification verified")
				}
				t.Fatalf("%s BYOK text chat must complete: status=%s code=%s message=%s", tc.provider, turn.Status, turn.ErrorCode, turn.ErrorMessage)
			}
			for _, block := range turn.Blocks {
				if block.Type == "text" && strings.TrimSpace(block.Content) != "" {
					return
				}
			}
			t.Fatalf("%s BYOK text chat completed without an assistant text block: %+v", tc.provider, turn.Blocks)
		})
	}
}

// TestLiveBYOK_GoogleListedModelCanBeAccountUnavailable proves the honest failure boundary for
// a model that remains visible in Google's ListModels inventory but is rejected by the current
// account at generate time. Selection may persist the user's explicit choice; the first turn must
// fail once, without retrying a non-retryable 404 or pretending an assistant answer exists.
func TestLiveBYOK_GoogleListedModelCanBeAccountUnavailable(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("GEMINI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires GEMINI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://generativelanguage.googleapis.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-google-listed-unavailable"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "google", "displayName": "live-google-listed-unavailable", "key": key, "baseUrl": rec.URL() + "/v1beta",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	listed, recoverable := false, false
	for _, cap := range caps {
		if cap.APIKeyID != keyID || cap.Provider != "google" {
			continue
		}
		switch cap.ModelID {
		case "gemini-2.5-flash":
			listed = true
		case "gemini-3-flash-preview":
			recoverable = true
		}
	}
	if !listed {
		t.Skip("current Google account no longer lists gemini-2.5-flash; stale-model reprobe is not constructible")
	}
	if !recoverable {
		t.Skip("current Google account does not expose a known-good recovery model; stale-model recovery reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gemini-2.5-flash"}).OK(t, nil)
	conv := convCreate(t, wc, "Google listed unavailable model")
	msg := sendMsg(t, wc, conv, "请用一句简短中文回答：连接测试。不要调用工具。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "error" {
		t.Fatalf("listed-but-unavailable Google model must end in error: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if got := rec.CallsTo("streamGenerateContent"); got != 1 {
		t.Fatalf("non-retryable Google model 404 must make exactly one generate call, got %d", got)
	}
	if turn.ErrorCode == "" || turn.ErrorMessage == "" || !strings.Contains(strings.ToLower(turn.ErrorMessage), "model not found") {
		t.Fatalf("listed-but-unavailable Google model must expose a structured non-empty failure: code=%q message=%q", turn.ErrorCode, turn.ErrorMessage)
	}
	for _, block := range turn.Blocks {
		if block.Type == "text" && strings.TrimSpace(block.Content) != "" {
			t.Fatalf("listed-but-unavailable Google model must not persist an assistant answer: %+v", turn.Blocks)
		}
	}
	t.Logf("listed-but-unavailable Google model failure: code=%s message=%s", turn.ErrorCode, turn.ErrorMessage)

	// The failure banner's user action is a model re-pick, not a dead-end. Exercise the
	// recovery on the same conversation so an error turn cannot poison the next send or keep
	// resolving the stale model behind the scenes.
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gemini-3-flash-preview"}).OK(t, nil)
	retryMsg := sendMsg(t, wc, conv, "模型已切换，请用一句简短中文确认恢复。不要调用工具。")
	recovered := waitTurn(t, wc, conv, retryMsg, 180000)
	if recovered.Status != "completed" {
		t.Fatalf("a valid model selected after stale-model failure must recover the same conversation: status=%s code=%s message=%s", recovered.Status, recovered.ErrorCode, recovered.ErrorMessage)
	}
	foundText := false
	for _, block := range recovered.Blocks {
		if block.Type == "text" && strings.TrimSpace(block.Content) != "" {
			foundText = true
			break
		}
	}
	if !foundText {
		t.Fatalf("recovered conversation must persist an assistant text block: %+v", recovered.Blocks)
	}
	if got := rec.CallsTo("streamGenerateContent"); got != 2 {
		t.Fatalf("stale-model failure plus one recovery send must make exactly two generate calls, got %d", got)
	}
}

// TestLiveBYOK_GoogleImageInput covers Google's native Gemini wire on the multimodal read
// boundary. Unlike the OpenAI-compatible image lane above, this exercises contents/parts mapping,
// native x-goog-api-key auth and the model-in-path request while keeping the managed gateway closed.
func TestLiveBYOK_GoogleImageInput(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("GEMINI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires GEMINI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-google-image-input"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "google", "displayName": "live-google-byok-image", "key": key,
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	vision := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "google" && cap.ModelID == "gemini-3-flash-preview" && cap.Vision {
			vision = true
			break
		}
	}
	if !vision {
		t.Fatalf("probed Google BYOK key must expose Gemini image input before selection: %+v", caps)
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gemini-3-flash-preview"}).OK(t, nil)

	attID := uploadAtt(t, wc, "input.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "Google BYOK image input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认请求已收到。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		if turn.ErrorCode == "LLM_RATE_LIMITED" {
			t.Logf("Google BYOK image-input lane reached the provider's current rate window: %s", turn.ErrorMessage)
			t.Skip("Google provider rate-limited this live sample; structured LLM_RATE_LIMITED classification verified")
		}
		t.Fatalf("Google BYOK image-input chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); got.Status != 200 || len(got.Raw) != len(liveManagedPNG) {
		t.Fatalf("uploaded image must survive the Google BYOK multimodal turn: HTTP %d, %d bytes", got.Status, len(got.Raw))
	}
}

// TestLiveBYOK_OpenAIAudioInput covers the OpenAI-compatible native input_audio part through the
// product API. The recorder proves the uploaded WAV reaches the real upstream wire; the durable
// attachment check proves the product did not rewrite the user's source while preparing it.
func TestLiveBYOK_OpenAIAudioInput(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.openai.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-audio-input"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-audio", "key": key, "baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Audio    bool   `json:"audio"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	model := "gpt-audio"
	audio := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == model && cap.Audio {
			audio = true
			break
		}
	}
	if !audio {
		t.Skip("current followed OpenAI catalog does not expose gpt-audio audio input; audio reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": model}).OK(t, nil)

	attID := uploadAtt(t, wc, "input.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "OpenAI BYOK audio input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认收到了音频。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("OpenAI BYOK audio-input chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); got.Status != 200 || !bytes.Equal(got.Raw, harness.MockOpenAIWAV) {
		t.Fatalf("uploaded WAV must survive the OpenAI BYOK audio turn: HTTP %d, %d bytes", got.Status, len(got.Raw))
	}
	encoded := base64.StdEncoding.EncodeToString(harness.MockOpenAIWAV)
	wireAudio, wireEncoded := false, false
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		wireAudio = wireAudio || bytes.Contains(call.Body, []byte(`"input_audio"`))
		wireEncoded = wireEncoded || bytes.Contains(call.Body, []byte(encoded))
	}
	if !wireAudio || !wireEncoded {
		t.Fatalf("OpenAI upstream must receive the exact native input_audio part: audio=%v encodedBytes=%v calls=%d", wireAudio, wireEncoded, rec.CallsTo("/chat/completions"))
	}
}

// TestLiveBYOK_OpenAIAudioToolContinuation proves the combined boundary that is easiest to miss:
// a real gpt-audio turn must carry native input_audio and still remain an agent turn. The first
// request must call a user-owned function, the sandbox result must be fed back, and the second
// request must finish without losing the audio/tool wire distinction.
func TestLiveBYOK_OpenAIAudioToolContinuation(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.openai.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-audio-tool"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-audio-tool", "key": key, "baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Audio    bool   `json:"audio"`
		Tools    bool   `json:"tools"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	eligible := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-audio" && cap.Audio && cap.Tools {
			eligible = true
			break
		}
	}
	if !eligible {
		t.Skip("current OpenAI account/catalog does not expose gpt-audio audio+tools; combined reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-audio"}).OK(t, nil)
	fnID := fnCreate(t, wc, "openai_audio_eval_receipt", "def openai_audio_eval_receipt(value: str) -> dict:\n    return {'value': value}\n")
	// Function creation is HTTP-synchronous for the entity but its sandbox environment is not. Wait
	// for the active version to become callable so a fast audio model cannot race the registry build.
	harness.Eventually(t, 30000, "the audio continuation function environment becomes ready", func() bool {
		var detail struct {
			ActiveVersion struct {
				EnvStatus string `json:"envStatus"`
			} `json:"activeVersion"`
		}
		wc.GET("/api/v1/functions/"+fnID).OK(t, &detail)
		return detail.ActiveVersion.EnvStatus == "ready"
	})

	attID := uploadAtt(t, wc, "input.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "OpenAI BYOK audio tool continuation")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       fmt.Sprintf("Use the available run_function tool exactly once with functionId %q and args {value: received}. Do not answer before the function returns; then briefly report the returned value.", fnID),
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("OpenAI gpt-audio audio+tool chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	toolCall, toolResult, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			toolName, _ := block.Attrs["tool"].(string)
			toolCall = toolCall || toolName == "run_function" && strings.Contains(block.Content, fnID)
		case "tool_result":
			toolResult = toolResult || strings.Contains(block.Content, "openai_audio_eval_receipt") || strings.Contains(block.Content, `"value":"received"`)
		case "text":
			answer += block.Content
		}
	}
	encoded := base64.StdEncoding.EncodeToString(harness.MockOpenAIWAV)
	wireAudio, wireEncoded, wireTools, chatCalls := false, false, false, 0
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		chatCalls++
		wireAudio = wireAudio || bytes.Contains(call.Body, []byte(`"input_audio"`))
		wireEncoded = wireEncoded || bytes.Contains(call.Body, []byte(encoded))
		wireTools = wireTools || bytes.Contains(call.Body, []byte(`"tools"`))
	}
	if !toolCall || !toolResult || !strings.Contains(strings.ToLower(answer), "received") || chatCalls < 2 || !wireAudio || !wireEncoded || !wireTools {
		t.Fatalf("OpenAI audio+tool continuation lost call/result/text or wire evidence: call=%v result=%v answer=%q chatCalls=%d audio=%v encodedBytes=%v tools=%v", toolCall, toolResult, answer, chatCalls, wireAudio, wireEncoded, wireTools)
	}
}

// TestLiveBYOK_GoogleToolContinuation exercises Gemini's native functionCall/functionResponse
// round-trip through the ordinary chat loop. It is deliberately one tiny deterministic function:
// the real provider must request it, the sandbox must execute it, and the second model turn must
// report the returned value.
func TestLiveBYOK_GoogleToolContinuation(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("GEMINI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires GEMINI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://generativelanguage.googleapis.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-google-tool-continuation"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "google", "displayName": "live-google-byok-tool", "key": key, "baseUrl": rec.URL() + "/v1beta",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gemini-3-flash-preview"}).OK(t, nil)
	fnCreate(t, wc, "gemini_eval_square", "def gemini_eval_square(n: int) -> dict:\n    return {\"square\": n * n}\n")
	conv := convCreate(t, wc, "Google BYOK tool continuation")
	msg := sendMsg(t, wc, conv, "请调用 gemini_eval_square，参数 n=12。不要自己计算；工具返回后报告结果。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		if turn.ErrorCode == "LLM_RATE_LIMITED" {
			t.Logf("Google BYOK tool continuation reached the provider's current rate window: %s", turn.ErrorMessage)
			t.Skip("Google provider rate-limited this live sample; structured LLM_RATE_LIMITED classification verified")
		}
		for _, call := range rec.Calls() {
			if strings.Contains(call.Path, "streamGenerateContent") {
				t.Logf("Google provider request path=%s bytes=%d has_tools=%v has_function_call=%v has_function_response=%v has_thought_signature=%v",
					call.Path, len(call.Body), bytes.Contains(call.Body, []byte(`"tools"`)),
					bytes.Contains(call.Body, []byte(`"functionCall"`)), bytes.Contains(call.Body, []byte(`"functionResponse"`)),
					bytes.Contains(call.Body, []byte(`"thoughtSignature"`)))
			}
		}
		t.Fatalf("Google BYOK tool continuation must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	toolCall, toolResult, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			if strings.Contains(block.Content, "gemini_eval_square") {
				toolCall = true
			}
		case "tool_result":
			if strings.Contains(block.Content, "gemini_eval_square") || strings.Contains(block.Content, `"square":144`) {
				toolResult = true
			}
		case "text":
			answer += block.Content
		}
	}
	seenFunctionCall, seenFunctionResponse, seenThoughtSignature := false, false, false
	streamCalls := 0
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "streamGenerateContent") {
			continue
		}
		streamCalls++
		seenFunctionCall = seenFunctionCall || bytes.Contains(call.Body, []byte(`"functionCall"`))
		seenFunctionResponse = seenFunctionResponse || bytes.Contains(call.Body, []byte(`"functionResponse"`))
		seenThoughtSignature = seenThoughtSignature || bytes.Contains(call.Body, []byte(`"thoughtSignature"`))
	}
	if !toolCall || !toolResult || !strings.Contains(answer, "144") || streamCalls < 2 || !seenFunctionCall || !seenFunctionResponse || !seenThoughtSignature {
		for _, call := range rec.Calls() {
			t.Logf("Google provider call path=%s bytes=%d body_has_tools=%v body_has_function_call=%v body_has_function_response=%v body_has_thought_signature=%v",
				call.Path, len(call.Body), bytes.Contains(call.Body, []byte(`"tools"`)), bytes.Contains(call.Body, []byte(`"functionCall"`)),
				bytes.Contains(call.Body, []byte(`"functionResponse"`)), bytes.Contains(call.Body, []byte(`"thoughtSignature"`)))
		}
		t.Fatalf("Google tool continuation lost the call/result/wire round-trip: call=%v result=%v answer=%q streamCalls=%d functionCall=%v functionResponse=%v thoughtSignature=%v blocks=%+v",
			toolCall, toolResult, answer, streamCalls, seenFunctionCall, seenFunctionResponse, seenThoughtSignature, turn.Blocks)
	}
}

// TestLiveHybrid_OpenAIPlansManagedImage proves the product's intended mixed ownership: the user
// supplies the dialogue model, while Anselm supplies and pays for the generation route. It is a
// deliberately tiny paid sample: at most two loop steps, with the prompt requiring one image call
// followed by a final answer. A regression may therefore spend no more than two images before the
// durable loop stops, rather than silently burning an unbounded allowance.
func TestLiveHybrid_OpenAIPlansManagedImage(t *testing.T) {
	if os.Getenv("EVALS_HYBRID") != "1" {
		t.Skip("set EVALS_HYBRID=1 (and EVALS_MANAGED=1) for the real mixed-route acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_HYBRID=1 requires OPENAI_API_KEY; key material is never logged")
	}

	wc := liveManagedWorkspace(t, "live-hybrid-openai-managed-image")
	// Keep the planner real while recording the BYOK wire. The generation half still goes through
	// the deployed Anselm API Serve; this proxy only makes the downstream pixel claim observable.
	// 让 planner 仍使用真实模型，同时录下 BYOK 线缆。生成半边依旧经过部署中的 Anselm API Serve；代理只为
	// 让下游像素断言可观察。
	rec := harness.NewRecorder(t, "https://api.openai.com")
	var keys []struct {
		ID       string `json:"id"`
		Provider string `json:"provider"`
	}
	wc.GET("/api/v1/api-keys").OK(t, &keys)
	managedKeyID := ""
	for _, row := range keys {
		if row.Provider == "anselm" {
			managedKeyID = row.ID
			break
		}
	}
	if managedKeyID == "" {
		t.Fatal("hybrid generation requires the provisioned managed key")
	}

	byokKeyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-hybrid", "key": key,
		"baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+byokKeyID+":test", nil).OK(t, nil)
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Tools    bool   `json:"tools"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	toolCapable := false
	for _, cap := range caps {
		if cap.APIKeyID == byokKeyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" && cap.Tools {
			toolCapable = true
			break
		}
	}
	if !toolCapable {
		t.Fatalf("probed BYOK model must advertise tools before hybrid selection: %+v", caps)
	}
	wsID := wc.WorkspaceID()
	var workspace struct {
		DefaultImage *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultImage"`
	}
	wc.GET("/api/v1/workspaces/"+wsID).OK(t, &workspace)
	if workspace.DefaultImage == nil || workspace.DefaultImage.APIKeyID != managedKeyID || workspace.DefaultImage.ModelID == "" {
		t.Fatalf("hybrid image scenario must remain managed before the BYOK dialogue override: %+v", workspace.DefaultImage)
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": byokKeyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	// Two steps allow the required tool call plus its answer, and bound an accidental re-draw loop.
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	conv := convCreate(t, wc, "BYOK plans, Anselm renders")
	msg := sendMsg(t, wc, conv, "请调用 generate_image **恰好一次**，画一个白底红色圆形。工具成功后只用一句简短中文确认，绝不再次调用任何生成工具。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("hybrid image turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	attID := attachmentFrom(t, turn, "generate_image")
	callCount := 0
	for _, block := range turn.Blocks {
		if block.Type == "tool_result" && strings.Contains(block.Content, `"source":"generate_image"`) {
			callCount++
			if !strings.Contains(block.Content, `"provider":"anselm"`) {
				t.Fatalf("hybrid generation receipt must name the managed provider, got %s", block.Content)
			}
		}
	}
	if callCount != 1 {
		t.Fatalf("hybrid turn generated %d images, want exactly one within its bounded budget", callCount)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) {
		t.Fatalf("managed hybrid artifact must round-trip as an image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	dumps := rec.DumpsFor("gpt-4.1-mini")
	if len(dumps) < 2 {
		t.Fatalf("hybrid BYOK planner wire must contain tool-call and continuation requests, got %d", len(dumps))
	}
	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	fed := false
	for _, dump := range dumps {
		if dump.HasImagePart(b64) {
			fed = true
			break
		}
	}
	if !fed {
		t.Fatal("hybrid continuation never sent the managed image bytes to the BYOK planner")
	}
}
