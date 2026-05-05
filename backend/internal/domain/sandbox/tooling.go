package sandbox

import "context"

// ToolRegistry resolves support-tool (kind, version) → absolute binary path,
// lazily installing the underlying runtime when absent. Implemented by
// app/sandbox.Service (production); tests use in-memory fakes.
//
// ToolRegistry 把支持工具 (kind, version) 解析为绝对二进制路径，缺则懒装。
// 由 app/sandbox.Service 实现（生产）；测试用内存 fake。
type ToolRegistry interface {
	// EnsureTool returns the absolute path to kind's primary binary,
	// installing if absent. version="" = kind's default (Installer-defined).
	// Returns ErrRuntimeNotSupported when no installer registered;
	// ErrRuntimeInstallFailed (wrapping stderr) on install failure.
	//
	// EnsureTool 返 kind 主二进制绝对路径，缺则装。version="" = 该 kind 默认
	// （Installer 定义）。无 installer 返 ErrRuntimeNotSupported；装失败返
	// ErrRuntimeInstallFailed（含 stderr）。
	EnsureTool(ctx context.Context, kind, version string) (binPath string, err error)
}
