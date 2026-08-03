package trigger

import (
	"encoding/json"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

// TestFireTrigger_DescriptionRedirectsForPayload: round-2 longhaul lane saw the agent pass a {body:...}
// to fire_trigger to test a webhook workflow; fire_trigger silently dropped it (it fires only the
// synthetic {manual:true} payload). The description must say it carries no custom payload and point to
// trigger_workflow for data-carrying test runs, and must not suggest edit_trigger as a way to
// resume a paused trigger.
func TestFireTrigger_DescriptionRedirectsForPayload(t *testing.T) {
	desc := (&FireTrigger{}).Description()
	for _, want := range []string{"manual", "custom payload", "trigger_workflow", "TRIGGER_PAUSED", "edit_trigger", "cannot resume", ":resume"} {
		if !strings.Contains(desc, want) {
			t.Errorf("fire_trigger description must mention %q to stop agents passing a dropped payload; got: %s", want, desc)
		}
	}
	// Parameters stays valid JSON with only triggerId (no payload field to mislead).
	if !json.Valid((&FireTrigger{}).Parameters()) {
		t.Error("fire_trigger Parameters must be valid JSON")
	}
}

func TestNormalizeSensorOutputObjectShorthand(t *testing.T) {
	config := map[string]any{
		"output": map[string]any{
			"healthy": "payload.healthy",
			"total":   "payload.total",
		},
	}
	if err := normalizeSensorOutput("sensor", config); err != nil {
		t.Fatalf("normalizeSensorOutput() error = %v", err)
	}
	want := `{"healthy": payload.healthy, "total": payload.total}`
	if got, _ := config["output"].(string); got != want {
		t.Fatalf("normalized output = %q, want %q", got, want)
	}
}

func TestNormalizeSensorOutputLeavesCanonicalCELString(t *testing.T) {
	config := map[string]any{"output": `{"total": payload.total}`}
	if err := normalizeSensorOutput("sensor", config); err != nil {
		t.Fatalf("normalizeSensorOutput() error = %v", err)
	}
	if got := config["output"]; got != `{"total": payload.total}` {
		t.Fatalf("canonical output changed to %#v", got)
	}
}

func TestDecodeTriggerConfigAcceptsNativeAndStringifiedObjects(t *testing.T) {
	cases := []struct {
		name string
		raw  string
	}{
		{name: "native object", raw: `{"path":"/tmp/inbox"}`},
		{name: "stringified object", raw: `"{\"path\":\"/tmp/inbox\"}"`},
		{name: "stringified object with whitespace", raw: `"  {\"path\":\"/tmp/inbox\"}  "`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := decodeTriggerConfig([]byte(tc.raw))
			if err != nil {
				t.Fatalf("decodeTriggerConfig(%s) error = %v", tc.raw, err)
			}
			if got["path"] != "/tmp/inbox" {
				t.Fatalf("decoded config = %#v, want path", got)
			}
		})
	}
}

func TestDecodeTriggerConfigRejectsWrongShapes(t *testing.T) {
	for _, raw := range []string{
		`[]`,
		`1`,
		`true`,
		`"plain text"`,
		`"[]"`,
		`"not json"`,
	} {
		if got, err := decodeTriggerConfig([]byte(raw)); err == nil {
			t.Errorf("decodeTriggerConfig(%s) unexpectedly succeeded with %#v", raw, got)
		}
	}
}

func TestDecodeTriggerConfigPreservesOmittedAndNullEditSemantics(t *testing.T) {
	for _, raw := range []string{"", `null`} {
		got, err := decodeTriggerConfig([]byte(raw))
		if err != nil {
			t.Fatalf("decodeTriggerConfig(%q) error = %v", raw, err)
		}
		if got != nil {
			t.Fatalf("decodeTriggerConfig(%q) = %#v, want nil", raw, got)
		}
	}
}

func TestTriggerConfigDescriptionsPinStringifiedObjectBoundary(t *testing.T) {
	for name, desc := range map[string]string{
		"create": (&CreateTrigger{}).Description(),
		"edit":   (&EditTrigger{}).Description(),
	} {
		for _, want := range []string{
			"exact JSON-encoded object string",
			"arrays, scalar values, and malformed strings are rejected",
		} {
			if !strings.Contains(desc, want) {
				t.Errorf("%s trigger description missing %q: %s", name, want, desc)
			}
		}
	}
}

func TestDeleteTrigger_DescriptionAndDangerFloor(t *testing.T) {
	tl := &DeleteTrigger{}
	if got := tl.MinimumDanger(); got != toolapp.DangerDangerous {
		t.Fatalf("delete_trigger minimum danger = %q, want dangerous", got)
	}
	for _, want := range []string{
		"always dangerous",
		"explicit user approval",
		"NOT restorable",
		"no restore operation",
		"activation and firing history",
		"get_relations",
	} {
		if !strings.Contains(tl.Description(), want) {
			t.Fatalf("delete_trigger description missing %q: %s", want, tl.Description())
		}
	}
}
