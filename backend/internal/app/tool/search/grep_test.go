// grep_test.go — unit tests for the Grep system tool, focused on the
// stdlib backend so they pass without ripgrep installed. The stdlib
// backend is the surface-equivalent fallback; if it works, rg
// (the speed-up path) only adds throughput.
//
// grep_test.go — Grep 单元测试，聚焦 stdlib 后端，让它在没装 ripgrep
// 时也能跑过。stdlib 是 surface-equivalent 兜底；它对了，rg 只是加速。
package search

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	pathguardpkg "github.com/sunweilin/forgify/backend/internal/pkg/pathguard"
)

// ── Helpers ───────────────────────────────────────────────────────────────────

// newStdlibGrep builds a Grep wired with the default PathGuard and an
// empty rgPath, forcing tests through the stdlib backend regardless of
// whether `rg` is installed on the runner.
//
// newStdlibGrep 构造装好默认 PathGuard 的 Grep 并把 rgPath 强置空，
// 让 test 不论 runner 装没装 rg 都走 stdlib 后端。
func newStdlibGrep() *Grep {
	return &Grep{pathGuard: pathguardpkg.NewDefault(), rgPath: ""}
}

// seedTree creates a small fixture tree under t.TempDir() and returns its
// absolute root. Files cover .go / .py / nested / noise-dir cases.
//
// seedTree 在 t.TempDir() 下种一棵小测试树并返回绝对 root。
func seedTree(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	files := map[string]string{
		"a.go":             "package main\nfunc Hello() {}\nfunc World() {}\n",
		"b.go":             "package main\nfunc HelloAgain() {}\n",
		"sub/c.go":         "package sub\nfunc DeepHello() {}\n",
		"sub/d.py":         "def hello():\n    pass\n",
		"README.md":        "# Hello world\nNot Go code.\n",
		"node_modules/x.js": "console.log('should be skipped');\n",
		".git/HEAD":        "ref: refs/heads/main\n",
	}
	for rel, body := range files {
		full := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatalf("mkdir: %v", err)
		}
		if err := os.WriteFile(full, []byte(body), 0o644); err != nil {
			t.Fatalf("write %s: %v", rel, err)
		}
	}
	return root
}

func runGrep(t *testing.T, g *Grep, args grepArgs) string {
	t.Helper()
	args.normalize()
	body, err := json.Marshal(args)
	if err != nil {
		t.Fatalf("marshal args: %v", err)
	}
	out, err := g.Execute(context.Background(), string(body))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	return out
}

// ── ValidateInput ─────────────────────────────────────────────────────────────

func TestGrep_ValidateInput_RequiresPattern(t *testing.T) {
	g := newStdlibGrep()
	if err := g.ValidateInput(json.RawMessage(`{}`)); !errors.Is(err, ErrEmptyPattern) {
		t.Fatalf("want ErrEmptyPattern, got %v", err)
	}
	if err := g.ValidateInput(json.RawMessage(`{"pattern":"   "}`)); !errors.Is(err, ErrEmptyPattern) {
		t.Fatalf("whitespace-only pattern should fail, got %v", err)
	}
}

func TestGrep_ValidateInput_RejectsBadOutputMode(t *testing.T) {
	g := newStdlibGrep()
	err := g.ValidateInput(json.RawMessage(`{"pattern":"x","output_mode":"bogus"}`))
	if !errors.Is(err, ErrInvalidOutputMode) {
		t.Fatalf("want ErrInvalidOutputMode, got %v", err)
	}
}

func TestGrep_ValidateInput_RejectsNegativeNumbers(t *testing.T) {
	g := newStdlibGrep()
	cases := []string{
		`{"pattern":"x","-A":-1}`,
		`{"pattern":"x","-B":-1}`,
		`{"pattern":"x","-C":-1}`,
		`{"pattern":"x","head_limit":-1}`,
	}
	for _, c := range cases {
		if err := g.ValidateInput(json.RawMessage(c)); err == nil {
			t.Errorf("expected error for %s", c)
		}
	}
}

