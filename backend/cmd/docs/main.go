// Command docs is the documentation gate (GOVERNANCE.md §11): it lints docs/ for frontmatter
// validity, ID uniqueness, directory placement, lifecycle rules, freshness, the INDEX line cap,
// and orphan links. Errors exit 1 (fail the gate); warnings print but do not fail. Run from
// backend/: `go run ./cmd/docs --root=..`.
//
// Command docs 是文档门禁（GOVERNANCE §11）：lint docs/ 的 frontmatter 合法性、ID 唯一性、目录归属、
// 生命周期、新鲜度、INDEX 行数与孤儿链接。错误 → exit 1（门禁失败）；警告只打印不失败。
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

// validTypes / validStatuses / requiredFields mirror GOVERNANCE §2/§3/§6 — the single source is that
// doc; keep these in sync with it (a code change here is a doc change there, and vice versa).
//
// validTypes / validStatuses / requiredFields 对应 GOVERNANCE §2/§3/§6——事实源是那篇文档，二者保持一致。
var (
	validTypes      = map[string]bool{"concept": true, "reference": true, "how-to": true, "decision": true, "log": true, "working": true}
	validStatuses   = map[string]bool{"draft": true, "active": true, "superseded": true, "deprecated": true, "archived": true}
	requiredFields  = []string{"id", "type", "status", "owner", "created", "reviewed", "review-due", "audience"}
	indexMaxLines   = 50
	workingMaxDays  = 90
	linkRe          = regexp.MustCompile(`\[[^\]]*\]\(([^)]+)\)`)
	fencedRe        = regexp.MustCompile("(?s)```.*?```")
	inlineCodeRe    = regexp.MustCompile("`[^`]*`")
	docIDRe         = regexp.MustCompile(`^(?:DOC|WRK)-[0-9]{3}(?:-[A-Z0-9][A-Z0-9-]*)?$`)
	frontmatterDate = "2006-01-02"
)

func main() {
	root := flag.String("root", ".", "repo root (docs/ lives under it)")
	flag.Parse()

	l := &linter{docsDir: filepath.Join(*root, "docs"), now: time.Now()}
	if _, err := os.Stat(l.docsDir); err != nil {
		fmt.Fprintf(os.Stderr, "docs: no docs/ under %q: %v\n", *root, err)
		os.Exit(2)
	}
	l.run()
	// The contract-drift pass (#9's mechanical half) — see drift.go. 契约漂移 pass(#9 机械半)。
	l.checkDrift(filepath.Join(*root, "backend"))

	for _, w := range l.warns {
		fmt.Printf("⚠ %s\n", w)
	}
	for _, e := range l.errs {
		fmt.Printf("✗ %s\n", e)
	}
	if len(l.errs) > 0 {
		fmt.Printf("\n✗ docs lint: %d error(s), %d warning(s)\n", len(l.errs), len(l.warns))
		os.Exit(1)
	}
	fmt.Printf("✓ docs lint clean (%d warning(s))\n", len(l.warns))
}

type linter struct {
	docsDir string
	now     time.Time
	errs    []string
	warns   []string
	ids     map[string]string
}

func (l *linter) errf(format string, a ...any) { l.errs = append(l.errs, fmt.Sprintf(format, a...)) }
func (l *linter) warnf(format string, a ...any) {
	l.warns = append(l.warns, fmt.Sprintf(format, a...))
}

// run walks every .md under docs/ and applies the per-file checks, then the orphan-link pass.
//
// run 遍历 docs/ 下每个 .md 应用逐文件检查，再跑孤儿链接 pass。
func (l *linter) run() {
	l.ids = make(map[string]string)
	var files []string
	_ = filepath.WalkDir(l.docsDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}
		files = append(files, path)
		return nil
	})
	sort.Strings(files)
	for _, path := range files {
		l.checkFile(path)
	}
}

func (l *linter) rel(path string) string {
	r, _ := filepath.Rel(l.docsDir, path)
	return r
}

