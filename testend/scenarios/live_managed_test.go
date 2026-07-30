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
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

const liveManagedGateway = "https://api.anselm.website/v1"

// receiptField matches a semantic JSON string field inside a tool result. Real models are free to
// pretty-print the receipt (for example, `"source": "generate_image"`), so acceptance tests must
// not make whitespace part of the product contract.
func receiptField(content, key, value string) bool {
	pattern := `"` + regexp.QuoteMeta(key) + `"\s*:\s*"` + regexp.QuoteMeta(value) + `"`
	return regexp.MustCompile(pattern).MatchString(content)
}

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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_image") {
			count++
			if !receiptField(block.Content, "provider", "anselm") {
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
		case receiptField(block.Content, "source", "generate_image"):
			generateCount++
			if !receiptField(block.Content, "provider", "anselm") {
				t.Fatalf("managed generate receipt must name anselm: %s", block.Content)
			}
			if generatedID == "" {
				generatedID = attIDShape.FindString(block.Content)
			}
		case receiptField(block.Content, "source", "edit_image"):
			editCount++
			if !receiptField(block.Content, "provider", "anselm") {
				t.Fatalf("managed edit receipt must name anselm: %s", block.Content)
			}
			if editedID == "" {
				editedID = attIDShape.FindString(block.Content)
			}
			if generatedID != "" && !receiptField(block.Content, "sourceAttachmentId", generatedID) {
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

// TestLiveManaged_WorkflowGenerateSpeechToManagedViewer proves the managed workflow audio seam:
// the upstream trusted node generates one real WAV, the downstream managed node receives the
// MediaRef in the same run, and the default chat model completes with an honest audio downgrade
// instead of attempting an unsupported native audio request or redrawing the artifact.
func TestLiveManaged_WorkflowGenerateSpeechToManagedViewer(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-workflow-speech")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	var ws struct {
		DefaultAgent *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultAgent"`
	}
	wc.GET("/api/v1/workspaces/"+wc.WorkspaceID()).OK(t, &ws)
	if ws.DefaultAgent == nil || ws.DefaultAgent.APIKeyID == "" || ws.DefaultAgent.ModelID == "" {
		t.Fatalf("managed speech workflow probe requires a ready default agent model: %+v", ws.DefaultAgent)
	}

	speaker := agCreate(t, wc, map[string]any{
		"name":        "Managed Workflow Speaker",
		"description": "generates one managed WAV and hands its receipt to a managed listener",
		"prompt":      "请调用 generate_speech 恰好一次，把‘海内存知己’读出来；工具成功后把工具 receipt 原样写进最终回答，不要再次调用生成工具。",
		"tools":       []map[string]any{{"ref": "sys:generate_speech", "name": "generate speech"}},
	})
	listener := agCreate(t, wc, map[string]any{
		"name":        "Managed Workflow Listener",
		"description": "receives the managed WAV and degrades honestly if native chat audio is unavailable",
		"prompt":      "用一句简短中文确认你已收到上游音频；如果当前模型不能原生理解音频，请诚实说明。不要调用工具。",
	})
	wfID := wfCreate(t, wc, "managed_speech_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "speak", "kind": "agent", "ref": speaker,
			"input": map[string]any{"task": "start.topic"}}},
		{"op": "add_node", "node": map[string]any{"id": "listen", "kind": "agent", "ref": listener,
			"input": map[string]any{"audio": "speak.text"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "speak"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "speak", "to": "listen"}},
	})

	_, status, nodes := runAndWait(t, wc, wfID, map[string]any{"topic": "read the short Chinese sentence"}, 360000)
	if status != "completed" {
		t.Fatalf("managed speech workflow must complete through honest downstream degrade: status=%s nodes=%s", status, nodes)
	}
	nodeText := string(nodes)
	if !strings.Contains(nodeText, "generate_speech") || !strings.Contains(nodeText, "provider") || !strings.Contains(nodeText, "anselm") {
		t.Fatalf("managed speech workflow result must preserve the generation receipt: %s", nodeText)
	}
	attID := attIDShape.FindString(nodeText)
	if attID == "" {
		t.Fatalf("managed speech workflow result must carry an audio MediaRef attachment id: %s", nodeText)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsWAV(content.Raw) || len(content.Raw) < 4000 {
		t.Fatalf("managed speech workflow artifact must be real WAV audio: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_WorkflowGenerateVideoToManagedViewer proves the managed asynchronous video
// seam inside one default workflow: a trusted upstream agent spends once on generate_video, the
// downstream managed agent receives the resulting MP4 MediaRef, and the durable run completes
// without a lost lease, a second generation, or a receipt-only placeholder.
func TestLiveManaged_WorkflowGenerateVideoToManagedViewer(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-workflow-video")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" && cap.Video {
			ready = true
			break
		}
	}
	if !ready {
		t.Fatalf("managed default must advertise video before starting a video workflow: %+v", caps)
	}

	var ws struct {
		DefaultAgent *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultAgent"`
	}
	wc.GET("/api/v1/workspaces/"+wc.WorkspaceID()).OK(t, &ws)
	if ws.DefaultAgent == nil || ws.DefaultAgent.APIKeyID == "" || ws.DefaultAgent.ModelID == "" {
		t.Fatalf("managed video workflow probe requires a ready default agent model: %+v", ws.DefaultAgent)
	}

	filmmaker := agCreate(t, wc, map[string]any{
		"name":        "Managed Workflow Filmmaker",
		"description": "generates one managed MP4 and hands its receipt to a managed viewer",
		"prompt":      "请调用 generate_video 恰好一次，生成一段 5 秒横向、白天海边微风吹动棕榈树的视频；工具成功后把工具 receipt 原样写进最终回答，不要再次调用生成工具。",
		"tools":       []map[string]any{{"ref": "sys:generate_video", "name": "generate video"}},
	})
	viewer := agCreate(t, wc, map[string]any{
		"name":        "Managed Video Workflow Viewer",
		"description": "receives the managed MP4 over the default video route",
		"prompt":      "用一句简短中文确认你收到上游视频。不要调用工具。",
	})
	wfID := wfCreate(t, wc, "managed_video_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "film", "kind": "agent", "ref": filmmaker,
			"input": map[string]any{"task": "start.topic"}}},
		{"op": "add_node", "node": map[string]any{"id": "watch", "kind": "agent", "ref": viewer,
			"input": map[string]any{"video": "film.text"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "film"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "film", "to": "watch"}},
	})

	_, status, nodes := runAndWait(t, wc, wfID, map[string]any{"topic": "make the short palm-tree video"}, 600000)
	if status != "completed" {
		t.Fatalf("managed video workflow must complete through the managed viewer: status=%s nodes=%s", status, nodes)
	}
	nodeText := string(nodes)
	if !strings.Contains(nodeText, "generate_video") || !strings.Contains(nodeText, "provider") || !strings.Contains(nodeText, "anselm") {
		t.Fatalf("managed video workflow result must preserve the generation receipt: %s", nodeText)
	}
	attID := attIDShape.FindString(nodeText)
	if attID == "" {
		t.Fatalf("managed video workflow result must carry a video MediaRef attachment id: %s", nodeText)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsMP4(content.Raw) || len(content.Raw) < 10000 {
		t.Fatalf("managed video workflow artifact must be real MP4 video: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_WorkflowUserAttachmentFusion proves the other workflow direction: user-uploaded
// MediaRefs enter through the trigger payload, survive CEL input wiring, and become the managed
// agent's actual multimodal input. This is intentionally separate from producer→viewer tests above:
// no workflow node creates the files, so a receipt-only implementation cannot accidentally pass.
func TestLiveManaged_WorkflowUserAttachmentFusion(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-workflow-user-attachments")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)

	var caps []struct {
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		Vision     bool   `json:"vision"`
		Video      bool   `json:"video"`
		NativeDocs bool   `json:"nativeDocs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if !cap.Vision || !cap.Video || cap.NativeDocs {
				t.Fatalf("managed workflow user fusion requires vision+video plus non-native PDF extraction: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Fatal("managed default capability row anselm-auto not found")
	}

	const token = "WORKFLOW_USER_FUSION_7F3A"
	pdf := buildPDF(token)
	pdfID := uploadAtt(t, wc, "workflow-user-evidence.pdf", "application/pdf", pdf)
	imageID := uploadAtt(t, wc, "workflow-user-evidence.png", "image/png", liveManagedPNG)
	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("managed workflow MP4 fixture must be valid and within the published 3MiB budget: %d bytes", len(clip))
	}
	videoID := uploadAtt(t, wc, "workflow-user-evidence.mp4", "video/mp4", clip)

	reader := agCreate(t, wc, map[string]any{
		"name":        "Managed Workflow User Attachment Reader",
		"description": "reads user-uploaded PDF, image, and video through the trigger payload",
		"prompt":      "Input data contains a user-uploaded picture, document, and video. Read the attached document, find its only English token, and briefly acknowledge that the picture and video are also attached. Output only the token; do not call tools and do not guess.",
	})
	wfID := wfCreate(t, wc, "managed_user_attachment_fusion", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "read", "kind": "agent", "ref": reader,
			"input": map[string]any{"task": "start.task", "picture": "start.picture", "document": "start.document", "video": "start.video"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "read"}},
	})

	payload := map[string]any{
		"task": "从 document 找出唯一英文 token，同时确认 picture 和 video 已收到。",
		"picture": map[string]any{
			"attachmentId": imageID,
			"filename":     "workflow-user-evidence.png",
			"mime":         "image/png",
			"source":       "user_upload",
		},
		"document": map[string]any{
			"attachmentId": pdfID,
			"filename":     "workflow-user-evidence.pdf",
			"mime":         "application/pdf",
			"source":       "user_upload",
		},
		"video": map[string]any{
			"attachmentId": videoID,
			"filename":     "workflow-user-evidence.mp4",
			"mime":         "video/mp4",
			"source":       "user_upload",
		},
	}
	_, status, nodes := runAndWait(t, wc, wfID, payload, 240000)
	if status != "completed" {
		t.Fatalf("managed workflow user-attachment fusion must complete: status=%s nodes=%s", status, nodes)
	}
	nodeText := string(nodes)
	if !strings.Contains(nodeText, token) {
		t.Fatalf("workflow agent must answer from the uploaded PDF's extracted text, got nodes=%s", nodes)
	}
	if !strings.Contains(nodeText, imageID) || !strings.Contains(nodeText, pdfID) || !strings.Contains(nodeText, videoID) {
		t.Fatalf("workflow trigger result must preserve all user MediaRefs: %s", nodes)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "pdf", id: pdfID, want: pdf},
		{name: "image", id: imageID, want: liveManagedPNG},
		{name: "video", id: videoID, want: clip},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("workflow user %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_WorkflowWebhookUserAttachmentFusion proves the public trigger path for the same
// value: a real webhook body wraps the user's MediaRefs under `start.body`, then CEL wiring passes
// them to a managed agent. Manual flowrun input and webhook input deliberately have separate tests;
// accepting one shape while dropping the other is an easy static-test blind spot.
func TestLiveManaged_WorkflowWebhookUserAttachmentFusion(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-workflow-webhook-attachments")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)

	var caps []struct {
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		Vision     bool   `json:"vision"`
		NativeDocs bool   `json:"nativeDocs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if !cap.Vision || cap.NativeDocs {
				t.Fatalf("managed webhook fusion requires vision plus non-native PDF extraction: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Fatal("managed default capability row anselm-auto not found")
	}

	const token = "WORKFLOW_WEBHOOK_FUSION_9C2D"
	pdf := buildPDF(token)
	pdfID := uploadAtt(t, wc, "workflow-webhook-evidence.pdf", "application/pdf", pdf)
	imageID := uploadAtt(t, wc, "workflow-webhook-evidence.png", "image/png", liveManagedPNG)

	trgID := trgCreate(t, wc, "workflow_user_webhook", "webhook", map[string]any{"path": "workflow-user-webhook"})
	reader := agCreate(t, wc, map[string]any{
		"name":        "Managed Webhook Attachment Reader",
		"description": "reads user-uploaded PDF and image delivered by a webhook workflow trigger",
		"prompt":      "Input data contains a webhook-delivered user picture and document. Read the attached document, find its only English token, and briefly acknowledge the picture. Output only the token; do not call tools and do not guess.",
	})
	wfID := wfCreate(t, wc, "managed_webhook_user_attachment_fusion", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{"id": "read", "kind": "agent", "ref": reader,
			"input": map[string]any{"task": "start.body.task", "picture": "start.body.picture", "document": "start.body.document"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "read"}},
	})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	payload := map[string]any{
		"task": "从 document 找出唯一英文 token，同时确认 picture 已收到。",
		"picture": map[string]any{
			"attachmentId": imageID,
			"filename":     "workflow-webhook-evidence.png",
			"mime":         "image/png",
			"source":       "user_upload",
		},
		"document": map[string]any{
			"attachmentId": pdfID,
			"filename":     "workflow-webhook-evidence.pdf",
			"mime":         "application/pdf",
			"source":       "user_upload",
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal webhook payload: %v", err)
	}
	resp := wc.DoRaw("POST", "/api/v1/webhooks/"+trgID+"/workflow-user-webhook", "application/json", body)
	if resp.Status < 200 || resp.Status >= 300 {
		t.Fatalf("webhook must accept user attachment payload: HTTP %d %s", resp.Status, resp.Raw)
	}

	var rows []frRow
	harness.Eventually(t, 240000, "webhook workflow user attachment run completes", func() bool {
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID + "&origin=webhook&status=completed")
		if r.Status != 200 || json.Unmarshal(r.Data, &rows) != nil {
			return false
		}
		return len(rows) == 1 && rows[0].Origin == "webhook" && rows[0].TriggerID == trgID
	})
	if len(rows) != 1 {
		t.Fatalf("webhook workflow must produce one completed run, got %+v", rows)
	}
	var detail struct {
		Flowrun struct {
			Status string `json:"status"`
			Origin string `json:"origin"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	wc.GET("/api/v1/flowruns/"+rows[0].ID).OK(t, &detail)
	if detail.Flowrun.Status != "completed" || detail.Flowrun.Origin != "webhook" {
		t.Fatalf("webhook workflow run provenance must remain completed/webhook: %+v", detail.Flowrun)
	}
	nodeText := string(detail.Nodes)
	if !strings.Contains(nodeText, token) || !strings.Contains(nodeText, imageID) || !strings.Contains(nodeText, pdfID) {
		t.Fatalf("webhook workflow must preserve body MediaRefs and answer from extracted PDF: %s", nodeText)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "pdf", id: pdfID, want: pdf},
		{name: "image", id: imageID, want: liveManagedPNG},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("webhook workflow %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_ChatTriggerWorkflowUserAttachmentFusion proves the user-facing chat entry to
// the same contract: the default managed dialogue agent discovers trigger_workflow, sends a
// webhook-shaped payload containing user MediaRefs, and the workflow's managed agent consumes the
// document/image. This is intentionally not a direct POST to /flowruns: direct HTTP proves the
// engine, while this path proves chat tool discovery, chat provenance, and the workflow hand-off.
func TestLiveManaged_ChatTriggerWorkflowUserAttachmentFusion(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-chat-trigger-workflow-attachments")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	var caps []struct {
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		Vision     bool   `json:"vision"`
		NativeDocs bool   `json:"nativeDocs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if !cap.Vision || cap.NativeDocs {
				t.Fatalf("managed chat-trigger fusion requires vision plus non-native PDF extraction: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Fatal("managed default capability row anselm-auto not found")
	}

	const token = "CHAT_TRIGGER_WORKFLOW_FUSION_5E8A"
	pdf := buildPDF(token)
	pdfID := uploadAtt(t, wc, "chat-trigger-workflow-evidence.pdf", "application/pdf", pdf)
	imageID := uploadAtt(t, wc, "chat-trigger-workflow-evidence.png", "image/png", liveManagedPNG)

	trgID := trgCreate(t, wc, "chat_trigger_workflow_webhook", "webhook", map[string]any{"path": "chat-trigger-workflow"})
	reader := agCreate(t, wc, map[string]any{
		"name":        "Managed Chat Trigger Attachment Reader",
		"description": "reads user-uploaded PDF and image delivered by a chat-triggered workflow",
		"prompt":      "Input data contains a webhook-delivered user picture and document. Read the attached document, find its only English token, and briefly acknowledge the picture. Output only the token; do not call tools and do not guess.",
	})
	wfID := wfCreate(t, wc, "managed_chat_trigger_user_attachment_fusion", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{"id": "read", "kind": "agent", "ref": reader,
			"input": map[string]any{"task": "start.body.task", "picture": "start.body.picture", "document": "start.body.document"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "read"}},
	})

	convID := convCreate(t, wc, "managed chat trigger workflow attachments")
	prompt := fmt.Sprintf(`先调用 search_tools 查找名为 trigger_workflow 的工作流工具；等它返回工具 schema 后，只调用 trigger_workflow 一次来运行 workflowId=%s，然后直接告诉我返回的 flowrunId。除这一次 search_tools 外不要调用其他工具。
trigger_workflow 的 args 必须同时包含 workflowId 和 payload，不能省略 payload。payload 必须严格使用 webhook 入口形状，并保留这两个用户附件引用：
{"body":{"task":"从 document 找出唯一英文 token，同时确认 picture 已收到。","picture":{"attachmentId":"%s","filename":"chat-trigger-workflow-evidence.png","mime":"image/png","source":"user_upload"},"document":{"attachmentId":"%s","filename":"chat-trigger-workflow-evidence.pdf","mime":"application/pdf","source":"user_upload"}}}
不要平铺 body 内字段，也不要改写 attachmentId。`, wfID, imageID, pdfID)
	turn := waitTurn(t, wc, convID, sendMsg(t, wc, convID, prompt), 300000)
	if turn.Status != "completed" {
		t.Fatalf("chat trigger_workflow turn must complete: status=%s code=%s message=%s blocks=%+v", turn.Status, turn.ErrorCode, turn.ErrorMessage, turn.Blocks)
	}
	searchCalls, triggerCalls, triggerResults := 0, 0, 0
	for _, block := range turn.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "trigger_workflow":
			switch block.Type {
			case "tool_call":
				triggerCalls++
			case "tool_result":
				triggerResults++
				if !strings.Contains(block.Content, wfID) {
					t.Fatalf("trigger_workflow result must name workflow %s: %s", wfID, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || triggerCalls != 1 || triggerResults != 1 {
		t.Fatalf("chat must discover trigger_workflow then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, triggerCalls, triggerResults, turn.Blocks)
	}

	var rows []struct {
		ID             string `json:"id"`
		Status         string `json:"status"`
		Origin         string `json:"origin"`
		ConversationID string `json:"conversationId"`
	}
	harness.Eventually(t, 240000, "chat-triggered workflow run completes", func() bool {
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID + "&origin=chat&status=completed")
		if r.Status != 200 || json.Unmarshal(r.Data, &rows) != nil {
			return false
		}
		return len(rows) == 1 && rows[0].Origin == "chat" && rows[0].ConversationID == convID
	})
	if len(rows) != 1 {
		t.Fatalf("chat trigger_workflow must produce one completed chat run, got %+v", rows)
	}
	var detail struct {
		Flowrun struct {
			Status         string `json:"status"`
			Origin         string `json:"origin"`
			ConversationID string `json:"conversationId"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	wc.GET("/api/v1/flowruns/"+rows[0].ID).OK(t, &detail)
	if detail.Flowrun.Status != "completed" || detail.Flowrun.Origin != "chat" || detail.Flowrun.ConversationID != convID {
		t.Fatalf("chat workflow provenance must remain completed/chat/%s: %+v", convID, detail.Flowrun)
	}
	nodeText := string(detail.Nodes)
	if !strings.Contains(nodeText, token) || !strings.Contains(nodeText, imageID) || !strings.Contains(nodeText, pdfID) {
		t.Fatalf("chat workflow must preserve payload MediaRefs and answer from extracted PDF: %s", nodeText)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "pdf", id: pdfID, want: pdf},
		{name: "image", id: imageID, want: liveManagedPNG},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("chat workflow %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_ChatFlowrunObservability closes the chat-side execution loop: the first turn
// discovers trigger_workflow and starts a real workflow, then a second turn discovers get_flowrun
// and reads the completed run back through the LLM tool surface. The REST poll between turns only
// removes an async race; the user-facing assertions are deliberately on the two chat transcripts.
func TestLiveManaged_ChatFlowrunObservability(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-chat-flowrun-observability")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	const marker = "CHAT_FLOWRUN_OBSERVABILITY_7B2D"
	fnID := fnCreate(t, wc, "chat_flowrun_observer", fmt.Sprintf(`def observe(task: str) -> dict:
    return {"marker": "%s", "echo": task}
`, marker))
	trgID := trgCreate(t, wc, "chat_flowrun_observability_webhook", "webhook", map[string]any{"path": "chat-flowrun-observability"})
	wfID := wfCreate(t, wc, "managed_chat_flowrun_observability", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{"id": "observe", "kind": "action", "ref": fnID,
			"input": map[string]any{"task": "start.body.task"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "observe"}},
	})

	convID := convCreate(t, wc, "managed chat flowrun observability")
	firstPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 trigger_workflow 的工作流工具；等它返回工具 schema 后，只调用 trigger_workflow 一次来运行 workflowId=%s，然后告诉我返回的 flowrunId。除这一次 search_tools 外不要调用其他工具。
trigger_workflow 的 args 必须同时包含 workflowId 和 payload，payload 严格使用 webhook 入口形状：{"body":{"task":"run the observability probe"}}。`, wfID)
	first := waitTurn(t, wc, convID, sendMsg(t, wc, convID, firstPrompt), 300000)
	if first.Status != "completed" {
		t.Fatalf("chat trigger turn must complete: status=%s code=%s message=%s blocks=%+v", first.Status, first.ErrorCode, first.ErrorMessage, first.Blocks)
	}
	searchCalls, triggerCalls, triggerResults := 0, 0, 0
	for _, block := range first.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "trigger_workflow":
			switch block.Type {
			case "tool_call":
				triggerCalls++
			case "tool_result":
				triggerResults++
				if !strings.Contains(block.Content, wfID) {
					t.Fatalf("trigger_workflow result must name workflow %s: %s", wfID, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || triggerCalls != 1 || triggerResults != 1 {
		t.Fatalf("first chat turn must discover trigger_workflow then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, triggerCalls, triggerResults, first.Blocks)
	}

	var rows []struct {
		ID             string `json:"id"`
		Status         string `json:"status"`
		Origin         string `json:"origin"`
		ConversationID string `json:"conversationId"`
	}
	harness.Eventually(t, 240000, "chat-triggered observability run completes", func() bool {
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID + "&origin=chat&status=completed")
		if r.Status != 200 || json.Unmarshal(r.Data, &rows) != nil {
			return false
		}
		return len(rows) == 1 && rows[0].ID != "" && rows[0].Origin == "chat" && rows[0].ConversationID == convID
	})
	if len(rows) != 1 {
		t.Fatalf("chat trigger_workflow must produce one completed observability run, got %+v", rows)
	}

	secondPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 get_flowrun 的工具；等它返回工具 schema 后，只调用 get_flowrun 一次，参数必须是精确的 flowrunId=%s。读取返回的 flowrun 状态和 observe 节点结果，确认状态为 completed，并在最终答复中原样输出唯一 marker：%s。除这一次 search_tools 和这一次 get_flowrun 外不要调用其他工具。`, rows[0].ID, marker)
	second := waitTurn(t, wc, convID, sendMsg(t, wc, convID, secondPrompt), 300000)
	if second.Status != "completed" {
		t.Fatalf("chat get_flowrun turn must complete: status=%s code=%s message=%s blocks=%+v", second.Status, second.ErrorCode, second.ErrorMessage, second.Blocks)
	}
	searchCalls, getCalls, getResults := 0, 0, 0
	for _, block := range second.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "get_flowrun":
			switch block.Type {
			case "tool_call":
				getCalls++
			case "tool_result":
				getResults++
				if !strings.Contains(block.Content, rows[0].ID) || !strings.Contains(block.Content, `"status":"completed"`) || !strings.Contains(block.Content, marker) {
					t.Fatalf("get_flowrun result must expose completed run %s and marker %s: %s", rows[0].ID, marker, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || getCalls != 1 || getResults != 1 {
		t.Fatalf("second chat turn must discover get_flowrun then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, getCalls, getResults, second.Blocks)
	}
	answer := ""
	for _, block := range second.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, marker) {
		t.Fatalf("second chat turn must surface flowrun marker %s in assistant text, blocks=%+v", marker, second.Blocks)
	}
}

// TestLiveManaged_ChatFlowrunFailureDiagnosis proves the negative observability path: a chat
// trigger can start a workflow that fails, and a later chat turn can discover search_flowruns,
// select that failed run, then discover get_flowrun and expose the durable node error instead of
// pretending the asynchronous trigger succeeded end-to-end.
func TestLiveManaged_ChatFlowrunFailureDiagnosis(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-chat-flowrun-failure")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 5}}).OK(t, nil)

	const marker = "CHAT_FLOWRUN_FAILURE_C1A9"
	fnID := fnCreate(t, wc, "chat_flowrun_failure_probe", fmt.Sprintf(`def fail(task: str) -> dict:
    raise RuntimeError("%s")
`, marker))
	trgID := trgCreate(t, wc, "chat_flowrun_failure_webhook", "webhook", map[string]any{"path": "chat-flowrun-failure"})
	wfID := wfCreate(t, wc, "managed_chat_flowrun_failure", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{"id": "fail", "kind": "action", "ref": fnID,
			"input": map[string]any{"task": "start.body.task"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "fail"}},
	})
	// Keep the negative-path assertion about execution, not a provisioning race or workspace
	// scoping mistake: the exact workflow returned by create must already be readable here.
	wc.GET("/api/v1/workflows/"+wfID).OK(t, nil)

	convID := convCreate(t, wc, "managed chat flowrun failure")
	firstPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 trigger_workflow 的工作流工具；等它返回工具 schema 后，只调用 trigger_workflow 一次来运行 workflowId=%s（必须逐字复制这个 workflowId，不要自行改写或猜测），然后告诉我返回的 flowrunId。除这一次 search_tools 外不要调用其他工具。
trigger_workflow 的 args 必须同时包含 workflowId 和 payload，payload 严格使用 webhook 入口形状：{"body":{"task":"run the failure probe"}}。`, wfID)
	first := waitTurn(t, wc, convID, sendMsg(t, wc, convID, firstPrompt), 300000)
	if first.Status != "completed" {
		t.Fatalf("chat failure-trigger turn must complete: status=%s code=%s message=%s blocks=%+v", first.Status, first.ErrorCode, first.ErrorMessage, first.Blocks)
	}
	searchCalls, triggerCalls, triggerResults := 0, 0, 0
	for _, block := range first.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "trigger_workflow":
			switch block.Type {
			case "tool_call":
				triggerCalls++
			case "tool_result":
				triggerResults++
				if !strings.Contains(block.Content, wfID) {
					t.Fatalf("failure trigger result must name workflow %s: result=%s blocks=%+v", wfID, block.Content, first.Blocks)
				}
			}
		}
	}
	if searchCalls < 1 || triggerCalls != 1 || triggerResults != 1 {
		t.Fatalf("failure trigger turn must discover trigger_workflow then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, triggerCalls, triggerResults, first.Blocks)
	}

	var rows []struct {
		ID             string `json:"id"`
		Status         string `json:"status"`
		Origin         string `json:"origin"`
		ConversationID string `json:"conversationId"`
		Error          string `json:"error"`
	}
	harness.Eventually(t, 240000, "chat-triggered failure run settles", func() bool {
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID + "&origin=chat&status=failed")
		if r.Status != 200 || json.Unmarshal(r.Data, &rows) != nil {
			return false
		}
		return len(rows) == 1 && rows[0].ID != "" && rows[0].Origin == "chat" && rows[0].ConversationID == convID && strings.Contains(rows[0].Error, marker)
	})
	if len(rows) != 1 {
		t.Fatalf("chat trigger_workflow must produce one failed run with durable error %s, got %+v", marker, rows)
	}

	secondPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 search_flowruns 的工具；等它返回工具 schema 后，只调用 search_flowruns 一次，参数必须包含 workflowId=%s 和 status=failed。然后从返回的 runs 中选出这个失败 run，再调用 get_flowrun 一次读取它的完整节点错误；最终答复必须说明状态为 failed/失败，并原样输出错误 marker：%s。除这一次 search_tools、一次 search_flowruns 和一次 get_flowrun 外不要调用其他工具。`, wfID, marker)
	second := waitTurn(t, wc, convID, sendMsg(t, wc, convID, secondPrompt), 300000)
	if second.Status != "completed" {
		t.Fatalf("chat failure-diagnosis turn must complete: status=%s code=%s message=%s blocks=%+v", second.Status, second.ErrorCode, second.ErrorMessage, second.Blocks)
	}
	searchCalls, listCalls, listResults, getCalls, getResults := 0, 0, 0, 0, 0
	for _, block := range second.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "search_flowruns":
			switch block.Type {
			case "tool_call":
				listCalls++
			case "tool_result":
				listResults++
				if !strings.Contains(block.Content, rows[0].ID) || !strings.Contains(block.Content, marker) {
					t.Fatalf("search_flowruns result must expose failed run %s and marker %s: %s", rows[0].ID, marker, block.Content)
				}
			}
		case "get_flowrun":
			switch block.Type {
			case "tool_call":
				getCalls++
			case "tool_result":
				getResults++
				if !strings.Contains(block.Content, rows[0].ID) || !strings.Contains(block.Content, `"status":"failed"`) || !strings.Contains(block.Content, marker) {
					t.Fatalf("get_flowrun result must expose failed run %s and marker %s: %s", rows[0].ID, marker, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || listCalls != 1 || listResults != 1 || getCalls != 1 || getResults != 1 {
		t.Fatalf("failure diagnosis must discover/list/detail exactly once: search=%d list=%d/%d get=%d/%d blocks=%+v", searchCalls, listCalls, listResults, getCalls, getResults, second.Blocks)
	}
	answer := ""
	for _, block := range second.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	lowerAnswer := strings.ToLower(answer)
	if !strings.Contains(answer, marker) || (!strings.Contains(lowerAnswer, "failed") && !strings.Contains(answer, "失败")) {
		t.Fatalf("failure diagnosis must surface failed status and marker %s in assistant text, blocks=%+v", marker, second.Blocks)
	}
}

// TestLiveManaged_ChatFlowrunApprovalDecision covers the human-in-the-loop workflow seam from
// chat: one turn starts a run that parks at an approval, a later turn reads the parked node, and a
// final turn discovers decide_approval and resumes the pinned run into its downstream function.
func TestLiveManaged_ChatFlowrunApprovalDecision(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-chat-flowrun-approval")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	const marker = "CHAT_FLOWRUN_APPROVAL_C7E4"
	fnID := fnCreate(t, wc, "chat_flowrun_approval_publish", fmt.Sprintf(`def publish(decision: str) -> dict:
    return {"marker": "%s", "decision": decision}
`, marker))
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "chat_flowrun_release_gate", "template": "Approve release {{ input.task }}?", "allowReason": true,
	}).Field(t, "id")
	trgID := trgCreate(t, wc, "chat_flowrun_approval_webhook", "webhook", map[string]any{"path": "chat-flowrun-approval"})
	wfID := wfCreate(t, wc, "managed_chat_flowrun_approval", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID,
			"input": map[string]any{"task": "start.body.task"}}},
		{"op": "add_node", "node": map[string]any{"id": "publish", "kind": "action", "ref": fnID,
			"input": map[string]any{"decision": "human.decision"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "human"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "human", "to": "publish", "fromPort": "yes"}},
	})
	wc.GET("/api/v1/workflows/"+wfID).OK(t, nil)

	convID := convCreate(t, wc, "managed chat flowrun approval")
	firstPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 trigger_workflow 的工作流工具；等它返回工具 schema 后，只调用 trigger_workflow 一次来运行 workflowId=%s（必须逐字复制这个 workflowId），然后告诉我返回的 flowrunId。除这一次 search_tools 外不要调用其他工具。
trigger_workflow 的 args 必须同时包含 workflowId 和 payload，payload 严格使用 webhook 入口形状：{"body":{"task":"release candidate 7"}}。`, wfID)
	first := waitTurn(t, wc, convID, sendMsg(t, wc, convID, firstPrompt), 300000)
	if first.Status != "completed" {
		t.Fatalf("chat approval-trigger turn must complete: status=%s code=%s message=%s blocks=%+v", first.Status, first.ErrorCode, first.ErrorMessage, first.Blocks)
	}
	searchCalls, triggerCalls, triggerResults := 0, 0, 0
	for _, block := range first.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "trigger_workflow":
			switch block.Type {
			case "tool_call":
				triggerCalls++
			case "tool_result":
				triggerResults++
				if !strings.Contains(block.Content, wfID) {
					t.Fatalf("approval trigger result must name workflow %s: %s", wfID, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || triggerCalls != 1 || triggerResults != 1 {
		t.Fatalf("approval trigger turn must discover trigger_workflow then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, triggerCalls, triggerResults, first.Blocks)
	}

	var parkedID, parkedNode string
	harness.Eventually(t, 240000, "chat-triggered approval run parks", func() bool {
		var inbox struct {
			Parked []struct {
				FlowRunID string `json:"flowrunId"`
				NodeID    string `json:"nodeId"`
			} `json:"parked"`
		}
		r := wc.GET("/api/v1/flowrun-inbox")
		if r.Status != 200 || json.Unmarshal(r.Data, &inbox) != nil {
			return false
		}
		for _, row := range inbox.Parked {
			if row.FlowRunID != "" && row.NodeID == "human" {
				parkedID, parkedNode = row.FlowRunID, row.NodeID
				return true
			}
		}
		return false
	})
	if parkedID == "" || parkedNode != "human" {
		t.Fatalf("chat trigger must park at human approval node: flowrun=%q node=%q", parkedID, parkedNode)
	}

	secondPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 get_flowrun 的工具；等它返回工具 schema 后，只调用 get_flowrun 一次，参数必须是精确的 flowrunId=%s。确认节点 %s 的状态为 parked，并告诉我正在等待人工批准；本轮严禁调用 decide_approval 或任何其他工具。`, parkedID, parkedNode)
	second := waitTurn(t, wc, convID, sendMsg(t, wc, convID, secondPrompt), 300000)
	if second.Status != "completed" {
		t.Fatalf("chat parked-observation turn must complete: status=%s code=%s message=%s blocks=%+v", second.Status, second.ErrorCode, second.ErrorMessage, second.Blocks)
	}
	searchCalls, getCalls, getResults := 0, 0, 0
	for _, block := range second.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "get_flowrun":
			switch block.Type {
			case "tool_call":
				getCalls++
			case "tool_result":
				getResults++
				if !strings.Contains(block.Content, parkedID) || !strings.Contains(block.Content, `"status":"parked"`) || !strings.Contains(block.Content, `"nodeId":"human"`) {
					t.Fatalf("get_flowrun must expose parked run %s at human: %s", parkedID, block.Content)
				}
			}
		case "decide_approval":
			t.Fatalf("parked-observation turn must not decide approval: blocks=%+v", second.Blocks)
		}
	}
	if searchCalls < 1 || getCalls != 1 || getResults != 1 {
		t.Fatalf("parked-observation turn must discover get_flowrun exactly once: search=%d calls=%d results=%d blocks=%+v", searchCalls, getCalls, getResults, second.Blocks)
	}

	thirdPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 decide_approval 的工具；等它返回工具 schema 后，只调用 decide_approval 一次，参数必须精确使用 flowrunId=%s、nodeId=%s、decision=yes、reason="release approved by user"。读取工具返回的完整 run，确认状态为 completed 且 publish 节点结果包含 marker %s；最终答复原样输出 marker。除这一次 search_tools 和这一次 decide_approval 外不要调用其他工具。`, parkedID, parkedNode, marker)
	third := waitTurn(t, wc, convID, sendMsg(t, wc, convID, thirdPrompt), 300000)
	if third.Status != "completed" {
		t.Fatalf("chat approval-decision turn must complete: status=%s code=%s message=%s blocks=%+v", third.Status, third.ErrorCode, third.ErrorMessage, third.Blocks)
	}
	searchCalls, decideCalls, decideResults := 0, 0, 0
	for _, block := range third.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "decide_approval":
			switch block.Type {
			case "tool_call":
				decideCalls++
			case "tool_result":
				decideResults++
				if !strings.Contains(block.Content, parkedID) || !strings.Contains(block.Content, `"status":"completed"`) || !strings.Contains(block.Content, marker) || !strings.Contains(block.Content, `"decision":"yes"`) {
					t.Fatalf("decide_approval result must complete run %s with marker %s: %s", parkedID, marker, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || decideCalls != 1 || decideResults != 1 {
		t.Fatalf("approval decision turn must discover decide_approval then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, decideCalls, decideResults, third.Blocks)
	}
	answer := ""
	for _, block := range third.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, marker) {
		t.Fatalf("approval decision must surface downstream marker %s in assistant text, blocks=%+v", marker, third.Blocks)
	}
}

// TestLiveManaged_ChatFlowrunReplay proves chat can recover a durable failed run rather than
// merely inspect it: a resident handler fails on its first call, get_flowrun exposes the failed
// node, replay_flowrun reuses the completed prefix and the handler succeeds on its second call.
func TestLiveManaged_ChatFlowrunReplay(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-chat-flowrun-replay")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	const marker = "CHAT_FLOWRUN_REPLAY_4F6C"
	stableFn := fnCreate(t, wc, "chat_flowrun_replay_stable", "def stable() -> dict:\n    return {'stable': 'kept'}\n")
	finishFn := fnCreate(t, wc, "chat_flowrun_replay_finish", fmt.Sprintf(`def finish(n: int) -> dict:
    return {"marker": "%s", "final": n}
`, marker))
	hdID := hdCreate(t, wc, "chat_flowrun_replay_flaky", map[string]any{
		"initBody": "self.count = 0",
		"methods": []map[string]any{{
			"name": "flaky", "inputs": []any{},
			"body": "self.count += 1\nif self.count == 1:\n    raise RuntimeError('first replay attempt fails')\nreturn {'n': self.count}",
		}},
	})
	trgID := trgCreate(t, wc, "chat_flowrun_replay_webhook", "webhook", map[string]any{"path": "chat-flowrun-replay"})
	wfID := wfCreate(t, wc, "managed_chat_flowrun_replay", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{"id": "stable", "kind": "action", "ref": stableFn}},
		{"op": "add_node", "node": map[string]any{"id": "flaky", "kind": "action", "ref": hdID + ".flaky"}},
		{"op": "add_node", "node": map[string]any{"id": "finish", "kind": "action", "ref": finishFn,
			"input": map[string]any{"n": "flaky.n"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "stable"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "stable", "to": "flaky"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e3", "from": "flaky", "to": "finish"}},
	})
	wc.GET("/api/v1/workflows/"+wfID).OK(t, nil)

	convID := convCreate(t, wc, "managed chat flowrun replay")
	firstPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 trigger_workflow 的工作流工具；等它返回工具 schema 后，只调用 trigger_workflow 一次来运行 workflowId=%s（必须逐字复制这个 workflowId），然后告诉我返回的 flowrunId。除这一次 search_tools 外不要调用其他工具。
trigger_workflow 的 args 必须同时包含 workflowId 和 payload，payload 严格使用 webhook 入口形状：{"body":{"task":"replay probe"}}。`, wfID)
	first := waitTurn(t, wc, convID, sendMsg(t, wc, convID, firstPrompt), 300000)
	if first.Status != "completed" {
		t.Fatalf("chat replay-trigger turn must complete: status=%s code=%s message=%s blocks=%+v", first.Status, first.ErrorCode, first.ErrorMessage, first.Blocks)
	}
	searchCalls, triggerCalls, triggerResults := 0, 0, 0
	for _, block := range first.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "trigger_workflow":
			switch block.Type {
			case "tool_call":
				triggerCalls++
			case "tool_result":
				triggerResults++
				if !strings.Contains(block.Content, wfID) {
					t.Fatalf("replay trigger result must name workflow %s: %s", wfID, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || triggerCalls != 1 || triggerResults != 1 {
		t.Fatalf("replay trigger turn must discover trigger_workflow then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, triggerCalls, triggerResults, first.Blocks)
	}

	var rows []struct {
		ID             string `json:"id"`
		Status         string `json:"status"`
		Origin         string `json:"origin"`
		ConversationID string `json:"conversationId"`
	}
	harness.Eventually(t, 240000, "chat-triggered replay run fails at flaky handler", func() bool {
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID + "&origin=chat&status=failed")
		if r.Status != 200 || json.Unmarshal(r.Data, &rows) != nil {
			return false
		}
		return len(rows) == 1 && rows[0].ID != "" && rows[0].Origin == "chat" && rows[0].ConversationID == convID
	})
	if len(rows) != 1 {
		t.Fatalf("chat replay trigger must produce one failed run, got %+v", rows)
	}
	runID := rows[0].ID

	secondPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 get_flowrun 的工具；等它返回工具 schema 后，只调用 get_flowrun 一次，参数必须是精确的 flowrunId=%s。确认 flaky 节点已经 failed 且 stable 节点已经 completed；不要调用 replay_flowrun 或任何其他工具，只告诉我这个 run 可以重放。`, runID)
	second := waitTurn(t, wc, convID, sendMsg(t, wc, convID, secondPrompt), 300000)
	if second.Status != "completed" {
		t.Fatalf("chat failed-run observation turn must complete: status=%s code=%s message=%s blocks=%+v", second.Status, second.ErrorCode, second.ErrorMessage, second.Blocks)
	}
	searchCalls, getCalls, getResults := 0, 0, 0
	for _, block := range second.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "get_flowrun":
			switch block.Type {
			case "tool_call":
				getCalls++
			case "tool_result":
				getResults++
				if !strings.Contains(block.Content, runID) || !strings.Contains(block.Content, `"status":"failed"`) || !strings.Contains(block.Content, `"nodeId":"stable"`) || !strings.Contains(block.Content, `"nodeId":"flaky"`) {
					t.Fatalf("get_flowrun must expose failed run %s with stable/flaky nodes: %s", runID, block.Content)
				}
			}
		case "replay_flowrun":
			t.Fatalf("failed-run observation turn must not replay early: blocks=%+v", second.Blocks)
		}
	}
	if searchCalls < 1 || getCalls != 1 || getResults != 1 {
		t.Fatalf("failed-run observation must discover get_flowrun exactly once: search=%d calls=%d results=%d blocks=%+v", searchCalls, getCalls, getResults, second.Blocks)
	}

	thirdPrompt := fmt.Sprintf(`先调用 search_tools 查找名为 replay_flowrun 的工具；等它返回工具 schema 后，只调用 replay_flowrun 一次，参数必须是精确的 flowrunId=%s。读取返回的完整 run，确认状态为 completed、stable 节点结果仍保留、flaky 第二次调用成功且 finish 节点结果包含 marker %s；最终答复原样输出 marker。除这一次 search_tools 和这一次 replay_flowrun 外不要调用其他工具。`, runID, marker)
	third := waitTurn(t, wc, convID, sendMsg(t, wc, convID, thirdPrompt), 300000)
	if third.Status != "completed" {
		t.Fatalf("chat replay turn must complete: status=%s code=%s message=%s blocks=%+v", third.Status, third.ErrorCode, third.ErrorMessage, third.Blocks)
	}
	searchCalls, replayCalls, replayResults := 0, 0, 0
	for _, block := range third.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "search_tools":
			if block.Type == "tool_call" {
				searchCalls++
			}
		case "replay_flowrun":
			switch block.Type {
			case "tool_call":
				replayCalls++
			case "tool_result":
				replayResults++
				if !strings.Contains(block.Content, runID) || !strings.Contains(block.Content, `"status":"completed"`) || !strings.Contains(block.Content, marker) || !strings.Contains(block.Content, `"stable":"kept"`) {
					t.Fatalf("replay_flowrun must complete run %s with memoized prefix and marker %s: %s", runID, marker, block.Content)
				}
			}
		}
	}
	if searchCalls < 1 || replayCalls != 1 || replayResults != 1 {
		t.Fatalf("replay turn must discover replay_flowrun then persist exactly one call/result: search=%d calls=%d results=%d blocks=%+v", searchCalls, replayCalls, replayResults, third.Blocks)
	}
	answer := ""
	for _, block := range third.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, marker) {
		t.Fatalf("replay turn must surface finish marker %s in assistant text, blocks=%+v", marker, third.Blocks)
	}

	// Durable execution ledgers make the replay claim falsifiable: the stable prefix and finish run
	// exactly once, while the flaky resident handler records one failed and one successful call.
	var stableExecutions struct {
		Executions []json.RawMessage `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+stableFn+"/executions?flowrunId="+runID).OK(t, &stableExecutions)
	if len(stableExecutions.Executions) != 1 {
		t.Fatalf("replay must reuse stable prefix, got %d executions", len(stableExecutions.Executions))
	}
	var finishExecutions struct {
		Executions []json.RawMessage `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+finishFn+"/executions?flowrunId="+runID).OK(t, &finishExecutions)
	if len(finishExecutions.Executions) != 1 {
		t.Fatalf("replay must run finish exactly once after flaky recovery, got %d executions", len(finishExecutions.Executions))
	}
	var calls struct {
		Calls []struct {
			Status string `json:"status"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls?flowrunId="+runID).OK(t, &calls)
	seenCallStatus := map[string]int{}
	for _, call := range calls.Calls {
		seenCallStatus[call.Status]++
	}
	// Handler call lists use the public default keyset order (newest first), so the
	// replay success normally precedes the original failure.  The invariant here is
	// append-only auditability: exactly one failed attempt and one successful replay.
	if len(calls.Calls) != 2 || seenCallStatus["failed"] != 1 || seenCallStatus["ok"] != 1 {
		t.Fatalf("replay handler ledger must retain exactly one failed and one ok attempt: %+v", calls.Calls)
	}
}

// TestLiveManaged_SubagentFunctionFailureContinues proves the real managed nested failure path:
// a child invokes a function that raises, the failed execution is recorded against the child
// message, and the parent still completes with the failure visible instead of receiving a false
// success or an HTTP-level turn error.
func TestLiveManaged_SubagentFunctionFailureContinues(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-function-failure")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	const marker = "SUBAGENT_FUNCTION_FAILURE_8B2D"
	fnID := fnCreate(t, wc, "subagent_function_failure", fmt.Sprintf(`def explode() -> dict:
    raise RuntimeError("%s")
`, marker))
	convID := convCreate(t, wc, "managed subagent function failure")
	prompt := fmt.Sprintf(`请只派一个 general-purpose 子代理，不要在父回合直接调用其他工具。
子任务必须在子代理内部先调用 search_tools 搜索名为 run_function 的工具；等 schema 返回后，只调用 run_function 一次，参数必须逐字使用 functionId=%s 和 args={}，不要猜测或替换 functionId。
这个函数会故意失败并返回错误标记 %s。子代理不得把失败伪装成成功，必须把错误标记原样带回父回合。
父回合收到子代理结果后不要再调用任何工具，只用一句简短中文确认已经记录这次失败，并保留错误标记。`, fnID, marker)
	turn := waitTurn(t, wc, convID, sendMsg(t, wc, convID, prompt), 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed parent must complete after child function failure: status=%s code=%s message=%s blocks=%+v", turn.Status, turn.ErrorCode, turn.ErrorMessage, turn.Blocks)
	}
	parentSubagentCalls, parentDirectFunctionCalls := 0, 0
	parentSawFailure := false
	parentSawText := false
	for _, block := range turn.Blocks {
		tool, _ := block.Attrs["tool"].(string)
		switch tool {
		case "Subagent":
			if block.Type == "tool_call" {
				parentSubagentCalls++
			}
			if block.Type == "tool_result" && strings.Contains(block.Content, marker) {
				parentSawFailure = true
			}
		case "run_function":
			if block.Type == "tool_call" {
				parentDirectFunctionCalls++
			}
		}
		if block.Type == "text" && strings.Contains(block.Content, marker) {
			parentSawText = true
		}
	}
	if parentSubagentCalls != 1 || parentDirectFunctionCalls != 0 || !parentSawFailure || !parentSawText {
		t.Fatalf("parent must delegate once, surface the child failure, and continue without a direct function call: subagent=%d directFunction=%d sawFailure=%v sawText=%v blocks=%+v", parentSubagentCalls, parentDirectFunctionCalls, parentSawFailure, parentSawText, turn.Blocks)
	}

	var executions struct {
		Executions []struct {
			Status         string `json:"status"`
			TriggeredBy    string `json:"triggeredBy"`
			ConversationID string `json:"conversationId"`
			MessageID      string `json:"messageId"`
			ErrorMessage   string `json:"errorMessage"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &executions)
	if len(executions.Executions) != 1 {
		t.Fatalf("child must execute the failing function exactly once: %+v", executions.Executions)
	}
	exec := executions.Executions[0]
	if exec.Status != "failed" || exec.TriggeredBy != "agent" || exec.ConversationID != convID || exec.MessageID == "" || !strings.Contains(exec.ErrorMessage, marker) {
		t.Fatalf("child failure must be a durable agent execution tied to the conversation and marker: %+v", exec)
	}

	var messages []struct {
		SubagentID string `json:"subagentId"`
		Status     string `json:"status"`
		Blocks     []struct {
			Type    string `json:"type"`
			Content string `json:"content"`
		} `json:"blocks"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &messages)
	childFound, childSawFailure := false, false
	for _, message := range messages {
		if message.SubagentID == "" {
			continue
		}
		childFound = true
		for _, block := range message.Blocks {
			childSawFailure = childSawFailure || strings.Contains(block.Content, marker)
		}
	}
	if !childFound || !childSawFailure {
		t.Fatalf("the child failure must remain in the durable sub-message tree: found=%v sawFailure=%v messages=%+v", childFound, childSawFailure, messages)
	}
}

// TestLiveManaged_SubagentCancelTerminal proves cancellation while a real child tool is in flight:
// the parent and nested sub-message both leave streaming, the running function leaves one
// cancelled audit row, and the same conversation accepts a follow-up after the cancellation.
func TestLiveManaged_SubagentCancelTerminal(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-cancel")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	const marker = "SUBAGENT_CANCEL_STALL_5A17"
	fnID := fnCreate(t, wc, "subagent_cancel_stall", fmt.Sprintf(`import time
def stall() -> dict:
    time.sleep(60)
    return {"marker": "%s"}
`, marker))
	convID := convCreate(t, wc, "managed subagent cancel")
	prompt := fmt.Sprintf(`请只派一个 general-purpose 子代理。
子任务必须在子代理内部先调用 search_tools 搜索 run_function；等 schema 返回后，只调用一次 run_function，参数严格使用 functionId=%s 和 args={}，不要调用其他工具，也不要提前结束。这个 function 会运行约 60 秒，正在运行时父对话会发出取消。`, fnID)
	messageID := sendMsg(t, wc, convID, prompt)
	// The REST history endpoint intentionally batches nested blocks until the child turn is
	// durable; a real user cancellation arrives from the live UI/SSE path rather than waiting for
	// that history projection. Give the managed model enough time to enter the 60-second function,
	// then issue the same conversation action a user would click.
	timer := time.NewTimer(45 * time.Second)
	<-timer.C
	wc.POST("/api/v1/conversations/"+convID+":cancel", nil).OK(t, nil)

	var terminal []struct {
		ID         string `json:"id"`
		SubagentID string `json:"subagentId"`
		Status     string `json:"status"`
	}
	var lastMessagesRaw []byte
	deadline := time.Now().Add(30 * time.Second)
	settled := false
	for time.Now().Before(deadline) {
		r := wc.GET("/api/v1/conversations/" + convID + "/messages?limit=50")
		lastMessagesRaw = append(lastMessagesRaw[:0], r.Data...)
		if r.Status != 200 || json.Unmarshal(r.Data, &terminal) != nil {
			time.Sleep(100 * time.Millisecond)
			continue
		}
		parentCancelled, childCancelled := false, false
		allTerminal := true
		for _, message := range terminal {
			if message.ID == messageID {
				parentCancelled = message.Status == "cancelled"
			}
			if message.SubagentID != "" {
				childCancelled = message.Status == "cancelled"
			}
			if message.Status == "streaming" || message.Status == "pending" {
				allTerminal = false
			}
		}
		if parentCancelled && childCancelled && allTerminal {
			settled = true
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if !settled {
		t.Fatalf("parent and child leave streaming after cancel — not within 30000ms; messages=%s", string(lastMessagesRaw))
	}

	var executions struct {
		Executions []struct {
			Status      string `json:"status"`
			TriggeredBy string `json:"triggeredBy"`
			MessageID   string `json:"messageId"`
		} `json:"executions"`
	}
	harness.Eventually(t, 30000, "cancelled function leaves one audit row", func() bool {
		r := wc.GET("/api/v1/functions/" + fnID + "/executions")
		if r.Status != 200 || json.Unmarshal(r.Data, &executions) != nil {
			return false
		}
		return len(executions.Executions) == 1
	})
	if len(executions.Executions) != 1 || executions.Executions[0].Status != "cancelled" || executions.Executions[0].TriggeredBy != "agent" || executions.Executions[0].MessageID == "" {
		t.Fatalf("cancelled child function must leave one agent execution tied to a child message: %+v", executions.Executions)
	}

	followUp := waitTurn(t, wc, convID, sendMsg(t, wc, convID, "刚才的子任务已经取消。请只用一句简短中文确认对话仍可继续，不要调用工具。"), 120000)
	if followUp.Status != "completed" {
		t.Fatalf("same conversation must accept a follow-up after subagent cancel: status=%s code=%s message=%s blocks=%+v", followUp.Status, followUp.ErrorCode, followUp.ErrorMessage, followUp.Blocks)
	}
	for _, block := range followUp.Blocks {
		if block.Type == "tool_call" && block.Attrs["tool"] != nil {
			t.Fatalf("follow-up after cancellation must not resurrect the cancelled tool call: %+v", followUp.Blocks)
		}
	}
}

// TestLiveManaged_SubagentGenerateImageArtifact covers the subagent-specific multimodal seam:
// capability tools and the tool-result media expander must survive the depth-1 delegated run, and
// the parent must receive the child's managed receipt without paying for a redraw.
func TestLiveManaged_SubagentGenerateImageArtifact(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-image")
	// Parent steps are: delegate → receive the subagent result → final confirmation. The child has
	// its own loop budget; capping the parent at three stops before it can acknowledge the result.
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
		if block.Type != "tool_result" || !receiptField(block.Content, "source", "generate_image") {
			continue
		}
		count++
		if !receiptField(block.Content, "provider", "anselm") {
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

// TestLiveManaged_SubagentReadsTextAttachment proves that a parent turn's ordinary text upload
// survives delegation: the child must find the unique token (using the attachment projection or
// read_attachment), return it to the parent, and leave the source bytes untouched.
func TestLiveManaged_SubagentReadsTextAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-text-attachment")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	const token = "SUBAGENT_ATTACHMENT_6D91"
	textBytes := []byte("The delegated task has exactly one answer token: " + token + ".")
	attID := uploadAtt(t, wc, "subagent-note.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed subagent text attachment")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请派一个 general-purpose subagent。子任务必须从文字附件中找出唯一英文 token，并把 token 原样交回；父回合收到后只用一句简短中文确认，不要调用其他工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed subagent text-attachment turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" || block.Type == "tool_result" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, token) {
		t.Fatalf("managed subagent must return the attachment token to the parent: token=%q blocks=%+v", token, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("managed subagent text attachment must remain byte-identical: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_SubagentInspectsImageAttachment proves the delegated multimodal tool chain:
// the requested subagent task must be attempted, bounded inspect_media evidence must reach the
// parent (either from the child when the model honors general-purpose, or from the parent's honest
// fallback when the model selects the read-only Explore type), and the original image bytes must
// survive the nested turn. The built-in Explore whitelist intentionally excludes inspect_media;
// this route-aware assertion keeps model tool-choice variance from masquerading as a backend bug.
func TestLiveManaged_SubagentInspectsImageAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-image-attachment")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	attID := uploadAtt(t, wc, "subagent-inspect.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed subagent inspect image")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请派一个 general-purpose subagent，并把 Subagent 工具的 subagent_type 参数精确设为 general-purpose（不要选择 Explore 或 Plan）。子任务必须调用 inspect_media 工具检查图片附件 " + attID + "，question 写“描述图片中的主要颜色”，不要调用 read_attachment；工具返回后把 bounded evidence 交回，父回合收到后只用一句简短中文确认。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed subagent inspect-image turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	delegated, directInspect, childEvidence, directEvidence, answer := false, false, false, false, ""
	delegatedType := ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			if block.Attrs["tool"] == "Subagent" {
				delegated = strings.Contains(block.Content, attID)
				var args struct {
					SubagentType string `json:"subagent_type"`
				}
				if err := json.Unmarshal([]byte(block.Content), &args); err == nil {
					delegatedType = args.SubagentType
				}
			}
			if block.Attrs["tool"] == "inspect_media" {
				directInspect = strings.Contains(block.Content, attID)
			}
		case "tool_result":
			// Nested child tool results are intentionally collapsed into the parent Subagent result;
			// assert the bounded semantic evidence at that boundary rather than requiring the child's
			// internal inspect_media JSON to leak into the parent trace.
			semantic := strings.Contains(block.Content, "红色") || strings.Contains(strings.ToLower(block.Content), "red")
			childEvidence = childEvidence || (block.Attrs["tool"] == "Subagent" && semantic)
			directEvidence = directEvidence || (block.Attrs["tool"] == "inspect_media" && semantic)
		case "text":
			answer += block.Content
		}
	}
	childRouteOK := delegatedType == "general-purpose" && childEvidence
	fallbackRouteOK := delegatedType != "" && delegatedType != "general-purpose" && directInspect && directEvidence
	if !delegated || !(childRouteOK || fallbackRouteOK) || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed delegated inspect_media must return bounded evidence/continue: delegated=%v type=%q directInspect=%v childEvidence=%v directEvidence=%v answer=%q blocks=%+v", delegated, delegatedType, directInspect, childEvidence, directEvidence, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("managed subagent inspect_media must not mutate source image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_SubagentReadsPDFAttachment proves that a delegated general-purpose run can
// consume a non-native document through the same sandbox extraction tool as the parent. The child
// must return the unique token, the parent must continue, and the original PDF bytes must remain
// immutable.
func TestLiveManaged_SubagentReadsPDFAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-pdf-attachment")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	pdf := buildPDF("SUBAGENT_PDF_4E21")
	attID := uploadAtt(t, wc, "subagent-evidence.pdf", "application/pdf", pdf)
	conv := convCreate(t, wc, "managed subagent PDF attachment")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请派一个 general-purpose subagent，并把 Subagent 工具的 subagent_type 参数精确设为 general-purpose（不要选择 Explore 或 Plan）。子任务必须调用 read_attachment 工具读取 PDF 附件 " + attID + "，找出唯一英文 token SUBAGENT_PDF_4E21，不要调用 inspect_media；工具返回后把 token 原样交回，父回合收到后只用一句简短中文确认。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed subagent PDF turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	delegated, parentRead, childEvidence, answer := false, false, false, ""
	delegatedType := ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			if block.Attrs["tool"] == "Subagent" {
				delegated = strings.Contains(block.Content, attID)
				var args struct {
					SubagentType string `json:"subagent_type"`
				}
				if err := json.Unmarshal([]byte(block.Content), &args); err == nil {
					delegatedType = args.SubagentType
				}
			}
			if block.Attrs["tool"] == "read_attachment" {
				parentRead = strings.Contains(block.Content, attID)
			}
		case "tool_result":
			childEvidence = childEvidence || (block.Attrs["tool"] == "Subagent" && strings.Contains(block.Content, "SUBAGENT_PDF_4E21"))
		case "text":
			answer += block.Content
		}
	}
	if !delegated || delegatedType != "general-purpose" || !childEvidence || strings.TrimSpace(answer) == "" || parentRead {
		t.Fatalf("managed subagent PDF must delegate read_attachment and return token: delegated=%v type=%q parentRead=%v childEvidence=%v answer=%q blocks=%+v", delegated, delegatedType, parentRead, childEvidence, answer, turn.Blocks)
	}
	if !strings.Contains(answer, "SUBAGENT_PDF_4E21") {
		t.Fatalf("managed subagent PDF parent answer must contain token: answer=%q blocks=%+v", answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, pdf) {
		t.Fatalf("managed subagent PDF attachment must remain byte-identical: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_SubagentInspectsVideoAttachment proves the delegated temporal boundary: a
// general-purpose child can call inspect_media for a bounded video metadata capsule (including an
// explicit time range), return it to the parent, and leave the MP4 untouched.
func TestLiveManaged_SubagentInspectsVideoAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-video-attachment")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 5}}).OK(t, nil)
	clip := shortVideoFixture(t)
	attID := uploadAtt(t, wc, "subagent-inspect.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "managed subagent video inspect")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请派一个 general-purpose subagent，并把 Subagent 工具的 subagent_type 参数精确设为 general-purpose（不要选择 Explore 或 Plan）。子任务必须调用 inspect_media 工具检查视频附件 " + attID + "，question 写‘给出这个视频指定时间段的本地媒体元数据’，startMs 写 1000，endMs 写 2000，不要调用 read_attachment；把工具返回的 bounded metadata 原样交回，父回合收到后只用一句简短中文确认。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed subagent video inspect turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	delegated, parentInspect, childEvidence, answer := false, false, false, ""
	delegatedType := ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			if block.Attrs["tool"] == "Subagent" {
				delegated = strings.Contains(block.Content, attID)
				var args struct {
					SubagentType string `json:"subagent_type"`
				}
				if err := json.Unmarshal([]byte(block.Content), &args); err == nil {
					delegatedType = args.SubagentType
				}
			}
			if block.Attrs["tool"] == "inspect_media" {
				parentInspect = strings.Contains(block.Content, attID)
			}
		case "tool_result":
			normalized := strings.Join(strings.Fields(block.Content), "")
			childEvidence = childEvidence || (block.Attrs["tool"] == "Subagent" && strings.Contains(normalized, attID) &&
				strings.Contains(normalized, `"kind":"video"`) && strings.Contains(normalized, `"mode":"metadata"`) &&
				strings.Contains(normalized, `"startMs":1000`) && strings.Contains(normalized, `"endMs":2000`))
		case "text":
			answer += block.Content
		}
	}
	if !delegated || delegatedType != "general-purpose" || parentInspect || !childEvidence || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed subagent video must return bounded metadata from child: delegated=%v type=%q parentInspect=%v childEvidence=%v answer=%q blocks=%+v", delegated, delegatedType, parentInspect, childEvidence, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, clip) {
		t.Fatalf("managed subagent video must not mutate source MP4: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_SubagentInspectsAudioAttachment proves the audio counterpart: temporal inspect
// remains a local metadata capsule rather than fabricated transcript/scene understanding, even
// when the call is delegated to a general-purpose child.
func TestLiveManaged_SubagentInspectsAudioAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-subagent-audio-attachment")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 5}}).OK(t, nil)
	audio := harness.MockOpenAIWAV
	attID := uploadAtt(t, wc, "subagent-inspect.wav", "audio/wav", audio)
	conv := convCreate(t, wc, "managed subagent audio inspect")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请派一个 general-purpose subagent，并把 Subagent 工具的 subagent_type 参数精确设为 general-purpose（不要选择 Explore 或 Plan）。子任务必须调用 inspect_media 工具检查音频附件 " + attID + "，question 写‘给出这个音频指定时间段的本地媒体元数据’，startMs 写 1200，endMs 写 2600，不要调用 read_attachment；明确不要伪造转录，把工具返回的 bounded metadata 原样交回，父回合收到后只用一句简短中文确认。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 300000)
	if turn.Status != "completed" {
		t.Fatalf("managed subagent audio inspect turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	delegated, parentInspect, childEvidence, answer := false, false, false, ""
	delegatedType := ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			if block.Attrs["tool"] == "Subagent" {
				delegated = strings.Contains(block.Content, attID)
				var args struct {
					SubagentType string `json:"subagent_type"`
				}
				if err := json.Unmarshal([]byte(block.Content), &args); err == nil {
					delegatedType = args.SubagentType
				}
			}
			if block.Attrs["tool"] == "inspect_media" {
				parentInspect = strings.Contains(block.Content, attID)
			}
		case "tool_result":
			normalized := strings.Join(strings.Fields(block.Content), "")
			childEvidence = childEvidence || (block.Attrs["tool"] == "Subagent" && strings.Contains(normalized, attID) &&
				strings.Contains(normalized, `"kind":"audio"`) && strings.Contains(normalized, `"mode":"metadata"`) &&
				strings.Contains(normalized, `"startMs":1200`) && strings.Contains(normalized, `"endMs":2600`))
		case "text":
			answer += block.Content
		}
	}
	if !delegated || delegatedType != "general-purpose" || parentInspect || !childEvidence || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed subagent audio must return bounded metadata from child: delegated=%v type=%q parentInspect=%v childEvidence=%v answer=%q blocks=%+v", delegated, delegatedType, parentInspect, childEvidence, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, audio) {
		t.Fatalf("managed subagent audio must not mutate source WAV: HTTP %d, %d bytes", content.Status, len(content.Raw))
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_speech") {
			count++
			if !receiptField(block.Content, "provider", "anselm") {
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_speech") {
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_video") {
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_video") {
			t.Fatalf("cancelled submitted video must not leave a local tool receipt: %s", block.Content)
		}
	}
	// Give a fast provider job time to finish on the gateway. The local cancellation must remain
	// terminal and must not later backfill an attachment after the conversation has ended.
	time.Sleep(3000 * time.Millisecond)
	for _, block := range waitTurn(t, wc, conv, msg, 1000).Blocks {
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_video") {
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_video") {
			count++
			if !receiptField(block.Content, "provider", "anselm") {
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "animate_image") {
			count++
			if !receiptField(block.Content, "provider", "anselm") ||
				!receiptField(block.Content, "sourceAttachmentId", sourceID) {
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "animate_image") {
			count++
			if !receiptField(block.Content, "provider", "anselm") ||
				!receiptField(block.Content, "sourceAttachmentId", sourceID) {
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

// TestLiveManaged_DefaultChatWithTextAttachment proves the ordinary upload boundary for a plain
// text file: the managed default chat receives a labelled text part, answers from its contents,
// and leaves the content-addressed source bytes untouched without needing a tool call.
func TestLiveManaged_DefaultChatWithTextAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-text-attachment")
	const token = "DIRECT_TEXT_ATTACHMENT_7F3A"
	textBytes := []byte(strings.Repeat("ordinary text attachment context\n", 420) + token + " is the only answer token\n" + strings.Repeat("ordinary trailing context\n", 420))
	attID := uploadAtt(t, wc, "direct-note.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed text attachment")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请从附件中找出唯一的英文 token，只输出该 token，不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed text attachment chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, token) {
		t.Fatalf("managed text attachment answer must contain the extracted token, got %q", answer)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("managed text attachment must survive direct projection unchanged: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_DefaultChatWithTextAndImageAttachments proves a mixed ordinary upload turn:
// a text file and an image are projected together in one managed user message, the model can use
// the text evidence without a tool call, and both original attachment byte streams remain intact.
func TestLiveManaged_DefaultChatWithTextAndImageAttachments(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-text-image-attachments")
	const token = "MIXED_TEXT_IMAGE_7F3A"
	textBytes := []byte("This note accompanies the image. The only answer token is " + token + ".")
	textID := uploadAtt(t, wc, "mixed-note.txt", "text/plain", textBytes)
	imageID := uploadAtt(t, wc, "mixed-image.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed text and image attachments")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请从混合附件中找出文本里的唯一英文 token，只输出该 token，不要调用工具。",
		"attachmentIds": []string{textID, imageID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed mixed text-image chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, token) {
		t.Fatalf("managed mixed text-image answer must contain the text token, got %q", answer)
	}
	for _, tc := range []struct {
		id   string
		want []byte
	}{
		{id: textID, want: textBytes},
		{id: imageID, want: liveManagedPNG},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("managed mixed text-image turn must preserve %s: HTTP %d, %d bytes", tc.id, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_ListAttachments proves the discovery half of the attachment tool contract:
// the managed model must call list_attachments, receive metadata for every active upload, and
// continue the same turn without reading or mutating the underlying bytes.
func TestLiveManaged_ListAttachments(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-list-attachments")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	textBytes := []byte("LIST_ATTACHMENT_TOKEN_7F3A")
	textID := uploadAtt(t, wc, "discovery-note.txt", "text/plain", textBytes)
	imageID := uploadAtt(t, wc, "discovery-image.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed list attachments")
	msg := sendMsg(t, wc, conv,
		"必须调用 list_attachments 工具发现当前工作区的附件，不要调用其他工具；工具返回后用一句话确认已发现 discovery-note.txt 和 discovery-image.png。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed list_attachments turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, listed, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "list_attachments" || strings.Contains(block.Content, "list_attachments")
		case "tool_result":
			listed = listed || (strings.Contains(block.Content, textID) && strings.Contains(block.Content, imageID) &&
				strings.Contains(block.Content, "discovery-note.txt") && strings.Contains(block.Content, "discovery-image.png") &&
				strings.Contains(block.Content, `"count"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !listed || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed list_attachments must discover/return metadata/continue: called=%v listed=%v answer=%q blocks=%+v", called, listed, answer, turn.Blocks)
	}
	for _, tc := range []struct {
		id   string
		want []byte
	}{
		{id: textID, want: textBytes},
		{id: imageID, want: liveManagedPNG},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("list_attachments must not mutate %s: HTTP %d, %d bytes", tc.id, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_InspectMediaImage proves the nested real vision path: the outer managed model
// calls inspect_media, the tool's internal vision request completes through the deployed gateway,
// and only bounded JSON evidence is returned to the parent conversation.
func TestLiveManaged_InspectMediaImage(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-image")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	attID := uploadAtt(t, wc, "inspect-evidence.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed inspect image")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查附件 "+attID+"，question 写“描述图片中的主要颜色”，不要调用 read_attachment；工具返回后用一句话总结。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media image turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, evidence, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || strings.Contains(block.Content, "inspect_media") || block.Attrs["tool"] == "inspect_media"
		case "tool_result":
			evidence = evidence || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"answer"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !evidence || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed inspect_media must call/return bounded evidence/continue: called=%v evidence=%v answer=%q blocks=%+v", called, evidence, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("inspect_media must not mutate the source image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaImageCropDetail proves the user-facing local-derivative controls
// survive the managed model boundary: crop and high detail must reach inspect_media, the nested
// vision helper must inspect only that bounded derivative, and the original bytes remain intact.
func TestLiveManaged_InspectMediaImageCropDetail(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-image-crop")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	attID := uploadAtt(t, wc, "inspect-crop.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed inspect image crop")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查附件 "+attID+"，question 写‘描述裁剪区域的主要颜色’，crop 使用归一化 x=0.25、y=0.25、width=0.5、height=0.5，detail 写 high；不要调用 read_attachment。工具返回后用一句话总结。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media image crop turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, evidence, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			evidence = evidence || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"detail":"high"`) &&
				strings.Contains(block.Content, `"crop"`) && strings.Contains(block.Content, `"answer"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !evidence || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed inspect_media image crop must preserve crop/detail/continue: called=%v evidence=%v answer=%q blocks=%+v", called, evidence, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("inspect_media crop must not mutate the source image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaImageTiles proves the large-image escape hatch: the managed model
// must request tiles=true, receive a compact deterministic tile map without a nested vision call,
// and continue the outer turn while preserving the original image bytes.
func TestLiveManaged_InspectMediaImageTiles(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-image-tiles")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	attID := uploadAtt(t, wc, "inspect-tiles.png", "image/png", liveManagedAnimationPNG)
	conv := convCreate(t, wc, "managed inspect image tiles")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查图片附件 "+attID+"，question 写‘给出图片分块地图’，tiles 写 true，tileRows 写 2，tileCols 写 3；不要调用其他工具。工具返回后用一句话确认已得到 tile map。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media image tiles turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, tiles, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			tiles = tiles || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"tileRows":2`) &&
				strings.Contains(block.Content, `"tileCols":3`) && strings.Contains(block.Content, `"tiles"`) && strings.Contains(block.Content, `"usage"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !tiles || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed inspect_media image tiles must call/return map/continue: called=%v tiles=%v answer=%q blocks=%+v", called, tiles, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedAnimationPNG) {
		t.Fatalf("inspect_media tiles must not mutate source image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaVideo proves the temporal boundary honestly: inspect_media returns
// a bounded local metadata capsule for a real MP4, without pretending that a text-only metadata
// probe produced transcript, scenes, or raw-video understanding.
func TestLiveManaged_InspectMediaVideo(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-video")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) {
		t.Fatalf("inspect_media video fixture must be a valid MP4: %d bytes", len(clip))
	}
	attID := uploadAtt(t, wc, "inspect-video.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "managed inspect video")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查视频附件 "+attID+"，question 写“给出这个视频的本地媒体元数据”，不要调用其他工具；工具返回后用一句话说明它没有做转录。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media video turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, capsule, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			capsule = capsule || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"kind":"video"`) && strings.Contains(block.Content, `"usage"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !capsule || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed inspect_media video must call/return metadata/continue: called=%v capsule=%v answer=%q blocks=%+v", called, capsule, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, clip) {
		t.Fatalf("inspect_media must not mutate the source video: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaVideoTimeRange proves the managed tool path preserves an explicit
// temporal request instead of silently falling back to the whole-file metadata capsule.
func TestLiveManaged_InspectMediaVideoTimeRange(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-video-range")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	clip := shortVideoFixture(t)
	attID := uploadAtt(t, wc, "inspect-video-range.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "managed inspect video range")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查视频附件 "+attID+"，question 写‘给出这个视频指定时间段的本地媒体元数据’，startMs 写 1000，endMs 写 2000；不要调用其他工具。工具返回后用一句话确认时间范围已保留。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media video range turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, capsule, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			capsule = capsule || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"kind":"video"`) &&
				strings.Contains(block.Content, `"startMs":1000`) && strings.Contains(block.Content, `"endMs":2000`) &&
				strings.Contains(block.Content, `"mode":"metadata"`) && strings.Contains(block.Content, `"usage"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !capsule || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed inspect_media video range must preserve range/continue: called=%v capsule=%v answer=%q blocks=%+v", called, capsule, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, clip) {
		t.Fatalf("inspect_media video range must not mutate source video: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaAudio is the audio counterpart: ordinary chat does not advertise
// native audio perception, but inspect_media still provides a truthful local metadata capsule.
func TestLiveManaged_InspectMediaAudio(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-audio")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	attID := uploadAtt(t, wc, "inspect-audio.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "managed inspect audio")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查音频附件 "+attID+"，question 写“给出这个音频的本地媒体元数据”，不要调用其他工具；工具返回后用一句话说明它没有做转录。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media audio turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, capsule, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			capsule = capsule || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"kind":"audio"`) && strings.Contains(block.Content, `"usage"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !capsule || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed inspect_media audio must call/return metadata/continue: called=%v capsule=%v answer=%q blocks=%+v", called, capsule, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, harness.MockOpenAIWAV) {
		t.Fatalf("inspect_media must not mutate the source audio: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaAudioTimeRange proves the audio branch preserves an explicit
// temporal request in the same truthful metadata-only contract as video.
func TestLiveManaged_InspectMediaAudioTimeRange(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-audio-range")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	attID := uploadAtt(t, wc, "inspect-audio-range.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "managed inspect audio range")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查音频附件 "+attID+"，question 写‘给出这个音频指定时间段的本地媒体元数据’，startMs 写 1200，endMs 写 2600；不要调用其他工具。工具返回后用一句话确认时间范围已保留。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media audio range turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, capsule, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			capsule = capsule || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"kind":"audio"`) &&
				strings.Contains(block.Content, `"startMs":1200`) && strings.Contains(block.Content, `"endMs":2600`) &&
				strings.Contains(block.Content, `"mode":"metadata"`) && strings.Contains(block.Content, `"usage"`))
		case "text":
			answer += block.Content
		}
	}
	if !called || !capsule || strings.TrimSpace(answer) == "" {
		t.Fatalf("managed inspect_media audio range must preserve range/continue: called=%v capsule=%v answer=%q blocks=%+v", called, capsule, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, harness.MockOpenAIWAV) {
		t.Fatalf("inspect_media audio range must not mutate source audio: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaTextQuery proves the local bounded evidence path for a large text
// attachment: inspect_media must honor query mode, return compact evidence, and continue the outer
// managed turn without invoking a second tool or dumping the document body.
func TestLiveManaged_InspectMediaTextQuery(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-text-query")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	const token = "INSPECT_QUERY_7F3A"
	textBytes := []byte(strings.Repeat("document context line for bounded inspect\n", 1500) + token + " appears exactly once\n" + strings.Repeat("document tail line\n", 1500))
	attID := uploadAtt(t, wc, "inspect-query.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed inspect text query")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查附件 "+attID+"，question 写‘找到唯一 token’，query 精确写 "+token+"，contextChars 写 64，maxMatches 写 1，不要调用 read_attachment；工具返回后只回复 token。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media text query turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, bounded, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			bounded = bounded || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"mode":"query"`) &&
				strings.Contains(block.Content, token) && len(block.Content) < 5000)
		case "text":
			answer += block.Content
		}
	}
	if !called || !bounded || !strings.Contains(answer, token) {
		t.Fatalf("managed inspect_media text query must query/bound/continue: called=%v bounded=%v answer=%q blocks=%+v", called, bounded, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("inspect_media text query must not mutate source text: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaTextPage proves the document/page branch returns a compact
// extracted page through the managed tool loop, preserving page and limit intent.
func TestLiveManaged_InspectMediaTextPage(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-text-page")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	const token = "INSPECT_PAGE_TOKEN_7F3A"
	textBytes := []byte("# Page 1\n" + strings.Repeat("first page context\n", 300) + "# Page 2\n" + token + " appears on page two\n" + strings.Repeat("second page bounded context\n", 300))
	attID := uploadAtt(t, wc, "inspect-page.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed inspect text page")
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查附件 "+attID+"，question 写‘找到第 2 页 token’，page 写 2，limitChars 写 128，不要调用 read_attachment；工具返回后只回复 token。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media text page turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, page, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			page = page || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, token) &&
				strings.Contains(block.Content, `"mode":"page"`) && strings.Contains(block.Content, `"page":2`) &&
				strings.Contains(block.Content, `"limitChars":128`) && len(block.Content) < 5000)
		case "text":
			answer += block.Content
		}
	}
	if !called || !page || !strings.Contains(answer, token) {
		t.Fatalf("managed inspect_media must return bounded page/continue: called=%v page=%v answer=%q blocks=%+v", called, page, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("inspect_media page must not mutate source text: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_InspectMediaTextWindow proves inspect_media's offset window branch remains
// distinct from page/query mode while still returning bounded evidence through managed tooling.
func TestLiveManaged_InspectMediaTextWindow(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-inspect-text-window")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)
	prefix := strings.Repeat("window prefix line\n", 900)
	const token = "INSPECT_WINDOW_TOKEN_7F3A"
	textBytes := []byte(prefix + token + " appears at the window offset\n" + strings.Repeat("window tail line\n", 1800))
	attID := uploadAtt(t, wc, "inspect-window.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed inspect text window")
	offset := len(prefix)
	msg := sendMsg(t, wc, conv,
		"必须调用 inspect_media 工具检查附件 "+attID+"，question 写‘找到窗口 token’，offset 写 "+fmt.Sprint(offset)+"，limitChars 写 96，不要调用 read_attachment；工具返回后只回复 token。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed inspect_media text window turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, window, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "inspect_media" || strings.Contains(block.Content, "inspect_media")
		case "tool_result":
			window = window || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, token) &&
				strings.Contains(block.Content, `"mode":"window"`) && strings.Contains(block.Content, fmt.Sprintf(`"offset":%d`, offset)) &&
				strings.Contains(block.Content, `"limitChars":96`) && len(block.Content) < 5000)
		case "text":
			answer += block.Content
		}
	}
	if !called || !window || !strings.Contains(answer, token) {
		t.Fatalf("managed inspect_media must return bounded window/continue: called=%v window=%v answer=%q blocks=%+v", called, window, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("inspect_media window must not mutate source text: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_DefaultChatWithPDFAttachment proves the managed model's non-native document
// route: the default Anselm capability intentionally does not advertise NativeDocs, so a PDF must
// be extracted in the sandbox and its text made available to the real managed conversation.
func TestLiveManaged_DefaultChatWithPDFAttachment(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-pdf-input")
	var caps []struct {
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		NativeDocs bool   `json:"nativeDocs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	found := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if cap.NativeDocs {
				t.Fatalf("managed default must keep the non-native PDF extraction contract: %+v", cap)
			}
			found = true
			break
		}
	}
	if !found {
		t.Fatal("managed default capability row anselm-auto not found")
	}

	pdf := buildPDF("PDFTOKEN_7F3A")
	attID := uploadAtt(t, wc, "managed-evidence.pdf", "application/pdf", pdf)
	conv := convCreate(t, wc, "managed PDF input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请从 PDF 中找出唯一的英文 token，只输出该 token，不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed PDF chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, "PDFTOKEN_7F3A") {
		t.Fatalf("managed PDF answer must contain the extracted token, got %q", answer)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, pdf) {
		t.Fatalf("managed PDF attachment must survive extraction unchanged: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_DefaultChatWithPDFAndImageAttachments proves that a non-native PDF's sandbox
// extraction can coexist with a native vision part in one ordinary managed turn. The extracted
// document token must remain answerable while the image route completes and neither source changes.
func TestLiveManaged_DefaultChatWithPDFAndImageAttachments(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-pdf-image-fusion")
	var caps []struct {
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		NativeDocs bool   `json:"nativeDocs"`
		Vision     bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if cap.NativeDocs || !cap.Vision {
				t.Fatalf("managed default must expose vision but keep PDF extraction non-native for mixed input: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Fatal("managed default capability row anselm-auto not found")
	}

	pdf := buildPDF("PDF_IMAGE_FUSION_6A4C")
	pdfID := uploadAtt(t, wc, "fusion-evidence.pdf", "application/pdf", pdf)
	imageID := uploadAtt(t, wc, "fusion-evidence.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed PDF and image fusion")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请从 PDF 中找出唯一的英文 token，只输出该 token；同时确认图片已收到，不要调用工具。",
		"attachmentIds": []string{pdfID, imageID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed PDF-image fusion chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, "PDF_IMAGE_FUSION_6A4C") {
		t.Fatalf("managed PDF-image fusion answer must contain the extracted token, got %q", answer)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "pdf", id: pdfID, want: pdf},
		{name: "image", id: imageID, want: liveManagedPNG},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("managed PDF-image %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_ReadAttachmentPDF proves the tool-mediated document path separately from the
// direct attachment projection: the real managed model must call read_attachment for a PDF, the
// shared extractor must return the token as a tool result, and the parent turn must continue.
func TestLiveManaged_ReadAttachmentPDF(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-read-attachment-pdf")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	pdf := buildPDF("PDFTOOL_7F3A")
	attID := uploadAtt(t, wc, "tool-evidence.pdf", "application/pdf", pdf)
	conv := convCreate(t, wc, "managed read PDF tool")
	msg := sendMsg(t, wc, conv,
		"必须调用 read_attachment 工具读取附件 "+attID+"，从 PDF 找出唯一 token，然后只回复这个 token；不要调用其他工具。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed read_attachment PDF turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, result, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || strings.Contains(block.Content, "read_attachment")
		case "tool_result":
			result = result || strings.Contains(block.Content, "PDFTOOL_7F3A")
		case "text":
			answer += block.Content
		}
	}
	if !called || !result || !strings.Contains(answer, "PDFTOOL_7F3A") {
		t.Fatalf("managed read_attachment PDF must call/extract/continue: called=%v result=%v answer=%q blocks=%+v", called, result, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, pdf) {
		t.Fatalf("read_attachment must not mutate the source PDF: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_ReadAttachmentLargeTextQuery proves the bounded search contract on a large
// text upload: the model must use query mode instead of asking the tool to dump the full body,
// receive the unique match with total-size metadata, and continue the parent turn.
func TestLiveManaged_ReadAttachmentLargeTextQuery(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-read-attachment-large-query")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	const token = "LARGE_READ_QUERY_7F3A"
	textBytes := []byte(strings.Repeat("background context line for bounded attachment search\n", 1800) + token + " appears exactly once near the tail\n" + strings.Repeat("trailing context line\n", 1800))
	attID := uploadAtt(t, wc, "large-query.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed large read query")
	msg := sendMsg(t, wc, conv,
		"必须调用 read_attachment 工具读取附件 "+attID+"；id 使用该附件，query 精确写 "+token+"，contextChars 写 64，maxMatches 写 1，不要调用其他工具。工具返回后只回复找到的 token。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed large read_attachment turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, bounded, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "read_attachment" || strings.Contains(block.Content, "read_attachment")
		case "tool_result":
			bounded = bounded || (strings.Contains(block.Content, "read_attachment search") && strings.Contains(block.Content, token) &&
				strings.Contains(block.Content, "totalChars=") && len(block.Content) < 5000)
		case "text":
			answer += block.Content
		}
	}
	if !called || !bounded || !strings.Contains(answer, token) {
		t.Fatalf("managed large read_attachment must query/bound/continue: called=%v bounded=%v answer=%q blocks=%+v", called, bounded, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("large read_attachment query must not mutate source text: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_ReadAttachmentLargeTextIndex proves the managed model can request the compact
// index explicitly instead of dumping a large text attachment; the body sentinel must stay out of
// the tool result while the parent turn continues.
func TestLiveManaged_ReadAttachmentLargeTextIndex(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-read-attachment-large-index")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	const token = "INDEX_BODY_SECRET_7F3A"
	textBytes := []byte(strings.Repeat("index body line for compact preview\n", 1000) + token + " appears in the body\n" + strings.Repeat("index tail line\n", 5000))
	attID := uploadAtt(t, wc, "large-index.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed large read index")
	msg := sendMsg(t, wc, conv,
		"必须调用 read_attachment 工具读取附件 "+attID+"，id 使用该附件，index 写 true，只要返回紧凑索引不要读取正文；不要调用其他工具。工具返回后只回复‘索引已返回’。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed large read_attachment index turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, compact, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "read_attachment" || strings.Contains(block.Content, "read_attachment")
		case "tool_result":
			compact = compact || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"chunks"`) &&
				strings.Contains(block.Content, `"totalChars"`) && strings.Contains(block.Content, `"usage"`) &&
				!strings.Contains(block.Content, token) && len(block.Content) < 12000)
		case "text":
			answer += block.Content
		}
	}
	if !called || !compact || !strings.Contains(answer, "索引") {
		t.Fatalf("managed large read_attachment must return compact index/continue: called=%v compact=%v answer=%q blocks=%+v", called, compact, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("large read_attachment index must not mutate source text: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_ReadAttachmentLargeTextAutoIndex proves the default safety boundary for a
// large text upload: when the caller omits index/page/query controls, read_attachment must still
// return a compact index rather than dumping the full body into the managed context.
func TestLiveManaged_ReadAttachmentLargeTextAutoIndex(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-read-attachment-large-auto-index")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	const token = "AUTO_INDEX_BODY_SECRET_7F3A"
	textBytes := []byte(strings.Repeat("auto-index body line for default safety\n", 1200) + token + " appears in the body\n" + strings.Repeat("auto-index tail line\n", 5200))
	attID := uploadAtt(t, wc, "large-auto-index.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed large read auto index")
	msg := sendMsg(t, wc, conv,
		"必须调用 read_attachment 工具读取附件 "+attID+"；id 使用该附件，不要传 index、offset、limitChars 或 query 参数，只要返回紧凑索引，不要读取正文；不要调用其他工具。工具返回后只回复‘默认索引已返回’。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed read_attachment auto-index turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, compact, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "read_attachment" || strings.Contains(block.Content, "read_attachment")
		case "tool_result":
			compact = compact || (strings.Contains(block.Content, attID) && strings.Contains(block.Content, `"chunks"`) &&
				strings.Contains(block.Content, `"totalChars"`) && strings.Contains(block.Content, `"usage"`) &&
				!strings.Contains(block.Content, token) && len(block.Content) < 12000)
		case "text":
			answer += block.Content
		}
	}
	if !called || !compact || !strings.Contains(answer, "索引") {
		t.Fatalf("managed read_attachment default must auto-index/continue: called=%v compact=%v answer=%q blocks=%+v", called, compact, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("large read_attachment auto-index must not mutate source text: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveManaged_ReadAttachmentTextPage proves the managed model can follow a bounded page
// request with an explicit offset/limitChars and receive the unique token without dumping the
// rest of the attachment.
func TestLiveManaged_ReadAttachmentTextPage(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-read-attachment-page")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 3}}).OK(t, nil)
	prefix := strings.Repeat("page prefix line for bounded read\n", 1200)
	const token = "PAGE_READ_TOKEN_7F3A"
	textBytes := []byte(prefix + token + " appears at the requested page start\n" + strings.Repeat("page tail line\n", 2500))
	attID := uploadAtt(t, wc, "page-read.txt", "text/plain", textBytes)
	conv := convCreate(t, wc, "managed read attachment page")
	offset := len(prefix)
	msg := sendMsg(t, wc, conv,
		"必须调用 read_attachment 工具读取附件 "+attID+"；id 使用该附件，offset 写 "+fmt.Sprint(offset)+"，limitChars 写 128，只返回这个 bounded page；不要调用其他工具。工具返回后只回复找到的 token。")
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed read_attachment page turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	called, page, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			called = called || block.Attrs["tool"] == "read_attachment" || strings.Contains(block.Content, "read_attachment")
		case "tool_result":
			page = page || (strings.Contains(block.Content, token) &&
				strings.Contains(block.Content, fmt.Sprintf("offset=%d", offset)) && strings.Contains(block.Content, "chars=128") &&
				strings.Contains(block.Content, "totalChars=") && len(block.Content) < 5000)
		case "text":
			answer += block.Content
		}
	}
	if !called || !page || !strings.Contains(answer, token) {
		t.Fatalf("managed read_attachment must return bounded page/continue: called=%v page=%v answer=%q blocks=%+v", called, page, answer, turn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, textBytes) {
		t.Fatalf("read_attachment page must not mutate source text: HTTP %d, %d bytes", content.Status, len(content.Raw))
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

// TestLiveManaged_DefaultChatWithVideoAndUnsupportedAudio keeps the supported video branch alive
// when a user drops a WAV in the same ordinary chat turn. Video must still select the managed
// video route; chat audio remains an explicit text downgrade rather than poisoning the request.
func TestLiveManaged_DefaultChatWithVideoAndUnsupportedAudio(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-video-unsupported-audio")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Video    bool   `json:"video"`
		Audio    bool   `json:"audio"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" {
			if !cap.Video || cap.Audio {
				t.Fatalf("managed default must expose video but not chat audio for mixed downgrade: %+v", cap)
			}
			ready = true
			break
		}
	}
	if !ready {
		t.Fatal("managed default capability row anselm-auto not found")
	}

	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("managed MP4 fixture must be valid and within the published 3MiB decoded budget: %d bytes", len(clip))
	}
	videoID := uploadAtt(t, wc, "mixed.mp4", "video/mp4", clip)
	audioID := uploadAtt(t, wc, "mixed.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "managed video and unsupported audio")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认视频已收到，并说明语音附件会如何处理。不要调用工具。",
		"attachmentIds": []string{videoID, audioID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed video+unsupported-audio turn must complete via honest degrade: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "video", id: videoID, want: clip},
		{name: "audio", id: audioID, want: harness.MockOpenAIWAV},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("mixed %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
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

// TestLiveManaged_DefaultChatWithTextAndVideoAttachments proves another mixed ordinary upload
// shape: a labelled text file and an MP4 share one managed user turn, the text evidence remains
// answerable, and the video lease does not poison the request or mutate either source.
func TestLiveManaged_DefaultChatWithTextAndVideoAttachments(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-text-video-attachments")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Video    bool   `json:"video"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" && cap.Video {
			ready = true
			break
		}
	}
	if !ready {
		t.Fatalf("managed default must advertise video before accepting text+video: %+v", caps)
	}
	const token = "MIXED_TEXT_VIDEO_7F3A"
	textBytes := []byte("The companion note contains the only answer token: " + token + ".")
	textID := uploadAtt(t, wc, "video-note.txt", "text/plain", textBytes)
	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("managed MP4 fixture must be valid and within the published 3MiB decoded budget: %d bytes", len(clip))
	}
	videoID := uploadAtt(t, wc, "mixed-note.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "managed text and video attachments")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请从文字附件中找出唯一英文 token，只输出该 token；同时确认视频已收到，不要调用工具。",
		"attachmentIds": []string{textID, videoID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed mixed text-video chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, token) {
		t.Fatalf("managed mixed text-video answer must contain the text token, got %q", answer)
	}
	for _, tc := range []struct {
		id   string
		want []byte
	}{
		{id: textID, want: textBytes},
		{id: videoID, want: clip},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("managed mixed text-video turn must preserve %s: HTTP %d, %d bytes", tc.id, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_DefaultChatWithTextAndUnsupportedAudio proves that a text answer remains
// available when the same ordinary turn also carries a chat-audio attachment the managed model
// does not advertise. The unsupported audio must degrade independently and neither source may be
// rewritten while the gateway assembles the mixed request.
func TestLiveManaged_DefaultChatWithTextAndUnsupportedAudio(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-text-unsupported-audio")
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
	const token = "MIXED_TEXT_AUDIO_9C2D"
	textBytes := []byte("The companion note contains the only answer token: " + token + ".")
	textID := uploadAtt(t, wc, "audio-note.txt", "text/plain", textBytes)
	audioID := uploadAtt(t, wc, "voice-note.wav", "audio/wav", harness.MockOpenAIWAV)
	conv := convCreate(t, wc, "managed text and unsupported audio attachments")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请从文字附件中找出唯一英文 token，只输出该 token；同时说明语音附件会如何处理。不要调用工具。",
		"attachmentIds": []string{textID, audioID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		t.Fatalf("managed mixed text-unsupported-audio chat must complete via honest degrade: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, token) {
		t.Fatalf("managed mixed text-audio answer must contain the text token, got %q", answer)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "text", id: textID, want: textBytes},
		{name: "audio", id: audioID, want: harness.MockOpenAIWAV},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("managed mixed %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_DefaultChatWithTextImageAndVideoAttachments proves the three-way ordinary
// upload shape: a text answer, a vision part, and an MP4 video all share one managed turn. The
// text evidence must remain answerable while both media branches stay native and byte-stable.
func TestLiveManaged_DefaultChatWithTextImageAndVideoAttachments(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-text-image-video-attachments")
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
		t.Fatalf("managed default must advertise vision+video before accepting text+image+video: %+v", caps)
	}

	const token = "TRIPLE_TEXT_IMAGE_VIDEO_4B7E"
	textBytes := []byte("The companion note contains the only answer token: " + token + ".")
	textID := uploadAtt(t, wc, "triple-note.txt", "text/plain", textBytes)
	imageID := uploadAtt(t, wc, "triple-note.png", "image/png", liveManagedPNG)
	clip := shortVideoFixture(t)
	if !bytes2IsMP4(clip) || len(clip) > 3*1024*1024 {
		t.Fatalf("managed MP4 fixture must be valid and within the published 3MiB decoded budget: %d bytes", len(clip))
	}
	videoID := uploadAtt(t, wc, "triple-note.mp4", "video/mp4", clip)
	conv := convCreate(t, wc, "managed text image and video attachments")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请从文字附件中找出唯一英文 token，只输出该 token；同时确认图片和视频都已收到，不要调用工具。",
		"attachmentIds": []string{textID, imageID, videoID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed text-image-video fusion chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	answer := ""
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if !strings.Contains(answer, token) {
		t.Fatalf("managed text-image-video answer must contain the text token, got %q", answer)
	}
	for _, tc := range []struct {
		name string
		id   string
		want []byte
	}{
		{name: "text", id: textID, want: textBytes},
		{name: "image", id: imageID, want: liveManagedPNG},
		{name: "video", id: videoID, want: clip},
	} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+tc.id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, tc.want) {
			t.Fatalf("managed triple %s attachment must remain byte-identical: HTTP %d, %d bytes", tc.name, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_DefaultChatWithMultipleImageAttachments proves the common screenshot-comparison
// shape on the managed route: two distinct image attachments share one user turn and both survive
// the gateway's media staging/lease path without degrading the conversation.
func TestLiveManaged_DefaultChatWithMultipleImageAttachments(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-multiple-image-attachments")
	var caps []struct {
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	ready := false
	for _, cap := range caps {
		if cap.Provider == "anselm" && cap.ModelID == "anselm-auto" && cap.Vision {
			ready = true
			break
		}
	}
	if !ready {
		t.Fatalf("managed default must advertise vision before accepting multiple images: %+v", caps)
	}
	firstID := uploadAtt(t, wc, "compare-first.png", "image/png", liveManagedPNG)
	secondID := uploadAtt(t, wc, "compare-second.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed multiple images")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认两张图片都已收到，不要调用工具。",
		"attachmentIds": []string{firstID, secondID},
	})
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		t.Fatalf("managed multiple-image turn must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	for _, id := range []string{firstID, secondID} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+id+"/content", "", nil)
		if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
			t.Fatalf("managed image attachment %s must remain byte-identical: HTTP %d, %d bytes", id, content.Status, len(content.Raw))
		}
	}
}

// TestLiveManaged_DeletedAttachmentDegradesInHistory proves the stale-history boundary: deleting
// an attachment after one completed turn must make the next turn honest and recoverable, rather
// than replaying a missing media blob into a gateway 400 or silently poisoning the conversation.
func TestLiveManaged_DeletedAttachmentDegradesInHistory(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-deleted-attachment-history")
	attID := uploadAtt(t, wc, "will-delete.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed deleted attachment history")
	first := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认已收到这张图片，不要调用工具。",
		"attachmentIds": []string{attID},
	})
	firstTurn := waitTurn(t, wc, conv, first, 180000)
	if firstTurn.Status != "completed" {
		t.Fatalf("initial managed image turn must complete before deletion: status=%s code=%s message=%s", firstTurn.Status, firstTurn.ErrorCode, firstTurn.ErrorMessage)
	}
	if deleted := wc.DELETE("/api/v1/attachments/" + attID); deleted.Status != 204 {
		t.Fatalf("attachment delete must return 204, got %d code=%s body=%s", deleted.Status, deleted.Code, deleted.Raw)
	}
	if gone := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); gone.Status != 404 {
		t.Fatalf("deleted attachment content must be unavailable, got HTTP %d", gone.Status)
	}
	second := sendMsg(t, wc, conv, "继续对话。请用一句话确认你可以继续回答，即使上一轮图片已被删除。不要调用工具。")
	secondTurn := waitTurn(t, wc, conv, second, 180000)
	if secondTurn.Status != "completed" {
		t.Fatalf("managed follow-up after deleted attachment must complete honestly: status=%s code=%s message=%s", secondTurn.Status, secondTurn.ErrorCode, secondTurn.ErrorMessage)
	}
}

// TestLiveManaged_AttachmentHistoryReprojection proves a normal multi-turn media conversation:
// the second user message omits attachmentIds, so the chat history loader must re-project the
// first turn's image through the managed lease path and still complete the follow-up.
func TestLiveManaged_AttachmentHistoryReprojection(t *testing.T) {
	wc := liveManagedWorkspace(t, "live-managed-attachment-history-reprojection")
	attID := uploadAtt(t, wc, "history-image.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "managed attachment history reprojection")
	first := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认已收到图片，第一轮不要调用工具。",
		"attachmentIds": []string{attID},
	})
	firstTurn := waitTurn(t, wc, conv, first, 180000)
	if firstTurn.Status != "completed" {
		t.Fatalf("initial managed history image turn must complete: status=%s code=%s message=%s", firstTurn.Status, firstTurn.ErrorCode, firstTurn.ErrorMessage)
	}
	second := sendMsg(t, wc, conv, "继续此对话，请用一句话确认你仍能处理上一轮图片。不要调用工具。")
	secondTurn := waitTurn(t, wc, conv, second, 180000)
	if secondTurn.Status != "completed" {
		t.Fatalf("managed image history follow-up must complete: status=%s code=%s message=%s", secondTurn.Status, secondTurn.ErrorCode, secondTurn.ErrorMessage)
	}
	answer := ""
	for _, block := range secondTurn.Blocks {
		if block.Type == "text" {
			answer += block.Content
		}
	}
	if strings.TrimSpace(answer) == "" {
		t.Fatalf("managed image history follow-up must contain assistant text: %+v", secondTurn.Blocks)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("reprojected history image must remain byte-identical: HTTP %d, %d bytes", content.Status, len(content.Raw))
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

// TestLiveBYOK_OpenAIImageRetryPreservesNativeHistory proves the user-facing regenerate path for
// a multimodal turn. The retry creates a new assistant version without creating a second user row;
// both real OpenAI-compatible requests must still carry the original image part, otherwise a
// visually grounded answer silently becomes a text-only retry.
//
// TestLiveBYOK_OpenAIImageRetryPreservesNativeHistory 覆盖多模态回合的真实“重新生成”：重试只铸造
// 新 assistant 版本、不重复 user 行；两次真实 OpenAI-compatible 请求都必须携带原始图片 part，
// 否则一次视觉回答会静默退化成纯文本重试。
func TestLiveBYOK_OpenAIImageRetryPreservesNativeHistory(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK retry acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.openai.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-image-retry"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-image-retry", "key": key,
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
	ready := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" && cap.Vision {
			ready = true
			break
		}
	}
	if !ready {
		t.Skip("current followed OpenAI catalog does not expose gpt-4.1-mini vision capability; retry reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	attID := uploadAtt(t, wc, "retry-input.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "OpenAI image retry")
	first := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认收到了图片。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	firstTurn := waitTurn(t, wc, conv, first, 180000)
	if firstTurn.Status != "completed" {
		t.Fatalf("OpenAI image source turn must complete: status=%s code=%s message=%s", firstTurn.Status, firstTurn.ErrorCode, firstTurn.ErrorMessage)
	}

	regenerated := retryPost(t, wc, conv, "")
	regeneratedTurn := waitTurn(t, wc, conv, regenerated, 180000)
	if regeneratedTurn.Status != "completed" {
		t.Fatalf("OpenAI image regenerate turn must complete: status=%s code=%s message=%s", regeneratedTurn.Status, regeneratedTurn.ErrorCode, regeneratedTurn.ErrorMessage)
	}

	msgs := retryList(t, wc, conv)
	users, assistantVersions := 0, make([]retryMsg, 0, 2)
	for _, msg := range msgs {
		if msg.Role == "user" {
			users++
		}
		if msg.Role == "assistant" {
			assistantVersions = append(assistantVersions, msg)
		}
	}
	if users != 1 || len(assistantVersions) != 2 {
		t.Fatalf("image regenerate must keep one user row and append one assistant version: users=%d assistants=%d messages=%+v", users, len(assistantVersions), msgs)
	}
	var oldAnswer, newAnswer retryMsg
	for _, msg := range assistantVersions {
		if msg.retryOf() == "" {
			oldAnswer = msg
		} else {
			newAnswer = msg
		}
	}
	if oldAnswer.ID == "" || newAnswer.ID == "" || newAnswer.ID != regenerated || newAnswer.retryOf() != oldAnswer.ID || oldAnswer.SupersededBy != newAnswer.ID {
		t.Fatalf("image regenerate version chain must point newest→oldest and oldest→newest: old=%+v new=%+v returned=%s", oldAnswer, newAnswer, regenerated)
	}

	encoded := base64.StdEncoding.EncodeToString(liveManagedPNG)
	chatCalls := 0
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		chatCalls++
		if !bytes.Contains(call.Body, []byte(`"image_url"`)) || !bytes.Contains(call.Body, []byte(encoded)) {
			t.Fatalf("every OpenAI image retry request must carry the exact native image part: call=%d bytes=%d", chatCalls, len(call.Body))
		}
	}
	if chatCalls != 2 {
		t.Fatalf("image source + regenerate must make exactly two upstream chat requests, got %d", chatCalls)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("retry must leave the source image byte-identical: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
}

// TestLiveBYOK_OpenAIImageEditResendPreservesAttachment covers the other retry branch: editing
// the user's wording replaces both the user and assistant rows, but the attachment snapshot is
// deliberately carried to the new user version and rendered again for the real provider.
//
// TestLiveBYOK_OpenAIImageEditResendPreservesAttachment 覆盖另一条重试分支：编辑用户文字会替换
// user+assistant 两行，但附件快照必须带到新 user 版本，并在真实 provider 请求里再次渲染。
func TestLiveBYOK_OpenAIImageEditResendPreservesAttachment(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK edit-resend acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.openai.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-image-edit-resend"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-image-edit", "key": key,
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
	ready := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == "gpt-4.1-mini" && cap.Vision {
			ready = true
			break
		}
	}
	if !ready {
		t.Skip("current followed OpenAI catalog does not expose gpt-4.1-mini vision capability; edit-resend reprobe is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": "gpt-4.1-mini"}).OK(t, nil)

	attID := uploadAtt(t, wc, "edit-resend-input.png", "image/png", liveManagedPNG)
	conv := convCreate(t, wc, "OpenAI image edit resend")
	first := sendWith(t, wc, conv, map[string]any{
		"content":       "ORIGINAL-IMAGE-QUESTION：请简短确认收到图片。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	firstTurn := waitTurn(t, wc, conv, first, 180000)
	if firstTurn.Status != "completed" {
		if firstTurn.ErrorCode == "LLM_RATE_LIMITED" {
			t.Skip("OpenAI provider rate-limited the edit-resend live sample; structured LLM_RATE_LIMITED classification verified")
		}
		t.Fatalf("OpenAI image source turn must complete before edit-resend: status=%s code=%s message=%s", firstTurn.Status, firstTurn.ErrorCode, firstTurn.ErrorMessage)
	}

	editedAssistant := retryPost(t, wc, conv, "EDITED-IMAGE-QUESTION：请改用一句更短的中文确认收到图片。")
	editedTurn := waitTurn(t, wc, conv, editedAssistant, 180000)
	if editedTurn.Status != "completed" {
		if editedTurn.ErrorCode == "LLM_RATE_LIMITED" {
			t.Skip("OpenAI provider rate-limited the edit-resend continuation; structured LLM_RATE_LIMITED classification verified")
		}
		t.Fatalf("OpenAI image edit-resend turn must complete: status=%s code=%s message=%s", editedTurn.Status, editedTurn.ErrorCode, editedTurn.ErrorMessage)
	}

	msgs := retryList(t, wc, conv)
	oldQuestion := retryFind(t, msgs, "ORIGINAL-IMAGE-QUESTION：请简短确认收到图片。不要调用工具。")
	newQuestion := retryFind(t, msgs, "EDITED-IMAGE-QUESTION：请改用一句更短的中文确认收到图片。")
	if oldQuestion.SupersededBy != newQuestion.ID || newQuestion.retryOf() != oldQuestion.ID {
		t.Fatalf("edit-resend user version chain must point old↔new: old=%+v new=%+v", oldQuestion, newQuestion)
	}
	var oldAnswer, newAnswer retryMsg
	for _, msg := range msgs {
		if msg.Role != "assistant" {
			continue
		}
		if msg.retryOf() == "" {
			oldAnswer = msg
		} else {
			newAnswer = msg
		}
	}
	if oldAnswer.ID == "" || newAnswer.ID == "" || newAnswer.ID != editedAssistant || newAnswer.retryOf() != oldAnswer.ID || oldAnswer.SupersededBy != newAnswer.ID {
		t.Fatalf("edit-resend assistant version chain must point old↔new: old=%+v new=%+v returned=%s", oldAnswer, newAnswer, editedAssistant)
	}

	encoded := base64.StdEncoding.EncodeToString(liveManagedPNG)
	chatCalls := 0
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		chatCalls++
		if !bytes.Contains(call.Body, []byte(`"image_url"`)) || !bytes.Contains(call.Body, []byte(encoded)) {
			t.Fatalf("every OpenAI edit-resend request must carry the exact original image part: call=%d bytes=%d", chatCalls, len(call.Body))
		}
	}
	if chatCalls != 2 {
		t.Fatalf("image source + edit-resend must make exactly two upstream chat requests, got %d", chatCalls)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, liveManagedPNG) {
		t.Fatalf("edit-resend must leave the source image byte-identical: HTTP %d, %d bytes", content.Status, len(content.Raw))
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

// TestLiveBYOK_OpenAIPDFInput proves the OpenAI-native document lane end to end: the PDF is
// uploaded through Anselm, survives the conversation unchanged, and reaches the real OpenAI wire
// as a `file` part with inline file_data rather than extracted prompt prose.
func TestLiveBYOK_OpenAIPDFInput(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK PDF acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires OPENAI_API_KEY; key material is never logged")
	}

	rec := harness.NewRecorder(t, "https://api.openai.com")
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-openai-pdf-input"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-byok-pdf", "key": key,
		"baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	const model = "gpt-4.1-mini"
	var caps []struct {
		APIKeyID   string `json:"apiKeyId"`
		Provider   string `json:"provider"`
		ModelID    string `json:"modelId"`
		NativeDocs bool   `json:"nativeDocs"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	nativeDocs := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "openai" && cap.ModelID == model && cap.NativeDocs {
			nativeDocs = true
			break
		}
	}
	if !nativeDocs {
		t.Skip("probed OpenAI BYOK account/catalog does not currently expose native PDF input for gpt-4.1-mini")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": model}).OK(t, nil)

	pdf := buildPDF("PDFLIVE alpha")
	attID := uploadAtt(t, wc, "native-evidence.pdf", "application/pdf", pdf)
	conv := convCreate(t, wc, "BYOK OpenAI PDF input")
	msg := sendWith(t, wc, conv, map[string]any{
		"content":       "请简短确认收到了 PDF。不要调用工具。",
		"attachmentIds": []string{attID},
	})
	turn := waitTurn(t, wc, conv, msg, 180000)
	if turn.Status != "completed" {
		if turn.ErrorCode == "LLM_RATE_LIMITED" {
			t.Logf("OpenAI BYOK PDF lane reached the provider's current rate window: %s", turn.ErrorMessage)
			t.Skip("OpenAI provider rate-limited this live PDF sample; structured LLM_RATE_LIMITED classification verified")
		}
		t.Fatalf("OpenAI BYOK PDF chat must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, pdf) {
		t.Fatalf("uploaded PDF must survive the OpenAI BYOK turn unchanged: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}

	dumps := rec.DumpsFor(model)
	if len(dumps) == 0 {
		t.Fatal("BYOK PDF turn produced no recorded OpenAI request")
	}
	wire := `"file_data":"data:application/pdf;base64,` + base64.StdEncoding.EncodeToString(pdf) + `"`
	for _, dump := range dumps {
		if strings.Contains(string(dump.Raw), `"type":"file"`) && strings.Contains(string(dump.Raw), wire) {
			return
		}
	}
	t.Fatal("BYOK PDF never reached OpenAI as the exact native file part")
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

// TestLiveBYOK_DeepSeekToolContinuation exercises the second half of the DeepSeek compatibility
// contract that a text-only smoke cannot prove: an OpenAI-compatible model must preserve the
// assistant tool call, the function result, and the next assistant sampling on the real wire. The
// recorder is only an observation proxy; the function still runs in Anselm's real sandbox and the
// managed gateway remains absent from this BYOK-only workspace.
//
// TestLiveBYOK_DeepSeekToolContinuation 覆盖 DeepSeek 兼容契约中纯文本 smoke 证明不了的后半段：
// OpenAI-compatible 模型必须在真实线缆上保住 assistant tool call、函数结果和下一次 assistant
// sampling。recorder 只是观察代理；函数仍在 Anselm 真 sandbox 执行，这个 BYOK-only workspace
// 也没有受管 gateway 兜底。
func TestLiveBYOK_DeepSeekToolContinuation(t *testing.T) {
	if os.Getenv("EVALS_BYOK") != "1" {
		t.Skip("set EVALS_BYOK=1 to run the real-provider BYOK product acceptance")
	}
	key := os.Getenv("DEEPSEEK_API_KEY")
	if key == "" {
		t.Skip("EVALS_BYOK=1 requires DEEPSEEK_API_KEY; key material is never logged")
	}

	srv := harness.Start(t)
	c := srv.Client(t)
	rec := harness.NewRecorder(t, "https://api.deepseek.com")
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "live-byok-deepseek-tool-continuation"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "deepseek", "displayName": "live-deepseek-byok-tool", "key": key,
		"baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	const modelID = "deepseek-v4-flash"
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Tools    bool   `json:"tools"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	toolReady := false
	for _, cap := range caps {
		if cap.APIKeyID == keyID && cap.Provider == "deepseek" && cap.ModelID == modelID && cap.Tools {
			toolReady = true
			break
		}
	}
	if !toolReady {
		t.Skip("current DeepSeek account/catalog does not expose deepseek-v4-flash tools; continuation is not constructible")
	}
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": modelID}).OK(t, nil)
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	fnID := fnCreate(t, wc, "deepseek_eval_square", "def deepseek_eval_square(n: int) -> dict:\n    return {\"square\": n * n}\n")
	harness.Eventually(t, 30000, "the DeepSeek continuation function environment becomes ready", func() bool {
		var detail struct {
			ActiveVersion struct {
				EnvStatus string `json:"envStatus"`
			} `json:"activeVersion"`
		}
		wc.GET("/api/v1/functions/"+fnID).OK(t, &detail)
		return detail.ActiveVersion.EnvStatus == "ready"
	})

	conv := convCreate(t, wc, "DeepSeek BYOK tool continuation")
	msg := sendMsg(t, wc, conv,
		"请调用 deepseek_eval_square，参数 n=12。不要自己计算；工具返回后报告结果。")
	turn := waitTurn(t, wc, conv, msg, 240000)
	if turn.Status != "completed" {
		if turn.ErrorCode == "LLM_RATE_LIMITED" {
			t.Logf("DeepSeek BYOK tool continuation reached the provider's current rate window: %s", turn.ErrorMessage)
			t.Skip("DeepSeek provider rate-limited this live sample; structured LLM_RATE_LIMITED classification verified")
		}
		t.Fatalf("DeepSeek BYOK tool continuation must complete: status=%s code=%s message=%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	toolCall, toolResult, answer := false, false, ""
	for _, block := range turn.Blocks {
		switch block.Type {
		case "tool_call":
			toolCall = toolCall || strings.Contains(block.Content, fnID) || strings.Contains(block.Content, "deepseek_eval_square")
		case "tool_result":
			toolResult = toolResult || strings.Contains(block.Content, "deepseek_eval_square") || strings.Contains(block.Content, `"square":144`)
		case "text":
			answer += block.Content
		}
	}

	chatCalls := 0
	seenTools, seenToolCalls, seenToolResult := false, false, false
	for _, call := range rec.Calls() {
		if !strings.Contains(call.Path, "/chat/completions") {
			continue
		}
		chatCalls++
		seenTools = seenTools || bytes.Contains(call.Body, []byte(`"tools"`))
		seenToolCalls = seenToolCalls || bytes.Contains(call.Body, []byte(`"tool_calls"`))
		// DeepSeek's compatible request is the evidence, not a provider-specific role spelling:
		// the result payload is escaped inside the historical message list and its stable function
		// output markers survive that encoding. Requiring a literal `role:"tool"` or unescaped JSON
		// quotes here would make the
		// product acceptance depend on one serializer detail while the real continuation already
		// proves that the tool result crossed the boundary.
		seenToolResult = seenToolResult || (bytes.Contains(call.Body, []byte("square")) && bytes.Contains(call.Body, []byte(`144`)))
	}
	if !toolCall || !toolResult || !strings.Contains(answer, "144") || chatCalls < 2 || !seenTools || !seenToolCalls || !seenToolResult {
		for _, call := range rec.Calls() {
			if strings.Contains(call.Path, "/chat/completions") {
				t.Logf("DeepSeek provider call path=%s bytes=%d has_tools=%v has_tool_calls=%v has_square=%v has_144=%v",
					call.Path, len(call.Body), bytes.Contains(call.Body, []byte(`"tools"`)),
					bytes.Contains(call.Body, []byte(`"tool_calls"`)), bytes.Contains(call.Body, []byte("square")),
					bytes.Contains(call.Body, []byte(`144`)))
			}
		}
		t.Fatalf("DeepSeek tool continuation lost call/result/text or OpenAI-compatible wire: call=%v result=%v answer=%q chatCalls=%d tools=%v toolCalls=%v toolResult=%v blocks=%+v",
			toolCall, toolResult, answer, chatCalls, seenTools, seenToolCalls, seenToolResult, turn.Blocks)
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
		if recovered.ErrorCode == "LLM_RATE_LIMITED" {
			t.Logf("Google stale-model recovery reached the provider's current rate window: %s", recovered.ErrorMessage)
			t.Skip("Google provider rate-limited the recovery send; stale-model 404 classification was verified")
		}
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
		if block.Type == "tool_result" && receiptField(block.Content, "source", "generate_image") {
			callCount++
			if !receiptField(block.Content, "provider", "anselm") {
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
