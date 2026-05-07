// polling_test.go — exercise Service.Start's 1s poll loop against a real
// tempdir. Each scenario waits for a Scan to complete by polling
// Service.List rather than sleeping arbitrary time — fewer flakes on CI.
//
// polling_test.go ——验 Service.Start 的 1s 轮询循环 + 真 tempdir。每场景
// 轮询 Service.List 等 Scan 完成而非死睡——CI 抖动更少。
package skill

import (
	"context"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"go.uber.org/zap/zaptest"

	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
)

// recordingBridge counts Publish calls. Subscribe is unused by Scan so it
// returns a closed nil channel — never received from.
//
// recordingBridge 数 Publish 次数。Scan 不调 Subscribe，故返 nil channel。
type recordingBridge struct {
	publishes atomic.Int64
}

func (b *recordingBridge) Publish(_ context.Context, _ string, _ eventsdomain.Event) {
	b.publishes.Add(1)
}

func (b *recordingBridge) Subscribe(_ context.Context, _ string) (<-chan eventsdomain.Event, func()) {
	return nil, func() {}
}

func (b *recordingBridge) count() int64 { return b.publishes.Load() }

// waitForSkillCount blocks until s.List returns want skills or timeout.
// Polls fast enough that a single pollInterval elapses well before the
// deadline.
//
// waitForSkillCount 阻塞直到 s.List 返 want 数或超时。轮询足够密让单个
// pollInterval 远早于 deadline 走完。
func waitForSkillCount(t *testing.T, s *Service, want int, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if got := len(s.List(context.Background())); got == want {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("skill count did not reach %d within %s; got %d",
		want, timeout, len(s.List(context.Background())))
}

func TestPolling_DetectsNewSkill(t *testing.T) {
	tmp := t.TempDir()
	s := New(tmp, nil, nil, nil, nil, nil, zaptest.NewLogger(t))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if err := s.Start(ctx); err != nil {
		t.Fatalf("Start: %v", err)
	}
	t.Cleanup(s.Stop)

	if got := len(s.List(context.Background())); got != 0 {
		t.Fatalf("baseline want 0 skills, got %d", got)
	}

	writeSkill(t, tmp, "new-skill",
		"name: new-skill\ndescription: detected by polling", "body")

	// pollInterval + Scan + slack. 3s budget is generous on slow CI.
	// pollInterval + Scan + slack。3s 预算 CI 慢时也够。
	waitForSkillCount(t, s, 1, 3*time.Second)

	got, err := s.Get(context.Background(), "new-skill")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.Description != "detected by polling" {
		t.Errorf("description lost: %q", got.Description)
	}
}

func TestPolling_DetectsEdit(t *testing.T) {
	tmp := t.TempDir()
	writeSkill(t, tmp, "edit-me",
		"name: edit-me\ndescription: original", "body")

	s := New(tmp, nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if err := s.Start(ctx); err != nil {
		t.Fatalf("Start: %v", err)
	}
	t.Cleanup(s.Stop)

	// Overwrite SKILL.md with new description.
	// 用新 description 覆写 SKILL.md。
	target := filepath.Join(tmp, "edit-me", "SKILL.md")
	newContent := "---\nname: edit-me\ndescription: edited by user\n---\nnew body"
	if err := os.WriteFile(target, []byte(newContent), 0o644); err != nil {
		t.Fatalf("overwrite SKILL.md: %v", err)
	}

	// Poll for the description update specifically (not just count).
	// 轮询特定 description 更新（不止数量）。
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if sk, err := s.Get(context.Background(), "edit-me"); err == nil &&
			sk.Description == "edited by user" {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	cur, _ := s.Get(context.Background(), "edit-me")
	t.Fatalf("polling did not pick up edit; current description: %q", cur.Description)
}

func TestPolling_DetectsDelete(t *testing.T) {
	tmp := t.TempDir()
	writeSkill(t, tmp, "doomed",
		"name: doomed\ndescription: about to be deleted", "body")

	s := New(tmp, nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if err := s.Start(ctx); err != nil {
		t.Fatalf("Start: %v", err)
	}
	t.Cleanup(s.Stop)

	if got := len(s.List(context.Background())); got != 1 {
		t.Fatalf("baseline want 1 skill, got %d", got)
	}

	if err := os.RemoveAll(filepath.Join(tmp, "doomed")); err != nil {
		t.Fatalf("RemoveAll: %v", err)
	}

	waitForSkillCount(t, s, 0, 3*time.Second)
}

func TestScan_FingerprintShortCircuit(t *testing.T) {
	// Two back-to-back Scans on identical disk state should not double-
	// publish the SSE 'skill' event. Verified by counting Bridge.Publish
	// calls via a recording fake.
	//
	// 同盘状态连扫两次不该重复发 SSE 'skill'。用记录型 fake 数 Bridge
	// .Publish 次数验证。
	tmp := t.TempDir()
	writeSkill(t, tmp, "stable",
		"name: stable\ndescription: unchanged", "body")

	bridge := &recordingBridge{}
	s := New(tmp, nil, bridge, nil, nil, nil, zaptest.NewLogger(t))

	if err := s.Scan(context.Background()); err != nil {
		t.Fatalf("scan #1: %v", err)
	}
	if err := s.Scan(context.Background()); err != nil {
		t.Fatalf("scan #2: %v", err)
	}
	if got := bridge.count(); got != 1 {
		t.Errorf("expected 1 publish on identical-state rescan, got %d", got)
	}
}
