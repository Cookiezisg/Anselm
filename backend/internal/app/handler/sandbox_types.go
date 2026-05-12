// sandbox_types.go — request value types for the handler.Sandbox port.
//
// Mirrors function.SyncRequest shape; SpawnRequest is new (handler is the
// first trinity domain that needs long-lived subprocess spawn).
//
// sandbox_types.go — handler.Sandbox 端口的请求值类型。SyncRequest 跟 function
// 同形;SpawnRequest 是 handler 新加(第一个要长跑子进程的 trinity 域)。

package handler

import (
	"crypto/sha256"
	"encoding/hex"
	"sort"
	"strings"
)

// SyncRequest is one materialize-this-EnvID order. Same shape as function's.
//
// SyncRequest 物化 EnvID 指令(跟 function 同形)。
type SyncRequest struct {
	HandlerID     string
	VersionID     string
	EnvID         string
	Dependencies  []string
	PythonVersion string
	OnProgress    func(stage, detail string)
}

// SpawnRequest is one start-long-lived-subprocess order. The Sandbox spawns
// a python process running the driver script (which imports HandlerImpl from
// user_handler.py).
//
// SpawnRequest 起长跑子进程指令。Sandbox 跑 python driver(import user_handler 中的 HandlerImpl)。
type SpawnRequest struct {
	HandlerID string
	VersionID string
	EnvID     string
	// Env vars passed to subprocess (PYTHONPATH etc.). System sets these;
	// user init_args go via the protocol init message, NOT env.
	//
	// Env 给子进程的环境变量(PYTHONPATH 等);user init_args 走协议 init
	// 消息,不走 env。
	Env map[string]string
}

// SyncError wraps a venv-build failure so Service can errors.As + extract
// stderr text into Version.EnvError.
//
// SyncError 包装 venv 构建失败,Service 经 errors.As + 提 stderr 到 EnvError。
type SyncError struct {
	Cause  error
	Stderr string
}

func (e *SyncError) Error() string { return e.Stderr }
func (e *SyncError) Unwrap() error { return e.Cause }

// ComputeEnvID derives a stable EnvID from (deps, pythonVersion). Same algorithm
// as function.ComputeEnvID — see that file for the normalization rules
// rationale (D5 says each trinity owns its own copy; here we copy).
//
// ComputeEnvID 从 (deps, pythonVersion) 派生稳定 EnvID。算法跟 function 同
// (D5 各 trinity 自维护一份;此处复制)。
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
