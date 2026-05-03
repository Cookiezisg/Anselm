// Package pathguard provides a thin deny-list path safety layer for tools
// that touch the filesystem (Read / Write / Edit / Bash etc.). It is the
// lightweight alternative to OS-level sandboxing — see decision D5 in
// `02-tools-deep/03-shell.md`.
//
// The default deny list covers paths that macOS TCC does not protect (e.g.,
// ~/.ssh, ~/.aws) plus system-critical paths and Forgify's own data dir.
// macOS TCC handles the rest (Documents / Desktop / Downloads etc.); on
// Linux / Windows users get only the deny-list protection.
//
// Package pathguard 为操作文件系统的 tool（Read / Write / Edit / Bash 等）
// 提供薄薄一层路径黑名单守卫——见 02-tools-deep/03-shell.md 的决策 D5，
// 是 OS-level sandbox 的轻量替代。
//
// 默认黑名单覆盖 macOS TCC 不保护的路径（如 ~/.ssh、~/.aws）+ 系统关键路径
// + Forgify 自家数据目录。macOS TCC 处理其余（Documents / Desktop / Downloads
// 等）；Linux / Windows 用户只有黑名单这一层保护。
package pathguard

import (
	"os"
	"path/filepath"
	"strings"
)

// PathGuard decides whether a tool may operate on the given absolute path.
// reason is the human-readable explanation used in tool_result error
// messages when allowed is false.
//
// PathGuard 决定 tool 是否可以操作给定的绝对路径。
// allowed 为 false 时 reason 是 tool_result 错误消息里的人话解释。
type PathGuard interface {
	Allow(absPath string) (allowed bool, reason string)
}

// DefaultDenyList lists paths that should always be denied. A trailing "/"
// means directory (prefix match: the directory itself and anything under it
// are denied); no trailing "/" means exact file match. "~/" is expanded to
// the current user's home directory at New time.
//
// Curated for Unix (Linux + macOS). On Windows these paths simply won't
// match any real path, which is harmless — Windows users get only "~/"-
// rooted protection.
//
// DefaultDenyList 列出始终拒绝的路径。结尾 "/" = 目录前缀匹配（目录本身及
// 其下任何路径都拒）；无结尾 "/" = 精确文件匹配。"~/" 在 New 时展开为当前
// 用户家目录。
//
// 仅针对 Unix（Linux + macOS）维护。Windows 上这些路径不会匹配任何真实路径，
// 无害——Windows 用户只享受 "~/" 路径的保护。
var DefaultDenyList = []string{
	// ── System-critical paths ─────────────────────────────────────────────
	"/etc/", "/usr/", "/sys/", "/private/etc/", "/private/var/",
	"/System/", "/Library/Keychains/", "/bin/", "/sbin/",

	// ── User credentials (TCC blind spots) ────────────────────────────────
	"~/.ssh/", "~/.aws/", "~/.gnupg/", "~/.netrc", "~/.config/git-credentials",

	// ── Forgify's own state (avoid LLM corrupting our DB / keys) ──────────
	"~/.forgify/",
}

// rule is a parsed entry from a deny list.
//
// rule 是一条解析后的黑名单条目。
type rule struct {
	path  string // cleaned absolute path (no trailing separator)
	isDir bool   // true = match path itself or anything below it; false = exact-file match
}

// defaultGuard is the in-memory deny-list implementation.
//
// defaultGuard 是基于内存黑名单的实现。
type defaultGuard struct {
	rules []rule
}

// New returns a PathGuard that denies any path matching one of the supplied
// rules. Rules ending in "/" are treated as directory prefixes; "~/" is
// expanded against the current user's home directory. Entries that fail to
// expand (no home dir, or path turns out non-absolute after expansion) are
// silently dropped — fail-open is acceptable for a defense-in-depth layer.
//
// New 返回一个拒绝所有匹配规则的 PathGuard。结尾 "/" 视为目录前缀；"~/"
// 按当前用户家目录展开。展开失败的条目（无家目录，或展开后非绝对路径）
// 静默丢弃——defense-in-depth 层 fail-open 可接受。
func New(denyList []string) PathGuard {
	home, _ := os.UserHomeDir()
	rules := make([]rule, 0, len(denyList))
	for _, raw := range denyList {
		isDir := strings.HasSuffix(raw, string(filepath.Separator)) || strings.HasSuffix(raw, "/")
		expanded := raw
		if strings.HasPrefix(expanded, "~/") {
			if home == "" {
				continue
			}
			expanded = filepath.Join(home, expanded[2:])
		}
		if !filepath.IsAbs(expanded) {
			continue
		}
		rules = append(rules, rule{
			path:  filepath.Clean(expanded),
			isDir: isDir,
		})
	}
	return &defaultGuard{rules: rules}
}

// NewDefault returns a PathGuard configured with DefaultDenyList.
//
// NewDefault 返回一个用 DefaultDenyList 配置的 PathGuard。
func NewDefault() PathGuard {
	return New(DefaultDenyList)
}

// Allow checks absPath against the deny rules. Non-absolute paths are
// rejected outright — every tool that calls Allow should already pass an
// absolute path; if a relative one slips through it's a bug worth catching.
//
// Allow 按黑名单规则检查 absPath。非绝对路径直接拒——调用 Allow 的 tool
// 应保证传绝对路径，万一漏了相对路径属于值得捕获的 bug。
func (g *defaultGuard) Allow(absPath string) (bool, string) {
	if !filepath.IsAbs(absPath) {
		return false, "path must be absolute: " + absPath
	}
	cleaned := filepath.Clean(absPath)
	for _, r := range g.rules {
		if r.isDir {
			// Directory rule: match the directory itself or anything below it.
			// 目录规则：匹配目录本身或其下任意路径。
			if cleaned == r.path || strings.HasPrefix(cleaned, r.path+string(filepath.Separator)) {
				return false, "path is denied by safety guard: " + r.path
			}
		} else {
			// File rule: exact match only.
			// 文件规则：仅精确匹配。
			if cleaned == r.path {
				return false, "path is denied by safety guard: " + r.path
			}
		}
	}
	return true, ""
}
