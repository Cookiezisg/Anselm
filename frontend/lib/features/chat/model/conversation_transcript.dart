import '../../../core/contract/messages/block_content.dart';
import '../../../core/contract/messages/chat_message.dart';
import '../../../core/messages/block_tree_reducer.dart';
import '../../../core/sse/frame.dart';
import 'mention_spans.dart';

/// An optimistic user bubble awaiting its stream echo. [localId] is client-minted (never a msg_ id);
/// [failed] flips on a send error (the bubble grows retry/discard affordances). [mentions] are the
/// composer's local snapshots — merged into the echo when it lands, because the SSE user echo carries
/// attachmentIds but NOT mentions (REST reload has both).
///
/// 乐观用户泡(等回声)。localId 客户端铸(绝非 msg_);failed 在发送失败时翻(泡长出重试/丢弃)。mentions 是
/// composer 本地快照——回声落地时并进去(SSE 用户回声带 attachmentIds、**不带 mentions**;REST 重载两者都有)。
class PendingSend {
  PendingSend(
      {required this.localId, required this.text, this.mentions = const [], this.attachmentIds = const []});

  final String localId;
  final String text;
  final List<MentionSnapshot> mentions;
  final List<String> attachmentIds;
  bool failed = false;
}

/// The transcript merge model for ONE conversation — pure Dart (framework-free, unit-tested like
/// [BlockTreeReducer]). Three layers, strictly separated so REST and the stream are NEVER double-fed:
///
///  - [settled] — turns COMPLETED BEFORE the live subscription, hydrated from REST rows into the same
///    [BlockNode] shape live frames produce (the past↔live boundary is invisible to the renderer).
///  - the LIVE reducer — every frame since subscribe folds here; a non-terminal REST tail turn (opened
///    before we subscribed) is SEEDED into it via synthetic frames, so later deltas/closes/child-opens
///    land on known ids instead of becoming orphan no-ops. No promotion ever happens — a live turn just
///    stays live (equivalent content, zero migration bugs).
///  - [pending] — optimistic user bubbles, reconciled FIFO against durable user-role echo roots (the
///    send API mints no client nonce; sends are serialized per thread, so first-echo⇢oldest-bubble is
///    sound — a cross-window race self-heals on reload).
///
/// 单会话 transcript 合并模型——纯 Dart(脱框架,BlockTreeReducer 同等待遇单测)。三层严格分离,REST 与流
/// **绝不双喂**:[settled]=订阅前已完成的回合(REST 行水化成与 live 帧同形的 BlockNode);live reducer=订阅后
/// 的一切帧(REST 尾部未完回合经**合成帧种子**续接,后续 delta/close/子块落在已知 id 上、不成孤儿);
/// **永不搬迁**(live 回合就留在 live——内容等价、零迁移 bug)。[pending]=乐观泡,对 durable 用户回声 FIFO 对账
/// (发送 API 无 client nonce;每线程发送串行,首回声⇢最老泡成立;跨窗竞态重载自愈)。
class ConversationTranscript {
  ConversationTranscript(this.conversationId);

  final String conversationId;

  final List<BlockNode> settled = [];
  final BlockTreeReducer _live = BlockTreeReducer();
  final List<PendingSend> pending = [];
  final Set<String> _reconciledEchoes = {};
  // The consumed bubble's local mentions, keyed by echo node id — RE-applied after every durable frame,
  // because the echo's CLOSE snapshot overwrites content wholesale (it would wipe a one-shot merge).
  // 被消费泡的本地提及(按回声节点 id)——每个 durable 帧后**补写**,因回声 close 快照整体覆写 content(一次性
  // 并入会被抹)。
  final Map<String, List<MentionSnapshot>> _echoMentions = {};

  /// Top-level live turns (message-kind roots only — orphan block frames are defensive no-shows).
  /// live 顶层回合(仅 message 根;孤儿块帧防御性不显)。
  List<BlockNode> get liveTurns =>
      _live.roots.where((n) => n.kind == BlockKind.message).toList(growable: false);

  /// The full render order: settled history, then everything live. 渲染全序:settled 史 + live。
  List<BlockNode> get turns => [...settled, ...liveTurns];

  /// An assistant turn is streaming right now. 有 assistant 回合正在流。
  bool get isGenerating =>
      liveTurns.any((n) => n.isOpen && turnRole(n) == 'assistant');

  /// Something is in flight: an unacked optimistic send OR a streaming turn — drives send↔stop.
  /// 在飞:未回声的乐观发送 或 流中回合——驱动 send↔stop。
  bool get hasInFlight => pending.any((p) => !p.failed) || isGenerating;

  bool get isEmpty => settled.isEmpty && _live.isEmpty && pending.isEmpty;

  // ── hydration (REST → the live shape) 水化(REST → live 同形) ──

  /// How many rows at the FRONT of [settled] came from [prependOlder] — the view's center-sliver split
  /// (older pages grow upward around the anchor, so a prepend never shifts pixels). Reset by [setHistory].
  /// settled 前部来自 prependOlder 的行数——视图 center-sliver 的切分点(老页绕锚向上长,prepend 零位移)。
  int olderCount = 0;

