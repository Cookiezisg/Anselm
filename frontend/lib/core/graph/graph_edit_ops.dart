/// Pure diff of a WORKING workflow graph against its ORIGINAL → the backend `:edit` ops that
/// reproduce it (WRK-055 W5). The editor mutates a local working copy freely (add/move/delete/retarget)
/// and calls this ONCE on save, so one edit session = one `:edit` = one new version — never a version
/// per drag. Ops mirror the backend's 7 verbs (domain/workflow/ops.go): add/update/delete for nodes
/// and edges; update carries a top-level merge PATCH (input/retry are replaced whole, matching the
/// backend). Node/Edge are freezed value types so `==` drives the change detection. No widgets.
///
/// 工作图(working)相对原图(original)的纯 diff → 复现它的后端 `:edit` ops(W5)。编辑器自由改本地副本
/// (加/移/删/改指向),保存时调此一次——一次编辑会话=一次 `:edit`=一个新版本,绝非每拖一版。ops 镜像
/// 后端 7 动词:节点/边各 add/update/delete;update 带顶层 merge patch(input/retry 整体替换,同后端)。
/// Node/Edge 是 freezed 值类型,`==` 驱动变更检测。无 widget。
library;

import '../contract/entities/values.dart';

/// The wire form of one node for add_node (omits empty fields, like the backend/demo). 节点线缆形。
Map<String, Object?> nodeWire(Node n) => {
  'id': n.id,
  'kind': n.kind.name,
  'ref': n.ref,
  if (n.input.isNotEmpty) 'input': n.input,
  if (n.retry != null) 'retry': _retryWire(n.retry!),
  if (n.pos != null) 'pos': {'x': n.pos!.x, 'y': n.pos!.y},
  if ((n.notes ?? '').isNotEmpty) 'notes': n.notes,
};

Map<String, Object?> _retryWire(RetryConfig r) => {
  'maxAttempts': r.maxAttempts,
  if ((r.backoff ?? '').isNotEmpty) 'backoff': r.backoff,
  if (r.delayMs != null) 'delayMs': r.delayMs,
};

Map<String, Object?> _edgeWire(Edge e) => {
  'id': e.id,
  'from': e.from,
  if ((e.fromPort ?? '').isNotEmpty) 'fromPort': e.fromPort,
  'to': e.to,
};

/// Diff [original] → [working], emitting the minimal `:edit` ops. Deterministic order: node deletes,
/// node adds, node updates, then the same for edges (a delete_node cascades edges on the backend, so
/// edge ops touching a deleted node's edges are skipped — the backend already dropped them).
/// diff → 最小 ops。确定序:删点/加点/改点,再边同理(后端删点级联删边,故被删点的边 op 跳过)。
List<Map<String, Object?>> workflowEditOps(Graph original, Graph working) {
  final ops = <Map<String, Object?>>[];
  final oNodes = {for (final n in original.nodes) n.id: n};
  final wNodes = {for (final n in working.nodes) n.id: n};

  // Nodes removed → delete_node (the backend cascades their edges). 删点(后端级联删边)。
  final deletedNodeIds = <String>{};
  for (final id in oNodes.keys) {
    if (!wNodes.containsKey(id)) {
      ops.add({'op': 'delete_node', 'id': id});
      deletedNodeIds.add(id);
    }
  }
  // Nodes added → add_node. 加点。
  for (final n in working.nodes) {
    if (!oNodes.containsKey(n.id)) {
      ops.add({'op': 'add_node', 'node': nodeWire(n)});
    }
  }
  // Nodes changed → update_node with a merge patch of the changed fields. 改点(变更字段 patch)。
  for (final n in working.nodes) {
    final o = oNodes[n.id];
    if (o == null || o == n) continue;
    final patch = <String, Object?>{};
    if (o.kind != n.kind) patch['kind'] = n.kind.name;
    if (o.ref != n.ref) patch['ref'] = n.ref;
    if (o.input != n.input) {
      patch['input'] = n.input; // whole-map replace (backend contract) 整体替换
    }
    if (o.retry != n.retry) {
      patch['retry'] = n.retry == null ? null : _retryWire(n.retry!);
    }
    if (o.pos != n.pos) {
      patch['pos'] = n.pos == null ? null : {'x': n.pos!.x, 'y': n.pos!.y};
    }
    if (o.notes != n.notes) patch['notes'] = n.notes;
    if (patch.isNotEmpty) {
      ops.add({'op': 'update_node', 'id': n.id, 'patch': patch});
    }
  }

  final oEdges = {for (final e in original.edges) e.id: e};
  final wEdges = {for (final e in working.edges) e.id: e};
  // Edges removed → delete_edge, UNLESS their node was deleted (cascaded already). 删边(被删点的边跳过)。
  for (final e in original.edges) {
    if (wEdges.containsKey(e.id)) continue;
    if (deletedNodeIds.contains(e.from) || deletedNodeIds.contains(e.to)) {
      continue;
    }
    ops.add({'op': 'delete_edge', 'id': e.id});
  }
  // Edges added → add_edge. 加边。
  for (final e in working.edges) {
    if (!oEdges.containsKey(e.id)) {
      ops.add({'op': 'add_edge', 'edge': _edgeWire(e)});
    }
  }
  // Edges changed (only fromPort is patchable; from/to identity change = a different edge). 改边(仅 port)。
  for (final e in working.edges) {
    final o = oEdges[e.id];
    if (o == null || o == e) continue;
    if (o.fromPort != e.fromPort) {
      ops.add({
        'op': 'update_edge',
        'id': e.id,
        'patch': {'fromPort': e.fromPort},
      });
    }
  }
  return ops;
}

