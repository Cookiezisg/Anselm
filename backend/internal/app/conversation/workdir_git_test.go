package conversation

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	gitinfoinfra "github.com/sunweilin/anselm/backend/internal/infra/gitinfo"
	conversationstore "github.com/sunweilin/anselm/backend/internal/infra/store/conversation"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	"go.uber.org/zap"
)

// The residency's three git actions (WRK-077 WD2 + WD3), asserted on REAL repositories built by `git init`.
// Nothing here is mocked: the whole value of these actions is what git actually does to a work tree, and a
// fake git would prove only that the code calls the functions it calls.
//
// The batch's one real decision — WD2's dirty guardrail — gets its own pair of tests, because it is an
// ASYMMETRY that a reader will assume is a bug unless it is spelled out: switching to an existing branch is
// REFUSED while dirty, creating one is ALLOWED while dirty.
//
// 驻地的三个 git 动作（WRK-077 WD2 + WD3），在由 `git init` 造出的**真**仓库上断言。此处什么都不 mock:这些动作
// 的全部价值就在于 git 真的对一棵工作树做了什么，而一个假 git 只能证明「代码调用了它调用的那些函数」。
//
// 本批唯一真正的决定——WD2 的脏区护栏——独占一对测试，因为它是一处**不对称**，而读者若无人明说就会当它是 bug:
// 脏时切到已存在的分支被**拒**，脏时新建分支被**允许**。

// gitRepoFixture builds a real repository with one commit and returns its path, skipping when the host has no
// git (the read side's contract is that git's absence is not an error, so the TEST must not invent one).
//
// gitRepoFixture 造一个带一次提交的真仓库并返回路径;本机无 git 时 skip（读侧的契约是「git 不存在不是错误」，故
// **测试**不该自己造一个错误）。
func gitRepoFixture(t *testing.T) string {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git binary")
	}
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init", "--initial-branch=main"},
		{"config", "user.email", "t@example.com"},
		{"config", "user.name", "t"},
	} {
		runGit(t, dir, args...)
	}
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("a\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", ".")
	runGit(t, dir, "commit", "-m", "init")
	return dir
}

func runGit(t *testing.T, dir string, args ...string) {
	t.Helper()
	if out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

// dirty writes an untracked file, which is what the residency calls dirty (a brand-new file IS uncommitted
// work). 弄脏:写一个未跟踪文件——那正是驻地所说的脏（一个全新文件**就是**没提交的活）。
func dirty(t *testing.T, dir string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, "scratch.txt"), []byte("wip\n"), 0o644); err != nil {
		t.Fatal(err)
	}
}

// mountedThread creates a conversation whose residency is dir, with the marker recorder attached so the
// worktree one-shot's in-line mark can be asserted.
//
// mountedThread 建一条驻地为 dir 的对话，并挂上标记记录器，使 worktree 一条龙的行内标记可被断言。
func mountedThread(t *testing.T, dir string) (*Service, *recordingMarker, string, context.Context) {
	t.Helper()
	svc, _, _, ctx := newSvc(t)
	marker := &recordingMarker{}
	svc.SetWorkDirMarker(marker)
	c, err := svc.Create(ctx, "git actions")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if dir != "" {
		if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir}); err != nil {
			t.Fatalf("mount %q: %v", dir, err)
		}
		marker.calls = nil // the mount's own mark is not what these tests are about 挂载自己那条标记不是本组测试的题
	}
	return svc, marker, c.ID, ctx
}

