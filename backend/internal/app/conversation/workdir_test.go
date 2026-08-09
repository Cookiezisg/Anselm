package conversation

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
)

// recordingMarker stands in for chatapp: it records the (from, to) pair the residency switch reported.
//
// recordingMarker 替身 chatapp：记下驻地切换上报的 (from, to) 对。
type recordingMarker struct {
	calls [][2]string
	err   error
}

func (m *recordingMarker) MarkWorkDirSwitch(_ context.Context, _, from, to string) error {
	m.calls = append(m.calls, [2]string{from, to})
	return m.err
}

// TestUpdate_WorkDirMountSwitchUnmount: the residency's whole PATCH lifecycle, and the marker's (from, to)
// pair at each step. `""` is the unmount — there is no third state to express, which is why WorkDir is a
// plain pointer and not modelOverride's pointer-to-pointer.
//
// TestUpdate_WorkDirMountSwitchUnmount：驻地 PATCH 的完整生命周期，及每一步标记的 (from, to) 对。`""`
// 即退出驻地——没有第三种状态要表达，这正是 WorkDir 用朴素指针、而非 modelOverride 那种指针的指针的原因。
func TestUpdate_WorkDirMountSwitchUnmount(t *testing.T) {
	svc, em, _, ctx := newSvc(t)
	marker := &recordingMarker{}
	svc.SetWorkDirMarker(marker)
	c, err := svc.Create(ctx, "zoom")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if c.WorkDir != "" {
		t.Fatalf("a new conversation must start unmounted, got %q", c.WorkDir)
	}

	first, second := t.TempDir(), t.TempDir()
	mount := func(dir string) *conversationdomain.Conversation {
		t.Helper()
		got, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir})
		if err != nil {
			t.Fatalf("patch workDir=%q: %v", dir, err)
		}
		return got
	}

	if got := mount(first); got.WorkDir != first {
		t.Fatalf("mount: workDir = %q, want %q", got.WorkDir, first)
	}
	if em.last() != "conversation.work_dir" {
		t.Fatalf("a residency change must emit its own action, got %q", em.last())
	}
	if got := mount(second); got.WorkDir != second {
		t.Fatalf("switch: workDir = %q, want %q", got.WorkDir, second)
	}
	empty := ""
	got, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &empty})
	if err != nil {
		t.Fatalf("unmount: %v", err)
	}
	if got.WorkDir != "" {
		t.Fatalf("empty string must UNMOUNT, got %q", got.WorkDir)
	}

	// Both ends of every transition, in order. The pair is stored (not just the new value) because a
	// reader scrolling back needs to know what "here" used to be.
	// 每次转移的两端，按序。存的是一对（不只是新值），因为往回翻的读者需要知道「这里」原本是哪儿。
	want := [][2]string{{"", first}, {first, second}, {second, ""}}
	if len(marker.calls) != len(want) {
		t.Fatalf("marker calls = %v, want %v", marker.calls, want)
	}
	for i := range want {
		if marker.calls[i] != want[i] {
			t.Fatalf("marker call %d = %v, want %v", i, marker.calls[i], want[i])
		}
	}
}

// TestUpdate_WorkDirNoopsAndAbsentKey: an absent key leaves the residency alone, and re-PATCHing the SAME
// path is a real no-op — no marker, no work_dir action. Without that check, a client that echoes the whole
// head back on every edit would stamp a marker into the thread for changing nothing.
//
// TestUpdate_WorkDirNoopsAndAbsentKey：缺键不动驻地，而重复 PATCH **同一个**路径是真 no-op——不落标记、
// 不发 work_dir 动作。没有这道判定，一个每次编辑都把整个头回显回来的客户端，会为「什么都没改」在线程里盖下
// 一条标记。
func TestUpdate_WorkDirNoopsAndAbsentKey(t *testing.T) {
	svc, em, _, ctx := newSvc(t)
	marker := &recordingMarker{}
	svc.SetWorkDirMarker(marker)
	c, _ := svc.Create(ctx, "zoom")
	dir := t.TempDir()
	if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir}); err != nil {
		t.Fatalf("mount: %v", err)
	}
	em.events = nil

	// Same value again. 同一个值再来一次。
	if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir}); err != nil {
		t.Fatalf("re-patch: %v", err)
	}
	if len(marker.calls) != 1 {
		t.Fatalf("re-patching the same path must not mark again, calls=%v", marker.calls)
	}
	if len(em.events) != 0 {
		t.Fatalf("a no-op residency patch must not emit lifecycle events: %v", em.events)
	}

	// Absent key: another field changes, the residency does not. 缺键：别的字段变、驻地不变。
	title := "renamed"
	got, err := svc.Update(ctx, c.ID, UpdateInput{Title: &title})
	if err != nil {
		t.Fatalf("rename: %v", err)
	}
	if got.WorkDir != dir {
		t.Fatalf("an absent workDir key must leave the residency alone, got %q", got.WorkDir)
	}
	if len(marker.calls) != 1 {
		t.Fatalf("an unrelated PATCH must not mark, calls=%v", marker.calls)
	}
}

