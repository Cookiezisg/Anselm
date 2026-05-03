// glob.go — Glob system tool: find files matching a glob pattern under a
// root directory and return JSON enriched with type / size / mtime per
// entry. Per Forgify decision D3, Glob also covers what Claude Code's LS
// tool does — pass pattern "*" to list immediate children of a directory.
//
// Backend: github.com/bmatcuk/doublestar/v4 over os.DirFS(root). Results
// are sorted by mtime descending so the LLM sees freshly-modified files
// first when scanning a busy tree.
//
// glob.go — Glob 系统工具：在 root 目录下按 glob pattern 查找，返回带
// type / size / mtime 的 JSON。按 Forgify 决策 D3，Glob 同时覆盖 CC 的
// LS——传 pattern "*" 即列出目录直系子项。
//
// 后端 doublestar v4 + os.DirFS(root)；结果按 mtime 降序，让 LLM 在繁忙
// 树里先看到新改的文件。
package search

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"time"

	"github.com/bmatcuk/doublestar/v4"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	pathguardpkg "github.com/sunweilin/forgify/backend/internal/pkg/pathguard"
)

// ── Defaults & limits ─────────────────────────────────────────────────────────

const (
	// defaultGlobLimit caps results when LLM does not supply `limit`.
	// 100 mirrors what CC ships internally and is enough for a single
	// directory dump or a focused search.
	//
	// defaultGlobLimit 在 LLM 未传 limit 时的默认上限；100 与 CC 内部一致。
	defaultGlobLimit = 100

	// maxGlobLimit hard cap on a single Glob call. Prevents the LLM from
	// asking for a 1M-entry list that would blow the response payload.
	//
	// maxGlobLimit 硬上限；防 LLM 索取百万条把响应撑爆。
	maxGlobLimit = 1000
)

// ── Validation sentinels ──────────────────────────────────────────────────────

// (Reuses ErrEmptyPattern from grep.go — same package; the field name is
// the same on both schemas.)
//
// （复用 grep.go 的 ErrEmptyPattern——同包；两侧 schema 字段名相同。）

// ── Description & schema ──────────────────────────────────────────────────────

const globDescription = `Fast file finder: matches glob patterns and returns JSON enriched with type / size / mtime per entry.

Usage:
- Supports any glob pattern, including ` + "`**`" + ` for recursive descent (e.g. "**/*.go", "src/**/*.tsx", "*.md").
- Pass pattern "*" with a directory ` + "`path`" + ` to list immediate children — Glob fully replaces a separate LS tool.
- Output is JSON: {"root", "matches": [{"path","type","size","mtime"}], "total", "truncated"}.
- Each match's type is one of "file", "dir", or "symlink"; mtime is RFC 3339.
- Matches are sorted by mtime descending (newest first) so recently-edited files surface at the top.
- ` + "`path`" + ` (search root) defaults to the current working directory; must be absolute when provided.
- ` + "`limit`" + ` caps the result count (default 100, hard max 1000); the JSON ` + "`truncated`" + ` flag tells you whether more matches exist.
- Sensitive paths (system dirs, ~/.ssh, ~/.aws, etc.) are blocked for safety.`

var globSchema = json.RawMessage(`{
	"type": "object",
	"required": ["pattern"],
	"properties": {
		"pattern": {
			"type": "string",
			"description": "Glob pattern (e.g. \"**/*.go\", \"src/**/*.tsx\", \"*.md\"). Use \"*\" with a directory path to list immediate children."
		},
		"path": {
			"type": "string",
			"description": "Search root (absolute path). Defaults to the current working directory."
		},
		"limit": {
			"type": "number",
			"description": "Max matches to return (default 100, hard max 1000). The truncated flag in the response indicates whether more matches existed."
		}
	}
}`)

// ── Args ──────────────────────────────────────────────────────────────────────

type globArgs struct {
	Pattern string `json:"pattern"`
	Path    string `json:"path"`
	Limit   int    `json:"limit"`
}

// normalize fills cwd default for Path and applies the limit caps.
//
// normalize 把 Path 缺省补 cwd 并对 Limit 做默认/硬上限处理。
func (a *globArgs) normalize() {
	if a.Path == "" {
		if cwd, err := os.Getwd(); err == nil {
			a.Path = cwd
		}
	}
	if a.Limit == 0 {
		a.Limit = defaultGlobLimit
	}
	if a.Limit > maxGlobLimit {
		a.Limit = maxGlobLimit
	}
}

// ── Output shape ──────────────────────────────────────────────────────────────

// globMatch is one entry in the result. Times are emitted in RFC 3339 so
// the LLM can parse without a custom format.
//
// globMatch 是一条结果项；时间走 RFC 3339，让 LLM 无需自定义格式即可解析。
type globMatch struct {
	Path  string    `json:"path"`
	Type  string    `json:"type"` // "file" | "dir" | "symlink"
	Size  int64     `json:"size"`
	MTime time.Time `json:"mtime"`
}

