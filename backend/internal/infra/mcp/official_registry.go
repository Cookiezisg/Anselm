// official_registry.go — production RegistrySource that fetches the
// official MCP Registry at registry.modelcontextprotocol.io/v0.1/servers.
// Cursor-paginated full-catalog crawl on first List() (~1-15s depending
// on registry size); subsequent calls return from process memory until
// Refresh() is invoked or the process restarts.
//
// Schema adaptation:
//   - registry "packages[]" → Forgify single InstallCmd via priority
//     selection: npm (preferred — fast subprocess) > pypi > docker
//   - server.repository.url → RegistryEntry.Homepage
//   - server.version → RegistryEntry.Version (install pins to this)
//   - packageArguments → RequiredEnv + RequiredArgs split heuristically
//     by name (ALL_CAPS or contains underscore = env; otherwise arg)
//
// Failure model: on first List() with no cache, fetch failure returns
// ErrMarketplaceUnavailable. Once a cache exists, subsequent List() calls
// always serve from cache; Refresh() failure leaves the prior cache intact.
//
// official_registry.go ——生产用 RegistrySource，fetch 官方 MCP Registry
// （registry.modelcontextprotocol.io/v0.1/servers）。首次 List() cursor 分页全量
// 拉（~1-15s 取决于 registry 大小）；后续从进程内存返直到 Refresh() 或重启。
//
// Schema 适配：registry packages[] → Forgify 单 InstallCmd 按优先级选
// （npm > pypi > docker）；server.repository.url → Homepage；server.version →
// Version；packageArguments 按 name 启发拆 RequiredEnv + RequiredArgs。
//
// 失败模型：首次 List() 无缓存时 fetch 失败返 ErrMarketplaceUnavailable。
// 缓存存在后 List() 永远从缓存返；Refresh() 失败时旧缓存不变。
package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

const (
	// DefaultRegistryEndpoint is the public official MCP Registry base URL.
	// V0.1 is in "API freeze" but still preview — pin the version path
	// so a future v1 launch doesn't silently break adapters.
	//
	// DefaultRegistryEndpoint 是公共官方 MCP Registry base URL。V0.1 处 API
	// freeze 但仍 preview——版本路径钉死防未来 v1 上线时静默破适配器。
	DefaultRegistryEndpoint = "https://registry.modelcontextprotocol.io/v0.1"

	// pageLimit is the per-page fetch size requested. 50 is a balance:
	// fewer round-trips than 20 (default) on big catalogs, small enough
	// that one bad page doesn't waste lots of bandwidth.
	//
	// pageLimit 每页请求的 fetch 大小。50 是平衡：大目录上比默认 20 少几次
	// 来回，但够小让单页坏不浪费太多带宽。
	pageLimit = 50

	// fetchTimeout caps the overall List() / Refresh() walk. A ~500-entry
	// catalog should complete well within this budget.
	//
	// fetchTimeout 限定 List() / Refresh() 整体走查。~500 条目录应远在此预算内完成。
	fetchTimeout = 30 * time.Second
)

// OfficialRegistrySource implements mcpdomain.RegistrySource against the
// official registry HTTP API. Wired by main.go; tests use FakeRegistrySource
// (fake_registry.go) instead so unit + integration runs avoid network.
//
// OfficialRegistrySource 用官方 registry HTTP API 实现 mcpdomain.RegistrySource。
// main.go 接；测试改用 FakeRegistrySource（fake_registry.go），让单元 + 集成
// 跑不发网络。
type OfficialRegistrySource struct {
	endpoint string // registry base URL incl. /v0.1
	client   *http.Client
	log      *zap.Logger

	// mu guards entries (the cached catalog). entries==nil means "never
	// fetched" (next List triggers fetch); non-nil entries (even empty
	// slice) means "fetched at least once" (subsequent List returns it).
	//
	// mu 守护 entries（缓存目录）。entries==nil 表示"从未 fetch"（下次 List
	// 触发 fetch）；非 nil entries（即便空 slice）表示"至少 fetch 过一次"
	// （后续 List 直接返）。
	mu      sync.RWMutex
	entries []mcpdomain.RegistryEntry
}

