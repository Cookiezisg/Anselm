package shell

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// pwdCommand prints the shell's current directory on either platform. POSIX uses `pwd -P` (PHYSICAL)
// on purpose: the plain builtin prints $PWD, which sh inherits from the backend's own environment, so on
// macOS it happily reports a stale logical path (/tmp/…) for a child actually sitting in /private/tmp/…
// — the assertion would then be testing the parent's env var, not cmd.Dir.
//
// pwdCommand 在两个平台上都打印 shell 的当前目录。POSIX **刻意**用 `pwd -P`（物理路径）：朴素的 builtin
// 打印 $PWD，而 sh 从后端自己的环境继承它，故在 macOS 上它会给一个实际身处 /private/tmp/… 的子进程报出
// 过期的逻辑路径（/tmp/…）——那样断言测的就是父进程的环境变量、不是 cmd.Dir。
func pwdCommand() string {
	if runtime.GOOS == "windows" {
		return "cd"
	}
	return "pwd -P"
}

// TestBash_RunsInWorkDir: the residency becomes cmd.Dir, so `pwd` reports it. This is the whole of "Bash
// today sets no cmd.Dir" being overturned, asserted through the process's own answer rather than by
// inspecting the struct — the struct field could be set and still not take effect.
//
// TestBash_RunsInWorkDir：驻地成为 cmd.Dir，故 `pwd` 报的就是它。这就是「Bash 今天不设 cmd.Dir」被翻案的
// 全部，且是**经进程自己的回答**断言、而非查看结构体字段——字段设上了也仍可能不生效。
func TestBash_RunsInWorkDir(t *testing.T) {
	root := t.TempDir()
	real, err := filepath.EvalSymlinks(root)
	if err != nil {
		t.Fatal(err)
	}
	b := &Bash{mgr: NewProcessManager("")}
	ctx := reqctxpkg.SetWorkDir(context.Background(), root)

	out, err := b.Execute(ctx, `{"command":"`+pwdCommand()+`"}`)
	if err != nil {
		t.Fatalf("Execute err = %v", err)
	}
	if !strings.Contains(out, real) {
		t.Fatalf("the child must run IN the residency: want %q in output, got %q", real, out)
	}
}

// TestBash_RelativeCommandSeesWorkDirContents: the point of cmd.Dir is not `pwd` — it is that a relative
// reference in the COMMAND means the user's "here".
//
// TestBash_RelativeCommandSeesWorkDirContents：cmd.Dir 的意义不在 `pwd`——而在于**命令里**的相对引用表示
// 用户所说的「这里」。
func TestBash_RelativeCommandSeesWorkDirContents(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX cat/ls shape")
	}
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "marker.txt"), []byte("FOUND-IT\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	b := &Bash{mgr: NewProcessManager("")}
	ctx := reqctxpkg.SetWorkDir(context.Background(), root)

	out, err := b.Execute(ctx, `{"command":"cat marker.txt"}`)
	if err != nil {
		t.Fatalf("Execute err = %v", err)
	}
	if !strings.Contains(out, "FOUND-IT") {
		t.Fatalf("a relative reference in the command must resolve in the residency, got %q", out)
	}
}

// TestBash_NoResidencyKeepsProcessDir: unmounted → no Dir is set and the child inherits the backend's own
// directory. The default path must be untouched by WD1.
//
// TestBash_NoResidencyKeepsProcessDir：未挂 → 不设 Dir，子进程继承后端自己的目录。默认路径必须不被 WD1 碰到。
func TestBash_NoResidencyKeepsProcessDir(t *testing.T) {
	own, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	real, err := filepath.EvalSymlinks(own)
	if err != nil {
		t.Fatal(err)
	}
	b := &Bash{mgr: NewProcessManager("")}
	out, err := b.Execute(context.Background(), `{"command":"`+pwdCommand()+`"}`)
	if err != nil {
		t.Fatalf("Execute err = %v", err)
	}
	if !strings.Contains(out, real) {
		t.Fatalf("without a residency the child must inherit the backend's dir %q, got %q", real, out)
	}
}

// TestBash_UnusableWorkDirRefusesLoudly: a residency the user moved or deleted is REFUSED, not silently
// downgraded to the backend's own directory — the silent version would run every relative path in the
// command against the wrong tree while the thread still claims to live somewhere else.
//
// TestBash_UnusableWorkDirRefusesLoudly：被用户移走或删掉的驻地**予以拒绝**、不静默降级到后端自己的目录——
// 静默那版会把命令里每个相对路径打到错误的树上，而线程仍声称自己住在别处。
func TestBash_UnusableWorkDirRefusesLoudly(t *testing.T) {
	base := t.TempDir()
	gone := filepath.Join(base, "gone")
	asFile := filepath.Join(base, "a-file")
	if err := os.WriteFile(asFile, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	b := &Bash{mgr: NewProcessManager("")}
	for _, dir := range []string{gone, asFile} {
		ctx := reqctxpkg.SetWorkDir(context.Background(), dir)
		out, err := b.Execute(ctx, `{"command":"`+pwdCommand()+`"}`)
		if err != nil {
			t.Fatalf("Execute err = %v", err)
		}
		if !strings.Contains(out, "no longer usable") || !strings.Contains(out, dir) {
			t.Errorf("an unusable residency %q must refuse loudly and name itself, got %q", dir, out)
		}
	}
}

// TestBash_BackgroundRunsInWorkDir: the detached child gets the residency too. It is passed explicitly
// because that path deliberately uses context.Background() — the residency must outlive the turn exactly
// as the process does, and reading a dead ctx would have silently produced "".
//
// TestBash_BackgroundRunsInWorkDir：detached 子进程同样拿到驻地。它是**显式**传入的，因为那条路径刻意用
// context.Background()——驻地必须像进程本身一样活过该回合，而去读一个已死的 ctx 会静默得到 ""。
func TestBash_BackgroundRunsInWorkDir(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX pwd shape")
	}
	root := t.TempDir()
	real, err := filepath.EvalSymlinks(root)
	if err != nil {
		t.Fatal(err)
	}
	mgr := NewProcessManager("")
	t.Cleanup(mgr.Stop)
	b := &Bash{mgr: mgr}
	ctx := reqctxpkg.SetWorkDir(context.Background(), root)

	start, err := b.Execute(ctx, `{"command":"pwd -P","run_in_background":true}`)
	if err != nil {
		t.Fatalf("Execute err = %v", err)
	}
	id := bashIDFrom(t, start)
	out := &BashOutput{mgr: mgr}
	var got string
	for range 100 {
		res, err := out.Execute(context.Background(), `{"bash_id":"`+id+`"}`)
		if err != nil {
			t.Fatalf("BashOutput err = %v", err)
		}
		got += res
		if strings.Contains(got, real) {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("background child must run IN the residency: want %q, got %q", real, got)
}

// bashIDFrom pulls the bash_id out of the start message ("... (bash_id=X): cmd").
//
// bashIDFrom 从启动消息里取出 bash_id（"... (bash_id=X): cmd"）。
func bashIDFrom(t *testing.T, start string) string {
	t.Helper()
	_, after, found := strings.Cut(start, "bash_id=")
	if !found {
		t.Fatalf("start message carries no bash_id: %q", start)
	}
	id, _, _ := strings.Cut(after, ")")
	if strings.TrimSpace(id) == "" {
		t.Fatalf("empty bash_id in %q", start)
	}
	return id
}
