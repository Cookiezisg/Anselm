package touchpoint

import (
	"errors"
	"testing"
	"time"
)

// The domain's whole job is the closed sets + row addressability — pin them.
// domain 的全部职责 = 封闭集 + 行可寻址性——钉死。

func validTouch() Touch {
	return Touch{
		ConversationID: "cv_1", ItemKind: "function", ItemID: "fn_1",
		Verb: VerbViewed, Actor: ActorAssistant, At: time.Now(),
	}
}

func TestValidate_OK(t *testing.T) {
	tc := validTouch()
	if err := tc.Validate(); err != nil {
		t.Fatalf("valid touch rejected: %v", err)
	}
}

func TestValidate_Rejections(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*Touch)
		want   error
	}{
		{"empty conversation", func(x *Touch) { x.ConversationID = "" }, ErrInvalidRef},
		{"empty item id", func(x *Touch) { x.ItemID = "" }, ErrInvalidRef},
		{"bad kind", func(x *Touch) { x.ItemKind = "gizmo" }, ErrInvalidKind},
		{"bad verb", func(x *Touch) { x.Verb = "poked" }, ErrInvalidVerb},
		{"bad actor", func(x *Touch) { x.Actor = "robot" }, ErrInvalidActor},
	}
	for _, c := range cases {
		tc := validTouch()
		c.mutate(&tc)
		if err := tc.Validate(); !errors.Is(err, c.want) {
			t.Errorf("%s: got %v, want %v", c.name, err, c.want)
		}
	}
}

func TestItemKind_RelationVocabularyPlusAttachment(t *testing.T) {
	// All 11 relation kinds + attachment pass; anything else dies. 11 实体 kind + attachment 全过。
	for _, k := range []string{
		"function", "handler", "agent", "workflow", "trigger",
		"control", "approval", "skill", "mcp", "document", "conversation", ItemKindAttachment,
	} {
		if !IsValidItemKind(k) {
			t.Errorf("kind %q should be valid", k)
		}
	}
	if IsValidItemKind("") || IsValidItemKind("flowrun") || IsValidItemKind("memory") {
		t.Error("non-ledger kinds must be invalid")
	}
}

func TestVerbAndActor_ClosedSets(t *testing.T) {
	for _, v := range []string{VerbMentioned, VerbCreated, VerbEdited, VerbViewed, VerbExecuted, VerbAttached, VerbDeleted} {
		if !IsValidVerb(v) {
			t.Errorf("verb %q should be valid", v)
		}
	}
	if IsValidVerb("touched") {
		t.Error("unknown verb must be invalid")
	}
	for _, a := range []string{ActorUser, ActorAssistant, ActorSubagent} {
		if !IsValidActor(a) {
			t.Errorf("actor %q should be valid", a)
		}
	}
	if IsValidActor("system") {
		t.Error("unknown actor must be invalid")
	}
}
