// Package cron is the cron-listener implementation for the trigger
// domain. Wraps robfig/cron with a per-(workflowID,nodeID) registry and
// last-fired-at memory so the scheduler can recover missed ticks at boot
// (§6.2 missedPolicy=runOnce).
//
// Time zone is locked to time.Local per Plan 05 §6.10 (desktop app
// matches user laptop's TZ — sane default; V1.5 may add per-trigger
// override).
//
// Package cron 是 trigger 域的 cron-listener 实现。包 robfig/cron + per-
// (workflowID,nodeID) 注册表 + last-fired-at 内存(让 boot 时按 §6.2
// missedPolicy=runOnce 补漏触发)。时区锁 time.Local(§6.10)。
package cron

import (
	"fmt"
	"sync"
	"time"

	robfigcron "github.com/robfig/cron/v3"
	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
)

// OnFireFunc is called when a cron entry fires. The Listener doesn't
// know about scheduler — caller wires this to scheduler.StartRun.
//
// OnFireFunc 在 cron entry firing 时调;Listener 不知 scheduler,
// 由调用方接到 scheduler.StartRun。
type OnFireFunc func(workflowID, nodeID string, input map[string]any)

// Listener wraps robfig/cron with per-(workflowID,nodeID) keyed entries
// and last-fired-at tracking.
//
// Listener 包 robfig/cron + per-(workflowID,nodeID) entry + last-fire
// 跟踪。
type Listener struct {
	mu       sync.Mutex
	cron     *robfigcron.Cron
	entries  map[string]robfigcron.EntryID
	lastFire map[string]time.Time
	onFire   OnFireFunc
	log      *zap.Logger
}

// New constructs a Listener bound to time.Local. cron.Start must be
// called separately (caller decides timing).
//
// New 构造 Listener;时区锁 time.Local;cron.Start 由调用方决定何时调。
func New(log *zap.Logger, onFire OnFireFunc) *Listener {
	return &Listener{
		cron:     robfigcron.New(robfigcron.WithLocation(time.Local)),
		entries:  make(map[string]robfigcron.EntryID),
		lastFire: make(map[string]time.Time),
		onFire:   onFire,
		log:      log.Named("trigger.cron"),
	}
}

// Register adds a cron entry. spec.Config["expression"] is the 5-field
// cron string. Invalid expression → ErrInvalidCronExpression. Replaces
// any existing entry under the same (workflowID,nodeID) key.
//
// Plan 05 §6.2 missedPolicy=runOnce: if lastFire[key] is set and the
// last scheduled fire has already passed, fire one catch-up immediately
// via a goroutine (so Register stays quick).
//
// Register 加 cron entry;表达式无效返 ErrInvalidCronExpression;同 key
// 已存在则替换。
//
// §6.2 missedPolicy=runOnce:lastFire 已记+下次该 fire 时间已过时,
// 起 goroutine 立刻补 1 次。
func (l *Listener) Register(spec triggerdomain.Spec) error {
	expr, _ := spec.Config["expression"].(string)
	if expr == "" {
		return fmt.Errorf("triggercroninfra.Register: %w: empty expression", triggerdomain.ErrInvalidCronExpression)
	}

	schedule, parseErr := robfigcron.ParseStandard(expr)
	if parseErr != nil {
		return fmt.Errorf("triggercroninfra.Register: %w: %v", triggerdomain.ErrInvalidCronExpression, parseErr)
	}

	key := spec.WorkflowID + "/" + spec.NodeID

	l.mu.Lock()
	defer l.mu.Unlock()

	if existing, ok := l.entries[key]; ok {
		l.cron.Remove(existing)
		delete(l.entries, key)
	}

	if last, ok := l.lastFire[key]; ok {
		next := schedule.Next(last)
		if time.Now().After(next) {
			missedSince := last
			go l.onFire(spec.WorkflowID, spec.NodeID, map[string]any{
				"firedAt":     time.Now(),
				"missedSince": missedSince,
				"catchUp":     true,
			})
		}
	}

	id, addErr := l.cron.AddFunc(expr, func() {
		now := time.Now()
		l.mu.Lock()
		l.lastFire[key] = now
		l.mu.Unlock()
		// recover the per-tick goroutine so a panic in onFire doesn't
		// kill the global cron scheduler (§6.13).
		defer func() {
			if r := recover(); r != nil {
				l.log.Error("cron onFire panic",
					zap.String("workflowID", spec.WorkflowID),
					zap.String("nodeID", spec.NodeID),
					zap.Any("recover", r))
			}
		}()
		l.onFire(spec.WorkflowID, spec.NodeID, map[string]any{
			"firedAt": now,
		})
	})
	if addErr != nil {
		return fmt.Errorf("triggercroninfra.Register: %w: %v", triggerdomain.ErrInvalidCronExpression, addErr)
	}
	l.entries[key] = id
	return nil
}

// Unregister removes a cron entry; safe to call on unknown key.
//
// Unregister 删 cron entry;key 未知时 no-op。
func (l *Listener) Unregister(workflowID, nodeID string) {
	key := workflowID + "/" + nodeID
	l.mu.Lock()
	defer l.mu.Unlock()
	if id, ok := l.entries[key]; ok {
		l.cron.Remove(id)
		delete(l.entries, key)
	}
}

// Start begins the cron scheduler.
//
// Start 启动 cron scheduler。
func (l *Listener) Start() { l.cron.Start() }

// Stop halts the cron scheduler. In-flight fires finish; new ones don't
// start. Blocks until in-flight complete (robfig/cron contract).
//
// Stop 停 cron scheduler;in-flight fire 跑完后真停。
func (l *Listener) Stop() {
	ctx := l.cron.Stop()
	<-ctx.Done()
}

// State returns the current state for one (workflowID,nodeID) trigger.
// Status is "active" when registered, "idle" when not. Plan 05 §6.12.
//
// State 返某 (workflowID,nodeID) 触发器当前状态(§6.12)。
func (l *Listener) State(workflowID, nodeID string) triggerdomain.State {
	key := workflowID + "/" + nodeID
	l.mu.Lock()
	defer l.mu.Unlock()
	state := triggerdomain.State{
		WorkflowID: workflowID,
		NodeID:     nodeID,
		Kind:       triggerdomain.KindCron,
		Status:     triggerdomain.StateIdle,
	}
	if last, ok := l.lastFire[key]; ok {
		t := last
		state.LastFiredAt = &t
	}
	if id, ok := l.entries[key]; ok {
		entry := l.cron.Entry(id)
		next := entry.Next
		state.NextFireAt = &next
		state.Status = triggerdomain.StateActive
	}
	return state
}
