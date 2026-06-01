// Package polling is the polling-trigger listener (doc 01 §polling / 17 §6-7): a polling trigger is
// a forge Function whose active version has Kind="polling". The trigger node config spec carries
// {functionRef}; the platform resolves the function's PollingInterval, calls poll(lastCursor) on that
// cadence, fires one onFire per returned event (deduped by cursor|index), and persists nextCursor.
//
// Package polling 是 polling 触发器 listener：polling trigger = active version Kind=polling 的 forge
// Function。trigger 节点 spec 带 {functionRef}；平台按 PollingInterval 反复调 poll(lastCursor)、
// 每事件触发一次、游标持久化。
package polling

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"sync"
	"time"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
)

// OnFireFunc is called once per returned event; dedupKey prevents duplicate fires across restarts.
type OnFireFunc func(workflowID, nodeID string, input map[string]any, dedupKey string)

// PollingFunction resolves + invokes a kind=polling forge Function. Implemented by an adapter over
// functionapp.Service in main.go. The interval is read from the function's active-version
// PollingInterval (17 §1, the canon location — NOT the trigger spec).
//
// PollingFunction 解析并调用 kind=polling 的 forge Function；间隔取自 active version 的 PollingInterval。
type PollingFunction interface {
	// Interval returns the poll cadence + confirms the function's active version is kind=polling.
	// An error (not-found / not-polling / unparseable interval) fails registration (surfaced via State).
	Interval(ctx context.Context, userID, functionID string) (time.Duration, error)
	// Poll runs the function's poll(lastCursor) and returns its raw output map ({events, nextCursor}).
	Poll(ctx context.Context, userID, functionID, lastCursor string) (map[string]any, error)
}

// CursorStore persists and loads the polling cursor across restarts (polling_states table).
type CursorStore interface {
	GetPollingCursor(ctx context.Context, workflowID, nodeID string) (string, error)
	UpdatePollingCursor(ctx context.Context, workflowID, nodeID, cursor string) error
}

const minInterval = 5 * time.Second // floor: a misconfigured tiny interval must not hammer

type entry struct {
	spec   triggerdomain.Spec
	cancel context.CancelFunc
}

// Listener runs one goroutine per polling trigger, calling the forge function at its PollingInterval.
//
// Listener 每个 polling trigger 起一个 goroutine，按 function 的 PollingInterval 周期轮询。
type Listener struct {
	mu      sync.Mutex
	entries map[string]*entry // key: workflowID+"|"+nodeID
	fn      PollingFunction
	cursor  CursorStore
	onFire  OnFireFunc
	log     *zap.Logger
}

func New(fn PollingFunction, cursor CursorStore, log *zap.Logger, onFire OnFireFunc) *Listener {
	return &Listener{
		entries: make(map[string]*entry),
		fn:      fn,
		cursor:  cursor,
		onFire:  onFire,
		log:     log.Named("trigger.polling"),
	}
}

func entryKey(workflowID, nodeID string) string { return workflowID + "|" + nodeID }

// Register resolves the trigger node's functionRef → active-version PollingInterval, then starts the
// poll goroutine. config.functionRef (17 §7 canon) is required and must point at a kind=polling fn.
//
// Register 解析 functionRef → PollingInterval 后起 poll goroutine；functionRef 必填、须指向 kind=polling 函数。
func (l *Listener) Register(spec triggerdomain.Spec) error {
	functionRef, _ := spec.Config["functionRef"].(string)
	if functionRef == "" {
		// Tolerate the legacy/alt key name so a drifted authoring path still resolves.
		functionRef, _ = spec.Config["callable"].(string)
	}
	if functionRef == "" {
		return fmt.Errorf("pollinginfra.Register: config.functionRef is required for a polling trigger")
	}

	interval, err := l.fn.Interval(context.Background(), spec.UserID, functionRef)
	if err != nil {
		return fmt.Errorf("pollinginfra.Register: resolve %s: %w", functionRef, err)
	}
	if interval < minInterval {
		interval = minInterval
	}

	key := entryKey(spec.WorkflowID, spec.NodeID)
	l.mu.Lock()
	defer l.mu.Unlock()
	if e, ok := l.entries[key]; ok {
		e.cancel()
	}
	ctx, cancel := context.WithCancel(context.Background())
	l.entries[key] = &entry{spec: spec, cancel: cancel}
	go l.poll(ctx, spec, functionRef, interval)
	return nil
}

