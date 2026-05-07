// registry.go — value types for the MCP marketplace + the RegistrySource
// port that decouples production (official MCP Registry HTTP fetch) from
// tests (fake source with predictable entries). The marketplace V2
// (2026-05-08) replaced the previous in-code 6-entry V1 builtins with
// RegistrySource — entries now come from registry.modelcontextprotocol.io
// (community-driven, growing organically).
//
// registry.go ——MCP marketplace 的值类型 + RegistrySource 端口，让生产
// （官方 MCP Registry HTTP fetch）与测试（fake source 给确定条目）解耦。
// marketplace V2（2026-05-08）把原 6 条内置项换成 RegistrySource——
// 条目现来自 registry.modelcontextprotocol.io（社区驱动，有机增长）。
package mcp

import (
	"context"
	"errors"
)

// RegistryEntry is one marketplace listing the LLM (via install_mcp_server
// tool) and UI (via /mcp-registry endpoint) can install. Schema chosen to
// be the intersection of "what Forgify needs to install + run" and "what
// the official MCP Registry actually publishes" — fields like Category /
// License / Notes (V1 had them) are dropped because the official registry
// doesn't carry them and adding them would force per-entry curation.
//
// RegistryEntry 是 marketplace 一个可装条目，LLM（经 install_mcp_server）
// 与 UI（经 /mcp-registry 端点）都用。schema 取"Forgify 装+跑所需"与"官方
// 注册表真正提供"的交集——V1 有的 Category / License / Notes 被删（官方没
// 这些，留着会强行 per-entry 人工 curation）。
type RegistryEntry struct {
	Name              string            `json:"name"`                   // canonical id: "io.github.<user>/<server>"
	DisplayName       string            `json:"displayName"`            // human-readable label (UI)
	Description       string            `json:"description"`
	Homepage          string            `json:"homepage,omitempty"`     // sourced from server.repository.url
	Runtime           string            `json:"runtime"`                // node / python / docker (chosen by package selector)
	Version           string            `json:"version,omitempty"`      // server.version from registry; install pins to this
	InstallCmd        InstallCmd        `json:"installCmd"`
	PostInstallSteps  []PostInstallStep `json:"postInstallSteps,omitempty"`
	RequiredEnv       []EnvRequirement  `json:"requiredEnv,omitempty"`
	RequiredArgs      []ArgRequirement  `json:"requiredArgs,omitempty"`
	DefaultTimeoutSec int               `json:"defaultTimeoutSec,omitempty"` // 0 = use global 30s
}

// InstallCmd is what the install flow runs to make the server available.
// Args may contain "${name}" tokens substituted from RequiredArgs at
// install time (e.g. "${dbPath}" for SQLite's --db-path).
//
// InstallCmd 是 install 流程跑的命令。Args 可含 "${name}" token，安装时
// 从 RequiredArgs 替换（例：SQLite 的 --db-path 用 "${dbPath}"）。
type InstallCmd struct {
	Command string   `json:"command"` // npx / uvx / docker / ...
	Args    []string `json:"args"`
}

// PostInstallStep is an extra command run after InstallCmd succeeds —
// e.g. Playwright needs `playwright install chromium` to download the
// browser binary. StreamProgress is a hint to UIs to show a progress bar
// for long-running steps.
//
// PostInstallStep 是 InstallCmd 成功后的额外命令——如 Playwright 需
// `playwright install chromium`。StreamProgress 是给 UI 的提示，长任务
// 显示进度条。
type PostInstallStep struct {
	Description    string   `json:"description"`
	Command        string   `json:"command"`
	Args           []string `json:"args"`
	StreamProgress bool     `json:"streamProgress"`
}

// EnvRequirement is one env var the user must provide before install
// (typically a credential). Secret=true masks the input field; SetupURL
// points the user at where to get the value (e.g. GitHub's PAT page).
//
// EnvRequirement 是用户安装前必填的一个 env 变量（通常是凭证）。
// Secret=true 让 UI mask 输入；SetupURL 指向获取链接（如 GitHub PAT 页）。
type EnvRequirement struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	SetupURL    string `json:"setupUrl,omitempty"`
	Secret      bool   `json:"secret"`
}

// ArgRequirement is a value the user must supply at install time that
// gets substituted into InstallCmd.Args via the "${name}" template.
// Type drives the UI input widget — path / url / string.
//
// ArgRequirement 是用户安装时必填的值，经 "${name}" 模板替换进
// InstallCmd.Args。Type 驱动 UI 输入控件——path / url / string。
type ArgRequirement struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Type        string `json:"type"`
	Default     string `json:"default,omitempty"`
}

// ── RegistrySource port ──────────────────────────────────────────────

