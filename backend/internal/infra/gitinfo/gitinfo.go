// Package gitinfo is the conversation residency's whole git surface: the facts it SHOWS about a
// mounted directory (branch, uncommitted work, local branches, worktrees) and the three changes it
// can MAKE there (switch branch, create branch, add a worktree). It shells out to the `git` binary
// rather than parsing .git/ by hand (原则 #8): git already knows about detached HEAD, worktrees whose
// .git is a FILE, submodules, packed refs and .gitignore — every one of which a hand-rolled
// .git/HEAD reader gets subtly wrong — and for the writes there is no sane alternative at all (a
// worktree is an entry in .git/worktrees plus a gitfile plus a checkout plus a ref).
//
// Every invocation passes an ARGUMENT ARRAY through exec.CommandContext — never a shell string. A
// branch name is user input that may contain `;`, a space or a leading `--`, and the one way that can
// never become command injection is for no shell to be involved. Names are additionally validated by
// git's own `check-ref-format` ([CheckRefFormat]) before they reach a write.
//
// The reads and the writes have OPPOSITE error contracts, deliberately:
//
//   - READS: absence is never an error. No git binary, not a repository, a directory that vanished —
//     all answer "not a repo" / an empty slice, and the caller renders a residency with no git
//     segment. These feed a menu and a system-prompt line; they must never be the reason a turn or an
//     HTTP request fails.
//   - WRITES: every failure is reported and carries git's OWN words ([CommandError.Stderr]). A write
//     the user asked for that silently did nothing is the one outcome a version-control action must
//     never have.
//
// Package gitinfo 是对话驻地的**整个** git 面:它**显示**的事实(分支、未提交改动、本地分支、worktree)
// 与它能在那里**做**的三件改动(切分支、建分支、加 worktree)。它调用 `git` 二进制、不手搓解析 .git/
// (原则 #8):git 早已懂 detached HEAD、.git 是**文件**的 worktree、submodule、packed refs 与
// .gitignore——手搓的 .git/HEAD 读法每一样都会微妙地弄错——而那些**写**根本没有别的清醒选项(一个
// worktree 是 .git/worktrees 里的一条 + 一个 gitfile + 一份 checkout + 一个 ref)。
//
// 每次调用都经 exec.CommandContext 传**参数数组**、绝不拼 shell 字符串。分支名是用户输入、可能含 `;`、
// 空格或前导 `--`,而让它永不可能变成命令注入的唯一办法就是**不让 shell 参与**。名字在进入任何写之前
// 另经 git 自己的 `check-ref-format` 校验([CheckRefFormat])。
//
// 读与写的错误契约**刻意相反**:
//
//   - **读**:「不存在」从不是错误。没有 git 二进制、不是仓库、目录已消失——全都答「不是仓库」/ 空切片,
//     调用方渲一个没有 git 段的驻地。它们供一个菜单和一行 system prompt;绝不该成为某个回合或某个 HTTP
//     请求失败的原因。
//   - **写**:每一次失败都上报、并带上 git **自己的话**([CommandError.Stderr])。一个用户要求了、却静默
//     什么都没做的写,正是一个版本控制动作绝不能有的结局。
package gitinfo