// NewOfficialRegistrySource constructs a source against the public registry.
// Pass "" for endpoint to use DefaultRegistryEndpoint; pass nil client for
// a 30s-timeout default. log is required (panics on nil).
//
// NewOfficialRegistrySource 构造对公共 registry 的 source。endpoint 传 ""
// 用 DefaultRegistryEndpoint；client 传 nil 用 30s 超时默认。log 必填
// （nil panic）。
func NewOfficialRegistrySource(endpoint string, client *http.Client, log *zap.Logger) *OfficialRegistrySource {
	if log == nil {
		panic("mcp.NewOfficialRegistrySource: nil logger")
	}
	if endpoint == "" {
		endpoint = DefaultRegistryEndpoint
	}
	if client == nil {
		client = &http.Client{Timeout: fetchTimeout}
	}
	return &OfficialRegistrySource{
		endpoint: strings.TrimRight(endpoint, "/"),
		client:   client,
		log:      log.Named("mcp.registry"),
	}
}

// List returns the cached catalog. First call (or after Refresh dropped
// the cache) blocks on fetch + adaptation. Returns
// ErrMarketplaceUnavailable when the fetch fails AND no cache exists.
//
// List 返缓存目录。首次（或 Refresh 弃缓存后）阻塞 fetch + 适配。fetch 失败
// 且无缓存返 ErrMarketplaceUnavailable。
func (o *OfficialRegistrySource) List(ctx context.Context) ([]mcpdomain.RegistryEntry, error) {
	o.mu.RLock()
	cached := o.entries
	o.mu.RUnlock()
	if cached != nil {
		out := make([]mcpdomain.RegistryEntry, len(cached))
		copy(out, cached)
		return out, nil
	}
	return o.fetchAndCache(ctx)
}

// Get returns one entry by canonical name. Triggers a fetch on first call
// (same as List). Returns ErrRegistryEntryNotFound when name is absent.
//
// Get 按 canonical name 返单个条目。首次调用触发 fetch（同 List）。
// name 不存在返 ErrRegistryEntryNotFound。
func (o *OfficialRegistrySource) Get(ctx context.Context, name string) (*mcpdomain.RegistryEntry, error) {
	entries, err := o.List(ctx)
	if err != nil {
		return nil, err
	}
	for i := range entries {
		if entries[i].Name == name {
			cp := entries[i]
			return &cp, nil
		}
	}
	return nil, fmt.Errorf("mcp.OfficialRegistrySource.Get: %w: %q", mcpdomain.ErrRegistryEntryNotFound, name)
}

// Refresh forces a re-fetch + cache replacement. On failure, keeps the
// existing cache (if any) so partial-network conditions don't degrade
// service. Logs the failure.
//
// Refresh 强制 re-fetch + 替换缓存。失败时保留现有缓存（如有），让局部网络
// 故障不退化服务。失败 log。
func (o *OfficialRegistrySource) Refresh(ctx context.Context) error {
	_, err := o.fetchAndCache(ctx)
	return err
}

// fetchAndCache walks the registry's cursor-paginated /servers endpoint,
// adapts each entry, and atomically replaces the cache. Returns the new
// (or same-as-cached on error) entry list.
//
// fetchAndCache 走 registry cursor 分页 /servers 端点，适配每条目，原子替换缓存。
// 返新（错时返同缓存）entry 列表。
func (o *OfficialRegistrySource) fetchAndCache(ctx context.Context) ([]mcpdomain.RegistryEntry, error) {
	all, fetchErr := o.fetchAllPages(ctx)
	if fetchErr != nil {
		// On error: if we have any prior cache, return that (degraded
		// mode); else surface ErrMarketplaceUnavailable so caller can
		// decide (LLM tool returns clear message; HTTP handler returns 422).
		// 错时：有旧缓存返之（降级）；否则返 ErrMarketplaceUnavailable 让
		// 调用方决定（LLM 工具返清晰消息；HTTP handler 返 422）。
		o.mu.RLock()
		cached := o.entries
		o.mu.RUnlock()
		if cached != nil {
			o.log.Warn("registry fetch failed; serving prior cache", zap.Error(fetchErr))
			out := make([]mcpdomain.RegistryEntry, len(cached))
			copy(out, cached)
			return out, nil
		}
		return nil, fmt.Errorf("mcp.OfficialRegistrySource.fetchAndCache: %w: %v",
			mcpdomain.ErrMarketplaceUnavailable, fetchErr)
	}

	adapted := make([]mcpdomain.RegistryEntry, 0, len(all))
	for _, raw := range all {
		entry, ok := adaptOfficialServer(raw, o.log)
		if !ok {
			continue // schema didn't match; logged inside adapter
		}
		adapted = append(adapted, entry)
	}

	o.mu.Lock()
	o.entries = adapted
	o.mu.Unlock()

	o.log.Info("registry fetched + cached",
		zap.Int("rawCount", len(all)),
		zap.Int("adaptedCount", len(adapted)))

	out := make([]mcpdomain.RegistryEntry, len(adapted))
	copy(out, adapted)
	return out, nil
}

