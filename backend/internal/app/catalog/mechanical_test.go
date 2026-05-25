package catalog

import (
	"strings"
	"testing"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

func TestAssemble_GroupHeaderContainsInvokeTool(t *testing.T) {
	items := []catalogdomain.Item{
		{Source: "function", ID: "f_1", Name: "csv-clean", Description: "Strips BOMs"},
	}
	gMap := map[string]catalogdomain.Granularity{"function": catalogdomain.PerItem}
	invokeMap := map[string]string{"function": "run_function"}

	cat := assemble(items, gMap, invokeMap)

	if !strings.Contains(cat.Summary, "### function [run_function]") {
		t.Errorf("header missing invoke tool; got:\n%s", cat.Summary)
	}
}

func TestAssemble_LongDescriptionTruncated(t *testing.T) {
	longDesc := "This description is intentionally very long and should be cut off by the truncate helper because it exceeds the limit"
	items := []catalogdomain.Item{
		{Source: "function", ID: "f_2", Name: "my-fn", Description: longDesc},
	}
	gMap := map[string]catalogdomain.Granularity{"function": catalogdomain.PerItem}
	invokeMap := map[string]string{"function": "run_function"}

	cat := assemble(items, gMap, invokeMap)

	// The rendered description must be no longer than 48 runes + "…" (49 runes total).
	// Find the line that starts with "- **my-fn**:".
	line := ""
	for _, l := range strings.Split(cat.Summary, "\n") {
		if strings.HasPrefix(l, "- **my-fn**:") {
			line = l
			break
		}
	}
	if line == "" {
		t.Fatalf("item line not found in:\n%s", cat.Summary)
	}
	// Extract desc after ": "
	idx := strings.Index(line, ": ")
	if idx < 0 {
		t.Fatalf("no ': ' separator in line: %q", line)
	}
	desc := line[idx+2:]
	runes := []rune(desc)
	if len(runes) > 49 {
		t.Errorf("desc too long (%d runes > 49): %q", len(runes), desc)
	}
	if !strings.HasSuffix(desc, "…") {
		t.Errorf("truncated desc should end with '…'; got: %q", desc)
	}
}

func TestAssemble_ShortDescriptionNotTruncated(t *testing.T) {
	short := "Short desc"
	items := []catalogdomain.Item{
		{Source: "skill", ID: "s_1", Name: "deploy", Description: short},
	}
	gMap := map[string]catalogdomain.Granularity{"skill": catalogdomain.PerItem}
	invokeMap := map[string]string{"skill": "activate_skill"}

	cat := assemble(items, gMap, invokeMap)

	if !strings.Contains(cat.Summary, short) {
		t.Errorf("short desc should appear verbatim; got:\n%s", cat.Summary)
	}
	if strings.Contains(cat.Summary, "…") {
		t.Errorf("short desc should not be truncated; got:\n%s", cat.Summary)
	}
}

func TestAssemble_EmptyLibrarySkipsSection(t *testing.T) {
	cat := assemble(nil, nil, nil)
	if strings.Contains(cat.Summary, "## Available capabilities") {
		t.Errorf("empty library should skip section; got:\n%s", cat.Summary)
	}
}