// TestWorkDirInfo_ListsBranchesAndWorktrees: the projection's two new fields (WD2 / WD3) are what make the
// menu's git segment ACTIONABLE — you cannot offer to switch to a branch you never listed. `current` is
// decided against the work tree's ROOT, so a residency mounted on a SUBDIRECTORY still knows which worktree
// it is standing in (comparing raw paths would mark none of them and offer a switch to where you already are).
//
// TestWorkDirInfo_ListsBranchesAndWorktrees:投影那两个新字段（WD2 / WD3）正是让菜单 git 段**可操作**的东西——
// 没列出来的分支无从提议切过去。`current` 是对工作树**根**判定的，故挂在**子目录**上的驻地依然知道自己站在哪一份
// worktree 里（直接比路径会一条都标不上、于是提议你切到你已经在的地方）。
func TestWorkDirInfo_ListsBranchesAndWorktrees(t *testing.T) {
	dir := gitRepoFixture(t)
	runGit(t, dir, "branch", "second")
	sub := filepath.Join(dir, "pkg")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	svc, _, id, ctx := mountedThread(t, sub)

	info, err := svc.WorkDirInfo(ctx, id)
	if err != nil {
		t.Fatalf("WorkDirInfo: %v", err)
	}
	if !info.IsGitRepo || info.Branch != "main" {
		t.Fatalf("a subdirectory of a repo is still in the repo: %+v", info)
	}
	if len(info.Branches) != 2 {
		t.Fatalf("branches = %v, want both local heads", info.Branches)
	}
	if len(info.Worktrees) != 1 || !info.Worktrees[0].Current {
		t.Fatalf("the main tree must be listed and flagged current: %+v", info.Worktrees)
	}
	if info.Worktrees[0].Branch != "main" {
		t.Fatalf("worktree branch = %q, want main", info.Worktrees[0].Branch)
	}

	// A PLAIN directory pays for neither list — they would be two guaranteed-empty processes, and a client
	// must be able to tell "no git here" from "a repo with no branches" (which cannot exist).
	// **普通**目录不为这两个列表付钱——它们会是两个必然空手而归的进程,而客户端必须能分辨「这里没有 git」与
	// 「一个没有分支的仓库」（后者不可能存在）。
	plain := t.TempDir()
	svc2, _, id2, ctx2 := mountedThread(t, plain)
	info2, err := svc2.WorkDirInfo(ctx2, id2)
	if err != nil {
		t.Fatalf("WorkDirInfo(plain): %v", err)
	}
	if info2.IsGitRepo || info2.Branches != nil || info2.Worktrees != nil {
		t.Fatalf("a plain directory must carry no git lists: %+v", info2)
	}
}

// TestSwitchBranch_MovesTheHeadAndRepromsTheProjection: the happy path, and the reason the action returns the
// projection instead of a bare 204 — one switch changes several fields at once, so a client forced to re-GET
// is a client that paints one frame of the old branch.
//
// TestSwitchBranch_MovesTheHeadAndRepromsTheProjection:顺路，以及这个动作为何返回投影而不是一个裸 204——一次
// 切换同时改好几个字段，故一个被迫再 GET 一次的客户端就是一个会画出一帧旧分支的客户端。
func TestSwitchBranch_MovesTheHeadAndRepromsTheProjection(t *testing.T) {
	dir := gitRepoFixture(t)
	runGit(t, dir, "branch", "second")
	svc, _, id, ctx := mountedThread(t, dir)

	info, err := svc.SwitchBranch(ctx, id, "second")
	if err != nil {
		t.Fatalf("SwitchBranch: %v", err)
	}
	if info.Branch != "second" {
		t.Fatalf("the returned projection still says %q — a stale answer is worse than none", info.Branch)
	}
	if live, _ := gitinfoinfra.Branch(ctx, dir); live != "second" {
		t.Fatalf("git says the head is %q — the projection must not be able to disagree with git", live)
	}
	// The RESIDENCY did not move: a branch switch is not a residency change, so no marker and no new path.
	// 驻地**没有**移动:切分支不是驻地变更,故不落标记、路径不变。
	if info.Path != dir {
		t.Fatalf("a branch switch must not move the residency: %q → %q", dir, info.Path)
	}
}

