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
	// SaveTrigger persists a WHOLE trigger row (upsert on the pk) — the Create path. It is NOT the
	// Edit path: the upsert writes every column from the in-memory struct, including the RUNTIME
	// ones (paused / missed_checked_at), which an Edit only ever holds a stale read-time copy of.
	// Use EditTrigger to patch an existing trigger.
	//
	// SaveTrigger 持久化**整行** trigger（按 pk upsert）——Create 径。**不是** Edit 径：upsert 会把
	// 内存结构里的每一列都写下去，含**运行时**列（paused / missed_checked_at），而 Edit 手上只有它们
	// 读时的陈旧拷贝。改已存在的 trigger 用 EditTrigger。
	SaveTrigger(ctx context.Context, t *Trigger) error
	// EditTrigger patches ONLY the author-editable entity columns (name/description/config/outputs)
	// of an existing trigger — a targeted UPDATE, never a whole-row upsert. The runtime axis
	// (paused, 工单⑦ · missed_checked_at, 工单⑨) belongs to SetTriggerPaused / AdvanceMissedWatermark
	// alone: Edit reads the row, validates, then writes, and a :pause (or a cron fan-out advancing
	// the watermark) landing inside that window would be silently undone by an upsert carrying the
	// read-time copies back to disk — the stop-the-bleeding switch would flip itself back on, across
	// restarts, with nothing in the log. ErrDuplicateName on a rename collision; ErrNotFound on miss.
	//
	// EditTrigger 只改已存在 trigger 的**作者可编辑**实体列（name/description/config/outputs）——定点
	// UPDATE、绝非整行 upsert。运行时轴（paused，工单⑦ · missed_checked_at，工单⑨）**只**归
	// SetTriggerPaused / AdvanceMissedWatermark：Edit 是「读→校验→写」，其间落地的 `:pause`（或推进
	// 水位的 cron 扇出）会被带着读时拷贝的 upsert 静默抹掉——止血开关自己弹回去、且跨重启永久丢失、
	// 日志里一声不吭。改名撞车 ErrDuplicateName；未命中 ErrNotFound。
	EditTrigger(ctx context.Context, t *Trigger) error
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
	// RequeueMissedFiring flips a `missed` firing back to `pending` — the ONE way a booked miss
	// becomes a run, guarded on the row still being `missed` so it can never resurrect one that
	// already ran. Two callers, one meaning ("this tick is going to run after all, the `missed`
	// verdict is overturned"): catchup_one, which deliberately runs the most recent miss it just
	// booked; and a fan-out whose dedup key turns out to be held by a missed row — the sweep called
	// it too early and the real fire arrived anyway, so the row must become the run instead of the
	// fire silently evaporating into a dedup hit (工单⑨). 0 rows matched = already requeued by an
	// identical concurrent fan-out, a harmless no-op.
	// It also stamps the requeued row with the fan-out's activationID: the sweep books a missed row
	// with NO activation (booking is not an action, it is bookkeeping), so without this the run's
	// firing would point at nothing while its activation reports a firingCount — the audit trail
	// would dead-end on exactly the path catchup_one makes ordinary.
	//
	// RequeueMissedFiring 把 `missed` firing 翻回 `pending`——已记账的错过变成 run 的**唯一**途径，
	// 以「行仍是 missed」为守卫，故绝不可能把已经跑过的行救活。两个调用方、同一个含义（「这个刻度终究
	// 要跑，`missed` 的判词被推翻」）：catchup_one 刻意补跑它刚记的最近一个错过点；以及 dedup 键恰好
	// 被 missed 行占住的扇出——sweep 判早了、真 fire 还是来了，那这行就该变成那次 run，而不是让 fire
	// 静默蒸发成一次去重命中（工单⑨）。匹配 0 行 = 并发的同款扇出已救过，无害 no-op。
	// 它同时给被救的行盖上本次扇出的 activationID：sweep 记 missed 行时**不带 activation**（记账不是一次
	// 动作），故若不盖，这次 run 的 firing 会指向虚空、而它的 activation 却报着 firingCount——审计链恰在
	// catchup_one 让其成为日常的那条径上断掉。
	RequeueMissedFiring(ctx context.Context, firingID, activationID string) error
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
