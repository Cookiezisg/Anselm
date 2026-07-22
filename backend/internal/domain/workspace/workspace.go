// Package workspace is the domain layer for the local isolation root. A named
// workspace is the unit every other entity is scoped to (its workspace_id), and
// is itself the one business table with no workspace_id column — it IS the
// workspace. Isolation is two-fold: DB rows (agents, documents, api keys, mcp
// servers, runs) are filtered by workspace_id via the orm, and the file-backed
// stores (memory / skill / blob) bucket under workspaces/<wsID>/ on disk. Only
// machine-level infrastructure (sandbox runtimes / envs) is shared across
// workspaces; workspace preferences (language, model defaults, web fetch mode)
// are columns on the workspace row itself.
//
// Package workspace 是本地隔离根的 domain 层。一个具名 workspace 是其它所有实体的隔离单元
// （它们的 workspace_id），而它自己是唯一不带 workspace_id 列的业务表——它就是 workspace。
// 隔离是双重的：DB 行（agent/document/api key/mcp server/run）经 orm 按 workspace_id 过滤，
// 文件式 store（memory/skill/blob）在磁盘按 workspaces/<wsID>/ 分桶。仅机器级基础设施
// （sandbox runtime/env）跨 workspace 共享；workspace 偏好（语言/模型默认/抓取模式）即
// workspace 行自身的列。
package workspace