// TestSwitchBranch_DirtyIsRefusedWithANextStep: THE GUARDRAIL. Refusing is the only behaviour that cannot lose
// a line of the user's work — git's own "carry it over if I can" makes the surprising outcome the silent
// SUCCESS case, and a silent stash is how work disappears. The refusal must (a) leave the head where it was and
// (b) say what to do next, which is why the message is asserted and not just the code.
//
// TestSwitchBranch_DirtyIsRefusedWithANextStep:**那道护栏**。拒绝是唯一一种不可能丢掉用户一行活的行为——git 自己
// 的「能带过去就带」让那个令人意外的结局成了静默的**成功**路径，而静默 stash 正是活消失的方式。这次拒绝必须
// (a) 把 HEAD 留在原处、(b) 说出下一步该做什么，故断言的是 message、不只是码。
func TestSwitchBranch_DirtyIsRefusedWithANextStep(t *testing.T) {
	dir := gitRepoFixture(t)
	runGit(t, dir, "branch", "second")
	svc, _, id, ctx := mountedThread(t, dir)
	dirty(t, dir)

	_, err := svc.SwitchBranch(ctx, id, "second")
	if !errors.Is(err, conversationdomain.ErrWorkDirDirty) {
		t.Fatalf("a dirty switch must be refused with ErrWorkDirDirty, got %v", err)
	}
	// The next step has to be IN the sentence: a refusal the user cannot act on is a dead end.
	// 下一步必须**在**那句话里:一个用户无从行动的拒绝是一条死路。
	if msg := conversationdomain.ErrWorkDirDirty.Message; !strings.Contains(msg, "commit") || !strings.Contains(msg, "stash") {
		t.Fatalf("the refusal must name the next step, got %q", msg)
	}
	if live, _ := gitinfoinfra.Branch(ctx, dir); live != "main" {
		t.Fatalf("a refused switch must leave the head alone, got %q", live)
	}
	if _, err := os.Stat(filepath.Join(dir, "scratch.txt")); err != nil {
		t.Fatalf("the user's uncommitted file must still be there: %v", err)
	}
	// Nothing was stashed behind their back either — a stash is how work becomes invisible.
	// 背后也没有 stash——stash 正是活变得看不见的方式。
	out, gerr := exec.Command("git", "-C", dir, "stash", "list").Output()
	if gerr != nil {
		t.Fatalf("stash list: %v", gerr)
	}
	if len(out) != 0 {
		t.Fatalf("a refused switch must not stash anything, got %q", out)
	}
}

// TestCreateBranch_DirtyIsAllowedBecauseNothingCanCollide: the other half of the asymmetry. A new branch starts
// at the commit already checked out, so the work tree does not change by a byte and no conflict can exist —
// gating the single most common branching flow ("I started, then realized this deserves its own branch") would
// be a guardrail against nothing.
//
// TestCreateBranch_DirtyIsAllowedBecauseNothingCanCollide:那处不对称的另一半。新分支起点就是已 checkout 的那个
// commit，故工作树一个字节都不变、冲突不可能存在——给最常见的那条开分支流程（「先动手，然后意识到这该有自己的
// 分支」）上门，等于守一道什么都不守的护栏。
func TestCreateBranch_DirtyIsAllowedBecauseNothingCanCollide(t *testing.T) {
	dir := gitRepoFixture(t)
	svc, _, id, ctx := mountedThread(t, dir)
	dirty(t, dir)

	info, err := svc.CreateBranch(ctx, id, "feat/wd2")
	if err != nil {
		t.Fatalf("creating a branch with a dirty tree must SUCCEED: %v", err)
	}
	if info.Branch != "feat/wd2" || !info.Dirty {
		t.Fatalf("the new branch carries the uncommitted work with it: %+v", info)
	}
	// The file is still there and still uncommitted — it simply belongs to the new branch now.
	// 文件还在、也仍未提交——它只是现在属于新分支了。
	if _, err := os.Stat(filepath.Join(dir, "scratch.txt")); err != nil {
		t.Fatalf("the uncommitted work must survive the create: %v", err)
	}
	if !slices.Contains(info.Branches, "feat/wd2") {
		t.Fatalf("the new branch must appear in the projection's list: %v", info.Branches)
	}
}

