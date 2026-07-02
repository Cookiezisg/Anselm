import 'dart:async';

import '../../../core/contract/attachment.dart';
import '../../../core/contract/conversation.dart';
import '../../../core/contract/messages/chat_message.dart';
import '../../../core/contract/model_capability.dart';
import '../../../core/contract/page.dart';
import '../../../core/sse/frame.dart';
import 'chat_repository.dart';
import 'conversation_signal.dart';

/// In-memory, scriptable [ChatRepository] — the SINGLE seam the whole Chat feature is driven by in
/// gallery / widget / provider tests and the zero-backend demo (mirrors [FixtureEntityRepository]). It
/// reproduces the backend's list semantics faithfully so the demo and tests behave like the real
/// thing: the archive scope filter, the title search substring, the pinned-first + sort ordering, and
/// keyset pagination (cursor = next start index). Seeds are held in a mutable list so later slices can
/// add upsert / mutate for scripted live updates.
///
/// 内存、可脚本化的 ChatRepository——gallery / widget / provider 测试与零后端 demo 驱动整 Chat feature 的唯一
/// 缝(镜像 FixtureEntityRepository)。忠实复现后端列表语义,使 demo/测试行为如真:归档范围过滤、标题搜索子串、
/// 置顶优先 + sort 排序、keyset 分页(cursor = 下一起始下标)。种子放可变 list,供后续片加 upsert / mutate 脚本化实时。
class FixtureChatRepository implements ChatRepository {
  FixtureChatRepository({
    List<Conversation>? conversations,
    Map<String, List<ChatMessage>>? messages,
  })  : _all = List.of(conversations ?? const []),
        _messages = {
          for (final e in (messages ?? const {}).entries) e.key: List.of(e.value),
        };

  final List<Conversation> _all;

  // Chronological per conversation (oldest→newest); listMessages serves newest-first like the backend.
  // 每会话时间序(旧→新);listMessages 按后端同款新→旧出。
  final Map<String, List<ChatMessage>> _messages;
  int _idSeq = 0;

  // A lazy broadcast controller so tests / the demo can script `conversation.<action>` signals without an
  // SSE socket (mirrors FixtureEntityRepository). 惰性广播控制器,使测试/demo 无 socket 即可脚本化信号。
  StreamController<ConversationSignal>? _signals;
  StreamController<ConversationSignal> get _lazySignals =>
      _signals ??= StreamController<ConversationSignal>.broadcast();

  // cursor = the next start index, as a string (same scheme as FixtureEntityRepository._page).
  // cursor = 下一起始下标的字符串(同 FixtureEntityRepository._page 方案)。
  static Page<T> _page<T>(List<T> all, String? cursor, int? limit) {
    final start = int.tryParse(cursor ?? '') ?? 0;
    final n = limit ?? all.length;
    final end = (start + n).clamp(0, all.length);
    final slice = all.sublist(start.clamp(0, all.length), end);
    final more = end < all.length;
    return Page(items: slice, nextCursor: more ? '$end' : null, hasMore: more);
  }

  // pinned-first, then the sort's secondary key, then an id tiebreaker matching the backend
  // (activity/created → id DESC, name → id ASC) so paging is deterministic.
  // 置顶优先、再 sort 次键、再 id tiebreaker(与后端一致:activity/created→id 降序、name→id 升序),使分页确定。
  static Comparator<Conversation> _comparator(ConvSort sort) => (a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final primary = switch (sort) {
          ConvSort.activity => b.lastMessageAt.compareTo(a.lastMessageAt),
          ConvSort.created => b.createdAt.compareTo(a.createdAt),
          ConvSort.name => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        };
        if (primary != 0) return primary;
        return sort == ConvSort.name ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
      };

  @override
  Future<Page<Conversation>> listConversations({
    String? cursor,
    int? limit,
    ConvSort sort = ConvSort.activity,
    ConvArchive archive = ConvArchive.active,
    String? search,
  }) async {
    final term = search?.trim().toLowerCase() ?? '';
    final rows = _all.where((c) {
      final scopeOk = switch (archive) {
        ConvArchive.active => !c.archived,
        ConvArchive.archivedOnly => c.archived,
        ConvArchive.all => true,
      };
      if (!scopeOk) return false;
      if (term.isNotEmpty && !c.title.toLowerCase().contains(term)) return false;
      return true;
    }).toList()
      ..sort(_comparator(sort));
    return _page(rows, cursor, limit);
  }

  // ── writes (mutate the seed list, mirroring the backend's PATCH/DELETE) ──

  // Find + replace by id; throw if gone (mirrors the backend's 404 CONVERSATION_NOT_FOUND so the error
  // path is exercisable). 按 id 改;不存在即抛(镜像后端 404)。
  Conversation _mutate(String id, Conversation Function(Conversation) f) {
    final i = _all.indexWhere((c) => c.id == id);
    if (i < 0) throw StateError('conversation not found: $id');
    final next = f(_all[i]);
    _all[i] = next;
    return next;
  }

