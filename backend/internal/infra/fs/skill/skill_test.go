package skill

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	skilldomain "github.com/sunweilin/foryx/backend/internal/domain/skill"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
)

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

func TestStore_RoundTrip(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	fm := skilldomain.Frontmatter{
		Name:         "code-review",
		Description:  "review code",
		AllowedTools: []string{"Read", "fn_abc"},
		Context:      "inline",
		Source:       "user",
		Arguments:    []string{"target"},
	}
	if err := st.Save(ctx, "code-review", fm, "Review $ARGUMENTS now."); err != nil {
		t.Fatalf("save: %v", err)
	}
	got, err := st.Get(ctx, "code-review")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Name != "code-review" || got.Description != "review code" || got.Context != "inline" || got.Source != "user" {
		t.Fatalf("metadata mismatch: %+v", got)
	}
	if got.Body != "Review $ARGUMENTS now." {
		t.Fatalf("body mismatch: %q", got.Body)
	}
	if len(got.Frontmatter.AllowedTools) != 2 || got.Frontmatter.AllowedTools[1] != "fn_abc" {
		t.Fatalf("allowed-tools roundtrip mismatch: %+v", got.Frontmatter.AllowedTools)
	}
	if len(got.Frontmatter.Arguments) != 1 || got.Frontmatter.Arguments[0] != "target" {
		t.Fatalf("arguments roundtrip mismatch: %+v", got.Frontmatter.Arguments)
	}
}

func TestStore_ListExcludesBodyAndFiltersSource(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	_ = st.Save(ctx, "a", skilldomain.Frontmatter{Name: "a", Description: "da", Source: "user"}, "body-a")
	_ = st.Save(ctx, "b", skilldomain.Frontmatter{Name: "b", Description: "db", Source: "ai"}, "body-b")

	all, err := st.List(ctx, skilldomain.ListFilter{})
	if err != nil || len(all) != 2 {
		t.Fatalf("list all: n=%d err=%v", len(all), err)
	}
	if all[0].Name != "a" || all[1].Name != "b" {
		t.Fatalf("list should be name-sorted: %+v", all)
	}
	if all[0].Body != "" {
		t.Fatalf("List must omit body, got %q", all[0].Body)
	}
	ai, err := st.List(ctx, skilldomain.ListFilter{Source: "ai"})
	if err != nil || len(ai) != 1 || ai[0].Name != "b" {
		t.Fatalf("source filter failed: n=%d err=%v", len(ai), err)
	}
}

func TestStore_DeleteAndExists(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	_ = st.Save(ctx, "x", skilldomain.Frontmatter{Name: "x", Description: "d"}, "b")

	if ok, _ := st.Exists(ctx, "x"); !ok {
		t.Fatal("x should exist")
	}
	if err := st.Delete(ctx, "x"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if ok, _ := st.Exists(ctx, "x"); ok {
		t.Fatal("x should be gone")
	}
	if _, err := st.Get(ctx, "x"); !errors.Is(err, skilldomain.ErrNotFound) {
		t.Fatalf("get deleted should be NotFound, got %v", err)
	}
	if err := st.Delete(ctx, "x"); !errors.Is(err, skilldomain.ErrNotFound) {
		t.Fatalf("delete missing should be NotFound, got %v", err)
	}
}

func TestStore_WorkspaceIsolation(t *testing.T) {
	st := New(t.TempDir())
	_ = st.Save(ctxWS("ws_1"), "only1", skilldomain.Frontmatter{Name: "only1", Description: "d"}, "b")

	items, err := st.List(ctxWS("ws_2"), skilldomain.ListFilter{})
	if err != nil {
		t.Fatalf("list ws_2: %v", err)
	}
	if len(items) != 0 {
		t.Fatalf("ws_2 must not see ws_1's skills, got %+v", items)
	}
}

func TestStore_InvalidNameRejected(t *testing.T) {
	st := New(t.TempDir())
	ctx := ctxWS("ws_1")
	if err := st.Save(ctx, "Bad Name", skilldomain.Frontmatter{Name: "Bad Name", Description: "d"}, "b"); !errors.Is(err, skilldomain.ErrInvalidName) {
		t.Fatalf("invalid slug should be ErrInvalidName, got %v", err)
	}
	if _, err := st.Get(ctx, "../escape"); !errors.Is(err, skilldomain.ErrInvalidName) {
		t.Fatalf("path-traversal name should be ErrInvalidName, got %v", err)
	}
}

func TestStore_SkipsUnparseable(t *testing.T) {
	base := t.TempDir()
	st := New(base)
	ctx := ctxWS("ws_1")
	_ = st.Save(ctx, "good", skilldomain.Frontmatter{Name: "good", Description: "d"}, "body")

	// 手写一个无 frontmatter 围栏的坏 skill 目录
	badDir := filepath.Join(base, "workspaces", "ws_1", "skills", "bad")
	if err := os.MkdirAll(badDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(badDir, "SKILL.md"), []byte("no frontmatter here"), 0o644); err != nil {
		t.Fatalf("write bad: %v", err)
	}

	items, err := st.List(ctx, skilldomain.ListFilter{})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(items) != 1 || items[0].Name != "good" {
		t.Fatalf("unparseable skill must be skipped, got %+v", items)
	}
}
