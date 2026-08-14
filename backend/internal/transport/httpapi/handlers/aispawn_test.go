package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	gozap "go.uber.org/zap"

	aispawnapp "github.com/sunweilin/anselm/backend/internal/app/aispawn"
	mentiondomain "github.com/sunweilin/anselm/backend/internal/domain/mention"
)

type triageTestStarter struct{}

func (triageTestStarter) StartSeeded(context.Context, string) (string, error) {
	return "cv_triage_test", nil
}

type triageTestSender struct {
	content string
}

func (s *triageTestSender) SendSeed(_ context.Context, _, content string, _ []mentiondomain.MentionInput) (string, error) {
	s.content = content
	return "msg_triage_test", nil
}

type triageTestRenderer struct{}

func (triageTestRenderer) Render(context.Context, string) (string, error) {
	return "Status: failed\nError: test failure", nil
}

// TestTriageHandlerAcceptsOmittedBody protects the UI contract: the scheduler sends no body when
// the user did not add a note, so an empty body must still open the seeded diagnosis conversation.
func TestTriageHandlerAcceptsOmittedBody(t *testing.T) {
	sender := &triageTestSender{}
	svc := aispawnapp.NewService(triageTestStarter{}, sender, triageTestRenderer{}, gozap.NewNop())
	h := NewTriageHandler(svc, gozap.NewNop())
	mux := http.NewServeMux()
	h.Register(mux)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/executions/fr_test:triage", http.NoBody)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("status = %d, want 202; body = %s", rec.Code, rec.Body)
	}
	var body struct {
		Data struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v; body = %s", err, rec.Body)
	}
	if body.Data.ID != "cv_triage_test" {
		t.Fatalf("conversation id = %q, want cv_triage_test", body.Data.ID)
	}
	if sender.content != "Please diagnose this execution." {
		t.Fatalf("seed content = %q, want default triage prompt", sender.content)
	}
}
