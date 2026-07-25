package filesystem

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	agentstatepkg "github.com/sunweilin/anselm/backend/internal/pkg/agentstate"
	pathguardpkg "github.com/sunweilin/anselm/backend/internal/pkg/pathguard"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// residencyCtx returns a ctx with an AgentState (the tools' fail-closed requirement) and a mounted work
// dir, so each test exercises the real seeded shape rather than a half-configured one.
//
// residencyCtx 返回带 AgentState（工具 fail-closed 的前提）与已挂工作目录的 ctx，使每个测试走的是真实的
// 播种形态、而不是半配好的形态。
func residencyCtx(root string) (context.Context, *agentstatepkg.AgentState) {
	state := agentstatepkg.New()
	ctx := reqctxpkg.WithAgentState(context.Background(), state)
	return reqctxpkg.SetWorkDir(ctx, root), state
}

// TestWrite_RelativePathResolvesAgainstWorkDir: with a residency, `notes.md` lands in the work dir. Before
// WD1 this exact call was refused as "must be absolute", so the assertion is the feature.
//
// TestWrite_RelativePathResolvesAgainstWorkDir：挂了驻地时 `notes.md` 落在工作目录里。WD1 之前这**同一次**
// 调用会被以「必须绝对」拒掉，故这个断言就是本功能本身。
func TestWrite_RelativePathResolvesAgainstWorkDir(t *testing.T) {
	root := t.TempDir()
	ctx, _ := residencyCtx(root)
	w := &Write{pathGuard: pathguardpkg.New(nil)}

	out, err := w.Execute(ctx, `{"file_path":"notes.md","content":"hello"}`)
	if err != nil {
		t.Fatalf("Execute err = %v", err)
	}
	want := filepath.Join(root, "notes.md")
	if !strings.Contains(out, want) {
		t.Fatalf("result must name the resolved path %q, got %q", want, out)
	}
	got, readErr := os.ReadFile(want)
	if readErr != nil || string(got) != "hello" {
		t.Fatalf("file must exist inside the residency: err=%v content=%q", readErr, got)
	}
}

// TestWrite_NestedRelativeAndAbsoluteBothWork: a relative path with subdirectories resolves under the
// root, and an ABSOLUTE path outside the root still writes — the residency is a zoom, not a cage. (The
// human gate that guards the outside write lives in loop, not here; this tool must not double-refuse.)
//
// TestWrite_NestedRelativeAndAbsoluteBothWork：带子目录的相对路径解析到根下，而根外的**绝对**路径照样写得
// 进去——驻地是 zoom、不是笼子。（守着那次外部写的人闸在 loop、不在此处；本工具不该重复拒绝。）
func TestWrite_NestedRelativeAndAbsoluteBothWork(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "root")
	if err := os.MkdirAll(filepath.Join(root, "sub"), 0o755); err != nil {
		t.Fatal(err)
	}
	ctx, _ := residencyCtx(root)
	w := &Write{pathGuard: pathguardpkg.New(nil)}

	if _, err := w.Execute(ctx, `{"file_path":"sub/deep.txt","content":"a"}`); err != nil {
		t.Fatalf("nested relative: %v", err)
	}
	if _, err := os.Stat(filepath.Join(root, "sub", "deep.txt")); err != nil {
		t.Fatalf("nested relative must land under the root: %v", err)
	}

	outside := filepath.Join(base, "elsewhere.txt")
	if _, err := w.Execute(ctx, `{"file_path":`+jsonStr(outside)+`,"content":"b"}`); err != nil {
		t.Fatalf("absolute outside: %v", err)
	}
	if _, err := os.Stat(outside); err != nil {
		t.Fatalf("an absolute path outside the residency must still be writable (the gate is loop's job): %v", err)
	}
}

