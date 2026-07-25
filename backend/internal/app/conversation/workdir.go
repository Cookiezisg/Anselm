package conversation

import (
	"context"
	"os"
	"strings"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	gitinfoinfra "github.com/sunweilin/anselm/backend/internal/infra/gitinfo"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	fspathpkg "github.com/sunweilin/anselm/backend/internal/pkg/fspath"

	"go.uber.org/zap"
)

// WorkDirMarker is the chat-side hook for the residency's durable in-line mark (chatapp.Service
// satisfies it, injected post-build like canceler / querier). It exists because the marker is a
// `message_blocks` row and MESSAGES BELONG TO CHAT — conversation owns the thread record, not its
// content, so writing the block here would be this layer reaching into another's table.
//
// A DIP port rather than a direct call for the usual reason: chatapp already depends on
// conversationapp (it reads the head every turn), so the reverse edge must be an interface or the
// packages cycle.
//
// WorkDirMarker 是驻地持久行内标记的 chat 侧钩子（chatapp.Service 满足它，与 canceler / querier 同款
// 后注入）。它存在是因为标记是一条 `message_blocks` 行,而**消息归 chat**——conversation 拥有线程记录、
// 不拥有它的内容,在此写那个块等于本层伸手进别人的表。
//
// 用 DIP 端口而非直接调用是老理由:chatapp 本就依赖 conversationapp（每回合读头行）,故反向边必须是
// 接口、否则两包成环。
type WorkDirMarker interface {
	MarkWorkDirSwitch(ctx context.Context, conversationID, from, to string) error
}

// SetWorkDirMarker injects the chat hook (post-build wiring, breaking the chat↔conversation cycle).
// nil → a residency switch simply leaves no mark.
//
// SetWorkDirMarker 注入 chat 钩子（后注入，破 chat↔conversation 环）。nil → 切换驻地只是不留标记。
func (s *Service) SetWorkDirMarker(m WorkDirMarker) { s.workDirMarker = m }

// markWorkDirSwitch drops the durable in-line mark for a mid-thread residency change. Best-effort and
// deliberately so: the residency itself is already persisted on the row, and refusing the user's
// switch because a decorative mark failed to write would be the tail wagging the dog.
//
// markWorkDirSwitch 为线程中途的驻地变更落下持久行内标记。best-effort 且刻意如此:驻地本身已经落在行上,
// 因为一条装饰性标记没写成而拒掉用户的切换是本末倒置。
func (s *Service) markWorkDirSwitch(ctx context.Context, conversationID, from, to string) {
	if s.workDirMarker == nil {
		return
	}
	if err := s.workDirMarker.MarkWorkDirSwitch(ctx, conversationID, from, to); err != nil {
		s.log.Warn("conversationapp.markWorkDirSwitch: failed (non-fatal)",
			zap.String("conversationId", conversationID), zap.Error(err))
	}
}

// WorkDirInfo computes the residency's live projection for one conversation (`GET /{id}/workdir`).
// Nothing is cached: the filesystem and git are the truth, and a conversation whose directory the user
// just deleted — or whose branch they just switched in their own terminal — must read as it now IS.
//
// An unmounted thread returns the zero projection (empty path, exists=false) rather than a 404: "this
// conversation has no residency" is a successful answer to the question, and the button that calls this
// needs to render the unmounted state too.
//
// The git probe runs ONLY when the directory exists and only once (a single `git status --porcelain=v2
// --branch`), so the cost of an unmounted or missing residency is one os.Stat.
//
// WorkDirInfo 现算某对话驻地的活投影（`GET /{id}/workdir`）。零缓存:文件系统与 git 才是真相,用户刚删掉
// 目录的对话——或刚在自己终端里切了分支的对话——必须读作它**现在的样子**。
//
// 未挂线程返回零投影（空路径、exists=false）而**不是** 404:「这个对话没有驻地」是对该问题的一个**成功**
// 回答,而调用它的那个按钮也要渲染未挂态。
//
// git 探针**仅在**目录存在时跑、且只跑一次（一次 `git status --porcelain=v2 --branch`）,故未挂或已消失的
// 驻地只花一次 os.Stat。
func (s *Service) WorkDirInfo(ctx context.Context, id string) (*conversationdomain.WorkDirInfo, error) {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	info := &conversationdomain.WorkDirInfo{Path: c.WorkDir}
	if c.WorkDir == "" {
		return info, nil
	}
	// A regular FILE at the path is not a residency either — Exists means "usable as a work dir".
	// 路径上是普通**文件**同样不算驻地——Exists 意为「可作工作目录用」。
	st, statErr := os.Stat(c.WorkDir)
	info.Exists = statErr == nil && st.IsDir()
	if !info.Exists {
		return info, nil
	}
	branch, dirty, isRepo := gitinfoinfra.Status(ctx, c.WorkDir)
	info.IsGitRepo, info.Branch, info.Dirty = isRepo, branch, dirty
	return info, nil
}

