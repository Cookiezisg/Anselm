package function

import "testing"

func TestIsValidTrigger(t *testing.T) {
	valid := []string{TriggeredByChat, TriggeredByAgent, TriggeredByWorkflow, TriggeredByManual}
	for _, v := range valid {
		if !IsValidTrigger(v) {
			t.Errorf("IsValidTrigger(%q) = false, want true", v)
		}
	}
	for _, v := range []string{"", "http", "test", "polling", "cron"} {
		if IsValidTrigger(v) {
			t.Errorf("IsValidTrigger(%q) = true, want false", v)
		}
	}
}
