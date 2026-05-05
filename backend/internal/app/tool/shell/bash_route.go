// bash_route.go — Bash auto-route to conversation sandbox env (sandbox.md
// §9.5). detectRuntime maps a shell command to a runtime kind (python /
// node / etc.); when a non-empty kind is detected and the sandbox service
// is ready, Bash.Execute lazily creates a per-conversation scratch env
// and prepends its bin directories onto PATH so subsequent commands
// (`pip install`, `python script.py`, ...) transparently land in the
// sandbox-managed env instead of the host system.
//
// "Infrastructure収口" approach (per sandbox.md §9.5 vs. denylist
// alternative): we never block the LLM from running pip install; we just
// reroute it. The LLM is unaware — packages it installs vanish when the
// conversation env is destroyed; multiple conversations don't share state.
//
// bash_route.go ——Bash 自动路由到 conversation sandbox env（sandbox.md §9.5）。
// detectRuntime 把 shell 命令映射到 runtime kind（python / node / 等）；检测
// 到非空 kind 且 sandbox service ready 时，Bash.Execute 懒建 per-conversation
// scratch env，把它的 bin 目录前置到 PATH，让后续命令（`pip install`、
// `python script.py` 等）透明落到 sandbox 管的 env 而非主机系统。
//
// "基础设施收口"路线（sandbox.md §9.5 vs denylist 替代）：从不拦 LLM 跑
// pip install——只重路由。LLM 无感——它装的包在 conversation env 销毁时消失；
// 多对话不共享状态。

package shell

