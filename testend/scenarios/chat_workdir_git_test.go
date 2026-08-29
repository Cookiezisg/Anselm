// chat_workdir_git_test.go — WRK-077 WD2 + WD3 的黑盒验收:驻地的 git 段**可操作**。
//
// 两条场景，各盯住一件在别处证不出来的事:
//   - **切分支后投影真的变了**——线缆上的 `branch` 必须跟着 HEAD 走，而不是回显请求。同一条场景里另钉住那道
//     **护栏**:脏工作区切分支被拒 422 `CONVERSATION_WORK_DIR_DIRTY`，且拒完之后 HEAD 与那个未提交文件**分毫未动**
//     （没 `--force`、没静默 stash）。
//   - **worktree 一条龙**——一次请求之后:目录真的在盘上、分支是 `wt/<name>`、**该对话的驻地已切过去**（行与投影
//     都是新目录）、线程上多了一条 `marker`。四件事缺一件，这个功能就是半个。
//
// 夹具是**真仓库**（`git init` + 一次提交），路径由 `git rev-parse --show-toplevel` 自己给——测试绝不假定自己那种
// 拼法胜出（macOS 上 `t.TempDir()` 在 `/var/…`，而 git 报 `/private/var/…`;后端按 git 的答案派生兄弟目录，故期望值
// 也必须按 git 的答案算）。
package scenarios

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// wdGitRepo builds a real repository with one commit, skipping when the host has no git — the read side's
// contract is that git's absence is not an error, so the TEST must not invent one.
//
// wdGitRepo 造一个带一次提交的真仓库;本机无 git 时 skip——读侧的契约是「git 不存在不是错误」，故**测试**不该自己
// 造一个错误。
func wdGitRepo(t *testing.T) string {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git binary — the residency's git segment is optional by contract")
	}
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init", "--initial-branch=main"},
		{"config", "user.email", "t@example.com"},
		{"config", "user.name", "t"},
	} {
		wdGit(t, dir, args...)
	}
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("a\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	wdGit(t, dir, "add", ".")
	wdGit(t, dir, "commit", "-m", "init")
	return dir
}