// TestBranchActions_EveryRefusalHasItsOwnReason: each pre-check exists so the user gets a sentence with a next
// step rather than git's prose. A single generic failure would be four different problems wearing one label.
//
// TestBranchActions_EveryRefusalHasItsOwnReason:每条预检的存在都是为了让用户拿到一句带下一步的话、而不是 git 的
// 散文。一个笼统的失败等于四个不同的问题戴着同一个标签。
func TestBranchActions_EveryRefusalHasItsOwnReason(t *testing.T) {
	dir := gitRepoFixture(t)
	svc, _, id, ctx := mountedThread(t, dir)

	if _, err := svc.SwitchBranch(ctx, id, "never-existed"); !errors.Is(err, conversationdomain.ErrBranchNotFound) {
		t.Errorf("unknown branch → ErrBranchNotFound, got %v", err)
	}
	if _, err := svc.CreateBranch(ctx, id, "main"); !errors.Is(err, conversationdomain.ErrBranchExists) {
		t.Errorf("existing branch → ErrBranchExists (a create and a switch are different intents), got %v", err)
	}
	// Names a menu could hand over that must never reach a command: a flag, a shell separator, a revision
	// range. Argument arrays already make injection impossible; this makes the REFUSAL explicit.
	// 菜单可能交过来、但绝不得抵达一条命令的名字:一个选项、一个 shell 分隔符、一个 revision range。参数数组已让
	// 注入不可能;这一条让那次**拒绝**显式。
	for _, bad := range []string{"", "  ", "-D", "--upload-pack=evil", "a b", "a..b", "x;rm -rf /", "tilde~1"} {
		if _, err := svc.SwitchBranch(ctx, id, bad); !errors.Is(err, conversationdomain.ErrInvalidBranch) {
			t.Errorf("SwitchBranch(%q) → ErrInvalidBranch, got %v", bad, err)
		}
		if _, err := svc.CreateBranch(ctx, id, bad); !errors.Is(err, conversationdomain.ErrInvalidBranch) {
			t.Errorf("CreateBranch(%q) → ErrInvalidBranch, got %v", bad, err)
		}
	}
}

// TestGitActions_NotARepoIsOneAnswerForEveryFlavour: unmounted / gone / plain directory all answer
// ErrWorkDirNotGitRepo, because the user's next step is identical in each case (mount a directory that is a
// repository) and four messages saying one thing is four chances to say it differently. The WRITE side must
// still SPEAK — the read side's silence would here mean a change the user asked for did not happen.
//
// TestGitActions_NotARepoIsOneAnswerForEveryFlavour:未挂 / 已消失 / 普通目录一律答 ErrWorkDirNotGitRepo，因为
// 用户的下一步在每种情形下都一样（挂一个是仓库的目录），而四句话说同一件事就是四次把它说得不一样的机会。但**写**
// 侧仍必须**说话**——读侧那种沉默在此意味着用户要求的改动没有发生。
func TestGitActions_NotARepoIsOneAnswerForEveryFlavour(t *testing.T) {
	plain := t.TempDir()
	for _, tc := range []struct{ name, dir string }{
		{"unmounted", ""},
		{"a plain directory", plain},
		{"a directory that is gone", filepath.Join(plain, "vanished")},
	} {
		svc, _, id, ctx := mountedThread(t, tc.dir)
		if _, err := svc.SwitchBranch(ctx, id, "main"); !errors.Is(err, conversationdomain.ErrWorkDirNotGitRepo) {
			t.Errorf("%s: SwitchBranch → ErrWorkDirNotGitRepo, got %v", tc.name, err)
		}
		if _, err := svc.CreateBranch(ctx, id, "x"); !errors.Is(err, conversationdomain.ErrWorkDirNotGitRepo) {
			t.Errorf("%s: CreateBranch → ErrWorkDirNotGitRepo, got %v", tc.name, err)
		}
		if _, err := svc.AddWorktree(ctx, id, "x"); !errors.Is(err, conversationdomain.ErrWorkDirNotGitRepo) {
			t.Errorf("%s: AddWorktree → ErrWorkDirNotGitRepo, got %v", tc.name, err)
		}
	}
}

