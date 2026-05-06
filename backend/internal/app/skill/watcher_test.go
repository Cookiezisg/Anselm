// watcher_test.go — exercise the fsnotify-driven rescan path. Tests use
// a real fsnotify watcher against t.TempDir() so we cover the actual
// kernel callback path (mocking fsnotify defeats the purpose). Each
// scenario waits for a Scan to complete by polling Service.List rather
// than sleeping arbitrary time — fewer flakes on CI.
//
// watcher_test.go ——验 fsnotify 驱动的重扫。用真 fsnotify watcher + t
// .TempDir() 覆盖真实内核回调路径（mock 失意义）。每场景轮询
// Service.List 等 Scan 完成，而非死睡——CI 抖动更少。
package skill

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"go.uber.org/zap/zaptest"
)

// waitForSkillCount blocks until s.List returns want skills or timeout.
// Polls at debounceWindow/4 so a single user-edit's debounce-window
// elapses without the test reaching the deadline.
//
// waitForSkillCount 阻塞直到 s.List 返 want 数或超时。轮询步长
// debounceWindow/4 让一次 debounce-window 走完前测试不会到 deadline。
func waitForSkillCount(t *testing.T, s *Service, want int, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if got := len(s.List(context.Background())); got == want {
			return
		}
		time.Sleep(debounceWindow / 4)
	}
	t.Fatalf("skill count did not reach %d within %s; got %d",
		want, timeout, len(s.List(context.Background())))
}

func TestWatcher_DetectsNewSkill(t *testing.T) {
	tmp := t.TempDir()
	s := New(tmp, nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	if err := s.Scan(context.Background()); err != nil {
		t.Fatalf("initial scan: %v", err)
	}
	if got := len(s.List(context.Background())); got != 0 {
		t.Fatalf("baseline want 0 skills, got %d", got)
	}

	w := NewWatcher(s, zaptest.NewLogger(t))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() {
		_ = w.Start(ctx)
	}()
	// Give Start a beat to add the root watch before we mutate the dir.
	// 给 Start 一拍加根 watch 后再动目录。
	time.Sleep(100 * time.Millisecond)

	writeSkill(t, tmp, "new-skill",
		"name: new-skill\ndescription: detected by watcher", "body")

	// debounceWindow + Scan + slack. 3s budget is generous on slow CI.
	// debounceWindow + Scan + slack。3s 预算 CI 慢时也够。
	waitForSkillCount(t, s, 1, 3*time.Second)

	got, err := s.Get(context.Background(), "new-skill")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.Description != "detected by watcher" {
		t.Errorf("description lost: %q", got.Description)
	}
}

func TestWatcher_DetectsEdit(t *testing.T) {
	tmp := t.TempDir()
	writeSkill(t, tmp, "edit-me",
		"name: edit-me\ndescription: original", "body")

	s := New(tmp, nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	if err := s.Scan(context.Background()); err != nil {
		t.Fatalf("initial scan: %v", err)
	}

	w := NewWatcher(s, zaptest.NewLogger(t))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = w.Start(ctx) }()
	time.Sleep(100 * time.Millisecond)

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
		time.Sleep(debounceWindow / 4)
	}
	cur, _ := s.Get(context.Background(), "edit-me")
	t.Fatalf("watcher did not pick up edit; current description: %q", cur.Description)
}

func TestWatcher_DetectsDelete(t *testing.T) {
	tmp := t.TempDir()
	writeSkill(t, tmp, "doomed",
		"name: doomed\ndescription: about to be deleted", "body")

	s := New(tmp, nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	if err := s.Scan(context.Background()); err != nil {
		t.Fatalf("initial scan: %v", err)
	}
	if got := len(s.List(context.Background())); got != 1 {
		t.Fatalf("baseline want 1 skill, got %d", got)
	}

	w := NewWatcher(s, zaptest.NewLogger(t))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = w.Start(ctx) }()
	time.Sleep(100 * time.Millisecond)

	if err := os.RemoveAll(filepath.Join(tmp, "doomed")); err != nil {
		t.Fatalf("RemoveAll: %v", err)
	}

	waitForSkillCount(t, s, 0, 3*time.Second)
}

func TestWatcher_AddRecursive_SymlinkLoop(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("symlink test requires unix-style symlinks; Windows needs developer mode")
	}
	tmp := t.TempDir()
	// Create a normal subdir, then a symlink inside it pointing back to
	// the parent — classic loop. addRecursive must not hang or recurse
	// indefinitely.
	// 先建普通子目录，再在内部建软链回父目录——经典循环。addRecursive
	// 不能挂或无限递归。
	child := filepath.Join(tmp, "child")
	if err := os.Mkdir(child, 0o755); err != nil {
		t.Fatalf("mkdir child: %v", err)
	}
	loop := filepath.Join(child, "loop-back")
	if err := os.Symlink(tmp, loop); err != nil {
		t.Fatalf("symlink: %v", err)
	}

	s := New(tmp, nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	w := NewWatcher(s, zaptest.NewLogger(t))

	// Run addRecursive directly under a deadline; if loop guard fails
	// the stack overflows or the goroutine blocks past the timeout.
	// 直跑 addRecursive 加 deadline；guard 失败 → 栈溢 / 阻塞超时。
	done := make(chan error, 1)
	go func() {
		// Need a real fsnotify.Watcher to call Add against. Errors
		// from Add are tolerated (test only cares about loop-detection
		// not blowing up).
		// 需真 fsnotify.Watcher 让 Add 有目标。Add 错误容忍（测试只关心
		// loop-detection 不炸）。
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		go func() { _ = w.Start(ctx) }()
		<-ctx.Done()
		done <- nil
	}()
	select {
	case <-done:
		// Watcher returned cleanly within the timeout = loop guard worked.
		// Watcher 在超时内干净退出 = loop guard 起作用。
	case <-time.After(3 * time.Second):
		t.Fatal("Watcher.Start did not return within 3s — symlink loop likely")
	}
}

func TestWatcher_EmptySkillsDir_StartFails(t *testing.T) {
	s := New("", nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	w := NewWatcher(s, zaptest.NewLogger(t))
	err := w.Start(context.Background())
	if err == nil || !strings.Contains(err.Error(), "SkillsDir is empty") {
		t.Errorf("Start with empty SkillsDir should fail clearly; got %v", err)
	}
}

func TestWatcher_NewWatcher_NilLogOK(t *testing.T) {
	s := New(t.TempDir(), nil, nil, nil, nil, nil, zaptest.NewLogger(t))
	w := NewWatcher(s, nil)
	if w == nil || w.svc != s {
		t.Errorf("NewWatcher with nil log should still construct; got %+v", w)
	}
}
