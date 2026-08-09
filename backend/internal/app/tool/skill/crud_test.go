package skill

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

func TestSaveSkillArgsAcceptsNativeAndExactEncodedArrays(t *testing.T) {
	tests := []struct {
		name        string
		body        string
		wantAllowed []string
		wantArgs    []string
		wantUser    bool
	}{
		{
			name:        "native arrays",
			body:        `{"name":"review","description":"d","body":"b","allowedTools":["Read"],"arguments":["audience"],"userInvocable":true}`,
			wantAllowed: []string{"Read"},
			wantArgs:    []string{"audience"},
			wantUser:    true,
		},
		{
			name:        "exact array strings",
			body:        `{"name":"review","description":"d","body":"b","allowedTools":"[\"Read\"]","arguments":"[\"audience\"]","userInvocable":"true"}`,
			wantAllowed: []string{"Read"},
			wantArgs:    []string{"audience"},
			wantUser:    true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got saveSkillArgs
			if err := json.Unmarshal([]byte(tt.body), &got); err != nil {
				t.Fatalf("unmarshal: %v", err)
			}
			if !reflect.DeepEqual(got.AllowedTools, tt.wantAllowed) {
				t.Fatalf("allowedTools = %#v, want %#v", got.AllowedTools, tt.wantAllowed)
			}
			if !reflect.DeepEqual(got.Arguments, tt.wantArgs) {
				t.Fatalf("arguments = %#v, want %#v", got.Arguments, tt.wantArgs)
			}
			if got.UserInvocable != tt.wantUser {
				t.Fatalf("userInvocable = %v, want %v", got.UserInvocable, tt.wantUser)
			}
		})
	}
}

func TestDecodeSkillStringArrayRejectsAmbiguousShapes(t *testing.T) {
	for _, raw := range []string{`"Read"`, `2`, `{}`, `["Read",2]`, `"[Read]"`} {
		t.Run(strings.ReplaceAll(raw, `"`, "quote"), func(t *testing.T) {
			if got, err := decodeSkillStringArray(json.RawMessage(raw)); err == nil {
				t.Fatalf("expected rejection, got %#v", got)
			}
		})
	}
}

func TestDecodeSkillBoolAcceptsNativeAndExactEncodedValues(t *testing.T) {
	tests := []struct {
		raw  string
		want bool
	}{
		{raw: `false`, want: false},
		{raw: `true`, want: true},
		{raw: `"false"`, want: false},
		{raw: `"true"`, want: true},
		{raw: `null`, want: false},
	}
	for _, tt := range tests {
		t.Run(tt.raw, func(t *testing.T) {
			got, err := decodeSkillBool(json.RawMessage(tt.raw))
			if err != nil {
				t.Fatalf("decode: %v", err)
			}
			if got != tt.want {
				t.Fatalf("decode = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestDecodeSkillBoolRejectsAmbiguousShapes(t *testing.T) {
	for _, raw := range []string{`0`, `1`, `"yes"`, `{}`, `[]`} {
		t.Run(strings.ReplaceAll(raw, `"`, "quote"), func(t *testing.T) {
			if got, err := decodeSkillBool(json.RawMessage(raw)); err == nil {
				t.Fatalf("expected rejection, got %v", got)
			}
		})
	}
}

func TestSaveSkillSchemaDocumentsManagedArrayCompatibility(t *testing.T) {
	got := string((&CreateSkill{}).Parameters())
	if !strings.Contains(got, "exact JSON array as a string") {
		t.Fatalf("schema must document managed compatibility: %s", got)
	}
	if !strings.Contains((&CreateSkill{}).Description(), "Optional: allowedTools") {
		t.Fatalf("description must name optional skill metadata: %s", (&CreateSkill{}).Description())
	}
	if !strings.Contains(got, "Explore") || !strings.Contains(got, "general-purpose") {
		t.Fatalf("schema must document the exact fork agent types: %s", got)
	}
	if !strings.Contains(got, `"userInvocable"`) || !strings.Contains((&CreateSkill{}).Description(), "userInvocable") {
		t.Fatalf("schema and description must expose userInvocable: schema=%s description=%s", got, (&CreateSkill{}).Description())
	}
}

func TestEditSkillHaltOnRepeatOnlyForMissingTarget(t *testing.T) {
	tool := &EditSkill{}
	if !tool.HaltOnRepeat("", "skill not found") {
		t.Fatal("missing skill must be a terminal rejection")
	}
	if !tool.HaltOnRepeat("", "edit_skill: skill not found") {
		t.Fatal("wrapped missing skill must be a terminal rejection")
	}
	if tool.HaltOnRepeat("", "permission denied") {
		t.Fatal("permission errors remain retryable or separately handled")
	}
	if tool.HaltOnRepeat("", "temporary filesystem error") {
		t.Fatal("transient filesystem errors must not be terminal")
	}
}
