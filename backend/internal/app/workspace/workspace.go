// Package workspace owns the workspace CRUD service — the local isolation root's
// lifecycle. It validates names, guards the last workspace, and answers the auth
// middleware's WorkspaceResolver port (Validate).
//
// Package workspace 持有 workspace CRUD service——本地隔离根的生命周期。校验名字、守最后一个
// workspace、应答 auth 中间件的 WorkspaceResolver 端口（Validate）。
package workspace

import (
	"context"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"go.uber.org/zap"

	modelrefapp "github.com/sunweilin/anselm/backend/internal/app/modelref"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	websearchdomain "github.com/sunweilin/anselm/backend/internal/domain/websearch"
	workspacedomain "github.com/sunweilin/anselm/backend/internal/domain/workspace"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// Service orchestrates Workspace CRUD.
//
// Service 编排 Workspace CRUD。
type Service struct {
	repo workspacedomain.Repository
	log  *zap.Logger

	// reaper tears down a workspace's runtime + files before the row is deleted (cascade
	// destroy — kill automation, stop resident processes, remove the file tree).
	// Injected post-build by bootstrap (it alone sees every service); nil → row-delete only.
	//
	// reaper 在删行前拆掉 workspace 的运行时与文件（级联销毁——杀自动化、停常驻
	// 进程、删文件树）。bootstrap 后注入（只有它看得到全部 service）；nil → 仅删行。
	reaper Reaper

	// onCreated runs just after a new workspace row is saved (e.g. provision the free-tier
	// credential). Injected post-build by bootstrap; nil → skipped. Best-effort by contract: it
	// returns nothing (can never fail Create) and the registered hook must not block — slow work
	// (e.g. a gateway call) is offloaded to its own goroutine.
	//
	// onCreated 在新 workspace 行存好后即跑（如开通免费档凭证）。bootstrap 后注入；nil → 跳过。契约上
	// best-effort：不返回任何东西（绝不会让 Create 失败），注册的钩子不得阻塞——慢活（如网关调用）自行
	// 丢进 goroutine。
	onCreated CreatedHook

	// keyChecker is the optional apikey existence hook (apikeyapp, injected post-build): SetDefault
	// rejects a scenario default pointing at a non-existent apiKeyId at write time (API_KEY_NOT_FOUND).
	// Symmetric with ReferencesAPIKey, which already blocks DELETING a key a default points at — both
	// directions now consistent. nil → existence check skipped. (F153)
	//
	// keyChecker 是可选 apikey 存在性钩子（apikeyapp，后注入）：SetDefault 在写时拒绝指向不存在 apiKeyId 的
	// scenario 默认（API_KEY_NOT_FOUND）。与 ReferencesAPIKey（已挡删被默认引用的 key）对称——两向现一致。
	// nil → 跳过存在性校验。（F153）
	keyChecker modelrefapp.KeyExistenceChecker

	// Stats ports (bootstrap, post-build; both optional — nil degrades honestly): blobSizer walks
	// the workspace file tree under a time budget; generating snapshots chat's in-flight ids.
	// stats 端口(bootstrap 后注入,皆可选、nil 诚实退化):blobSizer 带预算走文件树;generating 快照
	// chat 在飞会话 id。
	blobSizer  BlobSizer
	generating GeneratingLister
}

// BlobSizer sums one workspace's stored blob bytes (ctx carries the workspace + the deadline).
// BlobSizer 求一个 workspace 的 blob 总字节(ctx 带 workspace 与 deadline)。
type BlobSizer interface {
	TotalBytes(ctx context.Context) (int64, error)
}

// GeneratingLister snapshots the conversation ids with an in-flight assistant turn (chatapp).
// GeneratingLister 快照在飞 assistant 回合的会话 id(chatapp)。
type GeneratingLister func() []string

// SetStatsPorts injects the stats dependencies (bootstrap, post-build).
//
// SetStatsPorts 注入 stats 依赖(bootstrap 后注入)。
func (s *Service) SetStatsPorts(b BlobSizer, g GeneratingLister) {
	s.blobSizer = b
	s.generating = g
}

// Reaper destroys everything a workspace owns beyond its row: in-flight runs, trigger
// listeners, resident handler/mcp processes, and the on-disk file tree. Best-effort by
// contract — a partially failed reap still proceeds to the row delete (the row's absence
// is what makes the data unreachable and the background seeding skip it).
//
// Reaper 销毁 workspace 行之外的一切所有物：在途 run、trigger 监听、常驻 handler/mcp 进程、
// 盘上文件树。契约上 best-effort——部分失败仍继续删行（行的消失才是数据不可达、后台播种
// 跳过它的根因）。
type Reaper func(ctx context.Context, workspaceID string)

// SetReaper injects the cascade-destroy hook (bootstrap, post-build).
//
// SetReaper 注入级联销毁钩子（bootstrap 后注入）。
func (s *Service) SetReaper(r Reaper) { s.reaper = r }

// CreatedHook runs after a workspace is created (post-Save). Best-effort and non-blocking — it
// returns nothing (cannot fail Create) and must offload slow work to its own goroutine.
//
// CreatedHook 在 workspace 创建后（Save 后）跑。best-effort 且非阻塞——不返回任何东西（不能让 Create
// 失败），慢活须自行丢 goroutine。
type CreatedHook func(ctx context.Context, workspaceID string)

// SetOnCreated injects the post-create hook (bootstrap, post-build).
//
// SetOnCreated 注入创建后钩子（bootstrap 后注入）。
func (s *Service) SetOnCreated(h CreatedHook) { s.onCreated = h }

// SetKeyChecker installs the apikey existence probe post-construction (apikeyapp; no cycle — apikey
// depends on none of workspace/agent/conversation). Enables SetDefault to reject a scenario default
// pointing at a non-existent apiKeyId at write time (F153). nil → existence check skipped.
//
// SetKeyChecker 装配后注入 apikey 存在性探针（apikeyapp；无环）。使 SetDefault 在写时拒绝指向不存在
// apiKeyId 的 scenario 默认（F153）。nil → 跳过存在性校验。
func (s *Service) SetKeyChecker(c modelrefapp.KeyExistenceChecker) { s.keyChecker = c }

// NewService wires dependencies; panics on nil logger.
//
// NewService 装配依赖；nil logger panic。
func NewService(repo workspacedomain.Repository, log *zap.Logger) *Service {
	if log == nil {
		panic("workspace.NewService: logger is nil")
	}
	return &Service{repo: repo, log: log.Named("workspaceapp")}
}

// CreateInput is the validated payload for Create.
//
// CreateInput 是 Create 的校验载荷。
type CreateInput struct {
	Name        string
	AvatarColor string
	Language    string // optional; defaults to zh-CN
}

// UpdateInput is the partial-update payload; nil fields are skipped.
//
// UpdateInput 是部分更新载荷；nil 字段跳过。
type UpdateInput struct {
	Name         *string
	AvatarColor  *string
	Language     *string
	WebFetchMode *string // "local" | "jina"
}

// Create makes a new workspace; name is required and length-bounded, language
// defaults to zh-CN. A duplicate name surfaces ErrNameConflict from the store.
//
// Create 创建新 workspace；name 必填限长，language 默认 zh-CN。重名由 store 冒泡 ErrNameConflict。
func (s *Service) Create(ctx context.Context, in CreateInput) (*workspacedomain.Workspace, error) {
	name, err := cleanName(in.Name)
	if err != nil {
		return nil, err
	}
	lang, err := resolveLanguage(in.Language)
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	w := &workspacedomain.Workspace{
		ID:          idgenpkg.New("ws"),
		Name:        name,
		AvatarColor: strings.TrimSpace(in.AvatarColor),
		Language:    lang,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if err := s.repo.Save(ctx, w); err != nil {
		return nil, err
	}
	s.log.Info("workspace created", zap.String("workspace_id", w.ID), zap.String("name", w.Name))
	// Post-create hook (e.g. free-tier provisioning). Best-effort + non-blocking by contract, so a
	// failing/slow hook can't break onboarding.
	//
	// 创建后钩子（如免费档开通）。契约 best-effort + 非阻塞，失败/慢钩子不能破坏 onboarding。
	if s.onCreated != nil {
		s.onCreated(ctx, w.ID)
	}
	return w, nil
}

// Get returns one workspace by id.
//
// Get 按 id 取 workspace。
func (s *Service) Get(ctx context.Context, id string) (*workspacedomain.Workspace, error) {
	return s.repo.Get(ctx, id)
}

// Stats inventories one workspace — the delete confirmation's REAL numbers (WRK-062 S-11). Counts
// come from the store in one batch; BlobBytes walks the file tree under a 500ms budget and reports
// -1 on overrun (an honest "unknown"); the generating intersection uses chat's in-flight snapshot.
// The path id is minted into ctx here — the route is workspace-exempt (it names its subject).
//
// Stats 盘点一个 workspace——删除确认的真数字(S-11)。计数 store 一批出;BlobBytes 500ms 预算内走文件树、
// 超时报 -1(诚实「未知」);generating 交集用 chat 在飞快照。path id 在此铸进 ctx——路由属 workspace 豁免
// (它自己点名对象)。
func (s *Service) Stats(ctx context.Context, id string) (*workspacedomain.Stats, error) {
	if _, err := s.repo.Get(ctx, id); err != nil {
		return nil, err
	}
	ctx = reqctxpkg.SetWorkspaceID(ctx, id)
	var generating []string
	if s.generating != nil {
		generating = s.generating()
	}
	st, err := s.repo.Stats(ctx, id, generating)
	if err != nil {
		return nil, err
	}
	st.BlobBytes = -1 // unknown until measured 量到前=未知
	if s.blobSizer != nil {
		walkCtx, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
		defer cancel()
		if n, err := s.blobSizer.TotalBytes(walkCtx); err == nil {
			st.BlobBytes = n
		}
	}
	return st, nil
}

// List returns all workspaces (small set, no pagination).
//
// List 返所有 workspace（量小，不分页）。
func (s *Service) List(ctx context.Context) ([]*workspacedomain.Workspace, error) {
	return s.repo.List(ctx)
}

// Update applies partial fields to a workspace; nil = skip.
//
// Update 部分更新；nil 字段跳过。
func (s *Service) Update(ctx context.Context, id string, in UpdateInput) (*workspacedomain.Workspace, error) {
	w, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if in.Name != nil {
		name, err := cleanName(*in.Name)
		if err != nil {
			return nil, err
		}
		w.Name = name
	}
	if in.AvatarColor != nil {
		w.AvatarColor = strings.TrimSpace(*in.AvatarColor)
	}
	if in.Language != nil {
		if !workspacedomain.IsValidLanguage(*in.Language) {
			return nil, workspacedomain.ErrLanguageInvalid
		}
		w.Language = *in.Language
	}
	if in.WebFetchMode != nil {
		if !workspacedomain.IsValidWebFetchMode(*in.WebFetchMode) {
			return nil, workspacedomain.ErrWebFetchModeInvalid
		}
		w.WebFetchMode = *in.WebFetchMode
	}
	w.UpdatedAt = time.Now().UTC()
	if err := s.repo.Save(ctx, w); err != nil {
		return nil, err
	}
	return w, nil
}

// Delete removes a workspace, refusing the last one — the isolation root must exist.
//
// Delete 删 workspace，拒删最后一个——隔离根必须存在。
func (s *Service) Delete(ctx context.Context, id string) error {
	n, err := s.repo.Count(ctx)
	if err != nil {
		return fmt.Errorf("workspace.Delete: count: %w", err)
	}
	if n <= 1 {
		return workspacedomain.ErrCannotDeleteLast
	}
	// Cascade destroy first: kill in-flight runs, detach trigger listeners, stop the
	// workspace's resident handler/mcp processes, remove its file tree. Best-effort — the row
	// delete below is the point of no return that makes everything unreachable.
	//
	// 先级联销毁：杀在途 run、摘 trigger 监听、停本 workspace 常驻 handler/mcp 进程、
	// 删文件树。best-effort——下方删行才是让一切不可达的不可回退点。
	if s.reaper != nil {
		s.reaper(ctx, id)
	}
	return s.repo.Delete(ctx, id)
}

// TouchLastUsed bumps the last-used timestamp (called on :activate / switch).
//
// TouchLastUsed 刷 last-used 时间戳（:activate / 切换时调）。
func (s *Service) TouchLastUsed(ctx context.Context, id string) error {
	return s.repo.TouchLastUsed(ctx, id)
}

// Resolve implements the auth middleware's WorkspaceResolver port: it confirms id names an
// existing workspace and returns its UI locale (derived from the persisted language) so the
// middleware can make the workspace language authoritative over Accept-Language.
// Unknown id → error. workspace.Language values ("zh-CN"/"en") are exactly the Locale values, so
// the cast is direct; an empty/invalid one is dropped by the middleware's IsSupported() guard.
//
// Resolve 实现 auth 中间件的 WorkspaceResolver 端口：确认 id 为已存在 workspace 并返回其 UI locale
// （由持久化 language 派生），使中间件让 workspace 语言压过 Accept-Language。未知 id→错。
// workspace.Language 取值（"zh-CN"/"en"）正是 Locale 取值，故直接 cast；空/非法值由中间件
// IsSupported() 守卫丢弃。
func (s *Service) Resolve(ctx context.Context, id string) (reqctxpkg.Locale, error) {
	// Single-column read: this runs on EVERY request (auth middleware), and the full Get paid a
	// 13-column reflective scan + 3 ModelRef JSON unmarshals per hit for one string (R3).
	// 单列读:每请求都走(auth 中间件),整行 Get 为一个字符串付 13 列反射 + 3 次 JSON 反序列化(R3)。
	lang, err := s.repo.Language(ctx, id)
	if err != nil {
		return "", err
	}
	return reqctxpkg.Locale(lang), nil
}

// Pick implements modeldomain.ModelPicker: it returns the current workspace's default ModelRef for
// a scenario (workspace id from ctx). ErrNotConfigured when that scenario has no default, so the
// caller surfaces a "configure a model" prompt rather than failing opaquely.
//
// Pick 实现 modeldomain.ModelPicker：返回当前 workspace（id 取自 ctx）某 scenario 的默认 ModelRef。
// 该 scenario 无默认时返 ErrNotConfigured——caller 提示"去配置模型"而非晦涩报错。
func (s *Service) Pick(ctx context.Context, scenario string) (modeldomain.ModelRef, error) {
	if !modeldomain.IsValidScenario(scenario) {
		return modeldomain.ModelRef{}, modeldomain.ErrScenarioInvalid
	}
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return modeldomain.ModelRef{}, err
	}
	w, err := s.repo.Get(ctx, wsID)
	if err != nil {
		return modeldomain.ModelRef{}, err
	}
	ref := w.DefaultFor(scenario)
	if ref == nil || ref.IsZero() {
		return modeldomain.ModelRef{}, modeldomain.ErrNotConfigured
	}
	return *ref, nil
}

// SetDefault sets (or clears, with a nil ref) the default model for one scenario of a workspace; a
// non-nil ref must carry both apiKeyId and modelId.
//
// SetDefault 设置（nil ref 则清除）某 workspace 某 scenario 的默认模型；非 nil ref 须带 apiKeyId+modelId。
func (s *Service) SetDefault(ctx context.Context, id, scenario string, ref *modeldomain.ModelRef) (*workspacedomain.Workspace, error) {
	if !modeldomain.IsValidScenario(scenario) {
		return nil, modeldomain.ErrScenarioInvalid
	}
	// Structure (MODEL_REF_INVALID) + apiKeyId existence (API_KEY_NOT_FOUND at write, F153). A nil ref
	// (clear) skips both. modelId spelling stays fail-loud-at-invoke (no authoritative catalog).
	// 结构（MODEL_REF_INVALID）+ apiKeyId 存在性（写时 API_KEY_NOT_FOUND，F153）。nil ref（清除）两者皆跳。
	// modelId 拼写留 fail-loud-at-invoke（无权威目录）。
	if err := modelrefapp.Validate(ctx, ref, modeldomain.ErrRefInvalid, s.keyChecker); err != nil {
		return nil, err
	}
	w, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	w.SetDefaultFor(scenario, ref)
	w.UpdatedAt = time.Now().UTC()
	if err := s.repo.Save(ctx, w); err != nil {
		return nil, err
	}
	s.log.Info("workspace default model set", zap.String("workspace_id", id), zap.String("scenario", scenario))
	return w, nil
}

// SeedDefaultsIfUnset points every scenario default (dialogue/utility/agent) that is still UNSET at
// ref, for the ctx workspace, in one Save. Free-tier provisioning calls this so the managed model is
// the out-of-box default for all three scenarios — without it the columns stay NULL and utility-model
// chores (auto-title, compaction) silently no-op. It only fills the blanks: a scenario a user has
// already picked is left alone, so re-running on every boot never clobbers an explicit choice. ref is
// our own managed ref (structural-check only, no keyChecker) — the caller ensured the key exists.
//
// SeedDefaultsIfUnset 把仍未设的 scenario 默认（dialogue/utility/agent）一次性设成 ref（ctx workspace）。
// 免费档 provisioning 调它，使受管模型成三 scenario 的开箱默认——否则列恒 NULL、utility 杂活（自动标题、压缩）
// 静默 no-op。只填空白：用户已选的 scenario 不动，故每次 boot 重跑绝不覆盖显式选择。ref 是自造受管 ref（仅结构
// 校验、不过 keyChecker）——调用方已确保 key 存在。
func (s *Service) SeedDefaultsIfUnset(ctx context.Context, ref modeldomain.ModelRef) error {
	if err := ref.Validate(); err != nil {
		return err
	}
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return err
	}
	w, err := s.repo.Get(ctx, wsID)
	if err != nil {
		return err
	}
	changed := false
	for _, scenario := range modeldomain.ListScenarios() {
		if cur := w.DefaultFor(scenario); cur == nil || cur.IsZero() {
			r := ref // fresh copy per scenario — never alias one *ModelRef across three columns
			w.SetDefaultFor(scenario, &r)
			changed = true
		}
	}
	if !changed {
		return nil
	}
	w.UpdatedAt = time.Now().UTC()
	return s.repo.Save(ctx, w)
}

