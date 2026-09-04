package blocks

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestSearchBlocksHostedModelStringifiedArgs(t *testing.T) {
	tool := &SearchBlocks{}
	for _, raw := range []string{
		`{"query":"workflow","kinds":["handler","function"],"limit":20}`,
		`{"query":"workflow","kinds":"[\"handler\",\"function\"]","limit":"20"}`,
	} {
		if err := tool.ValidateInput(json.RawMessage(raw)); err != nil {
			t.Fatalf("hosted-compatible args rejected: %s: %v", raw, err)
		}
	}
}

func TestSearchBlocksHostedModelStringifiedArgsRejectsWrongShapes(t *testing.T) {
	tool := &SearchBlocks{}
	for _, tc := range []struct {
		name string
		raw  string
		want string
	}{
		{name: "arbitrary kinds string", raw: `{"query":"workflow","kinds":"handler"}`, want: "kinds"},
		{name: "malformed kinds string", raw: `{"query":"workflow","kinds":"[handler]"}`, want: "kinds"},
		{name: "float limit", raw: `{"query":"workflow","limit":1.5}`, want: "limit"},
		{name: "arbitrary limit string", raw: `{"query":"workflow","limit":"many"}`, want: "limit"},
		{name: "empty query", raw: `{"query":"   ","kinds":[]}`, want: "query"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			err := tool.ValidateInput(json.RawMessage(tc.raw))
			if err == nil || !strings.Contains(strings.ToLower(err.Error()), tc.want) {
				t.Fatalf("ValidateInput(%s) = %v, want an error containing %q", tc.raw, err, tc.want)
			}
		})
	}
}

func TestSearchBlocksDescriptionRoutesChatExecutionToSearchTools(t *testing.T) {
	description := (&SearchBlocks{}).Description()
	for _, want := range []string{
		"workflow-palette discovery only",
		"Triggers are not workflow blocks",
		"do not send trigger or notification as a kinds value here",
		"Notification behavior belongs to the underlying function, handler, or MCP tool",
		"use its exact entityId with get_function/get_handler",
		"Keep exact refs in the adjacent result card",
		"do not use search_blocks to decide that a capability cannot run in the current conversation",
		"use search_tools to activate its callable tool",
		"including a connected MCP tool",
		"call it directly",
	} {
		if !strings.Contains(description, want) {
			t.Fatalf("SearchBlocks.Description() missing routing guard %q: %s", want, description)
		}
	}
}
