// Package trigger is the trigger-entity domain: a standalone signal source that fires
// when its source condition is met (cron tick / webhook hit / file change / sensor probe),
// fanning the signal out to every active workflow that listens to it. A trigger is a
// CONFIG entity — no version model, no sandbox, no env. Its listener runs only while at
// least one active workflow references it (reference-counted lifecycle, owned by app).
//
// Package trigger 是 trigger 实体域：独立的信号源，source 条件满足即 fire（cron 刻度 /
// webhook / 文件变 / sensor 探测），把信号扇给所有监听它的 active workflow。trigger 是
// **配置实体**——无版本、无 sandbox、无 env。listener 仅在 ≥1 个 active workflow 引用它时
// 运行（引用计数生命周期，由 app 持有）。
package trigger

import (
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// Source kinds. manual is intentionally absent — running a workflow by hand is the
// workflow's own ability (it listens to nothing), not a trigger source.
//
// Source 种类。故意没有 manual——手动跑 workflow 是 workflow 自己的能力（它不监听任何东西），不是 trigger source。
const (
	KindCron     = "cron"     // robfig/cron expression, fires on schedule tick
	KindWebhook  = "webhook"  // external HTTP push to a mounted path
	KindFsnotify = "fsnotify" // local filesystem change on a watched path
	KindSensor   = "sensor"   // periodically invoke a function/handler, fire when a CEL condition holds
)

// IsValidKind reports whether k is one of the 4 source kinds.
//
// IsValidKind 报告 k 是否 4 种 source 之一。
func IsValidKind(k string) bool {
	switch k {
	case KindCron, KindWebhook, KindFsnotify, KindSensor:
		return true
	}
	return false
}

// CanonicalOutputs returns the FIXED fire-payload fields a cron/webhook/fsnotify trigger delivers to
// listening workflows — the same keys the infra listeners emit (cron/webhook/fsnotify .go), so a
// workflow node can discover them by node id. The app stamps these onto Outputs at create/edit for
// these kinds, OVERRIDING any author-supplied list, so the declaration cannot drift from the real
// payload. sensor returns nil: its payload shape is author-defined via config.output, so the author
// keeps control of Outputs there. Keep these in sync with the listeners' fire payloads.
//
// CanonicalOutputs 返回 cron/webhook/fsnotify 触发器交付给监听 workflow 的固定 fire-payload 字段——
// 与 infra listeners 实际 emit 的键一致，使 workflow 节点能按 node id 发现。app 在 create/edit 时对这些
// kind 把它盖到 Outputs、**覆盖**作者所填，使声明永不与真实 payload 漂移。sensor 返 nil：其 payload 形状
// 由 config.output 作者定义、Outputs 由作者掌控。须与 listeners 的 fire payload 保持同步。
func CanonicalOutputs(kind string) []schemapkg.Field {
	switch kind {
	case KindCron:
		return []schemapkg.Field{
			{Name: "firedAt", Type: schemapkg.TypeString, Description: "When the trigger fired (RFC3339)."},
		}
	case KindWebhook:
		return []schemapkg.Field{
			{Name: "firedAt", Type: schemapkg.TypeString, Description: "When the request arrived (RFC3339)."},
			{Name: "method", Type: schemapkg.TypeString, Description: "HTTP method of the request."},
			{Name: "path", Type: schemapkg.TypeString, Description: "The mounted webhook path that was hit."},
			{Name: "headers", Type: schemapkg.TypeObject, Description: "Request headers (flattened)."},
			{Name: "body", Type: schemapkg.TypeObject, Description: "Posted body parsed as JSON (present when the body is valid JSON)."},
			{Name: "bodyRaw", Type: schemapkg.TypeString, Description: "Raw body string (present when the body is not JSON)."},
		}
	case KindFsnotify:
		return []schemapkg.Field{
			{Name: "firedAt", Type: schemapkg.TypeString, Description: "When the event fired (RFC3339)."},
			{Name: "path", Type: schemapkg.TypeString, Description: "The file/dir path that changed."},
			{Name: "eventKind", Type: schemapkg.TypeString, Description: "create|modify|delete|rename|chmod (combined events join with |)."},
		}
	}
	return nil
}

// Trigger is the entity row. Config holds the source-specific settings (see config.go);
// it is kept as a free map so adding a source kind needs no column change.
//
// Trigger 是实体行。Config 持有 source 专属配置（见 config.go），用自由 map 存——加 source 种类无需改列。
type Trigger struct {
	ID          string            `db:"id,pk"              json:"id"`
	WorkspaceID string            `db:"workspace_id,ws"    json:"-"` // D2 物理隔离列,不上线缆
	Name        string            `db:"name"               json:"name"`
	Description string            `db:"description"        json:"description"`
	Kind        string            `db:"kind"               json:"kind"`
	Config      map[string]any    `db:"config,json"        json:"config"`
	Outputs     []schemapkg.Field `db:"outputs,json"       json:"outputs"` // declared payload fields delivered to listening workflows (downstream reads these)
	// Paused is the runtime stop-the-bleeding switch (:pause / :resume, scheduler 工单⑦), PERSISTED
	// so a restart stays paused. Paused = the trigger produces NO new firings (its source listener is
	// unregistered; manual :fire is refused) while in-flight runs and already-pending firings are
	// untouched. Distinct from Listening: Listening is the derived "is a listener hot" fact (needs
	// ≥1 active workflow AND not paused); Paused is the user's own persisted intent.
	//
	// Paused 是运行时止血开关（:pause / :resume，scheduler 工单⑦），**持久化**——重启后仍暂停。
	// 暂停 = 不再产生任何新 firing（底层 source listener 已注销；手动 :fire 被拒），在途 run 与已
	// pending 的 firing 不受影响。与 Listening 不同：Listening 是派生的「listener 热否」事实
	// （须 ≥1 个 active workflow 且未暂停）；Paused 是用户自己的持久化意图。
	Paused bool `db:"paused"             json:"paused"`
	// MissedCheckedAt is the misfire watermark (scheduler 工单⑨): every scheduled cron tick at or
	// before this instant is ACCOUNTED — it fired, was recorded missed, or fell in a period the user
	// chose not to listen (paused / workflow inactive). The misfire sweep detects missed ticks in
	// (watermark, now]; advanced on every cron fan-out, at sweep end, on :resume, and on a fresh
	// 0→1 attach. Internal bookkeeping — not on the wire. Nil = never accounted (floor = CreatedAt).
	//
	// MissedCheckedAt 是 misfire 水位（scheduler 工单⑨）：此刻及之前的每个 cron 调度刻度都已**入账**——
	// 或已 fire、或已记 missed、或落在用户主动不监听的时段（暂停/workflow 停用）。misfire sweep 在
	// (水位, now] 内检测错过点；每次 cron 扇出、sweep 收尾、:resume、全新 0→1 attach 时推进。
	// 内部记账列——不上线缆。nil = 从未入账（下限取 CreatedAt）。
	MissedCheckedAt *time.Time `db:"missed_checked_at" json:"-"`
	CreatedAt       time.Time  `db:"created_at,created" json:"createdAt"`
	UpdatedAt       time.Time  `db:"updated_at,updated" json:"updatedAt"`
	DeletedAt       *time.Time `db:"deleted_at,deleted" json:"-"`

	// RefCount / Listening are computed at read time from the app's in-memory listen
	// registry (how many active workflows reference it / whether its listener is hot).
	// Not persisted — the persistent truth is the workflow side (who is active).
	//
	// RefCount / Listening 读时由 app 内存监听表算出（多少 active workflow 引用它 / listener 热否），不落库。
	RefCount  int  `db:"-" json:"refCount"`
	Listening bool `db:"-" json:"listening"`
	// LastFiredAt is the created_at of the most recent FIRED activation (nil = never fired),
	// projected into List/Get so the row can show "fired 3 minutes ago". Read-derived, not stored.
	//
	// LastFiredAt 是最近一条**已触发** activation 的 created_at（nil = 从未触发），投影进 List/Get 使行
	// 可显示「3 分钟前 fire」。读时派生，不落库。
	LastFiredAt *time.Time `db:"-" json:"lastFiredAt,omitempty"`
	// NextFireAt is the next scheduled fire of a CRON trigger (nil for non-cron, or an unparseable
	// expr), projected into List/Get so the UI can show "next fire in N". Read-derived from the cron
	// expression at request time, not stored.
	//
	// NextFireAt 是 CRON 触发器下次调度触发时刻（非 cron 或 expr 不可解析则 nil），投影进 List/Get 使
	// UI 可显示「N 后触发」。请求时从 cron 表达式读时派生，不落库。
	NextFireAt *time.Time `db:"-" json:"nextFireAt,omitempty"`
}

// ListFilter paginates the trigger list.
//
// ListFilter 分页 trigger 列表。
type ListFilter struct {
	Cursor string
	Limit  int
}

// Domain errors. Wire codes are stable; Kind maps to HTTP status (errorspkg).
//
// Domain 错误。wire code 稳定；Kind 映射 HTTP status。
var (
	ErrNotFound              = errorspkg.New(errorspkg.KindNotFound, "TRIGGER_NOT_FOUND", "trigger not found")
	ErrDuplicateName         = errorspkg.New(errorspkg.KindConflict, "TRIGGER_NAME_DUPLICATE", "trigger name already exists")
	ErrInvalidKind           = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_INVALID_KIND", "unknown trigger kind")
	ErrInvalidConfig         = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_INVALID_CONFIG", "invalid trigger config")
	ErrInvalidCron           = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_INVALID_CRON", "invalid cron expression — use a 5-field expression (minute granularity); @every and seconds are not supported")
	ErrInvalidCEL            = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_INVALID_CEL", "invalid CEL expression")
	ErrInvalidInterval       = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_INVALID_INTERVAL", "sensor interval below minimum")
	ErrSensorTargetRequired  = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_SENSOR_TARGET_REQUIRED", "sensor requires a function or handler target")
	ErrSensorTargetNotFound  = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_SENSOR_TARGET_NOT_FOUND", "sensor target does not exist")
	ErrWebhookSecretMismatch = errorspkg.New(errorspkg.KindUnauthorized, "TRIGGER_WEBHOOK_SECRET_MISMATCH", "webhook secret mismatch")
	ErrActivationNotFound    = errorspkg.New(errorspkg.KindNotFound, "TRIGGER_ACTIVATION_NOT_FOUND", "activation not found")
	ErrListenerUnavailable   = errorspkg.New(errorspkg.KindUnavailable, "TRIGGER_LISTENER_UNAVAILABLE", "trigger listener not available")
	// ErrFiringNotPending: a ClaimFiring lost the race — already claimed/terminal (consumed by the scheduler).
	// ErrFiringNotPending：claim 竞争失败（已被认领/终态），scheduler 消费。
	ErrFiringNotPending = errorspkg.New(errorspkg.KindConflict, "TRIGGER_FIRING_NOT_PENDING", "firing already claimed")
	// ErrPaused: a manual :fire (fire_trigger) hit a paused trigger. Loud 422 instead of a silent
	// no-op so neither the UI nor an agent bypasses (or misreads) the user's pause (scheduler 工单⑦).
	// ErrPaused：手动 :fire（fire_trigger）打在已暂停的 trigger 上。422 大声拒而非静默 no-op——
	// UI 与 agent 都不得绕过（或误读）用户的暂停（scheduler 工单⑦）。
	ErrPaused = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_PAUSED", "trigger is paused — resume it before firing")
	// ErrInvalidMisfirePolicy: create/edit passed a misfirePolicy outside the closed vocabulary
	// (scheduler 工单⑨) — loud 422, never a typo silently behaving as skip.
	// ErrInvalidMisfirePolicy：create/edit 传了词表外的 misfirePolicy（scheduler 工单⑨）——
	// 422 大声拒，绝不让写错的词静默按 skip 走。
	ErrInvalidMisfirePolicy = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_INVALID_MISFIRE_POLICY", "misfirePolicy must be one of: skip, catchup_one")
	// ErrInvalidScheduleQuery: GET /trigger-schedule got an unparsable/non-positive within or limit
	// (scheduler 工单⑧) — 422 with the offending param in Details.
	// ErrInvalidScheduleQuery：GET /trigger-schedule 的 within/limit 不可解析或非正（scheduler 工单⑧）——
	// 422，Details 带出错参数。
	ErrInvalidScheduleQuery = errorspkg.New(errorspkg.KindUnprocessable, "TRIGGER_SCHEDULE_INVALID_QUERY", "trigger-schedule query invalid — within must be a positive Go duration (e.g. 168h) and limit a positive integer")
)