// TestGitActions_NoGitBinaryUsesTheSameAnswer verifies the fourth environment shape without changing the
// process-wide implementation: an empty PATH makes the real exec lookup unable to find git, and all three
// writes must still fail closed with the same domain code as an unmounted or non-repository directory.
// TestGitActions_NoGitBinaryUsesTheSameAnswer 验证第四种环境形态:空 PATH 让真实 exec 查找不到 git，三个写动作仍须
// 与未挂载/非仓库目录一样，以同一个领域错误 fail-closed。
func TestGitActions_NoGitBinaryUsesTheSameAnswer(t *testing.T) {
	dir := gitRepoFixture(t)
	t.Setenv("PATH", t.TempDir())
	svc, _, id, ctx := mountedThread(t, dir)

	if _, err := svc.SwitchBranch(ctx, id, "main"); !errors.Is(err, conversationdomain.ErrWorkDirNotGitRepo) {
		t.Errorf("no git binary: SwitchBranch → ErrWorkDirNotGitRepo, got %v", err)
	}
	if _, err := svc.CreateBranch(ctx, id, "edge264-no-git"); !errors.Is(err, conversationdomain.ErrWorkDirNotGitRepo) {
		t.Errorf("no git binary: CreateBranch → ErrWorkDirNotGitRepo, got %v", err)
	}
	if _, err := svc.AddWorktree(ctx, id, "edge264-no-git"); !errors.Is(err, conversationdomain.ErrWorkDirNotGitRepo) {
		t.Errorf("no git binary: AddWorktree → ErrWorkDirNotGitRepo, got %v", err)
	}
}

// TestAddWorktree_TheOneShot: WD3's whole contract in one assertion chain — the sibling directory exists on
// disk, the `wt/<name>` branch exists, the RESIDENCY has moved into it, the thread carries the durable in-line
// mark, and the returned projection already describes the NEW directory (so the client's next paint is right).
//
// The path and branch are checked against `make worktree`'s literal convention (`../<repo>-<name>` on
// `wt/<name>`), because an app-made worktree and a discipline-made one must be the same object — otherwise the
// user has two conventions to remember and one of them is a trap.
//
// TestAddWorktree_TheOneShot:WD3 的全部契约在一条断言链里——兄弟目录真的在盘上、`wt/<name>` 分支存在、**驻地**已
// 移进去、线程带上了那条持久行内标记、返回的投影已经在描述**新**目录（故客户端下一帧就是对的）。
//
// 路径与分支是对着 `make worktree` 的**字面**约定核的（`../<repo>-<name>` 上的 `wt/<name>`），因为 app 建的
// worktree 与纪律建的必须是**同一种**对象——否则用户要记两套约定，而其中一套是陷阱。
func TestAddWorktree_TheOneShot(t *testing.T) {
	dir := gitRepoFixture(t)
	svc, marker, id, ctx := mountedThread(t, dir)

	info, err := svc.AddWorktree(ctx, id, "wd3")
	if err != nil {
		t.Fatalf("AddWorktree: %v", err)
	}
	top, ok := gitinfoinfra.Toplevel(ctx, dir)
	if !ok {
		t.Fatal("Toplevel must resolve")
	}
	want := filepath.Join(filepath.Dir(top), filepath.Base(top)+"-wd3")
	if info.Path != want {
		t.Fatalf("residency = %q, want the `make worktree` sibling %q", info.Path, want)
	}
	if st, err := os.Stat(want); err != nil || !st.IsDir() {
		t.Fatalf("the worktree directory must exist on disk: %v", err)
	}
	if info.Branch != gitinfoinfra.WorktreeBranchPrefix+"wd3" {
		t.Fatalf("branch = %q, want %s", info.Branch, gitinfoinfra.WorktreeBranchPrefix+"wd3")
	}
	// The thread's stored ROW followed, not just the projection — the residency IS the row.
	// 线程存下来的**行**也跟过去了、不只是投影——驻地**就是**那一行。
	row, err := svc.Get(ctx, id)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if row.WorkDir != want {
		t.Fatalf("the row's work_dir = %q, want %q", row.WorkDir, want)
	}
	// The durable in-line mark, reusing WD1's `marker` block (no new block type, D1 append-only).
	// 那条持久行内标记，复用 WD1 的 `marker` 块（不加块型，D1 只追加）。
	if len(marker.calls) != 1 || marker.calls[0] != [2]string{dir, want} {
		t.Fatalf("the residency move must leave ONE mark %v, got %v", [2]string{dir, want}, marker.calls)
	}
	// The projection describes the NEW tree and knows which of the two it is standing in.
	// 投影描述的是**新**树，并知道自己站在两者中的哪一份。
	if len(info.Worktrees) != 2 {
		t.Fatalf("both checkouts must be listed: %+v", info.Worktrees)
	}
	var currents int
	for _, wt := range info.Worktrees {
		if wt.Current {
			currents++
			if wt.Path != want {
				t.Fatalf("current worktree = %q, want %q", wt.Path, want)
			}
		}
	}
	if currents != 1 {
		t.Fatalf("exactly ONE worktree may be current, got %d in %+v", currents, info.Worktrees)
	}
}

