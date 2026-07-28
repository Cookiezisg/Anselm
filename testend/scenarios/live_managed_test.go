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
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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
	listed := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "google" && cap.ModelID == "gemini-2.5-flash" {
			listed = true
			break
		}
	}
	if !listed {
		t.Skip("current Google account no longer lists gemini-2.5-flash; stale-model reprobe is not constructible")
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
		t.Fatalf("Google BYOK image-input chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if got := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); got.Status != 200 || len(got.Raw) != len(liveManagedPNG) {
		t.Fatalf("uploaded image must survive the Google BYOK multimodal turn: HTTP %d, %d bytes", got.Status, len(got.Raw))
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
