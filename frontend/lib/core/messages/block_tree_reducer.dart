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

  String get deltaText => _delta.toString();
  bool get isOpen => status == 'open';
  bool get isError => status == 'error';

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
      case FrameDelta(:final chunk):
        _byId[env.id]?._delta.write(chunk);
      case FrameClose(:final status, :final result, :final error):
        final n = _byId[env.id];
        if (n == null) return;
        n.status = status.isEmpty ? 'completed' : status;
        n.error = error;
        if (result?.content != null) n.content = result!.content;
      case FrameSignal():
        break; // a signal builds no tree node (flowrun tick / entity change handled elsewhere) 不建节点
    }
  }

  void clear() {
    roots.clear();
    _byId.clear();
  }
}