  /// Replace history with one REST head page ([newestFirst], the wire order). Terminal turns hydrate to
  /// [settled] (chronological); ONE trailing non-terminal turn (a reply in flight when we loaded) is
  /// seeded into the live reducer so the ongoing stream continues it. Top-level only — subagent rows
  /// (subagentId ≠ '') never render as transcript turns.
  ///
  /// 用一页 REST 头([newestFirst] 线缆序)重置历史。终态回合水化进 settled(时间序);**一条**尾部未完回合
  /// (载入时在飞的回复)种进 live reducer,由进行中的流续写。仅顶层——subagent 行不入 transcript。
  void setHistory(List<ChatMessage> newestFirst) {
    settled.clear();
    olderCount = 0;
    final chronological =
        newestFirst.reversed.where((m) => m.subagentId.isEmpty).toList(growable: false);
    for (var i = 0; i < chronological.length; i++) {
      final m = chronological[i];
      final isTail = i == chronological.length - 1;
      if (isTail && !_isTerminal(m.status)) {
        _seedLive(m);
      } else {
        settled.add(hydrateTurn(m));
      }
    }
  }

  /// Prepend one older REST page ([newestFirst] wire order) above the loaded history. 上翻一页,插史前。
  void prependOlder(List<ChatMessage> newestFirst) {
    final rows = newestFirst.reversed
        .where((m) => m.subagentId.isEmpty)
        .map(hydrateTurn)
        .toList(growable: false);
    settled.insertAll(0, rows);
    olderCount += rows.length;
  }

  // ── live ──

  /// Fold one stream frame; reconcile a durable user echo against the oldest pending bubble.
  /// 折一帧;durable 用户回声对账最老乐观泡。
  void applyFrame(StreamEnvelope env) {
    _live.apply(env);
    if (!env.durable) return;
    final node = _live.nodeById(env.id);
    if (node == null || node.kind != BlockKind.message || turnRole(node) != 'user') return;
    // Consume the oldest bubble exactly once per echo node. 每回声节点恰消费一次最老泡。
    if (!_reconciledEchoes.contains(node.id)) {
      _reconciledEchoes.add(node.id);
      if (pending.isNotEmpty) {
        final p = pending.removeAt(0);
        if (p.mentions.isNotEmpty) _echoMentions[node.id] = p.mentions;
      }
    }
    // The echo carries no mentions on the wire — RE-apply the consumed bubble's local snapshots after
    // every durable frame (the close snapshot overwrites content wholesale and would wipe them).
    // 回声线缆不带 mentions——每个 durable 帧后补写本地快照(close 快照整体覆写 content、会抹掉)。
    final local = _echoMentions[node.id];
    if (local != null && (node.content?['mentions'] == null)) {
      node.content = {
        ...?node.content,
        'mentions': [
          for (final m in local)
            {'type': m.type, 'id': m.id, 'name': m.name, if (m.available) 'content': ''},
        ],
      };
    }
  }

  /// Drop the live layer (410 resync: the caller refetches the head via [setHistory], which re-seeds any
  /// still-running turn). Pending bubbles survive — an unacked send may still echo after resume.
  /// 丢 live 层(410:调用方随后 setHistory 重拉头、重种在飞回合)。乐观泡保留——未回声的发送恢复后仍可能回声。
  void dropLive() {
    _live.clear();
    _reconciledEchoes.clear();
    _echoMentions.clear();
  }

  // ── optimistic sends 乐观发送 ──

  void addPending(PendingSend p) => pending.add(p);

  void markPendingFailed(String localId) {
    for (final p in pending) {
      if (p.localId == localId) p.failed = true;
    }
  }

  void removePending(String localId) => pending.removeWhere((p) => p.localId == localId);

  // ── shape helpers (shared by hydration + the view) 形状助手(水化+视图共用) ──

  static bool _isTerminal(String status) =>
      status == 'completed' || status == 'error' || status == 'cancelled';

  static String turnRole(BlockNode n) => (n.content?['role'] as String?) ?? '';

  /// A user turn's text: inline on the live echo (`messageUserContent.content`), a child text block on
  /// REST reload — read both, or a live-echoed turn renders an empty bubble.
  /// 用户回合文本:live 回声内联、REST 重载在子 text 块——两处都读,否则回声泡渲空。
  static String turnText(BlockNode n) {
    final inline = n.content?['content'];
    if (inline is String && inline.trim().isNotEmpty) return inline;
    return n.children
        .where((c) => c.kind == BlockKind.text)
        .map((c) => c.displayText)
        .join('\n')
        .trim();
  }

  /// The frozen attachment ids: REST attrs key `attachments`, live echo key `attachmentIds`.
  /// 冻结附件 id:REST 键 attachments、live 回声键 attachmentIds。
  static List<String> turnAttachmentIds(BlockNode n) {
    final v = n.content?['attachments'] ?? n.content?['attachmentIds'];
    return v is List ? v.whereType<String>().toList(growable: false) : const [];
  }

