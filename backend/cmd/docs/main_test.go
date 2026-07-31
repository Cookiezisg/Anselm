package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func governanceDoc(id, docType, status, extra string) string {
	return "---\n" +
		"id: " + id + "\n" +
		"type: " + docType + "\n" +
		"status: " + status + "\n" +
		"owner: @weilin\n" +
		"created: 2026-07-01\n" +
		"reviewed: 2026-07-01\n" +
		"review-due: 2026-09-29\n" +
		"audience: [human, ai]\n" +
		extra +
		"---\n\n# Fixture\n"
}

func lintFixture(t *testing.T, files map[string]string) *linter {
	t.Helper()
	root := t.TempDir()
	for rel, content := range files {
		path := filepath.Join(root, "docs", filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	l := &linter{
		docsDir: filepath.Join(root, "docs"),
		now:     time.Date(2026, 7, 31, 0, 0, 0, 0, time.UTC),
	}
	l.run()
	return l
}

func TestGovernanceStructure_Green(t *testing.T) {
	l := lintFixture(t, map[string]string{
		"concepts/architecture.md": governanceDoc("DOC-001", "concept", "active", ""),
		"references/api.md":        governanceDoc("DOC-002", "reference", "active", ""),
		"working/campaign/LOG.md":  governanceDoc("WRK-003-LOG", "working", "active", "landed-into:\n"),
		"archive/old/README.md":    "# archive is frontmatter-exempt\n",
		"INDEX.md":                 "# Index\n",
	})
	if len(l.errs) != 0 {
		t.Fatalf("valid canonical tree must stay green; errs=%v", l.errs)
	}
}

func TestGovernanceStructure_DuplicateID(t *testing.T) {
	l := lintFixture(t, map[string]string{
		"concepts/a.md":   governanceDoc("DOC-001", "concept", "active", ""),
		"references/b.md": governanceDoc("DOC-001", "reference", "active", ""),
	})
	if !hasErr(l, `duplicate id "DOC-001"`) {
		t.Fatalf("duplicate governed IDs must go red; errs=%v", l.errs)
	}
}

func TestGovernanceStructure_TypeAndLifecyclePlacement(t *testing.T) {
	l := lintFixture(t, map[string]string{
		"references/wrong.md": governanceDoc("DOC-001", "concept", "archived", ""),
	})
	for _, want := range []string{`does not match canonical directory type "reference"`, "status archived belongs under top-level archive/"} {
		if !hasErr(l, want) {
			t.Errorf("%q must go red; errs=%v", want, l.errs)
		}
	}
}

func TestGovernanceStructure_PrivateArchiveAndWorkingField(t *testing.T) {
	l := lintFixture(t, map[string]string{
		"working/campaign/archived/old.md": governanceDoc("WRK-001", "working", "active", ""),
	})
	for _, want := range []string{"cannot contain a private archive", `working frontmatter missing field "landed-into"`} {
		if !hasErr(l, want) {
			t.Errorf("%q must go red; errs=%v", want, l.errs)
		}
	}
}

func TestGovernanceStructure_IDAndDates(t *testing.T) {
	content := strings.ReplaceAll(
		governanceDoc("BAD-1", "concept", "active", ""),
		"reviewed: 2026-07-01",
		"reviewed: July 1",
	)
	l := lintFixture(t, map[string]string{"concepts/a.md": content})
	for _, want := range []string{`invalid id "BAD-1"`, `field "reviewed" must be YYYY-MM-DD`} {
		if !hasErr(l, want) {
			t.Errorf("%q must go red; errs=%v", want, l.errs)
		}
	}
}
