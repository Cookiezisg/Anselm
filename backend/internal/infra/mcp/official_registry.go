// official_registry.go — production RegistrySource against the official
// MCP Registry at registry.modelcontextprotocol.io/v0.1/servers.
//
// Search-only model: the marketplace has 5000+ entries (still growing) so
// full-catalog walks were retired. All access goes through Search(query)
// which hits ?search=<query> server-side. Get(name) reuses recently-Searched
// entries via a 5-minute name cache, with a fallback search keyed off the
// name's last path segment when the cache misses.
//
// Multi-token queries: ?search= is a naive substring match on the upstream
// (so "web search" returns 0). We tokenize on whitespace and fetch each
// token, then union by canonical name. Acceptable cost for the typical 1-3
// keyword case; LLM tool prompts encourage short queries anyway.
//
// Schema adaptation:
//   - registry "packages[]" → Forgify single InstallCmd via priority
//     selection: npm (preferred — fast subprocess) > pypi > docker
//   - server.repository.url → RegistryEntry.Homepage
//   - server.version → RegistryEntry.Version (install pins to this)
//   - packageArguments → RequiredEnv + RequiredArgs split heuristically
//     by name (ALL_CAPS or contains underscore = env; otherwise arg)
//
// official_registry.go — 生产用 RegistrySource，搜索官方 MCP Registry
// （5000+ 条目）。仅 Search(query)，没有全量列出；Get 用 5min 短 cache +
// 按 name 末段 fallback search。多词 query 客户端拆词分别 fetch 后 union。
package mcp

import (
	"context"
	"encoding/json"
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
	// DefaultRegistryEndpoint 是公共官方 MCP Registry base URL。
	DefaultRegistryEndpoint = "https://registry.modelcontextprotocol.io/v0.1"

	// pageLimit caps results per ?search= request. 50 is enough for LLM
	// rerank to pick top-K without triggering pagination on common queries.
	//
	// pageLimit 限定每次 ?search= 返多少。50 足够给 LLM rerank 选 top-K，
	// 常见 query 不会触分页。
	pageLimit = 50

	// fetchTimeout caps each Search/Get round-trip.
	//
	// fetchTimeout 限定每次 Search/Get 来回。
	fetchTimeout = 30 * time.Second

	// cacheTTL is how long an entry persists in the name cache after being
	// returned by Search. 5 min covers the typical LLM "search → confirm →
	// install" turn without going stale.
	//
	// cacheTTL 是 Search 返条目在 name cache 的存活时间。5 分钟覆盖典型
	// "search → 确认 → install" turn 不会失效。
	cacheTTL = 5 * time.Minute
)

// OfficialRegistrySource implements mcpdomain.RegistrySource against the
// official registry HTTP API. Wired by main.go; tests use FakeRegistrySource
// to avoid network.
//
// OfficialRegistrySource 用官方 registry HTTP API 实现 RegistrySource。
// 测试改用 FakeRegistrySource 避网络。
type OfficialRegistrySource struct {
	endpoint string // registry base URL incl. /v0.1
	client   *http.Client
	log      *zap.Logger

	mu         sync.RWMutex
	nameCache  map[string]cachedEntry
}

type cachedEntry struct {
	entry mcpdomain.RegistryEntry
	at    time.Time
}

// NewOfficialRegistrySource constructs a source against the public registry.
// Pass "" for endpoint to use DefaultRegistryEndpoint; pass nil client for
// a 30s-timeout default. log is required (panics on nil).
//
// NewOfficialRegistrySource 构造对公共 registry 的 source。endpoint 传 ""
// 用 DefaultRegistryEndpoint；client 传 nil 用 30s 超时默认。log 必填。
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
		endpoint:  strings.TrimRight(endpoint, "/"),
		client:    client,
		log:       log.Named("mcp.registry"),
		nameCache: map[string]cachedEntry{},
	}
}