// WorkDirGroups returns the rail's residency grouping (`GET /conversations/workdir-groups`) — one row per
// directory some UNPINNED thread lives in, most-recently-active first. A thin pass-through: the whole point
// of the endpoint is that the aggregation happen in ONE server-side GROUP BY over the whole workspace, so
// there is nothing for this layer to add and nothing for the client to recompute.
//
// WorkDirGroups 返回 rail 的驻地分组（`GET /conversations/workdir-groups`）——每个住着**未置顶**线程的目录一行、
// 最近活跃在前。薄薄转发:该端点的全部意义就在于聚合发生在服务端对整个 workspace 的**一次** GROUP BY，故本层
// 无可添加、客户端亦无须重算。
func (s *Service) WorkDirGroups(ctx context.Context) ([]conversationdomain.WorkDirGroup, error) {
	return s.repo.WorkDirGroups(ctx)
}

// ArchiveWorkDir archives a whole residency group's threads in one request (`POST :archive-workdir`).
//
// Returns how many conversations actually changed. The rail needs this endpoint rather than a loop of N
// PATCHes for two reasons that are not about speed: a loop can be interrupted half-way (leaving a group the
// user asked to file away in a state that is neither filed nor not), and a loop's N-th failure has no
// honest thing to report. One statement in one transaction has exactly two outcomes.
//
// ArchiveWorkDir 一次请求归档整个驻地组的线程（`POST :archive-workdir`）。
//
// 返回真正改变了几条对话。rail 需要这个端点、而不是 N 次 PATCH 的循环，理由有两条且都与速度无关:循环可能在
// 半途被打断（把用户要收起来的一组留在既非收起也非未收起的状态），而循环的第 N 次失败没有任何诚实的话可报。
// 一个事务里的一条语句恰好只有两种结局。
func (s *Service) ArchiveWorkDir(ctx context.Context, workDir string) (int, error) {
	dir, err := normalizeGroupWorkDir(workDir)
	if err != nil {
		return 0, err
	}
	ids, err := s.repo.ArchiveWorkDir(ctx, dir)
	if err != nil {
		return 0, err
	}
	// One echo per conversation, on the EXISTING `conversation.archived` word (E1/E2: no new stream, no new
	// frame type). Per-row is not laziness — each of these rows genuinely was archived, and the rail
	// reconciles by re-reading the row a signal names; a single aggregate frame would name no row and every
	// other client would have to guess what moved.
	// 逐对话一条回声，用**既有**的 `conversation.archived` 词（E1/E2:不加流、不加帧型）。逐行不是偷懒——这些行
	// 每一条确实被归档了，而 rail 的对账方式正是重读信号点出的那一行;一条聚合帧点不出任何行，别的客户端只能猜
	// 是什么动了。
	for _, id := range ids {
		s.emit(ctx, id, "archived", map[string]any{"archived": true})
	}
	return len(ids), nil
}

