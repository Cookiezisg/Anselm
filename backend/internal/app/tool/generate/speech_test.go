package generate

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// speechTool digs the speech member out of the family by name.
func speechTool(t *testing.T, router *Router, up Uploader) *GenerateSpeech {
	t.Helper()
	for _, tw := range GenerateTools(router, up, nil, nil) {
		if s, ok := tw.Tool.(*GenerateSpeech); ok {
			return s
		}
	}
	t.Fatal("generate_speech missing from the family")
	return nil
}

func wav(nSamples int) []byte {
	return llminfra.BuildWAV(make([]byte, nSamples*2), 24000, 1, 16)
}

// TestSpeech_HonestAbsenceAndValidation: a workspace with no speech-capable key never offers the
// tool, and the tool refuses empty or oversized text before spending anything.
func TestSpeech_HonestAbsenceAndValidation(t *testing.T) {
	none := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{}},
		fakeProbes{},
	)
	if none.SpeechAvailable(context.Background()) {
		t.Fatal("no key can speak, yet the tool reports itself available")
	}
	if _, err := speechTool(t, none, &fakeUploader{}).Execute(context.Background(), `{"text":"hi"}`); err == nil {
		t.Fatal("execute without a route must fail loudly")
	}

	tool := speechTool(t, none, &fakeUploader{})
	if err := tool.ValidateInput(json.RawMessage(`{"text":"   "}`)); err == nil {
		t.Fatal("blank text must be refused")
	}
	long := strings.Repeat("字", maxSpeechChars+1)
	if err := tool.ValidateInput(json.RawMessage(`{"text":"` + long + `"}`)); err == nil {
		t.Fatal("oversized text must be refused before any upstream call")
	}
	if err := tool.ValidateInput(json.RawMessage(`{"text":"ok"}`)); err != nil {
		t.Fatalf("valid input refused: %v", err)
	}
}
