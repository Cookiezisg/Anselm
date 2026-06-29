package chat

import (
	"strings"
	"testing"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

func TestPreviewFrom(t *testing.T) {
	t.Run("folds whitespace and newlines to single spaces", func(t *testing.T) {
		got := previewFrom("  hello\n\nthere\t world  ")
		if got != "hello there world" {
			t.Fatalf("got %q", got)
		}
	})
	t.Run("empty / whitespace-only → empty (keep existing preview)", func(t *testing.T) {
		if previewFrom("") != "" || previewFrom("   \n\t ") != "" {
			t.Fatalf("expected empty")
		}
	})
	t.Run("truncates by RUNE not byte (CJK safe) with ellipsis", func(t *testing.T) {
		in := strings.Repeat("文", previewMaxRunes+50) // each rune is 3 bytes
		got := previewFrom(in)
		gotRunes := []rune(got)
		// previewMaxRunes content runes + 1 ellipsis rune, and no half-character mojibake.
		if len(gotRunes) != previewMaxRunes+1 {
			t.Fatalf("rune len = %d, want %d", len(gotRunes), previewMaxRunes+1)
		}
		if gotRunes[len(gotRunes)-1] != '…' {
			t.Fatalf("expected trailing ellipsis, got %q", got)
		}
		if !strings.HasPrefix(got, strings.Repeat("文", previewMaxRunes)) {
			t.Fatalf("truncated content corrupted: %q", got)
		}
	})
	t.Run("short text passes through untruncated", func(t *testing.T) {
		if previewFrom("hi") != "hi" {
			t.Fatalf("unexpected")
		}
	})
}

func TestPreviewFromBlocks(t *testing.T) {
	t.Run("joins only text blocks, excludes reasoning / tool_call / tool_result", func(t *testing.T) {
		blocks := []messagesdomain.Block{
			{Type: messagesdomain.BlockTypeReasoning, Content: "SECRET chain of thought"},
			{Type: messagesdomain.BlockTypeText, Content: "Here is"},
			{Type: messagesdomain.BlockTypeToolCall, Content: `{"args":"SECRET"}`},
			{Type: messagesdomain.BlockTypeText, Content: "the answer."},
			{Type: messagesdomain.BlockTypeToolResult, Content: "SECRET result"},
		}
		got := previewFromBlocks(blocks)
		if got != "Here is the answer." {
			t.Fatalf("got %q", got)
		}
		if strings.Contains(got, "SECRET") {
			t.Fatalf("preview leaked non-text block content: %q", got)
		}
	})
	t.Run("no text blocks (pure tool turn) → empty (keep prior preview)", func(t *testing.T) {
		blocks := []messagesdomain.Block{
			{Type: messagesdomain.BlockTypeReasoning, Content: "think"},
			{Type: messagesdomain.BlockTypeToolCall, Content: "{}"},
		}
		if previewFromBlocks(blocks) != "" {
			t.Fatalf("expected empty for a text-less message")
		}
	})
}