// TestAddWorktree_UpdateFailureLeavesAnHonestHalfState injects failure at the final persistence step.
// The filesystem action is already complete at that point, so the contract is to leave the worktree
// usable and keep the conversation on its old residency rather than pretending the move happened.
//
// TestAddWorktree_UpdateFailureLeavesAnHonestHalfState 在最后一次持久化动作注入失败。此时文件系统动作已经完成，
// 契约是留下可用 worktree、让对话保持旧驻地，而不是假装切换已经发生。
func TestAddWorktree_UpdateFailureLeavesAnHonestHalfState(t *testing.T) {
	dir := gitRepoFixture(t)
	_, em, _, sqlDB, ctx := newSvcDB(t)
	repo := conversationstore.New(ormpkg.Open(sqlDB))
	svc := NewService(repo, em, zap.NewNop())
	c, err := svc.Create(ctx, "honest half state")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir}); err != nil {
		t.Fatalf("mount: %v", err)
	}

	// Rebuild the façade over the same store with only the final workdir update failing. This leaves all
	// preceding git operations real while making the half-state boundary deterministic.
	failing := NewService(&failWorkDirUpdateRepo{Repository: repo}, em, zap.NewNop())
	info, err := failing.AddWorktree(ctx, c.ID, "half")
	if err == nil {
		t.Fatal("the final residency update must fail in this fixture")
	}
	top, ok := gitinfoinfra.Toplevel(ctx, dir)
	if !ok {
		t.Fatal("Toplevel must resolve")
	}
	target := filepath.Join(filepath.Dir(top), filepath.Base(top)+"-half")
	t.Cleanup(func() { _ = os.RemoveAll(target) })
	if _, statErr := os.Stat(target); statErr != nil {
		t.Fatalf("the already-created worktree must remain usable: %v", statErr)
	}
	if info != nil {
		t.Fatalf("a failed final update must not return a success projection: %+v", info)
	}
	row, getErr := failing.Get(ctx, c.ID)
	if getErr != nil {
		t.Fatalf("get after failed update: %v", getErr)
	}
	if row.WorkDir != dir {
		t.Fatalf("the conversation must remain on its old residency, got %q want %q", row.WorkDir, dir)
	}
}

// TestAddWorktree_RigFailureHookOnlyTouchesTheFinalResidencyUpdate keeps the real-process seam narrow:
// the acceptance hook must leave the already-created worktree behind, while an ordinary direct mount
// remains writable in the same process.
//
// TestAddWorktree_RigFailureHookOnlyTouchesTheFinalResidencyUpdate 锁住真实进程台架 seam 的范围：已经建好的
// worktree 必须留下，而同进程里的普通直接挂载仍可写入。
func TestAddWorktree_RigFailureHookOnlyTouchesTheFinalResidencyUpdate(t *testing.T) {
	t.Setenv(rigFailWorkDirUpdateEnv, "1")
	dir := gitRepoFixture(t)
	_, em, _, sqlDB, ctx := newSvcDB(t)
	repo := conversationstore.New(ormpkg.Open(sqlDB))
	svc := NewService(repo, em, zap.NewNop())
	c, err := svc.Create(ctx, "rig hook")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := svc.Update(ctx, c.ID, UpdateInput{WorkDir: &dir}); err != nil {
		t.Fatalf("ordinary mount must not be injected: %v", err)
	}

	_, err = svc.AddWorktree(ctx, c.ID, "rig")
	if err == nil || !strings.Contains(err.Error(), "acceptance rig injected workdir persistence failure") {
		t.Fatalf("AddWorktree must fail only at its final residency update, got %v", err)
	}
	top, ok := gitinfoinfra.Toplevel(ctx, dir)
	if !ok {
		t.Fatal("Toplevel must resolve")
	}
	target := filepath.Join(filepath.Dir(top), filepath.Base(top)+"-rig")
	t.Cleanup(func() { _ = os.RemoveAll(target) })
	if _, statErr := os.Stat(target); statErr != nil {
		t.Fatalf("the real worktree operation must already be complete: %v", statErr)
	}
	row, getErr := svc.Get(ctx, c.ID)
	if getErr != nil {
		t.Fatalf("get after injected failure: %v", getErr)
	}
	if row.WorkDir != dir {
		t.Fatalf("the conversation must remain on its old residency, got %q want %q", row.WorkDir, dir)
	}
}

