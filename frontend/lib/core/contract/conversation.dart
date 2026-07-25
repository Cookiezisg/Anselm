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

/// The residency's LIVE projection — `GET /conversations/{id}/workdir`, mirroring
/// `conversation.WorkDirInfo`. Recomputed per request and cached nowhere: the filesystem and git ARE the
/// truth, so a directory the user just deleted, or a branch they just switched in their own terminal, reads
/// as it now is. This is why the folder button's three states can be honest.
///
/// [path] echoes the row's column so one read serves the whole menu. [exists] false with a non-empty
/// [path] is the WARNING state (mounted, then moved or deleted) — a real thing to render, not an error.
/// [branch] / [dirty] are meaningful only when [isGitRepo]; WD1 shows them READ-ONLY (switching branches is
/// WD2, worktrees WD3).
///
/// 驻地的**活投影**——`GET /conversations/{id}/workdir`,镜像 `conversation.WorkDirInfo`。逐请求现算、零缓存:
/// 文件系统与 git **就是**真相,故用户刚删掉的目录、或刚在自己终端里切的分支,读作它**现在的样子**。这正是那个
/// 文件夹按钮的三态能够诚实的原因。
///
/// path 回显行上那一列,使一次读服务整个菜单。path 非空而 exists 为 false 是**警示**态(挂过、然后被移走或删了)
/// ——那是要渲的真实状态、不是错误。branch / dirty 仅在 isGitRepo 时有意义;WD1 **只读**地显示它们(切分支归
/// WD2、worktree 归 WD3)。
@freezed
abstract class WorkDirInfo with _$WorkDirInfo {
  const factory WorkDirInfo({
    @Default('') String path,
    @Default(false) bool exists,
    @Default(false) bool isGitRepo,
    @Default('') String branch,
    @Default(false) bool dirty,
  }) = _WorkDirInfo;

  factory WorkDirInfo.fromJson(Map<String, dynamic> json) =>
      _$WorkDirInfoFromJson(json);
}
