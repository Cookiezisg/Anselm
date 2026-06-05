package mention

import "testing"

func TestIsValidMentionType(t *testing.T) {
	for _, mt := range []MentionType{
		MentionDocument, MentionFunction, MentionHandler, MentionWorkflow, MentionAgent,
	} {
		if !IsValidMentionType(mt) {
			t.Errorf("IsValidMentionType(%q) = false, want true", mt)
		}
	}
	// Not mentionable — catalog has these kinds, mention deliberately does not.
	for _, mt := range []MentionType{"conversation", "skill", "mcp", "", "Function"} {
		if IsValidMentionType(mt) {
			t.Errorf("IsValidMentionType(%q) = true, want false", mt)
		}
	}
}