// Unregister stops the polling goroutine for (workflowID, nodeID). No-op if not registered.
func (l *Listener) Unregister(workflowID, nodeID string) {
	key := entryKey(workflowID, nodeID)
	l.mu.Lock()
	defer l.mu.Unlock()
	if e, ok := l.entries[key]; ok {
		e.cancel()
		delete(l.entries, key)
	}
}

// State returns the runtime state of a registered polling trigger; nil when not registered.
func (l *Listener) State(workflowID, nodeID string) *triggerdomain.State {
	l.mu.Lock()
	_, ok := l.entries[entryKey(workflowID, nodeID)]
	l.mu.Unlock()
	if !ok {
		return nil
	}
	return &triggerdomain.State{
		WorkflowID: workflowID,
		NodeID:     nodeID,
		Kind:       triggerdomain.KindPolling,
		Status:     triggerdomain.StateActive,
	}
}

// Stop cancels all goroutines; called on trigger service shutdown.
func (l *Listener) Stop() {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, e := range l.entries {
		e.cancel()
	}
	l.entries = make(map[string]*entry)
}

func (l *Listener) poll(ctx context.Context, spec triggerdomain.Spec, functionRef string, interval time.Duration) {
	l.log.Info("polling trigger started",
		zap.String("workflowID", spec.WorkflowID), zap.String("nodeID", spec.NodeID),
		zap.String("functionRef", functionRef), zap.Duration("interval", interval))
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	l.runPoll(ctx, spec, functionRef) // run once on registration (catch up after restart)
	for {
		select {
		case <-ctx.Done():
			l.log.Info("polling trigger stopped", zap.String("workflowID", spec.WorkflowID), zap.String("nodeID", spec.NodeID))
			return
		case <-ticker.C:
			l.runPoll(ctx, spec, functionRef)
		}
	}
}

func (l *Listener) runPoll(ctx context.Context, spec triggerdomain.Spec, functionRef string) {
	cursor, err := l.cursor.GetPollingCursor(ctx, spec.WorkflowID, spec.NodeID)
	if err != nil {
		l.log.Warn("polling: load cursor failed", zap.String("workflowID", spec.WorkflowID), zap.Error(err))
		return
	}

	// poll(lastCursor) → {"events":[...], "nextCursor":...} (doc 01 fixed signature).
	out, err := l.fn.Poll(ctx, spec.UserID, functionRef, cursor)
	if err != nil {
		l.log.Warn("polling: poll() failed", zap.String("workflowID", spec.WorkflowID), zap.String("functionRef", functionRef), zap.Error(err))
		return
	}

	events, _ := out["events"].([]any)
	nextCursor, _ := out["nextCursor"].(string)

	// Each returned event → one onFire (→ one trigger_firing → one flowrun), deduped by cursor|index
	// (17 §6: polling dedup = (cursor_in, 段内 event-index)).
	for i, ev := range events {
		evMap, _ := ev.(map[string]any)
		if evMap == nil {
			bs, _ := json.Marshal(ev)
			evMap = map[string]any{"_raw": string(bs)}
		}
		dedupKey := fmt.Sprintf("%s|%s|%s|%s", spec.WorkflowID, spec.NodeID, cursor, strconv.Itoa(i))
		l.onFire(spec.WorkflowID, spec.NodeID, evMap, dedupKey)
	}

	// Advance the cursor when poll moved it forward (cursor must progress — 01 forging contract).
	if nextCursor != "" && nextCursor != cursor {
		if upErr := l.cursor.UpdatePollingCursor(ctx, spec.WorkflowID, spec.NodeID, nextCursor); upErr != nil {
			l.log.Warn("polling: update cursor failed", zap.String("workflowID", spec.WorkflowID), zap.Error(upErr))
		}
	}
}
