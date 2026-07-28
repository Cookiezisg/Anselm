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
}