/// Apply `:edit` ops to a graph → the resulting graph (the pure inverse of [workflowEditOps]; the
/// backend's ops.go authority, mirrored for the fixture + round-trip tests). Unknown ops are skipped.
/// 把 `:edit` ops 应用到图 → 结果图(workflowEditOps 的纯逆;镜像后端 ops.go,供 fixture + 往返测试)。
Graph applyEditOps(Graph g, List<Map<String, Object?>> ops) {
  var nodes = [...g.nodes];
  var edges = [...g.edges];
  for (final op in ops) {
    switch (op['op']) {
      case 'add_node':
        nodes.add(Node.fromJson((op['node']! as Map).cast<String, dynamic>()));
      case 'delete_node':
        final id = op['id'];
        nodes = nodes.where((n) => n.id != id).toList();
        edges = edges
            .where((e) => e.from != id && e.to != id)
            .toList(); // cascade 级联
      case 'update_node':
        final id = op['id'];
        final patch = (op['patch']! as Map).cast<String, dynamic>();
        nodes = [for (final n in nodes) n.id == id ? _patchNode(n, patch) : n];
      case 'add_edge':
        edges.add(Edge.fromJson((op['edge']! as Map).cast<String, dynamic>()));
      case 'delete_edge':
        edges = edges.where((e) => e.id != op['id']).toList();
      case 'update_edge':
        final id = op['id'];
        final patch = (op['patch']! as Map).cast<String, dynamic>();
        edges = [
          for (final e in edges)
            e.id == id ? e.copyWith(fromPort: patch['fromPort'] as String?) : e,
        ];
    }
  }
  return Graph(nodes: nodes, edges: edges);
}

Node _patchNode(Node n, Map<String, dynamic> patch) {
  return n.copyWith(
    kind: patch.containsKey('kind')
        ? NodeKind.values.firstWhere(
            (k) => k.name == patch['kind'],
            orElse: () => NodeKind.unknown,
          )
        : n.kind,
    ref: patch.containsKey('ref') ? patch['ref'] as String : n.ref,
    input: patch.containsKey('input')
        ? (patch['input'] as Map?)?.cast<String, String>() ?? const {}
        : n.input,
    retry: patch.containsKey('retry')
        ? (patch['retry'] == null
              ? null
              : RetryConfig.fromJson(
                  (patch['retry'] as Map).cast<String, dynamic>(),
                ))
        : n.retry,
    pos: patch.containsKey('pos')
        ? (patch['pos'] == null
              ? null
              : NodePosition.fromJson(
                  (patch['pos'] as Map).cast<String, dynamic>(),
                ))
        : n.pos,
    notes: patch.containsKey('notes') ? patch['notes'] as String? : n.notes,
  );
}