// DefaultSearchKeyID implements websearch.SearchKeyPicker: it returns the current
// workspace's chosen search api-key id (workspace id from ctx); ok=false when none is
// configured or the workspace can't be loaded — WebSearch then falls through to its
// next backend rather than failing.
//
// DefaultSearchKeyID 实现 websearch.SearchKeyPicker：返回当前 workspace（id 取自 ctx）选定的搜索
// api-key id；未配置或 workspace 取不到时 ok=false——WebSearch 据此降级到下个后端而非报错。
func (s *Service) DefaultSearchKeyID(ctx context.Context) (string, bool) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return "", false
	}
	w, err := s.repo.Get(ctx, wsID)
	if err != nil {
		return "", false
	}
	id := strings.TrimSpace(w.DefaultSearchKeyID)
	return id, id != ""
}

// ReferencesAPIKey implements apikeyapp.RefScanner: the current workspace (id from ctx)
// references an api-key when any scenario default model (dialogue/utility/agent) or the
// default search key points at it. Deleting such a key would silently dangle the
// workspace's model config, so apikey.Delete consults this scanner and refuses with
// API_KEY_IN_USE. A missing workspace in ctx or an unreadable row is a scan miss (false),
// never a hard error — a delete-guard must not block on its own lookup failing.
//
// ReferencesAPIKey 实现 apikeyapp.RefScanner：当前 workspace（id 取自 ctx）的任一 scenario
// 默认模型（dialogue/utility/agent）或默认搜索 key 指向某 api-key 即算引用。删它会静默悬空
// workspace 的模型配置，故 apikey.Delete 询问本 scanner、命中即拒删 API_KEY_IN_USE。ctx 无
// workspace 或行读不到都算未命中（false）、绝不硬错——删除守卫不能因自身查询失败而挡删。
func (s *Service) ReferencesAPIKey(ctx context.Context, apiKeyID string) ([]apikeydomain.APIKeyRef, error) {
	if apiKeyID == "" {
		return nil, nil
	}
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return nil, nil
	}
	w, err := s.repo.Get(ctx, wsID)
	if err != nil {
		return nil, nil
	}
	var refs []apikeydomain.APIKeyRef
	for _, scenario := range modeldomain.ListScenarios() {
		if ref := w.DefaultFor(scenario); ref != nil && ref.APIKeyID == apiKeyID {
			refs = append(refs, apikeydomain.APIKeyRef{Kind: "scenario_default", ID: scenario, Name: scenario})
		}
	}
	if strings.TrimSpace(w.DefaultSearchKeyID) == apiKeyID {
		refs = append(refs, apikeydomain.APIKeyRef{Kind: "search_default", ID: "search", Name: "default search"})
	}
	return refs, nil
}

