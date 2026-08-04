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