  @override
  Future<Conversation> renameConversation(String id, String title) async =>
      _mutate(id, (c) => c.copyWith(title: title.trim()));

  @override
  Future<Conversation> setPinned(String id, bool pinned) async =>
      _mutate(id, (c) => c.copyWith(pinned: pinned));

  @override
  Future<Conversation> setArchived(String id, bool archived) async =>
      _mutate(id, (c) => c.copyWith(archived: archived));

  @override
  Future<void> deleteConversation(String id) async {
    if (!_all.any((c) => c.id == id)) throw StateError('conversation not found: $id');
    _all.removeWhere((c) => c.id == id);
  }

  @override
  Future<Conversation> getConversation(String id) async {
    final c = _all.where((c) => c.id == id).firstOrNull;
    if (c == null) throw StateError('conversation not found: $id'); // mirrors 404 CONVERSATION_NOT_FOUND
    return c;
  }

  @override
  Stream<ConversationSignal> lifecycleSignals() => _lazySignals.stream;

  // ── the per-thread transcript surface 逐线程 transcript 面 ──

  @override
  Future<Conversation> createConversation() async {
    final now = DateTime.now();
    final c = Conversation(
      id: 'cv_fx_${_idSeq++}',
      createdAt: now,
      updatedAt: now,
      lastMessageAt: now,
    );
    _all.insert(0, c);
    // Mirror the backend's notifications echo so the rail inserts the new row (demo/tests). 镜像回声,rail 长新行。
    emitSignal(ConversationSignal(id: c.id, action: ConversationAction.created, durable: true));
    return c;
  }

  @override
  Future<Page<ChatMessage>> listMessages(String conversationId, {String? cursor, int? limit}) async {
    if (!_all.any((c) => c.id == conversationId)) {
      throw StateError('conversation not found: $conversationId');
    }
    // Wire order = newest-first (the backend's keyset), so hydration's reverse is exercised for real.
    // 线缆序=新→旧(后端 keyset 同款),水化的反转被真实演练。
    final newestFirst = (_messages[conversationId] ?? const <ChatMessage>[]).reversed.toList();
    return _page(newestFirst, cursor, limit);
  }

  /// One-shot scripted send failure (the optimistic bubble's failed path). 一次性发送失败脚本。
  bool failNextSend = false;

  @override
  Future<String> sendMessage(
    String conversationId, {
    required String content,
    List<String> attachmentIds = const [],
    List<({String type, String id})> mentions = const [],
  }) async {
    if (failNextSend) {
      failNextSend = false;
      throw StateError('scripted send failure');
    }
    if (!_all.any((c) => c.id == conversationId)) {
      throw StateError('conversation not found: $conversationId');
    }
    final now = DateTime.now();
    final rows = _messages.putIfAbsent(conversationId, () => []);
    rows.add(ChatMessage(
      id: 'msg_fx_u${_idSeq++}',
      conversationId: conversationId,
      role: 'user',
      status: 'completed',
      attrs: {
        if (attachmentIds.isNotEmpty) 'attachments': attachmentIds,
        if (mentions.isNotEmpty)
          'mentions': [
            for (final m in mentions) {'type': m.type, 'id': m.id, 'name': m.id, 'content': ''},
          ],
      },
      blocks: [
        ChatBlock(id: 'blk_fx_${_idSeq++}', type: 'text', content: content, status: 'completed'),
      ],
      createdAt: now,
    ));
    final assistantId = 'msg_fx_a${_idSeq++}';
    rows.add(ChatMessage(
      id: assistantId, conversationId: conversationId, role: 'assistant', status: 'pending', createdAt: now,
    ));
    _mutate(conversationId, (c) => c.copyWith(lastMessageAt: now, hasUnread: false));
    lastSend = (conversationId: conversationId, content: content, mentions: mentions, assistantId: assistantId);
    lastSendAttachmentIds = attachmentIds;
    return assistantId;
  }

  @override
  Future<void> cancelTurn(String conversationId) async {
    cancelled.add(conversationId); // the terminal frame is the DEMO SCRIPT's job (mirrors the stream) 终帧归脚本
  }

  @override
  Future<void> markSeen(String conversationId) async {
    seen.add(conversationId);
    _mutate(conversationId, (c) => c.copyWith(hasUnread: false));
  }

  @override
  Future<Conversation> setModelOverride(String id, ({String apiKeyId, String modelId})? ref) async =>
      _mutate(
        id,
        (c) => ref == null
            ? c.copyWith(modelOverride: null)
            : c.copyWith(modelOverride: ModelRef(apiKeyId: ref.apiKeyId, modelId: ref.modelId)),
      );

