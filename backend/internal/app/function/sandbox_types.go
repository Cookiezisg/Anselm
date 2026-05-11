// sandbox_types.go — request value types for the function.Sandbox port.
//
// Shape mirrors forge's equivalent (SyncRequest / RunRequest / SyncError /
// ComputeEnvID). Per forge_redesign D5 (no cross-domain code reuse), each
// trinity domain owns its own copy — when forge is deleted at the end of
// Plan 01 Phase 7, only the function-side copy remains. If a third domain
// (handler) needs the same shape, the call is "extract to pkg/" vs "copy
// again"; we copy again unless the count hits 3.
//
// sandbox_types.go —— function.Sandbox 端口的请求值类型。
//
// 形状跟 forge 等价物一致(SyncRequest / RunRequest / SyncError /
// ComputeEnvID)。per forge_redesign D5(域之间不复用代码),每个 trinity
// domain 各自维护一份——Plan 01 Phase 7 删 forge 之后只剩 function 这份。
// 如果第三个域(handler)也要,届时考虑是否抽到 pkg/。

package function

import (
	"crypto/sha256"
	"encoding/hex"
	"sort"
	"strings"
)

// SyncRequest is one materialize-this-EnvID order. The Sandbox implementation
// creates a venv keyed by EnvID under the function's own dir, installs
// Dependencies via uv pip, and reports per-stage progress via OnProgress.
//
// SyncRequest 是一份"物化这个 EnvID"的指令。Sandbox 实现按 EnvID 在 function
// 自己的 dir 下建 venv,通过 uv pip 装 Dependencies,per-stage 进度通过
// OnProgress 报。
type SyncRequest struct {
	FunctionID    string
	VersionID     string // for logging only — venv keyed by EnvID, not version
	EnvID         string
	Dependencies  []string
	PythonVersion string
	OnProgress    func(stage, detail string)
}

// RunRequest is one execute-this-function order.
//
// RunRequest 是一份"执行这个 function"的指令。
type RunRequest struct {
	FunctionID    string
	VersionID     string
	EnvID         string
	Code          string
	EntryFunction string // optional; sandbox falls back to first `def` if empty
	Input         map[string]any
}

// SyncError wraps a venv-build failure (e.g. uv pip stderr) so the function
// service can errors.As + extract the captured stderr text into the
// FunctionVersion.EnvError column. Adapter implementations populate this when
// the underlying tool reports a failure.
//
// SyncError 包装 venv 构建失败(如 uv pip stderr),让 function service 能
// errors.As + 把捕获的 stderr 文本提取到 FunctionVersion.EnvError 列。
// adapter 实现在底层工具报错时填这个。
type SyncError struct {
	Cause  error
	Stderr string
}

func (e *SyncError) Error() string { return e.Stderr }
func (e *SyncError) Unwrap() error { return e.Cause }

// ComputeEnvID returns a stable hash-derived id for the (deps, pythonVersion)
// pair: identical inputs produce identical EnvIDs across processes / boots.
//
// Normalization rules: dep names are lowercased up to the first version
// operator (so "Pandas" / "pandas" hash the same); blank entries dropped;
// list sorted lexically; pythonVersion stripped of surrounding whitespace.
// Version constraint operators (>=, ==, ~=) and version numbers are preserved
// verbatim — `pandas>=2.0` and `pandas>=2.0.0` deliberately produce different
// EnvIDs (PEP 440 equivalence requires a full version parser, overkill for
// "deduplicate envs"; one extra venv costs a few MB of metadata).
//
// ComputeEnvID 返 (deps, pythonVersion) 对的稳定 hash 派生 id:相同输入
// 跨进程/boot 产生相同 EnvID。
func ComputeEnvID(deps []string, pythonVersion string) string {
	normalized := make([]string, 0, len(deps))
	for _, d := range deps {
		if n := normalizeSpecifier(d); n != "" {
			normalized = append(normalized, n)
		}
	}
	sort.Strings(normalized)
	payload := strings.Join(normalized, "\n") + "\n" + strings.TrimSpace(pythonVersion)
	h := sha256.Sum256([]byte(payload))
	return "env_" + hex.EncodeToString(h[:6])
}

// normalizeSpecifier trims whitespace and lowercases the leading package-name
// portion (everything up to the first comparison operator or other separator).
// Returns "" for blank input.
//
// normalizeSpecifier 去首尾空白并把前导包名(首个比较符或分隔符前的部分)
// 小写。空白输入返 ""。
func normalizeSpecifier(spec string) string {
	spec = strings.TrimSpace(spec)
	if spec == "" {
		return ""
	}
	i := 0
	for i < len(spec) {
		c := spec[i]
		if (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
			(c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.' {
			i++
			continue
		}
		break
	}
	return strings.ToLower(spec[:i]) + spec[i:]
}