func wdGit(t *testing.T, dir string, args ...string) string {
	t.Helper()
	out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused: the wire must not be able to disagree
// with git. The projection's `branch` is re-probed AFTER the checkout, so a client that renders the response
// is already showing the truth — and `branches[]` is what made the switch offerable in the first place.
//
// The guardrail is asserted in the same scenario because the two only mean something together: the action
// works, AND it refuses to work when working would silently relocate the user's uncommitted changes onto
// another branch. After the refusal, the HEAD and the untracked file must both be exactly where they were.
//
// TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused:线缆不得与 git 意见不一致。投影的 `branch`
// 是在 checkout **之后**重探的，故一个直接渲染响应的客户端已经在显示真相——而 `branches[]` 正是让这次切换一开始
// 就能被提议的东西。
//
// 护栏在同一条场景里断言，因为两者只有在一起才有意义:这个动作能用，**并且**当「能用」意味着把用户未提交的改动
// 静默搬到另一条分支上时它拒绝用。拒绝之后，HEAD 与那个未跟踪文件必须都还在原处。
func TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused(t *testing.T) {
	t.Parallel()
	wc, _ := chatSetup(t, false)
	repo := wdGitRepo(t)
	wdGit(t, repo, "branch", "second")

	convID := convCreate(t, wc, "git segment")
	wdMount(t, wc, convID, repo)

	// The projection now OFFERS the switch: a menu cannot propose a branch nobody listed.
	// 投影现在**提供**这次切换:没人列出来的分支，菜单无从提议。
	info := wdGitInfo(t, wc, convID)
	if !info.IsGitRepo || info.Branch != "main" {
		t.Fatalf("mounted on a repo: %+v", info)
	}
	if len(info.Branches) != 2 || !wdHas(info.Branches, "second") {
		t.Fatalf("branches[] must list both local heads, got %v", info.Branches)
	}
	// `worktrees[]` always carries the tree you are standing in, flagged — that is the honest answer to
	// "which worktrees does this repo have". `worktrees[]` 恒带你正站着的那棵树并标出它——那是「这个仓库有哪些
	// worktree」的诚实答案。
	if len(info.Worktrees) != 1 || !info.Worktrees[0].Current {
		t.Fatalf("worktrees[] must carry the current tree: %+v", info.Worktrees)
	}

	// ── the switch: the RESPONSE is already the new truth ──
	var after wdGitInfoRow
	wc.POST("/api/v1/conversations/"+convID+"/workdir:switch-branch",
		map[string]any{"branch": "second"}).OK(t, &after)
	if after.Branch != "second" {
		t.Fatalf("the action's own response still says %q — a stale answer forces a second read and one frame of the old branch", after.Branch)
	}
	if live := wdGit(t, repo, "rev-parse", "--abbrev-ref", "HEAD"); live != "second" {
		t.Fatalf("git says HEAD is %q — the wire must not be able to disagree with git", live)
	}
	if re := wdGitInfo(t, wc, convID); re.Branch != "second" {
		t.Fatalf("a fresh projection read says %q, want second", re.Branch)
	}
	// The RESIDENCY did not move — a branch switch is not a residency change, so no `marker` either.
	// 驻地**没有**移动——切分支不是驻地变更，故也不落 `marker`。
	if after.Path != repo {
		t.Fatalf("a branch switch must not move the residency: %q → %q", repo, after.Path)
	}
	if n := markerBlocks(t, wc, convID); len(n) != 0 {
		t.Fatalf("a branch switch must leave no residency marker, got %v", n)
	}

	// ── THE GUARDRAIL: uncommitted work makes the switch refuse ──
	if err := os.WriteFile(filepath.Join(repo, "wip.txt"), []byte("half a thought\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := wdGitInfo(t, wc, convID); !got.Dirty {
		t.Fatalf("an untracked file must read dirty: %+v", got)
	}
	r := wc.POST("/api/v1/conversations/"+convID+"/workdir:switch-branch", map[string]any{"branch": "main"})
	r.Fail(t, 422, "CONVERSATION_WORK_DIR_DIRTY")
	// The refusal must name the NEXT STEP — a dead end is worse than no button at all.
	// 这次拒绝必须点出**下一步**——一条死路比根本没有那个按钮更糟。
	if !strings.Contains(r.Msg, "commit") || !strings.Contains(r.Msg, "stash") {
		t.Fatalf("the refusal must say what to do next, got %q", r.Msg)
	}
	// Nothing moved and nothing was hidden: same HEAD, the file still there, no stash created.
	// 什么都没搬、什么都没藏:HEAD 未变、文件还在、没造出 stash。
	if live := wdGit(t, repo, "rev-parse", "--abbrev-ref", "HEAD"); live != "second" {
		t.Fatalf("a refused switch must leave HEAD alone, got %q", live)
	}
	if _, err := os.Stat(filepath.Join(repo, "wip.txt")); err != nil {
		t.Fatalf("the user's uncommitted file must survive a refusal: %v", err)
	}
	if out := wdGit(t, repo, "stash", "list"); out != "" {
		t.Fatalf("a refused switch must never stash — a silent stash is how work disappears; got %q", out)
	}

	// CREATING a branch is deliberately NOT gated: it starts at the current HEAD, so the work tree does not
	// change and no conflict can exist. 新建分支刻意**不**受此门:它从当前 HEAD 起，工作树不变、冲突不可能存在。
	var made wdGitInfoRow
	wc.POST("/api/v1/conversations/"+convID+"/workdir:create-branch",
		map[string]any{"branch": "feat/from-dirty"}).OK(t, &made)
	if made.Branch != "feat/from-dirty" || !made.Dirty {
		t.Fatalf("a create from a dirty tree must succeed and carry the work along: %+v", made)
	}
	// A name git itself refuses never reaches a command (arguments are passed as an array, so injection is
	// impossible; this asserts the REFUSAL is explicit). git 自己就拒的名字永不抵达一条命令（参数以数组传递，
	// 注入不可能;此处断言那次**拒绝**是显式的）。
	wc.POST("/api/v1/conversations/"+convID+"/workdir:switch-branch",
		map[string]any{"branch": "--upload-pack=evil"}).Fail(t, 422, "CONVERSATION_INVALID_BRANCH")
	wc.POST("/api/v1/conversations/"+convID+"/workdir:switch-branch",
		map[string]any{"branch": "never-existed"}).Fail(t, 404, "CONVERSATION_BRANCH_NOT_FOUND")
	wc.POST("/api/v1/conversations/"+convID+"/workdir:create-branch",
		map[string]any{"branch": "main"}).Fail(t, 409, "CONVERSATION_BRANCH_EXISTS")
}

// TestChatWorkDirGit_WorktreeOneShot: WD3's whole promise in one request — the directory exists, the branch is
// `wt/<name>`, THE CONVERSATION'S RESIDENCY MOVED THERE, and the thread carries the durable `marker`. Any one
// of the four missing makes this half a feature, which is why they are asserted together and from OUTSIDE.
//
// The path is checked against `make worktree`'s literal convention (a SIBLING of the repository named
// `<repo>-<name>`), because an app-made worktree and a discipline-made one must be the same object — otherwise
// the user has two conventions to remember and one of them is a trap.
//
// TestChatWorkDirGit_WorktreeOneShot:WD3 的全部承诺在**一次**请求里——目录在盘上、分支是 `wt/<name>`、**该对话的
// 驻地已切过去**、线程带上了那条持久 `marker`。四件里缺任何一件这个功能就是半个，故它们一起、且从**外部**断言。
//
// 路径是对着 `make worktree` 的**字面**约定核的（仓库的**兄弟**位、名为 `<repo>-<name>`），因为 app 建的 worktree
// 与纪律建的必须是**同一种**对象——否则用户要记两套约定，而其中一套是陷阱。
func TestChatWorkDirGit_WorktreeOneShot(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	repo := wdGitRepo(t)
	top := wdGit(t, repo, "rev-parse", "--show-toplevel")
	want := filepath.Join(filepath.Dir(top), filepath.Base(top)+"-wd3")

	convID := convCreate(t, wc, "one shot")
	wdMount(t, wc, convID, repo)
	// The thread has to SPEAK first: WD1 legislated that a residency change on a silent thread leaves no
	// marker (there is no "before" yet), so a worktree opened on a fresh thread would prove nothing about
	// the mark. 线程必须先**说话**:WD1 立法「空线程的驻地变更不落标记」（还没有「之前」），故在一条全新线程上开
	// worktree 对那条标记什么都证明不了。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "let's parallelize."})
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, "open a worktree"), 30000)

	var info wdGitInfoRow
	wc.POST("/api/v1/conversations/"+convID+"/workdir:add-worktree",
		map[string]any{"name": "wd3"}).OK(t, &info)

	// ① the directory really exists, at the `make worktree` sibling position
	if info.Path != want {
		t.Fatalf("residency = %q, want the `make worktree` sibling %q", info.Path, want)
	}
	st, err := os.Stat(want)
	if err != nil || !st.IsDir() {
		t.Fatalf("the worktree directory must exist on disk: %v", err)
	}
	// ② the branch follows the convention too
	if info.Branch != "wt/wd3" {
		t.Fatalf("branch = %q, want wt/wd3 (`make worktree` names it that)", info.Branch)
	}
	// ③ the CONVERSATION's residency moved — the row, not just the projection
	var head struct {
		WorkDir string `json:"workDir"`
	}
	wc.GET("/api/v1/conversations/"+convID).OK(t, &head)
	if head.WorkDir != want {
		t.Fatalf("the conversation row still lives at %q — the one-shot is exactly that it moves", head.WorkDir)
	}
	// The projection knows which of the two trees it is now standing in.
	// 投影知道自己现在站在两棵树中的哪一棵。
	if len(info.Worktrees) != 2 {
		t.Fatalf("both checkouts must be listed: %+v", info.Worktrees)
	}
	var currents int
	for _, w := range info.Worktrees {
		if w.Current {
			currents++
			if w.Path != want {
				t.Fatalf("current worktree = %q, want %q", w.Path, want)
			}
		}
	}
	if currents != 1 {
		t.Fatalf("exactly one worktree may be current, got %d in %+v", currents, info.Worktrees)
	}
	// ④ the thread carries WD1's existing `marker` block — reused, not a new block type (D1: append only)
	marks := markerBlocks(t, wc, convID)
	if len(marks) != 1 {
		t.Fatalf("the residency move must leave exactly one marker, got %d: %v", len(marks), marks)
	}
	if marks[0].Attrs["kind"] != "workdir" || marks[0].Attrs["from"] != repo || marks[0].Attrs["to"] != want {
		t.Fatalf("marker attrs must record both ends: %v (want from=%q to=%q)", marks[0].Attrs, repo, want)
	}

	// ── the two collisions ──
	// A NAME that is not one path segment is refused before git is invoked — the endpoint takes a name and
	// DERIVES the target, which is what keeps it from ever writing a checkout somewhere else on the disk.
	// 不是单个路径段的**名字**在 git 被调用之前就被拒——端点收名字、自己**派生**目标，正是这一点让它永不可能往
	// 磁盘别处写出一份 checkout。
	for _, bad := range []string{"../escape", "/absolute", "nested/deep", "..", "-b"} {
		wc.POST("/api/v1/conversations/"+convID+"/workdir:add-worktree",
			map[string]any{"name": bad}).Fail(t, 422, "CONVERSATION_INVALID_WORKTREE_NAME")
	}
	// Asking for the SAME name again refuses on the DIRECTORY, and names it: the directory holds somebody's
	// work — possibly another session's — and adopting it silently is how two agents come to edit one tree.
	// 再要**同一个**名字会因**目录**被拒，且点出它:那个目录装着某人的活、可能是另一个会话的，而静默接管它正是两个
	// agent 编辑同一棵树的方式。
	dup := wc.POST("/api/v1/conversations/"+convID+"/workdir:add-worktree", map[string]any{"name": "wd3"})
	dup.Fail(t, 409, "CONVERSATION_WORKTREE_EXISTS")
	// The residency did not move on a refusal, and no second marker was written.
	// 拒绝时驻地没动，也没写第二条标记。
	if got := wdGitInfo(t, wc, convID); got.Path != want {
		t.Fatalf("a refused worktree must leave the residency alone, got %q", got.Path)
	}
	if marks := markerBlocks(t, wc, convID); len(marks) != 1 {
		t.Fatalf("a refused worktree must not mark the thread, got %d marks", len(marks))
	}
}