// TestUpdate_WorkDirNormalizesAndRejects: `~` is expanded and the path Cleaned at WRITE time, so every
// downstream reader (ExpandIn / Inside / cmd.Dir) gets a real absolute path and never has to guess. A
// relative string is refused ONCE here rather than failing silently on every later tool call.
//
// TestUpdate_WorkDirNormalizesAndRejects：`~` 在**写时**展开、路径在写时 Clean，故每个下游读者（ExpandIn /
// Inside / cmd.Dir）拿到的都是真绝对路径、永不必猜。相对字符串在此被拒**一次**，而不是在此后每次工具调用里
// 静默失效。
func TestUpdate_WorkDirNormalizesAndRejects(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "zoom")

	home, homeErr := os.UserHomeDir()
	if homeErr == nil && home != "" {
		tilde := "~/projects/anselm"
		got, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &tilde})
		if err != nil {
			t.Fatalf("~ mount: %v", err)
		}
		if want := filepath.Join(home, "projects/anselm"); got.WorkDir != want {
			t.Fatalf("~ must be expanded at write time: got %q, want %q", got.WorkDir, want)
		}
	}

	messy := "/proj/./sub/../lib/"
	got, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &messy})
	if err != nil {
		t.Fatalf("messy mount: %v", err)
	}
	if got.WorkDir != "/proj/lib" {
		t.Fatalf("the stored path must be Cleaned: got %q", got.WorkDir)
	}

	for _, bad := range []string{"relative/path", "./here", "..", "~someone/else"} {
		if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &bad}); !errors.Is(err, conversationdomain.ErrInvalidWorkDir) {
			t.Errorf("workDir %q must be rejected with ErrInvalidWorkDir, got %v", bad, err)
		}
	}
	// The rejected writes left the last good value in place. 被拒的写保留了上一个好值。
	after, err := svc.Get(ctx, c.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if after.WorkDir != "/proj/lib" {
		t.Fatalf("a rejected patch must not disturb the stored residency, got %q", after.WorkDir)
	}
}

// TestUpdate_WorkDirAcceptsNonExistentPath: existence is NOT validated at write time. A directory the user
// later moves or deletes is a legitimate, renderable state (WorkDirInfo.Exists=false), so demanding it
// here would reject an honest mount for a condition that can change a second afterwards.
//
// TestUpdate_WorkDirAcceptsNonExistentPath：写时**不**校验存在性。被用户日后移走或删掉的目录是合法且可渲染
// 的状态（WorkDirInfo.Exists=false），故在此强求它，等于为一个下一秒就可能改变的条件拒掉一次诚实的挂载。
func TestUpdate_WorkDirAcceptsNonExistentPath(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "zoom")
	ghost := filepath.Join(t.TempDir(), "not-there-yet")
	got, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &ghost})
	if err != nil {
		t.Fatalf("a not-yet-existing directory must be mountable: %v", err)
	}
	if got.WorkDir != ghost {
		t.Fatalf("workDir = %q, want %q", got.WorkDir, ghost)
	}
	info, err := svc.WorkDirInfo(ctx, c.ID)
	if err != nil {
		t.Fatalf("workdir info: %v", err)
	}
	if info.Path != ghost || info.Exists {
		t.Fatalf("the projection must report it honestly as missing: %+v", info)
	}
}