// TestWrite_RelativeStillRefusedWithoutResidency: no work dir → the pre-WD1 refusal, verbatim. The
// message is the LLM's only clue, so it must name the real reason.
//
// TestWrite_RelativeStillRefusedWithoutResidency：无工作目录 → 逐字保持 WD1 之前的拒绝。那条消息是 LLM
// 唯一的线索，故它必须说出真实原因。
func TestWrite_RelativeStillRefusedWithoutResidency(t *testing.T) {
	state := agentstatepkg.New()
	ctx := reqctxpkg.WithAgentState(context.Background(), state)
	w := &Write{pathGuard: pathguardpkg.New(nil)}
	out, err := w.Execute(ctx, `{"file_path":"notes.md","content":"x"}`)
	if err != nil {
		t.Fatalf("Execute err = %v", err)
	}
	if !strings.Contains(out, "must be absolute") {
		t.Fatalf("unmounted conversation must still refuse a relative path, got %q", out)
	}
}

// TestRead_RelativePathResolvesAgainstWorkDir: reads get the same root. Read is where a relative path is
// most natural ("open main.go") and it must not be the one tool that still refuses.
//
// TestRead_RelativePathResolvesAgainstWorkDir：读也用同一个根。Read 正是相对路径最自然的地方（「打开
// main.go」），它绝不能成为唯一还在拒绝的那个工具。
func TestRead_RelativePathResolvesAgainstWorkDir(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "main.go"), []byte("package main\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	ctx, _ := residencyCtx(root)
	r := &Read{pathGuard: pathguardpkg.New(nil)}
	out, err := r.Execute(ctx, `{"file_path":"main.go"}`)
	if err != nil {
		t.Fatalf("Execute err = %v", err)
	}
	if !strings.Contains(out, "package main") {
		t.Fatalf("relative read must resolve against the residency, got %q", out)
	}
}

// TestEdit_RelativePathResolvesAgainstWorkDir: Edit's write-before-read guard must see the SAME resolved
// path Read stamped, or a relative Read followed by a relative Edit would refuse itself.
//
// TestEdit_RelativePathResolvesAgainstWorkDir：Edit 的写前必读守卫必须看到与 Read 盖章的**同一个**解析
// 路径，否则「相对 Read 之后紧接相对 Edit」会自己拒掉自己。
func TestEdit_RelativePathResolvesAgainstWorkDir(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "a.txt")
	if err := os.WriteFile(target, []byte("before\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	ctx, _ := residencyCtx(root)
	guard := pathguardpkg.New(nil)

	if _, err := (&Read{pathGuard: guard}).Execute(ctx, `{"file_path":"a.txt"}`); err != nil {
		t.Fatalf("read: %v", err)
	}
	out, err := (&Edit{pathGuard: guard}).Execute(ctx, `{"file_path":"a.txt","old_string":"before","new_string":"after"}`)
	if err != nil {
		t.Fatalf("edit: %v", err)
	}
	got, _ := os.ReadFile(target)
	if !strings.Contains(string(got), "after") {
		t.Fatalf("relative Edit must apply to the resolved file; result=%q content=%q", out, got)
	}
}

// TestWriteTarget_RawAndUnresolved: the gate's input is the LLM's own string, untouched. If this ever
// started resolving, there would be two resolvers and eventually two answers.
//
// TestWriteTarget_RawAndUnresolved：闸的输入是 LLM 自己写的那个字符串、原封不动。它一旦开始解析，就会有
// 两个解析器、并最终给出两个答案。
func TestWriteTarget_RawAndUnresolved(t *testing.T) {
	cases := map[string]string{
		`{"file_path":"rel/x.txt"}`: "rel/x.txt",
		`{"file_path":"~/x.txt"}`:   "~/x.txt",
		`{"file_path":"/abs/x"}`:    "/abs/x",
		`{}`:                        "",
		`nonsense`:                  "",
	}
	for args, want := range cases {
		if got := (&Write{}).WriteTarget([]byte(args)); got != want {
			t.Errorf("Write.WriteTarget(%s) = %q, want %q", args, got, want)
		}
		if got := (&Edit{}).WriteTarget([]byte(args)); got != want {
			t.Errorf("Edit.WriteTarget(%s) = %q, want %q", args, got, want)
		}
	}
}

func jsonStr(s string) string { return `"` + strings.ReplaceAll(s, `\`, `\\`) + `"` }