// Search returns entries matching query via the upstream's ?search= filter.
// Multi-word queries are tokenized; each token fetches one page (limit 50);
// results are unioned by canonical name. Returns ErrQueryRequired on empty
// input, ErrMarketplaceUnavailable on network failure.
//
// Search 经上游 ?search= 过滤返条目。多词 query 拆词分别 fetch 一页（50
// 上限），按规范 name union。空输入返 ErrQueryRequired，网络失败返
// ErrMarketplaceUnavailable。
func (o *OfficialRegistrySource) Search(ctx context.Context, query string) ([]mcpdomain.RegistryEntry, error) {
	tokens := tokenize(query)
	if len(tokens) == 0 {
		return nil, mcpdomain.ErrQueryRequired
	}

	ctx, cancel := context.WithTimeout(ctx, fetchTimeout)
	defer cancel()

	seen := map[string]mcpdomain.RegistryEntry{}
	for _, token := range tokens {
		page, err := o.fetchOnePage(ctx, token)
		if err != nil {
			return nil, fmt.Errorf("mcp.OfficialRegistrySource.Search: %w: %v",
				mcpdomain.ErrMarketplaceUnavailable, err)
		}
		for _, raw := range page {
			entry, ok := adaptOfficialServer(raw, o.log)
			if !ok {
				continue
			}
			if _, dup := seen[entry.Name]; !dup {
				seen[entry.Name] = entry
			}
		}
	}

	out := make([]mcpdomain.RegistryEntry, 0, len(seen))
	for _, e := range seen {
		out = append(out, e)
	}

	o.cachePut(out)

	o.log.Info("registry searched",
		zap.String("query", query),
		zap.Int("tokens", len(tokens)),
		zap.Int("matched", len(out)))
	return out, nil
}

// Get returns one entry by canonical name. Hits the short-lived cache
// populated by recent Search results; on miss falls back to a search keyed
// off the name's last path segment ("io.github.X/everything" → "everything").
// Returns ErrRegistryEntryNotFound when truly absent.
//
// Get 按规范 name 返单条。先击中由近期 Search 填的短 cache；miss 时按
// name 末段做 fallback search（"io.github.X/everything" → "everything"）。
// 真不可达返 ErrRegistryEntryNotFound。
func (o *OfficialRegistrySource) Get(ctx context.Context, name string) (*mcpdomain.RegistryEntry, error) {
	if e, ok := o.cacheGet(name); ok {
		return &e, nil
	}

	keyword := lastPathSegment(name)
	if keyword == "" {
		return nil, fmt.Errorf("mcp.OfficialRegistrySource.Get: %w: %q",
			mcpdomain.ErrRegistryEntryNotFound, name)
	}

	entries, err := o.Search(ctx, keyword)
	if err != nil {
		return nil, fmt.Errorf("mcp.OfficialRegistrySource.Get: %w", err)
	}
	for i := range entries {
		if entries[i].Name == name {
			cp := entries[i]
			return &cp, nil
		}
	}
	return nil, fmt.Errorf("mcp.OfficialRegistrySource.Get: %w: %q",
		mcpdomain.ErrRegistryEntryNotFound, name)
}

// fetchOnePage GETs /servers?search=<query>&limit=<pageLimit> and decodes.
//
// fetchOnePage GET /servers?search=<query>&limit=<pageLimit> 并解码。
func (o *OfficialRegistrySource) fetchOnePage(ctx context.Context, query string) ([]officialServerEntry, error) {
	u, err := url.Parse(o.endpoint + "/servers")
	if err != nil {
		return nil, fmt.Errorf("parse endpoint: %w", err)
	}
	q := u.Query()
	q.Set("limit", fmt.Sprint(pageLimit))
	q.Set("search", query)
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := o.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http get %s: %w", u.String(), err)
	}
	defer resp.Body.Close()

	if resp.StatusCode/100 != 2 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return nil, fmt.Errorf("http %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20)) // 8 MB sanity cap
	if err != nil {
		return nil, fmt.Errorf("read body: %w", err)
	}

	var env officialPageEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		return nil, fmt.Errorf("decode envelope: %w", err)
	}
	return env.Servers, nil
}

// ── name cache ───────────────────────────────────────────────────────

func (o *OfficialRegistrySource) cachePut(entries []mcpdomain.RegistryEntry) {
	now := time.Now()
	o.mu.Lock()
	defer o.mu.Unlock()
	for _, e := range entries {
		o.nameCache[e.Name] = cachedEntry{entry: e, at: now}
	}
	// Cheap lazy GC: drop expired entries when cache crosses 1000.
	// 廉价惰性 GC：cache 超 1000 时清过期。
	if len(o.nameCache) > 1000 {
		cutoff := now.Add(-cacheTTL)
		for k, v := range o.nameCache {
			if v.at.Before(cutoff) {
				delete(o.nameCache, k)
			}
		}
	}
}

func (o *OfficialRegistrySource) cacheGet(name string) (mcpdomain.RegistryEntry, bool) {
	o.mu.RLock()
	defer o.mu.RUnlock()
	c, ok := o.nameCache[name]
	if !ok {
		return mcpdomain.RegistryEntry{}, false
	}
	if time.Since(c.at) > cacheTTL {
		return mcpdomain.RegistryEntry{}, false
	}
	return c.entry, true
}

// ── helpers ──────────────────────────────────────────────────────────

