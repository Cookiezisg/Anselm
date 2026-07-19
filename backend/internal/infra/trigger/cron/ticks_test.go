package cron

// ticks_test.go covers the two schedule primitives the scheduler work orders stand on:
// TicksWithin (工单⑧ timeline + 工单⑨ gap detection) and DedupKey's tick-snapping identity
// (工单⑨ idempotence: a tick is booked fired XOR missed, never both).
//
// ticks_test.go 覆盖 scheduler 两张工单赖以成立的两个调度原语：TicksWithin（工单⑧ 时间线 + 工单⑨
// 缺口检测）与 DedupKey 的刻度吸附身份（工单⑨ 幂等：一个刻度记 fired 与 missed 互斥、绝不两者兼有）。

import (
	"testing"
	"time"

	robfigcron "github.com/robfig/cron/v3"
)

// TestTicksWithin_WindowIsHalfOpen: ticks strictly after `after`, at/before `until` — the same
// half-open shape a watermark walk needs, so consecutive sweeps neither skip nor double-count a tick.
func TestTicksWithin_WindowIsHalfOpen(t *testing.T) {
	base := time.Date(2026, 6, 18, 10, 0, 0, 0, time.UTC)

	// (10:00, 10:05] over an every-minute cron = 10:01…10:05. The boundary tick at 10:00 is NOT
	// re-emitted (it belongs to the previous window), and 10:05 IS included.
	// (10:00, 10:05] 上的每分钟 cron = 10:01…10:05。边界的 10:00 不重发（属上个窗），10:05 含。
	ticks, more, err := TicksWithin("* * * * *", base, base.Add(5*time.Minute), 0)
	if err != nil {
		t.Fatalf("TicksWithin: %v", err)
	}
	if more {
		t.Fatal("an uncapped walk must never report truncation")
	}
	if len(ticks) != 5 {
		t.Fatalf("(10:00, 10:05] of an every-minute cron = 5 ticks, got %d: %v", len(ticks), ticks)
	}
	if !ticks[0].Equal(base.Add(time.Minute)) {
		t.Fatalf("first tick must be strictly after `after`: %v", ticks[0])
	}
	if !ticks[4].Equal(base.Add(5 * time.Minute)) {
		t.Fatalf("last tick must include `until`: %v", ticks[4])
	}
	// Consecutive windows tile without gap or overlap — the watermark invariant.
	// 相邻窗无缝无叠拼接——水位不变式。
	next, _, err := TicksWithin("* * * * *", base.Add(5*time.Minute), base.Add(10*time.Minute), 0)
	if err != nil {
		t.Fatalf("TicksWithin (next): %v", err)
	}
	if !next[0].Equal(base.Add(6 * time.Minute)) {
		t.Fatalf("the next window must resume at 10:06, got %v", next[0])
	}
}

// TestTicksWithin_CapReportsTruncation — 工单⑧: the cap bounds the walk and says so, so a
// `* * * * *` trigger cannot mint an unbounded slice and the caller never mistakes a capped page
// for the whole window.
func TestTicksWithin_CapReportsTruncation(t *testing.T) {
	base := time.Date(2026, 6, 18, 10, 0, 0, 0, time.UTC)

	ticks, more, err := TicksWithin("* * * * *", base, base.Add(time.Hour), 10)
	if err != nil {
		t.Fatalf("TicksWithin: %v", err)
	}
	if len(ticks) != 10 || !more {
		t.Fatalf("an hour of minutely ticks capped at 10 must yield 10 + more=true, got %d/%v", len(ticks), more)
	}
	// A cap the window never reaches leaves more=false.
	// 窗内根本够不着的 cap → more=false。
	if _, more2, _ := TicksWithin("0 * * * *", base, base.Add(2*time.Hour), 100); more2 {
		t.Fatal("2 hourly ticks under a cap of 100 must not report truncation")
	}
	// An empty window is empty, not an error. 空窗就是空、不是错误。
	if got, _, err := TicksWithin("0 0 1 1 *", base, base.Add(time.Minute), 0); err != nil || len(got) != 0 {
		t.Fatalf("a window with no ticks = empty, got %v err=%v", got, err)
	}
	if _, _, err := TicksWithin("not a cron", base, base.Add(time.Hour), 0); err == nil {
		t.Fatal("an invalid expression must error")
	}
}