// fetchAllPages walks the cursor-paginated /servers endpoint until
// nextCursor is empty.
//
// fetchAllPages 走 cursor 分页 /servers 直到 nextCursor 空。
func (o *OfficialRegistrySource) fetchAllPages(ctx context.Context) ([]officialServerEntry, error) {
	ctx, cancel := context.WithTimeout(ctx, fetchTimeout)
	defer cancel()

	var (
		all    []officialServerEntry
		cursor string
	)
	for {
		page, next, err := o.fetchOnePage(ctx, cursor)
		if err != nil {
			return nil, err
		}
		all = append(all, page...)
		if next == "" {
			break
		}
		cursor = next
		// Loose safety cap — any well-formed registry should converge.
		// Also catches a hypothetical pagination bug where nextCursor
		// keeps returning a non-empty value indefinitely.
		// 松散安全 cap——任何良构 registry 应收敛。也兜住假想分页 bug 让
		// nextCursor 永远返非空。
		if len(all) > 5000 {
			return nil, fmt.Errorf("page walk exceeded 5000 entries — registry pagination loop?")
		}
	}
	return all, nil
}

// fetchOnePage GETs one cursor-paginated page and decodes the envelope.
//
// fetchOnePage GET 一个 cursor 分页页 + 解码 envelope。
func (o *OfficialRegistrySource) fetchOnePage(ctx context.Context, cursor string) ([]officialServerEntry, string, error) {
	u, err := url.Parse(o.endpoint + "/servers")
	if err != nil {
		return nil, "", fmt.Errorf("parse endpoint: %w", err)
	}
	q := u.Query()
	q.Set("limit", fmt.Sprint(pageLimit))
	if cursor != "" {
		q.Set("cursor", cursor)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, "", fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := o.client.Do(req)
	if err != nil {
		return nil, "", fmt.Errorf("http get %s: %w", u.String(), err)
	}
	defer resp.Body.Close()

	if resp.StatusCode/100 != 2 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, "", fmt.Errorf("http %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20)) // 8 MB sanity cap per page
	if err != nil {
		return nil, "", fmt.Errorf("read body: %w", err)
	}

	var env officialPageEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		return nil, "", fmt.Errorf("decode envelope: %w", err)
	}
	return env.Servers, env.Metadata.NextCursor, nil
}

// ── Wire shapes (official registry v0.1) ─────────────────────────────

// officialPageEnvelope wraps one page of /servers response.
//
// officialPageEnvelope 包 /servers 一页响应。
type officialPageEnvelope struct {
	Servers  []officialServerEntry `json:"servers"`
	Metadata struct {
		NextCursor string `json:"nextCursor"`
	} `json:"metadata"`
}

// officialServerEntry mirrors one entry as returned by the official registry.
// Fields not consumed by Forgify (e.g. _meta) are absent — encoding/json
// silently drops unknown fields, so adding fields here later is safe.
//
// officialServerEntry 镜像官方 registry 返的单条目。Forgify 不消费的字段（如
// _meta）省略——encoding/json 静默丢未知字段，将来加字段安全。
type officialServerEntry struct {
	Server struct {
		Name        string `json:"name"`        // io.github.<user>/<server>
		Description string `json:"description"`
		Repository  struct {
			URL       string `json:"url"`
			Subfolder string `json:"subfolder,omitempty"`
		} `json:"repository"`
		Version string `json:"version"`
	} `json:"server"`
	Packages []officialPackage `json:"packages"`
}

// officialPackage describes one of multiple install options for a server
// (e.g. an entry might publish both an npm and a pypi package).
//
// officialPackage 描述一个 server 的多种安装选项之一（如条目可能同时发 npm
// 和 pypi 两包）。
type officialPackage struct {
	RegistryType    string                  `json:"registryType"` // npm / pypi / oci / ...
	Identifier      string                  `json:"identifier"`   // package name or image ref
	Transport       string                  `json:"transport"`    // stdio / sse / streamable-http
	RuntimeHint     string                  `json:"runtimeHint"`  // npx / uvx / docker / ...
	PackageArguments []officialPackageArgument `json:"packageArguments,omitempty"`
}

// officialPackageArgument is the registry's unified "thing the user must
// supply" — covers both env vars and CLI args. Forgify splits them
// heuristically by name (uppercase-with-underscore = env) since the
// registry doesn't carry an explicit type discriminator.
//
// officialPackageArgument 是 registry 统一的"用户必须提供"——同时覆盖 env vars
// 与 CLI args。Forgify 按 name 启发拆分（大写+下划线 = env）因为 registry 不
// 带显式 type 区分符。
type officialPackageArgument struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Format      string `json:"format,omitempty"` // string / path / url / etc.
	Required    bool   `json:"required"`
	Default     string `json:"default,omitempty"`
}

