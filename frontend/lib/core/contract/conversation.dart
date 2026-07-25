import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

/// A chat-thread container — the backend projection of `conversation.Conversation`, as the rail and
/// ocean see it on the wire (camelCase ↔ json_serializable, no rename maps; mirrors `references/`).
/// This is the list-row + identity shape plus the per-thread [modelOverride] the ocean head edits; the
/// heavier thread config (systemPrompt / attachedDocuments / summary) is added when that surface lands —
/// json_serializable simply ignores those wire keys until then.
///
/// Three flags are SYSTEM-WRITE / wire-read-only (never sent in PATCH), each driving a rail status
/// dot: [isGenerating] (an assistant turn is in flight → blue pulse), [awaitingInput] (≥1 pending
/// human-in-loop interaction → amber), [hasUnread] (a completed reply not yet seen → green). The first
/// two are derived server-side per request; [hasUnread] is a persisted column. [archived] drives the
/// gray "archived" marker when the rail shows archived threads.
///
/// 对话线程容器——后端 `conversation.Conversation` 的投影,rail/ocean 在线缆上所见(camelCase ↔
/// json_serializable、无重命名表;镜像 references/)。= rail 的「列表行 + 身份」形状 + ocean 头编辑的线程级
/// [modelOverride];更重配置(systemPrompt / attachedDocuments / summary)待其表面落地再加——在此之前
/// json_serializable 直接忽略那些线缆键。三个标志系统写、线缆只读(不进 PATCH),各驱动一个 rail 状态点:
/// isGenerating(在途 assistant 回合→蓝呼吸)、awaitingInput(≥1 待决人在环→琥珀)、hasUnread(完成的回复未看→绿)。
/// 前两个服务端逐请求派生;hasUnread 是持久列。archived 在 rail 显归档时驱动灰色标记。
///
/// [forkedFromConversationId] / [forkedFromMessageId] are the fork lineage (`POST /{id}:fork`): the
/// source thread and the message its prefix copy stopped at. Written once server-side and never
/// updated — a fork IS a new thread, so the pair is PROVENANCE, not a live link: the source may
/// later be deleted, and the head's lineage line then simply does not render. Both empty = an
/// ordinary thread. System-write, wire read-only.
///
/// forkedFromConversationId / forkedFromMessageId 是分叉血缘(`POST /{id}:fork`):源线程 + 前缀复制停在
/// 的那条消息。服务端一次写定、永不更新——分叉**是**新线程,故这对 id 是**溯源**、非活链接:源日后可被删,
/// 届时头部血缘行只是不渲。两者皆空 = 普通线程。系统写、线缆只读。
///
/// [workDir] is the thread's optional RESIDENCY: an absolute directory the agent is zoomed in on. Empty =
/// not mounted, the default. Unlike the flags above it is USER-EDITABLE and rides the PATCH surface next to
/// [modelOverride] — but as a PLAIN string, not a tristate: the column's empty value already means
/// "unmounted", so `''` IS the clear. Mounted, it does three things server-side (relative paths resolve
/// against it, Bash runs in it, the system prompt names it) and one thing client-side: the breadcrumb's
/// folder button. It is NOT a sandbox — reads outside are untouched, only writes outside ask for
/// confirmation. Whether the directory still EXISTS is not on this row: that is the live projection
/// ([WorkDirInfo], `GET /{id}/workdir`), because the answer changes without the row changing.
///
/// workDir 是线程可选的**驻地**:agent 已 zoom in 的一个绝对目录。空 = 未挂(默认)。不同于上面那些标志,它
/// **用户可改**、与 modelOverride 并列走 PATCH 面——但是**朴素字符串**、不是三态:该列的空值已表示「未挂」,故
/// `''` **就是**清除。挂上后它在服务端做三件事(相对路径以它解析、Bash 在它里面跑、system prompt 点出它),在
/// 客户端做一件事:面包屑那个文件夹按钮。它**不是**沙箱——往外读分毫不受影响,只有往外写才要确认。目录**是否
/// 还在**不在这一行上:那是活投影([WorkDirInfo],`GET /{id}/workdir`),因为那个答案会在行不变的情况下改变。
@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    @Default('') String title,
    @Default(false) bool autoTitled,
    @Default(false) bool archived,
    @Default(false) bool pinned,
    ModelRef? modelOverride,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime lastMessageAt,
    @Default(false) bool isGenerating,
    @Default(false) bool awaitingInput,
    @Default(false) bool hasUnread,
    @Default('') String forkedFromConversationId,
    @Default('') String forkedFromMessageId,
    @Default('') String workDir,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}