// TestUpdate_WorkDirMarkerFailureNeverBlocksTheSwitch: the mark is decoration; the residency itself is
// already on the row. Refusing the user's switch because a marker write failed would be the tail wagging
// the dog.
//
// TestUpdate_WorkDirMarkerFailureNeverBlocksTheSwitch：标记是装饰；驻地本身已经在行上。因为一条标记没写成
// 而拒掉用户的切换是本末倒置。
func TestUpdate_WorkDirMarkerFailureNeverBlocksTheSwitch(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	svc.SetWorkDirMarker(&recordingMarker{err: errors.New("messages table on fire")})
	c, _ := svc.Create(ctx, "zoom")
	dir := t.TempDir()
	got, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir})
	if err != nil {
		t.Fatalf("a failing marker must not fail the PATCH: %v", err)
	}
	if got.WorkDir != dir {
		t.Fatalf("workDir = %q, want %q", got.WorkDir, dir)
	}
}

// TestWorkDirInfo_UnmountedIsSuccessNot404: "this thread has no residency" is a successful answer, and the
// button that calls this has to render the unmounted state too.
//
// TestWorkDirInfo_UnmountedIsSuccessNot404：「这条线程没有驻地」是一个**成功**的回答，而调用它的那个按钮也
// 得渲染未挂态。
func TestWorkDirInfo_UnmountedIsSuccessNot404(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "plain")
	info, err := svc.WorkDirInfo(ctx, c.ID)
	if err != nil {
		t.Fatalf("an unmounted conversation must not error: %v", err)
	}
	if info.Path != "" || info.Exists || info.IsGitRepo || info.Branch != "" || info.Dirty {
		t.Fatalf("unmounted must be the zero projection, got %+v", info)
	}
	if _, err := svc.WorkDirInfo(ctx, "cv_nope"); !errors.Is(err, conversationdomain.ErrNotFound) {
		t.Fatalf("only an unknown CONVERSATION is a 404, got %v", err)
	}
}

// TestWorkDirInfo_PlainDirectoryIsNotARepo: a real directory that is not a git repo reports exists=true and
// isGitRepo=false, and a FILE at the path is not a usable residency at all.
//
// TestWorkDirInfo_PlainDirectoryIsNotARepo：一个真实但非 git 仓库的目录报 exists=true / isGitRepo=false，
// 而路径上是**文件**则根本不是可用驻地。
func TestWorkDirInfo_PlainDirectoryIsNotARepo(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	c, _ := svc.Create(ctx, "plain dir")
	base := t.TempDir()
	dir := filepath.Join(base, "plain")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir}); err != nil {
		t.Fatalf("mount: %v", err)
	}
	info, err := svc.WorkDirInfo(ctx, c.ID)
	if err != nil {
		t.Fatalf("info: %v", err)
	}
	if !info.Exists || info.IsGitRepo || info.Branch != "" || info.Dirty {
		t.Fatalf("a plain directory: %+v", info)
	}

	asFile := filepath.Join(base, "a-file")
	if err := os.WriteFile(asFile, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &asFile}); err != nil {
		t.Fatalf("mount file: %v", err)
	}
	info, err = svc.WorkDirInfo(ctx, c.ID)
	if err != nil {
		t.Fatalf("info: %v", err)
	}
	if info.Exists {
		t.Fatalf("a regular file is not a usable work dir: %+v", info)
	}
}

// TestFork_InheritsWorkDir: the residency is what the copied conversation was ABOUT, and the prefix the
// fork inherits is full of tool calls that ran in that directory — a fork landing nowhere would make every
// relative path in its own history unreadable.
//
// TestFork_InheritsWorkDir：驻地正是被复制的那段对话**在谈的地方**，而分叉继承的前缀里满是在那个目录里跑过
// 的工具调用——一个落在虚空里的分叉会让它自己历史中的每个相对路径都读不懂。
func TestFork_InheritsWorkDir(t *testing.T) {
	svc, _, _, ctx := newSvc(t)
	src, _ := svc.Create(ctx, "source")
	dir := t.TempDir()
	mounted, err := svc.Update(ctx, src.ID, UpdateInput{WorkDir: &dir})
	if err != nil {
		t.Fatalf("mount: %v", err)
	}
	fork, err := svc.Fork(ctx, conversationdomain.ForkInput{Source: mounted, AtMessageID: "msg_1"})
	if err != nil {
		t.Fatalf("fork: %v", err)
	}
	if fork.WorkDir != dir {
		t.Fatalf("a fork must inherit the residency: got %q, want %q", fork.WorkDir, dir)
	}
}
