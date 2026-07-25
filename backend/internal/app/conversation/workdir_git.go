// workdir_git.go — the residency's three GIT ACTIONS (WRK-077 WD2 + WD3): switch to an existing branch,
// create a branch and move onto it, and open a parallel worktree for this conversation and move the
// residency there.
//
// The whole file is deliberately three verbs wide. This is NOT a git client: there is no commit, push,
// pull, merge, rebase or reset here and there is not meant to be (§1 拍板 #10 — only the actions that are
// about "where this conversation lives"). Everything below shells out through infra/gitinfo, which passes
// argument arrays and never a shell string.
//
// The layering: gitinfo knows git, this file knows what a refusal MEANS. Every pre-check exists so the
// user gets a sentence with a next step in it rather than git's prose — and when the pre-checks have
// nothing to say, git's prose is forwarded verbatim (ErrGitFailed's `git` detail) rather than replaced by
// a guess.
//
// workdir_git.go —— 驻地的三个 **git 动作**（WRK-077 WD2 + WD3）:切到一条已存在的分支、新建一条分支并移过去、
// 为本对话开一份平行 worktree 并把驻地移过去。
//
// 整个文件**刻意**只有三个动词宽。这**不是**一个 git 客户端:此处没有 commit / push / pull / merge / rebase /
// reset，也不打算有（§1 拍板 #10——只做与「这段对话住在哪」有关的动作）。以下一切都经 infra/gitinfo 调用，
// 它传参数数组、绝不拼 shell 字符串。
//
// 分层:gitinfo 懂 git，本文件懂一次拒绝**意味着什么**。每一条预检的存在，都是为了让用户拿到一句**带下一步**的
// 话、而不是 git 的散文——而当预检无话可说时，git 的散文被**逐字**转发（ErrGitFailed 的 `git` detail）、而不是
// 被一句猜测替换。
package conversation

import (
	"context"
	"errors"
	"os"
	"strings"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	gitinfoinfra "github.com/sunweilin/anselm/backend/internal/infra/gitinfo"
)

// SwitchBranch moves the residency's work tree onto an EXISTING local branch and returns the freshly
// re-probed projection (WD2).
//
// THE GUARDRAIL — a dirty work tree is REFUSED (ErrWorkDirDirty carries the next step). The reasoning
// lives on that sentinel; the short version is that git's own "carry the changes over if I can" makes the
// surprising outcome the silent success case, and refusing is the only behaviour here that cannot lose a
// line of the user's work. Nothing is forced, nothing is stashed.
//
// The projection is returned rather than a bare 204 because a branch switch changes several of its fields
// at once (branch, dirty, and — with a worktree in play — which entry is current), and a client that has
// to re-GET is a client that renders one frame of the old branch.
//
// SwitchBranch 把驻地的工作树移到一条**已存在**的本地分支上，并返回**重探**后的投影（WD2）。
//
// **护栏**——脏工作树被**拒绝**（ErrWorkDirDirty 带着下一步）。理由写在那个 sentinel 上;短版本是:git 自己的
// 「能带过去就带」让那个令人意外的结局成了静默的成功路径，而在此处拒绝是唯一一种不可能丢掉用户一行活的行为。
// 什么都不强制、什么都不 stash。
//
// 返回投影而非一个裸 204，是因为一次切分支同时改变它的好几个字段（分支、脏、以及有 worktree 在场时哪一条是
// current），而一个还得再 GET 一次的客户端，就是一个会渲出一帧旧分支的客户端。
func (s *Service) SwitchBranch(ctx context.Context, id, branch string) (*conversationdomain.WorkDirInfo, error) {
	dir, name, err := s.gitTarget(ctx, id, branch)
	if err != nil {
		return nil, err
	}
	if !gitinfoinfra.BranchExists(ctx, dir, name) {
		return nil, conversationdomain.ErrBranchNotFound
	}
	// Read dirtiness HERE rather than trusting whatever the client last saw: the user may have edited a
	// file in their own editor since the menu opened, and a guardrail that consults a stale projection is
	// no guardrail. 在**此处**读脏态、不信客户端上次看到的:菜单打开之后用户可能在自己编辑器里改了文件，而一道
	// 咨询过期投影的护栏不是护栏。
	if _, dirty, isRepo := gitinfoinfra.Status(ctx, dir); !isRepo {
		return nil, conversationdomain.ErrWorkDirNotGitRepo
	} else if dirty {
		return nil, conversationdomain.ErrWorkDirDirty
	}
	if err := gitinfoinfra.Checkout(ctx, dir, name); err != nil {
		return nil, gitFailure(err)
	}
	return s.WorkDirInfo(ctx, id)
}

