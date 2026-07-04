import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/entities/values.dart';
import '../../../../core/graph/graph_edit_ops.dart';
import '../../../../core/graph/graph_model.dart';
import '../../data/entity_format.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../selected_entity.dart';
import 'entity_detail_provider.dart';
import 'workflow_editor_state.dart';

/// Sentinel id for the candidate edge while validating (never persisted). 校验期候选边的哨兵 id。
const _trialEdgeId = '__anselm_trial_edge__';

/// Edge-add validation, matching the backend's rules (graph.go ValidateGraph): no self-loop, and —
/// after the edge is added — EVERY back edge in the whole graph may leave ONLY a control/approval node.
/// The backend forbids duplicate edge IDs, NOT duplicate endpoints, so it only rejects an EXACT
/// duplicate (same source, target AND port); control/approval FAN-IN to one target via DIFFERENT ports
/// (approval yes+no, control's two branches) is legal. "Which edge is a back edge" is decided by the
/// SAME gray-node DFS the backend runs ([backEdgeIds], keyed on node/edge declaration order), because
/// the cycle a new edge closes can make a DIFFERENT edge the back edge — a plain reachability test on
/// the new edge alone diverges from the backend and yields false accepts/rejects. Returns the assigned
/// port (approval → the free yes/no slot; control gets an empty port the user fills; forward plain edge
/// → null). 加边校验(对齐后端 ValidateGraph):禁自环;加边后整图每条回边只可从 control·approval 出。后端禁
/// 重复边 id、非重复端点,故只拒完全重复(源/目标/端口全同);control/approval 用不同端口扇入同一目标(approval
/// yes+no、control 两分支)合法。"哪条是回边"用后端同款灰节点 DFS([backEdgeIds])判——新边闭合的环可能让另一
/// 条边成为回边。返回端口(approval→空闲 yes/no;control 空口待填;前向普通边→null)。
({bool ok, String? reason, String? port}) validateWorkflowEdge(Graph g, String from, String to) {
  if (from == to) return (ok: false, reason: 'selfLoop', port: null);
  final src = g.nodes.where((n) => n.id == from).firstOrNull;
  // Prospective port first (an approval source auto-takes the free yes/no slot), so the duplicate check
  // can be port-aware. 先定预期端口(approval 取空闲 yes/no),使重复检查能按端口区分。
  String? port;
  if (src?.kind == NodeKind.approval) {
    final used = g.edges.where((e) => e.from == from).map((e) => e.fromPort).toSet();
    port = !used.contains('yes') ? 'yes' : (!used.contains('no') ? 'no' : null);
    if (port == null) return (ok: false, reason: 'approvalPortsFull', port: null);
  }
  // Reject only an EXACT duplicate (source, target AND port all equal) — NOT any second (from,to).
  // 仅拒完全重复(源/目标/端口全同),非任意第二条 (from,to)。
  if (g.edges.any((e) => e.from == from && e.to == to && e.fromPort == port)) {
    return (ok: false, reason: 'duplicateEdge', port: null);
  }
  final trial = g.copyWith(edges: [
    ...g.edges,
    Edge(id: _trialEdgeId, from: from, fromPort: port, to: to),
  ]);
  final backs = backEdgeIds(trial);
  final byId = {for (final n in trial.nodes) n.id: n};
  for (final e in trial.edges) {
    if (!backs.contains(e.id)) continue;
    final k = byId[e.from]?.kind;
    if (k != NodeKind.control && k != NodeKind.approval) {
      return (ok: false, reason: 'backEdgeSource', port: null);
    }
  }
  return (ok: true, reason: null, port: port);
}

/// The graph editor (family over the workflow [EntityRef]). Loads the active-version graph into a
/// working copy, applies local structural edits, and saves the diff as one `:edit`. Not autoDispose
/// — the editor is a full route the user is actively working in; it's released when the route pops.
/// 图编辑器(按 workflow [EntityRef] family)。活跃版本图 → working 副本,本地结构编辑,保存 diff 成一个
/// `:edit`。非 autoDispose(编辑器是活跃的整页路由,pop 时释放)。
class WorkflowEditorNotifier extends AsyncNotifier<WorkflowEditorState> {
  WorkflowEditorNotifier(this.entityRef);

  final EntityRef entityRef;
  late EntityRepository _repo;
  int _idSeq = 0;

