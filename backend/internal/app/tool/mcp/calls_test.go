package mcp

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestSearchMCPCallsArgsDecodeLimit(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    int
		wantErr string
	}{
		{name: "native integer", input: `{"serverId":"mcp_1","limit":1}`, want: 1},
		{name: "exact decimal string", input: `{"serverId":"mcp_1","limit":" 1 "}`, want: 1},
		{name: "omitted default", input: `{"serverId":"mcp_1"}`, want: 0},
		{name: "null default", input: `{"serverId":"mcp_1","limit":null}`, want: 0},
		{name: "float rejected", input: `{"serverId":"mcp_1","limit":1.5}`, wantErr: "must be integer"},
		{name: "decimal string rejected", input: `{"serverId":"mcp_1","limit":"1.5"}`, wantErr: "must be integer"},
		{name: "object rejected", input: `{"serverId":"mcp_1","limit":{}}`, wantErr: "must be integer"},
		{name: "boolean rejected", input: `{"serverId":"mcp_1","limit":true}`, wantErr: "must be integer"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got searchMCPCallsArgs
			err := json.Unmarshal([]byte(tt.input), &got)
			if tt.wantErr == "" {
				if err != nil {
					t.Fatalf("unmarshal: %v", err)
				}
				if got.Limit != tt.want {
					t.Fatalf("limit = %d, want %d", got.Limit, tt.want)
				}
				return
			}
			if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
				t.Fatalf("error = %v, want substring %q", err, tt.wantErr)
			}
		})
	}
}

func TestSearchMCPCallsParametersDocumentManagedStringCompatibility(t *testing.T) {
	if !strings.Contains(string((&SearchMCPCalls{}).Parameters()), "exact decimal string") {
		t.Fatal("limit schema must document managed decimal-string compatibility")
	}
}

func TestSearchMCPCallsDescriptionDocumentsNameOrIDResolution(t *testing.T) {
	description := (&SearchMCPCalls{}).Description()
	for _, phrase := range []string{
		"serverId accepts either the canonical mcp_ server id",
		"server name shown by the MCP catalog",
	} {
		if !strings.Contains(description, phrase) {
			t.Fatalf("search_mcp_calls description missing %q: %s", phrase, description)
		}
	}
	if !strings.Contains(string((&SearchMCPCalls{}).Parameters()), "Canonical mcp_ server id or the server name") {
		t.Fatal("serverId schema must document name or id resolution")
	}
}

func TestGetMCPCallDescriptionProtectsExactTimingValues(t *testing.T) {
	description := (&GetMCPCall{}).Description()
	for _, phrase := range []string{
		"omit them from prose unless the user asks for a named field",
		"copy the returned string character-for-character",
		"never use a field label or placeholder as its value",
	} {
		if !strings.Contains(description, phrase) {
			t.Fatalf("get_mcp_call description missing %q: %s", phrase, description)
		}
	}
}