// checkFile applies frontmatter + lifecycle + special-file checks to one doc.
//
// checkFile 对一篇文档应用 frontmatter + 生命周期 + 特例检查。
func (l *linter) checkFile(path string) {
	rel := l.rel(path)
	raw, err := os.ReadFile(path)
	if err != nil {
		l.errf("%s: read: %v", rel, err)
		return
	}
	content := string(raw)

	// INDEX.md — line cap; frontmatter-exempt (entry point).
	if rel == "INDEX.md" {
		if n := strings.Count(content, "\n") + 1; n > indexMaxLines {
			l.errf("INDEX.md: %d lines > %d (GOVERNANCE §11.6)", n, indexMaxLines)
		}
		l.checkLinks(path, content)
		return
	}
	// archive/ — read-only graveyard, frontmatter-exempt.
	if strings.HasPrefix(rel, "archive/") {
		return
	}

	l.checkLinks(path, content)

	fm, ok := parseFrontmatter(content)
	if !ok {
		l.errf("%s: missing frontmatter (GOVERNANCE §3)", rel)
		return
	}
	if id := strings.TrimSpace(fm["id"]); id != "" {
		if !docIDRe.MatchString(id) {
			l.errf("%s: invalid id %q (GOVERNANCE §4)", rel, id)
		}
		if previous, exists := l.ids[id]; exists {
			l.errf("%s: duplicate id %q (already used by %s; GOVERNANCE §4)", rel, id, previous)
		} else {
			l.ids[id] = rel
		}
	}
	for _, f := range requiredFields {
		if strings.TrimSpace(fm[f]) == "" {
			l.errf("%s: frontmatter missing required field %q", rel, f)
		}
	}
	if t := fm["type"]; t != "" && !validTypes[t] {
		l.errf("%s: invalid type %q (GOVERNANCE §2)", rel, t)
	}
	if s := fm["status"]; s != "" && !validStatuses[s] {
		l.errf("%s: invalid status %q (GOVERNANCE §6)", rel, s)
	}
	if want := expectedType(rel); want != "" && fm["type"] != "" && fm["type"] != want {
		l.errf("%s: type %q does not match canonical directory type %q (GOVERNANCE §5)", rel, fm["type"], want)
	}
	if fm["status"] == "archived" {
		l.errf("%s: status archived belongs under top-level archive/ (GOVERNANCE §5/§6)", rel)
	}
	if archiveLikeWorkingPath(rel) {
		l.errf("%s: working/ cannot contain a private archive/legacy/old subtree; use top-level archive/ (GOVERNANCE §5/§9)", rel)
	}

	for _, field := range []string{"created", "reviewed", "review-due"} {
		if value := strings.TrimSpace(fm[field]); value != "" {
			if _, err := time.Parse(frontmatterDate, value); err != nil {
				l.errf("%s: frontmatter field %q must be YYYY-MM-DD, got %q (GOVERNANCE §3)", rel, field, value)
			}
		}
	}
	// review-due past → warn (not fail).
	if due, err := time.Parse(frontmatterDate, fm["review-due"]); err == nil && due.Before(l.now) {
		l.warnf("%s: review-due %s is past (re-review)", rel, fm["review-due"])
	}
	// working doc > 90 days with empty landed-into → fail.
	if fm["type"] == "working" {
		if _, exists := fm["landed-into"]; !exists {
			l.errf("%s: working frontmatter missing field %q (GOVERNANCE §3/§9)", rel, "landed-into")
		}
		if created, err := time.Parse(frontmatterDate, fm["created"]); err == nil {
			if l.now.Sub(created) > time.Duration(workingMaxDays)*24*time.Hour && strings.TrimSpace(fm["landed-into"]) == "" {
				l.errf("%s: working doc older than %dd with empty landed-into (GOVERNANCE §9)", rel, workingMaxDays)
			}
		}
	}
}

