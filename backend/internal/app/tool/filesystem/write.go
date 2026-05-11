// write.go — Write system tool: creates a new file or overwrites an
// existing one with the supplied content. Overwrites are gated by the
// must-Read-first guard (cross-tool AgentState.SeenFiles); fresh creation
// is unrestricted.
//
// Atomic write: stage to a tmp sibling, rename in place. Readers never see
// a half-written file; partial-write or panic mid-flight leaves the
// original (or absence) intact.
//
// write.go — Write 系统工具：新建或覆写文件。覆写经 must-Read-first 守卫
// （跨 tool 的 AgentState.SeenFiles）；新建无限制。
//
// 原子写：写到同目录的 tmp，rename 替换。读者永远看不到半成品；写入中途
// panic 也只留下原文件（或文件不存在）原状。
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

// ── Defaults ──────────────────────────────────────────────────────────────────

const (
	// defaultFileMode is applied to newly-created files. Existing files'
	// modes are preserved on overwrite (chmod after CreateTemp; see Execute).
	//
	// defaultFileMode 用于新建文件。覆写时保留原文件 mode（CreateTemp 后
	// chmod；见 Execute）。
	defaultFileMode os.FileMode = 0o644
)

// ── Validation sentinels ──────────────────────────────────────────────────────

// (`ErrEmptyFilePath` / `ErrPathNotAbsolute` are reused from read.go since
// the package owns both files.)
//
// （`ErrEmptyFilePath` / `ErrPathNotAbsolute` 复用 read.go 定义——同包共享。）

// ── Description & schema (LLM-facing) ─────────────────────────────────────────

// writeDescription is the text shown to the LLM. We use Piebald's
// Read-First mandatory variant (ccVersion 2.1.120) — Forgify enforces the
// must-Read-first rule, so the LLM should be told upfront.
//
// writeDescription 是给 LLM 的描述文本。采用 Piebald Read-First 强制变体
// （ccVersion 2.1.120）——Forgify 强制 must-Read-first 规则，要让 LLM 提前知道。
const writeDescription = `Writes a file to the local filesystem. Overwrites if the file exists.

Usage:
- file_path must be an absolute path.
- Existing files require a prior Read in this conversation (must-Read-first guard prevents accidental clobbering).
- Prefer Edit for modifying existing files — Edit sends only the diff.
- Parent directory must exist; use Bash 'mkdir -p' first if needed.
- Writes are atomic (tmp file + rename); readers never see a half-written file.
- Sensitive paths (system directories, credential locations) are blocked.`

// writeSchema is the LLM-facing JSON Schema (without the framework-injected
// summary / destructive / execution_group fields).
//
// writeSchema 是给 LLM 的 JSON Schema（不含 framework 注入的 summary /
// destructive / execution_group 字段）。
var writeSchema = json.RawMessage(`{
	"type": "object",
	"required": ["file_path", "content"],
	"properties": {
		"file_path": {
			"type": "string",
			"description": "The absolute path to the file to write (must be absolute)"
		},
		"content": {
			"type": "string",
			"description": "The content to write to the file (may be empty to create an empty file)"
		}
	}
}`)

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// Write implements the Write system tool.
//
// Write struct 是 Write 系统工具。pathGuard 是路径黑名单守卫；AgentState
// 通过 ctx 注入（保持 Tool stateless）。
type Write struct {
	pathGuard pathguardpkg.PathGuard
}

// Identity --------------------------------------------------------------------

func (t *Write) Name() string                { return "Write" }
func (t *Write) Description() string         { return writeDescription }
func (t *Write) Parameters() json.RawMessage { return writeSchema }

// Static metadata -------------------------------------------------------------

func (t *Write) IsReadOnly() bool        { return false }
func (t *Write) NeedsReadFirst() bool    { return true } // metadata; actual enforcement in Execute
func (t *Write) RequiresWorkspace() bool { return true }

// Args-dependent hooks --------------------------------------------------------

