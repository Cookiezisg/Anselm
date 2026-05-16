package document

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestSentinels_UniqueAndPrefixed(t *testing.T) {
	sentinels := []error{
		ErrNotFound,
		ErrInvalidParent,
		ErrNameConflict,
		ErrContentTooLarge,
		ErrInvalidName,
		ErrParentNotFound,
	}
	seen := make(map[string]bool, len(sentinels))
	for _, e := range sentinels {
		msg := e.Error()
		if !strings.HasPrefix(msg, "document: ") {
			t.Errorf("sentinel %q must start with 'document: '", msg)
		}
		if seen[msg] {
			t.Errorf("duplicate sentinel message: %q", msg)
		}
		seen[msg] = true
	}
}

func TestDocument_TableName(t *testing.T) {
	if (Document{}).TableName() != "documents" {
		t.Errorf("TableName should be 'documents'")
	}
}

func TestDocument_JSONRoundTrip(t *testing.T) {
	parent := "doc_parent"
	d := Document{
		ID:          "doc_abc123",
		UserID:      "local-user",
		ParentID:    &parent,
		Name:        "API spec",
		Description: "Service API contract",
		Content:     "# API spec\n\n...",
		Tags:        []string{"api", "spec"},
		Position:    2,
		Path:        "/Projects/Alpha/API spec",
		SizeBytes:   2048,
	}
	data, err := json.Marshal(d)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	mustContain := []string{
		`"id":"doc_abc123"`,
		`"userId":"local-user"`,
		`"parentId":"doc_parent"`,
		`"name":"API spec"`,
		`"description":"Service API contract"`,
		`"path":"/Projects/Alpha/API spec"`,
		`"position":2`,
		`"sizeBytes":2048`,
		`"tags":["api","spec"]`,
	}
	got := string(data)
	for _, want := range mustContain {
		if !strings.Contains(got, want) {
			t.Errorf("JSON missing %q; got: %s", want, got)
		}
	}

	var back Document
	if err := json.Unmarshal(data, &back); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if back.Name != d.Name || back.Path != d.Path || back.Position != d.Position {
		t.Errorf("round-trip mismatch: %+v vs %+v", back, d)
	}
	if back.ParentID == nil || *back.ParentID != parent {
		t.Errorf("ParentID round-trip mismatch: %v", back.ParentID)
	}
}

func TestDocument_JSONRoundTrip_RootHasNullParent(t *testing.T) {
	d := Document{
		ID:     "doc_root",
		UserID: "local-user",
		Name:   "Project Alpha",
		Path:   "/Project Alpha",
	}
	data, err := json.Marshal(d)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	got := string(data)
	if strings.Contains(got, `"parentId"`) {
		t.Errorf("root doc should omit parentId in JSON; got: %s", got)
	}
}

func TestConstants(t *testing.T) {
	if MaxContentBytes != 1<<20 {
		t.Errorf("MaxContentBytes should be 1 MB; got %d", MaxContentBytes)
	}
	if MaxNameLength != 256 {
		t.Errorf("MaxNameLength should be 256; got %d", MaxNameLength)
	}
}
