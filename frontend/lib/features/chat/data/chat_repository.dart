import 'package:dio/dio.dart';

import '../../../core/contract/attachment.dart';
import '../../../core/contract/conversation.dart';
import '../../../core/contract/messages/chat_message.dart';
import '../../../core/contract/model_capability.dart';
import '../../../core/contract/page.dart';
import '../../../core/net/api_client.dart';
import '../../../core/sse/frame.dart';
import '../../../core/sse/sse_gateway.dart';
import 'conversation_signal.dart';

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

  /// Every runnable model option (`GET /model-capabilities`: probed key × served model) — the head's
  /// per-thread model picker. 全部可跑模型选项(已探测 key × 模型)——头部线程级选择器的数据源。
  Future<List<ModelCapability>> listModelCapabilities();
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
  Future<List<ModelCapability>> listModelCapabilities() async {
    final page = await _api.getPage('/api/v1/model-capabilities', ModelCapability.fromJson);
    return page.items;
  }
}
