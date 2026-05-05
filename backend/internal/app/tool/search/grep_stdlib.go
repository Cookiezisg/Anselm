// grep_stdlib.go — Grep stdlib fallback backend: filepath.WalkDir +
// bufio.Scanner + regexp.Regexp. Used when ripgrep is missing from PATH.
// Slower than rg on large trees (no SIMD, no .gitignore awareness) but
// surface-equivalent: same args, same output formats, same head_limit.
//
// Design choices:
//   - Skip well-known noise dirs (.git / node_modules / .venv) without
//     attempting full .gitignore parsing — that would be too much code for
//     a fallback. Users who need .gitignore should install rg.
//   - Multiline mode reads each candidate file fully into memory (capped
//     by maxStdlibFileBytes). Single-line mode streams via bufio.Scanner
//     with the Read tool's 8 MiB line cap.
//   - Glob match uses doublestar so `**/*.go` works in both backends.
//
// grep_stdlib.go — Grep 的 stdlib 后端兜底：filepath.WalkDir +
// bufio.Scanner + regexp.Regexp。PATH 上无 rg 时启用。大树上慢于 rg
// （无 SIMD / 不读 .gitignore），但 surface 一致：同 args / 同输出 / 同
// head_limit。
//
// 设计取舍：跳过 .git / node_modules / .venv 这类显著噪声目录；不解析
// .gitignore（兜底不该写这么多代码——要 .gitignore 请装 rg）。
// multiline 模式整文件读进内存（受 maxStdlibFileBytes 限）；单行模式按
// Read tool 的 8 MiB 单行上限走 bufio.Scanner。
package search

import (
	"bufio"
	"context"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/bmatcuk/doublestar/v4"
)

// ── Limits & noise filters ────────────────────────────────────────────────────

const (
	// maxStdlibFileBytes caps the bytes read per file in multiline mode.
	// Anything bigger gets skipped to avoid OOM on accidental scans of
	// huge binaries the user forgot to filter out.
	//
	// maxStdlibFileBytes 限制 multiline 模式下单文件读取上限，防止扫到
	// 巨大的二进制文件 OOM。
	maxStdlibFileBytes = 32 * 1024 * 1024 // 32 MiB

	// maxStdlibScannerLine matches Read's per-line cap so the two tools
	// behave consistently on long-line files.
	//
	// maxStdlibScannerLine 与 Read 单行上限保持一致，确保二者对长行文件行为
	// 统一。
	maxStdlibScannerLine = 8 * 1024 * 1024
)

// noiseDirs are skipped during WalkDir so we don't spend time crawling
// node_modules / .git / virtualenvs. (These would also be skipped by rg
// when .gitignore is honoured.)
//
// noiseDirs 在 WalkDir 时直接跳过，避免在 node_modules / .git / venv 里浪费
// 时间。rg 走 .gitignore 时也会跳。
var noiseDirs = map[string]struct{}{
	".git":         {},
	"node_modules": {},
	".venv":        {},
	"venv":         {},
	"__pycache__":  {},
	".forgify":     {},
}

// ── Type → extensions map ─────────────────────────────────────────────────────

// typeExtensions maps the `type` parameter values (matching rg's --type
// vocabulary loosely) to the file extensions they include. The list is
// intentionally small: just the common languages an LLM would ask for.
// Extend as needed; unknown types match nothing (silently zero results).
//
// typeExtensions 把 `type` 参数值（粗略对齐 rg --type 词汇）映射到包含的
// 扩展名。故意保持小列表，按需扩展；未知 type 不报错只是零匹配。
var typeExtensions = map[string][]string{
	"go":     {".go"},
	"py":     {".py"},
	"js":     {".js", ".mjs", ".cjs"},
	"ts":     {".ts"},
	"tsx":    {".tsx"},
	"jsx":    {".jsx"},
	"rust":   {".rs"},
	"rs":     {".rs"},
	"c":      {".c", ".h"},
	"cpp":    {".cpp", ".cxx", ".cc", ".hpp", ".hxx"},
	"java":   {".java"},
	"rb":     {".rb"},
	"php":    {".php"},
	"swift":  {".swift"},
	"kotlin": {".kt", ".kts"},
	"yaml":   {".yml", ".yaml"},
	"yml":    {".yml", ".yaml"},
	"json":   {".json"},
	"xml":    {".xml"},
	"html":   {".html", ".htm"},
	"css":    {".css", ".scss", ".sass"},
	"md":     {".md", ".markdown"},
	"sh":     {".sh", ".bash"},
	"toml":   {".toml"},
	"sql":    {".sql"},
}