func TestGrep_ValidateInput_RejectsRelativePath(t *testing.T) {
	g := newStdlibGrep()
	err := g.ValidateInput(json.RawMessage(`{"pattern":"x","path":"relative/path"}`))
	if err == nil || !strings.Contains(err.Error(), "absolute") {
		t.Fatalf("want absolute-path error, got %v", err)
	}
}

func TestGrep_ValidateInput_AcceptsValidArgs(t *testing.T) {
	g := newStdlibGrep()
	if err := g.ValidateInput(json.RawMessage(`{"pattern":"foo","-A":2,"-n":true}`)); err != nil {
		t.Fatalf("unexpected: %v", err)
	}
}

// ── normalize ─────────────────────────────────────────────────────────────────

func TestGrepArgs_NormalizeFillsDefaults(t *testing.T) {
	a := grepArgs{Around: 3}
	a.normalize()
	if a.OutputMode != OutputModeFilesWithMatches {
		t.Errorf("OutputMode default = %q, want files_with_matches", a.OutputMode)
	}
	if a.Before != 3 || a.After != 3 {
		t.Errorf("-C did not fan out to -A/-B: before=%d after=%d", a.Before, a.After)
	}
	if a.Path == "" {
		t.Errorf("Path should default to cwd")
	}
}

func TestGrepArgs_NormalizeRespectsExplicitAB(t *testing.T) {
	// -C should not override -A/-B when caller already set them.
	// 调用方已设 -A/-B 时 -C 不应覆盖。
	a := grepArgs{Around: 3, Before: 1, After: 5}
	a.normalize()
	if a.Before != 1 || a.After != 5 {
		t.Errorf("explicit -A/-B clobbered: before=%d after=%d", a.Before, a.After)
	}
}

// ── Output modes ──────────────────────────────────────────────────────────────

func TestGrep_FilesWithMatches_DefaultMode(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{Pattern: "Hello", Path: root})
	wantPaths := []string{"a.go", "b.go", "sub/c.go", "README.md"}
	for _, p := range wantPaths {
		full := filepath.Join(root, p)
		if !strings.Contains(out, full) {
			t.Errorf("output missing %s\nfull output:\n%s", full, out)
		}
	}
	if strings.Contains(out, "node_modules") {
		t.Errorf("node_modules should be skipped:\n%s", out)
	}
	if strings.Contains(out, ".git") {
		t.Errorf(".git should be skipped:\n%s", out)
	}
}

func TestGrep_Content_ReportsMatchedLines(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{
		Pattern:    "Hello",
		Path:       root,
		OutputMode: OutputModeContent,
		ShowLines:  true,
	})
	// content mode should produce `<path>:<lineno>:<line>` for each hit.
	// content 模式应输出每命中 `<path>:<lineno>:<line>`。
	if !strings.Contains(out, "a.go:2:func Hello()") {
		t.Errorf("missing exact match line in:\n%s", out)
	}
}

func TestGrep_Count_EmitsPerFileCounts(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{
		Pattern:    "Hello",
		Path:       root,
		OutputMode: OutputModeCount,
	})
	// a.go has 1 occurrence ("Hello") — but normalize/regex catches both
	// "Hello" and "HelloAgain" too if pattern is "Hello". So a.go = 1,
	// b.go = 1, sub/c.go = 1, README.md = 1.
	//
	// a.go 含 1 处 "Hello"；b.go 含 1 处 "HelloAgain"（也被 "Hello" 匹配）；
	// sub/c.go 含 1 处；README.md 含 1 处。
	want := []string{
		filepath.Join(root, "a.go") + ":1",
		filepath.Join(root, "b.go") + ":1",
	}
	for _, w := range want {
		if !strings.Contains(out, w) {
			t.Errorf("missing %q in count output:\n%s", w, out)
		}
	}
}

// ── Filters: type / glob ──────────────────────────────────────────────────────

