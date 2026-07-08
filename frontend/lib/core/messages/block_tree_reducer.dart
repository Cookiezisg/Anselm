import '../contract/messages/block_content.dart';
import '../sse/frame.dart';

/// One node in a streamed block tree — a single open→delta*→close lifecycle. Holds the live delta
/// accumulator (lossy, ephemeral) AND the durable `content` snapshot (the open content, then the close
/// `result` snapshot which is the reconnect truth). [displayText] prefers the snapshot, falling back to
/// the live deltas while still streaming. Children are ordered (E3 nesting via parentId).
///
/// 流式块树的一个节点(一次 open→delta*→close)。持有实时 delta 累加器(可丢)+ durable `content` 快照
/// (open 内容,后被 close result 快照覆盖——重连真相)。displayText 优先快照、流式中退回 delta。
class BlockNode {
  BlockNode({required this.id, required this.kind, this.parentId});

  final String id;
  final BlockKind kind;
  final String? parentId;

  final StringBuffer _delta = StringBuffer();
  Map<String, dynamic>? content;
  String status = 'open'; // open | completed | error | cancelled
  String? error;
  final List<BlockNode> children = [];

  /// Subtree version — the reducer bumps it on every frame touching this node OR any descendant
  /// (ancestor-chain walk), so a derivation over the whole subtree can be memoized by one integer
  /// (WRK-061 W0). 子树版本号:触及本节点或其后代的每一帧都使其自增(沿祖先链上溯)——子树派生按一个整数记忆化。
  int revision = 0;

  /// The most recently ACTIVE descendant (or self) — maintained by the reducer on every frame walking
  /// the ancestor chain (O(depth), §5-8's O(1)-per-read tail pointer). The subagent ensemble reads it
  /// as «当前动作» without traversing the subtree per build. 最近活动的后代(或自身)——reducer 沿祖先链
  /// 维护;群像读它当「当前动作」,build 期零子树遍历。
  BlockNode? lastDescendant;

  /// One revision-keyed memo slot for a FEATURE-side render projection (e.g. the chat tool card state).
  /// Untyped on purpose — core stays feature-agnostic; the owner compares [derivedCacheRev] == [revision].
  /// 特性侧渲染投影的记忆槽(revision 为键)。刻意无类型:core 不识上层,归属方自校版本。
  Object? derivedCache;
  int derivedCacheRev = -1;

  // deltaText materialization memoized by buffer length — live cards read it every frame (WRK-061 W0).
  // 物化按缓冲长度记忆化——活卡每帧都读。
  String? _deltaCache;
  int _deltaCacheLen = -1;

  String get deltaText {
    if (_delta.length != _deltaCacheLen) {
      _deltaCache = _delta.toString();
      _deltaCacheLen = _delta.length;
    }
    return _deltaCache!;
  }

  bool get isOpen => status == 'open';
  bool get isError => status == 'error';

  // Once the close snapshot covers what the delta buffer was feeding, the buffer is a redundant second
  // copy (a 1MB document would sit in memory twice) — release it. Kind picks the covering key: tool_call
  // deltas feed [argumentsText] (`arguments`), everything else feeds [displayText] (`content`/`text`).
  // close 快照盖住 delta 即释放缓冲(1MB 文档双份驻留)。tool_call 看 `arguments`,余看 `content`/`text`。
  void _releaseDeltaIfSnapshotted() {
    if (_delta.isEmpty) return;
    final snap = kind == BlockKind.toolCall
        ? (content?['arguments'])
        : (content?['content'] ?? content?['text']);
    if (snap is String && snap.isNotEmpty) {
      _delta.clear();
      _deltaCache = null;
      _deltaCacheLen = -1;
    }
  }

  /// The durable snapshot's text, else the live delta buffer. Most blocks (text/reasoning/tool_result)
  /// snapshot under `content`; a PROGRESS close snapshot uses `text` (loop/progress.go progressContent) —
  /// so read both or a live-closed progress block renders empty. 优先快照(progress 用 `text` 键),否则 delta。
  String get displayText {
    final snap = content?['content'] ?? content?['text'];
    if (snap is String && snap.isNotEmpty) return snap;
    return deltaText;
  }

