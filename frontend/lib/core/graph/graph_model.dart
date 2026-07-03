/// The framework-free workflow-graph model layer (the `GraphModel` slot CLAUDE.md reserves next to
/// BlockTreeReducer): pure functions from a contract [Graph] to positioned geometry — back-edge
/// classification, Sugiyama-lite layered layout, floating-anchor orthogonal edge routing, loop
/// channels and content bounds. No widget/socket anywhere, so the whole thing unit-tests headless.
/// Ported 1:1 from the demo reference (demo/core/primitives/graph-canvas.js) with one deliberate
/// fix over it: persisted `pos` wins over auto-layout (the demo's own TODO — it unconditionally
/// overwrote dragged positions).
///
/// 框架无关的 workflow 图模型层(CLAUDE.md 预留的 GraphModel 位,与 BlockTreeReducer 并列):
/// 契约 [Graph] → 定位几何的纯函数——回边判定、Sugiyama-lite 分层布局、浮动锚正交边路由、回边
/// 通道与内容边界。零 widget/socket,整层可无头单测。从 demo 参照 1:1 移植,并修掉它自认的
/// TODO:持久化 `pos` 优先于自动布局(demo 无条件覆写拖拽位)。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../contract/entities/values.dart';

/// Layout flow direction. LR = layers advance left→right; TB = top→bottom.
/// 布局主轴方向:LR 层从左向右,TB 从上向下。
enum GraphDirection { lr, tb }

/// Graph geometry constants — mirrors the demo's canvas constants (graph-canvas.js:8) so the
/// Flutter render matches the reference pixel-for-pixel. These are the LAYOUT's own maths (node
/// slot size, layer gaps, edge stubs), not UI density tokens — they live with the layout.
/// 图几何常量(镜像 demo):布局自己的数学(节点槽/层距/出线柄),非 UI 密度 token,随布局层住。
abstract final class GraphGeometry {
  static const double nodeW = 188;
  static const double nodeH = 60;
  static const double gapX = 84; // main-axis layer gap (LR) 层间距·横
  static const double gapY = 44; // cross-axis sibling gap (LR) 兄弟间距·纵
  static const double pad = 48; // content padding on every side 内容四周留白
  static const double stub = 22; // straight lead-out before the first bend 拐弯前的直出线柄
  static const double corner = 12; // orthogonal-bend rounding radius 正交拐角圆角
  static const double loopFirst = 16; // first loop channel offset past the bounds 首条回边通道距界
  static const double loopGap = 26; // spacing between stacked loop channels 回边通道间距
  static const double loopTail = 8; // extra room after the last channel 末通道后余量
}

/// One routed edge: the orthogonal polyline (rounded at paint time), whether it is a back edge
/// (loop), and the mid-point along the line (the port-pill anchor).
/// 一条已路由的边:正交折点列(绘制时加圆角)+ 是否回边 + 线上中点(端口药丸锚)。
class GraphEdgeRoute {
  const GraphEdgeRoute({
    required this.edge,
    required this.isBack,
    required this.points,
    required this.mid,
  });

  final Edge edge;
  final bool isBack;
  final List<Offset> points;
  final Offset mid;
}

/// The positioned graph: node rects keyed by node id, routed edges, and the content size (bounds +
/// padding + loop channel). Everything a canvas needs to paint — and nothing it has to measure.
/// 定位完成的图:节点矩形(按 id)+ 已路由边 + 内容尺寸(界 + 留白 + 回边通道)。画布只画不量。
class GraphLayout {
  const GraphLayout({
    required this.graph,
    required this.nodeRects,
    required this.routes,
    required this.size,
    required this.backEdgeIds,
  });

  final Graph graph;
  final Map<String, Rect> nodeRects;
  final List<GraphEdgeRoute> routes;
  final Size size;
  final Set<String> backEdgeIds;
}

class _DfsFrame {
  _DfsFrame(this.id);
  final String id;
  int i = 0;
}