type failWorkDirUpdateRepo struct {
	conversationdomain.Repository
}

func (r *failWorkDirUpdateRepo) Update(ctx context.Context, c *conversationdomain.Conversation) error {
	if c.WorkDir != "" {
		return errors.New("injected residency update failure")
	}
	return r.Repository.Update(ctx, c)
}

// TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused: the two collisions, each with the answer
// the discipline already implies.
//
// A DIRECTORY that is there holds somebody's work — possibly another session's — and adopting it silently is
// how two agents come to edit one tree, the very accident the worktree discipline exists to prevent. A BRANCH
// that is there is REUSED, exactly as `make worktree` reuses it: `make worktree-rm` deliberately keeps the
// branch, so re-opening a worktree on it is the documented way back.
//
// TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused:两种撞车，各自的答案都是纪律本就暗含的。
//
// 已在那里的**目录**装着某人的活——可能是另一个会话的——而静默接管它正是两个 agent 编辑同一棵树的方式，也正是
// worktree 纪律所要防的那场事故。已在那里的**分支**被**复用**，与 `make worktree` 的复用完全一致:`make
// worktree-rm` **刻意**保留分支，故在它之上重开一份 worktree 正是被写进文档的回头路。
func TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused(t *testing.T) {
	dir := gitRepoFixture(t)
	svc, _, id, ctx := mountedThread(t, dir)
	top, _ := gitinfoinfra.Toplevel(ctx, dir)

	// ── the branch already exists, no worktree on it: REUSE (the way back after `worktree-rm`) ──
	runGit(t, dir, "branch", gitinfoinfra.WorktreeBranchPrefix+"kept")
	info, err := svc.AddWorktree(ctx, id, "kept")
	if err != nil {
		t.Fatalf("an existing wt/ branch must be REUSED, not refused: %v", err)
	}
	if info.Branch != gitinfoinfra.WorktreeBranchPrefix+"kept" {
		t.Fatalf("the reused branch must be checked out, got %q", info.Branch)
	}

	// ── the directory already exists: REFUSE, and name it so the message can offer the next step ──
	// The residency is now INSIDE `Anselm-kept`, and the target below is still `Anselm-taken` — that is the
	// flat-sibling rule holding: derivation measures from the MAIN tree, so a worktree opened from a worktree
	// never nests into `Anselm-kept-taken`.
	// 驻地现在**在** `Anselm-kept` 里，而下面那个目标仍是 `Anselm-taken`——那就是平兄弟规则在起作用:派生从**主**树
	// 量起，故从一份 worktree 里开出的 worktree 绝不会嵌套成 `Anselm-kept-taken`。
	taken := filepath.Join(filepath.Dir(top), filepath.Base(top)+"-taken")
	if err := os.MkdirAll(taken, 0o755); err != nil {
		t.Fatal(err)
	}
	_, err = svc.AddWorktree(ctx, id, "taken")
	if !errors.Is(err, conversationdomain.ErrWorktreeExists) {
		t.Fatalf("an existing directory → ErrWorktreeExists (proving the target stayed flat at %q), got %v", taken, err)
	}
	// The path rides in Details so the UI can say WHICH directory is in the way — «that name is taken» without
	// the path leaves the user hunting. 路径走 Details，使 UI 能说出**哪个**目录挡着——一句不带路径的「这个名字被
	// 占了」会让用户去猜。
	var domErr *errorspkg.Error
	if !errors.As(err, &domErr) || domErr.Details["path"] != taken {
		t.Fatalf("the refusal must name the directory in Details, got %+v", err)
	}
}

