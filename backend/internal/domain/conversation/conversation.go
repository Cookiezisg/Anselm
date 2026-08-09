// Package conversation is the domain layer for chat-thread containers: the persistent,
// per-workspace thread entity (title, pin/archive, soft-delete) plus its thread-level
// config (system prompt, attached documents, model override). Messages are NOT here —
// they belong to chat; this package owns only the thread record + storage contract.
//
// Package conversation 是对话线程容器的 domain 层：按 workspace 持久化的线程实体（标题、
// 置顶/归档、软删）及其线程级配置（system prompt、挂载文档、模型覆盖）。消息**不在这里**——
// 归 chat；本包只持有线程记录 + 存储契约。
package conversation

import (
	"context"
	"time"

	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Conversation is a chat-thread container. The thread's messages live in chat's
// message_blocks; this record carries only the thread's identity, interaction state,
// and the config the chat runtime reads each turn. Summary / SummaryCoversUpToSeq are
// written by the compactor (app/contextmgr); AutoTitled is set by chat after it auto-names
// a turn-1 thread — all three are declared here (one coherent thread record) but kept off the
// PATCH surface. SystemPrompt / AttachedDocuments / ModelOverride are user-editable settings
// (this is conversation's job); chat merely consumes them at runtime.
//
// Conversation 是对话线程容器。线程消息在 chat 的 message_blocks；本记录只承载线程身份、
// 交互状态、chat 运行时每轮要读的配置。Summary / SummaryCoversUpToSeq 由压缩器（app/contextmgr）
// 写；AutoTitled 由 chat 给首轮线程自动命名后设——三者在此声明（一份内聚的线程记录）但
// 不进 PATCH 面。SystemPrompt / AttachedDocuments / ModelOverride 是用户可改的设置（conversation
// 的职责）；chat 仅在运行时消费。
type Conversation struct {
	ID                   string                            `db:"id,pk"                    json:"id"`
	WorkspaceID          string                            `db:"workspace_id,ws"          json:"-"`
	Title                string                            `db:"title"                    json:"title"`
	AutoTitled           bool                              `db:"auto_titled"              json:"autoTitled"`
	SystemPrompt         string                            `db:"system_prompt"            json:"systemPrompt,omitempty"`
	Summary              string                            `db:"summary"                  json:"summary,omitempty"`
	SummaryCoversUpToSeq int64                             `db:"summary_covers_up_to_seq" json:"summaryCoversUpToSeq,omitempty"`
	AttachedDocuments    []documentdomain.AttachedDocument `db:"attached_documents,json"  json:"attachedDocuments,omitempty"`
	Archived             bool                              `db:"archived"                 json:"archived"`
	Pinned               bool                              `db:"pinned"                   json:"pinned"`
	ModelOverride        *modeldomain.ModelRef             `db:"model_override,json"      json:"modelOverride,omitempty"`
	CreatedAt            time.Time                         `db:"created_at,created"       json:"createdAt"`
	UpdatedAt            time.Time                         `db:"updated_at,updated"       json:"updatedAt"`
	// LastMessageAt is the recency-sort key: the time of the most recent message added to the
	// thread (set at creation, bumped by chat on each user turn). It is a plain column — NOT the
	// ,updated tag — so pin/rename/model-override (which bump updated_at) never reorder the list.
	//
	// LastMessageAt 是最近活跃排序键：线程最后一条消息加入的时间（创建时设、chat 每个用户回合刷）。
	// 它是普通列、非 ,updated tag——故 pin/改名/换模型（刷 updated_at）不会重排列表。
	LastMessageAt time.Time  `db:"last_message_at" json:"lastMessageAt"`
	DeletedAt     *time.Time `db:"deleted_at,deleted" json:"-"`

	// IsGenerating is a derived runtime flag (NOT persisted, db:"-"): true when chat has an
	// in-flight assistant turn for this conversation. Filled per-row in the app layer from the
	// chat registry (GeneratingQuerier) so a freshly-connected client can cold-start its live
	// activity dots; read-only on the wire, never accepted in PATCH.
	//
	// IsGenerating 是派生运行时标志（不落库，db:"-"）：chat 有该对话在途 assistant 回合时为 true。
	// 由 app 层据 chat 登记（GeneratingQuerier）逐行填，使刚连上的客户端能冷启动活动圆点；线缆只读、
	// 不进 PATCH。
	IsGenerating bool `db:"-" json:"isGenerating"`

	// AwaitingInput is a derived runtime flag (NOT persisted, db:"-"): true when this conversation has
	// ≥1 pending human-in-loop interaction (an approve/answer the user must resolve before the turn
	// continues). Filled per-row in the app layer from the in-memory humanloop broker
	// (AwaitingInputQuerier), mirroring IsGenerating, so a freshly-connected client cold-starts its
	// "needs you" rail dot. Pending interactions live ONLY in the broker (no DB table, intentionally
	// ephemeral — a restart leaves none), so this is always derived, never stored. Read-only on the
	// wire, never accepted in PATCH.
	//
	// AwaitingInput 是派生运行时标志（不落库，db:"-"）：该对话有 ≥1 个待决人在环 interaction（用户须批准/回答、
	// 回合才续）时为 true。由 app 层据内存 humanloop broker（AwaitingInputQuerier）逐行填，镜像 IsGenerating，
	// 使刚连上的客户端冷启动「等你」rail 点。待决 interaction 只活在 broker（无 DB 表、刻意 ephemeral——重启即无），
	// 故恒派生、不落库。线缆只读、不进 PATCH。
	AwaitingInput bool `db:"-" json:"awaitingInput"`

	// Unread is a PERSISTED boolean (NOT db:"-"): true when a COMPLETED assistant reply has landed that
	// the user has not yet seen — the "answered while you were away" rail dot (green). It is a stored
	// flag, not a derived comparison: set true by the assistant-finalize TouchLastMessage (folded into
	// the same UPDATE, so it is atomic with the recency bump), and cleared (false) on the user's own
	// send (TouchLastMessage with unread=false — sending is seeing), on MarkSeen (the :seen action when
	// the user opens the thread), and at creation (column default 0). A stored bool — NOT a timestamp /
	// seq watermark — because this is a single-user, conversation-level binary: it needs no read-position
	// granularity, and storing the answer directly sidesteps wall-clock comparison entirely (no NTP
	// step-back / coarse-tick mis-flag). Survives restart (it is a column). System-write, wire read-only,
	// never accepted in PATCH (like Summary / AutoTitled).
	//
	// Unread 是**持久布尔**（非 db:"-"）：有一条**完成的** assistant 回复落地、用户尚未看 → 为 true，即「你不在时答完了」
	// 的 rail 绿点。它是存的标志、非派生比较：由 assistant 终态的 TouchLastMessage 置 true（折进同一条 UPDATE，故与
	// recency 刷新原子），并在用户自己发送（TouchLastMessage unread=false——发即是看）、MarkSeen（用户打开线程的 :seen
	// 动作）、创建（列默认 0）时清为 false。用存布尔、**非时间戳/seq watermark**——因为这是单用户、会话级的二元量：不需要
	// 读位置粒度，且直接存答案彻底绕开墙上时钟比较（无 NTP 回拨 / 粗 tick 误判）。重启照样记得（是列）。系统写、线缆只读、
	// 不进 PATCH（同 Summary / AutoTitled）。
	Unread bool `db:"unread" json:"hasUnread"`

	// ForkedFromConversationID / ForkedFromMessageID are the fork lineage: the source thread and the
	// message its prefix copy stopped at (inclusive). Written once at fork time and never updated —
	// a fork IS a new thread, not a view of the old one, so the pair is provenance, not a live link:
	// the source may later be deleted, the ids then dangle, and the UI simply shows no lineage line.
	// Both empty = an ordinary thread. System-write, wire read-only, never accepted in PATCH (like
	// Summary / AutoTitled).
	//
	// ForkedFromConversationID / ForkedFromMessageID 是分叉血缘：源线程 + 前缀复制停在的那条消息（含它）。
	// fork 时一次写定、永不更新——分叉**是**新线程、不是旧线程的视图，故这对 id 是溯源、非活链接：源日后
	// 可被删，届时 id 悬空、UI 只是不显血缘行。两者皆空 = 普通线程。系统写、线缆只读、不进 PATCH（同
	// Summary / AutoTitled）。
	ForkedFromConversationID string `db:"forked_from_conversation_id" json:"forkedFromConversationId,omitempty"`
	ForkedFromMessageID      string `db:"forked_from_message_id"      json:"forkedFromMessageId,omitempty"`

	// WorkDir is the thread's optional RESIDENCY: an absolute directory the agent is zoomed in on.
	// Empty = not mounted, which is the whole-machine status quo (every host tool stays available, it
	// just has no focus). Mounted, it does exactly three things: relative paths resolve against it,
	// Bash runs in it, and the system prompt says where "here" is.
	//
	// It is NOT a cage. Reads outside it are untouched by design (the user's words: "if I want to look
	// outside, I can"); only WRITES outside it escalate to a human confirmation. That is why this is
	// one plain column on the thread and not a permission model.
	//
	// A user-editable setting, so it rides the PATCH surface next to Title / ModelOverride — unlike
	// Summary / AutoTitled / Unread, which are system-write.
	//
	// WorkDir 是线程可选的**驻地**:agent 已 zoom in 的一个绝对目录。空 = 未挂,即整台机器的现状（宿主
	// 工具全都还在、只是没有焦点）。挂上后它只做三件事:相对路径以它解析、Bash 在它里面跑、system prompt
	// 说明「这里」是哪里。
	//
	// 它**不是**笼子。按设计,往外读分毫不受影响（用户原话:「想看外面什么的,都可以」）;只有往外**写**
	// 才升级为一次人工确认。正因如此,它是线程上一个朴素的列、而非一套权限模型。
	//
	// 它是用户可改的设置,故与 Title / ModelOverride 并列走 PATCH 面——不同于系统写的 Summary /
	// AutoTitled / Unread。
	WorkDir string `db:"work_dir" json:"workDir,omitempty"`
}

// WorkDirInfo is the residency's LIVE projection: what is true about the mounted directory right now,
// computed per request and stored nowhere. `GET /conversations/{id}/workdir` returns it.
//
// A derived projection, not a stored collection — hence no cursor (N4's bounded-projection class):
// the filesystem and git ARE the source of truth, and a cached copy would become a lie the moment the
// user switches branch in their own terminal. Path echoes the column so a client needs one read, not
// two; every other field answers a question the column cannot (does it still exist? a repo? which
// branch? any uncommitted work? which branches could we switch to? which parallel checkouts exist?).
//
// Exists=false with a non-empty Path is a real, renderable state: the user mounted a directory and
// then moved or deleted it. The residency button warns instead of silently pretending.
//
// WorkDirInfo 是驻地的**活投影**:此刻关于已挂目录为真的东西,逐请求现算、不存任何地方。
// `GET /conversations/{id}/workdir` 返回它。
//
// 派生投影、非已存集合——故无游标（N4 的「有界投影」那一类）:文件系统与 git **就是**真相源,缓存副本
// 在用户于自己终端里切一次分支的那一刻就成了谎。Path 回显该列,使客户端读一次而非两次;其余每个字段都
// 回答那个列答不了的问题（它还在吗?是仓库吗?哪个分支?有没有没提交的活?能切到哪些分支?有哪些平行
// checkout?）。
//
// Path 非空而 Exists=false 是一个真实且可渲染的状态:用户挂了一个目录,然后把它移走或删了。驻地按钮
// 会警示、而不是静默装作无事。
type WorkDirInfo struct {
	Path      string `json:"path"`
	Exists    bool   `json:"exists"`
	IsGitRepo bool   `json:"isGitRepo"`
	Branch    string `json:"branch,omitempty"`
	Dirty     bool   `json:"dirty"`
	// Branches are the repository's LOCAL branches, most-recently-committed first (WD2) — what the menu
	// offers to switch to. `refs/remotes` is deliberately excluded, and that exclusion is what keeps this
	// a BOUNDED projection with no cursor: refs/heads is the set this person created (human scale), while a
	// fetched remote can carry thousands.
	//
	// Branches 是仓库的**本地**分支、最近提交在前（WD2）——菜单提议切过去的那些。`refs/remotes` **刻意**排除，
	// 而正是这个排除让它保持为无游标的**有界**投影:refs/heads 是这个人自己建的那一集（人类尺度），而一份
	// fetch 过的远端可以带来上千条。
	Branches []string `json:"branches,omitempty"`
	// Worktrees are every checkout of this repository, the MAIN tree included (WD3). Including the current
	// one is the honest answer to "which worktrees does this repo have" — `Current` marks where this
	// residency stands, so the menu can offer the others without the caller re-deriving that.
	//
	// Worktrees 是本仓库的每一份 checkout、**含主树**（WD3）。含当前那一份才是「这个仓库有哪些 worktree」的诚实
	// 答案——`Current` 标出本驻地站在哪一份上，故菜单可以只提议其余那些、而调用方不必自己再推一遍。
	Worktrees []WorkTreeInfo `json:"worktrees,omitempty"`
}

// WorkTreeInfo is ONE parallel checkout of the residency's repository (WD3): where it lives, which branch
// it has out (empty = detached), and whether it is the one this conversation is mounted on.
//
// It carries no id and no lifecycle for the same reason WorkDirGroup does not: a worktree exists exactly
// as long as git says it does, and the truth is `git worktree list` — not a table.
//
// WorkTreeInfo 是驻地所在仓库的**一份**平行 checkout（WD3）:它在哪、出着哪条分支（空 = detached）、以及它是不是
// 本对话所挂的那一份。
//
// 它没有 id、没有生命周期，理由与 WorkDirGroup 相同:一个 worktree 存在的时长恰好等于 git 说它存在的时长，而真相
// 是 `git worktree list`——不是某张表。
type WorkTreeInfo struct {
	Path    string `json:"path"`
	Branch  string `json:"branch,omitempty"`
	Current bool   `json:"current"`
}

// WorkDirGroup is ONE residency group in the rail's grouped projection (WRK-077 WD1.5): the directory,
// how many threads live in it, and when it was last active. It is a PROJECTION, not an entity — there is
// no table, no id, no lifecycle: a group exists exactly as long as some conversation carries that
// work_dir, and the last thread leaving makes it vanish on its own. Hence no "empty group" to manage.
//
// It exists because the rail pages FOREVER: grouping a single page client-side would make membership and
// counts drift as the user scrolls — the rail would state a number that changes without anything changing.
// So the grouping is computed server-side over the whole workspace, in one GROUP BY.
//
// The counted set is the UNPINNED threads of that residency. A pinned thread is hoisted into the rail's
// own Pinned section and must appear exactly once, so counting it here would make the head's number
// disagree with the rows underneath it. The same rule governs the two bulk actions (see Repository), which
// is why one number can honestly head the group AND inventory the confirm dialog.
//
// TWO counts, no parameters: `ActiveCount` and `ArchivedCount` are reported separately so the caller needs
// no query parameter and no second request — the rail's "show archived" toggle picks or sums them, and a
// bulk action (which is deliberately scope-BLIND: a destructive action must not depend on a view toggle)
// inventories the sum. LastMessageAt spans BOTH, so toggling the view never reorders the groups.
//
// WorkDirGroup 是 rail 分组投影里的**一个**驻地组（WRK-077 WD1.5）:目录、住着几条线程、最近一次活跃在何时。
// 它是**投影、不是实体**——无表、无 id、无生命周期:一个组存在的时长恰好等于「还有对话带着那个 work_dir」，
// 最后一条离开它就自行消失。故没有「空组」要管理。
//
// 它之所以存在:rail 是**无限**翻页的——在一窗内做客户端分组会让成员与计数随滚动**漂移**，于是 rail 会报出
// 一个在什么都没变的情况下自己会变的数。故分组在服务端对整个 workspace 一次 GROUP BY 算出。
//
// 被计数的集合是该驻地的**未置顶**线程。置顶线程被提到 rail 自己的置顶段、且必须**恰好出现一次**，故在此
// 计入它会让组头的数与它下面的行**不一致**。两个批量动作遵守同一条规则（见 Repository），正因如此**一个**数
// 既能诚实地作组头、又能诚实地作确认框的盘点。
//
// **两个计数、零参数**:ActiveCount 与 ArchivedCount 分开上报，使调用方**不需要**查询参数、也不需要第二次请求
// ——rail 的「显示已归档」开关自行取其一或求和，而批量动作（**刻意对范围盲**:一个破坏性动作不该依赖一个视图
// 开关）盘点二者之和。LastMessageAt 跨**两者**，故切换视图绝不重排组的顺序。
type WorkDirGroup struct {
	WorkDir       string    `json:"workDir"`
	ActiveCount   int       `json:"activeCount"`
	ArchivedCount int       `json:"archivedCount"`
	LastMessageAt time.Time `json:"lastMessageAt"`
}

// ForkTitleSuffix is appended to the source title so a fork is recognizable in the rail from turn
// zero. A starting name, not an auto-title — AutoTitled stays false on a fork.
//
// ForkTitleSuffix 追加在源标题后，使分叉在 rail 里从第 0 轮起就可辨。它是起步名、非自动命名——
// 分叉的 AutoTitled 恒 false。
const ForkTitleSuffix = " (fork)"

// ForkInput is the head half of a fork. The message rows are chat's half (it owns them), so the
// two meet here: chat resolves the prefix window and decides whether the source's compaction
// summary is still truthful for that prefix, conversation writes the head row.
//
// Summary / SummaryCoversUpToSeq are the CARRY decision already made by the caller — empty + 0
// means "do not carry" (the prefix ends before the summary's coverage, so inheriting it would
// describe turns the fork does not contain). SummaryCoversUpToSeq is expressed in the FORK's own
// block numbering (blocks are renumbered from 1), not the source's.
//
// ForkInput 是分叉的「头」半。消息行是 chat 的半（它拥有消息），故两半在此交汇：chat 定前缀窗、
// 判源的压缩摘要对该前缀是否仍然诚实，conversation 写头行。
//
// Summary / SummaryCoversUpToSeq 是调用方**已做好**的携带决定——空 + 0 即「不携带」（前缀止于摘要
// 覆盖线之前，继承它等于描述分叉根本没有的回合）。SummaryCoversUpToSeq 用**分叉自身**的 block 编号
// （block 从 1 重排），不是源的编号。
type ForkInput struct {
	Source               *Conversation
	AtMessageID          string
	Summary              string
	SummaryCoversUpToSeq int64
}

// ArchiveScope selects which archive states the conversation list returns. The zero value is
// ArchiveActive (active-only) — the common default. It is an explicit 3-state enum, NOT an
// overloaded *bool: the rail's "show archived" needs an ACTIVE+ARCHIVED-together mode that a
// nil/true/false pointer cannot express (and whose absence silently broke list_conversations'
// includeArchived). The store applies exactly one predicate per scope.
//
// ArchiveScope 选列表返回哪些归档态。零值 ArchiveActive（仅活跃）——常用默认。它是显式三态枚举、非
// 重载 *bool：rail 的「显示已归档」要一个**活跃+归档同列**的模式，nil/true/false 指针表达不了
// （其缺失正是 list_conversations 的 includeArchived 静默失效之因）。store 按每个 scope 套恰好一个谓词。
type ArchiveScope string

const (
	ArchiveActive   ArchiveScope = ""         // active only (default / zero value)
	ArchiveArchived ArchiveScope = "archived" // archived only
	ArchiveAll      ArchiveScope = "all"      // both active and archived (rail "show archived" — archived rows carry archived=true for the gray dot)
)

// ListFilter narrows the conversation list. Archive selects the archive scope (default ArchiveActive
// = active-only). Search is a case-insensitive title LIKE.
//
// ListFilter 收窄对话列表。Archive 选归档范围（默认 ArchiveActive = 仅活跃）。Search 是标题大小写不敏感 LIKE。
// ListSort selects the conversation list ordering (always pinned-first within each). Empty defaults
// to ListSortActivity. The keyset cursor tracks the chosen sort's column (activity/created walk a
// time key descending via Page; name walks the title string ascending + NOCASE via PageAsc) and the
// current pinned partition, so a page walk cannot lose unpinned rows after a multi-page pinned section.
// A client that switches sort or any list axis MUST drop its cursor (start a fresh page) — a cursor
// minted under a different query is meaningless.
//
// ListSort 选对话列表排序（每种都置顶优先）。空 = ListSortActivity。keyset 游标随所选排序的列走（activity/created
// 经 Page 走时间键降序；name 经 PageAsc 走 title 字符串升序 + NOCASE），并携带当前置顶分区，故置顶段跨页后
// 不会漏掉未置顶行。客户端切换排序或任一列表轴时**必须丢弃游标**（重新翻页）——另一查询铸出的游标没有意义。
type ListSort string

const (
	ListSortActivity ListSort = "activity" // pinned-first, then last_message_at DESC — "recently chatted" (default)
	ListSortCreated  ListSort = "created"  // pinned-first, then created_at DESC — "when opened"
	ListSortName     ListSort = "name"     // pinned-first, then title A–Z (case-insensitive) — "by name"
)

// PinScope selects which pin states the conversation list returns. The zero value PinAny is "both" — the
// long-standing default, so every caller that predates the rail's grouping keeps its exact behavior.
//
// It exists for ONE reason (WRK-077 WD1.5): the grouped rail renders the pinned threads in their own
// section and the residency groups underneath, and each thread must appear EXACTLY once. Without a pin
// filter, "all pinned threads" could only be recovered by assuming they all land on the first page of the
// unfiltered list — an assumption that a rail whose other axes are residency-filtered can no longer lean
// on, because a pinned thread living in a COLLAPSED group would never be fetched at all. So the pinned
// section gets its own exact query, and the residency axes ask for the unpinned complement.
//
// PinScope 选列表返回哪些置顶态。零值 PinAny = 两者皆返——长期以来的默认，故一切早于 rail 分组的调用方行为
// 逐字不变。
//
// 它的存在只为**一件**事（WRK-077 WD1.5）:分组后的 rail 把置顶线程渲在它们自己的段里、驻地组在其下，而每条
// 线程必须**恰好出现一次**。没有置顶过滤时，「所有置顶线程」只能靠「它们都落在未过滤列表的首页」这个假定去
// 复原——而一个其余各轴都按驻地过滤的 rail **再也**靠不住它了:住在一个**收起**的组里的置顶线程根本不会被取
// 回来。故置顶段拿到它自己的精确查询，驻地各轴则要那个未置顶的补集。
type PinScope string

const (
	PinAny      PinScope = ""         // pinned + unpinned (default / zero value)
	PinPinned   PinScope = "pinned"   // pinned only — the rail's Pinned section
	PinUnpinned PinScope = "unpinned" // unpinned only — the rail's residency groups + Recents
)

type ListFilter struct {
	Cursor  string
	Limit   int
	Search  string
	Archive ArchiveScope // "" → ArchiveActive (active only)
	Sort    ListSort     // "" → ListSortActivity
	Pinned  PinScope     // "" → PinAny (both)

	// WorkDir is the RESIDENCY filter, and it is a PLAIN POINTER precisely because it needs three states
	// that no string alone can express: nil = no filter at all (every conversation, the pre-WD1.5 default),
	// &"" = ONLY the unmounted ones (the rail's Recents section — the threads that live in no directory),
	// &path = only that residency (one rail group, paged on its own). The middle state is the reason for the
	// pointer: `""` is a MEANINGFUL filter value here, not the absence of one.
	//
	// WorkDir 是**驻地**过滤，且它之所以是**朴素指针**，恰因它需要三个状态、而单个字符串表达不了:nil = 完全
	// 不过滤（每条对话，WD1.5 之前的默认）、&"" = **仅未挂**的那些（rail 的「最近」段——不住在任何目录里的
	// 线程）、&path = 仅该驻地（一个 rail 组，自行翻页）。中间那一态正是要指针的原因:`""` 在这里是一个**有意义
	// 的过滤值**、不是「没有过滤」。
	WorkDir *string
}

// UpdateInput is the PATCH payload; a nil field is left unchanged. ModelOverride is a
// pointer-to-pointer for tristate: nil = leave, &nil = clear, &(&ref) = set.
//
// UpdateInput 是 PATCH 载荷；nil 字段不动。ModelOverride 是指针的指针以表三态：nil = 不变、
// &nil = 清除、&(&ref) = 设置。
type UpdateInput struct {
	Title             *string
	SystemPrompt      *string
	AttachedDocuments *[]documentdomain.AttachedDocument
	Archived          *bool
	Pinned            *bool
	ModelOverride     **modeldomain.ModelRef
	// WorkDir is a PLAIN pointer, not the tristate ModelOverride needs: the column's own empty value
	// already means "not mounted", so `""` IS the clear and there is no third state to express.
	// (ModelOverride needs **T only because its cleared value is a nil struct pointer, not "".)
	//
	// WorkDir 是**朴素**指针、不是 ModelOverride 那种三态:该列自己的空值已经表示「未挂」,故 `""`
	// **就是**清除、没有第三种状态要表达。（ModelOverride 之所以要 **T,只因它清除后的值是 nil 结构
	// 指针、而不是 ""。）
	WorkDir *string
}

var (
	// ErrNotFound: get/update/delete on an unknown (or soft-deleted) conversation.
	// ErrNotFound：对未知（或已软删）对话 get/update/delete。
	ErrNotFound = errorspkg.New(errorspkg.KindNotFound, "CONVERSATION_NOT_FOUND", "conversation not found")

	// ErrInvalidModelOverride: a set modelOverride is missing apiKeyId or modelId. Mirrors
	// agent — structural only; key existence is resolved (and may fail gracefully) at chat time.
	// ErrInvalidModelOverride：已设的 modelOverride 缺 apiKeyId 或 modelId。照 agent——仅结构；
	// key 存在性在 chat 时解析（可优雅失败）。
	ErrInvalidModelOverride = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_INVALID_MODEL_OVERRIDE", "invalid modelOverride (apiKeyId and modelId both required)")

	// ErrAttachedDocumentNotFound: a PATCH set attachedDocuments to include a doc id that does not
	// exist (mistyped or since-deleted). Rejected 422 at attach time with the missing ids in Details —
	// mirrors agent's eager knowledge-mount check, instead of silently accepting a dangling reference
	// that only surfaces as a render-time warning later (F168-M5; F167 render warning still backstops
	// old data not re-validated here).
	//
	// ErrAttachedDocumentNotFound：PATCH 把 attachedDocuments 设成含不存在的 doc id（拼错或已删）。attach
	// 时即 422、Details 带缺失 id——照 agent 的 eager knowledge 挂载校验，而非静默接受悬挂引用、只在后续渲染
	// 时才警告（F168-M5；F167 渲染警告仍兜底此处不回溯校验的老数据）。
	ErrAttachedDocumentNotFound = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_ATTACHED_DOC_NOT_FOUND", "conversation attaches a document that does not exist")

	// ErrInvalidWorkDir: a non-empty workDir that fspath.Expand cannot turn into an absolute path.
	// This is the one validation the residency needs and it is PHYSICAL, not theater (设计原则 #6): a
	// relative root cannot root anything — every relative path resolved against it would come out
	// relative too and be refused later by PathGuard, leaving the thread carrying a residency that
	// silently does nothing. Existence is deliberately NOT checked: a directory that has since been
	// moved or deleted is a legitimate, renderable state (WorkDirInfo.Exists=false), so demanding it at
	// write time would reject an honest mount for a condition that can change a second later. The
	// generic FSPATH_* primitive is translated here per the error-code convention.
	//
	// ErrInvalidWorkDir:非空 workDir 而 fspath.Expand 无法把它变成绝对路径。这是驻地唯一需要的校验,
	// 且它是**物理**的、非校验剧场（设计原则 #6）:相对的根扎不住任何东西——以它解析出的每个相对路径
	// 仍是相对的、随后会被 PathGuard 拒掉,于是线程带着一个**静默无效**的驻地。**刻意不校验存在性**:
	// 已被移走或删掉的目录是合法且可渲染的状态（WorkDirInfo.Exists=false）,在写时强求它等于为一个
	// 下一秒就可能改变的条件拒掉一次诚实的挂载。按错误码约定,泛型 FSPATH_* 原语在此翻成具体码。
	ErrInvalidWorkDir = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_INVALID_WORK_DIR", "invalid workDir (must be an absolute path, or empty to unmount)")

	// ErrWorkDirNotGitRepo: a git action (switch / create branch / add worktree — WD2+WD3) was asked of a
	// residency that is not a git repository — including a residency that is unmounted, gone, or a host
	// with no `git` binary. The READ side answers `isGitRepo=false` for all of those and that is right (a
	// menu simply hides its git segment), but a WRITE has to say so out loud: the user asked for a change
	// and it did not happen.
	//
	// ErrWorkDirNotGitRepo:对一个**不是** git 仓库的驻地要求了一个 git 动作（切/建分支、加 worktree——
	// WD2+WD3）——含驻地未挂、已消失、或本机没有 `git` 二进制。**读**侧对这些一律答 `isGitRepo=false`、
	// 那是对的（菜单只是不渲 git 段），但一次**写**必须大声说出来:用户要求了一次改动，而它没有发生。
	ErrWorkDirNotGitRepo = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_WORK_DIR_NOT_GIT_REPO", "the conversation's working directory is not a git repository")

	// ErrWorkDirDirty: the residency has uncommitted changes and the requested action was switching to an
	// EXISTING branch — WD2's guardrail, and the batch's one real decision (legislated in
	// `references/backend/domains/conversation.md`).
	//
	// The choice is REFUSE — not "let git decide", not "stash it for you". Git's own behaviour is to carry
	// uncommitted work across when it can and refuse when it collides, which means the SURPRISING outcome
	// (your work now sits on a branch you did not think it was on) is the SUCCESS path, silently. For a
	// residency an agent is mid-task in that is worse than an error: the branch named in the system prompt
	// changed AND the work moved with it. Stashing is refused for the reason the brief gives — a silent
	// stash is how work disappears, and owning the stash lifecycle (who pops it, what happens on conflict)
	// is exactly the mini git client this feature is not. Refusing is the only option that cannot lose a
	// single line: nothing is moved, nothing is forced, nothing is hidden, and the next step is in the
	// message.
	//
	// CREATING a branch is deliberately not gated by this — it starts at the current HEAD, so the work tree
	// does not change by a byte and no conflict can exist (see gitinfo.CreateBranch).
	//
	// ErrWorkDirDirty:驻地有未提交改动，而请求的动作是切到一条**已存在**的分支——WD2 的护栏，也是本批唯一
	// 真正的决定（立法在 `references/backend/domains/conversation.md`）。
	//
	// 选的是**拒绝**——不是「让 git 自己判」、不是「替你 stash」。git 自己的行为是能带过去就带、冲突才拒，
	// 这意味着那个**令人意外**的结局（你的活现在待在一条你以为不是的分支上）是**成功**路径、而且是静默的。
	// 对一个 agent 正在其中干活的驻地，那比一个错误更糟:system prompt 里点出的分支变了、活也跟着搬走了。
	// stash 被拒的理由如简报所言——静默 stash 正是活消失的方式，而承担 stash 的生命周期（谁 pop、冲突怎么办）
	// 恰恰就是本 feature 不做的那个迷你 git 客户端。拒绝是唯一一个连一行都丢不了的选项:什么都没搬、没强制、
	// 没藏起来，而下一步就写在消息里。
	//
	// **新建**分支刻意不受此门——它从当前 HEAD 起步，故工作树一个字节都不变、冲突不可能存在（见
	// gitinfo.CreateBranch）。
	ErrWorkDirDirty = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_WORK_DIR_DIRTY", "the working directory has uncommitted changes — commit or stash them, then switch branches")

	// ErrInvalidBranch: a branch name git will not accept (`git check-ref-format`), empty, or beginning
	// with `-`. Validated with git's own tool rather than a hand-rolled rule (原则 #8); the leading-dash
	// rule is ours, because a legal ref starting with `-` would be read as a FLAG by the next command.
	//
	// ErrInvalidBranch:git 不会接受的分支名（`git check-ref-format`）、空、或以 `-` 开头。用 git 自己的工具
	// 校验、不手搓规则（原则 #8）;前导 `-` 那条是我们加的——一个以 `-` 开头的合法 ref 会被下一条命令读成**选项**。
	ErrInvalidBranch = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_INVALID_BRANCH", "invalid branch name (git check-ref-format refused it)")

	// ErrBranchNotFound: the switch target has no local branch. Asked BEFORE the checkout so the answer is
	// this rather than git's prose — and so `git checkout`'s DWIM can never quietly turn a typo into a new
	// remote-tracking branch.
	//
	// ErrBranchNotFound:切换目标没有对应的本地分支。在 checkout **之前**问，故答案是这一条、不是 git 的散文
	// ——也使 `git checkout` 的 DWIM 永不可能把一个拼错悄悄变成一条新的远端跟踪分支。
	ErrBranchNotFound = errorspkg.New(errorspkg.KindNotFound, "CONVERSATION_BRANCH_NOT_FOUND", "no local branch by that name")

	// ErrBranchExists: creating a branch that is already there. A CONFLICT rather than a silent switch —
	// «new branch» and «switch to the branch that happens to have this name» are different intents, and
	// quietly performing the second is how a user lands on somebody else's work.
	//
	// ErrBranchExists:要新建的分支已经存在。是**冲突**、不是静默切过去——「新建分支」与「切到恰好叫这个名字
	// 的分支」是两种不同意图，静默执行后者正是用户落到别人的活上面的方式。
	ErrBranchExists = errorspkg.New(errorspkg.KindConflict, "CONVERSATION_BRANCH_EXISTS", "a branch by that name already exists")

	// ErrInvalidWorktreeName: the worktree name cannot be BOTH one directory segment and a branch under
	// `wt/`. Stricter than a branch name because the name becomes a DIRECTORY too, and that strictness is
	// what keeps the derived path provably a sibling of the repository (see gitinfo.ValidWorktreeName).
	//
	// ErrInvalidWorktreeName:worktree 名无法**同时**做一个目录段与 `wt/` 下的一条分支。比分支名更严，因为这个
	// 名字**也会**成为一个目录，而正是这份更严让派生出的路径可证明地落在仓库的兄弟位置（见
	// gitinfo.ValidWorktreeName）。
	ErrInvalidWorktreeName = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_INVALID_WORKTREE_NAME", "invalid worktree name (must be one path segment usable as a branch name)")

	// ErrWorktreeExists: the sibling directory the convention derives is already taken. Reported rather
	// than reused, because a directory that is already there holds somebody's work — possibly another
	// session's — and adopting it silently is how two agents end up editing one tree, the very accident the
	// worktree discipline exists to prevent.
	//
	// ErrWorktreeExists:约定派生出的那个兄弟目录已被占用。上报、不复用，因为一个已经在那里的目录装着某人的
	// 活——可能是另一个会话的——而静默接管它正是两个 agent 编辑同一棵树的方式，也正是 worktree 纪律所要防的
	// 那场事故。
	ErrWorktreeExists = errorspkg.New(errorspkg.KindConflict, "CONVERSATION_WORKTREE_EXISTS", "that worktree directory already exists")

	// ErrGitFailed: git itself refused, for a reason this layer did not pre-check. Details carries git's
	// VERBATIM stderr under `git`. The honest catch-all: the alternatives are inventing a sentinel per git
	// message (an endless, always-incomplete table) or swallowing the reason — and git's own sentence is the
	// most useful one anybody has about why a checkout or a worktree add refused.
	//
	// ErrGitFailed:git 自己拒了，理由是本层没有预检的那些。Details 在 `git` 键下带 git 的**逐字** stderr。
	// 诚实的兜底:另两种选择是「为每条 git 消息铸一个 sentinel」（一张无穷且永远不全的表）或「把理由吞掉」——
	// 而关于「一次 checkout 或 worktree add 为何被拒」，git 自己那句话是所有人手上最有用的一句。
	ErrGitFailed = errorspkg.New(errorspkg.KindUnprocessable, "CONVERSATION_GIT_FAILED", "git refused the operation")
)

// Repository is the storage contract; workspace isolation + soft-delete are applied by the
// orm layer from ctx, so methods take no workspace id and List excludes tombstones.
//
// Repository 是存储契约；workspace 隔离 + 软删由 orm 层据 ctx 施加，故方法不带 workspace id、
// List 自动排除墓碑。
type Repository interface {
	Insert(ctx context.Context, c *Conversation) error
	Get(ctx context.Context, id string) (*Conversation, error)
	GetBatch(ctx context.Context, ids []string) ([]*Conversation, error)
	List(ctx context.Context, filter ListFilter) (items []*Conversation, next string, err error)
	// Count returns the exact number of live conversations matching the same axes as List.
	// Count 返回与 List 使用同一过滤轴的存活对话精确总数。
	Count(ctx context.Context, filter ListFilter) (int, error)
	Update(ctx context.Context, c *Conversation) error
	// TouchLastMessage sets last_message_at AND the unread flag on one conversation (chat calls it when a
	// message lands) — a single cheap UPDATE carrying recency + the unread bit atomically; the ORM
	// ,updated tag also bumps updated_at. `unread` is the new unread state: false on the user's own send
	// (sending is seeing), true on a COMPLETED assistant finalize (a reply to read), false on a
	// non-completed terminal.
	//
	// TouchLastMessage 把某对话的 last_message_at 与 unread 标志一并设（chat 在消息落地时调）——一次廉价 UPDATE
	// 原子带 recency + 未读位；ORM ,updated tag 顺带刷 updated_at。unread 是新未读态：用户自己发送时 false（发即是看）、
	// assistant **完成**终态时 true（有回复待读）、非完成终态时 false。
	TouchLastMessage(ctx context.Context, id string, t time.Time, unread bool) error
	// MarkSeen clears the unread flag (the :seen action — the user opened the thread without sending).
	// A single focused UPDATE on the unread column only; idempotent (a no-op on an unknown id returns
	// nil). Does NOT touch last_message_at, so opening a thread never reorders the activity list.
	//
	// MarkSeen 清 unread 标志（:seen 动作——用户没发消息、只是打开了线程）。只针对 unread 列的聚焦 UPDATE；幂等
	// （未知 id 上 no-op 返 nil）。不动 last_message_at，故打开线程绝不重排活跃列表。
	MarkSeen(ctx context.Context, id string) error
	SoftDelete(ctx context.Context, id string) error

	// WorkDirGroups aggregates the workspace's UNPINNED conversations by their residency — one row per
	// distinct non-empty work_dir, ordered most-recently-active first. A single GROUP BY over the whole
	// workspace, which is the whole point: the numbers must not depend on how far the rail has scrolled.
	// A residency with no unpinned threads left simply is not in the result (no empty groups to manage).
	//
	// WorkDirGroups 把本 workspace 的**未置顶**对话按驻地聚合——每个不同的非空 work_dir 一行、按最近活跃降序。
	// 对整个 workspace 一次 GROUP BY，而这正是要点:那些数字不该取决于 rail 滚了多远。已无未置顶线程的驻地
	// 干脆不出现在结果里（没有空组要管理）。
	WorkDirGroups(ctx context.Context) ([]WorkDirGroup, error)

	// ArchiveWorkDir archives every UNPINNED, not-yet-archived conversation of one residency in ONE
	// statement inside ONE transaction, and returns the ids it actually flipped (already-archived rows are
	// excluded, so the count never overstates what changed and the caller emits no echo for a no-op).
	//
	// SoftDeleteWorkDir soft-deletes every UNPINNED conversation of one residency the same way — ACROSS
	// archive states, because a destructive action must not silently depend on which view toggle happens to
	// be on. It stamps `deleted_at` on the conversation rows and NOTHING else: `messages` /
	// `message_blocks` are D1 Log tables and are never touched, here or anywhere.
	//
	// Both read the id set and write in the SAME transaction: the returned ids are exactly the rows the
	// statement changed, so a caller cascading per-row side effects (cancel generation, purge edges, purge
	// the touchpoint ledger) can never act on a row that was not in fact written — and a mid-write failure
	// leaves NO half-archived / half-deleted group.
	//
	// ArchiveWorkDir 在**一个**事务里用**一条**语句归档某驻地下每一条**未置顶、尚未归档**的对话，并返回它
	// 真正翻动的 id（已归档的行被排除，故计数绝不夸大改了什么、调用方也不为 no-op 发回声）。
	//
	// SoftDeleteWorkDir 以同样方式软删某驻地下每一条**未置顶**对话——**跨归档态**，因为一个破坏性动作不该
	// 静默地取决于哪个视图开关正好开着。它只在**对话行**上盖 `deleted_at`、别的什么都不动:`messages` /
	// `message_blocks` 是 D1 Log 表，此处与任何别处都绝不碰它们。
	//
	// 两者都在**同一**事务里读 id 集并写:返回的 id 恰是该语句改动的那些行，故调用方逐行级联的副作用（停生成、
	// 清 relation 边、清触点台账）绝不可能作用在一条其实没被写的行上——而中途失败**不留**半归档 / 半删除的组。
	ArchiveWorkDir(ctx context.Context, workDir string) ([]string, error)
	SoftDeleteWorkDir(ctx context.Context, workDir string) ([]string, error)
}
