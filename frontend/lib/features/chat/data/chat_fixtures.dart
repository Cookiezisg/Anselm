import 'dart:async';

import '../../../core/contract/attachment.dart';
import '../../../core/contract/conversation.dart';
import '../../../core/contract/interaction.dart';
import '../../../core/contract/messages/chat_message.dart';
import '../../../core/contract/messages/transcript_nav.dart';
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
import '../../../core/contract/mcp.dart';
import '../../../core/contract/todo.dart';
import '../../../core/contract/touchpoint.dart';
import '../../../core/sse/frame.dart';
import 'chat_repository.dart';
import 'conversation_signal.dart';
import 'turn_signal.dart';

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
  }) : _all = List.of(conversations ?? const []),
       _messages = {
         for (final e in (messages ?? const {}).entries)
           e.key: List.of(e.value),
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

  /// One-shot scripted list failure (the M9 loadMore retry path). 一次性列表失败脚本(M9)。
  bool failNextListConversations = false;

  @override
  Future<Page<Conversation>> listConversations({
    String? cursor,
    int? limit,
    ConvSort sort = ConvSort.activity,
    ConvArchive archive = ConvArchive.active,
    String? search,
  }) async {
    if (failNextListConversations) {
      failNextListConversations = false;
      throw StateError('scripted list failure');
    }
    final term = search?.trim().toLowerCase() ?? '';
    final rows = _all.where((c) {
      final scopeOk = switch (archive) {
        ConvArchive.active => !c.archived,
        ConvArchive.archivedOnly => c.archived,
        ConvArchive.all => true,
      };
      if (!scopeOk) return false;
      if (term.isNotEmpty && !c.title.toLowerCase().contains(term)) {
        return false;
      }
      return true;
    }).toList()..sort(_comparator(sort));
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
    if (!_all.any((c) => c.id == id)) {
      throw StateError('conversation not found: $id');
    }
    _all.removeWhere((c) => c.id == id);
  }

  @override
  Future<Conversation> getConversation(String id) async {
    final c = _all.where((c) => c.id == id).firstOrNull;
    if (c == null) {
      throw StateError(
        'conversation not found: $id',
      ); // mirrors 404 CONVERSATION_NOT_FOUND
    }
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
    emitSignal(
      ConversationSignal(
        id: c.id,
        action: ConversationAction.created,
        durable: true,
      ),
    );
    return c;
  }

  @override
  Future<Page<ChatMessage>> listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
  }) async {
    if (!_all.any((c) => c.id == conversationId)) {
      throw StateError('conversation not found: $conversationId');
    }
    // Wire order = newest-first (the backend's keyset), so hydration's reverse is exercised for real.
    // 线缆序=新→旧(后端 keyset 同款),水化的反转被真实演练。
    final newestFirst = (_messages[conversationId] ?? const <ChatMessage>[])
        .reversed
        .toList();
    return _page(newestFirst, cursor, limit);
  }

  @override
  Future<MessagesWindow> messagesAround(
    String conversationId,
    String messageId, {
    int? limit,
  }) async {
    if (!_all.any((c) => c.id == conversationId)) {
      throw StateError('conversation not found: $conversationId');
    }
    final chrono = _messages[conversationId] ?? const <ChatMessage>[];
    final idx = chrono.indexWhere((m) => m.id == messageId);
    if (idx < 0) {
      throw StateError(
        'message not found: $messageId',
      ); // identity anchoring: the backend 404s 身份锚点
    }
    final n = (limit ?? 50).clamp(2, 200);
    final beforeN = n ~/ 2;
    final lo = (idx - beforeN).clamp(0, chrono.length);
    final hi = (idx + (n - beforeN) + 1).clamp(0, chrono.length);
    // olderCursor feeds listMessages (newest-first offset); newerCursor feeds listMessagesNewer
    // (chronological offset) — the same closed loop as the backend's two cursors.
    // olderCursor 喂 listMessages(新→旧偏移)、newerCursor 喂 listMessagesNewer(时间序偏移)——与后端双游标同一闭环。
    return MessagesWindow(
      messages: chrono.sublist(lo, hi).reversed.toList(),
      targetId: messageId,
      olderCursor: lo > 0 ? '${chrono.length - lo}' : '',
      newerCursor: hi < chrono.length ? '$hi' : '',
      hasOlder: lo > 0,
      hasNewer: hi < chrono.length,
    );
  }

  @override
  Future<Page<ChatMessage>> listMessagesNewer(
    String conversationId, {
    required String cursor,
    int? limit,
  }) async {
    if (!_all.any((c) => c.id == conversationId)) {
      throw StateError('conversation not found: $conversationId');
    }
    final chrono = _messages[conversationId] ?? const <ChatMessage>[];
    final start = (int.tryParse(cursor) ?? 0).clamp(0, chrono.length);
    final end = (start + (limit ?? 50)).clamp(0, chrono.length);
    final more = end < chrono.length;
    // Data stays newest-first (the wire's single ordering rule). data 恒新→旧(线缆唯一排序规则)。
    return Page(
      items: chrono.sublist(start, end).reversed.toList(),
      nextCursor: more ? '$end' : null,
      hasMore: more,
    );
  }

  @override
  Future<Page<TranscriptAnchor>> listAnchors(
    String conversationId, {
    String? cursor,
    int? limit,
  }) async {
    if (!_all.any((c) => c.id == conversationId)) {
      throw StateError('conversation not found: $conversationId');
    }
    // A lite mirror of the backend's buildAnchors taxonomy over the seeded turns (no gate rows —
    // the fixture has no broker). 后端锚分类学的 lite 镜像(无 gate 行——fixture 无 broker)。
    final chrono = _messages[conversationId] ?? const <ChatMessage>[];
    final anchors = <TranscriptAnchor>[];
    var clusterCount = 0;
    ChatBlock? clusterFirst;
    var clusterMsg = '';
    DateTime clusterAt = DateTime.now();
    void flush() {
      if (clusterCount == 0) return;
      anchors.add(
        TranscriptAnchor(
          kind: 'tools',
          messageId: clusterMsg,
          blockId: clusterFirst!.id,
          count: clusterCount,
          at: clusterAt,
        ),
      );
      clusterCount = 0;
      clusterFirst = null;
    }

    String firstLine(String s) {
      for (final line in s.split('\n')) {
        final t = line.trim();
        if (t.isNotEmpty) return t.length > 120 ? '${t.substring(0, 120)}…' : t;
      }
      return '';
    }

    for (final m in chrono) {
      if (m.role == 'user') {
        flush();
        final text = m.blocks
            .where((b) => b.type == 'text')
            .map((b) => b.content)
            .join();
        anchors.add(
          TranscriptAnchor(
            kind: 'user',
            messageId: m.id,
            title: firstLine(text),
            at: m.createdAt,
          ),
        );
        continue;
      }
      for (final b in m.blocks) {
        if (b.type == 'compaction') {
          flush();
          anchors.add(
            TranscriptAnchor(
              kind: 'compaction',
              messageId: m.id,
              blockId: b.id,
              title: firstLine(b.content),
              at: b.createdAt ?? m.createdAt,
            ),
          );
        } else if (b.type == 'tool_call' && b.attrs?['danger'] == 'dangerous') {
          flush();
          final name = '${b.attrs?['tool'] ?? ''}';
          final entity = '${b.attrs?['entityName'] ?? ''}';
          anchors.add(
            TranscriptAnchor(
              kind: 'danger',
              messageId: m.id,
              blockId: b.id,
              title: entity.isEmpty ? name : '$name · $entity',
              at: b.createdAt ?? m.createdAt,
            ),
          );
        } else if (b.type == 'tool_call') {
          if (clusterCount == 0) {
            clusterFirst = b;
            clusterMsg = m.id;
            clusterAt = b.createdAt ?? m.createdAt;
          }
          clusterCount++;
        }
      }
      if (m.status == 'error' || m.status == 'cancelled') {
        flush();
        final title = m.stopReason.isNotEmpty
            ? m.stopReason
            : (m.errorCode.isNotEmpty ? m.errorCode : m.status);
        anchors.add(
          TranscriptAnchor(
            kind: 'abnormal',
            messageId: m.id,
            title: title,
            at: m.createdAt,
          ),
        );
      }
    }
    flush();
    var page = _page(anchors.reversed.toList(), cursor, limit ?? 50);
    if ((cursor ?? '').isEmpty) {
      // Live gates ride the first page's top, outside the keyset — the backend's broker rule
      // mirrored (they are live state, not journal rows). 活人闸骑首页顶,keyset 之外(镜像 broker 规则)。
      final gates = [
        for (final i in interactions[conversationId] ?? const <Interaction>[])
          if (!i.resolved)
            TranscriptAnchor(
              kind: 'gate',
              blockId: i.toolCallId,
              title: i.tool,
              at: DateTime.now(),
            ),
      ];
      if (gates.isNotEmpty) {
        page = Page(
          items: [...gates, ...page.items],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        );
      }
    }
    return page;
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
    rows.add(
      ChatMessage(
        id: 'msg_fx_u${_idSeq++}',
        conversationId: conversationId,
        role: 'user',
        status: 'completed',
        attrs: {
          if (attachmentIds.isNotEmpty) 'attachments': attachmentIds,
          if (mentions.isNotEmpty)
            'mentions': [
              for (final m in mentions)
                {'type': m.type, 'id': m.id, 'name': m.id, 'content': ''},
            ],
        },
        blocks: [
          ChatBlock(
            id: 'blk_fx_${_idSeq++}',
            type: 'text',
            content: content,
            status: 'completed',
          ),
        ],
        createdAt: now,
      ),
    );
    final assistantId = 'msg_fx_a${_idSeq++}';
    rows.add(
      ChatMessage(
        id: assistantId,
        conversationId: conversationId,
        role: 'assistant',
        status: 'pending',
        createdAt: now,
      ),
    );
    _mutate(
      conversationId,
      (c) => c.copyWith(lastMessageAt: now, hasUnread: false),
    );
    lastSend = (
      conversationId: conversationId,
      content: content,
      mentions: mentions,
      assistantId: assistantId,
    );
    lastSendAttachmentIds = attachmentIds;
    return assistantId;
  }

  @override
  Future<void> cancelTurn(String conversationId) async {
    cancelled.add(
      conversationId,
    ); // the terminal frame is the DEMO SCRIPT's job (mirrors the stream) 终帧归脚本
  }

  @override
  Future<void> markSeen(String conversationId) async {
    seen.add(conversationId);
    _mutate(conversationId, (c) => c.copyWith(hasUnread: false));
  }

  /// One-shot scripted modelOverride PATCH failure (the landing-first-send orphan path). 一次性模型盖章失败脚本。
  bool failNextModelOverride = false;

  @override
  Future<Conversation> setModelOverride(
    String id,
    ({String apiKeyId, String modelId})? ref,
  ) async {
    if (failNextModelOverride) {
      failNextModelOverride = false;
      throw StateError('scripted modelOverride failure');
    }
    return _mutate(
      id,
      (c) => ref == null
          ? c.copyWith(modelOverride: null)
          : c.copyWith(
              modelOverride: ModelRef(
                apiKeyId: ref.apiKeyId,
                modelId: ref.modelId,
              ),
            ),
    );
  }

  @override
  Stream<StreamEnvelope> conversationFrames(String conversationId) =>
      (_frames[conversationId] ??= StreamController<StreamEnvelope>.broadcast())
          .stream;

  final Map<String, StreamController<StreamEnvelope>> _frames = {};

  /// What sendMessage / cancel / seen recorded — assertion + demo-script hooks. 发送/取消/已读的记录钩。
  ({
    String conversationId,
    String content,
    List<({String type, String id})> mentions,
    String assistantId,
  })?
  lastSend;
  List<String> lastSendAttachmentIds = const [];
  final List<String> cancelled = [];
  final List<String> seen = [];

  /// Script one realtime frame into a conversation's feed (the demo's fake streaming + tests).
  /// 向某会话的帧流脚本化推一帧(demo 假流式 + 测试)。
  void emitFrame(String conversationId, StreamEnvelope envelope) =>
      (_frames[conversationId] ??= StreamController<StreamEnvelope>.broadcast())
          .add(envelope);

  /// Seedable picker options. 可种的选择器选项。

  // ── the sidestage's old-truth reads (seedable, WRK-061 R-5) 侧幕旧真相(可种) ──

  /// Seedable single-read snapshots; a missing id throws like the backend's 404. 可种单读;缺 id 抛(如 404)。
  final Map<String, FunctionEntity> functions = {};
  final Map<String, DocumentNode> documents = {};
  final Map<String, WorkflowEntity> workflows = {};
  final Map<String, ControlLogic> controls = {};
  final Map<String, ApprovalForm> approvals = {};
  final Map<String, TriggerEntity> triggers = {};
  final Map<String, AgentEntity> agents = {};
  final Map<String, HandlerEntity> handlers = {};
  final Map<String, Skill> skills = {};
  final Map<String, McpServerStatus> mcpServers = {};

  @override
  Future<FunctionEntity> getFunctionSnapshot(String id) async =>
      functions[id] ?? (throw StateError('function not found: $id'));

  @override
  Future<DocumentNode> getDocumentSnapshot(String id) async =>
      documents[id] ?? (throw StateError('document not found: $id'));

  @override
  Future<WorkflowEntity> getWorkflowSnapshot(String id) async =>
      workflows[id] ?? (throw StateError('workflow not found: $id'));

  @override
  Future<ControlLogic> getControlSnapshot(String id) async =>
      controls[id] ?? (throw StateError('control not found: $id'));

  @override
  Future<ApprovalForm> getApprovalSnapshot(String id) async =>
      approvals[id] ?? (throw StateError('approval not found: $id'));

  @override
  Future<TriggerEntity> getTriggerSnapshot(String id) async =>
      triggers[id] ?? (throw StateError('trigger not found: $id'));

  @override
  Future<AgentEntity> getAgentSnapshot(String id) async =>
      agents[id] ?? (throw StateError('agent not found: $id'));

  @override
  Future<Skill> getSkillSnapshot(String name) async =>
      skills[name] ?? (throw StateError('skill not found: $name'));

  @override
  Future<McpServerStatus> getMcpSnapshot(String name) async =>
      mcpServers[name] ?? (throw StateError('mcp server not found: $name'));

  @override
  Future<HandlerEntity> getHandlerSnapshot(String id) async =>
      handlers[id] ?? (throw StateError('handler not found: $id'));

  // ── the rundown (seedable + scriptable) 场记清单(可种+可脚本化) ──

  /// Seedable per-conversation main todo list. 可种主清单。
  final Map<String, ConversationTodos> todos = {};

  @override
  Future<ConversationTodos> getTodos(String conversationId) async =>
      todos[conversationId] ??
      ConversationTodos(conversationId: conversationId);

  /// Script one whole-list todo frame (durable, payload = the full list — the backend shape).
  /// 脚本化一帧 todo 整表(durable,payload=完整清单)。
  void emitTodos(ConversationTodos list, {int seq = 1}) {
    todos[list.conversationId] = list;
    emitFrame(
      list.conversationId,
      StreamEnvelope(
        seq: seq,
        scope: StreamScope(kind: 'conversation', id: list.conversationId),
        id: 'todo_${list.subagentId.isEmpty ? 'main' : list.subagentId}',
        frame: FrameSignal(
          node: StreamNode(type: 'todo', content: list.toJson()),
        ),
      ),
    );
  }

  // ── right island: the touchpoint ledger (scriptable) 触点台账(可脚本化) ──

  /// Seedable ledger rows per conversation — served sorted (lastAt DESC, id DESC) with keyset paging,
  /// mirroring the backend. 可种台账行;按后端同款排序分页。
  final Map<String, List<Touchpoint>> touchpoints = {};

  @override
  Future<Page<Touchpoint>> listTouchpoints(
    String conversationId, {
    String? cursor,
    int? limit,
    String? kind,
    TouchpointVerb? verb,
  }) async {
    final rows = List.of(touchpoints[conversationId] ?? const <Touchpoint>[])
      ..sort((a, b) {
        final t = b.lastAt.compareTo(a.lastAt);
        return t != 0 ? t : b.id.compareTo(a.id);
      });
    final filtered = rows
        .where(
          (r) =>
              (kind == null || r.itemKind == kind) &&
              (verb == null || r.verb == verb),
        )
        .toList(growable: false);
    return _page(filtered, cursor, limit ?? 50);
  }

  /// Script one ledger upsert AND its durable touchpoint Signal frame (payload = the full row), the
  /// way the backend records + pushes. 脚本化一次记账:落行 + 推 durable touchpoint 信号帧(payload=整行)。
  void touch(Touchpoint row, {int seq = 1}) {
    final rows = touchpoints[row.conversationId] ??= [];
    final i = rows.indexWhere((r) => r.id == row.id);
    if (i >= 0) {
      rows[i] = row;
    } else {
      rows.add(row);
    }
    emitFrame(
      row.conversationId,
      StreamEnvelope(
        seq: seq,
        scope: StreamScope(kind: 'conversation', id: row.conversationId),
        id: row.id,
        frame: FrameSignal(
          node: StreamNode(type: 'touchpoint', content: row.toJson()),
        ),
      ),
    );
  }

  // ── human-loop interactions (scriptable) 人在环交互(可脚本化) ──

  /// Seedable pending snapshot per conversation (what [listInteractions] returns). 可种的待决快照。
  final Map<String, List<Interaction>> interactions = {};

  /// Every resolveInteraction call, in order — assertion hook. 决议调用记录(断言钩)。
  final List<
    ({
      String conversationId,
      String toolCallId,
      InteractionAction action,
      String? answer,
    })
  >
  resolvedInteractions = [];

  /// Script the failed-resolve path (POST rejects → the provider restores the awaiting record).
  /// 脚本化决议失败(POST 拒 → provider 复原待决记录)。
  bool failNextResolve = false;

  @override
  Future<List<Interaction>> listInteractions(String conversationId) async =>
      List.of(interactions[conversationId] ?? const []);

  @override
  Future<void> resolveInteraction(
    String conversationId,
    String toolCallId, {
    required InteractionAction action,
    String? answer,
  }) async {
    if (failNextResolve) {
      failNextResolve = false;
      throw StateError('scripted resolve failure');
    }
    resolvedInteractions.add((
      conversationId: conversationId,
      toolCallId: toolCallId,
      action: action,
      answer: answer,
    ));
  }

  final Map<String, StreamController<StreamEnvelope>> _workflowStreams = {};

  @override
  Stream<StreamEnvelope> workflowFrames(String workflowId) => _workflowStreams
      .putIfAbsent(workflowId, StreamController<StreamEnvelope>.broadcast)
      .stream;

  /// Script one entities-stream frame onto a workflow scope (the run_terminal path). 脚本 workflow 帧。
  void emitWorkflowFrame(String workflowId, StreamEnvelope env) =>
      _workflowStreams
          .putIfAbsent(workflowId, StreamController<StreamEnvelope>.broadcast)
          .add(env);

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

  StreamController<TurnSignal>? _turnSignals;
  StreamController<TurnSignal> get _lazyTurnSignals =>
      _turnSignals ??= StreamController<TurnSignal>.broadcast();

  @override
  Stream<TurnSignal> turnSignals() => _lazyTurnSignals.stream;

  /// Script a turn-lifecycle signal (the rail dots' realtime feed). 脚本化回合生命周期信号(活态点实时源)。
  void emitTurnSignal(String conversationId, TurnSignalKind kind) =>
      _lazyTurnSignals.add((conversationId: conversationId, kind: kind));

  /// Uploaded attachments in order; [failNextUpload] scripts the failed-chip path. 上传记录+失败脚本。
  final List<({String id, String filename, String? mimeType, int size})>
  uploads = [];
  final List<String> deletedAttachments = [];
  final List<String> cancelledPreparations = [];
  final List<String> retriedPreparations = [];
  bool failNextUpload = false;
  AttachmentPreparation? nextUploadPreparation;

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
    uploads.add((
      id: id,
      filename: filename,
      mimeType: mimeType,
      size: bytes.length,
    ));
    attachmentBytes[id] = bytes;
    final prep = nextUploadPreparation;
    nextUploadPreparation = null;
    return AttachmentMeta(
      id: id,
      filename: filename,
      mimeType: mimeType ?? '',
      sizeBytes: bytes.length,
      kind: (mimeType ?? '').startsWith('image/') ? 'image' : 'other',
      preparation: prep,
    );
  }

  @override
  Future<void> deleteAttachment(String id) async => deletedAttachments.add(id);

  @override
  Future<AttachmentPreparation> cancelAttachmentPreparation(String id) async {
    cancelledPreparations.add(id);
    final prep = const AttachmentPreparation(
      status: 'cancelled',
      target: 'model-default',
    );
    final meta = await getAttachment(id);
    attachmentMetas[id] = meta.copyWith(preparation: prep);
    return prep;
  }

  @override
  Future<AttachmentPreparation> retryAttachmentPreparation(String id) async {
    retriedPreparations.add(id);
    final prep = const AttachmentPreparation(
      status: 'pending',
      target: 'model-default',
    );
    final meta = await getAttachment(id);
    attachmentMetas[id] = meta.copyWith(preparation: prep);
    return prep;
  }

  /// Seedable metadata rows for [getAttachment] (uploads are auto-visible too). 可种元数据行。
  final Map<String, AttachmentMeta> attachmentMetas = {};

  /// Seedable content bytes for [getAttachmentBytes] (uploads auto-fill). 可种内容字节(上传自动存)。
  final Map<String, List<int>> attachmentBytes = {};

  @override
  Future<List<int>> getAttachmentBytes(String id) async {
    final b = attachmentBytes[id];
    if (b == null) {
      throw StateError('attachment content not found: $id'); // mirrors 404
    }
    return b;
  }

  @override
  Future<AttachmentMeta> getAttachment(String id) async {
    final seeded = attachmentMetas[id];
    if (seeded != null) return seeded;
    final up = uploads.where((u) => u.id == id).firstOrNull;
    if (up == null) {
      throw StateError('attachment not found: $id'); // mirrors 404
    }
    return AttachmentMeta(
      id: id,
      filename: up.filename,
      mimeType: up.mimeType ?? '',
      sizeBytes: up.size,
      kind: (up.mimeType ?? '').startsWith('image/') ? 'image' : 'other',
    );
  }

  /// Synchronous row peek for scripts (null when absent — no throw). 脚本用同步查行(缺=null,不抛)。
  Conversation? conversationOrNull(String id) {
    final i = _all.indexWhere((r) => r.id == id);
    return i < 0 ? null : _all[i];
  }

  Future<void> dispose() async {
    await _signals?.close();
    await _turnSignals?.close();
    await _resync.close();
    for (final c in _frames.values) {
      await c.close();
    }
  }
}
