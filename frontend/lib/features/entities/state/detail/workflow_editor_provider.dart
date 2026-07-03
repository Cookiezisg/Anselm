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

/// Edge-add validation, mirroring the backend's rules (graph.go): no self-loop, no duplicate
/// endpoints, and a back edge (target can already reach source) may leave ONLY a control/approval
/// node. Returns the assigned port (approval → yes/no; control gets an empty port the user fills in
/// the inspector; a forward plain edge → null). 加边校验(镜像后端):禁自环/禁重复端点/回边仅可从
/// control·approval 出。返回端口(approval→yes/no;control 空口待检查器填;前向普通边→null)。
({bool ok, String? reason, String? port}) validateWorkflowEdge(Graph g, String from, String to) {
  if (from == to) return (ok: false, reason: 'selfLoop', port: null);
  if (g.edges.any((e) => e.from == from && e.to == to)) {
    return (ok: false, reason: 'duplicateEdge', port: null);
  }
  final src = g.nodes.where((n) => n.id == from).firstOrNull;
  final isBack = _reachable(g, to, from);
  if (isBack && src?.kind != NodeKind.control && src?.kind != NodeKind.approval) {
    return (ok: false, reason: 'backEdgeSource', port: null);
  }
  String? port;
  if (src?.kind == NodeKind.approval) {
    final used = g.edges.where((e) => e.from == from).map((e) => e.fromPort).toSet();
    port = !used.contains('yes') ? 'yes' : (!used.contains('no') ? 'no' : null);
    if (port == null) return (ok: false, reason: 'approvalPortsFull', port: null);
  }
  return (ok: true, reason: null, port: port);
}

bool _reachable(Graph g, String from, String to) {
  final adj = <String, List<String>>{};
  for (final e in g.edges) {
    (adj[e.from] ??= []).add(e.to);
  }
  final seen = <String>{from};
  final q = <String>[from];
  while (q.isNotEmpty) {
    final u = q.removeAt(0);
    for (final v in adj[u] ?? const <String>[]) {
      if (v == to) return true;
      if (seen.add(v)) q.add(v);
    }
  }
  return false;
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
    final edge = Edge(id: 'e${_idSeq++}_new', from: from, fromPort: v.port, to: to);
    _mutate((g) => g.copyWith(edges: [...g.edges, edge]));
    selectEdge(edge.id);
    return null;
  }

  // ── inspector edits ──
  void setNodeRef(String id, String ref) => _mutate((g) => g.copyWith(nodes: [
        for (final n in g.nodes) n.id == id ? n.copyWith(ref: ref) : n,
      ]));

  void setNodeKind(String id, NodeKind kind) => _mutate((g) => g.copyWith(nodes: [
        for (final n in g.nodes) n.id == id ? n.copyWith(kind: kind) : n,
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
    final ops = workflowEditOps(cur.original, cur.working);
    if (ops.isEmpty) return false;
    state = AsyncData(cur.copyWith(saving: true, saveError: null));
    try {
      await _repo.editWorkflow(entityRef.id, ops, changeReason: changeReason);
      ref.invalidate(entityDetailProvider(entityRef));
      final now = state.value;
      if (now == null) return true;
      // New baseline = the just-saved working graph (also the server truth). 新基线=刚存的 working。
      state = AsyncData(now.copyWith(original: now.working, saving: false));
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