// ── Adapter ──────────────────────────────────────────────────────────

// adaptOfficialServer converts one registry server entry into Forgify's
// internal RegistryEntry. Returns (entry, true) on success; (zero, false)
// when no Forgify-supported runtime is found in packages[] (logged at debug).
// Skipping bad entries silently is the right move for community catalogs
// where occasional malformed publishes are normal.
//
// adaptOfficialServer 把单条 registry server entry 转 Forgify 内部 RegistryEntry。
// 成功返 (entry, true)；packages[] 无 Forgify 支持的 runtime 返 (zero, false)
// （debug log）。社区目录偶有畸形发布属正常，静默跳过坏条目是对的。
func adaptOfficialServer(raw officialServerEntry, log *zap.Logger) (mcpdomain.RegistryEntry, bool) {
	if raw.Server.Name == "" {
		log.Debug("registry entry skipped: empty server.name")
		return mcpdomain.RegistryEntry{}, false
	}

	pkg, runtime, ok := pickPackage(raw.Packages)
	if !ok {
		log.Debug("registry entry skipped: no supported runtime in packages",
			zap.String("name", raw.Server.Name))
		return mcpdomain.RegistryEntry{}, false
	}

	envReqs, argReqs := splitArguments(pkg.PackageArguments)

	display := raw.Server.Name
	if last := strings.LastIndex(display, "/"); last >= 0 && last < len(display)-1 {
		display = display[last+1:]
	}

	return mcpdomain.RegistryEntry{
		Name:         raw.Server.Name,
		DisplayName:  display,
		Description:  raw.Server.Description,
		Homepage:     raw.Server.Repository.URL,
		Runtime:      runtime,
		Version:      raw.Server.Version,
		InstallCmd:   buildInstallCmd(pkg),
		RequiredEnv:  envReqs,
		RequiredArgs: argReqs,
	}, true
}

// pickPackage selects the preferred package + maps to a Forgify runtime.
// Priority: npm (preferred — npx fast subprocess) > pypi (uvx) > docker.
// Returns (pkg, runtime-tag, ok); ok=false when no supported package exists.
//
// pickPackage 选偏好 package + 映射到 Forgify runtime。优先级：npm > pypi > docker。
// 返 (pkg, runtime-tag, ok)；无支持 package 返 ok=false。
func pickPackage(pkgs []officialPackage) (officialPackage, string, bool) {
	var npmPkg, pypiPkg, dockerPkg *officialPackage
	for i := range pkgs {
		p := &pkgs[i]
		switch strings.ToLower(p.RegistryType) {
		case "npm":
			if npmPkg == nil {
				npmPkg = p
			}
		case "pypi":
			if pypiPkg == nil {
				pypiPkg = p
			}
		case "oci", "docker":
			if dockerPkg == nil {
				dockerPkg = p
			}
		}
	}
	switch {
	case npmPkg != nil:
		return *npmPkg, "node", true
	case pypiPkg != nil:
		return *pypiPkg, "python", true
	case dockerPkg != nil:
		return *dockerPkg, "docker", true
	}
	return officialPackage{}, "", false
}