/// A model selection — the backend `model.ModelRef` {apiKeyId, modelId}: which credential serves it +
/// which model. Null on a conversation = no per-thread override (the workspace's dialogue default runs).
/// The PATCH is tristate: send a ref to set, an EXPLICIT null to clear (an absent key = unchanged).
///
/// 模型选择——后端 `model.ModelRef`(apiKeyId + modelId:哪个凭证 + 哪个模型)。会话上 null=无线程级覆写
/// (走 workspace 对话默认)。PATCH 三态:传 ref=设、显式 null=清(缺键=不动)。
@freezed
abstract class ModelRef with _$ModelRef {
  const factory ModelRef({
    @Default('') String apiKeyId,
    @Default('') String modelId,
  }) = _ModelRef;

  factory ModelRef.fromJson(Map<String, dynamic> json) =>
      _$ModelRefFromJson(json);
}

/// ONE residency group of the chat rail — `GET /conversations/workdir-groups`, mirroring
/// `conversation.WorkDirGroup`. A PROJECTION, not an entity: no table, no id, no lifecycle. A group exists
/// exactly as long as some UNPINNED thread carries that [workDir], and the last one leaving makes it vanish
/// on its own — so there is no "empty group" state to render or manage.
///
/// It comes from the server rather than being grouped client-side because the rail pages FOREVER: grouping
/// one loaded window would make membership and counts DRIFT as you scroll — the head would state a number
/// that changes while nothing about the workspace changed.
///
/// [activeCount] / [archivedCount] are reported separately so the endpoint takes NO parameters: the rail's
/// "show archived" toggle picks or sums them for the head, and a bulk action (deliberately blind to that
/// toggle — a destructive action must not depend on a view preference) inventories the SUM. Pinned threads
/// are in NEITHER count: they render in the rail's own Pinned section and must appear exactly once, and the
/// two bulk actions skip them too, which is what lets one number head the group AND inventory its confirm
/// dialog. [lastMessageAt] spans both archive states, so toggling the view never reorders the groups.
///
/// chat 左岛的**一个**驻地组——`GET /conversations/workdir-groups`,镜像 `conversation.WorkDirGroup`。它是
/// **投影、不是实体**:无表、无 id、无生命周期。一个组存在的时长恰好等于「还有**未置顶**线程带着那个 [workDir]」,
/// 最后一个离开它就自行消失——故没有「空组」态要渲、也没有要管理的。
///
/// 它来自服务端、而不是在客户端分组,因为 rail 是**无限**翻页的:对一个已加载窗做分组会让成员与计数随滚动**漂移**
/// ——组头会报出一个在 workspace 什么都没变时自己会变的数。
///
/// [activeCount] / [archivedCount] **分开**上报,使该端点**不收任何参数**:rail 的「显示已归档」开关自行取其一或
/// 求和作组头,而批量动作（**刻意对那个开关盲**——破坏性动作不该取决于一个视图偏好）盘点二者之**和**。置顶线程
/// **两个计数都不含**:它们渲在 rail 自己的置顶段、必须恰好出现一次,而两个批量动作同样跳过它们——正是这一点让
/// **一个**数既作组头、又作它的确认框盘点。[lastMessageAt] 跨两种归档态,故切换视图绝不重排组序。
@freezed
abstract class WorkDirGroup with _$WorkDirGroup {
  const factory WorkDirGroup({
    @Default('') String workDir,
    @Default(0) int activeCount,
    @Default(0) int archivedCount,
    required DateTime lastMessageAt,
  }) = _WorkDirGroup;

  factory WorkDirGroup.fromJson(Map<String, dynamic> json) =>
      _$WorkDirGroupFromJson(json);
}