  /// The frozen mention snapshots (REST attrs / reconciled locals). Availability = the `content` key
  /// exists (the backend's "(unavailable)" stub omits it). 冻结提及快照;可用性=有 content 键。
  static List<MentionSnapshot> turnMentions(BlockNode n) {
    final v = n.content?['mentions'];
    if (v is! List) return const [];
    return [
      for (final e in v.whereType<Map>())
        MentionSnapshot(
          type: (e['type'] as String?) ?? '',
          id: (e['id'] as String?) ?? '',
          name: (e['name'] as String?) ?? '',
          available: e.containsKey('content'),
        ),
    ];
  }

  /// Hydrate one REST turn into the node shape live frames produce. The message-level wire fields ride
  /// the root's content (the turn-end banner reads stopReason/errorCode there); blocks nest by
  /// parentBlockId. Per-type attrs↔content reconciliation lives in [hydrateBlockContent].
  /// 把一条 REST 回合水化成 live 同形节点:消息级字段上根 content(终态 banner 读之);块按 parentBlockId 嵌套。
  static BlockNode hydrateTurn(ChatMessage m) {
    final root = BlockNode(id: m.id, kind: BlockKind.message)
      ..content = {
        'role': m.role,
        'status': m.status,
        if (m.stopReason.isNotEmpty) 'stopReason': m.stopReason,
        if (m.errorCode.isNotEmpty) 'errorCode': m.errorCode,
        if (m.errorMessage.isNotEmpty) 'errorMessage': m.errorMessage,
        'inputTokens': m.inputTokens,
        'outputTokens': m.outputTokens,
        ...?m.attrs,
      }
      ..status = _isTerminal(m.status) ? m.status : 'open';
    final byId = <String, BlockNode>{};
    for (final b in m.blocks) {
      final node = BlockNode(
        id: b.id,
        kind: blockKindFromWire(b.type),
        parentId: b.parentBlockId.isEmpty ? m.id : b.parentBlockId,
      )
        ..content = hydrateBlockContent(b)
        ..status = b.status.isEmpty ? 'completed' : b.status
        ..error = b.error.isEmpty ? null : b.error;
      byId[b.id] = node;
      (byId[b.parentBlockId] ?? root).children.add(node);
    }
    return root;
  }

  /// Persisted block → the live content-map shape. Live frames carry tool metadata INLINE in content;
  /// REST rows keep it in attrs and the column in `content` — reconcile per type so one renderer serves
  /// both. progress's snapshot key is `text` (the wire asymmetry), preserved as-is.
  /// 持久块 → live content 形。live 帧的工具元数据内联在 content;REST 在 attrs+content 列——按型对齐,一个
  /// 渲染器吃两边。progress 快照键是 `text`(线缆不对称),原样保留。
  static Map<String, dynamic> hydrateBlockContent(ChatBlock b) => switch (blockKindFromWire(b.type)) {
        BlockKind.toolCall => {
            ...?b.attrs,
            'name': b.attrs?['tool'] ?? b.attrs?['name'] ?? '',
            if (b.attrs?['summary'] != null) 'summary': b.attrs?['summary'],
            if (b.attrs?['danger'] != null) 'danger': b.attrs?['danger'],
            'arguments': b.content,
          },
        BlockKind.progress => {...?b.attrs, 'text': b.content},
        _ => {...?b.attrs, 'content': b.content},
      };

  /// Seed a non-terminal REST turn into the live reducer via synthetic frames, so the ongoing stream's
  /// deltas / closes / child-opens land on known ids. Blocks already terminal get a synthetic close.
  /// 用合成帧把未完 REST 回合种进 live reducer,流的 delta/close/子块落在已知 id 上;已终块补合成 close。
  void _seedLive(ChatMessage m) {
    final scope = StreamScope(kind: 'conversation', id: conversationId);
    StreamEnvelope env(String id, StreamFrame frame) =>
        StreamEnvelope(seq: 1, scope: scope, id: id, frame: frame);

    _live.apply(env(
      m.id,
      FrameOpen(
        node: StreamNode(type: 'message', content: {
          'role': m.role,
          'status': m.status,
          ...?m.attrs,
        }),
      ),
    ));
    for (final b in m.blocks) {
      _live.apply(env(
        b.id,
        FrameOpen(
          parentId: b.parentBlockId.isEmpty ? m.id : b.parentBlockId,
          node: StreamNode(type: b.type, content: hydrateBlockContent(b)),
        ),
      ));
      if (b.status == 'completed' || b.status == 'error' || b.status == 'cancelled') {
        _live.apply(env(
          b.id,
          FrameClose(
            status: b.status,
            error: b.error.isEmpty ? null : b.error,
            result: StreamNode(type: b.type, content: hydrateBlockContent(b)),
          ),
        ));
      }
    }
  }
}