// CreateBranch creates a branch at the residency's current HEAD, switches onto it, and returns the freshly
// re-probed projection (WD2).
//
// A dirty work tree is ALLOWED here, and the asymmetry with [SwitchBranch] is deliberate: the new branch
// starts at the commit already checked out, so the work tree does not change by a byte and no conflict can
// exist — the uncommitted work simply becomes uncommitted work on the new branch. That is the most common
// branching flow there is ("I started, then realized this deserves its own branch"), and gating it would be
// a guardrail against nothing.
//
// CreateBranch 在驻地当前 HEAD 上建一条分支、切过去，并返回**重探**后的投影（WD2）。
//
// 此处**允许**脏工作树，而与 SwitchBranch 的这处不对称是刻意的:新分支起点就是已 checkout 的那个 commit，故工作
// 树一个字节都不变、冲突不可能存在——未提交的活只是变成了新分支上的未提交的活。那是最常见的开分支流程（「先动手，
// 然后意识到这该有自己的分支」），给它上门等于守一道什么都不守的护栏。
func (s *Service) CreateBranch(ctx context.Context, id, branch string) (*conversationdomain.WorkDirInfo, error) {
	dir, name, err := s.gitTarget(ctx, id, branch)
	if err != nil {
		return nil, err
	}
	if gitinfoinfra.BranchExists(ctx, dir, name) {
		return nil, conversationdomain.ErrBranchExists
	}
	if err := gitinfoinfra.CreateBranch(ctx, dir, name); err != nil {
		return nil, gitFailure(err)
	}
	return s.WorkDirInfo(ctx, id)
}

// AddWorktree opens a parallel worktree for this conversation and MOVES the residency into it — the whole
// one-shot the contract asks for (WD3): directory created, branch created (or reused), residency switched,
// in-line mark dropped, projection returned.
//
// Path and branch are NOT parameters. The caller hands in a NAME and the target is derived by the
// repository's own `make worktree` convention (gitinfo.WorktreeTarget / WorktreeBranchPrefix): a SIBLING of
// the repository named `<repo>-<name>`, on branch `wt/<name>`. Two reasons, both load-bearing: a worktree
// this makes and one `make worktree` makes must be the same object (one convention to remember, no traps),
// and a derived sibling is the SECURITY property — an endpoint that accepted a path would be an endpoint
// that writes a checkout anywhere on the disk.
//
// An existing `wt/<name>` BRANCH is reused rather than refused, exactly as the Makefile does, because that
// is a real flow: `make worktree-rm` deliberately keeps the branch, so re-opening a worktree on it is the
// documented way back. An existing DIRECTORY is refused (ErrWorktreeExists) — it holds somebody's work,
// possibly another session's, and adopting it silently is how two agents come to edit one tree.
//
// The residency switch goes through [Service.Update], not a direct repo write: that is the one place that
// normalizes the path, appends the durable `marker` block and emits `conversation.work_dir`. Doing it by
// hand here would be three behaviours re-implemented and one of them (the marker) silently lost.
//
// AddWorktree 为本对话开一份平行 worktree 并把驻地**移进去**——即契约要的那条一条龙（WD3）:目录建好、分支建好
// （或复用）、驻地切过去、行内标记落下、返回投影。
//
// 路径与分支**不是**参数。调用方交进来一个**名字**，目标按本仓自己的 `make worktree` 约定派生
// （gitinfo.WorktreeTarget / WorktreeBranchPrefix）:仓库的**兄弟**位置、名为 `<仓库>-<name>`、分支 `wt/<name>`。
// 两个理由都承重:本处建出的 worktree 与 `make worktree` 建出的必须是**同一种**对象（只有一套约定要记、没有陷阱），
// 而一个**派生**出来的兄弟位置就是那条**安全**性质——一个收路径的端点，就是一个能往磁盘任意处写出一份 checkout
// 的端点。
//
// 已存在的 `wt/<name>` **分支**被**复用**而非拒绝，与 Makefile 完全一致，因为那是一条真实流程:`make worktree-rm`
// **刻意**保留分支，故在它之上重开一份 worktree 正是被写进文档的回头路。已存在的**目录**被拒
// （ErrWorktreeExists）——它装着某人的活、可能是另一个会话的，而静默接管它正是两个 agent 编辑同一棵树的方式。
//
// 驻地的切换走 Service.Update、不是直接写 repo:那里是唯一一处会归一化路径、追加持久 `marker` 块、并发
// `conversation.work_dir` 的地方。在此手写等于重新实现三个行为、并静默丢掉其中一个（那条标记）。
func (s *Service) AddWorktree(ctx context.Context, id, name string) (*conversationdomain.WorkDirInfo, error) {
	dir, err := s.gitResidency(ctx, id)
	if err != nil {
		return nil, err
	}
	seg := strings.TrimSpace(name)
	branch := gitinfoinfra.WorktreeBranchPrefix + seg
	if !gitinfoinfra.ValidWorktreeName(seg) || !gitinfoinfra.CheckRefFormat(ctx, branch) {
		return nil, conversationdomain.ErrInvalidWorktreeName
	}
	// Derived from the MAIN working tree, not the current one: the discipline is a FLAT row of siblings next
	// to the repository, so opening a worktree from inside `Anselm-a` must still land `Anselm-b` — never
	// `Anselm-a-b`, and never `Anselm-a-b-c` after that.
	// 从**主**工作树派生、不是当前那棵:纪律是仓库旁边**一排平的**兄弟，故在 `Anselm-a` 里开一份仍必须落成
	// `Anselm-b`——绝不是 `Anselm-a-b`，也绝不是再下一次的 `Anselm-a-b-c`。
	top, ok := gitinfoinfra.MainToplevel(ctx, dir)
	if !ok {
		return nil, conversationdomain.ErrWorkDirNotGitRepo
	}
	target := gitinfoinfra.WorktreeTarget(top, seg)
	// Anything at the target is a refusal, file or directory alike: `worktree add` would refuse a non-empty
	// directory anyway, but saying it HERE is what lets the message name the next step.
	// 目标位置上有任何东西都是拒绝，文件目录一视同仁:`worktree add` 本就会拒一个非空目录，但在**此处**说出来
	// 才能让那句话点出下一步。
	if _, statErr := os.Lstat(target); statErr == nil {
		return nil, conversationdomain.ErrWorktreeExists.WithDetails(map[string]any{"path": target})
	}
	if err := gitinfoinfra.AddWorktree(ctx, dir, target, branch, !gitinfoinfra.BranchExists(ctx, dir, branch)); err != nil {
		return nil, gitFailure(err)
	}
	// The residency follows the worktree — that IS the feature ("open a worktree FOR THIS CONVERSATION").
	// A failure here leaves a perfectly good worktree on disk and the thread where it was, which is the
	// honest half-state to be in: nothing was destroyed and the user can mount it by hand.
	// 驻地**跟着** worktree 走——那**就是**这个功能（「为**此对话**开一个 worktree」）。此处失败会留下一份完好的
	// worktree 与仍在原处的线程，那是可以停在的那个诚实的半状态:什么都没被毁，用户手动挂上即可。
	if _, err := s.Update(ctx, id, UpdateInput{WorkDir: &target}); err != nil {
		return nil, err
	}
	return s.WorkDirInfo(ctx, id)
}

