// tooling.go — ToolRegistry abstraction for EnvManager → support-tool
// resolution. Solves the "PythonEnvManager needs uv, NodeEnvManager needs
// pnpm, JavaEnvManager needs mvn" lookup problem without coupling
// EnvManager implementations to mise / boot ordering / Service internals.
//
// Design intent:
//
//   - EnvManager implementations call ToolRegistry.EnsureTool to find
//     support binaries (uv / pnpm / mvn / bundle / composer / etc.).
//   - The registry hides whether the tool is mise-installed, embed-shipped,
//     or system-found — EnvManager doesn't care.
//   - First call triggers install; subsequent calls hit the manifest cache.
//     This keeps server boot fast (no synchronous "install uv before start"
//     blocker) while paying the install cost exactly once on first use.
//
// app/sandbox/Service implements ToolRegistry by chaining EnsureRuntime +
// RuntimeInstaller.Locate; main.go injects the Service as the registry
// when constructing EnvManagers.
//
// tooling.go ——给 EnvManager 解析支持工具用的 ToolRegistry 抽象。解决
// "PythonEnvManager 要 uv、NodeEnvManager 要 pnpm、JavaEnvManager 要 mvn"
// 的查找问题，不让 EnvManager 实现耦合 mise / boot 顺序 / Service 内部。
//
// 设计意图：
//
//   - EnvManager 实现调 ToolRegistry.EnsureTool 找支持二进制
//     （uv / pnpm / mvn / bundle / composer 等）。
//   - Registry 隐藏工具是 mise 装 / embed 自带 / 系统找到——EnvManager 不关心。
//   - 首次调用触发装；后续调用命中 manifest 缓存。让 server 启动快
//     （无"先装 uv 才能启动"同步阻塞），首次使用付一次 install 代价。
//
// app/sandbox/Service 通过链 EnsureRuntime + RuntimeInstaller.Locate 实现
// ToolRegistry；main.go 在构造 EnvManager 时把 Service 注入作 registry。

package sandbox

import "context"

// ToolRegistry resolves support-tool kind/version pairs to absolute
// binary paths, lazily installing the underlying runtime when absent.
//
// Implementations: app/sandbox.Service (production); unit tests provide
// in-memory fakes that pre-seed paths.
//
// ToolRegistry 把支持工具 kind/version 对解析为绝对二进制路径，缺则懒装
// 底层 runtime。
//
// 实现：app/sandbox.Service（生产）；单测提供预填路径的内存 fake。
type ToolRegistry interface {
	// EnsureTool returns the absolute path to <kind>'s primary binary,
	// installing the runtime if absent. version="" requests the kind's
	// default (Installer-defined). Returns ErrRuntimeNotSupported if no
	// installer is registered for kind, ErrRuntimeInstallFailed wrapped
	// with installer stderr on install failure.
	//
	// EnsureTool 返 <kind> 主二进制绝对路径，缺则装 runtime。version=""
	// 请求该 kind 默认（Installer 定义）。无 installer 注册返
	// ErrRuntimeNotSupported；装失败返 ErrRuntimeInstallFailed 包装
	// installer stderr。
	EnsureTool(ctx context.Context, kind, version string) (binPath string, err error)
}
