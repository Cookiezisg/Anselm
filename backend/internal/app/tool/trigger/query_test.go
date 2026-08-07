package trigger

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

func TestGetTriggerDescriptionPinsExactID(t *testing.T) {
	desc := (&GetTrigger{}).Description()
	for _, want := range []string{
		"exact opaque triggerId",
		"Use the triggerId key",
		"file_path only when its value is an unmistakable trg_... ID",
		"never send a filesystem path",
		"search_triggers first",
		"copy its returned id",
	} {
		if !strings.Contains(desc, want) {
			t.Errorf("get_trigger description missing %q: %s", want, desc)
		}
	}
}

func TestGetTriggerNormalizeArguments(t *testing.T) {
	tool := &GetTrigger{}
	tests := []struct {
		name    string
		args    string
		want    string
		changed bool
	}{
		{
			name:    "hosted file path alias containing exact trigger id",
			args:    `{"file_path":"trg_bceceaf60c93fb59"}`,
			want:    `{"triggerId":"trg_bceceaf60c93fb59"}`,
			changed: true,
		},
		{
			name: "explicit canonical field wins",
			args: `{"triggerId":"trg_exact","file_path":"/tmp/trigger"}`,
			want: `{"triggerId":"trg_exact","file_path":"/tmp/trigger"}`,
		},
		{
			name:    "identical alias is removed",
			args:    `{"triggerId":"trg_exact","file_path":"trg_exact"}`,
			want:    `{"triggerId":"trg_exact"}`,
			changed: true,
		},
		{
			name: "ordinary filesystem path is not guessed",
			args: `{"file_path":"/tmp/trigger"}`,
			want: `{"file_path":"/tmp/trigger"}`,
		},
		{
			name: "punctuated value is not treated as an id",
			args: `{"file_path":"trg_abc/def"}`,
			want: `{"file_path":"trg_abc/def"}`,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, changed := tool.NormalizeArguments([]byte(tt.args))
			if changed != tt.changed {
				t.Fatalf("changed = %v, want %v; got %s", changed, tt.changed, got)
			}
			var gotFields, wantFields map[string]any
			if err := json.Unmarshal(got, &gotFields); err != nil {
				t.Fatalf("normalized JSON: %v", err)
			}
			if err := json.Unmarshal([]byte(tt.want), &wantFields); err != nil {
				t.Fatalf("want JSON: %v", err)
			}
			if !reflect.DeepEqual(gotFields, wantFields) {
				t.Fatalf("normalized = %#v, want %#v", gotFields, wantFields)
			}
		})
	}
}

func TestGetTriggerValidateInputRejectsUnnormalizedAlias(t *testing.T) {
	tool := &GetTrigger{}
	for _, args := range []string{
		`{"file_path":"/tmp/trigger"}`,
		`{"triggerId":"trg_exact","file_path":"trg_other"}`,
	} {
		if err := tool.ValidateInput([]byte(args)); err == nil {
			t.Errorf("ValidateInput(%s) unexpectedly accepted an unnormalized alias", args)
		}
	}
}

func TestDecodeSearchTriggersQuery(t *testing.T) {
	tests := []struct {
		name string
		args string
		want string
	}{
		{name: "canonical query", args: `{"query":"webhookpulse"}`, want: "webhookpulse"},
		{name: "hosted model pattern alias", args: `{"pattern":"webhookpulse"}`, want: "webhookpulse"},
		{name: "canonical query wins", args: `{"query":"cron","pattern":"webhook"}`, want: "cron"},
		{name: "empty query remains list all", args: `{}`, want: ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := decodeSearchTriggersQuery(tt.args)
			if err != nil {
				t.Fatalf("decodeSearchTriggersQuery() error = %v", err)
			}
			if got != tt.want {
				t.Fatalf("decodeSearchTriggersQuery() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestDecodeSearchTriggersQueryRejectsNonStringAlias(t *testing.T) {
	if _, err := decodeSearchTriggersQuery(`{"pattern":123}`); err == nil {
		t.Fatal("pattern with a non-string value must fail instead of becoming an empty query")
	}
}