// gitTarget resolves the residency AND validates a branch name — the two things both branch actions need
// before they may touch anything.
//
// gitTarget 解出驻地**并**校验分支名——两个分支动作在碰任何东西之前都需要的那两件事。
func (s *Service) gitTarget(ctx context.Context, id, branch string) (dir, name string, err error) {
	dir, err = s.gitResidency(ctx, id)
	if err != nil {
		return "", "", err
	}
	name = strings.TrimSpace(branch)
	if !gitinfoinfra.CheckRefFormat(ctx, name) {
		return "", "", conversationdomain.ErrInvalidBranch
	}
	return dir, name, nil
}

// gitResidency returns the conversation's mounted directory, refusing when it cannot host a git action.
//
// All three flavours of "there is no git here" collapse into ONE answer (ErrWorkDirNotGitRepo) on purpose:
// unmounted, gone, not a repository, no `git` binary — the caller's next step is the same in every case
// (mount a directory that is a repository), and splitting them would be four messages saying one thing.
// That mirrors gitinfo's own read contract, which also declines to distinguish them.
//
// gitResidency 返回对话已挂的目录，当它无法承载一个 git 动作时拒绝。
//
// 「这里没有 git」的三种形态**刻意**收成**一个**答案（ErrWorkDirNotGitRepo）:未挂、已消失、不是仓库、没有 `git`
// 二进制——调用方的下一步在每种情形下都一样（挂一个是仓库的目录），把它们拆开等于四句话说同一件事。这与 gitinfo
// 自己的读契约同构，它同样拒绝区分它们。
func (s *Service) gitResidency(ctx context.Context, id string) (string, error) {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return "", err
	}
	if c.WorkDir == "" {
		return "", conversationdomain.ErrWorkDirNotGitRepo
	}
	if st, statErr := os.Stat(c.WorkDir); statErr != nil || !st.IsDir() {
		return "", conversationdomain.ErrWorkDirNotGitRepo
	}
	if _, ok := gitinfoinfra.Branch(ctx, c.WorkDir); !ok {
		return "", conversationdomain.ErrWorkDirNotGitRepo
	}
	return c.WorkDir, nil
}

// gitFailure turns a gitinfo write failure into the domain's catch-all, forwarding git's OWN stderr under
// the `git` detail. The stderr is the most useful sentence anybody has about why a checkout refused, so it
// is carried through verbatim rather than replaced by a guess — and it is a DETAIL rather than the message
// so the wire code stays stable and the UI still has one sentence it can localize.
//
// gitFailure 把一次 gitinfo 写失败变成 domain 的兜底码，并在 `git` detail 下转发 git **自己的** stderr。那段
// stderr 是关于「一次 checkout 为何被拒」所有人手上最有用的一句，故**逐字**带出、不用一句猜测替换——而它是
// **detail** 而非 message，使线缆码保持稳定、UI 仍有一句可本地化的话。
func gitFailure(err error) error {
	var cmdErr *gitinfoinfra.CommandError
	if errors.As(err, &cmdErr) && cmdErr.Stderr != "" {
		return conversationdomain.ErrGitFailed.WithCause(err).WithDetails(map[string]any{"git": cmdErr.Stderr})
	}
	return conversationdomain.ErrGitFailed.WithCause(err)
}