// ValidateInput checks structural correctness of file_path before Execute.
// content is allowed to be empty (creating empty files is a legitimate use).
//
// ValidateInput 在 Execute 前校验 file_path 的结构正确性。content 允许空
// （创建空文件是合法用法）。
func (t *Write) ValidateInput(args json.RawMessage) error {
	var a struct {
		FilePath string `json:"file_path"`
		// Content's presence is checked structurally (key must exist) but
		// emptiness is fine. Use json.RawMessage to detect missing key.
		Content *string `json:"content"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("Write.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.FilePath) == "" {
		return ErrEmptyFilePath
	}
	if !filepath.IsAbs(a.FilePath) {
		return ErrPathNotAbsolute
	}
	if a.Content == nil {
		return errors.New("content field is required (use empty string to create an empty file)")
	}
	return nil
}

// CheckPermissions always allows. Write's safety is enforced via PathGuard +
// must-Read-first guard inside Execute.
//
// CheckPermissions 始终允许。Write 安全靠 Execute 内的 PathGuard + must-Read-first 守卫。
func (t *Write) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

// Execute writes content to file_path atomically (tmp + rename).
//
// Guards (in order):
//  1. PathGuard deny-list
//  2. Parent directory must exist (we do NOT mkdir)
//  3. If target exists, it must have been Read in this conversation
//     (cross-tool AgentState.SeenFiles)
//
// On success, marks the new path as Read so subsequent Edit/Write of the
// same path passes their guards.
//
// Filesystem failures (permission denied, disk full) are returned as
// LLM-facing strings, not Go errors — the LLM can recover.
//
// Execute 原子写 content 到 file_path（tmp + rename）。
//
// 守卫顺序：(1) PathGuard 黑名单；(2) 父目录必须存在（不主动 mkdir）；
// (3) 目标文件存在时必须本对话内 Read 过（跨 tool AgentState.SeenFiles）。
//
// 成功后把新 path 标为 Read，让后续对同 path 的 Edit/Write 通过守卫。
//
// 文件系统失败（权限不足、磁盘满）作为 LLM 友好字符串返回，非 Go error——
// LLM 可恢复。
func (t *Write) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		FilePath string `json:"file_path"`
		Content  string `json:"content"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("Write.Execute: %w", err)
	}

	// Guard 1: PathGuard.
	if ok, reason := t.pathGuard.Allow(args.FilePath); !ok {
		return reason, nil
	}

	cleaned := filepath.Clean(args.FilePath)
	parent := filepath.Dir(cleaned)

	// Guard 2: parent directory must exist.
	parentInfo, err := os.Stat(parent)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return "Parent directory does not exist: " + parent + ". Use Bash 'mkdir -p' to create it first.", nil
		}
		return fmt.Sprintf("Cannot access parent directory %s: %v", parent, err), nil
	}
	if !parentInfo.IsDir() {
		return "Parent path exists but is not a directory: " + parent, nil
	}

	// Guard 3: must-Read-first for existing files.
	existingInfo, statErr := os.Stat(cleaned)
	exists := statErr == nil
	if exists && existingInfo.IsDir() {
		return "Path is a directory, not a file: " + cleaned, nil
	}
	if exists {
		state, hasState := reqctxpkg.GetAgentState(ctx)
		if !hasState {
			// Defensive: server-side wiring bug. Refuse the overwrite to
			// match the must-Read-first invariant rather than silently
			// allowing it (which would defeat the whole guard).
			//
			// 防御：服务端接线 bug。拒绝覆写以匹配 must-Read-first 不变量
			// （静默放过会让整个守卫形同虚设）。
			return "Cannot verify Read-first guard: agent state missing. Read the file first.", nil
		}
		if _, seen := state.WasRead(cleaned); !seen {
			return "File must be read first before overwriting: " + cleaned + ". Use the Read tool first.", nil
		}
	}

	// Atomic write: tmp in same dir + rename.
	// 原子写：同目录 tmp + rename。
	tmpFile, err := os.CreateTemp(parent, ".forgify-write-*")
	if err != nil {
		return fmt.Sprintf("Cannot create temp file in %s: %v", parent, err), nil
	}
	tmpPath := tmpFile.Name()
	cleanup := func() {
		// Best-effort cleanup; non-fatal if it fails (file just lingers).
		// 尽力清理；失败不致命（文件残留）。
		_ = os.Remove(tmpPath)
	}

	if _, err := tmpFile.WriteString(args.Content); err != nil {
		_ = tmpFile.Close()
		cleanup()
		return fmt.Sprintf("Write failed (writing temp): %v", err), nil
	}
	if err := tmpFile.Close(); err != nil {
		cleanup()
		return fmt.Sprintf("Write failed (closing temp): %v", err), nil
	}

	// Match existing file's mode on overwrite; otherwise use defaultFileMode.
	// CreateTemp defaults to 0600 which would silently shrink permissions
	// on overwrite — explicit chmod prevents that surprise.
	//
	// 覆写时匹配原文件 mode；新建用 defaultFileMode。CreateTemp 默认 0600
	// 会在覆写时静默收紧权限——显式 chmod 防意外。
	mode := defaultFileMode
	if exists {
		mode = existingInfo.Mode().Perm()
	}
	if err := os.Chmod(tmpPath, mode); err != nil {
		cleanup()
		return fmt.Sprintf("Write failed (chmod temp): %v", err), nil
	}

	if err := os.Rename(tmpPath, cleaned); err != nil {
		cleanup()
		return fmt.Sprintf("Write failed (rename to target): %v", err), nil
	}

	// Mark the freshly-written file as Read so subsequent Edit/Write of the
	// same path passes their must-Read-first guards. Record the new size.
	//
	// 把刚写的文件标为 Read，让后续对同 path 的 Edit/Write 通过 must-Read-first
	// 守卫。记录新 size。
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		state.MarkRead(cleaned, int64(len(args.Content)))
	}

	return "Wrote " + cleaned, nil
}

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*Write)(nil)
