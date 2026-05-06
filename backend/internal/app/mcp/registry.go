// Package mcp (app/mcp) is the service layer for MCP integration.
// This file defines the in-memory marketplace Registry: V1 ships 6
// bundled entries (5 user-visible + 1 hidden test) compiled into the
// binary. The full Service (Connect/Disconnect/Search/CallTool/Install/
// Health) lands in D6 once the stdio Client wrapper exists.
//
// V1 entry rationale (mcp.md §5.5):
//   - playwright   — browser automation; demo-wow for non-tech users
//   - markitdown   — PDF/DOCX/PPT → markdown for LLM consumption
//   - context7     — fresh per-week library docs (technical demo)
//   - duckduckgo-search — zero-API-key web search (works out of the box)
//   - sqlite       — query/modify a user-supplied .sqlite file
//   - everything   — Hidden=true reference test server for pipeline tests
//
// Skipped V1: anything needing OAuth (github / notion / slack / ...) —
// the OAuth 2.1 + DCR ecosystem is currently broken across providers,
// breaking the out-of-box experience.
//
// Windows compatibility audit (D11, 2026-05-06): all 6 V1 entries are
// confirmed Windows-compatible — runtimes (node / python via uvx) ship
// official Windows builds, transports are stdio (cross-platform), and
// no entry depends on Unix-only features (fork, Unix sockets, /bin/sh).
// No UnsupportedPlatforms field set on any V1 entry. Future entries
// requiring Unix-specific behavior (e.g. AppleScript / dbus / systemd)
// should populate UnsupportedPlatforms accordingly.
//
// Windows 兼容审计（D11, 2026-05-06）：6 项 V1 全部 Windows 兼容
// ——runtime（node / uvx 的 python）有官方 Windows 包，传输 stdio 跨平
// 台，无条目依赖 Unix-only 特性（fork / Unix sockets / /bin/sh）。无
// V1 项设 UnsupportedPlatforms。未来要 Unix 特定行为的条目（如
// AppleScript / dbus / systemd）应填 UnsupportedPlatforms。
//
// Future V2 (mcp.md §5.5 strategy-pattern note): replace
// embedRegistryProvider with remoteRegistryProvider that fetches a JSON
// catalog over HTTPS + 24h cache. Public Registry interface unchanged.
//
// Package mcp（app/mcp）是 MCP 集成的 service 层。本文件定义内存
// marketplace Registry：V1 内置 6 项（5 可见 + 1 hidden test）编译进 binary。
// 完整 Service（Connect/Disconnect/Search/CallTool/Install/Health）在 D6
// 落地，需要 stdio Client wrapper。未来 V2 用 remoteRegistryProvider 替换
// embedRegistryProvider 拿远程 JSON + 24h 缓存。
package mcp

