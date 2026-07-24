package contextmgr

import (
	"strings"
	"testing"
	"unicode/utf8"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

func TestExcerptTruncatesAtUTF8Boundary(t *testing.T) {
	content := strings.Repeat("界", maxBlockExcerptBytes)
	got := excerpt(messagesdomain.Block{
		Type:    messagesdomain.BlockTypeText,
		Content: content,
	})
	if !utf8.ValidString(got) {
		t.Fatal("summary excerpt split a UTF-8 rune")
	}
	if !strings.HasSuffix(got, "…[truncated]") {
		t.Fatalf("oversized excerpt did not declare truncation: %q", got[len(got)-40:])
	}
}