  @override
  Future<WorkflowEditorState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final wf = await _repo.getWorkflow(entityRef.id);
    final v = wf.activeVersion;
    final g = v == null ? const Graph() : (graphOf(v) ?? const Graph());
    return WorkflowEditorState(original: g, working: g);
  }

  void _mutate(Graph Function(Graph) f) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(working: f(cur.working), saveError: null));
  }

  // ── selection ──
  void selectNode(String? id) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(
        selectedNodeId: cur.selectedNodeId == id ? null : id, selectedEdgeId: null));
  }

  void selectEdge(String? id) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(selectedEdgeId: id, selectedNodeId: null));
  }

  // ── structure ──
  /// Add a node of [kind] at the graph centre-ish (a fresh pos so it doesn't stack). 加节点。
  void addNode(NodeKind kind) {
    final cur = state.value;
    if (cur == null) return;
    final id = _uniqueNodeId(kind, cur.working);
    final n = Node(
      id: id,
      kind: kind,
      ref: '${_prefix(kind)}_new',
      pos: NodePosition(x: 120 + (_idSeq % 5) * 40, y: 120 + (_idSeq % 5) * 40),
    );
    _idSeq++;
    _mutate((g) => g.copyWith(nodes: [...g.nodes, n]));
    selectNode(id);
  }

  void deleteSelected() {
    final cur = state.value;
    if (cur == null) return;
    final nodeId = cur.selectedNodeId, edgeId = cur.selectedEdgeId;
    if (nodeId != null) {
      _mutate((g) => g.copyWith(
            nodes: g.nodes.where((n) => n.id != nodeId).toList(),
            edges: g.edges.where((e) => e.from != nodeId && e.to != nodeId).toList(), // cascade 级联
          ));
      state = AsyncData(state.value!.copyWith(selectedNodeId: null));
    } else if (edgeId != null) {
      _mutate((g) => g.copyWith(edges: g.edges.where((e) => e.id != edgeId).toList()));
      state = AsyncData(state.value!.copyWith(selectedEdgeId: null));
    }
  }

  /// Move a node → persist its pos (drag end). Materializes the auto-layout into explicit pos on the
  /// FIRST drag: pos is respected only when EVERY node carries it (layout rule), so a lone dragged
  /// node in an unpositioned graph would otherwise snap back. 移动节点 → 落 pos。首次拖拽先把自动布局
  /// 固化成显式 pos(pos 仅当全节点都有时才生效,否则单个拖拽会弹回)。
  void moveNode(String id, NodePosition pos) {
    _ensurePositioned();
    _mutate((g) => g.copyWith(nodes: [
          for (final n in g.nodes) n.id == id ? n.copyWith(pos: pos) : n,
        ]));
  }

  /// Write the current auto-layout back as explicit pos on every node (no-op if already positioned).
  /// 把当前自动布局写回每节点的显式 pos(已定位则无操作)。
  void _ensurePositioned() {
    final cur = state.value;
    if (cur == null) return;
    final g = cur.working;
    if (g.nodes.isEmpty || g.nodes.every((n) => n.pos != null)) return;
    final l = layoutGraph(g, dir: cur.dir);
    state = AsyncData(cur.copyWith(working: g.copyWith(nodes: [
      for (final n in g.nodes)
        n.copyWith(
            pos: NodePosition(
                x: l.nodeRects[n.id]!.left.round(), y: l.nodeRects[n.id]!.top.round())),
    ])));
  }

  /// Attempt to connect [from]→[to]. Returns a reason string if rejected (caller toasts). 尝试连线。
  String? connect(String from, String to) {
    final cur = state.value;
    if (cur == null) return null;
    final v = validateWorkflowEdge(cur.working, from, to);
    if (!v.ok) return v.reason;
    // A fresh random edge id (NOT a per-session counter, which resets when this autoDispose provider
    // is rebuilt → a reopened editor would regenerate 'e0_new' and collide with the one already saved
    // into the graph, silently dropping the new edge at diff time). 全新随机边 id(非会话计数器——
    // autoDispose 重建即归零,重开编辑器会再生 'e0_new' 撞上已存入图的同 id,导致 diff 时静默吞掉新边)。
    final edge = Edge(id: _freshEdgeId(cur.working), from: from, fromPort: v.port, to: to);
    _mutate((g) => g.copyWith(edges: [...g.edges, edge]));
    selectEdge(edge.id);
    return null;
  }

  // ── inspector edits ──
  void setNodeRef(String id, String ref) => _mutate((g) => g.copyWith(nodes: [
        for (final n in g.nodes) n.id == id ? n.copyWith(ref: ref) : n,
      ]));

  /// Change a node's kind. The kind determines the ref's ENTITY FAMILY (action→callable, agent→ag_,
  /// …), so a kind change must reset the ref to the new kind's placeholder — otherwise the old ref
  /// (e.g. `fn_x`) would linger as a nonsense cross-family target in the ref picker. 改 kind → ref 家族
  /// 也变,故须把 ref 重置为新 kind 的占位(否则旧 ref 作跨族乱选目标留在选择器里)。
  void setNodeKind(String id, NodeKind kind) => _mutate((g) => g.copyWith(nodes: [
        for (final n in g.nodes)
          n.id == id
              ? (n.kind == kind ? n : n.copyWith(kind: kind, ref: '${_prefix(kind)}_new'))
              : n,
      ]));

  void setNodeInput(String id, Map<String, String> input) => _mutate((g) => g.copyWith(nodes: [
        for (final n in g.nodes) n.id == id ? n.copyWith(input: input) : n,
      ]));

  void setNodeRetry(String id, RetryConfig? retry) => _mutate((g) => g.copyWith(nodes: [
        for (final n in g.nodes) n.id == id ? n.copyWith(retry: retry) : n,
      ]));

  void setEdgePort(String id, String? port) => _mutate((g) => g.copyWith(edges: [
        for (final e in g.edges) e.id == id ? e.copyWith(fromPort: port) : e,
      ]));

  // ── layout ──
  /// Re-layout: drop every pos so the pure auto-layout takes over. 自动布局:清 pos 让自动布局接管。
  void autoLayout() => _mutate((g) => g.copyWith(nodes: [
        for (final n in g.nodes) n.copyWith(pos: null),
      ]));

  void setDir(GraphDirection dir) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(dir: dir));
  }

  // ── save / discard ──
  /// Diff working vs original → one `:edit`. On success the new version becomes the baseline; on
  /// WORKFLOW_INVALID_GRAPH/INVALID_OPS the reason is surfaced and the working copy is KEPT (fixable).
  /// diff → 一个 `:edit`。成功则新版本成基线;非法图/ops 则呈现理由、保留 working。
  Future<bool> save({String? changeReason}) async {
    final cur = state.value;
    if (cur == null || !cur.dirty || cur.saving) return false;
    // Snapshot the exact graph we diff + send. Edits the user makes DURING the await must not be
    // folded into the new baseline. 快照要 diff+发送的确切图;await 期间的编辑不得并入新基线。
    final committed = cur.working;
    final ops = workflowEditOps(cur.original, committed);
    if (ops.isEmpty) return false;
    state = AsyncData(cur.copyWith(saving: true, saveError: null));
    try {
      await _repo.editWorkflow(entityRef.id, ops, changeReason: changeReason);
      ref.invalidate(entityDetailProvider(entityRef));
      final now = state.value;
      if (now == null) return true;
      // New baseline = the snapshot we persisted, NOT now.working. now.working may carry edits made
      // during the await; setting original to it would mark them "saved" (dirty=false) though the
      // server never got them → data loss + a stuck-clean editor. Baselining to `committed` leaves
      // those edits as a live diff the user can still save. 新基线=已落盘的快照,非 now.working。后者可
      // 能含 await 期间的编辑,若设为基线会把它们标成已存(dirty=false)而服务器根本没收到 → 丢数据 +
      // 编辑器卡在假净态。基线设为 committed 让那些编辑仍是可再存的活 diff。
      state = AsyncData(now.copyWith(original: committed, saving: false));
      return true;
    } on ApiException catch (e) {
      final now = state.value;
      if (now != null) {
        final reason = e.details is Map ? (e.details as Map)['reason']?.toString() : null;
        state = AsyncData(now.copyWith(saving: false, saveError: reason ?? e.message));
      }
      return false;
    } catch (e) {
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(saving: false, saveError: e.toString()));
      return false;
    }
  }

  void discard() {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(
        working: cur.original, selectedNodeId: null, selectedEdgeId: null, saveError: null));
  }

  static final _rng = math.Random();

  /// A fresh, collision-checked edge id (`edg_<16hex>`, S15 shape). Client-authored so it must not
  /// reuse an existing id in the working graph. 全新、查重的边 id;客户端造,不得复用 working 中既有 id。
  static String _freshEdgeId(Graph g) {
    final ids = {for (final e in g.edges) e.id};
    String id;
    do {
      id = 'edg_${_hex16()}';
    } while (ids.contains(id));
    return id;
  }

  static String _hex16() {
    const chars = '0123456789abcdef';
    final b = StringBuffer();
    for (var i = 0; i < 16; i++) {
      b.write(chars[_rng.nextInt(16)]);
    }
    return b.toString();
  }

  static String _prefix(NodeKind k) => switch (k) {
        NodeKind.trigger => 'trg',
        NodeKind.action => 'fn',
        NodeKind.agent => 'ag',
        NodeKind.control => 'ctl',
        NodeKind.approval => 'apf',
        NodeKind.unknown => 'node',
      };

  static String _uniqueNodeId(NodeKind kind, Graph g) {
    final base = switch (kind) {
      NodeKind.trigger => 'trigger',
      NodeKind.action => 'task',
      NodeKind.agent => 'agent',
      NodeKind.control => 'route',
      NodeKind.approval => 'review',
      NodeKind.unknown => 'node',
    };
    final ids = {for (final n in g.nodes) n.id};
    if (!ids.contains(base)) return base;
    var i = 2;
    while (ids.contains('$base$i')) {
      i++;
    }
    return '$base$i';
  }
}

final workflowEditorProvider =
    AsyncNotifierProvider.autoDispose.family<WorkflowEditorNotifier, WorkflowEditorState, EntityRef>(
  WorkflowEditorNotifier.new,
  retry: (_, _) => null,
);