import (
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

// runtimeDetector pairs a runtime kind with the regex that decides
// whether a command "looks like" that runtime. First-match wins; order
// in the slice doesn't matter because patterns are disjoint.
//
// runtimeDetector 把 runtime kind 与决定命令"看起来像"该 runtime 的 regex
// 配对。首次匹配胜；切片顺序无关因 pattern 不相交。
type runtimeDetector struct {
	Kind    string
	Pattern *regexp.Regexp
}

// runtimeDetectors mirrors sandbox.md §9.5. To extend, add one row + one
// matching MiseInstaller registration in main.go's registerSandboxStack.
//
// runtimeDetectors 镜像 sandbox.md §9.5。扩展：加一行 + 在 main.go
// registerSandboxStack 加一个匹配 MiseInstaller 注册。
var runtimeDetectors = []runtimeDetector{
	{Kind: "python", Pattern: regexp.MustCompile(`^(?:python3?(?:\.\d+)?|pip3?|uv|virtualenv|pipenv|poetry)\b`)},
	{Kind: "node", Pattern: regexp.MustCompile(`^(?:node|npm|npx|yarn|pnpm)\b`)},
	{Kind: "rust", Pattern: regexp.MustCompile(`^(?:cargo|rustc|rustup)\b`)},
	{Kind: "go", Pattern: regexp.MustCompile(`^go\b`)},
	{Kind: "ruby", Pattern: regexp.MustCompile(`^(?:ruby|gem|bundle|bundler|rake)\b`)},
	{Kind: "php", Pattern: regexp.MustCompile(`^(?:php|composer)\b`)},
	{Kind: "java", Pattern: regexp.MustCompile(`^(?:java|javac|mvn|gradle)\b`)},
	{Kind: "dotnet", Pattern: regexp.MustCompile(`^dotnet\b`)},
}

// detectRuntime returns the runtime kind a command targets, or "" when
// no detector matches (regular Unix tools — ls, cat, git, etc. — fall
// through to plain shell). Uses the FIRST shell token after stripping
// chained-command prefixes (`cd /tmp && pip install ...` examines
// `pip install ...`); this keeps the logic deterministic without a full
// shell parser. Nested constructs (`bash -c "pip install"`) match `bash`
// not `pip`, intentionally — those degrade to plain shell and the LLM
// can adjust.
//
// detectRuntime 返命令瞄准的 runtime kind；无 detector 匹配返 ""（普通 Unix
// 工具——ls / cat / git 等——落到 plain shell）。剥链式命令前缀后取首 token
// （`cd /tmp && pip install ...` 看 `pip install ...`）；让逻辑确定性而无需
// 完整 shell 解析。嵌套构造（`bash -c "pip install"`）匹配 `bash` 非 `pip`，
// 故意——降级到 plain shell 让 LLM 自己调整。
func detectRuntime(command string) string {
	command = strings.TrimSpace(command)
	if command == "" {
		return ""
	}
	// Strip leading "cd <path> &&" prefix (single-segment, no recursion)
	// so the meaningful command is what we examine.
	// 剥前置 "cd <path> &&"（单段不递归）让有意义的命令被检查。
	if rest, ok := stripCDPrefix(command); ok {
		command = rest
	}
	// Take the first whitespace-separated token. Quotes / env-var
	// assignments (FOO=bar pip install) aren't handled — same simplicity
	// trade-off as the parser-less approach above.
	// 取首个空白分隔 token。引号 / env 赋值（FOO=bar pip install）不处理
	// ——同上的简化权衡。
	first := command
	if idx := strings.IndexAny(command, " \t"); idx > 0 {
		first = command[:idx]
	}
	for _, d := range runtimeDetectors {
		if d.Pattern.MatchString(first) {
			return d.Kind
		}
	}
	return ""
}

// stripCDPrefix removes a leading "cd <path> &&" (with optional trailing
// whitespace) and returns the rest. Returns (orig, false) when no such
// prefix exists. Only matches the exact pattern; chained `cd a && cd b
// && cmd` strips one level (good enough for the common LLM idiom).
//
// stripCDPrefix 剥前置 "cd <path> &&"（可带尾空白）返剩余。无该前缀返
// (orig, false)。仅匹配精确 pattern；链式 `cd a && cd b && cmd` 剥一层
// （够覆盖常见 LLM 用法）。
var cdPrefixRe = regexp.MustCompile(`^\s*cd\s+\S+\s*&&\s*`)

func stripCDPrefix(command string) (string, bool) {
	if loc := cdPrefixRe.FindStringIndex(command); loc != nil {
		return command[loc[1]:], true
	}
	return command, false
}

// envBinDirsForKind returns the directories under envPath that should
// prepend to PATH for the given runtime kind. Returns nil for kinds whose
// EnvManagers don't expose bin directories (Java uses classpath; Dotnet
// uses runtime PATH from the install dir, not from per-env scaffolding).
//
// envBinDirsForKind 返该 kind 应前置到 PATH 的 envPath 下目录。EnvManager
// 不暴露 bin 目录的 kind 返 nil（Java 用 classpath；Dotnet 从 install dir
// 的 runtime PATH 而非 per-env 脚手架）。
func envBinDirsForKind(envPath, kind string) []string {
	switch kind {
	case "python":
		// venv layout: bin/ on unix, Scripts/ on Windows.
		// venv 布局：unix bin/，Windows Scripts/。
		sub := "bin"
		if runtime.GOOS == "windows" {
			sub = "Scripts"
		}
		return []string{filepath.Join(envPath, ".venv", sub)}
	case "node":
		return []string{filepath.Join(envPath, "node_modules", ".bin")}
	case "rust", "go":
		return []string{filepath.Join(envPath, "bin")}
	case "ruby":
		return []string{filepath.Join(envPath, "bundle", "bin")}
	case "php":
		return []string{filepath.Join(envPath, "vendor", "bin")}
	default:
		return nil
	}
}

// prependPath returns env with PATH (or Path on Windows) updated so each
// dir in extras is prepended in order. Empty extras returns env unchanged.
//
// prependPath 返 env 把 PATH（Windows 上 Path）更新为 extras 中每个目录前置。
// extras 为空返 env 不变。
func prependPath(env []string, extras []string) []string {
	if len(extras) == 0 {
		return env
	}
	pathKey := "PATH"
	pathSep := ":"
	if runtime.GOOS == "windows" {
		pathKey = "Path"
		pathSep = ";"
	}
	prepend := strings.Join(extras, pathSep)
	out := make([]string, 0, len(env))
	replaced := false
	for _, kv := range env {
		if eq := strings.IndexByte(kv, '='); eq > 0 && envKeyEqual(kv[:eq], pathKey) {
			out = append(out, pathKey+"="+prepend+pathSep+kv[eq+1:])
			replaced = true
			continue
		}
		out = append(out, kv)
	}
	if !replaced {
		out = append(out, pathKey+"="+prepend)
	}
	return out
}

// envKeyEqual compares env-var keys case-insensitively on Windows
// (where PATH/Path/path all alias) and case-sensitively elsewhere.
//
// envKeyEqual 比较 env var key：Windows 大小写无关（PATH/Path/path 同义），
// 其他平台大小写敏感。
func envKeyEqual(a, b string) bool {
	if runtime.GOOS == "windows" {
		return strings.EqualFold(a, b)
	}
	return a == b
}