// ── Entry point ───────────────────────────────────────────────────────────────

// execStdlib runs the search using stdlib regexp. isDir tells us whether
// the search root is a directory (walk) or a single file (scan once).
//
// execStdlib 用 stdlib regexp 跑搜索；isDir 决定是走目录还是只扫单文件。
func (t *Grep) execStdlib(ctx context.Context, args grepArgs, isDir bool) (string, error) {
	re, err := compileGrepRegex(args)
	if err != nil {
		return fmt.Sprintf("Invalid regex pattern: %v", err), nil
	}

	candidates, err := collectCandidates(args, isDir)
	if err != nil {
		return "", fmt.Errorf("Grep.execStdlib: %w", err)
	}
	sort.Strings(candidates)

	switch args.OutputMode {
	case OutputModeContent:
		return searchContent(ctx, re, candidates, args, isDir), nil
	case OutputModeCount:
		return searchCount(ctx, re, candidates, args), nil
	default:
		return searchFilesWithMatches(ctx, re, candidates, args), nil
	}
}

// compileGrepRegex prepends Go regex inline flags for case-insensitive
// matching `(?i)` and DotAll `(?s)` for multiline mode (so `.` crosses
// `\n`). We do NOT enable `(?m)` because users who want `^/$` per line
// are already getting that semantics from line-oriented scanning;
// multiline mode is for cross-line patterns specifically.
//
// compileGrepRegex 给正则前置内联 flag：`(?i)` 大小写不敏感；multiline 时
// 加 `(?s)`（让 `.` 跨 `\n`）。不开 `(?m)`——按行扫描已经天然给了 `^/$`
// 的语义；multiline 专门服务跨行模式。
func compileGrepRegex(args grepArgs) (*regexp.Regexp, error) {
	var prefix strings.Builder
	if args.IgnoreCase {
		prefix.WriteString("(?i)")
	}
	if args.Multiline {
		prefix.WriteString("(?s)")
	}
	return regexp.Compile(prefix.String() + args.Pattern)
}

// ── Candidate collection ──────────────────────────────────────────────────────

// collectCandidates returns the absolute paths of files we should scan.
// Single-file root: just that file. Directory root: walk + filter by
// glob/type, skipping noiseDirs and unreadable entries.
//
// collectCandidates 返回应扫描的绝对路径文件列表。单文件即只扫该文件；
// 目录则 WalkDir + glob/type 过滤；跳过 noiseDirs 与不可读项。
func collectCandidates(args grepArgs, isDir bool) ([]string, error) {
	if !isDir {
		// Single-file search: type/glob filter still applies — empty result
		// is a legitimate "no files matched filter" outcome.
		// 单文件搜索：type/glob 过滤仍生效——空结果是合法的“无文件匹配过滤”。
		if !fileMatchesFilters(args.Path, args) {
			return nil, nil
		}
		return []string{args.Path}, nil
	}

	var out []string
	walkErr := filepath.WalkDir(args.Path, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			// Unreadable subtree: skip silently. Aborting the whole walk
			// would punish the user for one bad permission bit.
			// 子树不可读：静默跳过；为一个权限位中断整个 walk 是过度反应。
			if d != nil && d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if d.IsDir() {
			if _, skip := noiseDirs[d.Name()]; skip && path != args.Path {
				return filepath.SkipDir
			}
			return nil
		}
		if !d.Type().IsRegular() {
			return nil
		}
		if fileMatchesFilters(path, args) {
			out = append(out, path)
		}
		return nil
	})
	return out, walkErr
}