/// Classify back edges with the same iterative DFS gray-node walk the backend uses
/// (backend graph.go BackEdges / demo backEdges) — an edge into a node still on the DFS stack is a
/// back edge. Deterministic in declaration order, so the classification matches the backend's.
/// 回边判定:与后端同款迭代 DFS 灰节点算法——指向仍在栈上节点的边即回边。按声明序确定,与后端分类一致。
Set<String> backEdgeIds(Graph g) {
  final out = <String, List<Edge>>{};
  for (final e in g.edges) {
    (out[e.from] ??= <Edge>[]).add(e);
  }
  final color = <String, int>{}; // 0 white / 1 gray (on stack) / 2 black
  final back = <String>{};
  for (final n in g.nodes) {
    if (color[n.id] != null) continue;
    final stack = <_DfsFrame>[_DfsFrame(n.id)];
    color[n.id] = 1;
    while (stack.isNotEmpty) {
      final f = stack.last;
      final es = out[f.id] ?? const <Edge>[];
      if (f.i >= es.length) {
        color[f.id] = 2;
        stack.removeLast();
        continue;
      }
      final e = es[f.i++];
      final c = color[e.to] ?? 0;
      if (c == 1) {
        back.add(e.id);
      } else if (c == 0) {
        color[e.to] = 1;
        stack.add(_DfsFrame(e.to));
      }
    }
  }
  return back;
}

/// Lay out the whole graph. Persisted positions win: when EVERY node carries a `pos`, the authored
/// coordinates are used verbatim (normalized so the top-left node sits at the padding); any node
/// missing `pos` sends the whole graph through auto-layout — a mixed graph has no meaningful
/// mixed geometry (an authored island floating over an auto grid reads as broken).
/// 布局整图。持久化坐标优先:全节点带 `pos` 时逐字用之(归一化到留白起点);任一节点缺 `pos` 则整图
/// 自动布局——混合几何无意义(手摆孤岛浮在自动网格上读作坏)。
GraphLayout layoutGraph(Graph g, {GraphDirection dir = GraphDirection.lr}) {
  final back = backEdgeIds(g);
  final origins = <String, Offset>{};

  final allPinned = g.nodes.isNotEmpty && g.nodes.every((n) => n.pos != null);
  if (allPinned) {
    var minX = double.infinity, minY = double.infinity;
    for (final n in g.nodes) {
      minX = math.min(minX, n.pos!.x.toDouble());
      minY = math.min(minY, n.pos!.y.toDouble());
    }
    for (final n in g.nodes) {
      origins[n.id] = Offset(
        GraphGeometry.pad + n.pos!.x - minX,
        GraphGeometry.pad + n.pos!.y - minY,
      );
    }
  } else {
    _autoLayout(g, back, dir, origins);
  }

  final rects = <String, Rect>{
    for (final n in g.nodes)
      n.id: origins[n.id]! & const Size(GraphGeometry.nodeW, GraphGeometry.nodeH),
  };

  var maxX = GraphGeometry.nodeW, maxY = GraphGeometry.nodeH;
  for (final r in rects.values) {
    maxX = math.max(maxX, r.right);
    maxY = math.max(maxY, r.bottom);
  }

  // Loop channels stack past the far bounds (below for LR, right of for TB), earliest back edge
  // nearest the graph. 回边通道叠在远界外(LR 在下、TB 在右),先声明的贴图近。
  var loopIndex = 0;
  final loopOrd = <String, int>{};
  for (final e in g.edges) {
    if (back.contains(e.id)) loopOrd[e.id] = loopIndex++;
  }

  final routes = <GraphEdgeRoute>[];
  for (final e in g.edges) {
    final a = rects[e.from], b = rects[e.to];
    if (a == null || b == null) continue; // dangling edge — skip, never crash 悬挂边跳过不崩
    routes.add(back.contains(e.id)
        ? _loopRoute(e, a, b, loopOrd[e.id]!, maxX, maxY, dir)
        : _orthoRoute(e, a, b));
  }

  final channel = back.isEmpty
      ? 0.0
      : GraphGeometry.loopFirst + back.length * GraphGeometry.loopGap + GraphGeometry.loopTail;
  final size = Size(
    maxX + GraphGeometry.pad + (dir == GraphDirection.tb ? channel : 0),
    maxY + GraphGeometry.pad + (dir == GraphDirection.lr ? channel : 0),
  );

  return GraphLayout(graph: g, nodeRects: rects, routes: routes, size: size, backEdgeIds: back);
}