// WebFetchMode resolves the current workspace's web-fetch mode for the WebFetch tool:
// "local" (direct GET, the default) or "jina" (third-party reader). Any failure to read the
// workspace falls back to local — never leak a URL on a degraded path.
//
// WebFetchMode 为 WebFetch 工具解析当前 workspace 的抓取模式："local"（直接 GET，默认）或
// "jina"（第三方 reader）。读不到 workspace 一律落回 local——降级路径绝不外发 URL。
func (s *Service) WebFetchMode(ctx context.Context) string {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		return workspacedomain.WebFetchModeLocal
	}
	w, err := s.repo.Get(ctx, wsID)
	if err != nil {
		return workspacedomain.WebFetchModeLocal
	}
	return workspacedomain.EffectiveWebFetchMode(w.WebFetchMode)
}

// SetDefaultSearch sets (or clears with "") the workspace's default search api-key id.
// No provider/category check — mirrors SetDefault's runtime-graceful style: the WebSearch
// tool rejects a non-search key at call time, and the UI only offers search-category keys.
//
// SetDefaultSearch 设置（""则清除）workspace 的默认搜索 api-key id。不校验 provider/category
// ——镜像 SetDefault 的运行时优雅风格：WebSearch 工具调用时拒非搜索 key，UI 只让选 search 类 key。
func (s *Service) SetDefaultSearch(ctx context.Context, id, keyID string) (*workspacedomain.Workspace, error) {
	w, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	w.DefaultSearchKeyID = strings.TrimSpace(keyID)
	w.UpdatedAt = time.Now().UTC()
	if err := s.repo.Save(ctx, w); err != nil {
		return nil, err
	}
	s.log.Info("workspace default search key set",
		zap.String("workspace_id", id), zap.Bool("cleared", w.DefaultSearchKeyID == ""))
	return w, nil
}