// buildInstallCmd assembles the InstallCmd from a chosen package. For
// npm: uses runtimeHint (typically "npx") + ["-y", identifier]. For pypi:
// uses runtimeHint (typically "uvx") + [identifier]. For docker: returns
// just the image identifier as Args[0] — the marketplace adapter (in
// app/mcp install path) wraps this with `docker run -i --rm -v ... -e ...`
// via sandbox.BuildDockerRunArgs at install time.
//
// buildInstallCmd 从选中 package 装配 InstallCmd。npm：用 runtimeHint（典型
// "npx"）+ ["-y", identifier]。pypi：runtimeHint（典型 "uvx"）+ [identifier]。
// docker：仅把 image identifier 当 Args[0] —— marketplace adapter（在 app/mcp
// install 路径）经 sandbox.BuildDockerRunArgs 在 install 时套 `docker run -i
// --rm -v ... -e ...`。
func buildInstallCmd(pkg officialPackage) mcpdomain.InstallCmd {
	switch strings.ToLower(pkg.RegistryType) {
	case "npm":
		runtimeHint := pkg.RuntimeHint
		if runtimeHint == "" {
			runtimeHint = "npx"
		}
		return mcpdomain.InstallCmd{
			Command: runtimeHint,
			Args:    []string{"-y", pkg.Identifier},
		}
	case "pypi":
		runtimeHint := pkg.RuntimeHint
		if runtimeHint == "" {
			runtimeHint = "uvx"
		}
		return mcpdomain.InstallCmd{
			Command: runtimeHint,
			Args:    []string{pkg.Identifier},
		}
	case "oci", "docker":
		// For docker, Args[0] is the image — the actual `docker run -i
		// --rm ...` pattern is built later by the install path using
		// sandbox.BuildDockerRunArgs (so envPath + user env can be injected).
		// docker：Args[0] 是 image —— 真正 `docker run -i --rm ...` 模式由 install
		// 路径用 sandbox.BuildDockerRunArgs 拼（让 envPath + 用户 env 能注入）。
		return mcpdomain.InstallCmd{
			Command: "docker",
			Args:    []string{pkg.Identifier},
		}
	}
	// Defensive — shouldn't reach here since pickPackage filters first.
	// 防御——pickPackage 先过滤了，不该到这。
	return mcpdomain.InstallCmd{}
}

// splitArguments separates packageArguments into env requirements vs
// CLI arg requirements by naming convention: ALL_CAPS_WITH_UNDERSCORES =
// env (matches the standard convention for env vars); everything else is
// treated as a CLI arg. Imperfect but handles the common case.
//
// splitArguments 按命名约定把 packageArguments 拆成 env vs CLI arg：
// ALL_CAPS_WITH_UNDERSCORES = env（标准 env vars 约定）；其他当 CLI arg。
// 不完美但覆盖常见情况。
func splitArguments(args []officialPackageArgument) (envReqs []mcpdomain.EnvRequirement, argReqs []mcpdomain.ArgRequirement) {
	for _, a := range args {
		if !a.Required {
			continue
		}
		if isEnvName(a.Name) {
			envReqs = append(envReqs, mcpdomain.EnvRequirement{
				Name:        a.Name,
				Description: a.Description,
			})
		} else {
			argReqs = append(argReqs, mcpdomain.ArgRequirement{
				Name:        a.Name,
				Description: a.Description,
				Type:        a.Format,
				Default:     a.Default,
			})
		}
	}
	return envReqs, argReqs
}

// isEnvName returns true when name looks like an env-var convention
// identifier — all uppercase letters/digits with underscores allowed,
// starting with a letter.
//
// isEnvName 判断 name 是否符合 env-var 约定标识符——全大写字母/数字 + 允许
// 下划线，以字母开头。
func isEnvName(name string) bool {
	if name == "" {
		return false
	}
	if !(name[0] >= 'A' && name[0] <= 'Z') {
		return false
	}
	for _, r := range name {
		switch {
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '_':
		default:
			return false
		}
	}
	return true
}

// Compile-time check that OfficialRegistrySource satisfies the port.
//
// 编译期检查 OfficialRegistrySource 满足端口。
var _ mcpdomain.RegistrySource = (*OfficialRegistrySource)(nil)

// errNop avoids "imported and not used" if errors gets dropped during
// future refactors; harmless at runtime.
//
// errNop 防 "imported and not used"；运行时无害。
var _ = errors.New
