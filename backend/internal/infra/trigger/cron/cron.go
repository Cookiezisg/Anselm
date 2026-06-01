// Package cron is the cron-listener for the trigger domain (wraps robfig/cron).
//
// Package cron 是 trigger 域的 cron-listener（封装 robfig/cron）。
package cron

import (
	"fmt"
	"strconv"
	"sync"
	"time"

	robfigcron "github.com/robfig/cron/v3"
	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
)

// OnFireFunc is invoked when a cron entry fires; caller wires it to the durable firing inbox. dedupKey
// is the trigger's natural idempotency key: cron keys it on the SCHEDULED TICK (so a missed-tick
// catch-up that re-materializes an already-fired tick dedups against it, not a fresh wall-clock fire).
//
// OnFireFunc 在 cron entry 触发时调用;dedupKey 是该触发的天然幂等键 —— cron 按**调度刻度**算,
// 使补跑(re-materialize)同一刻度时与已触发的去重(而非按 wall-clock 各算一份)。
type OnFireFunc func(workflowID, nodeID string, input map[string]any, dedupKey string)

// cronDedupKey keys a cron firing on its scheduled tick (truncated to minute, the ParseStandard
// resolution) so two fires of the same tick — a live fire and a catch-up re-materialization — collide.
//
// cronDedupKey 按调度刻度(截断到分钟,ParseStandard 的分辨率)算 cron 触发的去重键。
func cronDedupKey(workflowID, nodeID string, tick time.Time) string {
	return workflowID + "|" + nodeID + "|cron|" + strconv.FormatInt(tick.Truncate(time.Minute).Unix(), 10)
}

// Listener wraps robfig/cron with per-(workflowID,nodeID) entries + last-fired tracking.
//
// Listener 包 robfig/cron，按 (workflowID,nodeID) 跟 entry 与 last-fired。
type Listener struct {
	mu       sync.Mutex
	cron     *robfigcron.Cron
	entries  map[string]robfigcron.EntryID
	lastFire map[string]time.Time
	onFire   OnFireFunc
	log      *zap.Logger
}

// New constructs a Listener bound to time.Local; caller calls Start to begin scheduling.
//
// New 构造 Listener，时区锁 time.Local；调用方调 Start 才开始调度。
func New(log *zap.Logger, onFire OnFireFunc) *Listener {
	return &Listener{
		cron:     robfigcron.New(robfigcron.WithLocation(time.Local)),
		entries:  make(map[string]robfigcron.EntryID),
		lastFire: make(map[string]time.Time),
		onFire:   onFire,
		log:      log.Named("trigger.cron"),
	}
}

// RegisterWithLastFire is like Register but seeds the in-memory lastFire map from spec.LastFiredAt
// (loaded from TriggerSchedule DB row by the app layer). This enables cross-restart missed-tick
// catch-up: after a process crash the cron listener knows when it last fired and can re-materialize
// any missed ticks.
//
// RegisterWithLastFire 等同 Register 但从 spec.LastFiredAt 种内存 lastFire,实现跨重启补漏跑。
func (l *Listener) RegisterWithLastFire(spec triggerdomain.Spec) error {
	if spec.LastFiredAt != nil {
		key := spec.WorkflowID + "/" + spec.NodeID
		l.mu.Lock()
		l.lastFire[key] = *spec.LastFiredAt
		l.mu.Unlock()
	}
	return l.Register(spec)
}

// Register adds or replaces a cron entry; missed runs fire one catch-up.
//
// Register 增加或替换一个 cron entry；漏跑过的会立即补一次。
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
			}, cronDedupKey(spec.WorkflowID, spec.NodeID, next))
		}
	}

	id, addErr := l.cron.AddFunc(expr, func() {
		now := time.Now()
		l.mu.Lock()
		l.lastFire[key] = now
		l.mu.Unlock()
		// Recover so an onFire panic doesn't crash the global scheduler.
		// 用 recover 防 onFire panic 把整个 scheduler 拉崩。
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
		}, cronDedupKey(spec.WorkflowID, spec.NodeID, now))
	})
	if addErr != nil {
		return fmt.Errorf("triggercroninfra.Register: %w: %v", triggerdomain.ErrInvalidCronExpression, addErr)
	}
	l.entries[key] = id
	return nil
}

// Unregister removes a cron entry; no-op on unknown key.
//
// Unregister 删 cron entry；未知 key 时 no-op。
func (l *Listener) Unregister(workflowID, nodeID string) {
	key := workflowID + "/" + nodeID
	l.mu.Lock()
	defer l.mu.Unlock()
	if id, ok := l.entries[key]; ok {
		l.cron.Remove(id)
		delete(l.entries, key)
	}
}

func (l *Listener) Start() { l.cron.Start() }

// Stop halts the scheduler and waits for in-flight fires to finish.
//
// Stop 停 scheduler 并等 in-flight fire 跑完。
func (l *Listener) Stop() {
	ctx := l.cron.Stop()
	<-ctx.Done()
}

// State returns the current state for one (workflowID,nodeID) trigger.
//
// State 返某 (workflowID,nodeID) 触发器的当前状态。
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
