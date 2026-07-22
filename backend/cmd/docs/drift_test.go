package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Contract-drift detector tests — a mini repo (fake backend source + fake index docs) per case,
// asserting each pass goes red on real drift and stays green on registered facts + every exemption
// (comments, helper domains, table-column prose, filenames, prose dot-paths).
//
// 漂移检测器测试——每例一个迷你仓(假后端源+假索引文档),断言各 pass 真漂移必红、已登记与全部
// 豁免形态(注释/helper 域/表列散文/文件名/散文点路径)保持绿。
func driftFixture(t *testing.T, goFiles map[string]string, docs map[string]string) *linter {
	t.Helper()
	root := t.TempDir()
	for rel, content := range goFiles {
		p := filepath.Join(root, "backend", "internal", rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	for rel, content := range docs {
		p := filepath.Join(root, "docs", "references", "backend", rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	l := &linter{docsDir: filepath.Join(root, "docs")}
	l.checkDrift(filepath.Join(root, "backend"))
	return l
}

func hasErr(l *linter, substr string) bool {
	for _, e := range l.errs {
		if strings.Contains(e, substr) {
			return true
		}
	}
	return false
}

const baseDocs = "| `GOOD_CODE` | 400 | msg |\n"

func TestDrift_ErrorCodes(t *testing.T) {
	goSrc := `package x
var a = errorspkg.New(errorspkg.KindInvalid, "GOOD_CODE", "m")
var b = errorspkg.New(errorspkg.KindInvalid, "MISSING_FROM_DOC", "m")
// comment example must not count: errorspkg.New(errorspkg.KindInvalid, "COMMENT_ONLY", "m")
`
	l := driftFixture(t,
		map[string]string{"app/x/x.go": goSrc},
		map[string]string{"error-codes.md": baseDocs + "| `GHOST_CODE` | 400 | msg |\n", "events.md": "", "api.md": "", "database.md": ""},
	)
	if !hasErr(l, "MISSING_FROM_DOC") {
		t.Errorf("unregistered code must go red; errs=%v", l.errs)
	}
	if !hasErr(l, "GHOST_CODE") {
		t.Errorf("ghost registration must go red; errs=%v", l.errs)
	}
	if hasErr(l, "GOOD_CODE") || hasErr(l, "COMMENT_ONLY") {
		t.Errorf("registered / comment-only codes must stay green; errs=%v", l.errs)
	}
}

func TestDrift_Events(t *testing.T) {
	goSrc := `package x
func f(s S, ctx C) {
	s.emitter.Emit(ctx, "relation.dependency_broken", nil)
	s.emitter.Broadcast(ctx, "sandbox.env_deleted", nil)
	s.emitter.Emit(ctx, "widget.unregistered", nil)
	publish(ctx, "lifecycle_changed", nil)
	_ = "workflow." + "x" // the helper prefix idiom 前缀拼接惯例
	open(ctx, "skill.md") // a filename, not an event 文件名非事件
}
`
	events := "⊞ `relation.dependency_broken` · ⤳ `sandbox.env_deleted` · `workflow.lifecycle_changed`(helper 域)\n" +
		"`ghost.event` 直写幽灵 · `payload.name` 散文点路径 · `flowruns.status` 表列引用\n"
	l := driftFixture(t,
		map[string]string{"app/x/x.go": goSrc, "infra/store/f/f.go": "package f\nvar d = `CREATE TABLE IF NOT EXISTS flowruns (id TEXT)`\n"},
		map[string]string{"events.md": events, "error-codes.md": "", "api.md": "", "database.md": "| `flowruns` | id |\n"},
	)
	if !hasErr(l, "widget.unregistered") {
		t.Errorf("unregistered event must go red; errs=%v", l.errs)
	}
	if !hasErr(l, "ghost.event") {
		t.Errorf("dotted ghost must go red; errs=%v", l.errs)
	}
	for _, green := range []string{"relation.dependency_broken", "sandbox.env_deleted", "workflow.lifecycle_changed", "payload.name", "flowruns.status", "skill.md"} {
		if hasErr(l, green) {
			t.Errorf("%s must stay green; errs=%v", green, l.errs)
		}
	}
}

func TestDrift_Endpoints(t *testing.T) {
	goSrc := `package h
func (h H) Register(mux M) {
	mux.HandleFunc("GET /api/v1/gadgets", h.List)
	mux.HandleFunc("POST /api/v1/gadgets/{idAction}", h.Act)
	mux.HandleFunc("GET /api/v1/unheard-of/{id}/subthing", h.Sub)
}
`
	l := driftFixture(t,
		map[string]string{"transport/h/h.go": goSrc},
		map[string]string{"api.md": "gadgets:CRUD 与動作。\n", "error-codes.md": "", "events.md": "", "database.md": ""},
	)
	if !hasErr(l, `"unheard-of"`) || !hasErr(l, `"subthing"`) {
		t.Errorf("unregistered resource words must go red; errs=%v", l.errs)
	}
	if hasErr(l, "gadgets") {
		t.Errorf("registered resource word must stay green; errs=%v", l.errs)
	}
}

func TestDrift_Tables(t *testing.T) {
	goSrc := "package s\nvar ddl = `CREATE TABLE IF NOT EXISTS widgets (id TEXT)`\n" +
		"var ddl2 = `CREATE TABLE IF NOT EXISTS orphans (id TEXT)`\n" +
		"var ddl3 = `CREATE VIRTUAL TABLE IF NOT EXISTS search_fts USING fts5(x)`\n"
	l := driftFixture(t,
		map[string]string{"infra/store/s/s.go": goSrc},
		map[string]string{
			"database.md":            "| `widgets` | id | 索引 |\n| `phantom` | id | 索引 |\n",
			"foundation/platform.md": "地基自有表 `search_fts` 登在这里。\n",
			"error-codes.md":         "", "events.md": "", "api.md": "",
		},
	)
	if !hasErr(l, "table orphans") {
		t.Errorf("unmentioned table must go red; errs=%v", l.errs)
	}
	if !hasErr(l, "phantom") {
		t.Errorf("ghost table row must go red; errs=%v", l.errs)
	}
	if hasErr(l, "widgets") || hasErr(l, "search_fts") {
		t.Errorf("registered / foundation-fallback tables must stay green; errs=%v", l.errs)
	}
}