/// Sugiyama-lite: longest-path ranks over the forward (acyclic) edges, then 8 median-ordering
/// passes to untangle siblings, then grid coordinates with cross-axis centering — the demo's
/// layout() verbatim. 分层布局:前向边最长路定 rank → 8 趟中位数排序解交叉 → 网格坐标 + 交叉轴居中。
void _autoLayout(Graph g, Set<String> back, GraphDirection dir, Map<String, Offset> origins) {
  final succ = <String, List<String>>{};
  final pred = <String, List<String>>{};
  final indeg = <String, int>{};
  for (final n in g.nodes) {
    succ[n.id] = <String>[];
    pred[n.id] = <String>[];
    indeg[n.id] = 0;
  }
  for (final e in g.edges) {
    if (back.contains(e.id)) continue;
    if (!succ.containsKey(e.from) || !succ.containsKey(e.to)) continue;
    succ[e.from]!.add(e.to);
    pred[e.to]!.add(e.from);
    indeg[e.to] = indeg[e.to]! + 1;
  }

  final rank = <String, int>{};
  final queue = <String>[for (final n in g.nodes) if (indeg[n.id] == 0) n.id];
  for (final id in queue) {
    rank[id] = 0;
  }
  final ind = Map<String, int>.from(indeg);
  var qi = 0;
  while (qi < queue.length) {
    final u = queue[qi++];
    for (final v in succ[u]!) {
      rank[v] = math.max(rank[v] ?? 0, (rank[u] ?? 0) + 1);
      ind[v] = ind[v]! - 1;
      if (ind[v] == 0) queue.add(v);
    }
  }
  for (final n in g.nodes) {
    rank[n.id] ??= 0;
  }

  final maxRank = g.nodes.isEmpty ? 0 : g.nodes.map((n) => rank[n.id]!).reduce(math.max);
  final layers = List.generate(maxRank + 1, (_) => <String>[]);
  for (final n in g.nodes) {
    layers[rank[n.id]!].add(n.id);
  }

  final pos = <String, int>{};
  for (final layer in layers) {
    for (var i = 0; i < layer.length; i++) {
      pos[layer[i]] = i;
    }
  }
  int median(String id, Map<String, List<String>> adj) {
    final ps = [for (final x in adj[id]!) if (pos[x] != null) pos[x]!]..sort();
    if (ps.isEmpty) return pos[id]!;
    return ps[(ps.length - 1) >> 1];
  }

  for (var p = 0; p < 8; p++) {
    final down = p.isEven;
    final order = down
        ? List<int>.generate(layers.length, (i) => i)
        : List<int>.generate(layers.length, (i) => layers.length - 1 - i);
    for (final li in order) {
      final adj = down ? pred : succ;
      final scored = [for (final id in layers[li]) (id: id, m: median(id, adj))]
        ..sort((a, b) => a.m.compareTo(b.m));
      layers[li] = [for (final s in scored) s.id];
      for (var i = 0; i < layers[li].length; i++) {
        pos[layers[li][i]] = i;
      }
    }
  }

  final horiz = dir == GraphDirection.lr;
  final main = horiz
      ? GraphGeometry.nodeW + GraphGeometry.gapX
      : GraphGeometry.nodeH + GraphGeometry.gapY;
  final cross = horiz
      ? GraphGeometry.nodeH + GraphGeometry.gapY
      : GraphGeometry.nodeW + GraphGeometry.gapX;
  final maxLen = layers.isEmpty ? 0 : layers.map((l) => l.length).reduce(math.max);
  for (var li = 0; li < layers.length; li++) {
    final layer = layers[li];
    final off = (maxLen - layer.length) * cross / 2;
    for (var i = 0; i < layer.length; i++) {
      final m = GraphGeometry.pad + li * main;
      final c = GraphGeometry.pad + off + i * cross;
      origins[layer[i]] = horiz ? Offset(m, c) : Offset(c, m);
    }
  }
}

enum _Side { top, bottom, left, right }

Offset _anchor(Rect n, _Side side) => switch (side) {
      _Side.top => Offset(n.left + n.width / 2, n.top),
      _Side.bottom => Offset(n.left + n.width / 2, n.bottom),
      _Side.left => Offset(n.left, n.top + n.height / 2),
      _Side.right => Offset(n.right, n.top + n.height / 2),
    };

