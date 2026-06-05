package stream

import "testing"

func TestScopeString(t *testing.T) {
	s := Scope{Kind: KindConversation, ID: "c_123"}
	if got, want := s.String(), "conversation:c_123"; got != want {
		t.Errorf("String() = %q, want %q", got, want)
	}
}

func TestIsValidKind(t *testing.T) {
	valid := []string{
		KindConversation, KindFunction, KindHandler, KindAgent, KindWorkflow,
		KindDocument, KindMCP, KindSkill, KindNotification,
	}
	for _, k := range valid {
		if !IsValidKind(k) {
			t.Errorf("IsValidKind(%q) = false, want true", k)
		}
	}
	for _, k := range []string{"", "bogus", "Conversation"} {
		if IsValidKind(k) {
			t.Errorf("IsValidKind(%q) = true, want false", k)
		}
	}
}
