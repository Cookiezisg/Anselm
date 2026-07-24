package golden

// This is C2's billable opt-in black-box acceptance. Unit tests freeze Qwen's request JSON;
// this test proves a real regional key, the Qwen adapter, attachment ingestion, and a tool
// continuation agree end to end. It is never run by the ordinary eval target.

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

func TestGolden_C2_QwenMultimodalInputAndToolContinuation(t *testing.T) {
	if os.Getenv("EVALS_QWEN_MULTIMODAL") != "1" {
		t.Skip("set EVALS_QWEN_MULTIMODAL=1 to run the billable Qwen C2 golden")
	}
	if got := firstNonEmpty(os.Getenv("EVALS_PROVIDER"), "deepseek"); got != "qwen" {
		t.Fatalf("Qwen C2 golden requires EVALS_PROVIDER=qwen, got %q", got)
	}
	fixtures := materializeQwenFixtures(t)
	wc := evalWS(t, "dialogue")
	visual := firstNonEmpty(os.Getenv("QWEN_EVAL_VISUAL_MODEL"), "qwen3.7-plus")
	omni := firstNonEmpty(os.Getenv("QWEN_EVAL_OMNI_MODEL"), "qwen3.5-omni-plus")

	assertQwenAttachmentTurn(t, wc, fixtures, "text-screenshot.png", "image/png", visual,
		"Read the large heading and six-digit number in this image. State both.")
	assertQwenAttachmentTurn(t, wc, fixtures, "short.mp4", "video/mp4", visual,
		"Summarize the main visible action in this short video.")
	assertQwenAttachmentTurn(t, wc, fixtures, "speech.wav", "audio/wav", omni,
		"Transcribe the spoken audio and preserve its language.")

	wc.POST("/api/v1/functions", map[string]any{
		"name": "qwen_eval_square", "description": "Return the square of a supplied integer.",
		"code": "def qwen_eval_square(n: int) -> dict:\n    return {\"square\": n * n}\n",
	}).OK(t, nil)
	conv := newConv(t, wc, "golden: qwen tool continuation")
	setQwenConversationModel(t, wc, conv, visual)
	messageID := wc.POST("/api/v1/conversations/"+conv+"/messages", map[string]any{
		"content": "Use qwen_eval_square now with n=12. Do not calculate it yourself: call the tool, then report its returned square.",
	}).Field(t, "id")
	turn := waitGoldenAssistant(t, wc, conv, messageID, 180_000)
	answer := requireCleanQwenTurn(t, "tool continuation", turn)
	if !hasGoldenBlock(turn, "tool_call") || !hasGoldenBlock(turn, "tool_result") {
		t.Fatalf("Qwen did not continue after tool execution; blocks=%+v", turn.Blocks)
	}
	if !strings.Contains(answer, "144") {
		t.Fatalf("Qwen tool continuation did not report the returned square: %q", answer)
	}
}

func assertQwenAttachmentTurn(t *testing.T, wc *harness.Client, fixtures, filename, mime, model, prompt string) {
	t.Helper()
	data, err := os.ReadFile(filepath.Join(fixtures, filename))
	if err != nil {
		t.Fatalf("read %s: %v", filename, err)
	}
	attachmentID := wc.Upload(t, "/api/v1/attachments", filename, mime, data).OK(t, nil).Field(t, "id")
	conv := newConv(t, wc, "golden: qwen "+filename)
	setQwenConversationModel(t, wc, conv, model)
	messageID := wc.POST("/api/v1/conversations/"+conv+"/messages", map[string]any{
		"content": prompt, "attachmentIds": []string{attachmentID},
	}).Field(t, "id")
	requireCleanQwenTurn(t, filename, waitGoldenAssistant(t, wc, conv, messageID, 240_000))
}

func setQwenConversationModel(t *testing.T, wc *harness.Client, convID, model string) {
	t.Helper()
	var keys []struct {
		ID       string `json:"id"`
		Provider string `json:"provider"`
	}
	wc.GET("/api/v1/api-keys").OK(t, &keys)
	for _, key := range keys {
		if key.Provider == "qwen" {
			wc.PATCH("/api/v1/conversations/"+convID, map[string]any{
				"modelOverride": map[string]any{"apiKeyId": key.ID, "modelId": model},
			}).OK(t, nil)
			return
		}
	}
	t.Fatal("Qwen eval workspace has no qwen API-key row")
}

func waitGoldenAssistant(t *testing.T, wc *harness.Client, convID, messageID string, timeoutMS int) evalMsg {
	t.Helper()
	var terminal evalMsg
	harness.Eventually(t, timeoutMS, "Qwen assistant turn reaches terminal", func() bool {
		drainInteractions(wc, convID)
		var messages []evalMsg
		wc.GET("/api/v1/conversations/"+convID+"/messages?limit=80").OK(t, &messages)
		for _, message := range messages {
			if message.ID == messageID && message.Status != "pending" && message.Status != "streaming" {
				terminal = message
				return true
			}
		}
		return false
	})
	return terminal
}

func requireCleanQwenTurn(t *testing.T, label string, turn evalMsg) string {
	t.Helper()
	if turn.Status == "error" || turn.ErrorCode != "" {
		t.Fatalf("Qwen %s failed: status=%s code=%s blocks=%+v", label, turn.Status, turn.ErrorCode, turn.Blocks)
	}
	var answer strings.Builder
	for _, block := range turn.Blocks {
		if block.Type == "text" {
			answer.WriteString(block.Content)
		}
	}
	if strings.TrimSpace(answer.String()) == "" {
		t.Fatalf("Qwen %s completed without text: blocks=%+v", label, turn.Blocks)
	}
	return answer.String()
}

func hasGoldenBlock(turn evalMsg, want string) bool {
	for _, block := range turn.Blocks {
		if block.Type == want {
			return true
		}
	}
	return false
}

func materializeQwenFixtures(t *testing.T) string {
	t.Helper()
	if dir := strings.TrimSpace(os.Getenv("EVALS_FIXTURE_DIR")); dir != "" {
		for _, name := range []string{"text-screenshot.png", "short.mp4", "speech.wav"} {
			if _, err := os.Stat(filepath.Join(dir, name)); err != nil {
				t.Fatalf("EVALS_FIXTURE_DIR missing %s: %v", name, err)
			}
		}
		return dir
	}
	out := t.TempDir()
	cmd := exec.Command("go", "run", "./fixtures/cmd/materialize", "-out", out)
	cmd.Dir = goldenTestendRoot(t)
	if logs, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("materialize Qwen fixtures: %v\n%s", err, strings.TrimSpace(string(logs)))
	}
	return out
}

func goldenTestendRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "fixtures", "cmd", "materialize", "main.go")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("could not locate testend fixture materializer")
		}
		dir = parent
	}
}
