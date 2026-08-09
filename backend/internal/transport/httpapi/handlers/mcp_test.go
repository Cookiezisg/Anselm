package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestMCPHandlerImportRejectsInvalidShapeWithActionableError(t *testing.T) {
	h := NewMCPHandler(nil, nil)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/mcp-servers:import", strings.NewReader(`{"servers":{"bad":{"command":"npx"}}}`))

	h.Import(rec, req)
	assertMCPImportError(t, rec, http.StatusBadRequest, "MCP_IMPORT_INVALID", "mcp.json must contain a non-empty mcpServers object")
}

func TestMCPHandlerImportRejectsOversizedBodyWithActionableError(t *testing.T) {
	h := NewMCPHandler(nil, nil)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/mcp-servers:import", strings.NewReader(strings.Repeat("x", mcpImportMaxBytes+1)))

	h.Import(rec, req)
	assertMCPImportError(t, rec, http.StatusRequestEntityTooLarge, "MCP_IMPORT_TOO_LARGE", "mcp.json exceeds the 1 MiB import limit")
}

func assertMCPImportError(t *testing.T, rec *httptest.ResponseRecorder, wantStatus int, wantCode, wantMessage string) {
	t.Helper()
	if rec.Code != wantStatus {
		t.Fatalf("status = %d, body=%s; want %d", rec.Code, rec.Body.String(), wantStatus)
	}
	var body struct {
		Error struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode error response: %v", err)
	}
	if body.Error.Code != wantCode || body.Error.Message != wantMessage {
		t.Fatalf("error = {%q, %q}; want {%q, %q}", body.Error.Code, body.Error.Message, wantCode, wantMessage)
	}
}
