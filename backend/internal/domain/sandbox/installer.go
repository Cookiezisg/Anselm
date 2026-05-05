// installer.go: open/closed extension ports for adding new runtime kinds.
// Adding a new runtime (say, Deno) is one RuntimeInstaller + one EnvManager
// implementation plus one main.go registration line — sandbox core code is
// untouched.
//
// Two responsibilities, deliberately split:
//
//   - RuntimeInstaller knows how to download / locate / version-resolve the
//     runtime binary (e.g. mise install python@3.12; rustup; dotnet-install).
//   - EnvManager knows how to build a per-owner package-isolation env on top
//     of an installed runtime (uv venv + uv pip install for Python, pnpm
//     install --prefix for Node, cargo install --root for Rust, etc.).
//
// installer.go：加新 runtime kind 的开闭扩展端口。
// 新增 runtime（如 Deno）= 写一对 RuntimeInstaller + EnvManager 实现
// 并在 main.go 加一行注册——sandbox 核心代码不改。
//
// 两个职责故意拆开：
//   - RuntimeInstaller 管下载 / 定位 / 版本解析（如 mise install python@3.12 /
//     rustup / dotnet-install）。
//   - EnvManager 管在已装 runtime 上建 per-owner 包隔离 env（Python 用
//     uv venv + uv pip install；Node 用 pnpm install --prefix；Rust 用
//     cargo install --root；等）。

package sandbox

import "context"

// RuntimeInstaller is the install + locate contract for one runtime kind.
// Implementations register at app boot (main.go); the sandbox service
// dispatches by Kind.
//
// RuntimeInstaller 是单个 runtime kind 的装机 + 定位契约。
// 实现在 app 启动时（main.go）注册，sandbox service 按 Kind 派发。
type RuntimeInstaller interface {
	// Kind is the stable string identifier — must match RuntimeSpec.Kind
	// and the kind column in sandbox_runtimes. One Installer per kind.
	//
	// Kind 是稳定字符串标识——必须与 RuntimeSpec.Kind 和 sandbox_runtimes
	// 的 kind 列匹配。一个 kind 对应一个 Installer。
	Kind() string

	// Install installs the requested version into dest. stream is invoked
	// for progress updates (downloading / extracting / etc.); pass nil to
	// skip progress reporting. Returns ErrRuntimeInstallFailed wrapped
	// with stderr context on failure.
	//
	// Install 把指定版本装到 dest。stream 在装机过程中接进度（downloading /
	// extracting / 等）；传 nil 跳过进度上报。失败返 ErrRuntimeInstallFailed
	// 包装 stderr 上下文。
	Install(ctx context.Context, version string, dest string, stream ProgressFunc) error

	// Locate returns the absolute path to the runtime's primary executable
	// inside an installed dest directory (e.g. "<dest>/bin/python" for
	// Python; "<dest>/bin/node" for Node).
	//
	// Locate 返回已装 dest 目录中 runtime 主可执行文件的绝对路径
	// （如 Python 返 "<dest>/bin/python"；Node 返 "<dest>/bin/node"）。
	Locate(version string, dest string) (binPath string, err error)

	// ListAvailable returns versions the user could install, for UI
	// pickers. Optional — return (nil, nil) when enumeration is not
	// supported (e.g. "stable" pseudo-versions).
	//
	// ListAvailable 返回用户可装的版本列表，供 UI picker 用。可选——
	// 不支持枚举（如 "stable" 伪版本）时返 (nil, nil)。
	ListAvailable(ctx context.Context) ([]string, error)

	// ResolveDefault returns the kind's default version (e.g. "3.12.5" for
	// python). Used when an EnvSpec.Runtime.Version is empty.
	//
	// ResolveDefault 返回该 kind 的默认版本（如 python 返 "3.12.5"）。
	// EnvSpec.Runtime.Version 为空时使用。
	ResolveDefault(ctx context.Context) (string, error)
}

// EnvManager is the per-owner env build contract for one runtime kind. One
// Manager per kind, paired with the matching RuntimeInstaller.
//
// EnvManager 是单个 runtime kind 的 per-owner env 构建契约。
// 每 kind 一个 Manager，与对应的 RuntimeInstaller 配对。
type EnvManager interface {
	// Kind matches RuntimeInstaller.Kind() — sandbox dispatches both via
	// the same key.
	//
	// Kind 与 RuntimeInstaller.Kind() 一致——sandbox 用同一 key 派发两者。
	Kind() string

	// CreateEnv materializes an empty isolation env at envPath against the
	// installed runtime at runtimePath (e.g. uv venv for Python, mkdir +
	// package.json init for Node). Idempotent — already-existing env
	// returns nil.
	//
	// CreateEnv 在 envPath 物化一个空的隔离 env，使用 runtimePath 处的已装
	// runtime（如 Python 调 uv venv，Node 调 mkdir + package.json init）。
	// 幂等——已存在直接返 nil。
	CreateEnv(ctx context.Context, runtimePath, envPath string) error

	// InstallDeps installs deps into the env via the runtime's native
	// package manager — uv pip install / pnpm install --prefix / cargo
	// install --root / etc. Deps are package names per the language's
	// idiom (with optional version specifiers). Returns
	// ErrDepInstallFailed wrapped with stderr on failure.
	//
	// InstallDeps 通过 runtime 原生包管理器把 deps 装进 env——uv pip install /
	// pnpm install --prefix / cargo install --root / 等。Deps 是按语言习惯
	// 的包名（可带版本约束）。失败返 ErrDepInstallFailed 包装 stderr。
	InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream ProgressFunc) error

	// InstallExtras runs post-install steps that aren't regular deps —
	// e.g. "browsers/chromium" triggers `playwright install chromium` for
	// the Playwright MCP server. Pass nil/empty extras to skip.
	//
	// InstallExtras 跑非常规 deps 的装后步骤——如 "browsers/chromium" 触发
	// `playwright install chromium`（Playwright MCP server 用）。
	// extras 为 nil/空跳过。
	InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream ProgressFunc) error

	// EnvBin returns the absolute path to a binary inside the env (e.g.
	// "<envPath>/.venv/bin/python" for Python). Used by Spawn to launch
	// processes against env-isolated tools.
	//
	// EnvBin 返回 env 内某 binary 的绝对路径（如 Python 返
	// "<envPath>/.venv/bin/python"）。Spawn 用它针对 env 隔离的工具启进程。
	EnvBin(envPath, binName string) string

	// EnvDir returns the env's primary directory — typically Spawn's cwd
	// candidate.
	//
	// EnvDir 返回 env 主目录——通常作 Spawn cwd 候选。
	EnvDir(envPath string) string
}