  /// For tool_call: the final arguments JSON (close snapshot), else the streamed arg deltas.
  /// tool_call 的最终参数 JSON(close 快照),否则流式参数 delta。
  String get argumentsText {
    final args = content?['arguments'];
    if (args is String && args.isNotEmpty) return args;
    return deltaText;
  }

  String? get name => content?['name'] as String?;
  String? get danger => content?['danger'] as String?;
  String? get summary => content?['summary'] as String?;

  /// For tool_call: the display NAME of the call's primary target entity (backend-resolved from the arg
  /// id via the touchpoint Namer at close), so the UI shows "Run Function «sync_inventory»" not a bare id.
  /// null when the tool touches no nameable entity. tool_call 主目标实体显示名(后端关帧解析),空则 UI 留 id。
  String? get entityName => content?['entityName'] as String?;
}

/// The framework-agnostic, widget-free reducer that folds the SSE block frames (open/delta/close) of ONE
/// scope into a nested [BlockNode] tree — the pure model layer CLAUDE.md names ("BlockTreeReducer …
/// 承载性正确、须脱 widget/socket 单测"). It is the shared core of the agent run-terminal (STEP 5) and
/// the future Chat transcript (4.2). Frames are ephemeral (seq=0, lossy by design) — the reducer applies
/// every frame losslessly into the in-memory tree; the DB row / Execution transcript is the durable
/// truth (so a missed delta only costs live fidelity, never correctness). Signals build no tree node.
/// Defensive against out-of-order / orphaned frames (a delta/close for an unknown id is a no-op; an open
/// whose parent isn't seen yet attaches to roots).
///
/// 框架无关、脱 widget 的 reducer:把一个 scope 的块帧(open/delta/close)折成嵌套 [BlockNode] 树——
/// CLAUDE.md 点名的纯模型层。agent run 终端(STEP 5)与未来 Chat transcript(4.2)的共享核心。帧 ephemeral
/// (seq=0、设计上可丢),全部无损折入内存树;DB 行 / Execution transcript 才是 durable 真相。signal 不建节点。
/// 对乱序/孤儿帧设防(未知 id 的 delta/close 为 no-op;父未见的 open 挂根)。
class BlockTreeReducer {
  final List<BlockNode> roots = [];
  final Map<String, BlockNode> _byId = {};

  bool get isEmpty => roots.isEmpty;
  int get nodeCount => _byId.length;

  /// Look up a node by its tree id (for tests / correlation). 据树 id 取节点。
  BlockNode? nodeById(String id) => _byId[id];

  void apply(StreamEnvelope env) {
    switch (env.frame) {
      case FrameOpen(:final parentId, :final node):
        if (_byId.containsKey(env.id)) return; // idempotent re-open guard 幂等防重开
        final n = BlockNode(
          id: env.id,
          kind: blockKindFromWire(node.type),
          parentId: parentId,
        )..content = node.content;
        _byId[env.id] = n;
        final parent = (parentId != null && parentId.isNotEmpty)
            ? _byId[parentId]
            : null;
        (parent?.children ?? roots).add(n);
        _bump(n);
      case FrameDelta(:final chunk):
        final n = _byId[env.id];
        if (n == null) return;
        n._delta.write(chunk);
        _bump(n);
      case FrameClose(:final status, :final result, :final error):
        final n = _byId[env.id];
        if (n == null) return;
        n.status = status.isEmpty ? 'completed' : status;
        n.error = error;
        if (result?.content != null) {
          n.content = result!.content;
          n._releaseDeltaIfSnapshotted();
        }
        _bump(n);
      case FrameSignal():
        break; // a signal builds no tree node (flowrun tick / entity change handled elsewhere) 不建节点
    }
  }

  // Bump the node's revision and every ancestor's (subtree-version semantics; trees are shallow),
  // and point each ancestor's tail at the ACTIVE node (§5-8). 版本自增+祖先尾指针指向活动节点。
  void _bump(BlockNode n) {
    for (BlockNode? cur = n; cur != null;) {
      cur.revision++;
      cur.lastDescendant = n;
      final p = cur.parentId;
      cur = (p != null && p.isNotEmpty) ? _byId[p] : null;
    }
  }

  void clear() {
    roots.clear();
    _byId.clear();
  }
}
