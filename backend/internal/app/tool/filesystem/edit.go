// edit.go — Edit system tool: performs exact-string replacement in an
// existing file. Replaces a single unique occurrence by default; pass
// replace_all=true to replace every match.
//
// Decision D1 (see 02-tools-deep/01-file-ops.md): we trust Go's
// strings.Replace / strings.ReplaceAll (well-defined: replace all
// non-overlapping occurrences) and do NOT replicate Claude Code's #51986
// defensive count-after check. To gain the transparency #51986 needed,
// the success message explicitly reports N replacements (CC just says
// "All replaced").
//
// edit.go — Edit 系统工具：在已存在文件里做精确字符串替换。默认替换单一
// 唯一出现；replace_all=true 替全部。
//
// 决策 D1（见 02-tools-deep/01-file-ops.md）：信任 Go 的
// strings.Replace / strings.ReplaceAll（语义明确：替换所有非重叠出现），
// 不复刻 Claude Code 的 #51986 防御性 count-after 校验。为获得 #51986 想要
// 的透明度，成功消息显式报告 N 次替换（CC 只说 "All replaced"）。
package filesystem

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	pathguardpkg "github.com/sunweilin/forgify/backend/internal/pkg/pathguard"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// ── Validation sentinels ──────────────────────────────────────────────────────

// (`ErrEmptyFilePath` / `ErrPathNotAbsolute` are reused from read.go —
// same package.)
//
// （`ErrEmptyFilePath` / `ErrPathNotAbsolute` 复用 read.go 定义——同包共享。）
var (
	// ErrEmptyOldString: old_string missing or empty. Empty old_string would
	// match infinite zero-length boundaries; reject early.
	// ErrEmptyOldString：old_string 缺失或为空。空 old_string 会匹配无限多
	// 个零宽边界；提前拒绝。
	ErrEmptyOldString = errors.New("old_string is required and must be non-empty")

	// ErrEditNoOp: old_string == new_string would be a no-op edit; reject
	// so the LLM doesn't waste a tool call.
	// ErrEditNoOp：old_string == new_string 是空操作；拒绝以免 LLM 浪费一次
	// tool 调用。
	ErrEditNoOp = errors.New("old_string and new_string must be different")
)

// ── Description & schema (LLM-facing) ─────────────────────────────────────────

// editDescription is the text shown to the LLM. Forgify-tailored: explicit
// about must-Read-first, the literal-substring matching algorithm, the
// uniqueness rule, and the explicit replacement count we report on success.
//
// editDescription 是给 LLM 的描述文本。Forgify 定制：明示 must-Read-first、
// 字面量匹配、唯一性规则、成功时显式报告替换次数。
const editDescription = `Performs exact string replacement in an existing file.

Usage:
- The file_path parameter must be an absolute path, not a relative path
- You must have read the file with the Read tool in this conversation before attempting to edit it
- Matching is exact literal string (NOT regex). Whitespace, indentation, and case all matter
- old_string must match the file contents exactly. Include enough surrounding context to make the match unique
- The operation FAILS if old_string is not unique (appears more than once), unless replace_all: true
- The operation FAILS if old_string is not found at all
- old_string and new_string must differ (no-op edits are rejected)
- The file is written atomically (staged tmp + rename); readers never see a half-written file
- On success, the result message reports the actual number of replacements performed
- When editing text from Read tool output, preserve exact indentation as it appears AFTER the line number prefix; never include the line-number prefix itself in old_string or new_string
- Use replace_all: true to rename a string everywhere in the file (e.g. variable rename); only do this when you have verified all occurrences are intended replacements
- Some sensitive paths (system directories, credential locations like ~/.ssh, ~/.aws) are blocked for safety`

