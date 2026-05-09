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
	// Name is the short, human-friendly identifier (e.g. "playwright",
	// "notion", "ms365"). Doubles as the mcp.json key once installed and
	// as the lookup id LLM tools pass to install_mcp_server / etc.
	// Curated catalog gives every entry a clean kebab-case slug — no
	// canonical "io.github.X/server" prefixes.
	//
	// Name 是短的人性化 id（如 "playwright"、"notion"、"ms365"）。装好后同时
	// 作 mcp.json key + LLM 工具传给 install_mcp_server 的 lookup id。curated
	// 目录给每条一个干净的 kebab-case slug。
	Name string `json:"name"`

	Description string `json:"description"`        // one-line capability summary
	Homepage    string `json:"homepage,omitempty"` // GitHub / docs URL
	Runtime     string `json:"runtime"`            // node / python (curated list is npm + pypi only)
	Version     string `json:"version,omitempty"`  // pinned version; empty means "latest"

	InstallCmd   InstallCmd       `json:"installCmd"`
	RequiredEnv  []EnvRequirement `json:"requiredEnv,omitempty"`
	RequiredArgs []ArgRequirement `json:"requiredArgs,omitempty"`

	// Category groups entries for marketplace filtering / display
	// (browser, web-data, code, vcs, error, db, pm, docs, design, memory,
	// sandbox, email).
	//
	// Category 给 marketplace 分组。
	Category string `json:"category,omitempty"`

	// Tier indicates setup friction so UIs can sort easiest-first:
	//   0 — zero config, install and use
	//   1 — single API key (free / easy signup)
	//   2 — OAuth flow (device code; first run prints login URL to stderr)
	//   3 — DB / cloud credential (DSN / connection string / multiple env)
	//
	// Tier 表征上手难度：0 零配置；1 一个 API key；2 OAuth 设备码；3 DB / 云凭证。
	Tier int `json:"tier"`

	// Notes are free-text "watch out" hints — first-run downloads, OAuth
	// flow expectations, common pitfalls. Surfaced in install UI + LLM
	// marketplace results so the agent can warn the user proactively.
	//
	// Notes 是"陷阱提示"——首次下载、OAuth 流、常见坑。
	Notes string `json:"notes,omitempty"`
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

// RegistrySource is the marketplace data source. Production wires
// infra/mcp.CuratedRegistrySource (21 hand-picked entries); tests wire
// the in-memory test fixture.
//
// V3 (2026-05-09): full List replaces the V2 Search-only contract.
// Curated catalog tops out around 21–30 entries — listing all of them
// fits comfortably in the LLM's context, and per-call keyword search
// (V2) was empirically too lossy (4-token AND-match found 1 of 21
// playwright/browser/github/slack candidates).
//
// RegistrySource 是 marketplace 数据源——生产接 CuratedRegistrySource
// （21 条精选）；测试接内存 fixture。
//
// V3（2026-05-09）：全量 List 取代 V2 仅 Search。curated 目录上限 ~21-30
// 条，全列入 LLM context 完全 OK；V2 关键词 AND-match 实测召回过低
// （playwright/browser/github/slack 4 词 21 条只命中 1）。
type RegistrySource interface {
	// List returns every entry in the curated catalog, sorted tier-asc
	// then name-asc so "easiest-to-use" servers appear first. Stable
	// ordering — callers can rely on the order being identical across
	// calls within one process.
	//
	// List 返 curated 目录所有条目，按 tier asc + name asc 稳排让"最易上手"
	// 排前。同进程内多次调用顺序一致。
	List(ctx context.Context) ([]RegistryEntry, error)

	// Get returns a single entry by canonical name. Returns
	// ErrRegistryEntryNotFound when the name isn't in the curated list.
	//
	// Get 按规范 name 返单条目；不在 curated 列表返 ErrRegistryEntryNotFound。
	Get(ctx context.Context, name string) (*RegistryEntry, error)
}

// ── Marketplace V2 sentinels ────────────────────────────────────────

var (
	// ErrMarketplaceUnavailable means the registry source could not fetch
	// the catalog (network down, API error, etc.). UI / LLM should advise
	// the user to check connectivity or configure a BYOK search key as
	// fallback.
	//
	// ErrMarketplaceUnavailable 表示 registry source 无法 fetch 目录
	// （网络挂、API 错等）。UI / LLM 应提示用户检查网络或配 BYOK 搜索 key
	// 作 fallback。
	ErrMarketplaceUnavailable = errors.New("mcp: marketplace registry unavailable")

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
