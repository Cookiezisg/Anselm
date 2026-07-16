package trigger

import (
	"context"
	"fmt"
	"time"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	croninfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/cron"
)

// Attach registers workflowID as a listener of triggerID. The first reference (0→1) starts
// the underlying source listener; subsequent references just join the fan-out set. This is
// the reference-counted lifecycle: N workflows sharing a trigger run ONE listener. Called by
// the workflow service on activate; on boot it replays every active reference.
//
// Attach 把 workflowID 注册为 triggerID 的监听者。首个引用（0→1）启动底层 source listener，后续引用
// 只加入扇出集。这就是引用计数生命周期：N 个 workflow 共享一个 trigger 只跑一个 listener。workflow
// service 在 activate 时调；boot 时重放每个 active 引用。
func (s *Service) Attach(ctx context.Context, triggerID, workflowID string) error {
	return s.attach(ctx, triggerID, workflowID, false)
}

// AttachOnce registers workflowID as a ONE-SHOT listener of triggerID (stage_workflow): it joins
// the fan-out exactly like Attach, but fanOut drops it after its single fire. Same ref-counted
// listener (0→1 starts it; its later auto-detach may take it 1→0 and stop it). A workflow already
// attached (active) being staged is harmless — it just gains the one-shot mark; the workflow service
// guards that case (ErrAlreadyActive) before reaching here.
//
// AttachOnce 把 workflowID 注册为 triggerID 的**一次性**监听者（stage_workflow）：与 Attach 一样加入扇出，
// 但 fanOut 在其单次扇出后摘掉它。同一引用计数 listener（0→1 启动；其后的自动 Detach 可能把它 1→0 停掉）。
func (s *Service) AttachOnce(ctx context.Context, triggerID, workflowID string) error {
	return s.attach(ctx, triggerID, workflowID, true)
}

// attach is the shared body: ensure the listener is hot, then add workflowID to the fan-out set
// (and, when once, to the one-shot set). A PAUSED trigger (scheduler 工单⑦) still tracks its
// references — the entry is created with paused=true and Register is skipped — so a boot replay
// (ReattachActive) keeps a paused trigger paused across restarts, and Resume can re-register from
// the surviving reference set.
//
// attach 是共用体：确保 listener 已热，再把 workflowID 加进扇出集（once 时还加进一次性集）。
// **已暂停**的 trigger（scheduler 工单⑦）仍记引用——entry 以 paused=true 建、跳过 Register——使 boot
// 重放（ReattachActive）让暂停跨重启仍暂停，Resume 也能凭存活的引用集重注册。
func (s *Service) attach(ctx context.Context, triggerID, workflowID string, once bool) error {
	t, err := s.repo.GetTrigger(ctx, triggerID)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.listeners[triggerID]
	if !ok {
		l := s.listenerFor(t.Kind)
		if l == nil {
			return triggerdomain.ErrInvalidKind
		}
		if !t.Paused {
			if err := l.Register(triggerID, t.WorkspaceID, t.Config); err != nil {
				return fmt.Errorf("triggerapp.attach: register %s: %w", triggerID, err)
			}
		}
		e = &listenEntry{workspaceID: t.WorkspaceID, kind: t.Kind, workflows: make(map[string]bool), once: make(map[string]bool), paused: t.Paused}
		s.listeners[triggerID] = e
	}
	e.workflows[workflowID] = true
	if once {
		e.once[workflowID] = true
	}
	return nil
}

// Detach removes workflowID's reference to triggerID. The last reference (1→0) stops the
// underlying listener. No-op when the reference is absent.
//
// Detach 移除 workflowID 对 triggerID 的引用。最后一个引用（1→0）停掉底层 listener。
func (s *Service) Detach(triggerID, workflowID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.listeners[triggerID]
	if !ok {
		return
	}
	delete(e.workflows, workflowID)
	delete(e.once, workflowID)
	if len(e.workflows) == 0 {
		if l := s.listenerFor(e.kind); l != nil {
			l.Unregister(triggerID)
		}
		delete(s.listeners, triggerID)
	}
}

// attachRuntime fills the computed RefCount/Listening fields from the in-memory registry. A
// paused entry keeps its RefCount but reads Listening=false — the source listener really is
// unregistered (scheduler 工单⑦).
//
// attachRuntime 从内存监听表填充计算字段 RefCount/Listening。暂停的 entry 保留 RefCount 但
// Listening=false——底层 listener 真的已注销（scheduler 工单⑦）。
func (s *Service) attachRuntime(t *triggerdomain.Trigger) {
	s.mu.RLock()
	if e, ok := s.listeners[t.ID]; ok {
		t.RefCount = len(e.workflows)
		t.Listening = !e.paused
	}
	s.mu.RUnlock()
	// Project the next scheduled fire for a cron trigger (read-time, like LastFiredAt) so the UI can
	// show "next fire in N". Best-effort: a non-cron kind or unparseable expr leaves it nil. A paused
	// trigger projects nil — nothing IS scheduled (its cron entry is removed), so a timestamp would lie.
	//
	// 对 cron 触发器投影下次调度触发时刻（读时派生，类比 LastFiredAt），使 UI 可显示「N 后触发」。
	// best-effort：非 cron 或 expr 不可解析则留 nil。暂停时投影 nil——根本没有排程（cron entry 已摘），
	// 给时间戳就是撒谎。
	if t.Kind == triggerdomain.KindCron && !t.Paused {
		if next, err := croninfra.NextAfter(triggerdomain.CronExpression(t.Config), time.Now()); err == nil {
			t.NextFireAt = &next
		}
	}
}