// tokenize splits query on whitespace, dropping empties. Used to work
// around the upstream's naive substring match (multi-word phrases match
// nothing because slashes/spaces don't tokenize server-side).
//
// tokenize 按空白拆 query 丢空。绕开上游朴素子串匹配（多词不分词，斜杠
// 空格在 server 侧不切）。
func tokenize(query string) []string {
	var out []string
	for _, t := range strings.Fields(query) {
		t = strings.TrimSpace(t)
		if t != "" {
			out = append(out, t)
		}
	}
	return out
}

// lastPathSegment returns the substring after the final '/' in name,
// or the whole name when there's no '/'.
//
// lastPathSegment 返 name 中最后一个 '/' 之后的子串，无 '/' 时返整个。
func lastPathSegment(name string) string {
	if i := strings.LastIndex(name, "/"); i >= 0 && i < len(name)-1 {
		return name[i+1:]
	}
	return name
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
// Fields not consumed by Forgify (e.g. _meta, remotes) are absent —
// encoding/json silently drops unknown fields. Note packages is nested
// INSIDE server (not at the top level) per the v0.1 schema.
//
// officialServerEntry 镜像官方 registry 返的单条目。packages 嵌在 server
// 里（不是顶层），这是 v0.1 schema 的真实形状——之前放顶层是 bug，所有
// 条目都被 adapter 丢了。
type officialServerEntry struct {
	Server struct {
		Name        string `json:"name"` // io.github.<user>/<server>
		Description string `json:"description"`
		Repository  struct {
			URL       string `json:"url"`
			Subfolder string `json:"subfolder,omitempty"`
		} `json:"repository"`
		Version  string            `json:"version"`
		Packages []officialPackage `json:"packages,omitempty"` // installable packages
	} `json:"server"`
}

// officialPackage is one installable package for a server. v0.1 schema:
// transport is {"type":"stdio"|"sse"|"streamable-http"}; only stdio is
// installable as a Forgify subprocess. environmentVariables hold env
// requirements; packageArguments + runtimeArguments hold CLI args.
//
// officialPackage 是 server 的一个可装包。v0.1 schema：transport 是 object；
// 仅 stdio 可作 Forgify 子进程；environmentVariables 是 env 需求；
// packageArguments + runtimeArguments 是 CLI args。
type officialPackage struct {
	RegistryType         string             `json:"registryType"`
	Identifier           string             `json:"identifier"`
	Version              string             `json:"version,omitempty"`
	Transport            officialTransport  `json:"transport"`
	EnvironmentVariables []officialEnvVar   `json:"environmentVariables,omitempty"`
	PackageArguments     []officialArg      `json:"packageArguments,omitempty"`
	RuntimeArguments     []officialArg      `json:"runtimeArguments,omitempty"`
}

// officialTransport describes how the server speaks MCP. Only "stdio" is
// installable as a Forgify subprocess; sse / streamable-http are remote
// endpoints (not handled).
//
// officialTransport 描述 server 的 MCP 通讯方式。仅 stdio 可作 Forgify
// 子进程；sse / streamable-http 是远端端点（暂不处理）。
type officialTransport struct {
	Type string `json:"type"` // stdio / sse / streamable-http
}

// officialEnvVar is one env-var requirement on a package.
//
// officialEnvVar 是 package 的一个 env 变量需求。
type officialEnvVar struct {
	Name        string `json:"name"`
	Description string `json:"description,omitempty"`
	IsRequired  bool   `json:"isRequired,omitempty"`
	IsSecret    bool   `json:"isSecret,omitempty"`
	Format      string `json:"format,omitempty"`
	Default     string `json:"default,omitempty"`
}

// officialArg is one CLI arg requirement (packageArguments or
// runtimeArguments). Name is optional (positional args lack one); Value
// is the default.
//
// officialArg 是一个 CLI arg 需求。Name 可选（位置 arg 无名）；Value 是默认。
type officialArg struct {
	Name        string `json:"name,omitempty"`
	Description string `json:"description,omitempty"`
	Value       string `json:"value,omitempty"`
	ValueHint   string `json:"valueHint,omitempty"`
	Format      string `json:"format,omitempty"`
	IsRequired  bool   `json:"isRequired,omitempty"`
}

// ── Adapter ──────────────────────────────────────────────────────────

// adaptOfficialServer converts one registry server entry into Forgify's
// internal RegistryEntry. Returns (entry, true) on success; (zero, false)
// when no Forgify-supported runtime is found in packages[].
//
// adaptOfficialServer 转换条目；packages[] 无支持 runtime 返 (zero, false)。
func adaptOfficialServer(raw officialServerEntry, log *zap.Logger) (mcpdomain.RegistryEntry, bool) {
	if raw.Server.Name == "" {
		log.Debug("registry entry skipped: empty server.name")
		return mcpdomain.RegistryEntry{}, false
	}

	pkg, runtime, ok := pickPackage(raw.Server.Packages)
	if !ok {
		// Many registry entries are "remote-only" (streamable-http URLs) and
		// have no installable packages. We silently skip them — Forgify's
		// install flow currently only supports npm/pypi/docker subprocesses.
		// 很多条目是 remote-only（streamable-http URL），无可装 package。
		// Forgify 当前 install 流仅支持 npm/pypi/docker 子进程，静默跳过。
		log.Debug("registry entry skipped: no supported package",
			zap.String("name", raw.Server.Name))
		return mcpdomain.RegistryEntry{}, false
	}

	envReqs := collectEnvRequirements(pkg.EnvironmentVariables)
	argReqs := collectArgRequirements(pkg.PackageArguments, pkg.RuntimeArguments)

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
// Priority: npm > pypi > docker. Only "stdio" transport is considered —
// sse / streamable-http packages are remote endpoints not installable
// as subprocesses.
//
// pickPackage 选偏好 package + 映射 runtime。优先级：npm > pypi > docker。
// 仅 stdio transport——sse / streamable-http 是远端端点不可作子进程装。
func pickPackage(pkgs []officialPackage) (officialPackage, string, bool) {
	var npmPkg, pypiPkg, dockerPkg *officialPackage
	for i := range pkgs {
		p := &pkgs[i]
		if p.Transport.Type != "" && p.Transport.Type != "stdio" {
			continue
		}
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

// buildInstallCmd assembles InstallCmd from a chosen package. The v0.1
// schema doesn't carry a runtimeHint, so the command is derived from
// registryType: npm → npx, pypi → uvx, oci/docker → docker. Identifier is
// pinned to a specific version when package.version is set.
//
// buildInstallCmd 从选中 package 装配 InstallCmd。v0.1 schema 无 runtimeHint，
// 命令按 registryType 推：npm→npx，pypi→uvx，oci/docker→docker。
// package.version 非空时 identifier 钉版本。
func buildInstallCmd(pkg officialPackage) mcpdomain.InstallCmd {
	identifier := pkg.Identifier
	if pkg.Version != "" && !strings.Contains(identifier, "@") && !strings.Contains(identifier, ":") {
		// npm/pypi: append @version; docker: would be tag (handled below).
		// npm/pypi：追加 @version；docker tag 在下方处理。
		identifier = identifier + "@" + pkg.Version
	}
	switch strings.ToLower(pkg.RegistryType) {
	case "npm":
		return mcpdomain.InstallCmd{
			Command: "npx",
			Args:    []string{"-y", identifier},
		}
	case "pypi":
		return mcpdomain.InstallCmd{
			Command: "uvx",
			Args:    []string{identifier},
		}
	case "oci", "docker":
		// docker images already include tag in identifier (e.g. "image:1.0.0").
		// docker image identifier 已含 tag。
		return mcpdomain.InstallCmd{
			Command: "docker",
			Args:    []string{pkg.Identifier},
		}
	}
	return mcpdomain.InstallCmd{}
}

// collectEnvRequirements maps required environmentVariables to Forgify
// EnvRequirement. Optional vars are dropped (Forgify only surfaces what
// the user MUST supply at install).
//
// collectEnvRequirements 把 isRequired=true 的 environmentVariables 映射到
// EnvRequirement。可选变量跳过——install 表单只展示必填。
func collectEnvRequirements(envs []officialEnvVar) []mcpdomain.EnvRequirement {
	var out []mcpdomain.EnvRequirement
	for _, e := range envs {
		if !e.IsRequired || e.Name == "" {
			continue
		}
		out = append(out, mcpdomain.EnvRequirement{
			Name:        e.Name,
			Description: e.Description,
			Secret:      e.IsSecret,
		})
	}
	return out
}

// collectArgRequirements unions packageArguments + runtimeArguments and
// keeps only required, named entries (positional args without names can't
// be substituted via "${name}" tokens, so they're skipped).
//
// collectArgRequirements 合并 packageArguments + runtimeArguments，仅留
// required 且有名的（无名位置 arg 无法用 "${name}" 替换，跳过）。
func collectArgRequirements(pkgArgs, rtArgs []officialArg) []mcpdomain.ArgRequirement {
	var out []mcpdomain.ArgRequirement
	for _, a := range append(append([]officialArg(nil), pkgArgs...), rtArgs...) {
		if !a.IsRequired || a.Name == "" {
			continue
		}
		out = append(out, mcpdomain.ArgRequirement{
			Name:        a.Name,
			Description: a.Description,
			Type:        a.Format,
			Default:     a.Value,
		})
	}
	return out
}

// Compile-time check that OfficialRegistrySource satisfies the port.
//
// 编译期检查 OfficialRegistrySource 满足端口。
var _ mcpdomain.RegistrySource = (*OfficialRegistrySource)(nil)