type globResult struct {
	Root      string      `json:"root"`
	Matches   []globMatch `json:"matches"`
	Total     int         `json:"total"`
	Truncated bool        `json:"truncated"`
}

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// Glob implements the Glob system tool.
//
// Glob struct 是 Glob 系统工具。pathGuard 守卫敏感路径。
type Glob struct {
	pathGuard pathguardpkg.PathGuard
}

// Identity --------------------------------------------------------------------

func (t *Glob) Name() string                { return "Glob" }
func (t *Glob) Description() string         { return globDescription }
func (t *Glob) Parameters() json.RawMessage { return globSchema }

// Static metadata -------------------------------------------------------------

func (t *Glob) IsReadOnly() bool        { return true }
func (t *Glob) NeedsReadFirst() bool    { return false }
func (t *Glob) RequiresWorkspace() bool { return true }

// Args-dependent hooks --------------------------------------------------------

// ValidateInput rejects empty patterns, relative paths, and negative limits.
// Pattern syntax errors (e.g. an unclosed bracket) are deferred to Execute
// so the caller sees a friendlier "Invalid pattern" message rather than a
// raw doublestar error.
//
// ValidateInput 拒绝空 pattern / 相对 path / 负 limit；pattern 语法错延后到
// Execute，让用户看到友好的 "Invalid pattern" 而非原始 doublestar 错误。
func (t *Glob) ValidateInput(args json.RawMessage) error {
	var a globArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("Glob.ValidateInput: %w", err)
	}
	if a.Pattern == "" {
		return ErrEmptyPattern
	}
	if a.Path != "" && !filepath.IsAbs(a.Path) {
		return errors.New("path must be absolute when provided")
	}
	if a.Limit < 0 {
		return errors.New("limit must be non-negative")
	}
	return nil
}

func (t *Glob) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

// Execute resolves the search root, runs doublestar.Glob over os.DirFS,
// then stats each match for size/mtime/type. Results are sorted newest
// first and capped to the limit.
//
// Filesystem-level failures (root not found, permission denied) are
// returned as LLM-friendly strings, not Go errors.
//
// Execute 解析 root，用 doublestar.Glob 在 os.DirFS 上找匹配，然后逐项 stat
// 取 size/mtime/type；按 mtime 降序排，按 limit 截断。
//
// 文件系统层面错误返友好字符串，非 Go error。
func (t *Glob) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args globArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("Glob.Execute: %w", err)
	}
	args.normalize()

	if ok, reason := t.pathGuard.Allow(args.Path); !ok {
		return reason, nil
	}

	root := filepath.Clean(args.Path)
	info, err := os.Stat(root)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return "Search root not found: " + root, nil
		}
		return fmt.Sprintf("Cannot access %s: %v", root, err), nil
	}
	if !info.IsDir() {
		return "Search root must be a directory: " + root, nil
	}

	// doublestar.Glob expects forward slashes regardless of OS — relative to
	// the FS root it operates on.
	//
	// doublestar.Glob 要求 pattern 用正斜杠（不分平台），相对于 FS root。
	pattern := filepath.ToSlash(args.Pattern)
	relMatches, err := doublestar.Glob(os.DirFS(root), pattern)
	if err != nil {
		return fmt.Sprintf("Invalid glob pattern %q: %v", args.Pattern, err), nil
	}

	matches := make([]globMatch, 0, len(relMatches))
	for _, rel := range relMatches {
		if ctx.Err() != nil {
			break
		}
		full := filepath.Join(root, rel)
		// Use Lstat so symlinks report as "symlink" rather than the target's
		// type. Mirrors what an LLM expects from a file finder.
		// 用 Lstat：symlink 报 "symlink"，不是目标类型。
		st, err := os.Lstat(full)
		if err != nil {
			continue // unreadable entry — silently skip; consistent with rg/Walk pattern
		}
		matches = append(matches, globMatch{
			Path:  full,
			Type:  classifyType(st),
			Size:  st.Size(),
			MTime: st.ModTime(),
		})
	}

	// Sort by mtime descending; tie-break on path for determinism.
	// 按 mtime 降序排；相同时间用 path 字典序兜底，保证确定性。
	sort.Slice(matches, func(i, j int) bool {
		if matches[i].MTime.Equal(matches[j].MTime) {
			return matches[i].Path < matches[j].Path
		}
		return matches[i].MTime.After(matches[j].MTime)
	})

	total := len(matches)
	truncated := false
	if total > args.Limit {
		matches = matches[:args.Limit]
		truncated = true
	}

	out := globResult{
		Root:      root,
		Matches:   matches,
		Total:     total,
		Truncated: truncated,
	}
	body, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return "", fmt.Errorf("Glob.Execute: marshal result: %w", err)
	}
	return string(body), nil
}

// classifyType maps fs.FileInfo to a short string an LLM can read easily.
// "symlink" wins over "dir"/"file" because Lstat reports the link's own
// type via FileInfo.Mode().
//
// classifyType 把 fs.FileInfo 映射成 LLM 易读的短字符串；symlink 优先级最高。
func classifyType(st os.FileInfo) string {
	mode := st.Mode()
	switch {
	case mode&os.ModeSymlink != 0:
		return "symlink"
	case mode.IsDir():
		return "dir"
	default:
		return "file"
	}
}

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*Glob)(nil)
