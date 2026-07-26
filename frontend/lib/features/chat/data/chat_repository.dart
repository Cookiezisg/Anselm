import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/contract/attachment.dart';
import '../../../core/contract/conversation.dart';
import '../../../core/contract/interaction.dart';
import '../../../core/contract/messages/chat_message.dart';
import '../../../core/contract/messages/transcript_nav.dart';
import '../../../core/contract/mcp.dart';
import '../../../core/contract/page.dart';
import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/approval.dart';
import '../../../core/contract/entities/control.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/todo.dart';
import '../../../core/contract/touchpoint.dart';
import '../../../core/net/api_client.dart';
import '../../../core/sse/frame.dart';
import '../../../core/sse/sse_gateway.dart';
import 'conversation_signal.dart';
import 'turn_signal.dart';

@immutable
class AttachmentPlaybackLease {
  const AttachmentPlaybackLease({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;

  factory AttachmentPlaybackLease.fromJson(Map<String, dynamic> json) =>
      AttachmentPlaybackLease(
        url: (json['url'] as String?) ?? '',
        expiresAt:
            DateTime.tryParse((json['expiresAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// How the conversation list is ordered. Mirrors the backend's three sort values exactly (a sealed
/// closed set — the rail's sort menu offers only these). [wire] is the `?sort=` query value.
///
/// 对话列表排序。逐字镜像后端三个 sort 值(封闭集——rail 排序菜单只此三项)。[wire] 是 `?sort=` 值。
enum ConvSort {
  activity, // pinned-first, then most-recently-active (default)
  created, // pinned-first, then creation order
  name; // pinned-first, then title A–Z (case-insensitive)

  // this.name (the Enum.name string getter) — a bare `name` would resolve to the ConvSort.name VALUE.
  // this.name（Enum.name 字符串 getter）——裸 `name` 会解析成 ConvSort.name 这个枚举值。
  String get wire => this.name;
}

/// Which archive states the list returns. Mirrors the backend `ArchiveScope`: active-only (default),
/// archived-only, or all (active + archived together — the rail's "show archived" mode, where archived
/// rows carry archived=true for the gray dot). [wire] is the `?archived=` value (null = omit = active).
///
/// 列表返回哪些归档态。镜像后端 ArchiveScope:仅活跃(默认)/仅归档/全部(活跃+归档同列——rail「显示已归档」,归档行
/// 带 archived=true 供灰点)。[wire] 是 `?archived=` 值(null = 省略 = 活跃)。
enum ConvArchive {
  active, // active only (default)
  all, // active + archived together
  archivedOnly; // archived only

  String? get wire => switch (this) {
    ConvArchive.active => null,
    ConvArchive.all => 'all',
    ConvArchive.archivedOnly => 'true',
  };
}

/// Which pin states the list returns — the backend `?pinned=`. [any] omits the parameter (both, the
/// long-standing default); the grouped rail (WD1.5) asks for the two halves SEPARATELY so every thread
/// renders exactly once: the Pinned section is [pinnedOnly], the residency groups and Recents are
/// [unpinnedOnly].
///
/// 列表返回哪些置顶态——后端 `?pinned=`。[any] 省略该参数(两者,长期默认);分组后的 rail(WD1.5)**分别**取两半,
/// 使每条线程恰好渲一次:置顶段是 [pinnedOnly],驻地组与「最近」是 [unpinnedOnly]。
enum ConvPin {
  any,
  pinnedOnly,
  unpinnedOnly;

  String? get wire => switch (this) {
    ConvPin.any => null,
    ConvPin.pinnedOnly => 'true',
    ConvPin.unpinnedOnly => 'false',
  };
}

/// Which residency the list is confined to — the backend `?workDir=`, whose three states are read off the
/// KEY'S PRESENCE, not its value:
///
///   - [ConvWorkDir.any] — the key is absent: no residency filter at all (every conversation).
///   - [ConvWorkDir.unmounted] — the key is present and EMPTY (`?workDir=`): ONLY the threads that live in
///     no directory. This is the rail's Recents section, and it is why the filter cannot be a plain
///     nullable string: `''` here is a MEANINGFUL value, not the absence of one.
///   - [ConvWorkDir.of] — one residency, the rail's group axis. The path must be the STORED absolute one
///     (the value `GET /workdir-groups` handed back), because the backend compares it verbatim.
///
/// 列表被限定在哪个驻地——后端 `?workDir=`,其三态按**键是否出现**读、不按值读:[any] 键缺席=完全不按驻地过滤;
/// [unmounted] 键出现且为空(`?workDir=`)=**仅**不住在任何目录里的线程(rail 的「最近」段,也正是该过滤不能是
/// 可空裸字符串的原因:`''` 在此是一个**有意义的值**、不是「没有值」);[of] = 一个驻地(rail 的组轴,路径须是**存
/// 下来**的那个绝对路径——即 `GET /workdir-groups` 回的值,后端逐字比较)。
class ConvWorkDir {
  const ConvWorkDir._(this.path);

  /// One residency. 一个驻地。
  const ConvWorkDir.of(String path) : this._(path);

  /// No residency filter — the parameter is omitted entirely. 不过滤——参数完全省略。
  static const any = ConvWorkDir._(null);

  /// Only the unmounted threads — the parameter is sent EMPTY. 仅未挂——参数发空值。
  static const unmounted = ConvWorkDir._('');

  final String? path;

  /// null → omit the key; otherwise send it (possibly empty). null → 省略键;否则发出(可为空)。
  String? get wire => path;

  @override
  bool operator ==(Object other) => other is ConvWorkDir && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'ConvWorkDir(${path ?? 'any'})';
}

/// THE seam for the Chat feature's data access — every read/realtime/action the feature makes passes
/// through here, so the whole feature can be driven by one [FixtureChatRepository] override (no
/// per-provider HTTP/SSE mocking), exactly as the Entities feature does. [LiveChatRepository] wires the
/// Phase-4.0 pipeline (ApiClient); realtime + the per-thread message/action surface are added to this
/// interface as their build slices land (kept lean here — step 1 is the conversation LIST).
///
/// Chat feature 数据访问的唯一缝——feature 的每个读/实时/动作都过此,故整 feature 可被单个
/// FixtureChatRepository override 驱动(无 per-provider HTTP/SSE mock),与 Entities 同款。Live 接 Phase 4.0
/// 管道(ApiClient);实时与逐线程消息/动作面随各建造片落地再加(此处保持精简——step 1 = 对话列表)。
abstract interface class ChatRepository {
  /// One keyset page of the conversation list. [sort] / [archive] map to `?sort=` / `?archived=`;
  /// [search] is a case-insensitive title substring. Switching sort MUST drop the cursor (a cursor is
  /// meaningless under a different sort), so callers start a fresh page on sort change.
  ///
  /// 对话列表的一页 keyset。sort/archive 映射 `?sort=`/`?archived=`;search 是标题大小写不敏感子串。切换 sort
  /// 必须丢弃游标(跨 sort 游标无意义),故调用方切换排序时重新翻页。
  Future<Page<Conversation>> listConversations({
    String? cursor,
    int? limit,
    ConvSort sort,
    ConvArchive archive,
    String? search,
    ConvWorkDir workDir,
    ConvPin pinned,
  });

  /// The rail's residency GROUPING (`GET /conversations/workdir-groups`) — one row per directory some
  /// unpinned thread lives in, most-recently-active first. Bounded, uncursored, parameterless.
  ///
  /// It is a SERVER read rather than a client-side `groupBy` over the loaded rows for one reason: the rail
  /// pages forever, so grouping a window would make membership and counts drift as you scroll. The counts
  /// this returns are the whole workspace's, and they do not move when the user scrolls.
  ///
  /// rail 的驻地**分组**(`GET /conversations/workdir-groups`)——每个住着未置顶线程的目录一行、最近活跃在前。
  /// 有界、无游标、零参数。
  ///
  /// 它是**服务端**读、而不是对已加载行做客户端 `groupBy`，只为一个理由:rail 无限翻页，对一窗分组会让成员与
  /// 计数随滚动漂移。它返回的计数是**整个 workspace** 的，且用户滚动时它们不动。
  Future<List<WorkDirGroup>> workdirGroups();

  /// Archive a whole residency group in ONE request (`POST /conversations:archive-workdir`) → how many
  /// conversations actually CHANGED. Not a loop of N PATCHes: a loop can stop half-way, leaving a folder the
  /// user asked to file away neither filed nor unfiled.
  ///
  /// 一个请求归档整个驻地组(`POST /conversations:archive-workdir`)→ 真正**改变**了几条对话。不是 N 次 PATCH 的
  /// 循环:循环会半途停下，把用户要收起的一个文件夹留在既非收起也非未收起的状态。
  Future<int> archiveWorkDir(String workDir);

  /// Delete a whole residency group in ONE request (`POST /conversations:delete-workdir`) → how many
  /// conversations were deleted.
  ///
  /// It deletes CONVERSATIONS. Not the directory, not one file on disk, not one message row (messages are an
  /// append-only log with no delete). Pinned threads of that residency survive. This is exactly why the menu
  /// item that calls it says «delete all conversations» and never «delete the directory».
  ///
  /// 一个请求删除整个驻地组(`POST /conversations:delete-workdir`)→ 删了几条对话。
  ///
  /// 它删的是**对话**。不是那个目录、不是盘上任何一个文件、也不是任何一条消息行(消息是只追加的日志、没有删除)。
  /// 该驻地的置顶线程存活。这正是调用它的那个菜单项写作「删除全部对话」、而**绝不**写作「删除目录」的原因。
  Future<int> deleteWorkDir(String workDir);

  /// Rename a thread (`PATCH {title}`). Returns the authoritative updated object so the caller patches
  /// its list state from it (the initiator never waits on the SSE echo — notifications are for OTHER
  /// clients, and carry no echo suppression, so the list merge must be idempotent). One PATCH = one
  /// semantic field (the backend's `action` is otherwise undefined). 重命名,返权威对象供调用方 patch 列表(不等 SSE)。
  Future<Conversation> renameConversation(String id, String title);

  /// Mount / switch / unmount the thread's RESIDENCY (`PATCH {workDir}`). A PLAIN string, not the tristate
  /// [setModelOverride] needs: the column's empty value already means "unmounted", so `''` IS the clear and
  /// there is no third state to express. The path is normalized SERVER-side (`~` expanded, Cleaned), so the
  /// returned row — not the string that was sent — is the authoritative value to render.
  ///
  /// 挂 / 切换 / 退出线程**驻地**(`PATCH {workDir}`)。是**朴素**字符串、不是 setModelOverride 那种三态:该列的
  /// 空值已表示「未挂」,故 `''` **就是**清除、没有第三种状态要表达。路径在**服务端**归一化(展开 `~`、Clean),
  /// 故要渲的权威值是**返回的行**、不是发出去的那个字符串。
  Future<Conversation> setWorkDir(String id, String workDir);

  /// The residency's LIVE projection (`GET /{id}/workdir`): does the directory still exist, is it a git repo,
  /// which branch, any uncommitted work. Recomputed server-side per call and cached nowhere, so the folder
  /// button's three states stay honest — a directory the user deleted, or a branch they switched in their own
  /// terminal, shows as it now is. An UNMOUNTED thread answers successfully with the zero projection (empty
  /// path, exists=false), never a 404: the button has to render that state too.
  ///
  /// 驻地的**活投影**(`GET /{id}/workdir`):目录还在吗、是 git 仓库吗、哪个分支、有没有没提交的活。服务端逐次
  /// 现算、零缓存,故文件夹按钮的三态保持诚实——用户删掉的目录、或他在自己终端里切的分支,显示成它**现在的样子**。
  /// **未挂**线程以零投影(空路径、exists=false)**成功**作答、绝非 404:那个按钮也得渲染那一态。
  Future<WorkDirInfo> workDirInfo(String id);

  /// Switch the residency onto an EXISTING local branch (`POST /{id}/workdir:switch-branch {branch}`, WD2).
  /// Returns the re-probed projection, so the caller renders the new branch without a second read.
  ///
  /// THE GUARDRAIL lives server-side: a dirty work tree is refused 422 `CONVERSATION_WORK_DIR_DIRTY` and the
  /// message names the next step (commit or stash, then switch). Never `--force`, never a silent stash —
  /// carrying uncommitted work onto another branch behind the user's back is the outcome that must not happen.
  /// Other refusals: 404 `CONVERSATION_BRANCH_NOT_FOUND`, 422 `CONVERSATION_INVALID_BRANCH`, 422
  /// `CONVERSATION_WORK_DIR_NOT_GIT_REPO`, 422 `CONVERSATION_GIT_FAILED` (git's own stderr in `details.git`).
  ///
  /// 把驻地切到一条**已存在**的本地分支(`POST /{id}/workdir:switch-branch {branch}`,WD2)。返回重探后的投影,
  /// 故调用方无须第二次读就能渲出新分支。
  ///
  /// **护栏在服务端**:脏工作树拒为 422 `CONVERSATION_WORK_DIR_DIRTY`,message 点出下一步(先提交或贮藏,再切)。
  /// 绝不 `--force`、绝不静默 stash——在用户背后把未提交的活带到另一条分支上,正是不能发生的那个结局。其余拒绝:
  /// 404 `CONVERSATION_BRANCH_NOT_FOUND`、422 `CONVERSATION_INVALID_BRANCH`、422
  /// `CONVERSATION_WORK_DIR_NOT_GIT_REPO`、422 `CONVERSATION_GIT_FAILED`(git 自己的 stderr 在 `details.git`)。
  Future<WorkDirInfo> switchBranch(String id, String branch);

  /// Create a branch at the residency's current HEAD and switch onto it
  /// (`POST /{id}/workdir:create-branch {branch}`, WD2).
  ///
  /// A DIRTY work tree is deliberately fine here, unlike [switchBranch]: the new branch starts at the commit
  /// already checked out, so the work tree does not change and no conflict can exist — "I started, then
  /// realized this deserves its own branch" is the most common branching flow there is. An existing name is 409
  /// `CONVERSATION_BRANCH_EXISTS`.
  ///
  /// 在驻地当前 HEAD 上建一条分支并切过去(`POST /{id}/workdir:create-branch {branch}`,WD2)。
  ///
  /// 与 switchBranch 不同,此处脏工作树**刻意**无妨:新分支起点就是已 checkout 的那个 commit,故工作树不变、冲突不
  /// 可能存在——「先动手,然后意识到这该有自己的分支」是最常见的开分支流程。名字已存在 → 409
  /// `CONVERSATION_BRANCH_EXISTS`。
  Future<WorkDirInfo> createBranch(String id, String branch);

  /// Open a parallel worktree for this conversation and MOVE the residency into it — one request
  /// (`POST /{id}/workdir:add-worktree {name}`, WD3). Returns the projection of the NEW directory.
  ///
  /// A NAME, never a path: the target is DERIVED by the repository's `make worktree` convention (a SIBLING of
  /// the repo named `<repo>-<name>`, on branch `wt/<name>`), which is both why an app-made worktree is
  /// indistinguishable from a discipline-made one and why this can never write a checkout anywhere else. The
  /// thread also gains WD1's durable `marker` block, because its residency really moved. Refusals: 409
  /// `CONVERSATION_WORKTREE_EXISTS` (`details.path` names the directory in the way), 422
  /// `CONVERSATION_INVALID_WORKTREE_NAME`, 422 `CONVERSATION_WORK_DIR_NOT_GIT_REPO`, 422
  /// `CONVERSATION_GIT_FAILED`.
  ///
  /// 为本对话开一份平行 worktree 并把驻地**移进去**——**一次**请求(`POST /{id}/workdir:add-worktree {name}`,WD3)。
  /// 返回**新**目录的投影。
  ///
  /// 收**名字**、绝不收路径:目标按本仓 `make worktree` 约定**派生**(仓库的**兄弟**位、名为 `<repo>-<name>`、分支
  /// `wt/<name>`)——正是这一点既让 app 建的 worktree 与纪律建的无从区分,也让它永不可能往别处写出一份 checkout。
  /// 线程另会多一条 WD1 的持久 `marker` 块,因为它的驻地真的移动了。拒绝:409 `CONVERSATION_WORKTREE_EXISTS`
  /// (`details.path` 点出挡路的目录)、422 `CONVERSATION_INVALID_WORKTREE_NAME`、422
  /// `CONVERSATION_WORK_DIR_NOT_GIT_REPO`、422 `CONVERSATION_GIT_FAILED`。
  Future<WorkDirInfo> addWorktree(String id, String name);

  /// Pin / unpin (`PATCH {pinned}`). 置顶/取消(PATCH {pinned})。
  Future<Conversation> setPinned(String id, bool pinned);

  /// Archive / unarchive (`PATCH {archived}`). 归档/取消(PATCH {archived})。
  Future<Conversation> setArchived(String id, bool archived);

  /// Soft-delete (`DELETE` → 204, tombstoned server-side; the rail just drops the row). 软删(204)。
  Future<void> deleteConversation(String id);

  /// Fork a thread into a NEW conversation (`POST /{id}:fork {atMessageId?}` → 201). The prefix through
  /// [atMessageId] (INCLUSIVE) is copied — head config, message rows, blocks with seq renumbered and
  /// nesting remapped — and the source is untouched. A null [atMessageId] forks at the latest message
  /// (the rail entry, which holds no message id). Returns the authoritative new row so the caller folds
  /// it into the list state and navigates to it.
  ///
  /// 分叉成一条**新**对话(`POST /{id}:fork {atMessageId?}` → 201)。复制直到 atMessageId(**含它**)的前缀
  /// ——头配置、消息行、seq 重排 + 嵌套 remap 的 blocks——源分毫不动。atMessageId 为 null = 从**最新**消息
  /// 处分叉(左岛入口手上没有 message id)。返权威新行供调用方折进列表态并导航过去。
  Future<Conversation> forkConversation(String id, {String? atMessageId});

  /// Upload one attachment (`POST /attachments`, multipart field `file`, 50MB cap server-side) →
  /// the authoritative row (id goes into the send's attachmentIds). 上传附件(multipart `file`)→ 权威行。
  Future<AttachmentMeta> uploadAttachment({
    required List<int> bytes,
    required String filename,
    String? mimeType,
  });

  /// Delete an attachment (soft, 204) — the composer calls this when a pending chip is removed, so
  /// dangling uploads don't pile up (the backend has no GC). 软删附件——移除待发 chip 时调,防悬挂堆积。
  Future<void> deleteAttachment(String id);

  /// Cancel the app-managed media preparation sidecar for an attachment. This never deletes or blocks
  /// the attachment itself; it only stops background proxy/perception work.
  Future<AttachmentPreparation> cancelAttachmentPreparation(String id);

  /// Retry a failed/cancelled app-managed media preparation sidecar.
  Future<AttachmentPreparation> retryAttachmentPreparation(String id);

  /// One attachment's metadata (`GET /attachments/{id}`) — the bubble resolves filename/kind/size from
  /// the id-only `attrs.attachments` snapshot. 附件元数据——泡从纯 id 快照解析名/类/大小。
  Future<AttachmentMeta> getAttachment(String id);

  /// The raw bytes (`GET /attachments/{id}/content`, non-envelope) — image thumbnails decode from
  /// this; loopback-only, so per-image fetch is cheap. 原始字节(非 envelope)——图缩略图由此解码;loopback 便宜。
  Future<List<int>> getAttachmentBytes(String id);

  /// A short loopback playback URL for sent audio attachments. The mint request is authenticated, but
  /// the returned URL is an opaque short-lived lease because native audio players cannot attach bearer
  /// headers to their media fetch. 已发送音频附件的短期本机播放 URL。签发请求鉴权；返回 URL 靠 opaque 短租约，
  /// 因原生播放器无法给媒体请求加 bearer header。
  Future<AttachmentPlaybackLease> createAttachmentPlaybackLease(String id);

  /// A single conversation by id (`GET /{id}`) — the rail re-reads ONE row on a lifecycle signal it did
  /// not originate (auto-title, or a change from another window). 单取一条,供 rail 据非自身发起的信号重读一行。
  Future<Conversation> getConversation(String id);

  /// The conversation lifecycle signals off the notifications SSE stream (`conversation.<action>`). The
  /// list patches on `durable`, ignores ephemeral — created→insert, deleted→drop, everything else→re-read
  /// that row. Live is a projection over the gateway; the fixture scripts them. 对话生命周期信号(notifications)。
  Stream<ConversationSignal> lifecycleSignals();

  /// The 410 twin of [lifecycleSignals] — same stream, so every consumer of the signals must refetch on
  /// this (WRK-083 L7). A `SEQ_TOO_OLD` drops the cursor and reconnects at a fresh head: every signal in
  /// the gap is gone for good, and a list that only listens to the signals stays stale for the whole
  /// session. NOT [transcriptResync] — that one is the MESSAGES stream (activity dots).
  /// [lifecycleSignals] 的 410 孪生——同一条流,故信号的每个消费方都必须在它上面补取(WRK-083 L7)。
  /// `SEQ_TOO_OLD` 丢游标、从新 head 重连:缺口里的信号永远没了,只听信号的列表会陈旧到会话结束。
  /// **不是** [transcriptResync]——那条是 messages 流(活态点)。
  Stream<void> lifecycleResync();

  // ── the per-thread transcript surface 逐线程 transcript 面 ──

  /// Create a thread (`POST /conversations`, empty title — the backend auto-titles after turn 1). The
  /// landing's first send calls this, then [sendMessage]. 建线程(空标题,首回合后后端自动命名)。
  Future<Conversation> createConversation();

  /// One keyset page of turn history WITH blocks (`GET /{id}/messages`) — wire order is newest-first;
  /// hydration reverses to chronological. 回合历史一页(含 blocks);线缆新→旧,水化反转为时间序。
  Future<Page<ChatMessage>> listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
  });

  /// The deep-jump window (`GET /{id}/messages?around=<messageId>`): a newest-first slice centered
  /// on the target + both continuation cursors. The jump path REPLACES the transcript window with
  /// this (re-anchor) — never stitches. An unknown target surfaces the backend's 404 (identity
  /// anchoring). 深跳窗(?around=):以目标为中心的切片+双向游标;跳转径整窗替换、绝不缝合;未知目标 404。
  Future<MessagesWindow> messagesAround(
    String conversationId,
    String messageId, {
    int? limit,
  });

  /// One keyset page walking FORWARD in time (`GET /{id}/messages?dir=newer&cursor=`) — the window's
  /// newerCursor continuation; data stays newest-first (the wire's single ordering rule).
  /// 沿时间向前的一页(?dir=newer);data 恒新→旧(线缆唯一排序规则)。
  Future<Page<ChatMessage>> listMessagesNewer(
    String conversationId, {
    required String cursor,
    int? limit,
  });

  /// One keyset page of navigation anchors (`GET /{id}/anchors`, newest-first) — the 场次条 source:
  /// user turns / folded tool clusters / dangerous calls / compaction marks / abnormal terminals;
  /// pending gates ride the first page's top outside the keyset. 场次条锚点一页(最新在前)。
  Future<Page<TranscriptAnchor>> listAnchors(
    String conversationId, {
    String? cursor,
    int? limit,
  });

  /// Send a user turn (`POST /{id}/messages` → 202): lands the user message, opens the assistant turn,
  /// enqueues the run; returns the ASSISTANT message id. [mentions] are `{type,id}` wire inputs
  /// (freeze-on-send happens server-side). 发送(202,返 assistant msg id);mentions 为 {type,id} 线缆输入。
  Future<String> sendMessage(
    String conversationId, {
    required String content,
    List<String> attachmentIds,
    List<({String type, String id})> mentions,
  });

  /// Replace the conversation's LAST round with a new version (`POST /{id}:retry` → 202, returns the new
  /// ASSISTANT message id — the same shape as [sendMessage], because it is the same kind of act: a
  /// generation that streams over the messages SSE).
  ///
  /// An empty [content] REGENERATES (the same question, answered again). A non-empty one EDIT-RESENDS: the
  /// question is replaced too, keeping the original attachment references. [modelOverride] applies to THIS
  /// TURN ONLY and is never written to the thread's setting (that has its own PATCH — [setModelOverride]).
  ///
  /// Nothing is deleted: the replaced rows keep coming back from the history reads with `supersededBy` set,
  /// which is what the version pager reads. 409 `STREAM_IN_PROGRESS` while the last round has not settled;
  /// 404 `MESSAGE_NOT_FOUND` when there is no round to retry.
  ///
  /// 把对话的**末回合**换成一个新版本(`POST /{id}:retry` → 202,返回新 **assistant** message id——与
  /// [sendMessage] 同形,因为它是同一种行为:一次经 messages SSE 流式的生成)。
  ///
  /// [content] 为空 = **重生成**(同一个问题、再答一次);非空 = **编辑重发**:问句也一起换,并保留原来的附件引用。
  /// [modelOverride] **只作用于本回合**、绝不写进线程设置(那有它自己的 PATCH——[setModelOverride])。
  ///
  /// 什么都不删:被替换的行照常从历史读返回、带上 `supersededBy`,那正是版本翻页所读。末回合未落定 → 409
  /// `STREAM_IN_PROGRESS`;无回合可重试 → 404 `MESSAGE_NOT_FOUND`。
  Future<String> retryTurn(
    String conversationId, {
    String content,
    ({String apiKeyId, String modelId})? modelOverride,
  });

  /// Cancel the in-flight turn (`POST /{id}:cancel` → 204, idempotent). The terminal arrives via the
  /// stream's `message_stop` — the client never fabricates one. 取消在途回合;终态经流帧到达、不本地伪造。
  Future<void> cancelTurn(String conversationId);

  /// Clear the unread flag (`POST /{id}:seen` → 204, idempotent) — called when the user has the thread
  /// focused as a reply completes (or opens it). 清未读(:seen,幂等)。
  Future<void> markSeen(String conversationId);

  /// PATCH the per-thread model override — tristate: a [ref] sets it, null CLEARS it (the wire sends an
  /// explicit `modelOverride: null`; omitting the key would mean "leave unchanged"). 三态:ref=设,null=显式清。
  Future<Conversation> setModelOverride(
    String id,
    ({String apiKeyId, String modelId})? ref,
  );

  /// The realtime frame feed for ONE conversation (messages SSE, scope `conversation:<id>`) — the
  /// transcript controller folds these. Live = the gateway demux; the fixture scripts playback, which is
  /// what makes the zero-backend demo stream. 单会话实时帧(messages 流 demux);fixture 脚本化回放供 demo 流式。
  Stream<StreamEnvelope> conversationFrames(String conversationId);

  /// The messages-stream 410 resync signal: the buffer evicted past our cursor — drop the live layer,
  /// refetch the durable head, resubscribe-fresh. messages 流 410 重同步信号:丢 live 层、重拉耐久头。
  Stream<void> transcriptResync();

  /// ONE workflow's entities-stream frames (scope `workflow:{id}`) — the sidestage listens for the
  /// durable `run_terminal` signal so a poll-type stage (trigger_workflow's 202) settles the moment
  /// the run truly ends instead of holding forever (R-10 retires, W6 backend).
  /// 单 workflow 的 entities 流帧(scope workflow:{id})——侧幕借它听 durable `run_terminal`,poll 型舞台
  /// (trigger_workflow 202)在 run 真结束的瞬间落定、不再无限驻留(R-10 退役,W6 后端)。
  Stream<StreamEnvelope> workflowFrames(String workflowId);

  /// Workspace-wide TURN lifecycle for the rail's activity dots: durable top-level `message`
  /// open/close + `interaction` signals from the messages stream (E1: unfiltered, client-filtered).
  /// The row re-read this drives is the ONLY realtime path for isGenerating / awaitingInput /
  /// hasUnread — the backend emits NO notifications event at turn terminals by design.
  /// workspace 级回合生命周期(rail 活态点):messages 流的顶层 message open/close + interaction 信号。
  /// 由此驱动的单行重读是 isGenerating/awaitingInput/hasUnread 唯一实时通路——后端设计上回合终态
  /// **不发** notifications 事件。
  Stream<TurnSignal> turnSignals();

  /// Every runnable model option (`GET /model-capabilities`: probed key × served model) — the head's
  /// per-thread model picker. 全部可跑模型选项(已探测 key × 模型)——头部线程级选择器的数据源。

  // ── right island: the touchpoint ledger (WRK-061) 右岛触点台账 ──

  /// One keyset page of the conversation's touchpoint ledger (`GET /{id}/touchpoints`, sorted
  /// last_at DESC, id DESC). NOTE the sort key MUTATES (a re-touched row jumps pages) — the ledger
  /// provider dedupes by row id and lets the durable touchpoint Signal deliver rows that moved into
  /// the loaded region. [kind]/[verb] are the server-side enum filters (wrong values = 400).
  /// 台账一页(last_at 降序,排序键会变——再触碰行跳页):provider 按行 id 去重,升区行由 durable 信号送达;
  /// kind/verb 是服务端枚举过滤(拼错=400)。
  Future<Page<Touchpoint>> listTouchpoints(
    String conversationId, {
    String? cursor,
    int? limit,
    String? kind,
    TouchpointVerb? verb,
  });

  // ── the sidestage's old-truth reads (WRK-061 R-5) 侧幕旧真相单读 ──

  /// One function WITH its active version embedded (`GET /functions/{id}`) — the edit stage's
  /// entrance GET: name while the args stream is still nameless, the AnLayerDiff old-code layer, and
  /// the settle diff's `before` — one fetch, three uses. 函数单读(带 activeVersion):edit 登台一石三鸟。
  Future<FunctionEntity> getFunctionSnapshot(String id);

  /// One document WITH content (`GET /documents/{id}`) — the document stage's prefix fast-forward
  /// baseline (and the settle size badge's `before`). 文档单读(带 content):前缀快进基线+尺寸徽 before。
  Future<DocumentNode> getDocumentSnapshot(String id);

  /// One workflow WITH graphParsed (`GET /workflows/{id}`) — the edit stage's resting canvas + the
  /// settle reconcile truth (W3). 工作流单读(带 graphParsed):edit 静置底座+落定对账真相。
  Future<WorkflowEntity> getWorkflowSnapshot(String id);

  /// One control WITH branches (`GET /controls/{id}`) — the edit ladder's 40% understratum (W3).
  /// control 单读(带 branches):edit 旧梯垫底。
  Future<ControlLogic> getControlSnapshot(String id);

  /// One approval WITH template (`GET /approvals/{id}`) — the settle reconcile (W3). approval 单读。
  Future<ApprovalForm> getApprovalSnapshot(String id);

  /// One agent WITH its active version (`GET /agents/{id}`) — the edit stage's R-9 progressive
  /// disclosure baseline + the settle reconcile. agent 单读:R-9 渐进开区基线+落定对账。
  Future<AgentEntity> getAgentSnapshot(String id);

  /// One handler WITH methods (`GET /handlers/{id}`) — the edit rack's old truth + the settle's
  /// config/runtime state. handler 单读:旧方法架+落定配置/运行态。
  Future<HandlerEntity> getHandlerSnapshot(String id);

  /// One trigger (`GET /triggers/{id}`) — the settle's listening dot / nextFireAt countdown / refCount
  /// (R-16: counts come from GET only). trigger 单读:落定的监听点/倒计时/引用数(R-16 只信 GET)。
  Future<TriggerEntity> getTriggerSnapshot(String id);

  /// One skill WITH body (`GET /skills/{name}`) — the sidestage settled row's full stage (WRK-064). id=name.
  /// skill 单读(带 body):侧幕落定行的完整真身舞台。id=name。
  Future<Skill> getSkillSnapshot(String name);

  /// One MCP server (`GET /mcp-servers/{name}`) — the settled row's tool shelf (WRK-064). id=name.
  /// mcp 单读:侧幕落定行的工具货架。id=name。
  Future<McpServerStatus> getMcpSnapshot(String name);

  /// The conversation's own todo list (`GET /{id}/todos`, whole-list semantics) — the rundown's
  /// reconnect hydration; live updates ride the durable `todo` Signal. 主清单水化(重连兜底);实时走信号。
  Future<ConversationTodos> getTodos(String conversationId);

  // ── human-loop interactions (V6 danger gate + ask_user) 人在环交互 ──

  /// The reconnect snapshot of currently-AWAITING interactions (`GET /{id}/interactions` → `{data:[…]}`,
  /// bounded/unpaginated — the broker's in-memory pending table). The interaction signal is ephemeral
  /// (seq 0), so THIS is the source of truth after a reconnect. 重连快照:当前待决交互(ephemeral 信号的重连真相)。
  Future<List<Interaction>> listInteractions(String conversationId);

  /// Resolve one awaiting interaction (`POST /{id}/interactions/{toolCallId}` `{action, answer?}` → 204).
  /// [action] is the closed wire set; [answer] rides only ask-accept. fail-safe: only approve/accept
  /// executes. 决议一个待决交互(204);action 封闭集,answer 仅 ask-accept;fail-safe 只 approve/accept 落下去。
  Future<void> resolveInteraction(
    String conversationId,
    String toolCallId, {
    required InteractionAction action,
    String? answer,
  });
}

/// The production repository over the Phase-4.0 pipeline. Holds no state; the method is a thin
/// envelope-decode over [ApiClient.getPage]. (Realtime gets the nullable SseGateway added in the
/// live-wiring slice — omitted now since step 1 has no realtime method.)
///
/// 生产 repository(接 Phase 4.0 管道)。无状态;读方法是 ApiClient 上的薄信封解码,实时则是 notifications 流
/// 上的投影(可空 SseGateway——就绪前 null,则信号流为空)。
class LiveChatRepository implements ChatRepository {
  LiveChatRepository({required ApiClient api, SseGateway? sse})
    : _api = api,
      _sse = sse;

  final ApiClient _api;
  final SseGateway? _sse;

  @override
  Future<Page<Conversation>> listConversations({
    String? cursor,
    int? limit,
    ConvSort sort = ConvSort.activity,
    ConvArchive archive = ConvArchive.active,
    String? search,
    ConvWorkDir workDir = ConvWorkDir.any,
    ConvPin pinned = ConvPin.any,
  }) {
    final q = <String, dynamic>{
      'cursor': ?cursor,
      'limit': ?limit,
      'sort': sort.wire,
      'archived': ?archive.wire,
      'search': ?search,
      // `workDir` is PRESENCE-sensitive on the wire: an empty value means "only the unmounted threads",
      // which is not the same request as omitting the key. The `?` spread omits null and keeps `''`.
      // `workDir` 在线缆上**对键是否出现敏感**:空值意为「仅未挂的线程」，与省略该键**不是**同一个请求。`?` 展开
      // 省略 null、保留 `''`。
      'workDir': ?workDir.wire,
      'pinned': ?pinned.wire,
    };
    return _api.getPage(
      '/api/v1/conversations',
      Conversation.fromJson,
      query: q,
    );
  }

  // A bounded projection: `getPage(...).items` is the house idiom for the uncursored `{data:[…]}` reads
  // (documents/tree, /tools) — there is no cursor to carry, so the page's coordinates are simply empty.
  // 有界投影:`getPage(...).items` 是无游标 `{data:[…]}` 读的本库惯用形(documents/tree、/tools)——没有游标要带，
  // 故页坐标就是空的。
  @override
  Future<List<WorkDirGroup>> workdirGroups() async => (await _api.getPage(
    '/api/v1/conversations/workdir-groups',
    WorkDirGroup.fromJson,
  )).items;

  @override
  Future<int> archiveWorkDir(String workDir) =>
      _workDirAction('archive-workdir', workDir, 'archived');

  @override
  Future<int> deleteWorkDir(String workDir) =>
      _workDirAction('delete-workdir', workDir, 'deleted');

  // Both residency-wide actions answer `{workDir, <verb>: n}` where n is how many conversations actually
  // changed — the rail folds that number, not its own guess, so an already-archived group honestly reports 0.
  // 两个驻地级动作都答 `{workDir, <动词>: n}`，n 是真正改变了几条对话——rail 折入**那个**数、而不是自己的猜测，
  // 故一个已归档的组诚实地报 0。
  Future<int> _workDirAction(
    String action,
    String workDir,
    String field,
  ) async {
    final data = await _api.postData(
      '/api/v1/conversations:$action',
      body: {'workDir': workDir},
    );
    final n = data[field];
    return n is int ? n : 0;
  }

  // Each write is one PATCH of one semantic field (rename / pin / archive) or a DELETE — the response is
  // the authoritative new Conversation (PATCH) the caller folds into its list. 每写=单字段 PATCH 或 DELETE。
  String _path(String id) => '/api/v1/conversations/$id';

  @override
  Future<Conversation> renameConversation(String id, String title) => _api
      .patchEntity(_path(id), Conversation.fromJson, body: {'title': title});

  @override
  Future<Conversation> setWorkDir(
    String id,
    String workDir,
  ) => _api.patchEntity(
    _path(id),
    Conversation.fromJson,
    // A plain string: '' unmounts. The key is always PRESENT — an absent key would mean "leave unchanged".
    // 朴素字符串:'' 即退出驻地。键恒**出现**——缺键意为「不动」。
    body: {'workDir': workDir},
  );

  @override
  Future<WorkDirInfo> workDirInfo(String id) =>
      _api.getEntity('${_path(id)}/workdir', WorkDirInfo.fromJson);

  // The three residency git actions (WD2 + WD3). Each returns the re-probed projection rather than 204: one
  // switch changes several of its fields at once, so a client made to re-GET is a client that paints one frame
  // of the old branch. They ride the `workdir` SUB-resource because the conversation-level `{id}:action`
  // pattern already belongs to chat's :cancel/:seen/:fork/:retry dispatcher.
  // 三个驻地 git 动作(WD2 + WD3)。各返回重探后的投影、不是 204:一次切换同时改它好几个字段,故一个被迫再 GET 一次的
  // 客户端就是一个会画出一帧旧分支的客户端。它们骑在 `workdir` **子**资源上,因为对话级 `{id}:action` 模式已归 chat 的
  // :cancel/:seen/:fork/:retry 派发器。
  @override
  Future<WorkDirInfo> switchBranch(String id, String branch) => _api.postEntity(
    '${_path(id)}/workdir:switch-branch',
    WorkDirInfo.fromJson,
    body: {'branch': branch},
  );

  @override
  Future<WorkDirInfo> createBranch(String id, String branch) => _api.postEntity(
    '${_path(id)}/workdir:create-branch',
    WorkDirInfo.fromJson,
    body: {'branch': branch},
  );

  @override
  Future<WorkDirInfo> addWorktree(String id, String name) => _api.postEntity(
    '${_path(id)}/workdir:add-worktree',
    WorkDirInfo.fromJson,
    // A NAME, never a path — the server derives the sibling target by the `make worktree` convention, which is
    // what keeps this from being able to write a checkout anywhere on the disk.
    // 是**名字**、绝不是路径——服务端按 `make worktree` 约定派生兄弟目标,正是这一点让它无法往磁盘任意处写出一份
    // checkout。
    body: {'name': name},
  );

  @override
  Future<Conversation> setPinned(String id, bool pinned) => _api.patchEntity(
    _path(id),
    Conversation.fromJson,
    body: {'pinned': pinned},
  );

  @override
  Future<Conversation> setArchived(String id, bool archived) =>
      _api.patchEntity(
        _path(id),
        Conversation.fromJson,
        body: {'archived': archived},
      );

  @override
  Future<void> deleteConversation(String id) => _api.delete(_path(id));

  @override
  Future<AttachmentMeta> uploadAttachment({
    required List<int> bytes,
    required String filename,
    String? mimeType,
  }) => _api.postEntity(
    '/api/v1/attachments',
    AttachmentMeta.fromJson,
    body: FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
      ),
    }),
  );

  @override
  Future<void> deleteAttachment(String id) =>
      _api.delete('/api/v1/attachments/$id');

  @override
  Future<AttachmentPreparation> cancelAttachmentPreparation(String id) =>
      _api.postEntity(
        '/api/v1/attachments/$id/preparation/cancel',
        AttachmentPreparation.fromJson,
      );

  @override
  Future<AttachmentPreparation> retryAttachmentPreparation(String id) =>
      _api.postEntity(
        '/api/v1/attachments/$id/preparation/retry',
        AttachmentPreparation.fromJson,
      );

  @override
  Future<AttachmentMeta> getAttachment(String id) =>
      _api.getEntity('/api/v1/attachments/$id', AttachmentMeta.fromJson);

  @override
  Future<List<int>> getAttachmentBytes(String id) =>
      _api.getBytes('/api/v1/attachments/$id/content');

  @override
  Future<AttachmentPlaybackLease> createAttachmentPlaybackLease(String id) =>
      _api.postEntity(
        '/api/v1/attachments/$id/playback-lease',
        AttachmentPlaybackLease.fromJson,
      );

  @override
  Future<Conversation> getConversation(String id) =>
      _api.getEntity(_path(id), Conversation.fromJson);

  @override
  Future<Conversation> forkConversation(
    String id, {
    String? atMessageId,
  }) => _api.postEntity(
    '${_path(id)}:fork',
    Conversation.fromJson,
    // A null atMessageId is OMITTED, not sent as "" — the backend treats an absent key and an empty
    // string alike, and omitting keeps the wire honest about "no cut point given".
    // atMessageId 为 null 时**省略**该键、不发空串——后端对缺键与空串同解,省略让线缆诚实表达「未给切点」。
    body: {'atMessageId': ?atMessageId},
  );

  @override
  Stream<ConversationSignal> lifecycleSignals() {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    // The notifications stream is low-frequency and shares one scope (scope.kind="notification"), so a
    // `.where` over the raw feed is correct here — NOT the rebuild-storm the demux guards high-freq paths
    // against (mirrors LiveEntityRepository.lifecycleSignals).
    // notifications 低频、共用单 scope,故对原始 feed `.where` 在此正确(非 demux 所防的高频风暴)。
    return sse
        .rawStream(StreamName.notifications)
        .map(ConversationSignal.fromEnvelope)
        .where((s) => s != null)
        .cast<ConversationSignal>();
  }

  @override
  Stream<void> lifecycleResync() =>
      _sse?.resync(StreamName.notifications) ?? const Stream.empty();

  @override
  Future<Conversation> createConversation() => _api.postEntity(
    '/api/v1/conversations',
    Conversation.fromJson,
    body: {'title': ''},
  );

  @override
  Future<Page<ChatMessage>> listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
  }) => _api.getPage(
    '${_path(conversationId)}/messages',
    ChatMessage.fromJson,
    query: {'cursor': ?cursor, 'limit': ?limit},
  );

  @override
  Future<MessagesWindow> messagesAround(
    String conversationId,
    String messageId, {
    int? limit,
  }) async => MessagesWindow.fromJson(
    await _api.getEnvelope(
      '${_path(conversationId)}/messages',
      query: {'around': messageId, 'limit': ?limit},
    ),
  );

  @override
  Future<Page<ChatMessage>> listMessagesNewer(
    String conversationId, {
    required String cursor,
    int? limit,
  }) => _api.getPage(
    '${_path(conversationId)}/messages',
    ChatMessage.fromJson,
    query: {'dir': 'newer', 'cursor': cursor, 'limit': ?limit},
  );

  @override
  Future<Page<TranscriptAnchor>> listAnchors(
    String conversationId, {
    String? cursor,
    int? limit,
  }) => _api.getPage(
    '${_path(conversationId)}/anchors',
    TranscriptAnchor.fromJson,
    query: {'cursor': ?cursor, 'limit': ?limit},
  );

  @override
  Future<String> sendMessage(
    String conversationId, {
    required String content,
    List<String> attachmentIds = const [],
    List<({String type, String id})> mentions = const [],
  }) => _api.postForId(
    '${_path(conversationId)}/messages',
    body: {
      'content': content,
      'attachmentIds': attachmentIds,
      'mentions': [
        for (final m in mentions) {'type': m.type, 'id': m.id},
      ],
    },
  );

  @override
  Future<String> retryTurn(
    String conversationId, {
    String content = '',
    ({String apiKeyId, String modelId})? modelOverride,
  }) => _api.postForId(
    '${_path(conversationId)}:retry',
    // Both keys are OMITTED when absent rather than sent empty/null: the backend reads an absent content
    // as "regenerate" and an absent modelOverride as "use whatever this thread is set to", so omitting is
    // what the wire actually means. An explicit null modelOverride would read as a tristate CLEAR, which
    // retry has no case for.
    // 两个键缺省时**省略**、不发空/null:后端把缺席的 content 解作「重生成」、缺席的 modelOverride 解作「用这条
    // 线程现有的设置」,故省略正是线缆的本意。显式 null 会被读成三态的**清除**,而重试没有那一格。
    body: {
      if (content.isNotEmpty) 'content': content,
      if (modelOverride != null)
        'modelOverride': {
          'apiKeyId': modelOverride.apiKeyId,
          'modelId': modelOverride.modelId,
        },
    },
  );

  @override
  Future<void> cancelTurn(String conversationId) =>
      _api.postNoContent('${_path(conversationId)}:cancel');

  @override
  Future<void> markSeen(String conversationId) =>
      _api.postNoContent('${_path(conversationId)}:seen');

  @override
  Future<Conversation> setModelOverride(
    String id,
    ({String apiKeyId, String modelId})? ref,
  ) =>
      // Tristate on the wire: the key must be PRESENT — a value sets, an explicit null clears (an absent
      // key would mean "leave unchanged"). 线缆三态:键必须出现——有值=设,显式 null=清(缺键=不动)。
      _api.patchEntity(
        _path(id),
        Conversation.fromJson,
        body: {
          'modelOverride': ref == null
              ? null
              : {'apiKeyId': ref.apiKeyId, 'modelId': ref.modelId},
        },
      );

  @override
  Stream<StreamEnvelope> conversationFrames(String conversationId) {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    return sse.scopeStream(
      StreamScope(kind: 'conversation', id: conversationId),
    );
  }

  @override
  Stream<void> transcriptResync() =>
      _sse?.resync(StreamName.messages) ?? const Stream.empty();

  @override
  Stream<StreamEnvelope> workflowFrames(String workflowId) {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    return sse.scopeStream(StreamScope(kind: 'workflow', id: workflowId));
  }

  @override
  Stream<TurnSignal> turnSignals() {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    // The RAW workspace feed (deltas included) through a PURE O(1) mapper — demux-layer discipline:
    // per-frame constant work lives here, never in a Riverpod build (the deltas die in the mapper).
    // RAW 全量 feed 过纯 O(1) 映射——demux 层纪律:逐帧常数功在此、绝不进 build(delta 死在映射里)。
    return sse
        .rawStream(StreamName.messages)
        .map(turnSignalFromEnvelope)
        .where((s) => s != null)
        .cast<TurnSignal>();
  }

  @override
  Future<FunctionEntity> getFunctionSnapshot(String id) =>
      _api.getEntity('/api/v1/functions/$id', FunctionEntity.fromJson);

  @override
  Future<DocumentNode> getDocumentSnapshot(String id) =>
      _api.getEntity('/api/v1/documents/$id', DocumentNode.fromJson);

  @override
  Future<WorkflowEntity> getWorkflowSnapshot(String id) =>
      _api.getEntity('/api/v1/workflows/$id', WorkflowEntity.fromJson);

  @override
  Future<ControlLogic> getControlSnapshot(String id) =>
      _api.getEntity('/api/v1/controls/$id', ControlLogic.fromJson);

  @override
  Future<ApprovalForm> getApprovalSnapshot(String id) =>
      _api.getEntity('/api/v1/approvals/$id', ApprovalForm.fromJson);

  @override
  Future<Skill> getSkillSnapshot(String name) =>
      _api.getEntity('/api/v1/skills/$name', Skill.fromJson);

  @override
  Future<McpServerStatus> getMcpSnapshot(String name) =>
      _api.getEntity('/api/v1/mcp-servers/$name', McpServerStatus.fromJson);

  @override
  Future<TriggerEntity> getTriggerSnapshot(String id) =>
      _api.getEntity('/api/v1/triggers/$id', TriggerEntity.fromJson);

  @override
  Future<AgentEntity> getAgentSnapshot(String id) =>
      _api.getEntity('/api/v1/agents/$id', AgentEntity.fromJson);

  @override
  Future<HandlerEntity> getHandlerSnapshot(String id) =>
      _api.getEntity('/api/v1/handlers/$id', HandlerEntity.fromJson);

  @override
  Future<Page<Touchpoint>> listTouchpoints(
    String conversationId, {
    String? cursor,
    int? limit,
    String? kind,
    TouchpointVerb? verb,
  }) => _api.getPage(
    '${_path(conversationId)}/touchpoints',
    Touchpoint.fromJson,
    query: {
      'cursor': ?cursor,
      'limit': ?limit,
      'kind': ?kind,
      if (verb != null) 'verb': verb.name,
    },
  );

  @override
  Future<ConversationTodos> getTodos(String conversationId) => _api.getEntity(
    '${_path(conversationId)}/todos',
    ConversationTodos.fromJson,
  );

  @override
  Future<List<Interaction>> listInteractions(String conversationId) async {
    // Bounded `{data:[…]}` (no cursor) — reuse getPage and take the items (mirrors listModelCapabilities).
    // 有界 {data:[…]}(无游标)——复用 getPage 取 items。
    final page = await _api.getPage(
      '${_path(conversationId)}/interactions',
      Interaction.fromJson,
    );
    return page.items;
  }

  @override
  Future<void> resolveInteraction(
    String conversationId,
    String toolCallId, {
    required InteractionAction action,
    String? answer,
  }) => _api.postNoContent(
    '${_path(conversationId)}/interactions/$toolCallId',
    body: {'action': action.wire, 'answer': ?answer},
  );
}
