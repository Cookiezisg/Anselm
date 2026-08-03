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

func TestSearchActivations_DescriptionPinsPerActivationFanout(t *testing.T) {
	desc := (&SearchActivations{}).Description()
	for _, want := range []string{
		"firingCount",
		"number of workflows fanned out by THAT activation",
		"NOT a cumulative counter",
		"NOT the number of fires in the trigger's history",
		"fired entry can still be 0",
		"payload.manual=true",
		"bypassed the sensor condition",
		"NOT evidence that the sensor condition or threshold evaluated true",
		"exact JSON strings \"true\"/\"false\"",
		"exact decimal integer strings such as \"3\"",
	} {
		if !strings.Contains(desc, want) {
			t.Fatalf("search_activations description missing %q: %s", want, desc)
		}
	}
	if !json.Valid((&SearchActivations{}).Parameters()) {
		t.Fatal("search_activations Parameters must be valid JSON")
	}
}

func TestSearchActivationsArgsAcceptHostedScalarStrings(t *testing.T) {
	var got searchActivationsArgs
	if err := json.Unmarshal([]byte(`{"triggerId":"trg_1","firedOnly":"true","limit":"3","cursor":"c"}`), &got); err != nil {
		t.Fatalf("exact hosted scalar strings rejected: %v", err)
	}
	if got.TriggerID != "trg_1" || !got.FiredOnly || got.Limit != 3 || got.Cursor != "c" {
		t.Fatalf("decoded args = %+v", got)
	}
	if err := json.Unmarshal([]byte(`{"triggerId":"trg_1","firedOnly":false,"limit":3}`), &got); err != nil {
		t.Fatalf("native scalar values rejected: %v", err)
	}
}

func TestSearchActivationsArgsRejectWrongScalarShapes(t *testing.T) {
	for _, raw := range []string{
		`{"triggerId":"trg_1","firedOnly":"1"}`,
		`{"triggerId":"trg_1","firedOnly":1}`,
		`{"triggerId":"trg_1","limit":"3.0"}`,
		`{"triggerId":"trg_1","limit":3.0}`,
		`{"triggerId":"trg_1","limit":[]}`,
	} {
		var got searchActivationsArgs
		if err := json.Unmarshal([]byte(raw), &got); err == nil {
			t.Errorf("wrong scalar shape unexpectedly accepted: %s", raw)
		}
	}
}

func TestSearchFiringsArgsAcceptHostedLimitString(t *testing.T) {
	var got searchFiringsArgs
	if err := json.Unmarshal([]byte(`{"triggerId":"trg_1","limit":"3","status":"started"}`), &got); err != nil {
		t.Fatalf("exact hosted limit string rejected: %v", err)
	}
	if got.TriggerID != "trg_1" || got.Limit != 3 || got.Status != "started" {
		t.Fatalf("decoded args = %+v", got)
	}
	if err := json.Unmarshal([]byte(`{"triggerId":"trg_1","limit":3}`), &got); err != nil {
		t.Fatalf("native limit rejected: %v", err)
	}
}

func TestSearchFiringsArgsRejectWrongLimitShapes(t *testing.T) {
	for _, raw := range []string{
		`{"triggerId":"trg_1","limit":"3.0"}`,
		`{"triggerId":"trg_1","limit":3.0}`,
		`{"triggerId":"trg_1","limit":[]}`,
		`{"triggerId":"trg_1","limit":"many"}`,
	} {
		var got searchFiringsArgs
		if err := json.Unmarshal([]byte(raw), &got); err == nil {
			t.Errorf("wrong limit shape unexpectedly accepted: %s", raw)
		}
	}
}

func TestSearchFiringsDescriptionPinsExactTriggerID(t *testing.T) {
	desc := (&SearchFirings{}).Description()
	for _, want := range []string{
		"exact opaque triggerId",
		"byte-for-byte",
		"NOT a name/pattern search",
		"never accepts a pattern argument",
		"the requested item",
		"call search_triggers first",
	} {
		if !strings.Contains(desc, want) {
			t.Errorf("search_firings description missing %q: %s", want, desc)
		}
	}
	if !json.Valid((&SearchFirings{}).Parameters()) {
		t.Fatal("search_firings Parameters must be valid JSON")
	}
}

func TestSearchFiringsValidateRejectsPatternWithoutTriggerID(t *testing.T) {
	err := (&SearchFirings{}).ValidateInput(json.RawMessage(`{"pattern":"search_firings"}`))
	if err == nil || !strings.Contains(err.Error(), "exact triggerId is required") {
		t.Fatalf("pattern-only args error = %v, want exact triggerId guidance", err)
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