  @override
  Stream<StreamEnvelope> conversationFrames(String conversationId) =>
      (_frames[conversationId] ??= StreamController<StreamEnvelope>.broadcast()).stream;

  final Map<String, StreamController<StreamEnvelope>> _frames = {};

  /// What sendMessage / cancel / seen recorded — assertion + demo-script hooks. 发送/取消/已读的记录钩。
  ({String conversationId, String content, List<({String type, String id})> mentions, String assistantId})? lastSend;
  List<String> lastSendAttachmentIds = const [];
  final List<String> cancelled = [];
  final List<String> seen = [];

  /// Script one realtime frame into a conversation's feed (the demo's fake streaming + tests).
  /// 向某会话的帧流脚本化推一帧(demo 假流式 + 测试)。
  void emitFrame(String conversationId, StreamEnvelope envelope) =>
      (_frames[conversationId] ??= StreamController<StreamEnvelope>.broadcast()).add(envelope);

  /// Seedable picker options. 可种的选择器选项。
  List<ModelCapability> capabilities = const [];

  @override
  Future<List<ModelCapability>> listModelCapabilities() async => capabilities;

  @override
  Stream<void> transcriptResync() => _resync.stream;
  final StreamController<void> _resync = StreamController.broadcast();

  /// Script a messages-stream 410 (tests: the controller must drop live + refetch). 脚本化 410。
  void emitResync() => _resync.add(null);

  /// Append a persisted message row (so a later hydration/refetch sees it — the demo script finalizes
  /// its scripted turn through this). 落一条持久消息(后续水化可见;demo 脚本借此定格已完成回合)。
  void appendMessage(String conversationId, ChatMessage message) =>
      _messages.putIfAbsent(conversationId, () => []).add(message);

  /// Replace a persisted row by id (the demo script settles the pending assistant row it minted).
  /// 按 id 替换持久行(demo 脚本把铸出的 pending assistant 行定格成完成态)。
  void replaceMessage(String conversationId, ChatMessage message) {
    final rows = _messages.putIfAbsent(conversationId, () => []);
    final i = rows.indexWhere((m) => m.id == message.id);
    i < 0 ? rows.add(message) : rows[i] = message;
  }

  // ── realtime scripting (tests / demo) ──

  /// Seed or replace a row (a server-side create fetchable via [getConversation], or an out-of-band edit),
  /// WITHOUT emitting — pair with [emitSignal]. 落/替一行(不发信号,配 emitSignal 用)。
  void upsert(Conversation c) {
    final i = _all.indexWhere((r) => r.id == c.id);
    i < 0 ? _all.add(c) : _all[i] = c;
  }

  /// Push a lifecycle signal to subscribers (the list notifier). 向订阅者(list notifier)推一条生命周期信号。
  void emitSignal(ConversationSignal signal) => _lazySignals.add(signal);

  /// Uploaded attachments in order; [failNextUpload] scripts the failed-chip path. 上传记录+失败脚本。
  final List<({String id, String filename, String? mimeType, int size})> uploads = [];
  final List<String> deletedAttachments = [];
  bool failNextUpload = false;

  @override
  Future<AttachmentMeta> uploadAttachment({
    required List<int> bytes,
    required String filename,
    String? mimeType,
  }) async {
    if (failNextUpload) {
      failNextUpload = false;
      throw StateError('scripted upload failure');
    }
    final id = 'att_fx_${_idSeq++}';
    uploads.add((id: id, filename: filename, mimeType: mimeType, size: bytes.length));
    return AttachmentMeta(
        id: id, filename: filename, mimeType: mimeType ?? '', sizeBytes: bytes.length,
        kind: (mimeType ?? '').startsWith('image/') ? 'image' : 'other');
  }

  @override
  Future<void> deleteAttachment(String id) async => deletedAttachments.add(id);

  /// Seedable metadata rows for [getAttachment] (uploads are auto-visible too). 可种元数据行。
  final Map<String, AttachmentMeta> attachmentMetas = {};

  @override
  Future<AttachmentMeta> getAttachment(String id) async {
    final seeded = attachmentMetas[id];
    if (seeded != null) return seeded;
    final up = uploads.where((u) => u.id == id).firstOrNull;
    if (up == null) throw StateError('attachment not found: $id'); // mirrors 404
    return AttachmentMeta(
        id: id, filename: up.filename, mimeType: up.mimeType ?? '', sizeBytes: up.size,
        kind: (up.mimeType ?? '').startsWith('image/') ? 'image' : 'other');
  }

  /// Synchronous row peek for scripts (null when absent — no throw). 脚本用同步查行(缺=null,不抛)。
  Conversation? conversationOrNull(String id) {
    final i = _all.indexWhere((r) => r.id == id);
    return i < 0 ? null : _all[i];
  }

  Future<void> dispose() async {
    await _signals?.close();
    await _resync.close();
    for (final c in _frames.values) {
      await c.close();
    }
  }
}