// DeleteWorkDir soft-deletes a whole residency group's threads in one request (`POST :delete-workdir`).
//
// WHAT IT DELETES, exactly: the `deleted_at` stamp on those `conversations` rows, plus each thread's
// relation edges and its touchpoint ledger — the same cascade a single Delete performs, because those are
// derived indexes of a thread that no longer exists. WHAT IT DOES NOT DELETE: any message. `messages` /
// `message_blocks` are D1 Log tables — no `deleted_at`, never physically deleted — so the transcripts stay
// on disk exactly as they were. And, most importantly for the user: nothing on the FILESYSTEM. The
// residency is a string on a row; this endpoint reads it as a grouping key and never touches the directory
// it names.
//
// The cascade runs AFTER the transaction commits, per row and best-effort, exactly as single Delete's does:
// a failed edge purge must not resurrect a thread the user deleted. Cancelling generation therefore also
// lands after the write rather than before it (single Delete cancels first) — the id set cannot be known
// without reading it, and reading it outside the write would let the set drift between the read and the
// write. The window is milliseconds, during which the turn is streaming into a row no reader can reach.
//
// DeleteWorkDir 一次请求软删整个驻地组的线程（`POST :delete-workdir`）。
//
// **它到底删了什么**:那些 `conversations` 行上的 `deleted_at` 戳，加上每条线程的 relation 边与它的触点台账——
// 与单条 Delete 完全相同的级联，因为那些是一条**已不存在**的线程的派生索引。**它没有删什么**:任何消息。
// `messages` / `message_blocks` 是 D1 Log 表——无 `deleted_at`、绝不物理删——故那些逐字记录**原样留在盘上**。
// 而对用户最要紧的一条:**文件系统上什么都没动**。驻地是行上的一个字符串;本端点把它当分组键读，绝不碰它点出的
// 那个目录。
//
// 级联在事务**提交之后**跑、逐行、best-effort，与单条 Delete 完全一致:一次失败的边清理不该复活一条用户已删的
// 线程。故停生成也落在写**之后**、而非之前（单条 Delete 先停）——不读就无从知道 id 集，而在写之外读会让集合在
// 读与写之间漂移。那个窗口是毫秒级的，其间那个回合正流进一条没有读者到得了的行。
func (s *Service) DeleteWorkDir(ctx context.Context, workDir string) (int, error) {
	dir, err := normalizeGroupWorkDir(workDir)
	if err != nil {
		return 0, err
	}
	ids, err := s.repo.SoftDeleteWorkDir(ctx, dir)
	if err != nil {
		return 0, err
	}
	for _, id := range ids {
		if s.canceler != nil {
			if err := s.canceler.Cancel(ctx, id); err != nil {
				s.log.Warn("conversationapp.DeleteWorkDir: cancel generation failed",
					zap.String("conversationId", id), zap.Error(err))
			}
			s.canceler.ForgetConversation(id)
		}
		s.emit(ctx, id, "deleted", nil)
		s.purgeRelations(ctx, id)
		s.purgeTouchpoints(ctx, id)
	}
	return len(ids), nil
}

// normalizeGroupWorkDir turns the client's residency string into the exact value stored on the rows, and
// refuses the two spellings that cannot name a group.
//
// EMPTY is refused deliberately and it is the important one: `work_dir = ”` is a perfectly good LIST
// filter (the rail's Recents section asks for exactly that), but it is NOT a group — the unmounted threads
// have no folder head and no ⋯ menu. Accepting it would mean one request could archive or delete every
// thread in the workspace that never picked a directory, an action no surface offers and no confirm dialog
// has ever inventoried. Non-absolute is refused for the reason WD1 already legislated: a relative root
// roots nothing, so it can only ever match zero rows while looking like it named something.
//
// normalizeGroupWorkDir 把客户端给的驻地字符串变成行上存的那个确切值，并拒掉两种点不出组的拼法。
//
// **空**被刻意拒绝，而它是要紧的那一个:`work_dir = ”` 是一个完全正当的**列表过滤**（rail 的「最近」段要的正是
// 它），但它**不是一个组**——未挂的线程没有文件夹头、没有 ⋯ 菜单。接受它意味着一个请求可以归档或删除本 workspace
// 里每一条**从未选过目录**的线程，而那是没有任何界面提供、也从未被任何确认框盘点过的动作。非绝对路径按 WD1 已
// 立的法拒:相对的根扎不住任何东西，故它只可能匹配零行、却看着像点出了什么。
func normalizeGroupWorkDir(workDir string) (string, error) {
	dir := strings.TrimSpace(workDir)
	if dir == "" {
		return "", errorspkg.ErrInvalidRequest
	}
	abs, err := fspathpkg.Expand(dir)
	if err != nil {
		return "", conversationdomain.ErrInvalidWorkDir
	}
	return abs, nil
}
