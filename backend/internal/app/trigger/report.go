package trigger

import (
	"context"
	"strconv"
	"time"

	"go.uber.org/zap"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// onReport is the ReportFunc handed to every listener. A listener only knows "my trigger did
// X"; here the app resolves the trigger's workspace + listening workflows and turns the
// report into an Activation (always) plus, when Fired, one Firing per workflow (fan-out).
// A report racing in after Detach (listeners entry gone) or after Pause (entry marked paused —
// the unregister may land a beat behind, scheduler 工单⑦) is dropped.
//
// onReport 是交给每个 listener 的 ReportFunc。listener 只知"我这个 trigger 做了 X"；app 在此解析 trigger
// 的 workspace + 监听 workflow，把报告变成 Activation（总是）+ Fired 时每 workflow 一条 Firing（扇出）。
// Detach 后（entry 已删）或 Pause 后（entry 已标暂停——unregister 可能慢半拍落地，scheduler 工单⑦）
// 抢进来的报告一律丢弃。
func (s *Service) onReport(triggerID string, act triggerinfra.Activity) {
	s.mu.RLock()
	e, ok := s.listeners[triggerID]
	if !ok || e.paused {
		s.mu.RUnlock()
		return // detached / paused mid-flight — drop. 半途被摘 / 被暂停——丢弃。
	}
	gate := e.reportGate
	s.mu.RUnlock()
	// Admit the report while the registry read lock is held. Detach cannot remove the entry before
	// this read-side gate is acquired; after the snapshot it waits on the write side before returning.
	// Gate is acquired before the second registry read so a detach writer cannot strand a report
	// while holding the registry lock.
	// 先确认 entry，再拿 report 读侧 gate，随后重新读 registry；Detach writer 不会在持有 registry 锁时等
	// gate，故不会把 report 卡在锁序环里。快照之后它会在返回前等写侧 gate。
	gate.RLock()
	s.mu.RLock()
	e, ok = s.listeners[triggerID]
	if !ok || e.paused {
		s.mu.RUnlock()
		gate.RUnlock()
		return // detached / paused while acquiring the gate — drop.
	}
	wsID, kind := e.workspaceID, e.kind
	workflows := make([]string, 0, len(e.workflows))
	for wf := range e.workflows {
		workflows = append(workflows, wf)
	}
	s.mu.RUnlock()
	defer gate.RUnlock()

	// Detached context seeded with the trigger's workspace — the listener fired off-request.
	// Detached ctx 种入 trigger 的 workspace——listener 在请求之外触发。
	ctx := reqctxpkg.Detached(wsID)
	_ = s.fanOut(ctx, triggerID, kind, workflows, act)

	// A delivered cron tick is ACCOUNTED — advance the misfire watermark past it (scheduler 工单⑨)
	// so the sweep never re-books a tick that really fired. Done after the fan-out: the firing rows
	// are the durable truth, and a crash between them and this write only costs a re-check whose
	// dedup key already exists (AppendFiring is idempotent).
	//
	// 已送达的 cron 刻度即**已入账**——把 misfire 水位推过它（scheduler 工单⑨），使 sweep 绝不重记真
	// fire 过的刻度。放在扇出之后：firing 行才是耐久真相，两者之间崩溃只损失一次复查、而其 dedup 键已
	// 存在（AppendFiring 幂等）。
	if kind == triggerdomain.KindCron && act.Fired {
		if err := s.repo.AdvanceMissedWatermark(ctx, triggerID, time.Now()); err != nil {
			s.log.Warn("triggerapp: advance misfire watermark", zapTrigger(triggerID), zapErr(err))
		}
	}
}

// fanOut writes one Activation (always) and, when the activity fired, one Firing per listening
// workflow (each sharing the activity's dedup key so a re-materialized fire dedups per
// workflow). The Activation is minted first so every Firing references it.
//
// The RETURN VALUE of AppendFiring is the contract here, not the absence of an error: the dedup key
// may already be taken (idx_trf_dedup), in which case AppendFiring hands back the EXISTING row and
// nil — a nil error means "the key is accounted for", never "your fire produced a run". So each
// outcome is read off the row's status:
//   - pending — a new row, or one already waiting: this fire is runnable. Count it.
//   - missed — the misfire sweep called this tick a miss and the fire arrived anyway (the sweep
//     ruled too early, or a catchup_one deliberately fires the tick it just booked). Overturn the
//     verdict: requeue the row so the run really happens. Counting it while leaving it `missed` is
//     precisely the lie this fixes — firingCount would say 1, the ledger would say "never ran", and
//     the workflow would never run (工单⑨).
//   - anything terminal (claimed/started/skipped/superseded/shed) — the tick already reached a
//     disposition; a re-materialized fire adds no run, so it must not inflate firingCount either.
//
// fanOut 写一条 Activation（总是），动作触发时每监听 workflow 一条 Firing（共享 dedup key，使重复材化
// 按 workflow 去重）。先 mint Activation 使每条 Firing 都能反指它。
//
// 此处的契约是 AppendFiring 的**返回值**、不是「没报错」：dedup 键可能已被占（idx_trf_dedup），那时
// AppendFiring 交回**已存在**的行 + nil——nil 错误的意思是「这个键已有着落」，从来不是「你这次 fire 产生了
// 一次 run」。故逐个结局按行的 status 读：
//   - pending —— 新行，或已在等的行：本次 fire 可跑。计数。
//   - missed —— misfire sweep 判了这个刻度错过、而 fire 还是来了（sweep 判早了；或 catchup_one 刻意补跑
//     它刚记的那个刻度）。**推翻判词**：把行救回队列，让 run 真的发生。若一边计数一边把它留在 `missed`，
//     那正是本处所修的谎——firingCount 说 1、台账说「从未跑」、而 workflow 永远不跑（工单⑨）。
//   - 任一终态（claimed/started/skipped/superseded/shed）—— 该刻度已有处置；重复材化的 fire 不产生
//     任何 run，故也绝不许把 firingCount 撑大。
func (s *Service) fanOut(ctx context.Context, triggerID, kind string, workflows []string, act triggerinfra.Activity) string {
	actID := idgenpkg.New("tra")
	fired := 0
	if act.Fired {
		// Claim staged workflows BEFORE the durable append. Two source reports can carry the same
		// listener snapshot; claiming first gives exactly one of them the one-shot budget. The
		// claimed set is retained for this fan-out even though claimOneShots removes the listener
		// entries, while a stale concurrent snapshot is filtered out below.
		claimed := s.claimOneShots(triggerID, workflows)
		workflows = s.activeFanOutWorkflows(triggerID, workflows, claimed)
		dedup := act.DedupKey
		if dedup == "" {
			dedup = triggerID + "|" + strconv.FormatInt(time.Now().UnixNano(), 10)
		}
		for _, wfID := range workflows {
			f, err := s.repo.AppendFiring(ctx, &triggerdomain.Firing{
				TriggerID:    triggerID,
				WorkflowID:   wfID,
				ActivationID: actID,
				Payload:      act.Payload,
				DedupKey:     dedup,
			})
			if err != nil {
				s.log.Warn("triggerapp: append firing failed", zapTrigger(triggerID), zap.String("workflowId", wfID), zapErr(err))
				continue
			}
			if f.Status == triggerdomain.FiringMissed {
				if err := s.repo.RequeueMissedFiring(ctx, f.ID, actID); err != nil {
					s.log.Warn("triggerapp: requeue missed firing failed", zapTrigger(triggerID), zap.String("workflowId", wfID), zapErr(err))
					continue
				}
				s.log.Info("triggerapp: a fire landed on a tick booked missed — requeued it as the run",
					zapTrigger(triggerID), zap.String("workflowId", wfID), zap.String("firingId", f.ID))
				f.Status = triggerdomain.FiringPending
			}
			if f.Status != triggerdomain.FiringPending {
				continue // already dispositioned — this fire mints no run, so it counts as none.
			}
			fired++
		}
	}
	if err := s.repo.AppendActivation(ctx, &triggerdomain.Activation{
		ID:          actID,
		TriggerID:   triggerID,
		Kind:        kind,
		Fired:       act.Fired,
		ReturnValue: act.ReturnValue,
		Payload:     act.Payload,
		Error:       act.Error,
		Detail:      act.Detail,
		FiringCount: fired,
	}); err != nil {
		s.log.Warn("triggerapp: append activation failed", zapTrigger(triggerID), zapErr(err))
	}

	// SSE-C: every fan-out (all sources — cron/webhook/fsnotify/sensor/manual — pass through
	// here) emits one fire signal scoped to the trigger, so the trigger panel shows its activity
	// live. Durable record = the Activation/Firing rows; this is the live view.
	//
	// SSE-C：每次扇出（所有来源——cron/webhook/fsnotify/sensor/manual——都经此处）发一条 trigger scope 的
	// fire 信号，使 trigger 面板实时显示活动。耐久记录 = Activation/Firing 行；这是 live 视图。
	// ephemeral=true：Activation/Firing 行是重连真相，fire 信号仅 live 视图、不占 replay 环(E2)。
	entitystreamapp.Signal(ctx, s.entities, streamdomain.Scope{Kind: streamdomain.KindTrigger, ID: triggerID},
		entitystreamapp.NodeFire, streamdomain.JSONContent(map[string]any{
			"activationId": actID,
			"kind":         kind,
			"fired":        act.Fired,
			"firingCount":  fired,
			"error":        act.Error,
		}), true)
	return actID
}

// FireManual fires a trigger by hand (the fire_trigger tool / a test "ping it now"): it
// fans out to whatever workflows currently listen (possibly none — then it's just a recorded
// Activation with 0 firings). A PAUSED trigger refuses loudly (422 TRIGGER_PAUSED) — pause means
// "no new firings, period"; a manual fire slipping past the switch would betray it, and a silent
// no-op would read as "fired but nothing ran" (scheduler 工单⑦).
//
// FireManual 手动触发一次（fire_trigger 工具 / 测试"立刻催它"）：扇给当前监听的 workflow（可能没有——
// 那就只是一条 0 firing 的 Activation 记录）。**已暂停**的 trigger 大声拒（422 TRIGGER_PAUSED）——
// 暂停 = 一个新 firing 都不许；手动 fire 绕过开关即背叛暂停，静默 no-op 则会被读作「触发了但没跑」
// （scheduler 工单⑦）。
func (s *Service) FireManual(ctx context.Context, triggerID string) (string, error) {
	t, err := s.repo.GetTrigger(ctx, triggerID)
	if err != nil {
		return "", err
	}
	if t.Paused {
		return "", triggerdomain.ErrPaused
	}
	release, workflows := s.admitFanOut(triggerID)
	defer release()
	// NOTE: a manual :fire deliberately does NOT advance the misfire watermark — it is not a
	// scheduled tick, so it accounts for nothing on the cron timeline (工单⑨).
	// 注：手动 :fire 刻意**不**推水位——它不是调度刻度，在 cron 时间线上什么都没入账（工单⑨）。
	actID := s.fanOut(ctx, triggerID, t.Kind, workflows, triggerinfra.Activity{
		Fired:    true,
		Payload:  map[string]any{"manual": true},
		DedupKey: triggerID + "|manual|" + strconv.FormatInt(time.Now().UnixNano(), 10),
	})
	return actID, nil
}

// admitFanOut snapshots the currently listening workflows and holds the trigger's report read
// gate until the caller's fan-out has fully written its durable rows. It is used by manual fires as
// well as listener reports: :deactivate must fence both sources of accepted work.
//
// admitFanOut 快照当前监听 workflow，并持有 trigger 的 report 读侧 gate，直到调用方完成 durable 行扇出。
// 手动 fire 与 listener report 都走它：`:deactivate` 必须 fence 两种已接受工作来源。
func (s *Service) admitFanOut(triggerID string) (func(), []string) {
	// Acquire the report gate before the registry lock. Detach releases s.mu before waiting on the
	// gate; reversing this order could deadlock a report that needs s.mu for a one-shot claim while a
	// new manual fire waits for the gate.
	// 先拿 report gate 再拿 registry 锁。Detach 会先释放 s.mu 再等 gate；反过来会让需要 s.mu 做 one-shot
	// claim 的旧 report 与等待 gate 的新 manual fire 互相死锁。
	s.mu.RLock()
	gate := s.reportGates[triggerID]
	s.mu.RUnlock()
	if gate == nil {
		s.mu.Lock()
		gate = s.reportGateLocked(triggerID)
		s.mu.Unlock()
	}
	gate.RLock()
	s.mu.RLock()
	var workflows []string
	if e, ok := s.listeners[triggerID]; ok && !e.paused {
		workflows = make([]string, 0, len(e.workflows))
		for wf := range e.workflows {
			workflows = append(workflows, wf)
		}
	}
	s.mu.RUnlock()
	return gate.RUnlock, workflows
}

// admitListeningSince is the misfire-sweep variant of admitFanOut; it preserves each workflow's
// attach epoch while fencing the subsequent catch-up fan-out against Detach.
//
// admitListeningSince 是 misfire sweep 的 admitFanOut 变体；保留 workflow 挂载纪元，并用 gate fence
// 后续 catch-up 扇出与 Detach 的交错。
func (s *Service) admitListeningSince(triggerID string) (func(), map[string]time.Time) {
	s.mu.RLock()
	gate := s.reportGates[triggerID]
	s.mu.RUnlock()
	if gate == nil {
		s.mu.Lock()
		gate = s.reportGateLocked(triggerID)
		s.mu.Unlock()
	}
	gate.RLock()
	s.mu.RLock()
	listeners := map[string]time.Time{}
	if e, ok := s.listeners[triggerID]; ok && !e.paused {
		listeners = make(map[string]time.Time, len(e.workflows))
		for wf, since := range e.workflows {
			listeners[wf] = since
		}
	}
	s.mu.RUnlock()
	return gate.RUnlock, listeners
}

// listeningSince returns the workflows currently attached to triggerID with each one's attach epoch
// (zero = listening since before this process) — the misfire sweep's per-workflow lower bound
// (scheduler 工单⑨). Absent entry (not listening) → nil, and the sweep skips the trigger entirely.
//
// listeningSince 返回当前挂在 triggerID 上的 workflow 及各自的挂载纪元（零值 = 本进程之前就在监听）——
// misfire sweep 的 per-workflow 下界（scheduler 工单⑨）。entry 不存在（未监听）→ nil，sweep 整个跳过该 trigger。
func (s *Service) listeningSince(triggerID string) map[string]time.Time {
	s.mu.RLock()
	defer s.mu.RUnlock()
	e, ok := s.listeners[triggerID]
	if !ok || e.paused {
		return nil
	}
	out := make(map[string]time.Time, len(e.workflows))
	for wf, since := range e.workflows {
		out[wf] = since
	}
	return out
}

// claimOneShots atomically claims every one-shot (staged) workflow among `workflows` that just
// received this fire — across ALL trigger entries for that workflow, not only the source that
// fired. Stage arms every entry of a multi-trigger workflow as one trial budget: the first source
// to fire consumes that budget and must disarm the other sources too. Claiming happens before the
// durable append so two concurrent reports cannot both spend the same budget. The returned set is
// allowed to pass through the current fan-out even though its listener entries were removed.
//
// claimOneShots 摘掉 `workflows` 中刚收到本次扇出的每个一次性（试运行）workflow——**跨该 workflow
// 的全部 trigger entry**，不只当前发火的 source。多入口 workflow 的 stage 把所有入口视为一个试跑额度：
// 第一条 source 发火即消耗额度，其他 source 也必须撤防。claim 在 durable append **之前**完成，故两个
// 并发报告不能同时花掉同一额度；返回集合允许当前 fan-out 继续走，即使 listener entry 已被摘掉。
func (s *Service) claimOneShots(triggerID string, workflows []string) map[string]bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	entry, ok := s.listeners[triggerID]
	if !ok || entry.paused {
		return nil
	}
	// Only workflows marked one-shot on the source that fired can be claimed by this report. This
	// prevents a continuous listener that merely shares another entry from being detached.
	claim := make(map[string]bool, len(workflows))
	for _, wf := range workflows {
		if entry.once[wf] {
			claim[wf] = true
		}
	}
	if len(claim) == 0 {
		return nil
	}
	// A multi-trigger stage has one budget. Remove each claimed workflow from every entry while the
	// registry lock is held, so another report cannot snapshot a second live one-shot in between.
	for ref, e := range s.listeners {
		for wf := range claim {
			if !e.once[wf] {
				continue
			}
			delete(e.once, wf)
			delete(e.workflows, wf)
		}
		if len(e.workflows) == 0 {
			if l := s.listenerFor(e.kind); l != nil {
				l.Unregister(ref)
			}
			delete(s.listeners, ref)
		}
	}
	return claim
}

// activeFanOutWorkflows filters a listener snapshot against the current registry. A concurrent
// one-shot claim removes stale snapshots from the source that lost the race, while the winner's
// claimed set lets its own in-flight report proceed once. Continuous listeners are retained only
// while the source is still live and not paused.
func (s *Service) activeFanOutWorkflows(triggerID string, workflows []string, claimed map[string]bool) []string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	entry, ok := s.listeners[triggerID]
	active := make([]string, 0, len(workflows))
	for _, wf := range workflows {
		if claimed[wf] || (ok && !entry.paused && hasWorkflow(entry, wf)) {
			active = append(active, wf)
		}
	}
	return active
}

func hasWorkflow(entry *listenEntry, workflowID string) bool {
	_, ok := entry.workflows[workflowID]
	return ok
}

func zapTrigger(id string) zap.Field { return zap.String("triggerId", id) }
func zapErr(err error) zap.Field     { return zap.Error(err) }