// restartIfListening re-registers a hot trigger's listener with its new config (called on Edit).
// A paused entry is skipped — its listener is deliberately unregistered; the new config takes
// effect on Resume (which re-reads the trigger).
//
// restartIfListening 用新 config 重注册正在监听的 trigger 的 listener（Edit 时调）。暂停的 entry
// 跳过——其 listener 是刻意注销的；新 config 在 Resume（重读 trigger）时生效。
func (s *Service) restartIfListening(t *triggerdomain.Trigger) {
	s.mu.RLock()
	e, ok := s.listeners[t.ID]
	ws, paused := "", false
	if ok {
		ws, paused = e.workspaceID, e.paused
	}
	s.mu.RUnlock()
	if !ok || paused {
		return
	}
	if l := s.listenerFor(t.Kind); l != nil {
		if err := l.Register(t.ID, ws, t.Config); err != nil {
			s.log.Warn("triggerapp: re-register on edit failed", zapTrigger(t.ID), zapErr(err))
		}
	}
}

// Pause is the runtime stop-the-bleeding switch (:pause, scheduler 工单⑦): persist paused=true,
// then unregister the underlying source listener AT THE SOURCE (cron entry removed / webhook path
// 404s / fs watch stopped / sensor probes stopped) while keeping the reference set — the workflow
// side stays untouched, so Resume restores exactly what listened before. In-flight runs and
// already-pending firings are deliberately unaffected (they are pre-pause events; the scheduler
// drains them normally). Idempotent: pausing a paused trigger is a harmless no-op (200).
//
// Pause 是运行时止血开关（:pause，scheduler 工单⑦）：先持久化 paused=true，再**在源头**注销底层
// source listener（cron 摘 entry / webhook 路径 404 / fs watch 停 / sensor 探测停），引用集保留——
// workflow 侧不动，Resume 原样恢复此前的监听。在途 run 与已 pending 的 firing 刻意不受影响（它们是
// 暂停前的事件；scheduler 照常消化）。幂等：暂停已暂停的无害 no-op（200）。
func (s *Service) Pause(ctx context.Context, id string) (*triggerdomain.Trigger, error) {
	t, err := s.repo.GetTrigger(ctx, id)
	if err != nil {
		return nil, err
	}
	changed := !t.Paused
	if changed {
		if err := s.repo.SetTriggerPaused(ctx, id, true); err != nil {
			return nil, err
		}
		t.Paused = true
	}
	s.mu.Lock()
	if e, ok := s.listeners[id]; ok && !e.paused {
		e.paused = true
		if l := s.listenerFor(e.kind); l != nil {
			l.Unregister(id)
		}
	}
	s.mu.Unlock()
	if changed {
		s.signalPaused(ctx, id, true)
	}
	s.attachRuntime(t)
	if lf, lerr := s.repo.LastFiredAt(ctx, t.ID); lerr == nil {
		t.LastFiredAt = lf
	}
	return t, nil
}

// Resume flips the switch back (:resume): persist paused=false, then — if any active workflow
// still references the trigger — re-register the source listener with the CURRENT config (an Edit
// made while paused takes effect here). With no references it just clears the flag; the next
// workflow activation registers as usual. Idempotent like Pause.
//
// Resume 把开关翻回（:resume）：先持久化 paused=false，再——若仍有 active workflow 引用——用**当前**
// config 重注册 source listener（暂停期间的 Edit 在此生效）。无引用则只清标志，下次 workflow 激活照常
// 注册。与 Pause 同样幂等。
func (s *Service) Resume(ctx context.Context, id string) (*triggerdomain.Trigger, error) {
	t, err := s.repo.GetTrigger(ctx, id)
	if err != nil {
		return nil, err
	}
	changed := t.Paused
	if changed {
		if err := s.repo.SetTriggerPaused(ctx, id, false); err != nil {
			return nil, err
		}
		t.Paused = false
	}
	s.mu.Lock()
	var regErr error
	if e, ok := s.listeners[id]; ok && e.paused {
		e.paused = false
		if l := s.listenerFor(e.kind); l != nil {
			regErr = l.Register(id, e.workspaceID, t.Config)
		}
	}
	s.mu.Unlock()
	if regErr != nil {
		// The persisted switch is already off — honest state: the next boot/activation retries the
		// register. Surface the failure loudly rather than pretending the listener is hot.
		// 持久开关已关——状态诚实：下次 boot/激活会重试注册。大声上抛，不假装 listener 已热。
		return nil, fmt.Errorf("triggerapp.Resume: register %s: %w", id, regErr)
	}
	if changed {
		s.signalPaused(ctx, id, false)
	}
	s.attachRuntime(t)
	if lf, lerr := s.repo.LastFiredAt(ctx, t.ID); lerr == nil {
		t.LastFiredAt = lf
	}
	return t, nil
}

// signalPaused pushes the pause transition as an EPHEMERAL entities-stream status signal (the live
// ⏸ badge nudge), mirroring the mcp status precedent: the triggers.paused row (GET /triggers) is
// the reconnect truth, so the signal never needs the replay ring — and deliberately NOT a durable
// notification (trigger has no lifecycle notifications; the bell stays quiet).
//
// signalPaused 把暂停转移作为 **ephemeral** entities 流 status 信号推出（实时 ⏸ 徽章推送），照 mcp
// status 先例：triggers.paused 行（GET /triggers）是重连真相，信号不占 replay 环——刻意**非** durable
// 通知（trigger 无生命周期通知；铃铛保持安静）。
func (s *Service) signalPaused(ctx context.Context, id string, paused bool) {
	entitystreamapp.Signal(ctx, s.entities,
		streamdomain.Scope{Kind: streamdomain.KindTrigger, ID: id},
		"status",
		streamdomain.JSONContent(map[string]any{"paused": paused}),
		true)
}
