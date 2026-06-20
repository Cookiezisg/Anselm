package trigger

import (
	"encoding/json"
	"strings"
	"testing"
)

// TestFireTrigger_DescriptionRedirectsForPayload: round-2 longhaul lane saw the agent pass a {body:...}
// to fire_trigger to test a webhook workflow; fire_trigger silently dropped it (it fires only the
// synthetic {manual:true} payload). The description must say it carries no custom payload and point to
// trigger_workflow for data-carrying test runs.
func TestFireTrigger_DescriptionRedirectsForPayload(t *testing.T) {
	desc := (&FireTrigger{}).Description()
	for _, want := range []string{"manual", "custom payload", "trigger_workflow"} {
		if !strings.Contains(desc, want) {
			t.Errorf("fire_trigger description must mention %q to stop agents passing a dropped payload; got: %s", want, desc)
		}
	}
	// Parameters stays valid JSON with only triggerId (no payload field to mislead).
	if !json.Valid((&FireTrigger{}).Parameters()) {
		t.Error("fire_trigger Parameters must be valid JSON")
	}
}