// editSchema is the LLM-facing JSON Schema (without the framework-injected
// summary / destructive / execution_group fields).
//
// editSchema 是给 LLM 的 JSON Schema（不含 framework 注入的 summary /
// destructive / execution_group 字段）。
var editSchema = json.RawMessage(`{
	"type": "object",
	"required": ["file_path", "old_string", "new_string"],
	"properties": {
		"file_path": {
			"type": "string",
			"description": "The absolute path to the file to edit (must be absolute)"
		},
		"old_string": {
			"type": "string",
			"description": "The text to replace. Must be non-empty and present in the file. Include enough surrounding context to make the match unique unless replace_all is true."
		},
		"new_string": {
			"type": "string",
			"description": "The text to replace it with. Must differ from old_string."
		},
		"replace_all": {
			"type": "boolean",
			"default": false,
			"description": "If true, replace every occurrence of old_string in the file (e.g. variable rename). If false (default), the call fails when old_string is not unique."
		}
	}
}`)

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// Edit implements the Edit system tool.
//
// Edit struct 是 Edit 系统工具。pathGuard 是路径黑名单守卫；AgentState
// 通过 ctx 注入（保持 Tool stateless）。
type Edit struct {
	pathGuard pathguardpkg.PathGuard
}

// Identity --------------------------------------------------------------------

func (t *Edit) Name() string                { return "Edit" }
func (t *Edit) Description() string         { return editDescription }
func (t *Edit) Parameters() json.RawMessage { return editSchema }

// Static metadata -------------------------------------------------------------

func (t *Edit) IsReadOnly() bool        { return false }
func (t *Edit) NeedsReadFirst() bool    { return true } // metadata; actual enforcement in Execute
func (t *Edit) RequiresWorkspace() bool { return true }

// Args-dependent hooks --------------------------------------------------------