func TestGrep_TypeFilter_GoOnly(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{Pattern: "Hello", Path: root, Type: "go"})
	if strings.Contains(out, "README.md") {
		t.Errorf("type=go should exclude .md files:\n%s", out)
	}
	if strings.Contains(out, ".py") {
		t.Errorf("type=go should exclude .py files:\n%s", out)
	}
	if !strings.Contains(out, "a.go") {
		t.Errorf("type=go should include .go files:\n%s", out)
	}
}

func TestGrep_TypeFilter_UnknownType_NoResults(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{Pattern: "Hello", Path: root, Type: "fortran"})
	if !strings.Contains(out, "No matches") {
		t.Errorf("unknown type should yield no matches, got:\n%s", out)
	}
}

func TestGrep_GlobFilter_BasenamePattern(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{Pattern: "Hello", Path: root, Glob: "*.go"})
	if strings.Contains(out, "README.md") {
		t.Errorf("glob *.go should not include README.md:\n%s", out)
	}
	if !strings.Contains(out, "a.go") {
		t.Errorf("glob *.go should include a.go:\n%s", out)
	}
}

func TestGrep_GlobFilter_DoubleStarPattern(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{Pattern: "Hello", Path: root, Glob: "sub/**/*.go"})
	if strings.Contains(out, filepath.Join(root, "a.go")) {
		t.Errorf("sub/**/*.go should not include top-level a.go:\n%s", out)
	}
	if !strings.Contains(out, filepath.Join(root, "sub", "c.go")) {
		t.Errorf("sub/**/*.go should include sub/c.go:\n%s", out)
	}
}

// ── Modifiers: -i / -n / -A / -B / -C / multiline / head_limit ────────────────

func TestGrep_IgnoreCase(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{
		Pattern:    "HELLO",
		Path:       root,
		IgnoreCase: true,
		OutputMode: OutputModeContent,
	})
	if !strings.Contains(out, "func Hello()") {
		t.Errorf("ignore_case should match Hello as HELLO:\n%s", out)
	}
}

func TestGrep_AfterContextEmitted(t *testing.T) {
	g := newStdlibGrep()
	dir := t.TempDir()
	body := "line1\nMATCH here\nline3\nline4\n"
	target := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(target, []byte(body), 0o644); err != nil {
		t.Fatalf("seed: %v", err)
	}
	out := runGrep(t, g, grepArgs{
		Pattern:    "MATCH",
		Path:       target,
		OutputMode: OutputModeContent,
		ShowLines:  true,
		After:      2,
	})
	// Expect line 2 (match), 3 (after), 4 (after); single-file root drops path.
	// 期望第 2 行（匹配）、3、4（after）；单文件 root 不带 path 前缀。
	wantParts := []string{"2:MATCH here", "3-line3", "4-line4"}
	for _, w := range wantParts {
		if !strings.Contains(out, w) {
			t.Errorf("missing %q in:\n%s", w, out)
		}
	}
}

func TestGrep_BeforeContextEmitted(t *testing.T) {
	g := newStdlibGrep()
	dir := t.TempDir()
	body := "line1\nline2\nMATCH here\nline4\n"
	target := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(target, []byte(body), 0o644); err != nil {
		t.Fatalf("seed: %v", err)
	}
	out := runGrep(t, g, grepArgs{
		Pattern:    "MATCH",
		Path:       target,
		OutputMode: OutputModeContent,
		ShowLines:  true,
		Before:     2,
	})
	wantParts := []string{"1-line1", "2-line2", "3:MATCH here"}
	for _, w := range wantParts {
		if !strings.Contains(out, w) {
			t.Errorf("missing %q in:\n%s", w, out)
		}
	}
}

