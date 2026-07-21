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
  PendingSend({
    required this.localId,
    required this.text,
    this.mentions = const [],
    this.attachmentIds = const [],
  });

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

  // Subagent sub-messages (subagentId ≠ '') held aside from [settled] until folded under their spawning
  // tool_call by [attrs.parentBlockId] (WRK-064 B6). A sub whose parent hasn't loaded yet stays PENDING
  // (re-tried on every later page); [_foldedSubs] guards each from folding twice. 待折子消息 + 已折账。
  final List<ChatMessage> _subMessages = [];
  final Set<String> _foldedSubs = {};

  /// One live block by id (any depth) — the sidestage renders its subject straight off the reducer
  /// (WRK-061; live turns never migrate, so a streamed tool_call stays reachable here all session).
  /// 按 id 取 live 块(任意深)——侧幕直读 reducer 渲主角(live 回合永不搬迁,流过的 tool_call 全程可达)。
  BlockNode? liveBlock(String id) => _live.nodeById(id);

  /// The transcript turn containing [blockId] (any depth) — the jump anchor for a live-born block
  /// (R-14: a settle hands off to the transcript anchor; a role-式 Subagent has no Cast shadow, so
  /// this IS its only anchor). null when the block is unknown to the live layer.
  /// 含 [blockId] 的回合(任意深)——live 生块的跳转锚(R-14:谢幕交棒 transcript 锚;role 式 Subagent
  /// 台账无影,这就是它唯一的锚)。live 层不识该块时 null。
  String? messageIdOf(String blockId) {
    var node = _live.nodeById(blockId);
    while (node != null) {
      if (node.kind == BlockKind.message) return node.id;
      final p = node.parentId;
      node = (p == null || p.isEmpty) ? null : _live.nodeById(p);
    }
    return null;
  }

  /// Top-level live turns (message-kind roots only — orphan block frames are defensive no-shows).
  /// live 顶层回合(仅 message 根;孤儿块帧防御性不显)。
  List<BlockNode> get liveTurns => _live.roots
      .where((n) => n.kind == BlockKind.message)
      .toList(growable: false);

  /// The full render order: settled history, then everything live. 渲染全序:settled 史 + live。
  List<BlockNode> get turns => [...settled, ...liveTurns];

  /// Every `Subagent` tool_call across BOTH layers (settled history + the live reducer) — the sidestage
  /// lists each as a row (id=`block:<toolCallId>`): a live one rides its director channel, a
  /// closed/reloaded one rehydrates its folded nested trajectory as a settled subagent stage (WRK-064 B6).
  /// Deduped by id (a block lives in exactly one layer). 两层所有 Subagent tool_call(侧幕逐个列行)。
  List<BlockNode> get subagentBlocks {
    final out = <BlockNode>[];
    final seen = <String>{};
    void walk(BlockNode n) {
      if (n.kind == BlockKind.toolCall &&
          n.name == 'Subagent' &&
          seen.add(n.id)) {
        out.add(n);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final root in settled) {
      walk(root);
    }
    for (final root in _live.roots) {
      walk(root);
    }
    return out;
  }

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
  /// seeded into the live reducer so the ongoing stream continues it. Subagent sub-messages (subagentId ≠
  /// '') are NOT transcript turns — they fold under their spawning tool_call ([_foldSubagents]) so a
  /// settled subagent's nested trajectory rehydrates on the sidestage (WRK-064 B6).
  ///
  /// 用一页 REST 头([newestFirst] 线缆序)重置历史。终态回合水化进 settled(时间序);**一条**尾部未完回合
  /// (载入时在飞的回复)种进 live reducer,由进行中的流续写。subagent 子消息不入 transcript 回合——按
  /// parentBlockId 折进派它的 tool_call,使落定 subagent 的嵌套轨迹在侧幕重水合。
  void setHistory(List<ChatMessage> newestFirst) {
    settled.clear();
    _subMessages.clear();
    _foldedSubs.clear();
    olderCount = 0;
    windowMode = false;
    final tops = <ChatMessage>[];
    for (final m in newestFirst.reversed) {
      (m.subagentId.isEmpty ? tops : _subMessages).add(m);
    }
    for (var i = 0; i < tops.length; i++) {
      final m = tops[i];
      final isTail = i == tops.length - 1;
      if (isTail && !_isTerminal(m.status)) {
        _seedLive(m);
      } else {
        settled.add(hydrateTurn(m));
      }
    }
    _foldSubagents();
    _reconcilePendingWithSettled();
  }

  /// After a head re-hydrate (410 resync / back-to-live): a pending bubble whose send actually
  /// LANDED sits in the refetched head as a TERMINAL user turn — and terminal turns never re-echo
  /// on the live stream, so the FIFO echo reconcile can never consume it. Left alone it becomes a
  /// permanent duplicate bubble AND pins the composer in stop-state via hasInFlight (WRK-059 M4).
  /// Consume here instead: match in-flight (non-failed) bubbles FIFO against the TRAILING settled
  /// user turns by exact text (trailing only — deep history legitimately repeats phrases; the
  /// just-landed send is by construction near the end). Failed bubbles stay (retry/discard).
  ///
  /// 重拉头之后(410 重同步/回到现场):真落了盘的发送在新头页里是**终态** user 回合——终态回合不再产
  /// live 回声,FIFO 回声对账永远消费不到它,留下=永久重复泡+经 hasInFlight 卡死 composer(M4)。
  /// 在此消费:在飞(非失败)泡按 FIFO 与 settled **尾部** user 回合按原文匹配(只看尾部——深历史合理
  /// 重复短语,刚落的发送按构造必在尾部)。失败泡保留(retry/discard 不动)。
  void _reconcilePendingWithSettled() {
    final inFlight = pending.where((p) => !p.failed).length;
    if (inFlight == 0) return;
    // The trailing window: enough user turns to cover every in-flight bubble, plus slack for the
    // assistant replies interleaved between them. 尾窗:覆盖全部在飞泡的 user 回合数+穿插余量。
    final tailTexts = <String, int>{};
    var seen = 0;
    for (var i = settled.length - 1; i >= 0 && seen < inFlight + 2; i--) {
      final n = settled[i];
      if (turnRole(n) != 'user') continue;
      final txt = turnText(n).trim();
      tailTexts[txt] = (tailTexts[txt] ?? 0) + 1;
      seen++;
    }
    pending.removeWhere((p) {
      if (p.failed) return false;
      final c = tailTexts[p.text] ?? 0;
      if (c > 0) {
        tailTexts[p.text] = c - 1;
        return true;
      }
      return false;
    });
  }

  /// Prepend one older REST page ([newestFirst] wire order) above the loaded history. 上翻一页,插史前。
  void prependOlder(List<ChatMessage> newestFirst) {
    final rows = <BlockNode>[];
    for (final m in newestFirst.reversed) {
      if (m.subagentId.isEmpty) {
        rows.add(hydrateTurn(m));
      } else {
        _subMessages.add(
          m,
        ); // an older page may carry a subagent whose parent is already loaded 折向已载父
      }
    }
    settled.insertAll(0, rows);
    olderCount += rows.length;
    _foldSubagents();
  }

  // ── deep-jump window mode (W6 re-anchor) 深跳窗口模式 ──

  /// [settled] holds a DISJOINT `?around=` window instead of the head-attached pages. The view hides
  /// live/pending (they belong to the detached present — the「回到现场」pill restores them via a head
  /// re-hydrate); the live reducer keeps folding frames untouched so nothing is lost for the rejoin.
  /// The window is REPLACED wholesale, never stitched into contiguous pages (prependOlder is blind —
  /// a disjoint merge would duplicate rows or leave silent gaps).
  ///
  /// settled 持一扇非连续 `?around=` 窗、而非贴头分页。视图藏 live/pending(它们属于被离开的「现场」——
  /// 「回到现场」pill 经重拉头恢复);live reducer 照常折帧,归队时零损失。窗**整扇替换**、绝不与连续分页
  /// 缝合(prependOlder 是盲插——非连续合并必重复行或留静默断层)。
  bool windowMode = false;

  /// Replace [settled] with a jump window ([newestFirst] wire order), RE-ANCHORED on [targetId]: the
  /// target becomes the center sliver's first row (scroll offset 0 = the target at the anchor — zero
  /// extent estimation, the re-anchor move production chat apps converge on; older rows grow upward,
  /// newer rows downward, both directions page on).
  ///
  /// 用跳转窗([newestFirst] 线缆序)替换 settled、以 [targetId] **重锚**:目标成为 center sliver 首行
  /// (offset 0 = 目标落锚——零 extent 估算,生产级聊天收敛的 re-anchor 形;更旧向上长、更新向下长,双向续翻)。
  void setWindow(List<ChatMessage> newestFirst, String targetId) {
    settled.clear();
    _subMessages.clear();
    _foldedSubs.clear();
    windowMode = true;
    for (final m in newestFirst.reversed) {
      if (m.subagentId.isEmpty) {
        settled.add(hydrateTurn(m));
      } else {
        _subMessages.add(m);
      }
    }
    _foldSubagents();
    final i = settled.indexWhere((n) => n.id == targetId);
    olderCount = i < 0 ? 0 : i;
  }

  /// Re-center the anchor on an ALREADY-LOADED settled row — the near jump (no fetch, no mode
  /// change): the view then lands the target at offset 0. False when the id isn't loaded (the
  /// caller falls back to the deep window). 近跳:锚移到已加载行(零拉取零换模);未加载返 false 走深窗。
  bool retargetCenter(String targetId) {
    final i = settled.indexWhere((n) => n.id == targetId);
    if (i < 0) return false;
    olderCount = i;
    return true;
  }

  /// Append one NEWER page below the window ([newestFirst] wire order) — window mode's forward
  /// continuation (the `?dir=newer` closed loop). 窗下接一页更新(向前续翻闭环)。
  void appendNewer(List<ChatMessage> newestFirst) {
    for (final m in newestFirst.reversed) {
      if (m.subagentId.isEmpty) {
        settled.add(hydrateTurn(m));
      } else {
        _subMessages.add(m);
      }
    }
    _foldSubagents();
  }

  // ── live ──

  /// Fold one stream frame; reconcile a durable user echo against the oldest pending bubble.
  /// 折一帧;durable 用户回声对账最老乐观泡。
  void applyFrame(StreamEnvelope env) {
    _live.apply(env);
    if (!env.durable) return;
    final node = _live.nodeById(env.id);
    if (node == null ||
        node.kind != BlockKind.message ||
        turnRole(node) != 'user') {
      return;
    }
    // Consume the oldest bubble exactly once per echo node. 每回声节点恰消费一次最老泡。
    if (!_reconciledEchoes.contains(node.id)) {
      _reconciledEchoes.add(node.id);
      // Reconcile the oldest IN-FLIGHT (non-failed) bubble, NOT blindly removeAt(0): a leftover failed
      // bubble (an earlier send the user hasn't retried/discarded) must survive — consuming it would lose
      // its retry/discard AND leave the real send's optimistic bubble forever unreconciled (a permanent
      // duplicate that also pins the composer in stop-state via hasInFlight). 跳过失败泡,对账最老在飞泡。
      final idx = pending.indexWhere((p) => !p.failed);
      if (idx >= 0) {
        final p = pending.removeAt(idx);
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
            {
              'type': m.type,
              'id': m.id,
              'name': m.name,
              if (m.available) 'content': '',
            },
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

  void removePending(String localId) =>
      pending.removeWhere((p) => p.localId == localId);

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
      final node =
          BlockNode(
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
  static Map<String, dynamic> hydrateBlockContent(ChatBlock b) =>
      switch (blockKindFromWire(b.type)) {
        BlockKind.toolCall => {
          ...?b.attrs,
          'name': b.attrs?['tool'] ?? b.attrs?['name'] ?? '',
          if (b.attrs?['summary'] != null) 'summary': b.attrs?['summary'],
          if (b.attrs?['danger'] != null) 'danger': b.attrs?['danger'],
          if (b.attrs?['entityName'] != null)
            'entityName': b.attrs?['entityName'],
          'arguments': b.content,
        },
        BlockKind.progress => {...?b.attrs, 'text': b.content},
        _ => {...?b.attrs, 'content': b.content},
      };

  /// Fold every pending subagent sub-message under its spawning tool_call — by `attrs.parentBlockId`, as a
  /// `message` child so [SubagentStageBody]'s trajectory flattens it to the same E3 shape the live stream
  /// produces (WRK-064 B6). Idempotent: a sub folds ONCE ([_foldedSubs]); an ORPHAN (parent tool_call not
  /// in the loaded window yet) stays pending, re-tried when a later page brings the parent in. The sub's
  /// settle metadata (tokens / stopReason) lifts onto the tool_call so the card's settle line reads it.
  /// 把待折子消息按 parentBlockId 折进派它的 tool_call(作 message 子,复现 live E3 形)。幂等;孤儿待后页;
  /// 抬结算元数据到 tool_call。
  void _foldSubagents() {
    if (_subMessages.isEmpty) return;
    final byBlockId = <String, BlockNode>{};
    void index(BlockNode n) {
      if (n.kind == BlockKind.toolCall) byBlockId[n.id] = n;
      for (final c in n.children) {
        index(c);
      }
    }

    for (final root in settled) {
      index(root);
    }
    for (final sub in _subMessages) {
      if (_foldedSubs.contains(sub.id)) continue;
      final parentBlockId = sub.attrs?['parentBlockId'] as String?;
      if (parentBlockId == null || parentBlockId.isEmpty) continue;
      final parent = byBlockId[parentBlockId];
      if (parent == null) {
        continue; // orphan — parent tool_call not loaded yet 孤儿,待后页
      }
      _foldedSubs.add(sub.id);
      parent.children.add(
        hydrateTurn(sub),
      ); // the sub-run's message wrapper (its blocks nested) 子运行包装
      final content = parent.content;
      if (content != null) {
        if (content['tokens'] == null &&
            (sub.inputTokens > 0 || sub.outputTokens > 0)) {
          content['tokens'] = {'in': sub.inputTokens, 'out': sub.outputTokens};
        }
        if (content['stopReason'] == null && sub.stopReason.isNotEmpty) {
          content['stopReason'] = sub.stopReason;
        }
      }
    }
  }

  /// Seed a non-terminal REST turn into the live reducer via synthetic frames, so the ongoing stream's
  /// deltas / closes / child-opens land on known ids. Blocks already terminal get a synthetic close.
  /// 用合成帧把未完 REST 回合种进 live reducer,流的 delta/close/子块落在已知 id 上;已终块补合成 close。
  void _seedLive(ChatMessage m) {
    final scope = StreamScope(kind: 'conversation', id: conversationId);
    StreamEnvelope env(String id, StreamFrame frame) =>
        StreamEnvelope(seq: 1, scope: scope, id: id, frame: frame);

    _live.apply(
      env(
        m.id,
        FrameOpen(
          node: StreamNode(
            type: 'message',
            content: {'role': m.role, 'status': m.status, ...?m.attrs},
          ),
        ),
      ),
    );
    for (final b in m.blocks) {
      _live.apply(
        env(
          b.id,
          FrameOpen(
            parentId: b.parentBlockId.isEmpty ? m.id : b.parentBlockId,
            node: StreamNode(type: b.type, content: hydrateBlockContent(b)),
          ),
        ),
      );
      if (b.status == 'completed' ||
          b.status == 'error' ||
          b.status == 'cancelled') {
        _live.apply(
          env(
            b.id,
            FrameClose(
              status: b.status,
              error: b.error.isEmpty ? null : b.error,
              result: StreamNode(type: b.type, content: hydrateBlockContent(b)),
            ),
          ),
        );
      }
    }
  }
}