import (
	"runtime"
	"slices"
	"sort"
	"sync"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// builtInEntries is the V1 marketplace catalog. Order in this slice is
// presentational only — Registry.List() sorts alphabetically by Name
// for stable UI rendering across calls.
//
// builtInEntries 是 V1 marketplace 目录。slice 顺序仅展示——Registry.List()
// 按 Name 字母序排序保证 UI 渲染稳定。
var builtInEntries = []mcpdomain.RegistryEntry{
	{
		Name:        "playwright",
		DisplayName: "Playwright",
		Description: "Headless browser automation. Open URLs, click elements, fill forms, take screenshots.",
		Category:    "browser",
		Homepage:    "https://github.com/microsoft/playwright-mcp",
		License:     "Apache-2.0",
		Runtime:     "node",
		Bundled:     true,
		InstallCmd: mcpdomain.InstallCmd{
			Command: "npx",
			Args:    []string{"-y", "@playwright/mcp"},
		},
		PostInstallSteps: []mcpdomain.PostInstallStep{
			{
				Description:    "Downloading Chromium browser (~150MB, one-time)",
				Command:        "npx",
				Args:           []string{"-y", "playwright", "install", "chromium"},
				StreamProgress: true,
			},
		},
		DefaultTimeoutSec: 60, // browser ops are slow
		Notes:             "Optionally use system Chrome via 'useSystemChrome' arg to skip download (advanced).",
	},
	{
		Name:        "markitdown",
		DisplayName: "MarkItDown",
		Description: "Convert PDF / DOCX / PPTX / XLSX / images / audio / YouTube to markdown for LLM consumption.",
		Category:    "doc",
		Homepage:    "https://github.com/microsoft/markitdown",
		License:     "MIT",
		Runtime:     "python",
		Bundled:     true,
		InstallCmd: mcpdomain.InstallCmd{
			Command: "uvx",
			Args:    []string{"markitdown-mcp"},
		},
		Notes: "Best on text-based PDFs/Office docs. Complex layouts (scanned docs) may extract poorly.",
	},
	{
		Name:        "context7",
		DisplayName: "Context7",
		Description: "Up-to-date library docs from Context7. AI sees this week's API releases.",
		Category:    "docs",
		Homepage:    "https://github.com/upstash/context7",
		License:     "MIT",
		Runtime:     "node",
		Bundled:     true,
		InstallCmd: mcpdomain.InstallCmd{
			Command: "npx",
			Args:    []string{"-y", "@upstash/context7-mcp"},
		},
		OnlineOnly: true,
		Notes:      "Calls Context7 service; requires internet. Free tier rate-limited.",
	},
	{
		Name:        "duckduckgo-search",
		DisplayName: "DuckDuckGo Search",
		Description: "Free web search via DuckDuckGo — no API key required.",
		Category:    "web",
		Homepage:    "https://github.com/nickclyde/duckduckgo-mcp-server",
		License:     "MIT",
		Runtime:     "python",
		Bundled:     true,
		InstallCmd: mcpdomain.InstallCmd{
			Command: "uvx",
			Args:    []string{"duckduckgo-mcp-server"},
		},
	},
	{
		Name:        "sqlite",
		DisplayName: "SQLite",
		Description: "Query and modify a user-specified SQLite database.",
		Category:    "data",
		License:     "MIT",
		Runtime:     "python",
		Bundled:     true,
		InstallCmd: mcpdomain.InstallCmd{
			Command: "uvx",
			Args:    []string{"mcp-server-sqlite", "--db-path", "${dbPath}"},
		},
		RequiredArgs: []mcpdomain.ArgRequirement{
			{Name: "dbPath", Description: "Absolute path to a .sqlite/.db file", Type: "path"},
		},
	},
	{
		Name:        "everything",
		DisplayName: "Everything (test server)",
		Description: "MCP protocol reference test server.",
		Category:    "demo",
		Runtime:     "node",
		Bundled:     true,
		Hidden:      true, // marketplace UI hides; pipeline tests use it
		InstallCmd: mcpdomain.InstallCmd{
			Command: "npx",
			Args:    []string{"-y", "@modelcontextprotocol/server-everything"},
		},
		Notes: "For Forgify pipeline tests only.",
	},
}

// Registry indexes RegistryEntry by Name. Constructed once at boot from
// builtInEntries; future remote-loaded entries would mutate behind the
// same Get/List/Visible facade. Read-only post-construction.
//
// Registry 按 Name 索引 RegistryEntry。boot 时从 builtInEntries 一次构造；
// 未来远程加载条目通过同 Get/List/Visible 门面变更。构造后只读。
type Registry struct {
	once sync.Once
	idx  map[string]mcpdomain.RegistryEntry
}

// NewRegistry constructs the V1 in-code registry.
//
// NewRegistry 用 V1 内置数据构造 registry。
func NewRegistry() *Registry {
	return &Registry{}
}

func (r *Registry) ensureIndexed() {
	r.once.Do(func() {
		r.idx = make(map[string]mcpdomain.RegistryEntry, len(builtInEntries))
		for _, e := range builtInEntries {
			r.idx[e.Name] = e
		}
	})
}

// Get returns the RegistryEntry for name; second return false when
// absent. Hidden entries are returned (callers like the install flow
// need to look up the hidden everything server by name).
//
// Get 按 name 取 RegistryEntry；不存在第二返 false。Hidden 条目也返
// （install 流等调用方需要按名查 hidden 的 everything server）。
func (r *Registry) Get(name string) (mcpdomain.RegistryEntry, bool) {
	r.ensureIndexed()
	e, ok := r.idx[name]
	return e, ok
}

// List returns every entry in stable Name order — used by the wire
// /api/v1/mcp-registry endpoint. Visible() applies the user-facing
// filter (hide Hidden + UnsupportedPlatforms); List does not.
//
// List 按 Name 字母序返所有条目——/api/v1/mcp-registry wire 用。
// Visible() 应用用户面过滤（藏 Hidden + UnsupportedPlatforms）；List 不过滤。
func (r *Registry) List() []mcpdomain.RegistryEntry {
	r.ensureIndexed()
	out := make([]mcpdomain.RegistryEntry, 0, len(r.idx))
	for _, e := range r.idx {
		out = append(out, e)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

// Visible returns entries the marketplace UI should show on the current
// platform: drop Hidden=true and drop entries whose UnsupportedPlatforms
// includes the running GOOS (per mcp.md §5.5 Windows-platform-filter
// section). Stable Name order matches List.
//
// Visible 返当前平台 marketplace UI 应展示的条目：去 Hidden=true，去
// UnsupportedPlatforms 含运行 GOOS 的（mcp.md §5.5 Windows 段）。
// 顺序与 List 一致按 Name 字母序。
func (r *Registry) Visible() []mcpdomain.RegistryEntry {
	all := r.List()
	out := make([]mcpdomain.RegistryEntry, 0, len(all))
	for _, e := range all {
		if e.Hidden {
			continue
		}
		if slices.Contains(e.UnsupportedPlatforms, runtime.GOOS) {
			continue
		}
		out = append(out, e)
	}
	return out
}
