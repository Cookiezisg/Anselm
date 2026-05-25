package document

import (
	"strings"
	"testing"
)

func TestMentionResolver_ResolvesDocContent(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	d, err := s.Create(ctx, CreateInput{Name: "Spec", Description: "the spec", Content: "# Hello"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	r := s.AsMentionResolver()
	if r.Type() != "document" {
		t.Errorf("Type() = %q, want document", r.Type())
	}
	ref, err := r.Resolve(ctx, d.ID)
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if ref.Name != "Spec" || !strings.Contains(ref.Content, "# Hello") || !strings.Contains(ref.Content, "the spec") {
		t.Errorf("bad reference: %+v", ref)
	}
}

func TestMentionResolver_NotFound_Errors(t *testing.T) {
	s := newService(t)
	ctx := userCtx()
	if _, err := s.AsMentionResolver().Resolve(ctx, "doc_missing"); err == nil {
		t.Error("Resolve of missing doc should error")
	}
}