func TestGrep_ContextSeparator_DashForContext_ColonForMatch(t *testing.T) {
	g := newStdlibGrep()
	dir := t.TempDir()
	body := "ctx\nHIT\nctx2\n"
	target := filepath.Join(dir, "f.txt")
	if err := os.WriteFile(target, []byte(body), 0o644); err != nil {
		t.Fatalf("seed: %v", err)
	}
	out := runGrep(t, g, grepArgs{
		Pattern:    "HIT",
		Path:       target,
		OutputMode: OutputModeContent,
		ShowLines:  true,
		Around:     1,
	})
	if !strings.Contains(out, "1-ctx") {
		t.Errorf("context line should use '-' separator: %s", out)
	}
	if !strings.Contains(out, "2:HIT") {
		t.Errorf("match line should use ':' separator: %s", out)
	}
	if !strings.Contains(out, "3-ctx2") {
		t.Errorf("after-context should use '-': %s", out)
	}
}

func TestGrep_Multiline_AcrossLines(t *testing.T) {
	g := newStdlibGrep()
	dir := t.TempDir()
	body := "type Foo struct {\n\tBar int\n\tBaz string\n}\n"
	target := filepath.Join(dir, "f.go")
	if err := os.WriteFile(target, []byte(body), 0o644); err != nil {
		t.Fatalf("seed: %v", err)
	}
	out := runGrep(t, g, grepArgs{
		Pattern:    `struct \{[\s\S]*?Baz`,
		Path:       target,
		OutputMode: OutputModeContent,
		ShowLines:  true,
		Multiline:  true,
	})
	// Multiline match spans lines 1–3; we expect at minimum line 1 (the
	// struct opener) to appear in output.
	// multiline 匹配横跨第 1–3 行；至少结构体起始那行要出现。
	if !strings.Contains(out, "1:type Foo") {
		t.Errorf("multiline match should surface line 1, got:\n%s", out)
	}
}

func TestGrep_HeadLimit_FilesMode(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{
		Pattern:   "Hello",
		Path:      root,
		HeadLimit: 1,
	})
	// Exactly one path should appear in the body before the truncation hint.
	// 截断提示前应只有 1 个 path。
	if !strings.Contains(out, "[truncated at 1 files") {
		t.Errorf("expected truncation hint, got:\n%s", out)
	}
	pathLines := 0
	for _, ln := range strings.Split(strings.TrimSpace(out), "\n") {
		if !strings.HasPrefix(ln, "...") && ln != "" {
			pathLines++
		}
	}
	if pathLines != 1 {
		t.Errorf("expected 1 path line under head_limit=1, got %d:\n%s", pathLines, out)
	}
}

func TestGrep_HeadLimit_ContentMode_CapsMatches(t *testing.T) {
	g := newStdlibGrep()
	dir := t.TempDir()
	target := filepath.Join(dir, "many.txt")
	body := strings.Repeat("MATCH\n", 10)
	if err := os.WriteFile(target, []byte(body), 0o644); err != nil {
		t.Fatalf("seed: %v", err)
	}
	out := runGrep(t, g, grepArgs{
		Pattern:    "MATCH",
		Path:       target,
		OutputMode: OutputModeContent,
		HeadLimit:  3,
	})
	if !strings.Contains(out, "[truncated at 3 matches") {
		t.Errorf("expected match-cap hint, got:\n%s", out)
	}
}

// ── Path safety + error paths ─────────────────────────────────────────────────

func TestGrep_PathGuard_DeniesSensitivePath(t *testing.T) {
	g := newStdlibGrep()
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skip("no home dir; PathGuard test needs ~ expansion")
	}
	denied := filepath.Join(home, ".ssh", "doesnotexist-test")
	out := runGrep(t, g, grepArgs{Pattern: "anything", Path: denied})
	if !strings.Contains(out, "denied") {
		t.Errorf("expected PathGuard denial message, got: %q", out)
	}
}

func TestGrep_NonexistentPath_ReportsClearly(t *testing.T) {
	g := newStdlibGrep()
	missing := filepath.Join(t.TempDir(), "nope")
	out := runGrep(t, g, grepArgs{Pattern: "anything", Path: missing})
	if !strings.Contains(out, "Search root not found") {
		t.Errorf("expected not-found message, got: %q", out)
	}
}

