// live_hybrid_workflow_test.go — the real mixed workflow seam: managed generation upstream,
// BYOK vision consumption downstream. The downstream recorder makes the pixel hand-off observable
// without pretending that the deployed gateway exposes its provider wire to the desktop.
package scenarios

import (
	"bytes"
	"encoding/base64"
	"os"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestLiveHybrid_WorkflowManagedImageToOpenAIViewer proves the workflow variant of the mixed
// ownership contract. The upstream agent calls the managed-only generate_image tool; a separate
// downstream agent is pinned to a real OpenAI BYOK key behind a transparent recorder. The final
// assertion is on that downstream request: it must contain the exact bytes stored for the managed
// attachment as a native image part, not merely the upstream receipt text.
func TestLiveHybrid_WorkflowManagedImageToOpenAIViewer(t *testing.T) {
	if os.Getenv("EVALS_HYBRID") != "1" {
		t.Skip("set EVALS_HYBRID=1 (and EVALS_MANAGED=1) for the real mixed workflow acceptance")
	}
	key := os.Getenv("OPENAI_API_KEY")
	if key == "" {
		t.Skip("EVALS_HYBRID=1 requires OPENAI_API_KEY; key material is never logged")
	}

	wc := liveManagedWorkspace(t, "live-hybrid-workflow-managed-to-openai")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
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
		t.Fatal("hybrid workflow requires the provisioned managed key")
	}

	byokKeyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "live-openai-workflow-viewer", "key": key,
		"baseUrl": rec.URL() + "/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+byokKeyID+":test", nil).OK(t, nil)

	const viewerModel = "gpt-4.1-mini"
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	viewerReady := false
	for _, cap := range caps {
		if cap.APIKeyID == byokKeyID && cap.Provider == "openai" && cap.ModelID == viewerModel && cap.Vision {
			viewerReady = true
			break
		}
	}
	if !viewerReady {
		t.Fatalf("workflow viewer requires a real BYOK vision capability: %+v", caps)
	}

	var ws struct {
		DefaultAgent *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultAgent"`
	}
	wc.GET("/api/v1/workspaces/"+wc.WorkspaceID()).OK(t, &ws)
	if ws.DefaultAgent == nil || ws.DefaultAgent.ModelID == "" {
		t.Fatalf("managed workflow painter requires a default agent model: %+v", ws.DefaultAgent)
	}
	managedModel := ws.DefaultAgent.ModelID
	if ws.DefaultAgent.APIKeyID != managedKeyID {
		// Make the ownership boundary explicit even if onboarding defaults change later.
		wc.PUT("/api/v1/workspaces/"+wc.WorkspaceID()+"/default-models/agent",
			map[string]any{"apiKeyId": managedKeyID, "modelId": managedModel}).OK(t, nil)
	}

	painter := agCreate(t, wc, map[string]any{
		"name":          "Managed Workflow Painter",
		"description":   "generates one managed image and hands its receipt to a BYOK viewer",
		"prompt":        "请调用 generate_image 恰好一次，画一个白底红色圆形；工具成功后把工具 receipt 原样写进最终回答，不要再次调用工具。",
		"tools":         []map[string]any{{"ref": "sys:generate_image", "name": "generate image"}},
		"modelOverride": map[string]any{"apiKeyId": managedKeyID, "modelId": managedModel},
	})
	viewer := agCreate(t, wc, map[string]any{
		"name":        "OpenAI Workflow Viewer",
		"description": "receives the managed image over a BYOK vision route",
		"prompt":      "用一句简短中文确认你收到上游图像。不要调用工具。",
		"modelOverride": map[string]any{
			"apiKeyId": byokKeyID,
			"modelId":  viewerModel,
		},
	})
	wfID := wfCreate(t, wc, "managed_to_byok_workflow_media", []map[string]any{
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
		t.Fatalf("managed-to-BYOK workflow must complete: status=%s nodes=%s", status, nodes)
	}
	nodeText := string(nodes)
	// The receipt lives inside the agent result's text, so the workflow node envelope escapes its
	// JSON quotes. Assert on the semantic fields rather than one particular escaping layer.
	if !strings.Contains(nodeText, "generate_image") || !strings.Contains(nodeText, "provider") || !strings.Contains(nodeText, "anselm") {
		t.Fatalf("upstream workflow result must preserve the managed generation receipt: %s", nodeText)
	}
	attID := attIDShape.FindString(nodeText)
	if attID == "" {
		t.Fatalf("workflow result must carry a MediaRef attachment id: %s", nodeText)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) || len(content.Raw) < 1000 {
		t.Fatalf("managed workflow artifact must be a real image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}

	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	seen := false
	for _, dump := range rec.DumpsFor(viewerModel) {
		if dump.HasImagePart(b64) {
			seen = true
			break
		}
	}
	if !seen {
		t.Fatal("BYOK workflow viewer never received the managed image bytes as a native image part")
	}
}

// TestLiveHybrid_WorkflowManagedImageToGoogleViewer is the same ownership boundary through
// Gemini's native contents/parts dialect. The OpenAI-compatible lane above cannot prove this:
// Google receives inlineData, puts the model in the path, and has its own request envelope.
func TestLiveHybrid_WorkflowManagedImageToGoogleViewer(t *testing.T) {
	if os.Getenv("EVALS_HYBRID") != "1" {
		t.Skip("set EVALS_HYBRID=1 (and EVALS_MANAGED=1) for the real mixed workflow acceptance")
	}
	key := os.Getenv("GEMINI_API_KEY")
	if key == "" {
		t.Skip("EVALS_HYBRID=1 requires GEMINI_API_KEY; key material is never logged")
	}

	wc := liveManagedWorkspace(t, "live-hybrid-workflow-managed-to-google")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	rec := harness.NewRecorder(t, "https://generativelanguage.googleapis.com")

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
		t.Fatal("hybrid workflow requires the provisioned managed key")
	}

	byokKeyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "google", "displayName": "live-google-workflow-viewer", "key": key,
		"baseUrl": rec.URL() + "/v1beta",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+byokKeyID+":test", nil).OK(t, nil)

	const viewerModel = "gemini-3-flash-preview"
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Vision   bool   `json:"vision"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	viewerReady := false
	for _, cap := range caps {
		if cap.APIKeyID == byokKeyID && cap.Provider == "google" && cap.ModelID == viewerModel && cap.Vision {
			viewerReady = true
			break
		}
	}
	if !viewerReady {
		t.Fatalf("workflow viewer requires a real BYOK Gemini vision capability: %+v", caps)
	}

	var ws struct {
		DefaultAgent *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultAgent"`
	}
	wc.GET("/api/v1/workspaces/"+wc.WorkspaceID()).OK(t, &ws)
	if ws.DefaultAgent == nil || ws.DefaultAgent.ModelID == "" {
		t.Fatalf("managed workflow painter requires a default agent model: %+v", ws.DefaultAgent)
	}
	managedModel := ws.DefaultAgent.ModelID
	if ws.DefaultAgent.APIKeyID != managedKeyID {
		wc.PUT("/api/v1/workspaces/"+wc.WorkspaceID()+"/default-models/agent",
			map[string]any{"apiKeyId": managedKeyID, "modelId": managedModel}).OK(t, nil)
	}

	painter := agCreate(t, wc, map[string]any{
		"name":          "Managed Workflow Painter",
		"description":   "generates one managed image and hands its receipt to a Gemini viewer",
		"prompt":        "请调用 generate_image 恰好一次，画一个白底红色圆形；工具成功后把工具 receipt 原样写进最终回答，不要再次调用工具。",
		"tools":         []map[string]any{{"ref": "sys:generate_image", "name": "generate image"}},
		"modelOverride": map[string]any{"apiKeyId": managedKeyID, "modelId": managedModel},
	})
	viewer := agCreate(t, wc, map[string]any{
		"name":        "Gemini Workflow Viewer",
		"description": "receives the managed image over a native Gemini vision route",
		"prompt":      "用一句简短中文确认你收到上游图像。不要调用工具。",
		"modelOverride": map[string]any{
			"apiKeyId": byokKeyID,
			"modelId":  viewerModel,
		},
	})
	wfID := wfCreate(t, wc, "managed_to_google_workflow_media", []map[string]any{
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
		t.Fatalf("managed-to-Google workflow must complete: status=%s nodes=%s", status, nodes)
	}
	nodeText := string(nodes)
	if !strings.Contains(nodeText, "generate_image") || !strings.Contains(nodeText, "provider") || !strings.Contains(nodeText, "anselm") {
		t.Fatalf("upstream workflow result must preserve the managed generation receipt: %s", nodeText)
	}
	attID := attIDShape.FindString(nodeText)
	if attID == "" {
		t.Fatalf("workflow result must carry a MediaRef attachment id: %s", nodeText)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) || len(content.Raw) < 1000 {
		t.Fatalf("managed workflow artifact must be a real image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}

	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	seen := false
	for _, call := range rec.Calls() {
		if strings.Contains(call.Path, "streamGenerateContent") &&
			bytes.Contains(call.Body, []byte(`"inlineData"`)) && bytes.Contains(call.Body, []byte(b64)) {
			seen = true
			break
		}
	}
	if !seen {
		t.Fatal("native Gemini workflow viewer never received the managed image bytes as inlineData")
	}
}

// TestLiveHybrid_WorkflowManagedSpeechToQwenViewer covers the audio branch of the same workflow
// contract. The downstream Qwen model uses the OpenAI-compatible input_audio vocabulary, but its
// capability comes from a different catalog family than OpenAI; this is a real audio MediaRef
// expansion, not another image alias.
func TestLiveHybrid_WorkflowManagedSpeechToQwenViewer(t *testing.T) {
	if os.Getenv("EVALS_HYBRID") != "1" {
		t.Skip("set EVALS_HYBRID=1 (and EVALS_MANAGED=1) for the real mixed workflow acceptance")
	}
	key := os.Getenv("QWEN_API_KEY")
	if key == "" {
		t.Skip("EVALS_HYBRID=1 requires QWEN_API_KEY; key material is never logged")
	}

	wc := liveManagedWorkspace(t, "live-hybrid-workflow-managed-to-qwen-audio")
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 2}}).OK(t, nil)
	rec := harness.NewRecorder(t, "https://dashscope-intl.aliyuncs.com")

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
		t.Fatal("hybrid workflow requires the provisioned managed key")
	}

	byokKeyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "qwen", "displayName": "live-qwen-workflow-viewer", "key": key,
		"baseUrl": rec.URL() + "/compatible-mode/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+byokKeyID+":test", nil).OK(t, nil)

	const viewerModel = "qwen3-omni-flash"
	var caps []struct {
		APIKeyID string `json:"apiKeyId"`
		Provider string `json:"provider"`
		ModelID  string `json:"modelId"`
		Audio    bool   `json:"audio"`
	}
	wc.GET("/api/v1/model-capabilities").OK(t, &caps)
	viewerReady := false
	for _, cap := range caps {
		if cap.APIKeyID == byokKeyID && cap.Provider == "qwen" && cap.ModelID == viewerModel && cap.Audio {
			viewerReady = true
			break
		}
	}
	if !viewerReady {
		t.Fatalf("workflow viewer requires a real BYOK Qwen audio capability: %+v", caps)
	}

	var ws struct {
		DefaultAgent *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultAgent"`
	}
	wc.GET("/api/v1/workspaces/"+wc.WorkspaceID()).OK(t, &ws)
	if ws.DefaultAgent == nil || ws.DefaultAgent.ModelID == "" {
		t.Fatalf("managed workflow painter requires a default agent model: %+v", ws.DefaultAgent)
	}
	managedModel := ws.DefaultAgent.ModelID
	if ws.DefaultAgent.APIKeyID != managedKeyID {
		wc.PUT("/api/v1/workspaces/"+wc.WorkspaceID()+"/default-models/agent",
			map[string]any{"apiKeyId": managedKeyID, "modelId": managedModel}).OK(t, nil)
	}

	painter := agCreate(t, wc, map[string]any{
		"name":          "Managed Workflow Speaker",
		"description":   "generates one managed WAV and hands its receipt to a Qwen viewer",
		"prompt":        "请调用 generate_speech 恰好一次，把‘海内存知己’读出来；工具成功后把工具 receipt 原样写进最终回答，不要再次调用工具。",
		"tools":         []map[string]any{{"ref": "sys:generate_speech", "name": "generate speech"}},
		"modelOverride": map[string]any{"apiKeyId": managedKeyID, "modelId": managedModel},
	})
	viewer := agCreate(t, wc, map[string]any{
		"name":        "Qwen Workflow Listener",
		"description": "receives the managed WAV over a BYOK Qwen audio route",
		"prompt":      "用一句简短中文确认你收到上游音频。不要调用工具。",
		"modelOverride": map[string]any{
			"apiKeyId": byokKeyID,
			"modelId":  viewerModel,
		},
	})
	wfID := wfCreate(t, wc, "managed_to_qwen_workflow_audio", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "speak", "kind": "agent", "ref": painter,
			"input": map[string]any{"task": "start.topic"}}},
		{"op": "add_node", "node": map[string]any{"id": "listen", "kind": "agent", "ref": viewer,
			"input": map[string]any{"audio": "speak.text"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "speak"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "speak", "to": "listen"}},
	})

	_, status, nodes := runAndWait(t, wc, wfID, map[string]any{"topic": "read the short Chinese sentence"}, 360000)
	if status != "completed" {
		t.Fatalf("managed-to-Qwen audio workflow must complete: status=%s nodes=%s", status, nodes)
	}
	nodeText := string(nodes)
	if !strings.Contains(nodeText, "generate_speech") || !strings.Contains(nodeText, "provider") || !strings.Contains(nodeText, "anselm") {
		t.Fatalf("upstream workflow result must preserve the managed speech receipt: %s", nodeText)
	}
	attID := attIDShape.FindString(nodeText)
	if attID == "" {
		t.Fatalf("workflow result must carry an audio MediaRef attachment id: %s", nodeText)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsWAV(content.Raw) || len(content.Raw) < 4000 {
		t.Fatalf("managed workflow artifact must be real WAV audio: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}

	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	seen := false
	for _, call := range rec.Calls() {
		if strings.Contains(call.Path, "/chat/completions") &&
			bytes.Contains(call.Body, []byte(`"input_audio"`)) && bytes.Contains(call.Body, []byte(b64)) {
			seen = true
			break
		}
	}
	if !seen {
		t.Fatal("BYOK Qwen workflow viewer never received the managed WAV bytes as native input_audio")
	}
}
