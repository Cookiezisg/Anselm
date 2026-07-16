package trigger

import (
	"context"
	"time"
)

// Repository persists triggers (soft-deleted) + the firings inbox + the activation log.
// The single-tx claim (pending→claimed + flowrun INSERT) is NOT here — it spans the
// flowruns table and must not leak *orm.DB into a domain port; the store exposes
// it as a concrete method for the scheduler to call.
//
// Repository 持久化 triggers（软删）+ firings 收件箱 + activation 日志。单事务 claim
// （pending→claimed + 建 flowrun）不在此——它跨 flowruns 表、不该把 *orm.DB 漏进
// domain 端口；store 以具体方法暴露给 scheduler。
type Repository interface {
	// triggers
	SaveTrigger(ctx context.Context, t *Trigger) error
	GetTrigger(ctx context.Context, id string) (*Trigger, error)
	GetTriggerByName(ctx context.Context, name string) (*Trigger, error)
	GetTriggersByIDs(ctx context.Context, ids []string) ([]*Trigger, error)
	ListTriggers(ctx context.Context, filter ListFilter) ([]*Trigger, string, error)
	ListAllTriggers(ctx context.Context) ([]*Trigger, error)
	DeleteTrigger(ctx context.Context, id string) error
	// SetTriggerPaused flips ONLY the persisted pause switch (:pause / :resume, scheduler 工单⑦) —
	// a targeted update, not a whole-row Save, so it cannot clobber a concurrent Edit. ErrNotFound
	// on miss; setting the current value again is a harmless no-op (idempotent endpoints).
	// SetTriggerPaused 只翻持久化暂停开关（:pause / :resume，scheduler 工单⑦）——定点更新、非整行
	// Save，不会覆写并发 Edit。未命中 ErrNotFound；重复设同值无害 no-op（端点幂等）。
	SetTriggerPaused(ctx context.Context, id string, paused bool) error
	// AdvanceMissedWatermark moves the misfire watermark (missed_checked_at, scheduler 工单⑨)
	// forward to `at` — monotonic (an older value never overwrites a newer one) and deliberately
	// NOT bumping updated_at: the watermark is machine bookkeeping on every cron fire/sweep, and
	// churning updated_at would make the row's edit timestamp meaningless. Missing row = no-op.
	// AdvanceMissedWatermark 把 misfire 水位（missed_checked_at，scheduler 工单⑨）单调推进到 `at`
	// （旧值绝不覆盖新值），且刻意**不**碰 updated_at：水位是每次 cron fire/sweep 的机器记账，
	// 若搅动 updated_at 会让行的编辑时间失义。行不存在 = no-op。
	AdvanceMissedWatermark(ctx context.Context, id string, at time.Time) error

	// firings inbox (persist-before-act). AppendFiring is idempotent on the dedup key.
	// firings 收件箱（先持久化再动作）。AppendFiring 按 dedup key 幂等。
	AppendFiring(ctx context.Context, f *Firing) (*Firing, error)
	// AppendMissedFiring books a `missed` firing DATED AT the tick it stands for (f.CreatedAt =
	// the scheduled instant, scheduler 工单⑨) — unlike a live fire, a missed tick is recorded after
	// the fact, and wearing the sweep instant would make every missed row of a night-long outage
	// claim to have happened in the same second at wake-up. Same dedup-key idempotence as
	// AppendFiring: the existing row is returned when the tick is already accounted.
	//
	// AppendMissedFiring 记一条 `missed` firing，**日期取它所代表的刻度**（f.CreatedAt = 调度时刻，
	// scheduler 工单⑨）——与实时 fire 不同，错过的刻度是事后补记的，若戴上 sweep 时刻，整夜停机的每条
	// missed 行都会自称发生在睡醒的同一秒。与 AppendFiring 同样按 dedup key 幂等：刻度已入账则返已存在行。
	AppendMissedFiring(ctx context.Context, f *Firing) (*Firing, error)
	ListPendingFirings(ctx context.Context, limit int) ([]*Firing, error)
	// SearchFirings pages a trigger's firing inbox (the disposition surface: started /
	// skipped / superseded / shed). SearchFirings 分页 trigger 的 firing 收件箱（处置面）。
	SearchFirings(ctx context.Context, filter FiringFilter) ([]*Firing, string, error)
	MarkFiringOutcome(ctx context.Context, firingID, status string) error

	// activation log (append-only; D1 no delete).
	// activation 日志（只增；D1 不删）。
	AppendActivation(ctx context.Context, a *Activation) error
	GetActivation(ctx context.Context, id string) (*Activation, error)
	SearchActivations(ctx context.Context, filter ActivationFilter) ([]*Activation, string, error)
	// LastFiredAt returns the created_at of a trigger's most recent FIRED activation (nil if it
	// never fired) — projected into List/Get rows. One indexed lookup (idx_tra_ws_trigger).
	//
	// LastFiredAt 返某 trigger 最近一条**已触发** activation 的 created_at（从未触发则 nil）——投影进
	// List/Get 行。一次走索引的查询（idx_tra_ws_trigger）。
	LastFiredAt(ctx context.Context, triggerID string) (*time.Time, error)
}
