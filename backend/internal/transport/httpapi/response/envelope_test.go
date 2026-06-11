package response

import (
	"encoding/json"
	"net/http/httptest"
	"testing"
)

func TestSuccessEnvelope(t *testing.T) {
	w := httptest.NewRecorder()
	Success(w, 200, map[string]string{"x": "y"})
	var env map[string]json.RawMessage
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	if _, ok := env["data"]; !ok {
		t.Errorf("success must wrap in {data}: %s", w.Body.String())
	}
	if _, ok := env["error"]; ok {
		t.Error("success must not carry error")
	}
}

func TestPagedEnvelope(t *testing.T) {
	w := httptest.NewRecorder()
	Paged(w, []int{1, 2}, "cur1", true)
	var env struct {
		Data       []int   `json:"data"`
		NextCursor *string `json:"nextCursor"`
		HasMore    *bool   `json:"hasMore"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	if len(env.Data) != 2 || env.NextCursor == nil || *env.NextCursor != "cur1" || env.HasMore == nil || !*env.HasMore {
		t.Errorf("paged envelope = %s", w.Body.String())
	}
}

func TestErrorEnvelope(t *testing.T) {
	w := httptest.NewRecorder()
	Error(w, 400, "BAD", "bad thing", map[string]any{"field": "name"})
	if w.Code != 400 {
		t.Errorf("status = %d", w.Code)
	}
	code, msg := decodeErr(t, w.Body.Bytes())
	if code != "BAD" || msg != "bad thing" {
		t.Errorf("error envelope = %q / %q", code, msg)
	}
}