// fileMatchesFilters returns true when the file passes both the glob and
// the type filter (each only when non-empty).
//
// fileMatchesFilters：文件同时通过 glob 与 type 过滤（仅非空时生效）才返 true。
func fileMatchesFilters(path string, args grepArgs) bool {
	if args.Type != "" {
		exts, known := typeExtensions[args.Type]
		if !known {
			return false
		}
		ext := strings.ToLower(filepath.Ext(path))
		matched := false
		for _, e := range exts {
			if e == ext {
				matched = true
				break
			}
		}
		if !matched {
			return false
		}
	}
	if args.Glob != "" {
		// doublestar matches against the basename for `*.go` and against the
		// path-relative form for `**/*.go`. Try both for friendly behaviour.
		// doublestar 对 `*.go` 匹配 basename；对 `**/*.go` 匹配 relative path。
		// 双试以提供友好行为。
		if ok, _ := doublestar.Match(args.Glob, filepath.Base(path)); ok {
			return true
		}
		rel := path
		if absRoot := args.Path; absRoot != "" {
			if r, err := filepath.Rel(absRoot, path); err == nil {
				rel = filepath.ToSlash(r)
			}
		}
		if ok, _ := doublestar.Match(args.Glob, rel); ok {
			return true
		}
		return false
	}
	return true
}

// ── Search implementations per output mode ────────────────────────────────────

// searchFilesWithMatches scans each candidate and emits one path per file
// that has at least one match. Stops at head_limit files.
//
// searchFilesWithMatches 逐文件扫描；至少一处匹配的文件输出 path。
// 命中 head_limit 个文件即停。
func searchFilesWithMatches(ctx context.Context, re *regexp.Regexp, files []string, args grepArgs) string {
	var sb strings.Builder
	emitted := 0
	for _, p := range files {
		if ctx.Err() != nil {
			break
		}
		hit, _ := fileHasMatch(p, re, args.Multiline)
		if !hit {
			continue
		}
		sb.WriteString(p)
		sb.WriteByte('\n')
		emitted++
		if args.HeadLimit > 0 && emitted >= args.HeadLimit {
			fmt.Fprintf(&sb, "... [truncated at %d files; raise head_limit to see more]\n", args.HeadLimit)
			break
		}
	}
	if emitted == 0 {
		return noMatchesMessage(args)
	}
	return sb.String()
}

// searchCount emits `<path>:<count>` per file with at least one match.
//
// searchCount 给每个有匹配的文件输出 `<path>:<count>`。
func searchCount(ctx context.Context, re *regexp.Regexp, files []string, args grepArgs) string {
	var sb strings.Builder
	emitted := 0
	for _, p := range files {
		if ctx.Err() != nil {
			break
		}
		_, count := fileHasMatch(p, re, args.Multiline)
		if count == 0 {
			continue
		}
		fmt.Fprintf(&sb, "%s:%d\n", p, count)
		emitted++
		if args.HeadLimit > 0 && emitted >= args.HeadLimit {
			fmt.Fprintf(&sb, "... [truncated at %d files; raise head_limit to see more]\n", args.HeadLimit)
			break
		}
	}
	if emitted == 0 {
		return noMatchesMessage(args)
	}
	return sb.String()
}

// searchContent emits matching lines with optional line numbers and
// before/after context. Path prefix is omitted when the search root is a
// single file (matches CC's behaviour).
//
// searchContent 输出匹配行；可选行号 + 前后上下文。单文件 root 时省略 path
// 前缀（与 CC 行为一致）。
func searchContent(ctx context.Context, re *regexp.Regexp, files []string, args grepArgs, isDir bool) string {
	var sb strings.Builder
	emitted := 0
	for _, p := range files {
		if ctx.Err() != nil {
			break
		}
		matches := scanFileContent(p, re, args)
		if len(matches) == 0 {
			continue
		}
		for _, m := range matches {
			writeContentLine(&sb, p, m, args, isDir)
			emitted++
			if args.HeadLimit > 0 && emitted >= args.HeadLimit {
				fmt.Fprintf(&sb, "... [truncated at %d matches; raise head_limit to see more]\n", args.HeadLimit)
				return sb.String()
			}
		}
	}
	if emitted == 0 {
		return noMatchesMessage(args)
	}
	return sb.String()
}

