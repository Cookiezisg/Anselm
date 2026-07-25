package gitinfo

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// gitRepo initializes a real repository with one commit, skipping the test when no git binary exists
// (the probe's whole contract is that its absence is not an error, so the TEST must not invent one).
//
// gitRepo 初始化一个真仓库并提交一次;无 git 二进制时 skip(探针的全部契约就是「它不存在不是错误」,
// 故**测试**不该自己造一个错误)。
func gitRepo(t *testing.T) string {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git binary — gitinfo's contract is that this is not an error")
	}
	dir := t.TempDir()
	for _, args := range [][]string{
		{"init", "--initial-branch=main"},
		{"config", "user.email", "t@example.com"},
		{"config", "user.name", "t"},
	} {
		cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("a\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "."}, {"commit", "-m", "init"}} {
		cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	return dir
}

func TestStatus_CleanThenDirty(t *testing.T) {
	dir := gitRepo(t)
	ctx := context.Background()

	branch, dirty, isRepo := Status(ctx, dir)
	if !isRepo || branch != "main" || dirty {
		t.Fatalf("fresh commit: got branch=%q dirty=%v isRepo=%v, want main/false/true", branch, dirty, isRepo)
	}
	if b, ok := Branch(ctx, dir); !ok || b != "main" {
		t.Fatalf("Branch = %q,%v want main,true", b, ok)
	}

	// An UNTRACKED file counts as dirty: the residency dot means "there is work here that isn't
	// committed", and a brand-new file is exactly that.
	// **未跟踪**文件算脏:驻地那个点的意思是「这里有没提交的活」,全新文件正是如此。
	if err := os.WriteFile(filepath.Join(dir, "new.txt"), []byte("n\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, dirty, _ := Status(ctx, dir); !dirty {
		t.Error("an untracked file must read dirty")
	}
	if err := os.Remove(filepath.Join(dir, "new.txt")); err != nil {
		t.Fatal(err)
	}
	// A MODIFIED tracked file too. 已跟踪文件被改亦然。
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("changed\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, dirty, _ := Status(ctx, dir); !dirty {
		t.Error("a modified tracked file must read dirty")
	}
}

// TestStatus_NotARepoAndMissingDir: every flavour of absence answers isRepo=false rather than an
// error — the endpoint and the system prompt both depend on that.
//
// TestStatus_NotARepoAndMissingDir:每种「不存在」都答 isRepo=false 而非报错——端点与 system prompt
// 都靠这一点。
func TestStatus_NotARepoAndMissingDir(t *testing.T) {
	ctx := context.Background()
	plain := t.TempDir()
	for _, dir := range []string{plain, filepath.Join(plain, "gone"), ""} {
		if _, _, isRepo := Status(ctx, dir); isRepo {
			t.Errorf("Status(%q) reported a repo", dir)
		}
		if _, ok := Branch(ctx, dir); ok {
			t.Errorf("Branch(%q) reported a repo", dir)
		}
	}
}

// TestStatus_DetachedHeadNormalized: porcelain=v2 says "(detached)" and rev-parse says "HEAD"; both
// probes must hand the UI the SAME word or the menu shows two different things for one state.
//
// TestStatus_DetachedHeadNormalized:porcelain=v2 说 "(detached)"、rev-parse 说 "HEAD";两个探针必须
// 给 UI **同一个**词,否则同一种状态在菜单里会显示成两样。
func TestStatus_DetachedHeadNormalized(t *testing.T) {
	dir := gitRepo(t)
	ctx := context.Background()
	if out, err := exec.Command("git", "-C", dir, "checkout", "--detach", "HEAD").CombinedOutput(); err != nil {
		t.Fatalf("detach: %v\n%s", err, out)
	}
	branch, _, isRepo := Status(ctx, dir)
	if !isRepo || branch != DetachedBranch {
		t.Fatalf("detached Status branch = %q (isRepo=%v), want %q", branch, isRepo, DetachedBranch)
	}
	b, ok := Branch(ctx, dir)
	if !ok || b != DetachedBranch {
		t.Fatalf("detached Branch = %q,%v want %q,true", b, ok, DetachedBranch)
	}
}

// git runs one git command in dir and fails the test on refusal — the fixture's own hands, kept separate
// from the package under test so a bug in gitinfo cannot also build the world it is measured in.
//
// git 在 dir 里跑一条 git 命令,失败即 fail——夹具自己的手,与被测包分开,使 gitinfo 的 bug 不会连它被测量的
// 那个世界一起造出来。
func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	out, err := exec.Command("git", append([]string{"-C", dir}, args...)...).CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return string(out)
}

// gitAt commits with an explicit COMMITTER date, which is the field `--sort=-committerdate` reads (git's
// `--date` moves the AUTHOR date and would leave the ordering untouched).
//
// gitAt 用**显式** committer 日期提交,那正是 `--sort=-committerdate` 读的字段(git 的 `--date` 改的是 author
// 日期、对排序毫无影响)。
func gitAt(t *testing.T, dir, when string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_COMMITTER_DATE="+when, "GIT_AUTHOR_DATE="+when)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v at %s: %v\n%s", args, when, err, out)
	}
}

