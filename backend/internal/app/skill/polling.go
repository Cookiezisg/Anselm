// polling.go — Service.Start / Stop / pollLoop. The runtime heart that
// keeps the skill cache in sync with ~/.forgify/skills/ on disk: an
// initial synchronous Scan at boot (so chat sees skills before the first
// tool call) followed by a 1s polling goroutine that re-Scans and only
// publishes the SSE snapshot when the fingerprint actually changes.
//
// Mirrors catalog/polling.go: same 1s cadence, same fingerprint short-
// circuit pattern, same single-flight-via-busy-flag is unnecessary here
// because Scan is cheap (parses ~1-50 SKILL.md files, dominated by I/O).
//
// polling.go ——Service.Start / Stop / pollLoop。让 skill cache 与
// ~/.forgify/skills/ 磁盘内容同步的运行时心脏：boot 时同步 Scan 一次（让
// chat 在第一次 tool call 前已能见到 skill），然后 1s 轮询 goroutine 重
// Scan，仅在 fingerprint 真变化时发 SSE 快照。
//
// 与 catalog/polling.go 同模子：同 1s 节奏、同 fingerprint 短路；这里不需
// catalog 的 single-flight busy 守，因为 Scan 廉价（解析 1-50 个 SKILL.md，
// I/O 主导）。
package skill

import (
	"context"
	"time"

	"go.uber.org/zap"
)

// pollInterval is how often the goroutine re-Scans skillsDir. 1s matches
// catalog so user edits surface in roughly the same window as catalog
// regen — feels instant to the user without burning CPU.
//
// pollInterval 是轮询 goroutine 重 Scan skillsDir 的频率。1s 与 catalog 一
// 致，让用户编辑在与 catalog regen 大致同窗口内显现——用户感觉即时，CPU 几
// 乎无开销。
const pollInterval = 1 * time.Second

// Start runs an initial synchronous Scan (so the cache is hot before the
// caller returns), then launches the polling goroutine. The initial Scan
// error is logged + swallowed so a transient I/O hiccup at boot doesn't
// take the whole app down — the next tick will retry.
//
// Stop must be called at shutdown to drain the goroutine; main.go +
// test harnesses both wire t.Cleanup or shutdown ctx for this.
//
// Start 同步跑一次 Scan（让 caller 返回前 cache 已 hot），然后启轮询
// goroutine。初始 Scan 错误 log + 吞——boot 时 I/O 抖动不该让整个 app 挂，
// 下一 tick 会重试。Stop 必须在 shutdown 调以排空 goroutine；main.go +
// 测试 harness 都接 t.Cleanup 或 shutdown ctx 完成此事。
func (s *Service) Start(ctx context.Context) error {
	if err := s.Scan(ctx); err != nil {
		s.log.Warn("skill initial scan failed (continuing with empty cache)",
			zap.Error(err))
	}

	pollCtx, pollCancel := context.WithCancel(ctx)
	s.stopCancel = pollCancel
	s.pollDone = make(chan struct{})
	go func() {
		defer close(s.pollDone)
		s.pollLoop(pollCtx)
	}()
	return nil
}

// Stop cancels the polling goroutine and blocks until it exits. Idempotent
// — safe to call multiple times. Test harnesses must call Stop in a
// t.Cleanup so the tempdir RemoveAll doesn't race a final Scan's read.
//
// Stop 取消轮询 goroutine 并阻塞到其退出。幂等——多次调用安全。测试
// harness 必须在 t.Cleanup 调，让 tempdir RemoveAll 不与最后一次 Scan 读
// 竞态。
func (s *Service) Stop() {
	s.stopOnce.Do(func() {
		if s.stopCancel != nil {
			s.stopCancel()
		}
		if s.pollDone != nil {
			<-s.pollDone
		}
	})
}

// pollLoop re-Scans every pollInterval until ctx is cancelled. Scan
// errors are logged + skipped (the next tick retries); the fingerprint
// short-circuit inside Scan keeps SSE quiet on no-change ticks.
//
// pollLoop 每 pollInterval 重 Scan 直到 ctx 取消。Scan 错误 log + 跳
// （下一 tick 重试）；Scan 内的 fingerprint 短路让无变化的 tick 不发 SSE。
func (s *Service) pollLoop(ctx context.Context) {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := s.Scan(ctx); err != nil {
				s.log.Warn("skill rescan failed", zap.Error(err))
			}
		}
	}
}
