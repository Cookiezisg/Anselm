// Package cron is the cron source listener (wraps robfig/cron), keyed by triggerID: one
// cron entry per trigger. dedupKey is the scheduled tick (minute-truncated, ParseStandard's
// resolution) so a re-materialized fire of the same tick dedups against the live one.
//
// Package cron 是 cron source listener（封装 robfig/cron），按 triggerID 键：每 trigger 一个
// cron entry。dedupKey 是调度刻度（截断到分钟，ParseStandard 分辨率），同刻度重复材化时去重。
package cron

import (
	"fmt"
	"strconv"
	"sync"
	"time"

	robfigcron "github.com/robfig/cron/v3"
	"go.uber.org/zap"

	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
)

// Validate reports whether expr is a parseable standard (5-field) cron expression. The app
// calls it at create/edit time so a bad expression fails fast (mapped to ErrInvalidCron),
// not silently at Register.
//
// Validate 报告 expr 是否可解析的标准（5 字段）cron 表达式；app 在 create/edit 时调以快速失败。
func Validate(expr string) error {
	if _, err := robfigcron.ParseStandard(expr); err != nil {
		return err
	}
	return nil
}

func dedupKey(triggerID string, tick time.Time) string {
	return triggerID + "|cron|" + strconv.FormatInt(tick.Truncate(time.Minute).Unix(), 10)
}

// Listener wraps robfig/cron with one entry per triggerID.
//
// Listener 包 robfig/cron，每 triggerID 一个 entry。
type Listener struct {
	mu      sync.Mutex
	cron    *robfigcron.Cron
	entries map[string]robfigcron.EntryID
	report  triggerinfra.ReportFunc
	log     *zap.Logger
}

// New constructs a Listener bound to time.Local; caller calls Start to begin scheduling.
//
// New 构造 Listener（时区锁 time.Local）；调用方调 Start 才开始调度。
func New(log *zap.Logger, report triggerinfra.ReportFunc) *Listener {
	return &Listener{
		cron:    robfigcron.New(robfigcron.WithLocation(time.Local)),
		entries: make(map[string]robfigcron.EntryID),
		report:  report,
		log:     log.Named("trigger.cron"),
	}
}

// Register adds or replaces the cron entry for triggerID.
//
// Register 增加或替换 triggerID 的 cron entry。
func (l *Listener) Register(triggerID string, _ string, config map[string]any) error {
	expr, _ := config["expression"].(string)
	if expr == "" {
		return fmt.Errorf("cron.Register %s: empty expression", triggerID)
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if existing, ok := l.entries[triggerID]; ok {
		l.cron.Remove(existing)
		delete(l.entries, triggerID)
	}
	id, err := l.cron.AddFunc(expr, func() {
		now := time.Now()
		// Recover so an onFire panic doesn't crash the shared scheduler.
		// recover 防回调 panic 把共享 scheduler 拉崩。
		defer func() {
			if r := recover(); r != nil {
				l.log.Error("cron report panic", zap.String("triggerID", triggerID), zap.Any("recover", r))
			}
		}()
		l.report(triggerID, triggerinfra.Activity{
			Fired:    true,
			Payload:  map[string]any{"firedAt": now},
			DedupKey: dedupKey(triggerID, now),
		})
	})
	if err != nil {
		return fmt.Errorf("cron.Register %s: %w", triggerID, err)
	}
	l.entries[triggerID] = id
	return nil
}

// Unregister removes triggerID's cron entry; no-op when absent.
//
// Unregister 删 triggerID 的 cron entry；不存在则 no-op。
func (l *Listener) Unregister(triggerID string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if id, ok := l.entries[triggerID]; ok {
		l.cron.Remove(id)
		delete(l.entries, triggerID)
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

var _ triggerinfra.Listener = (*Listener)(nil)
