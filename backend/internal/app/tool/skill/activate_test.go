package skill

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestDecodeActivateSkillArguments(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want []string
		fail bool
	}{
		{name: "native array", raw: `["design","review"]`, want: []string{"design", "review"}},
		{name: "exact array string", raw: `"[\"design\",\"review\"]"`, want: []string{"design", "review"}},
		{name: "omitted", raw: ``, want: nil},
		{name: "null", raw: `null`, want: nil},
		{name: "empty array", raw: `[]`, want: []string{}},
		{name: "plain string rejected", raw: `"design"`, fail: true},
		{name: "number rejected", raw: `2`, fail: true},
		{name: "object rejected", raw: `{}`, fail: true},
		{name: "mixed array rejected", raw: `["design",2]`, fail: true},
		{name: "invalid encoded array rejected", raw: `"[design]"`, fail: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := decodeActivateSkillArguments(json.RawMessage(tt.raw))
			if tt.fail {
				if err == nil {
					t.Fatalf("expected error, got %#v", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("decode: %v", err)
			}
			if len(got) != len(tt.want) {
				t.Fatalf("got %#v, want %#v", got, tt.want)
			}
			for i := range got {
				if got[i] != tt.want[i] {
					t.Fatalf("got %#v, want %#v", got, tt.want)
				}
			}
		})
	}
}

func TestActivateSkillParametersDocumentManagedCompatibility(t *testing.T) {
	got := string((&ActivateSkill{}).Parameters())
	if !strings.Contains(got, "exact JSON array as a string") {
		t.Fatalf("schema must document managed compatibility: %s", got)
	}
}