func TestGrep_InvalidRegex_ReportsCleanly(t *testing.T) {
	g := newStdlibGrep()
	dir := t.TempDir()
	out := runGrep(t, g, grepArgs{Pattern: "(unclosed", Path: dir})
	if !strings.Contains(out, "Invalid regex pattern") {
		t.Errorf("expected regex error message, got: %q", out)
	}
}

func TestGrep_NoMatches_ReportsExplicitly(t *testing.T) {
	g := newStdlibGrep()
	root := seedTree(t)
	out := runGrep(t, g, grepArgs{Pattern: "ZzzNoSuchTokenZzz", Path: root})
	if !strings.Contains(out, "No matches for") {
		t.Errorf("expected explicit no-matches message, got: %q", out)
	}
}

// ── Single-file root ──────────────────────────────────────────────────────────

func TestGrep_SingleFileRoot_OmitsPathPrefix(t *testing.T) {
	g := newStdlibGrep()
	dir := t.TempDir()
	target := filepath.Join(dir, "single.txt")
	if err := os.WriteFile(target, []byte("alpha\nbeta\n"), 0o644); err != nil {
		t.Fatalf("seed: %v", err)
	}
	out := runGrep(t, g, grepArgs{
		Pattern:    "beta",
		Path:       target,
		OutputMode: OutputModeContent,
		ShowLines:  true,
	})
	// Single-file root: no `<path>:` prefix on each line, just `<lineno>:<text>`.
	// 单文件 root：每行无 `<path>:` 前缀，只 `<lineno>:<text>`。
	want := "2:beta"
	if !strings.Contains(out, want) {
		t.Errorf("want %q in:\n%s", want, out)
	}
	if strings.Contains(out, target+":") {
		t.Errorf("single-file root should not prefix path:\n%s", out)
	}
}

// ── Identity / metadata ───────────────────────────────────────────────────────

func TestGrep_IdentityMethods(t *testing.T) {
	g := newStdlibGrep()
	if g.Name() != "Grep" {
		t.Errorf("Name = %q, want Grep", g.Name())
	}
	if g.Description() == "" {
		t.Error("Description should not be empty")
	}
	if len(g.Parameters()) == 0 {
		t.Error("Parameters should not be empty")
	}
}

func TestGrep_StaticMetadata(t *testing.T) {
	g := newStdlibGrep()
	if !g.IsReadOnly() {
		t.Error("Grep should be read-only")
	}
	if g.NeedsReadFirst() {
		t.Error("Grep should not require Read first")
	}
	if !g.RequiresWorkspace() {
		t.Error("Grep should require workspace")
	}
}

// Sanity that the schema parses as JSON Schema-shaped.
//
// Sanity 检查 schema 能解出 JSON-Schema 形态。
func TestGrep_Schema_IsParsableObject(t *testing.T) {
	var doc map[string]any
	if err := json.Unmarshal(grepSchema, &doc); err != nil {
		t.Fatalf("schema is not valid JSON: %v", err)
	}
	if doc["type"] != "object" {
		t.Errorf("schema type = %v, want object", doc["type"])
	}
	props, ok := doc["properties"].(map[string]any)
	if !ok {
		t.Fatalf("schema properties not an object")
	}
	for _, want := range []string{"pattern", "path", "glob", "type", "output_mode", "-A", "-B", "-C", "-n", "-i", "multiline", "head_limit"} {
		if _, ok := props[want]; !ok {
			t.Errorf("schema missing property %q", want)
		}
	}
}

// Stable fixture-print helper — handy when a failure dumps debug info.
//
// Stable fixture-print helper —— 失败时方便打调试信息。
func dumpListing(root string) string {
	var sb strings.Builder
	_ = filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		fmt.Fprintf(&sb, "  %s\n", p)
		return nil
	})
	return sb.String()
}

// Compile-time keep-alive to silence "unused" if dumpListing is not used
// by any current test (kept for future debugging).
//
// 编译时保活，让未引用的 dumpListing 不报 unused（留给未来调试）。
var _ = dumpListing