// TestBranches_LocalOnlyMostRecentFirst: the switcher's list. Local heads ONLY (that exclusion is what keeps
// the projection bounded and cursor-free) and recency order, because the question the menu asks is "where was
// I working" — alphabetical would bury today's branch behind `chore/…`.
//
// TestBranches_LocalOnlyMostRecentFirst:切换器那份列表。**只**取本地 heads(正是这个排除让投影保持有界、无游标),
// 且按**最近**排,因为菜单问的是「我刚在哪干活」——按字母排会把今天那条埋在 `chore/…` 后面。
func TestBranches_LocalOnlyMostRecentFirst(t *testing.T) {
	dir := gitRepo(t)
	ctx := context.Background()
	if got := Branches(ctx, dir); len(got) != 1 || got[0] != "main" {
		t.Fatalf("a fresh repo has exactly its initial branch, got %v", got)
	}
	// ALL THREE tips get an explicit committer date, main's by amend. Two reasons and both bite: git's
	// timestamps are second-granular, so commits made within one test tick tie and fall back to refname
	// order; and the fixture's initial commit is stamped with the WALL CLOCK, so any date literal picked
	// here would be "older than main" or "newer than main" depending on what year the machine thinks it is.
	// Pinning every tip makes the assertion about the sort, not about the calendar.
	// **三条**分支的 tip 都拿到显式 committer 日期,main 的经 amend。两个理由都会咬人:git 的时间戳是**秒**级的,
	// 故一个测试 tick 内的提交会打平、回落到 refname 序;而夹具那次初始提交盖的是**墙钟**,故此处随便挑的任何日期
	// 字面量都会因机器认为今年是哪一年而变成「比 main 老」或「比 main 新」。把每个 tip 都钉住,使断言关于**排序**、
	// 而不是关于日历。
	gitAt(t, dir, "2026-01-01 12:00:00 +0000", "commit", "--amend", "--no-edit")
	for i, name := range []string{"older", "newer"} {
		git(t, dir, "checkout", "-b", name)
		if err := os.WriteFile(filepath.Join(dir, name+".txt"), []byte("x\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		git(t, dir, "add", ".")
		gitAt(t, dir, fmt.Sprintf("2026-0%d-01 12:00:00 +0000", i+2), "commit", "-m", name)
	}
	got := Branches(ctx, dir)
	if len(got) != 3 || got[0] != "newer" || got[1] != "older" {
		t.Fatalf("Branches = %v, want newest-committed first (newer, older, main)", got)
	}
	// A remote-tracking ref must NOT show up: refs/remotes is the set that runs to thousands, and including
	// it would turn a bounded projection into one that needs a cursor.
	// 远端跟踪 ref **不得**出现:refs/remotes 才是会跑到上千条的那一集,含它会把一个有界投影变成需要游标的。
	git(t, dir, "update-ref", "refs/remotes/origin/ghost", "HEAD")
	for _, name := range Branches(ctx, dir) {
		if strings.Contains(name, "ghost") {
			t.Fatalf("a remote-tracking ref leaked into Branches: %v", Branches(ctx, dir))
		}
	}
}

// TestWorktrees_MainTreeIncludedAndParsed: `worktrees[]` includes the MAIN tree, because the honest answer to
// "which worktrees does this repo have" contains the one you are standing in. Parsed from --porcelain, and a
// detached checkout reports an empty branch rather than the word HEAD.
//
// TestWorktrees_MainTreeIncludedAndParsed:`worktrees[]` **含主树**,因为「这个仓库有哪些 worktree」的诚实答案
// 包含你正站着的那一份。从 --porcelain 解析,而 detached 的 checkout 报**空**分支、不报 HEAD 这个词。
func TestWorktrees_MainTreeIncludedAndParsed(t *testing.T) {
	dir := gitRepo(t)
	ctx := context.Background()
	top, ok := Toplevel(ctx, dir)
	if !ok {
		t.Fatal("Toplevel must resolve for a real repo")
	}

	list := Worktrees(ctx, dir)
	if len(list) != 1 || list[0].Path != top || list[0].Branch != "main" {
		t.Fatalf("the main tree alone: %+v (top=%q)", list, top)
	}

	sibling := WorktreeTarget(top, "wd3")
	if err := AddWorktree(ctx, dir, sibling, WorktreeBranchPrefix+"wd3", true); err != nil {
		t.Fatalf("AddWorktree: %v", err)
	}
	list = Worktrees(ctx, dir)
	if len(list) != 2 {
		t.Fatalf("both checkouts must be listed, got %+v", list)
	}
	var found bool
	for _, wt := range list {
		if wt.Path == sibling {
			found = true
			if wt.Branch != "wt/wd3" {
				t.Fatalf("the added worktree's branch = %q, want wt/wd3", wt.Branch)
			}
		}
	}
	if !found {
		t.Fatalf("the added worktree %q is missing from %+v", sibling, list)
	}

	// The sibling convention, literally: ../<root's own name>-<name>, i.e. `make worktree`'s ../Anselm-<x>.
	// 兄弟约定,逐字:../<根自己的名字>-<name>,即 `make worktree` 的 ../Anselm-<x>。
	if filepath.Dir(sibling) != filepath.Dir(top) {
		t.Fatalf("a worktree must be a SIBLING of the repo: %q vs %q", sibling, top)
	}
	if filepath.Base(sibling) != filepath.Base(top)+"-wd3" {
		t.Fatalf("worktree dir = %q, want %q", filepath.Base(sibling), filepath.Base(top)+"-wd3")
	}

	// Detached reports no branch — the same "not on a branch" state DetachedBranch names for the residency,
	// spelled as absence here because a worktree list is a list of facts, not of labels.
	// detached 报**没有**分支——与 DetachedBranch 为驻地命名的那个「不在任何分支上」是同一状态,此处写成缺席,
	// 因为一份 worktree 列表是事实的列表、不是标签的列表。
	git(t, sibling, "checkout", "--detach", "HEAD")
	for _, wt := range Worktrees(ctx, dir) {
		if wt.Path == sibling && wt.Branch != "" {
			t.Fatalf("a detached worktree must report no branch, got %q", wt.Branch)
		}
	}
}

// TestCheckRefFormat_GitDecidesPlusTheDashRule: git's own tool is the rule (原则 #8), and the two pure-Go
// pre-checks cover what it has no opinion about — a ref beginning with `-` is LEGAL to git and would be read
// as a FLAG by the next command; a bare `@` is git's own shorthand for HEAD.
//
// TestCheckRefFormat_GitDecidesPlusTheDashRule:git 自己的工具就是规则(原则 #8),而那两条纯 Go 前置检查覆盖它
// 不表态的部分——以 `-` 开头的 ref 对 git 是**合法**的、却会被下一条命令读成**选项**;裸 `@` 是 git 自己表示 HEAD
// 的简写。
func TestCheckRefFormat_GitDecidesPlusTheDashRule(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git binary")
	}
	ctx := context.Background()
	for _, name := range []string{"main", "feat/x", "wt/wd2", "release-1.2"} {
		if !CheckRefFormat(ctx, name) {
			t.Errorf("CheckRefFormat(%q) = false, want true", name)
		}
	}
	// Every one of these is a name a menu could hand over, and every one of them must not reach a command.
	// 以下每一个都是菜单可能交过来的名字,而每一个都不得抵达一条命令。
	for _, name := range []string{
		"", " ", "-force", "--upload-pack=evil", "@",
		"a..b", "has space", "trail/", "/lead", "dot.lock", "tilde~1", "caret^", "colon:x", "q?", "star*",
		"brack[", "back\\slash", "at@{x}", "double//slash",
	} {
		if CheckRefFormat(ctx, name) {
			t.Errorf("CheckRefFormat(%q) = true, want false", name)
		}
	}
}

// TestValidWorktreeName_OnePathSegment: a worktree name becomes a DIRECTORY as well as a branch, so it is held
// to the stricter rule. `feat/x` is a fine branch and a nested path; `..` is the input the sibling derivation
// must never accept.
//
// TestValidWorktreeName_OnePathSegment:worktree 名**也会**成为一个目录、不只是一条分支,故受更严的规则。
// `feat/x` 是好分支、却是**嵌套**路径;`..` 正是那次兄弟派生绝不能收下的输入。
func TestValidWorktreeName_OnePathSegment(t *testing.T) {
	for _, name := range []string{"wd3", "fix-42", "sun.2"} {
		if !ValidWorktreeName(name) {
			t.Errorf("ValidWorktreeName(%q) = false, want true", name)
		}
	}
	for _, name := range []string{"", ".", "..", "feat/x", "a\\b", "/abs", "-dash", "nested/deep/x"} {
		if ValidWorktreeName(name) {
			t.Errorf("ValidWorktreeName(%q) = true, want false", name)
		}
	}
}

// TestWrites_HappyPathAndGitsOwnWords: the write contract is the OPPOSITE of the reads' — every failure is
// reported, carrying git's verbatim stderr, because a version-control action that silently did nothing is the
// one outcome that must never happen.
//
// TestWrites_HappyPathAndGitsOwnWords:写的契约与读**相反**——每次失败都上报、并带 git 的**逐字** stderr,因为
// 一个静默什么都没做的版本控制动作,是绝不能发生的那个结局。
func TestWrites_HappyPathAndGitsOwnWords(t *testing.T) {
	dir := gitRepo(t)
	ctx := context.Background()

	if err := CreateBranch(ctx, dir, "wd2"); err != nil {
		t.Fatalf("CreateBranch: %v", err)
	}
	if b, _ := Branch(ctx, dir); b != "wd2" {
		t.Fatalf("after CreateBranch the head is %q, want wd2", b)
	}
	if !BranchExists(ctx, dir, "wd2") || BranchExists(ctx, dir, "never") {
		t.Fatal("BranchExists must answer for the branch that is there and the one that is not")
	}
	if err := Checkout(ctx, dir, "main"); err != nil {
		t.Fatalf("Checkout: %v", err)
	}
	if b, _ := Branch(ctx, dir); b != "main" {
		t.Fatalf("after Checkout the head is %q, want main", b)
	}

	// A refusal carries git's OWN sentence: it is the most useful line anybody has about why, so it must
	// survive the trip. 一次拒绝带着 git **自己**那句话:关于「为什么」它是所有人手上最有用的一行,故必须活着
	// 走完这趟路。
	err := CreateBranch(ctx, dir, "main")
	var cmdErr *CommandError
	if !errors.As(err, &cmdErr) {
		t.Fatalf("a refused write must be a *CommandError, got %T (%v)", err, err)
	}
	if cmdErr.Stderr == "" {
		t.Fatal("a refused write must carry git's stderr — a swallowed reason is a lie by omission")
	}
	if !strings.Contains(cmdErr.Error(), cmdErr.Stderr) {
		t.Fatalf("Error() must surface the stderr, got %q", cmdErr.Error())
	}
}

// TestReadsAndWrites_AbsenceSplitsTheContract: the package's defining asymmetry, asserted on ONE plain
// directory — the reads answer "nothing here" and the writes REFUSE. A read that errored would break a chat
// turn's system prompt; a write that stayed quiet would lose a user's requested change.
//
// TestReadsAndWrites_AbsenceSplitsTheContract:本包的那处定义性不对称,在**同一个**普通目录上断言——读答「这里
// 什么都没有」,写**拒绝**。一个会报错的读会弄坏一次对话回合的 system prompt;一个闭口不谈的写会丢掉用户要求的
// 那次改动。
func TestReadsAndWrites_AbsenceSplitsTheContract(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("no git binary")
	}
	plain := t.TempDir()
	ctx := context.Background()

	if got := Branches(ctx, plain); got != nil {
		t.Errorf("Branches on a non-repo = %v, want nil", got)
	}
	if got := Worktrees(ctx, plain); got != nil {
		t.Errorf("Worktrees on a non-repo = %v, want nil", got)
	}
	if _, ok := Toplevel(ctx, plain); ok {
		t.Error("Toplevel on a non-repo must report not-ok")
	}
	if BranchExists(ctx, plain, "main") {
		t.Error("BranchExists on a non-repo must be false")
	}
	if err := Checkout(ctx, plain, "main"); err == nil {
		t.Error("Checkout on a non-repo must FAIL — a silent no-op loses the user's change")
	}
	if err := CreateBranch(ctx, plain, "x"); err == nil {
		t.Error("CreateBranch on a non-repo must FAIL")
	}
	if err := AddWorktree(ctx, plain, filepath.Join(plain, "wt"), "wt/x", true); err == nil {
		t.Error("AddWorktree on a non-repo must FAIL")
	}
}
