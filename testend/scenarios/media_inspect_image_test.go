package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestInspectMedia_ImageUsesVisionAndReturnsBoundedEvidence proves the image-specific inspect
// route is a nested model call with the right separation: the internal vision request carries an
// image part, while the outer chat receives only a small JSON answer/evidence object.
func TestInspectMedia_ImageUsesVisionAndReturnsBoundedEvidence(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	attID := uploadAtt(t, wc, "inspect.png", "image/png", tinyPNG)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "search_tools", Args: fw(map[string]any{"query": "inspect_media"})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "inspect_media", Args: fw(map[string]any{
			"attachmentId": attID, "question": "what is visible?", "detail": "high",
		})}}},
		// This response is consumed by inspect_media's internal vision Generate call, not by the
		// outer conversation turn.
		harness.LLMTurn{Text: "bounded vision answer"},
		harness.LLMTurn{Text: "inspect finished"},
	)
	convID := convCreate(t, wc, "image inspect")
	turn := waitTurn(t, wc, convID, sendMsg(t, wc, convID, "请检查图片并简短回答"), 30000)
	if turn.Status != "completed" {
		t.Fatalf("image inspect turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	dumps := mock.WaitDumps(t, dlgModel, 4, 10000)
	visionWire := false
	var evidence struct {
		AttachmentID string `json:"attachmentId"`
		Mime         string `json:"mime"`
		Width        int    `json:"width"`
		Height       int    `json:"height"`
		Detail       string `json:"detail"`
		Answer       string `json:"answer"`
	}
	foundEvidence := false
	for _, dump := range dumps {
		if strings.Contains(string(dump.Raw), "image_url") && strings.Contains(string(dump.Raw), "data:image/") {
			visionWire = true
		}
		for _, msg := range dump.Messages {
			if msg.Role != "tool" || !strings.Contains(msg.Content, attID) {
				continue
			}
			if err := json.Unmarshal([]byte(msg.Content), &evidence); err != nil {
				t.Fatalf("inspect_media image result must be JSON evidence: %v content=%q", err, msg.Content)
			}
			foundEvidence = true
		}
	}
	if !visionWire {
		t.Fatal("inspect_media image route never sent a native image_url/data URL to its vision model")
	}
	if !foundEvidence || evidence.AttachmentID != attID || evidence.Mime == "" || evidence.Width <= 0 || evidence.Height <= 0 || evidence.Detail != "high" || evidence.Answer != "bounded vision answer" {
		t.Fatalf("inspect_media must return bounded machine-readable evidence, found=%v evidence=%+v", foundEvidence, evidence)
	}
}
