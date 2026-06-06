package handler

import "testing"

func TestIsValidTrigger(t *testing.T) {
	for _, v := range []string{TriggeredByChat, TriggeredByAgent, TriggeredByWorkflow, TriggeredByManual} {
		if !IsValidTrigger(v) {
			t.Errorf("IsValidTrigger(%q) = false, want true", v)
		}
	}
	for _, v := range []string{"", "http", "test", "cron"} {
		if IsValidTrigger(v) {
			t.Errorf("IsValidTrigger(%q) = true, want false", v)
		}
	}
}