// TestAddWorktree_NameIsAPathSegmentNotAPath: the SECURITY property. The endpoint takes a NAME and derives the
// target, so it can only ever write next to the repository. Every input below is a way of asking for somewhere
// else, and every one must be refused BEFORE git is invoked.
//
// TestAddWorktree_NameIsAPathSegmentNotAPath:那条**安全**性质。端点收**名字**、自己派生目标，故它只可能写在仓库
// 旁边。以下每一个输入都是「要求写到别处」的一种说法，而每一个都必须在 git 被调用**之前**被拒。
func TestAddWorktree_NameIsAPathSegmentNotAPath(t *testing.T) {
	dir := gitRepoFixture(t)
	svc, marker, id, ctx := mountedThread(t, dir)

	for _, bad := range []string{
		"", "   ", ".", "..", "../escape", "/absolute", "nested/deep", "back\\slash",
		"-b", "--git-dir=/tmp", "a b", "dot.lock", "at@{1}",
	} {
		if _, err := svc.AddWorktree(ctx, id, bad); !errors.Is(err, conversationdomain.ErrInvalidWorktreeName) {
			t.Errorf("AddWorktree(%q) → ErrInvalidWorktreeName, got %v", bad, err)
		}
	}
	// A refused name changed nothing at all: no residency move, hence no mark.
	// 一个被拒的名字什么都没改:驻地没动，故没有标记。
	if len(marker.calls) != 0 {
		t.Fatalf("a refused worktree must not move the residency, got marks %v", marker.calls)
	}
	if row, err := svc.Get(ctx, id); err != nil || row.WorkDir != dir {
		t.Fatalf("the residency must be untouched, got %+v (%v)", row, err)
	}
}

// TestGitFailure_CarriesGitsOwnWords: when the pre-checks have nothing to say, git's sentence is forwarded
// VERBATIM under `details.git`. It is the most useful line anybody has about why a checkout refused, and
// replacing it with a guess is how an error message becomes useless.
//
// The scenario is real and not contrived: a second worktree has `wt/x` checked out, so `worktree add` on that
// branch refuses — and git's own message NAMES the directory holding it, which is exactly the next step.
//
// TestGitFailure_CarriesGitsOwnWords:当预检无话可说时，git 那句话在 `details.git` 下被**逐字**转发。关于「一次
// checkout 为何被拒」它是所有人手上最有用的一行，而用一句猜测替换它正是一条错误消息变得没用的方式。
//
// 这个场景是真的、不是硬造的:第二份 worktree 出着 `wt/x`，故对那条分支再 `worktree add` 会被拒——而 git 自己那句
// 话**点出**了占着它的目录，那正是下一步。
func TestGitFailure_CarriesGitsOwnWords(t *testing.T) {
	dir := gitRepoFixture(t)
	svc, _, id, ctx := mountedThread(t, dir)
	if _, err := svc.AddWorktree(ctx, id, "x"); err != nil {
		t.Fatalf("first worktree: %v", err)
	}
	// Move the residency back to the main tree, then ask for the SAME name from a different directory: the
	// branch is already checked out elsewhere, which only git can know.
	// 把驻地移回主树，再从另一个目录要**同一个**名字:那条分支已在别处被 checkout，而那只有 git 知道。
	top, _ := gitinfoinfra.Toplevel(ctx, dir)
	if _, err := svc.Update(ctx, id, UpdateInput{WorkDir: &top}); err != nil {
		t.Fatalf("move back: %v", err)
	}
	if err := os.RemoveAll(filepath.Join(filepath.Dir(top), filepath.Base(top)+"-x")); err != nil {
		t.Fatal(err)
	}
	_, err := svc.AddWorktree(ctx, id, "x")
	if !errors.Is(err, conversationdomain.ErrGitFailed) {
		t.Fatalf("an unforeseen git refusal → ErrGitFailed, got %v", err)
	}
	if !strings.Contains(err.Error(), "wt/x") {
		t.Fatalf("git's own words must survive the trip, got %q", err.Error())
	}
}