import (
	"context"
	"fmt"
	"os/exec"
	"path/filepath"
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

// Branches lists the repository's LOCAL branches, most-recently-committed first (WD2). Empty for
// every flavour of absence, exactly like the other reads.
//
// Local heads only — `refs/remotes` is deliberately NOT included, and that is what makes this a
// BOUNDED projection rather than a set needing a cursor: refs/heads holds the branches this person
// created, a human-scale set, while a fetched remote can carry thousands. Recency order rather than
// alphabetical because the menu it feeds is "where was I working" — a switcher sorted by name buries
// today's branch behind `chore/…`.
//
// Branches 列出仓库的**本地**分支、最近提交在前(WD2)。对一切「不存在」形态返空,与其余读一致。
//
// **只**取本地 heads——`refs/remotes` **刻意**不含,而这正是它成为**有界**投影、无须游标的原因:refs/heads
// 装的是这个人自己建的分支(人类尺度集合),而一份 fetch 过的远端可以带来上千条。按**最近**而非字母排,因为
// 它供的那个菜单问的是「我刚在哪干活」——按名字排的切换器会把今天那条分支埋在 `chore/…` 后面。
func Branches(ctx context.Context, dir string) []string {
	out, ok := run(ctx, dir, "for-each-ref", "--format=%(refname:short)", "--sort=-committerdate", "refs/heads")
	if !ok {
		return nil
	}
	var names []string
	for line := range strings.Lines(out) {
		if name := strings.TrimSpace(line); name != "" {
			names = append(names, name)
		}
	}
	return names
}

// Worktree is one entry of `git worktree list` — where a checkout of this repository lives and which
// branch it has out. Branch is empty for a detached checkout (the same "not on a branch" state
// [DetachedBranch] names for the residency itself).
//
// Worktree 是 `git worktree list` 的一条——本仓库的某份 checkout 在哪、出着哪条分支。detached 的 checkout
// 其 Branch 为空(与 DetachedBranch 为驻地本身命名的那个「不在任何分支上」是同一种状态)。
type Worktree struct {
	Path   string
	Branch string
}

// Worktrees lists every checkout of the repository the MAIN working tree included (WD3) — git reports
// the main tree as the first entry and that is kept, because the honest answer to "which worktrees does
// this repo have" includes the one you are standing in; the caller marks it rather than this layer
// guessing which one that is.
//
// Parsed from `--porcelain` rather than the human format: the human one aligns columns and abbreviates
// SHAs, which is a format that changes. Bare repositories and prunable entries answer with whatever git
// says about them, minus the branch (they have no checkout on a branch).
//
// Worktrees 列出本仓库的每一份 checkout、**含主工作树**(WD3)——git 把主树报作第一条,此处保留它,因为
// 「这个仓库有哪些 worktree」的诚实答案包含你正站着的那一份;由调用方去标记它是哪一份,而不是本层去猜。
//
// 从 `--porcelain` 解析、不用给人看的那种格式:后者会对齐列、缩写 SHA,那是一种会变的格式。裸仓库与
// prunable 条目按 git 怎么说就怎么答,只是没有分支(它们没有出在分支上的 checkout)。
func Worktrees(ctx context.Context, dir string) []Worktree {
	out, ok := run(ctx, dir, "worktree", "list", "--porcelain")
	if !ok {
		return nil
	}
	var (
		list []Worktree
		cur  *Worktree
	)
	for line := range strings.Lines(out) {
		line = strings.TrimRight(line, "\r\n")
		switch {
		case strings.HasPrefix(line, "worktree "):
			list = append(list, Worktree{Path: strings.TrimPrefix(line, "worktree ")})
			cur = &list[len(list)-1]
		case cur != nil && strings.HasPrefix(line, "branch "):
			cur.Branch = strings.TrimPrefix(strings.TrimPrefix(line, "branch "), "refs/heads/")
		}
	}
	return list
}

// Toplevel reports the root of the working tree dir sits in — the directory `git worktree add`'s
// sibling convention is measured from (see the repo's `make worktree`). ok=false for the usual
// absences.
//
// Toplevel 报告 dir 所在工作树的根——即 `git worktree add` 的**兄弟位置**约定所据以测量的那个目录(见本仓
// 的 `make worktree`)。对常见的「不存在」返 ok=false。
func Toplevel(ctx context.Context, dir string) (string, bool) {
	out, ok := run(ctx, dir, "rev-parse", "--show-toplevel")
	if !ok {
		return "", false
	}
	top := strings.TrimSpace(out)
	return top, top != ""
}

// MainToplevel reports the root of the repository's MAIN working tree, whichever tree dir happens to be
// in. `git worktree list` documents the main worktree as its first entry, which is why no extra
// invocation is needed to find it.
//
// It exists because [Toplevel] answers a different question. Deriving a new worktree from the CURRENT
// tree would nest the convention: opening one from inside `Anselm-a` would produce `Anselm-a-b`, and from
// there `Anselm-a-b-c`. The discipline is a FLAT row of siblings next to the main repository
// (`../Anselm-<x>`, one per concurrent session), so every derivation measures from the same origin no
// matter which tree the residency currently sits in.
//
// MainToplevel 报告仓库**主**工作树的根，无论 dir 此刻在哪一棵树里。`git worktree list` 明文规定主 worktree
// 是它的第一条，故不需要额外调用去找它。
//
// 它之所以存在:Toplevel 答的是**另一个**问题。从**当前**树派生新 worktree 会让约定嵌套下去:在 `Anselm-a`
// 里开一份会得到 `Anselm-a-b`，再开一份是 `Anselm-a-b-c`。纪律是主仓库旁边**一排平的**兄弟（`../Anselm-<x>`，
// 一个并发会话一个），故每次派生都从同一个原点量起、不管驻地此刻坐在哪棵树上。
func MainToplevel(ctx context.Context, dir string) (string, bool) {
	list := Worktrees(ctx, dir)
	if len(list) == 0 || list[0].Path == "" {
		return "", false
	}
	return list[0].Path, true
}

// BranchExists reports whether refs/heads/<name> resolves. It is asked BEFORE a switch and before a
// create so each can fail with the precise reason ("no such branch" / "already exists") instead of
// handing the user git's prose — and, for the switch, it is also what forecloses `checkout`'s DWIM:
// a name that exists locally can never be reinterpreted as "create a tracking branch from a remote".
//
// BranchExists 报告 refs/heads/<name> 能否解析。切分支**之前**与建分支之前都问它,使各自能以精确理由失败
// (「没有这条分支」/「已存在」)、而不是把 git 的散文丢给用户——而对**切**而言,它还是封掉 `checkout` 的
// DWIM 的那一手:一个本地已存在的名字,永不可能被重解成「从某个远端建一条跟踪分支」。
func BranchExists(ctx context.Context, dir, name string) bool {
	_, ok := run(ctx, dir, "rev-parse", "--verify", "--quiet", "refs/heads/"+name)
	return ok
}

// CheckRefFormat asks GIT whether name is a legal branch name (原则 #8 — `check-ref-format` is the
// rule, and re-deriving it from the gitrevisions man page in Go is how you end up accepting `a..b`).
// It is purely syntactic and needs no repository, so it runs before anything touches the residency.
//
// The pure-Go pre-checks are not redundant: `check-ref-format` happily accepts a name beginning with
// `-` (a legal ref) which would then be read as a FLAG by the next command, and it accepts a bare `@`,
// which git's own revision parser treats as HEAD.
//
// CheckRefFormat 问 **git** 这个名字是否合法分支名(原则 #8——`check-ref-format` 就是那条规则,而在 Go 里
// 照 gitrevisions 手册重推一遍,结局就是收下 `a..b`)。它纯语法、不需要仓库,故在任何东西碰到驻地之前先跑。
//
// 那两条纯 Go 前置检查并非冗余:`check-ref-format` 会愉快地收下以 `-` 开头的名字(它是合法 ref),而那个名字
// 会被下一条命令读成**选项**;它也收下裸 `@`,而 git 自己的 revision 解析器把 `@` 当作 HEAD。
func CheckRefFormat(ctx context.Context, name string) bool {
	if name == "" || name == "@" || strings.HasPrefix(name, "-") {
		return false
	}
	ctx, cancel := context.WithTimeout(ctx, probeTimeout)
	defer cancel()
	return exec.CommandContext(ctx, "git", "check-ref-format", "refs/heads/"+name).Run() == nil
}

// Checkout switches dir's working tree to an EXISTING local branch (WD2).
//
// It does not pass `--force`, does not stash and does not create: this call either moves HEAD or fails
// loudly. The caller refuses a dirty work tree BEFORE calling (see the residency's guardrail) so that
// git's own carry-over behaviour — which quietly relocates uncommitted work onto another branch — never
// happens behind the user's back.
//
// Checkout 把 dir 的工作树切到一条**已存在**的本地分支(WD2)。
//
// 它不传 `--force`、不 stash、不新建:这次调用要么移动 HEAD、要么大声失败。调用方在调用**之前**就拒掉脏
// 工作树(见驻地那道护栏),使 git 自己的「带过去」行为——它会静默地把未提交的活搬到另一条分支上——绝不在
// 用户背后发生。
func Checkout(ctx context.Context, dir, branch string) error {
	return runWrite(ctx, dir, "checkout", branch)
}

// CreateBranch creates branch at the current HEAD and switches to it (WD2).
//
// A dirty work tree is FINE here and that asymmetry with [Checkout] is the point: the new branch starts
// at the commit already checked out, so the working tree's content does not change by one byte and no
// conflict is possible — the uncommitted work simply becomes uncommitted work on the new branch. That
// is the most common branching flow there is ("I started, then realized this deserves its own branch"),
// and refusing it would be a guardrail against nothing.
//
// CreateBranch 在当前 HEAD 建分支并切过去(WD2)。
//
// 此处脏工作树**无妨**,而它与 Checkout 的这处不对称正是要点:新分支起点就是已 checkout 的那个 commit,故
// 工作树内容一个字节都不变、冲突不可能发生——未提交的活只是变成了新分支上的未提交的活。那是最常见的开分支
// 流程(「先动手,然后意识到这该有自己的分支」),拒掉它等于守一道什么都不守的护栏。
func CreateBranch(ctx context.Context, dir, branch string) error {
	return runWrite(ctx, dir, "checkout", "-b", branch)
}

// AddWorktree creates a parallel checkout at path on branch (WD3), creating the branch when newBranch.
//
// The two shapes mirror the repository's `make worktree` exactly (`worktree add <path> <branch>` when
// the branch already exists, `worktree add -b <branch> <path>` when it does not), because a worktree
// this makes and one that discipline makes must be the same object — otherwise the user has two
// conventions to remember and one of them is a trap.
//
// AddWorktree 在 path 建一份出着 branch 的平行 checkout(WD3);newBranch 时顺带建那条分支。
//
// 两种形状与本仓的 `make worktree` **逐字**一致(分支已存在 → `worktree add <path> <branch>`,不存在 →
// `worktree add -b <branch> <path>`),因为本处建出的 worktree 与纪律建出的 worktree 必须是**同一种**东西
// ——否则用户要记两套约定,而其中一套是陷阱。
func AddWorktree(ctx context.Context, dir, path, branch string, newBranch bool) error {
	if newBranch {
		return runWrite(ctx, dir, "worktree", "add", "-b", branch, path)
	}
	return runWrite(ctx, dir, "worktree", "add", path, branch)
}

// WorktreeBranchPrefix + [WorktreeTarget] ARE the repository's `make worktree` convention, transcribed
// once here so an app-made worktree and a discipline-made one are indistinguishable objects:
//
//	make worktree NAME=<x>  →  ../Anselm-<x>  on branch  wt/<x>
//
// i.e. a SIBLING of the working tree's root, named `<root's own name>-<name>`, on branch `wt/<name>`.
// The Makefile writes `../Anselm-` literally because Anselm IS its root's name; the general rule is the
// root's basename, which is what makes this reusable for a residency mounted on any repository.
//
// The sibling position is also the SECURITY property: callers hand in a NAME, never a path, so the
// target is derived and can only ever land next to the repository. [ValidWorktreeName] keeps the name a
// single path segment, which is what makes that derivation airtight.
//
// WorktreeBranchPrefix 与 WorktreeTarget **就是**本仓 `make worktree` 的约定,在此转录**一次**,使 app 建的
// worktree 与纪律建的 worktree 是无从区分的同一种对象:
//
//	make worktree NAME=<x>  →  ../Anselm-<x>  分支 wt/<x>
//
// 即工作树根的**兄弟**位置、名为 `<根自己的名字>-<name>`、分支 `wt/<name>`。Makefile 里写死 `../Anselm-`
// 是因为 Anselm **就是**它那个根的名字;一般规则是取根的 basename,而正是这一点让它对挂在**任何**仓库上的
// 驻地都可用。
//
// 兄弟位置同时是那条**安全**性质:调用方交进来的是**名字**、绝不是路径,故目标由此派生、只可能落在仓库旁边。
// ValidWorktreeName 保证名字是**单个**路径段,而那正是让这次派生密不透风的东西。
const WorktreeBranchPrefix = "wt/"

// WorktreeTarget derives the sibling directory `make worktree` would create for name.
//
// WorktreeTarget 派生出 `make worktree` 会为 name 建的那个兄弟目录。
func WorktreeTarget(top, name string) string {
	return filepath.Join(filepath.Dir(top), filepath.Base(top)+"-"+name)
}

// ValidWorktreeName reports whether name may become BOTH a directory segment and a branch under
// [WorktreeBranchPrefix]. Stricter than a branch name on purpose: `feat/x` is a perfectly good branch
// but as a directory it would be a nested path, and a name that escapes its parent (`..`, an absolute
// spelling) is precisely the input the sibling derivation must never accept.
//
// The syntactic ref rules are still git's ([CheckRefFormat] is asked separately, on `wt/<name>`) — this
// only adds the path-segment half that git has no opinion about.
//
// ValidWorktreeName 报告 name 是否可以**同时**做一个目录段与 WorktreeBranchPrefix 下的一条分支。刻意比分支
// 名更严:`feat/x` 是一条完全合格的分支,但作目录它是一条**嵌套**路径;而一个能逃出父目录的名字(`..`、绝对
// 写法)正是那次兄弟派生绝不能收下的输入。
//
// 语法上的 ref 规则仍归 git(CheckRefFormat 另问、问的是 `wt/<name>`)——此处只补 git 不表态的「单路径段」那半。
func ValidWorktreeName(name string) bool {
	if name == "" || name == "." || name == ".." || strings.HasPrefix(name, "-") {
		return false
	}
	if strings.ContainsAny(name, `/\`) || filepath.Base(name) != name || filepath.IsAbs(name) {
		return false
	}
	return true
}

// CommandError is a failed WRITE, carrying git's own stderr. The message git prints is the most useful
// sentence anyone has about why a checkout or a worktree add refused, so it is preserved verbatim for
// the layer that turns it into an answer the user can act on — never replaced by a guess.
//
// CommandError 是一次失败的**写**,带着 git 自己的 stderr。git 打印的那句话,是关于「一次 checkout 或
// worktree add 为何被拒」所有人手上最有用的一句,故**逐字**留给上层去把它变成用户可行动的回答——绝不用一句
// 猜测替换它。
type CommandError struct {
	Args   []string
	Stderr string
	Err    error
}

func (e *CommandError) Error() string {
	if e.Stderr != "" {
		return fmt.Sprintf("git %s: %s", strings.Join(e.Args, " "), e.Stderr)
	}
	return fmt.Sprintf("git %s: %v", strings.Join(e.Args, " "), e.Err)
}

func (e *CommandError) Unwrap() error { return e.Err }

// writeTimeout bounds each MUTATING invocation. It is far longer than probeTimeout because these do
// real work — a checkout rewrites the work tree and `worktree add` writes a whole second one — but it
// is still bounded: an HTTP request must not hang forever on a repository that is fetching over a
// stalled network mount.
//
// writeTimeout 界住每次**改动性**调用。它远长于 probeTimeout,因为这些在干真活——一次 checkout 会重写工作
// 树、`worktree add` 会写出**第二**份——但它仍然有界:一个 HTTP 请求不该在一个正经由僵死网络挂载取数的仓库
// 上永远挂着。
const writeTimeout = 60 * time.Second

// runWrite executes a mutating git command and reports failure WITH git's stderr. Absence is an error
// here (unlike run): if there is no git binary the user's requested change did not happen, and saying
// nothing would be the write silently doing nothing.
//
// runWrite 执行一条改动性 git 命令,失败时**带上** git 的 stderr 上报。此处「不存在」**是**错误(与 run
// 相反):没有 git 二进制,就意味着用户要的改动没有发生,而闭口不谈等于让这次写静默地什么都没做。
func runWrite(ctx context.Context, dir string, args ...string) error {
	ctx, cancel := context.WithTimeout(ctx, writeTimeout)
	defer cancel()
	full := append([]string{"-C", dir}, args...)
	cmd := exec.CommandContext(ctx, "git", full...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return &CommandError{Args: args, Stderr: strings.TrimSpace(stderr.String()), Err: err}
	}
	return nil
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
