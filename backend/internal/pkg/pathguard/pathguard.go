// Package pathguard provides a thin deny-list path safety layer for tools
// that touch the filesystem (Read / Write / Edit / Glob / Grep). It is the
// lightweight alternative to OS-level sandboxing — see decision D5 in
// `02-tools-deep/03-shell.md`.
//
// The default deny list covers (a) paths that macOS TCC does not protect
// (e.g. ~/.ssh, ~/.aws), (b) cross-platform credential / secret locations
// (browser logins, DPAPI, k8s service-account tokens), (c) system-critical
// paths on macOS / Linux / Windows, and (d) Forgify's own data dir. macOS
// TCC handles the user-document blanket (Documents / Desktop / Downloads
// etc.); Linux + Windows users rely on this deny list as the primary
// guardrail. Rules whose paths don't apply to the running OS get silently
// dropped at New() time (non-absolute paths are filtered out).
//
// **Limitation — Bash is not gated by PathGuard**. The Bash / BashOutput /
// KillShell tools intentionally declare RequiresWorkspace=false and do NOT
// consult PathGuard. Forgify is a single-user local app; Bash is the proxy
// for "commands the user would have typed in their terminal anyway", so a
// banned-list there has no protective value. This is a deliberate trade-off:
// `Read ~/.ssh/id_rsa` is denied by PathGuard, but `bash cat ~/.ssh/id_rsa`
// will succeed. Treat PathGuard as a guard against accidental LLM blunders
// in file-tools, not as a security boundary against the LLM running shell.
//
// Package pathguard 为操作文件系统的 tool（Read / Write / Edit / Glob /
// Grep）提供薄薄一层路径黑名单守卫——见 02-tools-deep/03-shell.md 的决策
// D5，是 OS-level sandbox 的轻量替代。
//
// 默认黑名单覆盖 (a) macOS TCC 不保护的路径（如 ~/.ssh、~/.aws）；
// (b) 跨平台凭据 / 密钥位置（浏览器登录、DPAPI、k8s service-account token）；
// (c) macOS / Linux / Windows 三平台的系统关键路径；(d) Forgify 自家数据
// 目录。macOS TCC 兜底用户文档区（Documents / Desktop / Downloads 等）；
// Linux + Windows 用户主要靠这层黑名单。展开后的非绝对路径在 New() 时
// 静默丢弃，让 list 跨平台共存（不适用本平台的 rule 自然失效）。
//
// **局限——Bash 不走 PathGuard**。Bash / BashOutput / KillShell 故意声明
// RequiresWorkspace=false 且不查 PathGuard。Forgify 是本地单用户应用，
// Bash 是"用户本来就会在终端敲的命令"的代理，挡 banned-list 没意义。
// 这是有意的 trade-off：`Read ~/.ssh/id_rsa` 被 PathGuard 拦，但
// `bash cat ~/.ssh/id_rsa` 会成功。**PathGuard 是 file-tool 防 LLM 手滑
// 的护栏，不是 LLM 跑 shell 的安全边界**。
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
// the current user's home directory at New() time.
//
// Cross-platform: rules for any OS are listed here; non-applicable rules
// get silently dropped at New() because their post-expansion path fails
// filepath.IsAbs on the running OS (e.g. "C:/Windows/" on Linux is not
// absolute, and "/proc/" doesn't exist on Windows). Tilde-prefixed Windows
// paths like "~/AppData/..." DO survive on macOS / Linux but never match
// a real file there — wasted but harmless.
//
// DefaultDenyList 列出始终拒绝的路径。结尾 "/" = 目录前缀匹配（目录本身及
// 其下任何路径都拒）；无结尾 "/" = 精确文件匹配。"~/" 在 New() 时展开为
// 当前用户家目录。
//
// 跨平台：列表里同时含 macOS / Linux / Windows 的 rule；不适用本平台的
// rule 在 New() 时静默丢弃（展开后 filepath.IsAbs 失败——例如 Linux 上
// "C:/Windows/" 非绝对路径，Windows 上 "/proc/" 也不会出现）。Windows 用
// `~/AppData/...` 写法的 rule 在 macOS / Linux 也算绝对路径，会进 rule
// 表但永不命中真实文件——浪费几个 entry 但无害。
var DefaultDenyList = []string{
	// ── macOS / Linux system-critical paths ───────────────────────────────
	"/etc/", "/usr/", "/sys/", "/bin/", "/sbin/",
	"/private/etc/", "/private/var/", "/System/", "/Library/Keychains/",

	// ── Linux runtime + secrets ───────────────────────────────────────────
	// /proc/<pid>/environ leaks env, /proc/self/maps leaks memory layout;
	// k8s / systemd-creds drop service-account tokens under these paths.
	// /proc/<pid>/environ 泄环境变量、/proc/self/maps 泄内存布局；
	// k8s / systemd-creds 把 service-account token 落在 /run/secrets/ 等。
	"/proc/", "/run/secrets/", "/var/run/secrets/", "/sys/class/",

	// ── Windows system + credential stores ────────────────────────────────
	// "C:/Windows/" gets cleaned to "C:\Windows" on Windows; on macOS / Linux
	// it fails filepath.IsAbs and is dropped silently.
	// "C:/Windows/" 在 Windows 上 Clean 成 "C:\Windows"；在 macOS / Linux
	// 上 IsAbs 失败、静默丢弃。
	"C:/Windows/", "C:/ProgramData/Microsoft/Crypto/",

	// ── User credentials — Unix (TCC blind spots) ─────────────────────────
	"~/.ssh/", "~/.aws/", "~/.gnupg/", "~/.netrc", "~/.config/git-credentials",
	"~/.docker/config.json", "~/.kube/config",

	// ── User credentials — Windows (DPAPI, Credential Manager) ────────────
	"~/AppData/Roaming/Microsoft/Credentials/",
	"~/AppData/Local/Microsoft/Credentials/",
	"~/AppData/Roaming/Microsoft/Crypto/",
	"~/AppData/Roaming/Microsoft/Protect/", // DPAPI master keys
	"~/AppData/Local/Microsoft/Vault/",      // Web Credentials

	// ── Browser saved logins (cross-platform locations) ───────────────────
	// Chrome / Edge / Firefox keep encrypted-but-extractable login DBs;
	// reading them lets a malicious LLM exfiltrate credentials at rest.
	// 浏览器保存的登录数据（加密但本机可解）；读它即等同于偷凭据。
	"~/Library/Application Support/Google/Chrome/Default/Login Data",   // macOS
	"~/.config/google-chrome/Default/Login Data",                        // Linux
	"~/AppData/Local/Google/Chrome/User Data/Default/Login Data",        // Windows
	"~/AppData/Local/Microsoft/Edge/User Data/Default/Login Data",       // Windows Edge

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