// expectedType maps canonical top-level directories to their only legal document type. Log
// documents are intentionally placed by their owning system (for example a working campaign log
// remains type=working); introducing a standalone log home requires a GOVERNANCE §2/§5 change.
//
// expectedType 把 canonical 顶层目录映射到唯一合法类型。日志随所属系统归类（例如 working 战役日志
// 仍是 type=working）；若要新增独立 log 目录，必须先改 GOVERNANCE §2/§5。
func expectedType(rel string) string {
	if rel == "GOVERNANCE.md" {
		return "concept"
	}
	switch strings.SplitN(rel, "/", 2)[0] {
	case "concepts":
		return "concept"
	case "references":
		return "reference"
	case "how-to":
		return "how-to"
	case "decisions":
		return "decision"
	case "working":
		return "working"
	default:
		return ""
	}
}

// archiveLikeWorkingPath rejects the historical anti-pattern working/<campaign>/archived/. There is
// exactly one graveyard: docs/archive/. Segment matching avoids false positives in prose filenames.
//
// archiveLikeWorkingPath 拒绝历史反模式 working/<战役>/archived/。墓地只有 docs/archive/ 一个；
// 按路径段匹配，避免普通文件名误报。
func archiveLikeWorkingPath(rel string) bool {
	if !strings.HasPrefix(rel, "working/") {
		return false
	}
	parts := strings.Split(filepath.ToSlash(rel), "/")
	for _, part := range parts[1 : len(parts)-1] {
		switch strings.ToLower(part) {
		case "archive", "archived", "legacy", "old":
			return true
		}
	}
	return false
}

// checkLinks flags orphan relative links: a markdown link to a local path (not http/anchor) whose
// target does not exist. Code spans (fenced ``` blocks and inline `code`) are stripped first so an
// illustrative link inside backticks (e.g. GOVERNANCE's "use `[api.md](…)`" example) is not checked.
//
// checkLinks 报告孤儿相对链接：指向本地路径（非 http/锚点）但目标不存在的 markdown 链接。先剥代码片段
// （``` 块 + 行内 `code`），故反引号里的说明性链接（如 GOVERNANCE 的 `[api.md](…)` 示例）不被检查。
func (l *linter) checkLinks(path, content string) {
	dir := filepath.Dir(path)
	content = inlineCodeRe.ReplaceAllString(fencedRe.ReplaceAllString(content, ""), "")
	for _, m := range linkRe.FindAllStringSubmatch(content, -1) {
		target := strings.TrimSpace(m[1])
		if target == "" || strings.HasPrefix(target, "#") || strings.Contains(target, "://") {
			continue
		}
		target = strings.SplitN(target, "#", 2)[0] // drop anchor
		if target == "" {
			continue
		}
		if _, err := os.Stat(filepath.Join(dir, target)); err != nil {
			l.errf("%s: orphan link → %q (target missing)", l.rel(path), m[1])
		}
	}
}

// parseFrontmatter reads the leading `---` … `---` YAML-ish block into a key→value map (values kept
// verbatim; array values like `[human, ai]` stay as the raw string, presence is what matters).
// Returns ok=false when the file has no frontmatter block.
//
// parseFrontmatter 把开头的 `---`…`---` 块读成 key→value（值原样；`[human, ai]` 数组保留原串，看存在性）。
// 无 frontmatter 块返 ok=false。
func parseFrontmatter(content string) (map[string]string, bool) {
	if !strings.HasPrefix(content, "---\n") {
		return nil, false
	}
	end := strings.Index(content[4:], "\n---")
	if end < 0 {
		return nil, false
	}
	block := content[4 : 4+end]
	fm := map[string]string{}
	for line := range strings.SplitSeq(block, "\n") {
		if i := strings.Index(line, ":"); i > 0 {
			fm[strings.TrimSpace(line[:i])] = strings.TrimSpace(line[i+1:])
		}
	}
	return fm, true
}