/// The residency's LIVE projection — `GET /conversations/{id}/workdir`, mirroring
/// `conversation.WorkDirInfo`. Recomputed per request and cached nowhere: the filesystem and git ARE the
/// truth, so a directory the user just deleted, or a branch they just switched in their own terminal, reads
/// as it now is. This is why the folder button's three states can be honest.
///
/// [path] echoes the row's column so one read serves the whole menu. [exists] false with a non-empty
/// [path] is the WARNING state (mounted, then moved or deleted) — a real thing to render, not an error.
/// [branch] / [dirty] / [branches] / [worktrees] are meaningful only when [isGitRepo].
///
/// [branches] and [worktrees] (WD2 / WD3) are what make the menu's git segment ACTIONABLE rather than a
/// read-out — you cannot offer to switch to a branch you never listed. Both stay cursor-free because both are
/// BOUNDED: [branches] is `refs/heads` only (the branches this person created; a fetched `refs/remotes` is the
/// set that runs to thousands), and [worktrees] is however many checkouts exist — the current one INCLUDED and
/// flagged, since the honest answer to "which worktrees does this repo have" contains the one you stand in.
///
/// 驻地的**活投影**——`GET /conversations/{id}/workdir`,镜像 `conversation.WorkDirInfo`。逐请求现算、零缓存:
/// 文件系统与 git **就是**真相,故用户刚删掉的目录、或刚在自己终端里切的分支,读作它**现在的样子**。这正是那个
/// 文件夹按钮的三态能够诚实的原因。
///
/// path 回显行上那一列,使一次读服务整个菜单。path 非空而 exists 为 false 是**警示**态(挂过、然后被移走或删了)
/// ——那是要渲的真实状态、不是错误。branch / dirty / branches / worktrees 仅在 isGitRepo 时有意义。
///
/// branches 与 worktrees（WD2 / WD3）正是让菜单 git 段**可操作**、而非一段读数的东西——没列出来的分支无从提议切
/// 过去。两者都无游标,因为两者都**有界**:branches **只**取 `refs/heads`（这个人自己建的那些分支;会跑到上千条的是
/// fetch 来的 `refs/remotes`）,worktrees 则是实际存在多少份 checkout 就多少条——**含**当前那一份并标出它,因为
/// 「这个仓库有哪些 worktree」的诚实答案包含你正站着的那一份。
@freezed
abstract class WorkDirInfo with _$WorkDirInfo {
  const factory WorkDirInfo({
    @Default('') String path,
    @Default(false) bool exists,
    @Default(false) bool isGitRepo,
    @Default('') String branch,
    @Default(false) bool dirty,
    @Default(<String>[]) List<String> branches,
    @Default(<WorkTreeInfo>[]) List<WorkTreeInfo> worktrees,
  }) = _WorkDirInfo;

  factory WorkDirInfo.fromJson(Map<String, dynamic> json) =>
      _$WorkDirInfoFromJson(json);
}

/// ONE parallel checkout of the residency's repository (WD3) — mirrors `conversation.WorkTreeInfo`: where it
/// lives, which branch it has out ([branch] empty = detached), and whether it is the one this conversation is
/// mounted on.
///
/// It carries no id and no lifecycle for the same reason [WorkDirGroup] does not: a worktree exists exactly as
/// long as git says it does, and the truth is `git worktree list` — not a table. [current] is decided
/// SERVER-side against the work tree's ROOT, so a residency mounted on a SUBDIRECTORY still knows which
/// worktree it stands in and the menu never offers a switch to where the user already is.
///
/// 驻地所在仓库的**一份**平行 checkout（WD3）——镜像 `conversation.WorkTreeInfo`:它在哪、出着哪条分支（branch 空 =
/// detached）、以及它是不是本对话所挂的那一份。
///
/// 它没有 id、没有生命周期,理由与 WorkDirGroup 相同:一个 worktree 存在的时长恰好等于 git 说它存在的时长,而真相是
/// `git worktree list`——不是某张表。current 在**服务端**拿工作树的**根**判定,故挂在**子目录**上的驻地依然知道自己
/// 站在哪一份里,菜单也就绝不会提议切到用户已经在的地方。
@freezed
abstract class WorkTreeInfo with _$WorkTreeInfo {
  const factory WorkTreeInfo({
    @Default('') String path,
    @Default('') String branch,
    @Default(false) bool current,
  }) = _WorkTreeInfo;

  factory WorkTreeInfo.fromJson(Map<String, dynamic> json) =>
      _$WorkTreeInfoFromJson(json);
}