// Service implements ModelPicker and websearch.SearchKeyPicker — the LLM/search-using
// callers depend on these ports.
//
// Service 实现 ModelPicker 与 websearch.SearchKeyPicker——用 LLM/搜索的 caller 依赖这些端口。
var (
	_ modeldomain.ModelPicker         = (*Service)(nil)
	_ websearchdomain.SearchKeyPicker = (*Service)(nil)
)

// cleanName trims, requires non-empty, and bounds the length of a workspace name.
//
// cleanName 去空白、要求非空、限制 workspace 名长度。
func cleanName(raw string) (string, error) {
	name := strings.TrimSpace(raw)
	if name == "" {
		return "", workspacedomain.ErrNameRequired
	}
	if utf8.RuneCountInString(name) > workspacedomain.MaxNameLen {
		return "", workspacedomain.ErrNameTooLong
	}
	return name, nil
}

// resolveLanguage defaults an empty language to zh-CN and validates non-empty ones.
//
// resolveLanguage 把空 language 默认为 zh-CN，非空则校验。
func resolveLanguage(lang string) (string, error) {
	if lang == "" {
		return workspacedomain.LanguageZhCN, nil
	}
	if !workspacedomain.IsValidLanguage(lang) {
		return "", workspacedomain.ErrLanguageInvalid
	}
	return lang, nil
}
