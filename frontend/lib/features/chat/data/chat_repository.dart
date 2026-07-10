import 'package:dio/dio.dart';

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
  });

  /// Rename a thread (`PATCH {title}`). Returns the authoritative updated object so the caller patches
  /// its list state from it (the initiator never waits on the SSE echo — notifications are for OTHER
  /// clients, and carry no echo suppression, so the list merge must be idempotent). One PATCH = one
  /// semantic field (the backend's `action` is otherwise undefined). 重命名,返权威对象供调用方 patch 列表(不等 SSE)。
  Future<Conversation> renameConversation(String id, String title);

  /// Pin / unpin (`PATCH {pinned}`). 置顶/取消(PATCH {pinned})。
  Future<Conversation> setPinned(String id, bool pinned);

  /// Archive / unarchive (`PATCH {archived}`). 归档/取消(PATCH {archived})。
  Future<Conversation> setArchived(String id, bool archived);

  /// Soft-delete (`DELETE` → 204, tombstoned server-side; the rail just drops the row). 软删(204)。
  Future<void> deleteConversation(String id);

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

  /// One attachment's metadata (`GET /attachments/{id}`) — the bubble resolves filename/kind/size from
  /// the id-only `attrs.attachments` snapshot. 附件元数据——泡从纯 id 快照解析名/类/大小。
  Future<AttachmentMeta> getAttachment(String id);

  /// The raw bytes (`GET /attachments/{id}/content`, non-envelope) — image thumbnails decode from
  /// this; loopback-only, so per-image fetch is cheap. 原始字节(非 envelope)——图缩略图由此解码;loopback 便宜。
  Future<List<int>> getAttachmentBytes(String id);

  /// A single conversation by id (`GET /{id}`) — the rail re-reads ONE row on a lifecycle signal it did
  /// not originate (auto-title, or a change from another window). 单取一条,供 rail 据非自身发起的信号重读一行。
  Future<Conversation> getConversation(String id);

  /// The conversation lifecycle signals off the notifications SSE stream (`conversation.<action>`). The
  /// list patches on `durable`, ignores ephemeral — created→insert, deleted→drop, everything else→re-read
  /// that row. Live is a projection over the gateway; the fixture scripts them. 对话生命周期信号(notifications)。
  Stream<ConversationSignal> lifecycleSignals();

  // ── the per-thread transcript surface 逐线程 transcript 面 ──

  /// Create a thread (`POST /conversations`, empty title — the backend auto-titles after turn 1). The
  /// landing's first send calls this, then [sendMessage]. 建线程(空标题,首回合后后端自动命名)。
  Future<Conversation> createConversation();

  /// One keyset page of turn history WITH blocks (`GET /{id}/messages`) — wire order is newest-first;
  /// hydration reverses to chronological. 回合历史一页(含 blocks);线缆新→旧,水化反转为时间序。
  Future<Page<ChatMessage>> listMessages(String conversationId, {String? cursor, int? limit});

  /// The deep-jump window (`GET /{id}/messages?around=<messageId>`): a newest-first slice centered
  /// on the target + both continuation cursors. The jump path REPLACES the transcript window with
  /// this (re-anchor) — never stitches. An unknown target surfaces the backend's 404 (identity
  /// anchoring). 深跳窗(?around=):以目标为中心的切片+双向游标;跳转径整窗替换、绝不缝合;未知目标 404。
  Future<MessagesWindow> messagesAround(String conversationId, String messageId, {int? limit});

  /// One keyset page walking FORWARD in time (`GET /{id}/messages?dir=newer&cursor=`) — the window's
  /// newerCursor continuation; data stays newest-first (the wire's single ordering rule).
  /// 沿时间向前的一页(?dir=newer);data 恒新→旧(线缆唯一排序规则)。
  Future<Page<ChatMessage>> listMessagesNewer(String conversationId, {required String cursor, int? limit});

  /// One keyset page of navigation anchors (`GET /{id}/anchors`, newest-first) — the 场次条 source:
  /// user turns / folded tool clusters / dangerous calls / compaction marks / abnormal terminals;
  /// pending gates ride the first page's top outside the keyset. 场次条锚点一页(最新在前)。
  Future<Page<TranscriptAnchor>> listAnchors(String conversationId, {String? cursor, int? limit});

  /// Send a user turn (`POST /{id}/messages` → 202): lands the user message, opens the assistant turn,
  /// enqueues the run; returns the ASSISTANT message id. [mentions] are `{type,id}` wire inputs
  /// (freeze-on-send happens server-side). 发送(202,返 assistant msg id);mentions 为 {type,id} 线缆输入。
  Future<String> sendMessage(
    String conversationId, {
    required String content,
    List<String> attachmentIds,
    List<({String type, String id})> mentions,
  });

  /// Cancel the in-flight turn (`POST /{id}:cancel` → 204, idempotent). The terminal arrives via the
  /// stream's `message_stop` — the client never fabricates one. 取消在途回合;终态经流帧到达、不本地伪造。
  Future<void> cancelTurn(String conversationId);

  /// Clear the unread flag (`POST /{id}:seen` → 204, idempotent) — called when the user has the thread
  /// focused as a reply completes (or opens it). 清未读(:seen,幂等)。
  Future<void> markSeen(String conversationId);

  /// PATCH the per-thread model override — tristate: a [ref] sets it, null CLEARS it (the wire sends an
  /// explicit `modelOverride: null`; omitting the key would mean "leave unchanged"). 三态:ref=设,null=显式清。
  Future<Conversation> setModelOverride(String id, ({String apiKeyId, String modelId})? ref);

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
  }) {
    final q = <String, dynamic>{
      'cursor': ?cursor,
      'limit': ?limit,
      'sort': sort.wire,
      'archived': ?archive.wire,
      'search': ?search,
    };
    return _api.getPage('/api/v1/conversations', Conversation.fromJson, query: q);
  }

  // Each write is one PATCH of one semantic field (rename / pin / archive) or a DELETE — the response is
  // the authoritative new Conversation (PATCH) the caller folds into its list. 每写=单字段 PATCH 或 DELETE。
  String _path(String id) => '/api/v1/conversations/$id';

  @override
  Future<Conversation> renameConversation(String id, String title) =>
      _api.patchEntity(_path(id), Conversation.fromJson, body: {'title': title});

  @override
  Future<Conversation> setPinned(String id, bool pinned) =>
      _api.patchEntity(_path(id), Conversation.fromJson, body: {'pinned': pinned});

  @override
  Future<Conversation> setArchived(String id, bool archived) =>
      _api.patchEntity(_path(id), Conversation.fromJson, body: {'archived': archived});

  @override
  Future<void> deleteConversation(String id) => _api.delete(_path(id));

  @override
  Future<AttachmentMeta> uploadAttachment({
    required List<int> bytes,
    required String filename,
    String? mimeType,
  }) =>
      _api.postEntity(
        '/api/v1/attachments',
        AttachmentMeta.fromJson,
        body: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename,
              contentType: mimeType == null ? null : DioMediaType.parse(mimeType)),
        }),
      );

  @override
  Future<void> deleteAttachment(String id) => _api.delete('/api/v1/attachments/$id');

  @override
  Future<AttachmentMeta> getAttachment(String id) =>
      _api.getEntity('/api/v1/attachments/$id', AttachmentMeta.fromJson);

  @override
  Future<List<int>> getAttachmentBytes(String id) =>
      _api.getBytes('/api/v1/attachments/$id/content');

  @override
  Future<Conversation> getConversation(String id) =>
      _api.getEntity(_path(id), Conversation.fromJson);

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
  Future<Conversation> createConversation() =>
      _api.postEntity('/api/v1/conversations', Conversation.fromJson, body: {'title': ''});

  @override
  Future<Page<ChatMessage>> listMessages(String conversationId, {String? cursor, int? limit}) =>
      _api.getPage('${_path(conversationId)}/messages', ChatMessage.fromJson,
          query: {'cursor': ?cursor, 'limit': ?limit});

  @override
  Future<MessagesWindow> messagesAround(String conversationId, String messageId, {int? limit}) async =>
      MessagesWindow.fromJson(await _api.getEnvelope('${_path(conversationId)}/messages',
          query: {'around': messageId, 'limit': ?limit}));

  @override
  Future<Page<ChatMessage>> listMessagesNewer(String conversationId,
          {required String cursor, int? limit}) =>
      _api.getPage('${_path(conversationId)}/messages', ChatMessage.fromJson,
          query: {'dir': 'newer', 'cursor': cursor, 'limit': ?limit});

  @override
  Future<Page<TranscriptAnchor>> listAnchors(String conversationId, {String? cursor, int? limit}) =>
      _api.getPage('${_path(conversationId)}/anchors', TranscriptAnchor.fromJson,
          query: {'cursor': ?cursor, 'limit': ?limit});

  @override
  Future<String> sendMessage(
    String conversationId, {
    required String content,
    List<String> attachmentIds = const [],
    List<({String type, String id})> mentions = const [],
  }) =>
      _api.postForId('${_path(conversationId)}/messages', body: {
        'content': content,
        'attachmentIds': attachmentIds,
        'mentions': [
          for (final m in mentions) {'type': m.type, 'id': m.id},
        ],
      });

  @override
  Future<void> cancelTurn(String conversationId) =>
      _api.postNoContent('${_path(conversationId)}:cancel');

  @override
  Future<void> markSeen(String conversationId) =>
      _api.postNoContent('${_path(conversationId)}:seen');

  @override
  Future<Conversation> setModelOverride(String id, ({String apiKeyId, String modelId})? ref) =>
      // Tristate on the wire: the key must be PRESENT — a value sets, an explicit null clears (an absent
      // key would mean "leave unchanged"). 线缆三态:键必须出现——有值=设,显式 null=清(缺键=不动)。
      _api.patchEntity(_path(id), Conversation.fromJson, body: {
        'modelOverride': ref == null ? null : {'apiKeyId': ref.apiKeyId, 'modelId': ref.modelId},
      });

  @override
  Stream<StreamEnvelope> conversationFrames(String conversationId) {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    return sse.scopeStream(StreamScope(kind: 'conversation', id: conversationId));
  }

  @override
  Stream<void> transcriptResync() => _sse?.resync(StreamName.messages) ?? const Stream.empty();

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
  }) =>
      _api.getPage('${_path(conversationId)}/touchpoints', Touchpoint.fromJson, query: {
        'cursor': ?cursor,
        'limit': ?limit,
        'kind': ?kind,
        if (verb != null) 'verb': verb.name,
      });

  @override
  Future<ConversationTodos> getTodos(String conversationId) =>
      _api.getEntity('${_path(conversationId)}/todos', ConversationTodos.fromJson);

  @override
  Future<List<Interaction>> listInteractions(String conversationId) async {
    // Bounded `{data:[…]}` (no cursor) — reuse getPage and take the items (mirrors listModelCapabilities).
    // 有界 {data:[…]}(无游标)——复用 getPage 取 items。
    final page =
        await _api.getPage('${_path(conversationId)}/interactions', Interaction.fromJson);
    return page.items;
  }

  @override
  Future<void> resolveInteraction(
    String conversationId,
    String toolCallId, {
    required InteractionAction action,
    String? answer,
  }) =>
      _api.postNoContent(
        '${_path(conversationId)}/interactions/$toolCallId',
        body: {'action': action.wire, 'answer': ?answer},
      );
}
