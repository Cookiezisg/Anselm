package bootstrap

import "testing"

// TestMCPResultMap — F74: an MCP tool's JSON-object result threads its fields into the node result
// (so downstream CEL reads mcpNode.<field>); plain text / arrays stay under "text".
func TestMCPResultMap(t *testing.T) {
	obj := mcpResultMap(`{"timezone":"UTC","datetime":"2026-06-19T02:08:07+00:00"}`)
	if obj["timezone"] != "UTC" || obj["datetime"] == nil {
		t.Fatalf("JSON object should thread fields, got %v", obj)
	}
	if _, hasText := obj["text"]; hasText {
		t.Errorf("a JSON object must NOT be wrapped under text; got %v", obj)
	}
	if txt := mcpResultMap("just some text"); txt["text"] != "just some text" {
		t.Fatalf("plain text should land under text, got %v", txt)
	}
	if arr := mcpResultMap(`[1,2,3]`); arr["text"] != "[1,2,3]" {
		t.Fatalf("JSON array should stay under text (no fields to thread), got %v", arr)
	}
}
