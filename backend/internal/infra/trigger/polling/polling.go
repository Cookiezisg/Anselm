// Package polling is the polling-trigger listener (doc 01 §polling): periodically calls a forge
// function (config.callable) with {cursor}, collects {events, nextCursor}, persists the cursor,
// and fires one onFire per returned event (deduped by cursor|eventIndex).
//
// Package polling 是 polling 触发器 listener（doc 01 §polling）：周期性调 forge function、
// 按返回 events 各触发一次 onFire、游标持久化、去重键 = cursor|eventIndex。
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

// PollingCallable executes the forge function identified by callable ID with the given args,
// returning its output as a JSON-serializable map. The platform calls it with {cursor}.
//
// PollingCallable 执行 forge function 并返 map；platform 以 {cursor} 调。
type PollingCallable interface {
	CallFunction(ctx context.Context, userID, functionID string, args map[string]any) (map[string]any, error)
}

// CursorStore persists and loads the polling cursor across restarts.
//
// CursorStore 持久化 polling 游标。
type CursorStore interface {
	GetPollingCursor(ctx context.Context, workflowID, nodeID string) (string, error)
	UpdatePollingCursor(ctx context.Context, workflowID, nodeID, cursor string) error
}

const defaultIntervalSec = 60

type entry struct {
	spec   triggerdomain.Spec
	cancel context.CancelFunc
}

// Listener runs one goroutine per polling trigger, calling the forge function at the configured interval.
//
// Listener 每个 polling trigger 起一个 goroutine，按 config.intervalSec 周期轮询。
type Listener struct {
	mu       sync.Mutex
	entries  map[string]*entry // key: workflowID+"|"+nodeID
	callable PollingCallable
	cursor   CursorStore
	onFire   OnFireFunc
	log      *zap.Logger
}

func New(callable PollingCallable, cursor CursorStore, log *zap.Logger, onFire OnFireFunc) *Listener {
	return &Listener{
		entries:  make(map[string]*entry),
		callable: callable,
		cursor:   cursor,
		onFire:   onFire,
		log:      log.Named("trigger.polling"),
	}
}

func entryKey(workflowID, nodeID string) string { return workflowID + "|" + nodeID }

// Register adds or replaces a polling listener entry. config.callable must be a function ID (fn_xxx).
//
// Register 增加/替换一个 polling 条目；config.callable 必须是 fn_xxx。
func (l *Listener) Register(spec triggerdomain.Spec) error {
	callable, _ := spec.Config["callable"].(string)
	if callable == "" {
		return fmt.Errorf("pollinginfra.Register: config.callable is required for polling trigger")
	}
	intervalSec := defaultIntervalSec
	if iv, ok := spec.Config["intervalSec"]; ok {
		switch v := iv.(type) {
		case float64:
			intervalSec = int(v)
		case int:
			intervalSec = v
		case int64:
			intervalSec = int(v)
		}
	}
	if intervalSec < 10 {
		intervalSec = 10 // floor: prevent hammering
	}

	key := entryKey(spec.WorkflowID, spec.NodeID)
	l.mu.Lock()
	defer l.mu.Unlock()

	if e, ok := l.entries[key]; ok {
		e.cancel()
	}

	ctx, cancel := context.WithCancel(context.Background())
	e := &entry{spec: spec, cancel: cancel}
	l.entries[key] = e

	go l.poll(ctx, spec, callable, time.Duration(intervalSec)*time.Second)
	return nil
}

// Unregister stops the polling goroutine for (workflowID, nodeID). No-op if not registered.
//
// Unregister 停止对应 polling goroutine；未注册时 no-op。
func (l *Listener) Unregister(workflowID, nodeID string) {
	key := entryKey(workflowID, nodeID)
	l.mu.Lock()
	defer l.mu.Unlock()
	if e, ok := l.entries[key]; ok {
		e.cancel()
		delete(l.entries, key)
	}
}

// State returns the runtime state of a registered polling trigger.
//
// State 返注册的 polling trigger 运行状态。
func (l *Listener) State(workflowID, nodeID string) *triggerdomain.State {
	l.mu.Lock()
	e, ok := l.entries[entryKey(workflowID, nodeID)]
	l.mu.Unlock()
	if !ok {
		return nil
	}
	return &triggerdomain.State{
		WorkflowID: e.spec.WorkflowID,
		NodeID:     e.spec.NodeID,
		Kind:       triggerdomain.KindPolling,
		Status:     triggerdomain.StateActive,
	}
}

// Stop cancels all goroutines; called on trigger service shutdown.
//
// Stop 取消所有 goroutine；trigger service 关停时调。
func (l *Listener) Stop() {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, e := range l.entries {
		e.cancel()
	}
	l.entries = make(map[string]*entry)
}

func (l *Listener) poll(ctx context.Context, spec triggerdomain.Spec, callable string, interval time.Duration) {
	l.log.Info("polling trigger started",
		zap.String("workflowID", spec.WorkflowID), zap.String("nodeID", spec.NodeID),
		zap.Duration("interval", interval))

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Run once immediately on registration (catch up after restart).
	l.runPoll(ctx, spec, callable)

	for {
		select {
		case <-ctx.Done():
			l.log.Info("polling trigger stopped", zap.String("workflowID", spec.WorkflowID), zap.String("nodeID", spec.NodeID))
			return
		case <-ticker.C:
			l.runPoll(ctx, spec, callable)
		}
	}
}

func (l *Listener) runPoll(ctx context.Context, spec triggerdomain.Spec, callable string) {
	cursor, err := l.cursor.GetPollingCursor(ctx, spec.WorkflowID, spec.NodeID)
	if err != nil {
		l.log.Warn("polling: load cursor failed", zap.String("workflowID", spec.WorkflowID), zap.Error(err))
		return
	}

	result, err := l.callable.CallFunction(ctx, spec.UserID, callable, map[string]any{"cursor": cursor})
	if err != nil {
		l.log.Warn("polling: callable failed", zap.String("workflowID", spec.WorkflowID), zap.String("callable", callable), zap.Error(err))
		return
	}

	events, _ := result["events"].([]any)
	nextCursor, _ := result["nextCursor"].(string)

	// Fire one onFire per returned event, deduped by cursor|eventIndex.
	for i, ev := range events {
		evMap, _ := ev.(map[string]any)
		if evMap == nil {
			bs, _ := json.Marshal(ev)
			evMap = map[string]any{"_raw": string(bs)}
		}
		dedupKey := fmt.Sprintf("%s|%s|%s|%s", spec.WorkflowID, spec.NodeID, cursor, strconv.Itoa(i))
		l.onFire(spec.WorkflowID, spec.NodeID, evMap, dedupKey)
	}

	if nextCursor != "" && nextCursor != cursor {
		if upErr := l.cursor.UpdatePollingCursor(ctx, spec.WorkflowID, spec.NodeID, nextCursor); upErr != nil {
			l.log.Warn("polling: update cursor failed", zap.String("workflowID", spec.WorkflowID), zap.Error(upErr))
		}
	}
}
