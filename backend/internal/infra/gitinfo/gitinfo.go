// Package gitinfo reads the two facts the conversation residency shows about a mounted directory:
// which branch it is on, and whether it has uncommitted changes. It shells out to the `git` binary
// rather than parsing .git/ by hand (原则 #8): git already knows about detached HEAD, worktrees whose
// .git is a FILE, submodules, packed refs and .gitignore — every one of which a hand-rolled
// .git/HEAD reader gets subtly wrong, and worktrees are explicitly on this feature's roadmap (WD3).
//
// Absence is never an error here. No git binary, not a repository, a directory that vanished — all
// answer "not a repo" and the caller renders a residency with no git segment. This is a read for a
// menu and a system-prompt line; it must never be the reason a turn or an HTTP request fails.
//
// Package gitinfo 读对话驻地要显示的两个事实:目录在哪个分支、有没有未提交改动。它调用 `git` 二进制、
// 不手搓解析 .git/(原则 #8):git 早已懂 detached HEAD、.git 是**文件**的 worktree、submodule、packed
// refs 与 .gitignore——手搓的 .git/HEAD 读法每一样都会微妙地弄错,而 worktree 正在本 feature 的路线图上
// (WD3)。
//
// 此处「不存在」从不是错误。没有 git 二进制、不是仓库、目录已消失——全都答「不是仓库」,调用方渲一个
// 没有 git 段的驻地。这是给一个菜单和一行 system prompt 用的读;它绝不该成为某个回合或某个 HTTP 请求
// 失败的原因。
package gitinfo

import (
	"context"
	"os/exec"
	"strings"
	"time"
)

// probeTimeout bounds each git invocation. `rev-parse` is O(1), but `status` walks the work tree and
// a residency may be mounted on something pathological (a huge monorepo, a stale network mount). The
// residency is decoration — an unbounded wait here would stall a chat turn's system prompt.
//
// probeTimeout 界住每次 git 调用。`rev-parse` 是 O(1),但 `status` 会走整个工作树,而驻地可能挂在
// 某个病态位置(超大 monorepo、失效的网络挂载)。驻地是装饰性的——此处无界等待会卡住一次对话回合的
// system prompt。
const probeTimeout = 2 * time.Second

// DetachedBranch is the branch name reported for a detached HEAD. `git rev-parse --abbrev-ref HEAD`
// literally prints "HEAD" then, which would render as a branch called HEAD; naming it here keeps the
// UI's "you are not on a branch" case explicit instead of a magic string in three places.
//
// DetachedBranch 是 detached HEAD 时上报的分支名。`git rev-parse --abbrev-ref HEAD` 那时会原样打印
// "HEAD",直接透出会渲成一个叫 HEAD 的分支;在此命名使 UI 的「你不在任何分支上」这一格显式,而不是三处
// 各写一个魔法字符串。
const DetachedBranch = "HEAD"

// Branch reports dir's current branch. isRepo=false means "no git here" for every reason (no binary,
// not a repository, dir gone) — the caller has no use for the distinction. It runs ONE cheap
// `rev-parse`, which is why the per-turn system prompt can afford to call it while the HTTP endpoint
// pays for [Status].
//
// Branch 报告 dir 的当前分支。isRepo=false 意为「这里没有 git」,不分原因(无二进制、非仓库、目录已
// 消失)——调用方用不到这个区别。它只跑**一次**廉价的 `rev-parse`,故逐回合的 system prompt 付得起它,
// 而 HTTP 端点去付 [Status] 的钱。
func Branch(ctx context.Context, dir string) (branch string, isRepo bool) {
	out, ok := run(ctx, dir, "rev-parse", "--abbrev-ref", "HEAD")
	if !ok {
		return "", false
	}
	return strings.TrimSpace(out), true
}

// Status reports dir's branch plus whether the work tree is dirty (any staged, unstaged or UNTRACKED
// change — the residency's dot means "there is work here that isn't committed", and a brand-new file
// is exactly that). One `status --porcelain=v2 --branch` answers both, so the endpoint spawns one
// process, not three.
//
// Status 报告 dir 的分支 + 工作树是否脏(任何已暂存、未暂存**或未跟踪**的改动——驻地那个点的意思是
// 「这里有没提交的活」,而一个全新文件正是如此)。一次 `status --porcelain=v2 --branch` 同时答两问,
// 故端点只起一个进程、不是三个。
func Status(ctx context.Context, dir string) (branch string, dirty, isRepo bool) {
	out, ok := run(ctx, dir, "status", "--porcelain=v2", "--branch")
	if !ok {
		return "", false, false
	}
	for line := range strings.Lines(out) {
		line = strings.TrimRight(line, "\r\n")
		if after, found := strings.CutPrefix(line, "# branch.head "); found {
			branch = strings.TrimSpace(after)
			continue
		}
		// Header lines all start with "# "; every other non-empty line is a changed / untracked /
		// unmerged entry. 头部行皆以 "# " 起;其余任何非空行都是一条改动/未跟踪/冲突项。
		if line != "" && !strings.HasPrefix(line, "# ") {
			dirty = true
		}
	}
	// porcelain=v2 prints "(detached)" for a detached HEAD while rev-parse prints "HEAD"; normalize so
	// both probes speak one vocabulary to the UI.
	// porcelain=v2 对 detached HEAD 打印 "(detached)"、而 rev-parse 打印 "HEAD";在此归一,使两个探针
	// 对 UI 说同一套词汇。
	if branch == "(detached)" {
		branch = DetachedBranch
	}
	return branch, dirty, true
}

// run executes git in dir and reports ok=false for every flavour of absence. Only stdout is returned;
// git's stderr is diagnostic noise for a probe whose whole answer is "repo / not a repo".
//
// run 在 dir 里执行 git,对一切「不存在」的形态返 ok=false。只返 stdout;对一个全部答案只是「是仓库/
// 不是仓库」的探针,git 的 stderr 是诊断噪音。
func run(ctx context.Context, dir string, args ...string) (string, bool) {
	if dir == "" {
		return "", false
	}
	ctx, cancel := context.WithTimeout(ctx, probeTimeout)
	defer cancel()
	// -C rather than cmd.Dir: exec fails outright when Dir does not exist, whereas `git -C <gone>`
	// fails as a plain non-zero exit — the same shape as "not a repository", which keeps the caller's
	// error handling to one branch.
	// 用 -C 而非 cmd.Dir:Dir 不存在时 exec 直接失败,而 `git -C <已消失>` 只是普通非零退出——与
	// 「不是仓库」同形,使调用方的错误处理只剩一条分支。
	cmd := exec.CommandContext(ctx, "git", append([]string{"-C", dir}, args...)...)
	out, err := cmd.Output()
	if err != nil {
		return "", false
	}
	return string(out), true
}
