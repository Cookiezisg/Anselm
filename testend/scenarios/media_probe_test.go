package scenarios

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestInspectMedia_AudioVideoMetadataCapsule is the black-box guard for the current temporal
// contract: audio/video inspection is local metadata plus an optional time-range intent. It must
// not claim to have produced ASR/scene understanding, and raw media bytes must never enter the LLM
// request merely because the model asked to inspect a file.
func TestInspectMedia_AudioVideoMetadataCapsule(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	audioRaw := []byte("RAW-AUDIO-SECRET")
	videoRaw := []byte("RAW-VIDEO-SECRET")
	audioID := uploadAtt(t, wc, "meeting.mp3", "audio/mpeg", audioRaw)
	videoID := uploadAtt(t, wc, "demo.mp4", "video/mp4", videoRaw)

	// inspect_media is lazy. Search first, then inspect both temporal attachments with explicit
	// ranges so the returned capsule proves the caller's intent was preserved.
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "search_tools", Args: fw(map[string]any{"query": "inspect_media"})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "inspect_media", Args: fw(map[string]any{
			"attachmentId": audioID, "question": "what time range is requested?", "startMs": 1000, "endMs": 3200,
		})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "inspect_media", Args: fw(map[string]any{
			"attachmentId": videoID, "question": "what time range is requested?", "startMs": 5000, "endMs": 7600,
		})}}},
		harness.LLMTurn{Text: "metadata captured"},
	)
	convID := convCreate(t, wc, "temporal inspect")
	turn := waitTurn(t, wc, convID, sendMsg(t, wc, convID, "检查音频和视频的指定时间段"), 30000)
	if turn.Status != "completed" {
		t.Fatalf("temporal inspect turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	dumps := mock.WaitDumps(t, dlgModel, 4, 10000)
	if len(dumps) < 4 {
		t.Fatalf("want search + two inspect calls + final model requests, got %d", len(dumps))
	}
	raw := make([]string, 0, len(dumps))
	toolWire := make([]string, 0, len(dumps))
	for _, d := range dumps {
		raw = append(raw, string(d.Raw))
		for _, msg := range d.Messages {
			if msg.Role == "tool" {
				toolWire = append(toolWire, msg.Content)
			}
		}
	}
	wire := strings.Join(raw, "\n")
	toolEvidence := strings.Join(toolWire, "\n")
	for _, sentinel := range []string{string(audioRaw), string(videoRaw)} {
		if strings.Contains(wire, sentinel) {
			t.Fatalf("raw temporal bytes leaked into an LLM request: %q", sentinel)
		}
	}
	if !strings.Contains(wire, audioID) || !strings.Contains(wire, videoID) {
		t.Fatalf("temporal tool results must name both attachment ids on the wire")
	}
	for _, want := range []string{`"mode":"metadata"`, `"startMs":1000`, `"endMs":3200`, `"startMs":5000`, `"endMs":7600`, "local metadata only", "does not contain audio transcript"} {
		if !strings.Contains(toolEvidence, want) {
			t.Errorf("temporal capsule wire is missing %q", want)
		}
	}
	// The tool result is JSON evidence, not a provider/media response blob. Decode the actual tool
	// message to make sure its public shape remains machine-readable as well as textually honest.
	var capsule struct {
		AttachmentID string `json:"attachmentId"`
		Kind         string `json:"kind"`
		Mode         string `json:"mode"`
		StartMS      int64  `json:"startMs"`
		EndMS        int64  `json:"endMs"`
	}
	foundCapsule := false
	for _, dump := range dumps {
		for _, msg := range dump.Messages {
			if msg.Role != "tool" || !strings.Contains(msg.Content, audioID) {
				continue
			}
			if err := json.Unmarshal([]byte(msg.Content), &capsule); err != nil {
				t.Fatalf("audio inspect tool result must be JSON: %v content=%q", err, msg.Content)
			}
			foundCapsule = true
		}
	}
	if !foundCapsule || capsule.AttachmentID != audioID || capsule.Kind != "audio" || capsule.Mode != "metadata" || capsule.StartMS != 1000 || capsule.EndMS != 3200 {
		t.Fatalf("capsule wire contract unexpectedly changed: found=%v capsule=%+v", foundCapsule, capsule)
	}
}
