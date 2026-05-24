package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

func TestScenariosHandler_List_MatchesWhitelist(t *testing.T) {
	h := NewScenariosHandler()
	mux := http.NewServeMux()
	h.Register(mux)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/scenarios", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}

	var env struct {
		Data []scenarioInfo `json:"data"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&env); err != nil {
		t.Fatalf("decode: %v", err)
	}

	want := modeldomain.ListScenarios()
	if len(env.Data) != len(want) {
		t.Fatalf("len = %d, want %d", len(env.Data), len(want))
	}
	for i, n := range want {
		if env.Data[i].Name != n {
			t.Errorf("index %d: name = %q, want %q", i, env.Data[i].Name, n)
		}
	}
}

func TestScenariosHandler_List_ContainsChat(t *testing.T) {
	h := NewScenariosHandler()
	mux := http.NewServeMux()
	h.Register(mux)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/scenarios", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	var env struct {
		Data []scenarioInfo `json:"data"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&env); err != nil {
		t.Fatalf("decode: %v", err)
	}

	found := false
	for _, s := range env.Data {
		if s.Name == modeldomain.ScenarioChat {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("scenarios response missing %q", modeldomain.ScenarioChat)
	}
}
