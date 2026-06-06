package trigger

import (
	"context"
	"fmt"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
)

// Attach registers workflowID as a listener of triggerID. The first reference (0→1) starts
// the underlying source listener; subsequent references just join the fan-out set. This is
// the reference-counted lifecycle: N workflows sharing a trigger run ONE listener. Called by
// the scheduler on workflow activate (波次 4); on boot it replays every active reference.
//
// Attach 把 workflowID 注册为 triggerID 的监听者。首个引用（0→1）启动底层 source listener，后续引用
// 只加入扇出集。这就是引用计数生命周期：N 个 workflow 共享一个 trigger 只跑一个 listener。
func (s *Service) Attach(ctx context.Context, triggerID, workflowID string) error {
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
		if err := l.Register(triggerID, t.WorkspaceID, t.Config); err != nil {
			return fmt.Errorf("triggerapp.Attach: register %s: %w", triggerID, err)
		}
		e = &listenEntry{workspaceID: t.WorkspaceID, kind: t.Kind, workflows: make(map[string]bool)}
		s.listeners[triggerID] = e
	}
	e.workflows[workflowID] = true
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
	if len(e.workflows) == 0 {
		if l := s.listenerFor(e.kind); l != nil {
			l.Unregister(triggerID)
		}
		delete(s.listeners, triggerID)
	}
}

// attachRuntime fills the computed RefCount/Listening fields from the in-memory registry.
//
// attachRuntime 从内存监听表填充计算字段 RefCount/Listening。
func (s *Service) attachRuntime(t *triggerdomain.Trigger) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if e, ok := s.listeners[t.ID]; ok {
		t.RefCount = len(e.workflows)
		t.Listening = true
	}
}

// restartIfListening re-registers a hot trigger's listener with its new config (called on Edit).
//
// restartIfListening 用新 config 重注册正在监听的 trigger 的 listener（Edit 时调）。
func (s *Service) restartIfListening(t *triggerdomain.Trigger) {
	s.mu.RLock()
	e, ok := s.listeners[t.ID]
	ws := ""
	if ok {
		ws = e.workspaceID
	}
	s.mu.RUnlock()
	if !ok {
		return
	}
	if l := s.listenerFor(t.Kind); l != nil {
		if err := l.Register(t.ID, ws, t.Config); err != nil {
			s.log.Warn("triggerapp: re-register on edit failed", zapTrigger(t.ID), zapErr(err))
		}
	}
}