import (
	"context"
	"time"

	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Workspace is one local isolation root. Name is a free-form display label,
// unique per machine; Language is a per-workspace UI preference (the first of a
// future set of workspace-scoped preferences). Unlike every other entity it
// carries no workspace_id.
//
// Workspace 是一个本地隔离根。Name 是自由展示名，全机唯一；Language 是 workspace 级 UI 偏好
// （未来一组 workspace 偏好的第一个）。与其它所有实体不同，它不带 workspace_id。
type Workspace struct {
	ID          string `db:"id,pk" json:"id"`
	Name        string `db:"name" json:"name"`
	AvatarColor string `db:"avatar_color" json:"avatarColor,omitempty"`
	Language    string `db:"language" json:"language"`
	// Per-scenario default model selections — workspace-scoped preferences alongside Language,
	// stored as JSON; nil = not configured for that scenario.
	// 按 scenario 的默认模型选择——与 Language 并列的 workspace 级偏好，JSON 存；nil = 该 scenario 未配置。
	DefaultDialogue *modeldomain.ModelRef `db:"default_dialogue,json" json:"defaultDialogue,omitempty"`
	DefaultUtility  *modeldomain.ModelRef `db:"default_utility,json" json:"defaultUtility,omitempty"`
	DefaultAgent    *modeldomain.ModelRef `db:"default_agent,json" json:"defaultAgent,omitempty"`
	// DefaultSearchKeyID is the api-key id chosen for WebSearch (provider implied by the
	// key). "" = unconfigured. A single explicit choice, not a priority list — the agent
	// never burns credits probing providers. Implements websearch.SearchKeyPicker via Service.
	// DefaultSearchKeyID 是为 WebSearch 选定的 api-key id（provider 由 key 隐含）。"" = 未配置。
	// 单一显式选择、非优先级列表——agent 永不试 provider 乱烧钱。经 Service 实现 websearch.SearchKeyPicker。
	DefaultSearchKeyID string `db:"default_search_key_id" json:"defaultSearchKeyId,omitempty"`
	// WebFetchMode picks how the WebFetch tool retrieves pages: "local" = direct HTTP GET from
	// this machine (no URL leaves it — the local-first default); "jina" = via the public Jina
	// reader (better Markdown extraction, but every fetched URL is sent to a third party).
	// "" = local.
	// WebFetchMode 决定 WebFetch 工具的抓取方式："local" = 本机直接 HTTP GET（URL 不出本机——
	// 本地优先的默认）；"jina" = 走公共 Jina reader（Markdown 提取更好，但每个抓取 URL 都发给
	// 第三方）。"" = local。
	WebFetchMode string     `db:"web_fetch_mode" json:"webFetchMode,omitempty"`
	LastUsedAt   *time.Time `db:"last_used_at" json:"lastUsedAt,omitempty"`
	CreatedAt    time.Time  `db:"created_at,created" json:"createdAt"`
	UpdatedAt    time.Time  `db:"updated_at,updated" json:"updatedAt"`
	DeletedAt    *time.Time `db:"deleted_at,deleted" json:"-"`
}

// Supported UI languages; Language is CHECK-constrained to this set in the DDL.
//
// 支持的 UI 语言；Language 在 DDL 里被 CHECK 约束到此集合。
const (
	LanguageZhCN = "zh-CN"
	LanguageEn   = "en"
)

// WebFetch modes; WebFetchMode is CHECK-constrained to this set plus the empty string in the DDL.
//
// WebFetch 模式；WebFetchMode 在 DDL 里被 CHECK 约束到此集合外加空串。
const (
	WebFetchModeLocal = "local"
	WebFetchModeJina  = "jina"
)

// IsValidWebFetchMode reports whether m is an explicit, storable mode.
//
// IsValidWebFetchMode 判断 m 是否为可落库的显式模式。
func IsValidWebFetchMode(m string) bool {
	return m == WebFetchModeLocal || m == WebFetchModeJina
}

// EffectiveWebFetchMode resolves the stored value to the mode that runs: "" → local
// (the local-first default).
//
// EffectiveWebFetchMode 把存储值解析为实际生效模式："" → local（本地优先默认）。
func EffectiveWebFetchMode(stored string) string {
	if stored == WebFetchModeJina {
		return WebFetchModeJina
	}
	return WebFetchModeLocal
}

// MaxNameLen bounds a workspace name in runes — free-form display text, not a slug.
//
// MaxNameLen 按 rune 限制 workspace 名长度——自由展示文本，非 slug。
const MaxNameLen = 64

// IsValidLanguage reports whether l is a supported UI language.
//
// IsValidLanguage 报告 l 是否为支持的 UI 语言。
func IsValidLanguage(l string) bool {
	return l == LanguageZhCN || l == LanguageEn
}

// DefaultFor returns the default ModelRef for a scenario, or nil if unconfigured / unknown scenario.
//
// DefaultFor 返回某 scenario 的默认 ModelRef；未配置 / 未知 scenario 返 nil。
func (w *Workspace) DefaultFor(scenario string) *modeldomain.ModelRef {
	switch scenario {
	case modeldomain.ScenarioDialogue:
		return w.DefaultDialogue
	case modeldomain.ScenarioUtility:
		return w.DefaultUtility
	case modeldomain.ScenarioAgent:
		return w.DefaultAgent
	}
	return nil
}

// SetDefaultFor sets (or clears with nil) the default ModelRef for a scenario; an unknown scenario
// is a no-op (callers validate first).
//
// SetDefaultFor 设置（nil 则清除）某 scenario 的默认 ModelRef；未知 scenario 为 no-op（caller 先校验）。
func (w *Workspace) SetDefaultFor(scenario string, ref *modeldomain.ModelRef) {
	switch scenario {
	case modeldomain.ScenarioDialogue:
		w.DefaultDialogue = ref
	case modeldomain.ScenarioUtility:
		w.DefaultUtility = ref
	case modeldomain.ScenarioAgent:
		w.DefaultAgent = ref
	}
}

// Domain sentinels — built via errorspkg.New so transport reads Kind/Code
// directly (§S20); wire codes align with error-codes.md.
//
// domain sentinel——经 errorspkg.New 构造，使 transport 直接读 Kind/Code（§S20）；
// wire code 对齐 error-codes.md。
var (
	ErrNotFound            = errorspkg.New(errorspkg.KindNotFound, "WORKSPACE_NOT_FOUND", "workspace not found")
	ErrNameRequired        = errorspkg.New(errorspkg.KindInvalid, "WORKSPACE_NAME_REQUIRED", "workspace name is required")
	ErrNameTooLong         = errorspkg.New(errorspkg.KindInvalid, "WORKSPACE_NAME_TOO_LONG", "workspace name exceeds the length limit")
	ErrNameConflict        = errorspkg.New(errorspkg.KindConflict, "WORKSPACE_NAME_CONFLICT", "workspace name already exists")
	ErrCannotDeleteLast    = errorspkg.New(errorspkg.KindUnprocessable, "CANNOT_DELETE_LAST_WORKSPACE", "cannot delete the last workspace")
	ErrLanguageInvalid     = errorspkg.New(errorspkg.KindInvalid, "WORKSPACE_LANGUAGE_INVALID", "language must be one of zh-CN, en")
	ErrWebFetchModeInvalid = errorspkg.New(errorspkg.KindInvalid, "WORKSPACE_WEB_FETCH_MODE_INVALID", "webFetchMode must be one of local, jina")
)

// Stats is one workspace's content inventory — what a delete would destroy. Pure counts (the
// store fills them in one query batch); BlobBytes is filled by the app layer from the file tree
// and is -1 when the walk exceeded its time budget (an honest "unknown", never a fake 0).
//
// Stats 是一个 workspace 的内容盘点——删除将销毁之物。纯计数(store 一批查询填充);BlobBytes 由 app 层
// 从文件树填充,walk 超预算时为 -1(诚实的「未知」,绝不假 0)。
type Stats struct {
	Conversations int `json:"conversations"`
	Functions     int `json:"functions"`
	Handlers      int `json:"handlers"`
	Agents        int `json:"agents"`
	Workflows     int `json:"workflows"`
	Documents     int `json:"documents"`
	// RunningFlowruns and GeneratingConversations are the DYNAMIC hazard: >0 means a delete
	// terminates live work (the confirm dialog leads with it, WRK-062 S-11).
	// 动态危险项:>0 = 删除将终止进行中的工作(确认框以它开头)。
	RunningFlowruns         int   `json:"runningFlowruns"`
	GeneratingConversations int   `json:"generatingConversations"`
	BlobBytes               int64 `json:"blobBytes"`
}

// Repository is the storage contract for Workspace. Like the entity it is not
// workspace-scoped — these are the only queries that span all workspaces.
//
// Repository 是 Workspace 的存储契约。与实体一样不按 workspace 隔离——这是唯一跨所有 workspace 的查询。
type Repository interface {
	Save(ctx context.Context, w *Workspace) error
	Get(ctx context.Context, id string) (*Workspace, error)
	// Language returns just the workspace's language column — the auth middleware resolves it on
	// EVERY request, and a full Get pays a 13-column reflective scan + three ModelRef JSON
	// unmarshals per hit for one string. Row-absent → ErrNotFound (existence check included).
	// Language 只取 language 列——auth 中间件每请求解析一次,整行 Get 为一个字符串付 13 列反射扫
	// + 3 次 ModelRef JSON 反序列化。行缺席 → ErrNotFound(存在性检查含在内)。
	Language(ctx context.Context, id string) (string, error)
	List(ctx context.Context) ([]*Workspace, error)
	Delete(ctx context.Context, id string) error
	Count(ctx context.Context) (int, error)
	TouchLastUsed(ctx context.Context, id string) error
	// Stats counts the workspace's contents in one batch. generatingIDs are the chat app's
	// in-flight conversation ids (memory state, not a column) — the store intersects them with
	// this workspace's live rows. 一批数完;generatingIDs 是 chat 内存在飞集,store 与本 ws 活行求交。
	Stats(ctx context.Context, id string, generatingIDs []string) (*Stats, error)
}