// RegistrySource is the marketplace data source — production wires
// infra/mcp.OfficialRegistrySource (HTTP fetch + in-memory cache against
// registry.modelcontextprotocol.io); tests wire infra/mcp.FakeRegistrySource
// with deterministic entries. Either way returns the catalog mcp.Service
// exposes via ListRegistry / GetRegistryEntry.
//
// RegistrySource 是 marketplace 数据源——生产接 infra/mcp.OfficialRegistrySource
// （HTTP fetch + 进程内缓存，对 registry.modelcontextprotocol.io）；测试接
// infra/mcp.FakeRegistrySource 给确定条目。两者都返 mcp.Service 经
// ListRegistry / GetRegistryEntry 暴露的目录。
type RegistrySource interface {
	// List returns all marketplace entries. The first call may block on
	// a network fetch (~1-15s depending on registry size); subsequent
	// calls return cached results from process memory. Returns
	// ErrMarketplaceUnavailable when the fetch fails and no cache exists.
	//
	// List 返所有 marketplace 条目。首次调用可能阻塞 fetch（~1-15s 取决于
	// registry 大小）；后续从进程内存返。fetch 失败且无缓存返
	// ErrMarketplaceUnavailable。
	List(ctx context.Context) ([]RegistryEntry, error)

	// Get returns a single entry by canonical name. Uses the same cache
	// as List. Returns ErrRegistryEntryNotFound when the name is not in
	// the (possibly fetched) catalog.
	//
	// Get 按 canonical name 返单个条目。共享 List 的缓存。name 不在（可能已
	// fetch 过的）目录中返 ErrRegistryEntryNotFound。
	Get(ctx context.Context, name string) (*RegistryEntry, error)

	// Refresh forces a re-fetch, replacing any cached data. Used by
	// manual UI refresh buttons. Failure leaves the previous cache intact.
	//
	// Refresh 强制重新 fetch + 替换缓存。UI 手动刷新按钮用。失败时旧缓存
	// 保持不变。
	Refresh(ctx context.Context) error
}

// ── Marketplace V2 sentinels ────────────────────────────────────────

var (
	// ErrMarketplaceUnavailable means the registry source could not fetch
	// the catalog (network down, API error, etc.) AND no in-memory cache
	// exists. UI / LLM should advise the user to check connectivity or
	// configure a BYOK search key as fallback.
	//
	// ErrMarketplaceUnavailable 表示 registry source 无法 fetch 目录
	// （网络挂、API 错等）且无内存缓存。UI / LLM 应提示用户检查网络或配
	// BYOK 搜索 key 作 fallback。
	ErrMarketplaceUnavailable = errors.New("mcp: marketplace registry unavailable")

	// ErrAliasCollision means the user-chosen alias for a new MCP server
	// is already in use by another configured server. Caller should pick
	// a different alias and retry.
	//
	// ErrAliasCollision 表示用户为新 MCP server 选的 alias 已被另一个已配
	// 置的 server 占用。调用方应换个 alias 重试。
	ErrAliasCollision = errors.New("mcp: alias already in use")

	// ErrAlreadyInstalled means an install attempt targeted a server alias
	// that's already configured (mcp.json already has it). Caller should
	// uninstall first or pick a different alias.
	//
	// ErrAlreadyInstalled 表示安装尝试针对已配置的 server alias（mcp.json
	// 已有）。调用方应先卸或换个 alias。
	ErrAlreadyInstalled = errors.New("mcp: server already installed")

	// ErrUnsupportedRuntime means the registry entry's package list has no
	// runtime Forgify can handle (e.g. only docker but Docker daemon not
	// detected, or only an unsupported package type).
	//
	// ErrUnsupportedRuntime 表示 registry 条目的 package 列表无 Forgify 能
	// 处理的 runtime（如只有 docker 但 daemon 未检测到，或只有不支持的
	// package 类型）。
	ErrUnsupportedRuntime = errors.New("mcp: no supported runtime for entry")

	// (ErrInstallFailed already exists in mcp.go — reused here for the
	// new install_mcp_server tool's error path.)
	// (ErrInstallFailed 已在 mcp.go 声明——新 install_mcp_server 工具的错误
	// 路径复用之。)

	// ErrHandshakeFailed means the server installed successfully but
	// failed the MCP initialize handshake. Caller can still retry
	// connection later via Reconnect; the server stays in the registry
	// with status=failed.
	//
	// ErrHandshakeFailed 表示 server 装成功但 MCP initialize 握手失败。
	// 调用方可后续 Reconnect 重试；server 留在 registry 状态 failed。
	ErrHandshakeFailed = errors.New("mcp: server installed but handshake failed")
)