// TestChatWorkDirGit_ReusesExistingBranch: the HTTP route must preserve the Makefile recovery path.
// A branch left behind by `make worktree-rm` is reusable; the endpoint must not demand a fresh branch
// or report a false conflict when its sibling target does not exist yet.
//
// TestChatWorkDirGit_ReusesExistingBranch:HTTP 入口必须保留 Makefile 的恢复路径。`make worktree-rm` 留下的分支可以
// 复用；只要目标兄弟目录尚不存在，端点就不能强求新分支，也不能误报冲突。
func TestChatWorkDirGit_ReusesExistingBranch(t *testing.T) {
	t.Parallel()
	wc, _ := chatSetup(t, false)
	repo := wdGitRepo(t)
	wdGit(t, repo, "branch", "wt/kept")
	top := wdGit(t, repo, "rev-parse", "--show-toplevel")
	want := filepath.Join(filepath.Dir(top), filepath.Base(top)+"-kept")

	convID := convCreate(t, wc, "reuse a worktree branch")
	wdMount(t, wc, convID, repo)
	var info wdGitInfoRow
	wc.POST("/api/v1/conversations/"+convID+"/workdir:add-worktree",
		map[string]any{"name": "kept"}).OK(t, &info)
	if info.Path != want || info.Branch != "wt/kept" {
		t.Fatalf("existing branch must be reused at the derived sibling: path=%q branch=%q", info.Path, info.Branch)
	}
	if _, err := os.Stat(want); err != nil {
		t.Fatalf("reusing the existing branch must create the worktree directory: %v", err)
	}

	var head struct {
		WorkDir string `json:"workDir"`
	}
	wc.GET("/api/v1/conversations/"+convID).OK(t, &head)
	if head.WorkDir != want {
		t.Fatalf("conversation residency = %q, want reused worktree %q", head.WorkDir, want)
	}
}

// wdGitInfoRow is the projection as WD2/WD3 extend it — the WD1 shape plus the two bounded lists.
//
// wdGitInfoRow 是被 WD2/WD3 扩写后的投影——WD1 那个形状 + 两个有界列表。
type wdGitInfoRow struct {
	Path      string   `json:"path"`
	Exists    bool     `json:"exists"`
	IsGitRepo bool     `json:"isGitRepo"`
	Branch    string   `json:"branch"`
	Dirty     bool     `json:"dirty"`
	Branches  []string `json:"branches"`
	Worktrees []struct {
		Path    string `json:"path"`
		Branch  string `json:"branch"`
		Current bool   `json:"current"`
	} `json:"worktrees"`
}

func wdGitInfo(t *testing.T, wc *harness.Client, convID string) wdGitInfoRow {
	t.Helper()
	var info wdGitInfoRow
	wc.GET("/api/v1/conversations/"+convID+"/workdir").OK(t, &info)
	return info
}

func wdHas(list []string, want string) bool {
	for _, s := range list {
		if s == want {
			return true
		}
	}
	return false
}