// TestDedupKey_IdentifiesTheTickNotTheMoment — 工单⑨ idempotence hinge: the key is derived from the
// SCHEDULED tick (minute resolution), so the live listener firing at 10:00:00.3 and the misfire
// sweep booking the 10:00 tick mint the SAME key — idx_trf_dedup then makes the tick land exactly
// once, fired XOR missed. Different ticks (and different triggers) never collide.
func TestDedupKey_IdentifiesTheTickNotTheMoment(t *testing.T) {
	tick := time.Date(2026, 6, 18, 10, 0, 0, 0, time.UTC)

	// The same tick observed at slightly different instants folds to one key.
	// 同一刻度在略不同时刻被观察到，折成同一个键。
	if a, b := DedupKey("trg_1", tick), DedupKey("trg_1", tick.Add(59*time.Second)); a != b {
		t.Fatalf("the same minute-tick must mint one key: %q vs %q", a, b)
	}
	// Adjacent ticks are distinct — a per-minute cron books each minute separately.
	// 相邻刻度互异——每分钟 cron 逐分钟分别记账。
	if a, b := DedupKey("trg_1", tick), DedupKey("trg_1", tick.Add(time.Minute)); a == b {
		t.Fatalf("adjacent ticks must not collide: %q", a)
	}
	// Different triggers never share a key even at the same instant.
	// 不同 trigger 即便同刻也绝不共键。
	if a, b := DedupKey("trg_1", tick), DedupKey("trg_2", tick); a == b {
		t.Fatalf("different triggers must not collide: %q", a)
	}
}

// TestSnapTick_SuppressesWakeArtifacts — 判决⑥ machinery: after a system sleep, robfig delivers one
// stale callback at wake. Snapping resolves which tick a callback belongs to, and refuses one that
// is beyond tolerance from any tick — that gap is the misfire sweep's to ACCOUNT, never the
// listener's to implicitly re-run.
func TestSnapTick_SuppressesWakeArtifacts(t *testing.T) {
	sched, err := robfigcron.ParseStandard("0 * * * *") // hourly, on the hour
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	hour := time.Date(2026, 6, 18, 10, 0, 0, 0, time.UTC)

	// A callback landing a beat after its tick snaps back onto it (the normal case: cron fires at
	// 10:00:00.2, the tick is 10:00).
	// 稍迟于刻度落地的回调吸附回该刻度（常态：cron 在 10:00:00.2 触发、刻度是 10:00）。
	got, ok := snapTick(sched, hour.Add(200*time.Millisecond))
	if !ok || !got.Equal(hour) {
		t.Fatalf("a punctual fire must snap to its tick: got=%v ok=%v", got, ok)
	}
	// Still within tolerance: a briefly-delayed callback is honestly that tick's.
	// 仍在容差内：略有延迟的回调诚实归属该刻度。
	if got, ok := snapTick(sched, hour.Add(90*time.Second)); !ok || !got.Equal(hour) {
		t.Fatalf("a slightly late fire still belongs to its tick: got=%v ok=%v", got, ok)
	}
	// Beyond tolerance = a wall-clock jump artifact: no tick owns it, so the listener drops it and
	// the sweep books the gap instead of an implicit late run.
	// 超出容差 = 墙钟跳变伪 fire：无刻度认领它，故 listener 丢弃、由 sweep 记账缺口，而非隐式迟跑。
	if _, ok := snapTick(sched, hour.Add(50*time.Minute)); ok {
		t.Fatal("a fire 50min past the hourly tick is a wake artifact — it must not claim that tick")
	}
}