// ValidateInput checks structural correctness of the four parameters.
// Empty old_string and old_string == new_string are rejected pre-Execute.
//
// ValidateInput 校验四个参数的结构正确性。空 old_string 和
// old_string == new_string 在 Execute 前拒绝。
func (t *Edit) ValidateInput(args json.RawMessage) error {
	var a struct {
		FilePath  string  `json:"file_path"`
		OldString *string `json:"old_string"`
		NewString *string `json:"new_string"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("Edit.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.FilePath) == "" {
		return ErrEmptyFilePath
	}
	if !filepath.IsAbs(a.FilePath) {
		return ErrPathNotAbsolute
	}
	if a.OldString == nil || *a.OldString == "" {
		return ErrEmptyOldString
	}
	if a.NewString == nil {
		return errors.New("new_string field is required (use empty string to delete the matched text)")
	}
	if *a.OldString == *a.NewString {
		return ErrEditNoOp
	}
	return nil
}

// CheckPermissions always allows. Safety enforced via PathGuard +
// must-Read-first guard inside Execute.
//
// CheckPermissions 始终允许。安全靠 Execute 内的 PathGuard + must-Read-first
// 守卫。
func (t *Edit) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

// Execute applies the literal-substring replacement and writes the result
// atomically.
//
// Guards (in order):
//  1. PathGuard deny-list
//  2. File must exist (Edit cannot create files)
//  3. File must have been Read in this conversation (cross-tool
//     AgentState.SeenFiles)
//  4. File size must match the size at last Read (external-modification
//     detection; size-only is good enough for accidental clobbers, hash
//     check would be heavier and not worth it for v1)
//
// Replacement semantics:
//   - count == 0: "string not found" message
//   - count == 1: replace it (regardless of replace_all)
//   - count > 1, replace_all=false: "found N matches" message
//   - count > 1, replace_all=true: replace all
//
// On success, the message explicitly reports the replacement count
// (transparency over Claude Code's "All replaced" — see decision D1).
//
// Filesystem failures (permission denied, disk full) are returned as
// LLM-facing strings, not Go errors.
//
// Execute 做字面量字符串替换并原子写入。
//
// 守卫顺序：(1) PathGuard 黑名单；(2) 文件必须存在（Edit 不创建文件）；
// (3) 必须本对话内 Read 过；(4) 文件 size 必须匹配上次 Read 时的 size
// （外部修改检测；仅 size 对意外覆盖足够，hash 校验更重且 v1 不必要）。
//
// 替换语义：count==0 报"未找到"；==1 直接替；>1 + replace_all=false 报
// "找到 N 个匹配"；>1 + replace_all=true 全替。
//
// 成功消息显式报告替换次数（比 CC 的 "All replaced" 透明，见决策 D1）。
//
// 文件系统失败（权限不足、磁盘满）作为 LLM 友好字符串返回，非 Go error。
func (t *Edit) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		FilePath   string `json:"file_path"`
		OldString  string `json:"old_string"`
		NewString  string `json:"new_string"`
		ReplaceAll bool   `json:"replace_all"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("Edit.Execute: %w", err)
	}

	// Guard 1: PathGuard.
	if ok, reason := t.pathGuard.Allow(args.FilePath); !ok {
		return reason, nil
	}

	cleaned := filepath.Clean(args.FilePath)

	// Guard 2: file must exist.
	info, err := os.Stat(cleaned)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return "File not found: " + cleaned + ". Edit can only modify existing files; use Write to create new ones.", nil
		}
		return fmt.Sprintf("Cannot access %s: %v", cleaned, err), nil
	}
	if info.IsDir() {
		return "Path is a directory, not a file: " + cleaned, nil
	}

	// Guard 3: must-Read-first.
	state, hasState := reqctxpkg.GetAgentState(ctx)
	if !hasState {
		return "Cannot verify Read-first guard: agent state missing. Read the file first.", nil
	}
	seenSize, seen := state.WasRead(cleaned)
	if !seen {
		return "File must be read first before editing: " + cleaned + ". Use the Read tool first.", nil
	}

	// Guard 4: external-modification check (size mismatch).
	// Note: size-only is best-effort. Same-size content swaps are not detected;
	// hash-based detection is overkill for accidental clobbers (v1 trade-off).
	//
	// 守卫 4：外部修改检测（size 失配）。仅 size 是 best-effort——同 size
	// 的内容互换检测不到；hash-based 对意外覆盖过重（v1 取舍）。
	if info.Size() != seenSize {
		return fmt.Sprintf(
			"File has been modified since last read (current size %d, expected %d): %s. Read it again before editing.",
			info.Size(), seenSize, cleaned,
		), nil
	}

	// Read current content.
	raw, err := os.ReadFile(cleaned)
	if err != nil {
		return fmt.Sprintf("Cannot read %s: %v", cleaned, err), nil
	}
	content := string(raw)

	// Match counting.
	occurrences := strings.Count(content, args.OldString)
	switch {
	case occurrences == 0:
		return "old_string not found in the file. Verify the exact text (whitespace and case matter).", nil
	case occurrences > 1 && !args.ReplaceAll:
		return fmt.Sprintf(
			"Found %d matches of old_string in %s, but replace_all is false. Either provide more surrounding context to make old_string unique, or set replace_all: true.",
			occurrences, cleaned,
		), nil
	}

	// Apply replacement. We trust stdlib (decision D1).
	// 应用替换，信任 stdlib（决策 D1）。
	var newContent string
	var replaced int
	if args.ReplaceAll {
		newContent = strings.ReplaceAll(content, args.OldString, args.NewString)
		replaced = occurrences
	} else {
		// occurrences == 1 here.
		newContent = strings.Replace(content, args.OldString, args.NewString, 1)
		replaced = 1
	}

	// Atomic write: tmp + rename, preserve original mode.
	parent := filepath.Dir(cleaned)
	tmpFile, err := os.CreateTemp(parent, ".forgify-edit-*")
	if err != nil {
		return fmt.Sprintf("Edit failed (cannot create temp): %v", err), nil
	}
	tmpPath := tmpFile.Name()
	cleanup := func() { _ = os.Remove(tmpPath) }

	if _, err := tmpFile.WriteString(newContent); err != nil {
		_ = tmpFile.Close()
		cleanup()
		return fmt.Sprintf("Edit failed (writing temp): %v", err), nil
	}
	if err := tmpFile.Close(); err != nil {
		cleanup()
		return fmt.Sprintf("Edit failed (closing temp): %v", err), nil
	}
	if err := os.Chmod(tmpPath, info.Mode().Perm()); err != nil {
		cleanup()
		return fmt.Sprintf("Edit failed (chmod temp): %v", err), nil
	}
	if err := os.Rename(tmpPath, cleaned); err != nil {
		cleanup()
		return fmt.Sprintf("Edit failed (rename to target): %v", err), nil
	}

	// Update SeenFiles with the new size so chained Edit/Write of this path
	// pass their guards.
	//
	// 更新 SeenFiles 为新 size，让链式的 Edit/Write 对此 path 通过守卫。
	state.MarkRead(cleaned, int64(len(newContent)))

	if replaced == 1 {
		return fmt.Sprintf("Successfully replaced 1 occurrence in %s.", cleaned), nil
	}
	return fmt.Sprintf("Successfully replaced %d occurrences in %s.", replaced, cleaned), nil
}

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*Edit)(nil)