Offset _normal(_Side side) => switch (side) {
      _Side.top => const Offset(0, -1),
      _Side.bottom => const Offset(0, 1),
      _Side.left => const Offset(-1, 0),
      _Side.right => const Offset(1, 0),
    };

/// Floating anchors: each endpoint attaches to the face of its node that FACES the other node
/// (aspect-weighted so wide nodes prefer left/right) — any hand placement still routes cleanly.
/// 浮动锚:端点各挂到朝向对方的那一面(按宽高比加权,宽节点偏左右)——任意手摆都走得顺。
(_Side, _Side) _facing(Rect a, Rect b) {
  final dx = b.center.dx - a.center.dx;
  final dy = b.center.dy - a.center.dy;
  final horiz = dx.abs() * GraphGeometry.nodeH >= dy.abs() * GraphGeometry.nodeW;
  return horiz
      ? (dx >= 0 ? _Side.right : _Side.left, dx >= 0 ? _Side.left : _Side.right)
      : (dy >= 0 ? _Side.bottom : _Side.top, dy >= 0 ? _Side.top : _Side.bottom);
}

GraphEdgeRoute _orthoRoute(Edge e, Rect a, Rect b) {
  final (sa, sb) = _facing(a, b);
  final s = _anchor(a, sa), t = _anchor(b, sb);
  final ns = _normal(sa), nt = _normal(sb);
  final s1 = s + ns * GraphGeometry.stub, t1 = t + nt * GraphGeometry.stub;
  final sh = sa == _Side.left || sa == _Side.right;
  final th = sb == _Side.left || sb == _Side.right;
  List<Offset> pts;
  if (sh && th) {
    final mx = (s1.dx + t1.dx) / 2;
    pts = [s, s1, Offset(mx, s1.dy), Offset(mx, t1.dy), t1, t];
  } else if (!sh && !th) {
    final my = (s1.dy + t1.dy) / 2;
    pts = [s, s1, Offset(s1.dx, my), Offset(t1.dx, my), t1, t];
  } else {
    final corner = sh ? Offset(t1.dx, s1.dy) : Offset(s1.dx, t1.dy);
    pts = [s, s1, corner, t1, t];
  }
  return GraphEdgeRoute(edge: e, isBack: false, points: pts, mid: _midpoint(pts));
}

/// Back edges leave the bottom (LR) / right (TB) face, run along a stacked channel outside the
/// bounds, and re-enter the target's same face — the loop reads as a detour under/beside the flow.
/// 回边从底面(LR)/右面(TB)出,沿界外叠放通道走,再回目标同面——循环读作主流之下/旁的绕行。
GraphEdgeRoute _loopRoute(Edge e, Rect a, Rect b, int loopIdx, double maxX, double maxY, GraphDirection dir) {
  final off = GraphGeometry.loopFirst + loopIdx * GraphGeometry.loopGap;
  List<Offset> pts;
  Offset mid;
  if (dir == GraphDirection.lr) {
    final sx = a.left + a.width / 2, sy = a.bottom;
    final tx = b.left + b.width / 2, ty = b.bottom;
    final ch = maxY + off;
    pts = [Offset(sx, sy), Offset(sx, ch), Offset(tx, ch), Offset(tx, ty)];
    mid = Offset((sx + tx) / 2, ch);
  } else {
    final sx = a.right, sy = a.top + a.height / 2;
    final tx = b.right, ty = b.top + b.height / 2;
    final ch = maxX + off;
    pts = [Offset(sx, sy), Offset(ch, sy), Offset(ch, ty), Offset(tx, ty)];
    mid = Offset(ch, (sy + ty) / 2);
  }
  return GraphEdgeRoute(edge: e, isBack: true, points: pts, mid: mid);
}

/// The point at half the polyline's total length — where the port pill sits.
/// 折线总长一半处的点——端口药丸落点。
Offset _midpoint(List<Offset> pts) {
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    total += (pts[i] - pts[i - 1]).distance;
  }
  var d = total / 2;
  for (var i = 1; i < pts.length; i++) {
    final seg = (pts[i] - pts[i - 1]).distance;
    if (d <= seg) {
      final t = seg == 0 ? 0.0 : d / seg;
      return pts[i - 1] + (pts[i] - pts[i - 1]) * t;
    }
    d -= seg;
  }
  return pts.last;
}