// ── File scan helpers ─────────────────────────────────────────────────────────

// fileHasMatch reports whether the file contains any match (and how many,
// for count mode). Returns (false, 0) on read errors so a single bad file
// doesn't taint the whole search.
//
// fileHasMatch 报告文件是否含匹配（及匹配数，用于 count 模式）。读失败返
// (false, 0)，避免单个坏文件污染整次搜索。
func fileHasMatch(path string, re *regexp.Regexp, multiline bool) (bool, int) {
	if multiline {
		data, err := readFileBounded(path, maxStdlibFileBytes)
		if err != nil {
			return false, 0
		}
		all := re.FindAllIndex(data, -1)
		return len(all) > 0, len(all)
	}
	f, err := os.Open(path) //nolint:gosec // path comes from filepath.WalkDir under the validated root.
	if err != nil {
		return false, 0
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), maxStdlibScannerLine)
	count := 0
	for scanner.Scan() {
		count += len(re.FindAllIndex(scanner.Bytes(), -1))
	}
	return count > 0, count
}

// matchedLine records one match plus the surrounding context lines so
// content mode can render -A/-B output. lineNum is 1-based.
//
// matchedLine 记录一处匹配及上下文行，供 content 模式渲染 -A/-B。
// lineNum 1-based。
type matchedLine struct {
	lineNum int
	text    string
	context bool // true = context line (rendered with `-` separator), false = match line (`:`)
}

// scanFileContent returns matchedLine entries for content mode, honouring
// -A/-B context. For multiline scans we read whole-file and emit one
// match per regex hit, then back-fill context using line-index lookups.
//
// scanFileContent 返回 content 模式的 matchedLine（含 -A/-B 上下文）。
// multiline 走整文件读取，每次 regex 命中算一个 match，按行号回填上下文。
func scanFileContent(path string, re *regexp.Regexp, args grepArgs) []matchedLine {
	if args.Multiline {
		return scanFileContentMultiline(path, re, args)
	}
	return scanFileContentLineMode(path, re, args)
}

func scanFileContentLineMode(path string, re *regexp.Regexp, args grepArgs) []matchedLine {
	f, err := os.Open(path) //nolint:gosec // path is under the validated walk root.
	if err != nil {
		return nil
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), maxStdlibScannerLine)

	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return nil
	}

	// Pre-compute which lines match. Before/after-context loops skip these
	// so a match line is never relabeled as context when it falls inside
	// another match's context window. Mirrors scanFileContentMultiline.
	//
	// 预算哪些行是 match。before/after 上下文循环跳过它们，确保 match 行
	// 落在另一处 match 的上下文窗口内时不会被错标为 context。与 scanFileContentMultiline 一致。
	matchLines := make(map[int]bool)
	for i, ln := range lines {
		if re.MatchString(ln) {
			matchLines[i] = true
		}
	}

	emitted := make(map[int]bool)
	var out []matchedLine
	for i := range lines {
		if !matchLines[i] {
			continue
		}
		// Before context — skip lines that are themselves matches.
		// 前置上下文——跳过本身就是 match 的行。
		for off := args.Before; off > 0; off-- {
			j := i - off
			if j < 0 || emitted[j] || matchLines[j] {
				continue
			}
			out = append(out, matchedLine{lineNum: j + 1, text: lines[j], context: true})
			emitted[j] = true
		}
		// The match itself.
		// 匹配本身。
		if !emitted[i] {
			out = append(out, matchedLine{lineNum: i + 1, text: lines[i], context: false})
			emitted[i] = true
		}
		// After context — skip lines that are themselves matches.
		// 后置上下文——跳过本身就是 match 的行。
		for off := 1; off <= args.After; off++ {
			j := i + off
			if j >= len(lines) || emitted[j] || matchLines[j] {
				continue
			}
			out = append(out, matchedLine{lineNum: j + 1, text: lines[j], context: true})
			emitted[j] = true
		}
	}
	// Re-sort by line number so output is monotonic when multiple matches
	// interleave context.
	// 按行号重排，保证多匹配交错时输出单调。
	sort.Slice(out, func(i, j int) bool { return out[i].lineNum < out[j].lineNum })
	return out
}

