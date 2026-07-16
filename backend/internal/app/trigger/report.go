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
	wsID, kind := e.workspaceID, e.kind
	workflows := make([]string, 0, len(e.workflows))
	for wf := range e.workflows {
		workflows = append(workflows, wf)
	}
	s.mu.RUnlock()

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
// fanOut 写一条 Activation（总是），动作触发时每监听 workflow 一条 Firing（共享 dedup key，使重复材化
// 按 workflow 去重）。先 mint Activation 使每条 Firing 都能反指它。
func (s *Service) fanOut(ctx context.Context, triggerID, kind string, workflows []string, act triggerinfra.Activity) string {
	actID := idgenpkg.New("tra")
	fired := 0
	if act.Fired {
		dedup := act.DedupKey
		if dedup == "" {
			dedup = triggerID + "|" + strconv.FormatInt(time.Now().UnixNano(), 10)
		}
		for _, wfID := range workflows {
			if _, err := s.repo.AppendFiring(ctx, &triggerdomain.Firing{
				TriggerID:    triggerID,
				WorkflowID:   wfID,
				ActivationID: actID,
				Payload:      act.Payload,
				DedupKey:     dedup,
			}); err != nil {
				s.log.Warn("triggerapp: append firing failed", zapTrigger(triggerID), zap.String("workflowId", wfID), zapErr(err))
				continue
			}
			fired++
		}
		// stage_workflow: a one-shot listener fires exactly once, then auto-disarms.
		// stage_workflow：一次性监听者只扇出一次，随即自动撤防。
		s.detachOneShots(triggerID, workflows)
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
	s.mu.RLock()
	var workflows []string
	if e, ok := s.listeners[triggerID]; ok {
		for wf := range e.workflows {
			workflows = append(workflows, wf)
		}
	}
	s.mu.RUnlock()
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

// detachOneShots drops every one-shot (staged) workflow among `workflows` that just received this
// fire — read the once set under the lock, then Detach each (Detach re-locks). A staged arm thus
// runs on exactly the next fire, then disarms (possibly taking the listener 1→0 and stopping it).
//
// detachOneShots 摘掉 `workflows` 中刚收到本次扇出的每个一次性（试运行）workflow——在锁内读 once 集，
// 再逐个 Detach（Detach 自己重新加锁）。一个试运行待命因此恰在下一次扇出时运行、随即撤防（可能把 listener
// 1→0 停掉）。
func (s *Service) detachOneShots(triggerID string, workflows []string) {
	s.mu.RLock()
	var drop []string
	if e, ok := s.listeners[triggerID]; ok {
		for _, wf := range workflows {
			if e.once[wf] {
				drop = append(drop, wf)
			}
		}
	}
	s.mu.RUnlock()
	for _, wf := range drop {
		s.Detach(triggerID, wf)
	}
}

func zapTrigger(id string) zap.Field { return zap.String("triggerId", id) }
func zapErr(err error) zap.Field     { return zap.Error(err) }