func scanFileContentMultiline(path string, re *regexp.Regexp, args grepArgs) []matchedLine {
	data, err := readFileBounded(path, maxStdlibFileBytes)
	if err != nil {
		return nil
	}
	lines := strings.Split(string(data), "\n")
	hits := re.FindAllIndex(data, -1)
	if len(hits) == 0 {
		return nil
	}

	matchLines := make(map[int]bool)
	for _, h := range hits {
		// Span every line the match touches (multiline patterns can cover
		// several). Convert byte offset → 1-based line number.
		// 覆盖 match 跨越的每一行（multiline 可能跨多行）。byte offset → 1-based
		// 行号。
		startLine := byteOffsetToLine(data, h[0])
		endLine := byteOffsetToLine(data, h[1]-1)
		for ln := startLine; ln <= endLine; ln++ {
			matchLines[ln] = true
		}
	}

	emitted := make(map[int]bool)
	var out []matchedLine
	maxLine := len(lines)
	for ln := 1; ln <= maxLine; ln++ {
		if !matchLines[ln] {
			continue
		}
		for off := args.Before; off > 0; off-- {
			j := ln - off
			if j < 1 || emitted[j] {
				continue
			}
			if matchLines[j] {
				continue
			}
			out = append(out, matchedLine{lineNum: j, text: lines[j-1], context: true})
			emitted[j] = true
		}
		if !emitted[ln] {
			out = append(out, matchedLine{lineNum: ln, text: lines[ln-1], context: false})
			emitted[ln] = true
		}
		for off := 1; off <= args.After; off++ {
			j := ln + off
			if j > maxLine || emitted[j] {
				continue
			}
			if matchLines[j] {
				continue
			}
			out = append(out, matchedLine{lineNum: j, text: lines[j-1], context: true})
			emitted[j] = true
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].lineNum < out[j].lineNum })
	return out
}

// writeContentLine renders one matchedLine into the output buffer.
// Format mirrors rg --no-heading: `<path>:<lineno>:<text>` for matches,
// `<path>-<lineno>-<text>` for context lines. Path is omitted on
// single-file searches.
//
// writeContentLine 把一条 matchedLine 写进输出。格式镜像 rg --no-heading：
// 匹配行 `:`，上下文行 `-`；单文件搜索省 path。
func writeContentLine(sb *strings.Builder, path string, m matchedLine, args grepArgs, isDir bool) {
	sep := byte(':')
	if m.context {
		sep = '-'
	}
	if isDir {
		sb.WriteString(path)
		sb.WriteByte(sep)
	}
	if args.ShowLines {
		fmt.Fprintf(sb, "%d", m.lineNum)
		sb.WriteByte(sep)
	}
	sb.WriteString(m.text)
	sb.WriteByte('\n')
}

// readFileBounded reads up to limit bytes from path. Returns an error if
// the file is larger than limit so callers can skip it.
//
// readFileBounded 从 path 读至多 limit 字节。文件超限即返错，让调用方跳过。
func readFileBounded(path string, limit int64) ([]byte, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if info.Size() > limit {
		return nil, fmt.Errorf("file exceeds %d-byte multiline scan cap", limit)
	}
	return os.ReadFile(path) //nolint:gosec // path is under validated walk root.
}

// byteOffsetToLine returns the 1-based line number containing byte offset
// b in data. O(b); fine for the small per-file budgets we accept.
//
// byteOffsetToLine 返回 data 中 byte 偏移 b 所在的 1-based 行号。
func byteOffsetToLine(data []byte, b int) int {
	if b < 0 {
		b = 0
	}
	if b > len(data) {
		b = len(data)
	}
	line := 1
	for i := 0; i < b; i++ {
		if data[i] == '\n' {
			line++
		}
	}
	return line
}
