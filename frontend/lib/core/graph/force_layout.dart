/// The framework-free force-directed LAYOUT engine (positions only) — the second pure model layer next
/// to [graph_model]'s Sugiyama-lite DAG layout, for the Entities Overview relationship graph. It answers
/// ONE question: given nodes (each with a collision radius) + undirected spring edges, where does each node
/// sit? Rendering (widgets, InteractiveViewer, hover, ripple, a11y) is the primitive's job — this layer has
/// no widget/socket, so the whole physics + packing unit-tests headless. All tunable numbers live in
/// [RelationGraphConfig.forceParams]; this file carries only the ALGORITHM, no literals.
///
/// WHY hand-rolled, not a pub package (原则 #8, research 0719): every Flutter force-graph package is a
/// MONOLITHIC view widget (owns the canvas + gestures + node rendering) — none exposes a `layout(nodes,
/// edges) → positions` seam, and none satisfies all four constraints we need at once: real WIDGETS as
/// nodes (a11y), our OWN InteractiveViewer canvas, DETERMINISTIC layout (FR impls seed `Random()`), and
/// STATIC-WHEN-SETTLED / zero repaint. The mature solution is the textbook ALGORITHM (d3-force
/// velocity-Verlet + d3-collide relaxation + connected-component packing), not a mismatched widget.
///
/// FOUR forces + packing (v2, WRK-072 涟漪焦点星图):
///  1. SPRING — edge rest length自适应 by the higher endpoint's degree (hub边放长); strength softened at
///     high-degree ends (`1/√min(deg)`), so leaves pull firmly and hubs float apart.
///  2. REPULSION — charge `F = repulsion/dist²`, every pair O(n²) (n≤~80 → trivial), the主力 that撑开 the
///     graph so it never挤成一团.
///  3. COLLISION — each node owns a radius that already covers its LABEL box; overlapping pairs are pushed
///     apart by position relaxation (d3-collide) so字不打架 — the first of the two label-avoidance passes.
///  4. CENTERING — a WEAK x/y pull to the component anchor, anti-drift ONLY (not the向心挤压 that crushed v1);
///     真正的居中靠布局后的 fit-to-viewport in the primitive.
///  + PACKING — connected components are simulated SEPARATELY then their bounding boxes are shelf-packed
///    (面积打包, non-overlapping); zero-degree ISOLATES never enter the force field — they sit frozen in a
///    quiet band below the cloud.
///
/// THREE engineering laws:
///  1. DETERMINISM — per-component phyllotaxis seed keyed by SORTED id, NO RNG, fixed iteration count, forces
///     summed in stable id order, components processed in a stable order → the same workspace graph settles
///     to the same shape every open (never re-shuffles).
///  2. STATIC-WHEN-SETTLED — the full layout is computed once in the constructor (`_alpha` starts settled);
///     [tick] only runs while a DRAG has reheated the sim, and returns `false` once cooled so the driving
///     Ticker stops → zero repaint at rest.
///  3. REDUCED-MOTION — the caller runs [settle] to the terminal frame directly instead of animating
///     tick-by-tick; dragging still works.
///
/// 框架无关力导向布局引擎(仅算位置)。四力(自适应弹簧/斥力/碰撞/弱定位)+ 连通分量分开模拟按面积打包 + 零度孤点
/// 不进力场(冻结在下方安静带)。全部可调数字在 RelationGraphConfig.forceParams,本文件只有算法、零字面量。
/// 三律:确定性(分量内 phyllotaxis 按排序 id、无 RNG、固定迭代、稳定分量序,同图恒同形)/静止即停(布局在构造时一次
/// 算完、alpha 起于 settled,tick 仅拖拽重加热时跑、冷却返 false 让 Ticker 停)/reduced-motion(直接 settle 到终帧)。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size, Rect;

/// One node in the simulation — an id, a collision [radius] (the primitive bakes the LABEL box into it so
/// collision keeps labels apart), and (transient) whether it is [pinned] (a dragged/held node the physics
/// must not move). 仿真节点:id + 碰撞半径(原语已把标签盒算进去)+ 是否钉住(拖拽中,物理不动它)。
class ForceNode {
  ForceNode(this.id, {this.pinned = false, this.radius = 8});
  final String id;
  bool pinned;

  /// Collision radius (visual dot radius grown to cover the label box). 碰撞半径(视觉点撑到盖住标签)。
  final double radius;
}

/// One undirected spring edge — the physics ignores direction (direction is a render/label concern), so
/// two edges A→B and B→A pull the same. 无向弹簧边:物理无视方向(方向是渲染/文字关切)。
class ForceEdge {
  const ForceEdge(this.from, this.to);
  final String from;
  final String to;
}

/// The tuned physics constants (all in scene px). The graph hands [RelationGraphConfig.forceParams]; these
/// defaults keep the headless tests self-contained. 物理常量(场景 px);图传 config 的调好值,默认供无头测试自足。
class ForceParams {
  const ForceParams({
    this.idealLength = 84,
    this.repulsion = 11000,
    this.springStrength = 0.085,
    this.hubStretch = 0.42,
    this.centering = 0.018,
    this.collisionStrength = 0.72,
    this.collisionIterations = 2,
    this.velocityDecay = 0.42,
    this.alphaDecay = 0.0228,
    this.alphaMin = 0.001,
    this.reheatAlpha = 0.55,
    this.minDist = 1.0,
    this.initialSpacing = 46,
    this.componentGap = 72,
    this.isolateGap = 34,
    this.isolateTopGap = 60,
    this.componentIterations = 320,
  });

  /// Spring rest length (a leaf edge relaxes toward this; hub edges stretch past it via [hubStretch]). 弹簧静止长。
  final double idealLength;

  /// Charge strength: pairwise repulsion `F = repulsion / dist²`. 电荷强度:对间斥力。
  final double repulsion;

  /// Base Hooke constant `F = springStrength · (dist − restLen)` (softened at high-degree ends). 弹簧基强度。
  final double springStrength;

  /// How much an edge's rest length grows with its higher-degree endpoint (`restLen = idealLength·(1 +
  /// hubStretch·(√maxDeg − 1))`) — spreads hubs' many spokes. hub 边随高度端放长的系数。
  final double hubStretch;

  /// WEAK positional pull toward the component anchor — bounds drift, does NOT crush the graph. 弱定位(防漂移)。
  final double centering;

  /// Fraction of a pair's overlap corrected each collision pass (0..1). 碰撞每遍纠正的重叠比例。
  final double collisionStrength;

  /// Collision relaxation passes per tick (d3-collide 做法). 每 tick 碰撞松弛遍数。
  final int collisionIterations;

  /// Per-tick velocity damping. 逐 tick 速度阻尼。
  final double velocityDecay;

  /// Cooling: `alpha *= (1 − alphaDecay)` each tick. 冷却率。
  final double alphaDecay;

  /// Below this the sim is settled and stops. 静止阈。
  final double alphaMin;

  /// Alpha a drag/data change reheats to. 拖拽/换数据重加热到的 alpha。
  final double reheatAlpha;

  /// Distance floor so repulsion can't explode at overlap. 距离下限。
  final double minDist;

  /// Phyllotaxis radius factor within a component: node i sits at radius `initialSpacing·√i`. 分量内初铺半径系数。
  final double initialSpacing;

  /// Gap packed between connected components' bounding boxes. 连通分量打包间隙。
  final double componentGap;

  /// Horizontal gap between zero-degree isolates in their band. 孤点带内水平间距。
  final double isolateGap;

  /// Gap from the main cloud down to the isolate band. 主云到孤点带的落差。
  final double isolateTopGap;

  /// Fixed per-component settle iterations (determinism — a固定 count, not a convergence probe). 分量固定迭代数。
  final int componentIterations;
}

/// The mutable force simulation. The full layout is computed deterministically in the constructor; call
/// [settle] to make sure it (or a post-drag re-squeeze) is at rest, or drive [tick] from a Ticker for the
/// live drag squeeze. Positions are centered near the origin (can be negative); the primitive translates to
/// scene space. 可变力仿真:构造时确定性算完整布局;[settle] 保证静止(或拖拽后重挤压),[tick] 供拖拽现场挤压。
class ForceLayout {
  ForceLayout({
    required List<ForceNode> nodes,
    required List<ForceEdge> edges,
    this.params = const ForceParams(),
  })  : _nodes = nodes,
        // Sort edges by (from,to) so force summation is INPUT-ORDER-INDEPENDENT (float addition isn't
        // associative). 边排序,使力求和与输入顺序无关(浮点加法不结合)。
        _edges = List.of(edges)
          ..sort((x, y) {
            final c = x.from.compareTo(y.from);
            return c != 0 ? c : x.to.compareTo(y.to);
          }) {
    _radius = {for (final n in _nodes) n.id: n.radius};
    _deg = _undirectedDegrees(_edges, _radius.keys);
    _computeStaticLayout();
  }

  final ForceParams params;
  final List<ForceNode> _nodes;
  final List<ForceEdge> _edges;

  final Map<String, Offset> _pos = {};
  final Map<String, Offset> _vel = {};
  late final Map<String, double> _radius;
  late final Map<String, int> _deg;
  final Set<String> _frozen = {}; // zero-degree isolates — placed once, never touched by the field 孤点冻结
  double _alpha = 1.0;

  /// Live positions (id → centered scene-ish coords). 活位置。
  Map<String, Offset> get positions => _pos;
  Offset positionOf(String id) => _pos[id] ?? Offset.zero;

  /// The cooling temperature; drops toward 0. 温度。
  double get alpha => _alpha;

  /// True once cooled below [ForceParams.alphaMin] — the driving Ticker should stop (zero repaint). 静止即真。
  bool get settled => _alpha < params.alphaMin;

  // ── deterministic static layout (components → per-component relax → shelf pack → isolate band) ──────────
  void _computeStaticLayout() {
    _pos.clear();
    _vel.clear();
    _frozen.clear();
    if (_radius.isEmpty) {
      _alpha = params.alphaMin * 0.5; // an empty graph is trivially settled 空图即静止
      return;
    }

    final comps = connectedComponents(_radius.keys, _edges);
    // Zero-degree isolates surface as SINGLETON components; the rest carry ≥1 edge. 孤点=单元素分量。
    final clusters = <List<String>>[];
    final isolates = <String>[];
    for (final c in comps) {
      if (c.length == 1 && (_deg[c.first] ?? 0) == 0) {
        isolates.add(c.first);
      } else {
        clusters.add(c);
      }
    }

    // Simulate each cluster on its own, recentered to its bbox → local positions + a packed box. 分量分开模拟。
    final boxes = <Size>[];
    final localById = <String, Offset>{};
    // Stable cluster order: larger first (packs better), id as tiebreak. 稳定分量序:大在前,id 破平局。
    clusters.sort((a, b) {
      final byLen = b.length.compareTo(a.length);
      return byLen != 0 ? byLen : a.first.compareTo(b.first);
    });
    final clusterBox = <int>[]; // parallel to clusters: index into boxes 平行索引
    for (final cluster in clusters) {
      final local = _relaxCluster(cluster);
      final rect = _boundsOf(cluster, local);
      for (final id in cluster) {
        localById[id] = local[id]! - rect.topLeft; // shift so cluster's top-left is (0,0) 归零左上
      }
      clusterBox.add(boxes.length);
      boxes.add(rect.size);
    }

    // Shelf-pack the cluster boxes, then recenter the whole packed area on the origin. 打包后整体居中原点。
    final origins = packBoxes(boxes, gap: params.componentGap);
    var packMinX = double.infinity, packMinY = double.infinity;
    var packMaxX = -double.infinity, packMaxY = -double.infinity;
    for (var i = 0; i < clusters.length; i++) {
      final o = origins[clusterBox[i]];
      final b = boxes[clusterBox[i]];
      packMinX = math.min(packMinX, o.dx);
      packMinY = math.min(packMinY, o.dy);
      packMaxX = math.max(packMaxX, o.dx + b.width);
      packMaxY = math.max(packMaxY, o.dy + b.height);
    }
    final packCenter = clusters.isEmpty
        ? Offset.zero
        : Offset((packMinX + packMaxX) / 2, (packMinY + packMaxY) / 2);
    for (var i = 0; i < clusters.length; i++) {
      final o = origins[clusterBox[i]] - packCenter;
      for (final id in clusters[i]) {
        _pos[id] = localById[id]! + o;
        _vel[id] = Offset.zero;
      }
    }

    _placeIsolateBand(isolates);
    _alpha = params.alphaMin * 0.5; // computed layout IS the terminal frame → settled 算完即静止
  }

  // A single connected cluster: phyllotaxis seed + a fixed number of force iterations, centered locally.
  // 单个连通分量:phyllotaxis 铺 + 固定迭代数,局部居中。
  Map<String, Offset> _relaxCluster(List<String> cluster) {
    final ids = List.of(cluster)..sort();
    final pos = <String, Offset>{};
    final vel = <String, Offset>{};
    const golden = 2.399963229728653; // the golden angle (137.507764°)
    for (var i = 0; i < ids.length; i++) {
      final r = params.initialSpacing * math.sqrt(i.toDouble());
      final a = i * golden;
      pos[ids[i]] = Offset(r * math.cos(a), r * math.sin(a));
      vel[ids[i]] = Offset.zero;
    }
    final scoped = [
      for (final e in _edges)
        if (pos.containsKey(e.from) && pos.containsKey(e.to)) e,
    ];
    var alpha = 1.0;
    for (var it = 0; it < params.componentIterations; it++) {
      _stepForces(pos, vel, ids, scoped, alpha, const <String>{});
      alpha *= (1 - params.alphaDecay);
      if (alpha < params.alphaMin) break;
    }
    return pos;
  }

  // Zero-degree isolates never enter the field — they sit in a single row below the settled cloud, centered.
  // 孤点不进力场:主云下方一排、居中、冻结。
  void _placeIsolateBand(List<String> isolates) {
    if (isolates.isEmpty) return;
    final ids = List.of(isolates)..sort();
    var top = 0.0;
    if (_pos.isNotEmpty) {
      var maxY = -double.infinity;
      _pos.forEach((id, p) => maxY = math.max(maxY, p.dy + (_radius[id] ?? 0)));
      top = maxY + params.isolateTopGap;
    }
    // Total width = Σ diameters + gaps; lay left→right centered on x=0. 总宽=Σ直径+间隙,以 x=0 居中。
    var total = 0.0;
    for (var i = 0; i < ids.length; i++) {
      total += (_radius[ids[i]] ?? 0) * 2;
      if (i > 0) total += params.isolateGap;
    }
    var x = -total / 2;
    for (final id in ids) {
      final r = _radius[id] ?? 0;
      _pos[id] = Offset(x + r, top + r);
      _vel[id] = Offset.zero;
      _frozen.add(id);
      x += r * 2 + params.isolateGap;
    }
  }

  // ── the shared force kernel (one tick of physics over a node subset) ────────────────────────────────────
  // Applies repulsion + adaptive spring + weak centering to [ids], integrates velocity, then relaxes
  // collisions. [frozen] nodes and [ForceNode.pinned] nodes hold position. 共享力内核:斥力+自适应弹簧+弱定位,
  // 积分后松弛碰撞;frozen/pinned 不动。
  void _stepForces(
    Map<String, Offset> pos,
    Map<String, Offset> vel,
    List<String> ids,
    List<ForceEdge> edges,
    double alpha,
    Set<String> frozen,
  ) {
    final force = {for (final id in ids) id: Offset.zero};

    // Repulsion (charge) — every pair, O(n²). 斥力:每对。
    for (var a = 0; a < ids.length; a++) {
      for (var b = a + 1; b < ids.length; b++) {
        final ia = ids[a], ib = ids[b];
        var delta = pos[ib]! - pos[ia]!;
        var dist = delta.distance;
        if (dist < params.minDist) {
          final ang = (a + 1) * 2.399963229728653; // deterministic nudge on exact overlap (never RNG) 重叠确定性微推
          delta = Offset(math.cos(ang), math.sin(ang)) * params.minDist;
          dist = params.minDist;
        }
        final f = params.repulsion / (dist * dist);
        final dir = delta / dist;
        force[ia] = force[ia]! - dir * f;
        force[ib] = force[ib]! + dir * f;
      }
    }

    // Attraction (adaptive springs) — rest length stretches at hubs, strength softens at high-degree ends.
    // 弹簧:hub 边放长,高度端强度调低。
    for (final e in edges) {
      if (e.from == e.to) continue;
      final pa = pos[e.from], pb = pos[e.to];
      if (pa == null || pb == null) continue;
      final da = _deg[e.from] ?? 1, db = _deg[e.to] ?? 1;
      final rest = params.idealLength * (1 + params.hubStretch * (math.sqrt(math.max(da, db)) - 1));
      final soft = params.springStrength / math.sqrt(math.max(1, math.min(da, db)));
      var delta = pb - pa;
      var dist = delta.distance;
      if (dist < params.minDist) dist = params.minDist;
      final dir = delta / dist;
      final f = soft * (dist - rest);
      force[e.from] = force[e.from]! + dir * f;
      force[e.to] = force[e.to]! - dir * f;
    }

    // Weak centering toward the anchor (origin) — anti-drift only. 弱定位(向原点,只防漂移)。
    for (final id in ids) {
      force[id] = force[id]! - pos[id]! * params.centering;
    }

    // Integrate (pinned / frozen frozen). 积分(钉住/冻结不动)。
    final pinned = {for (final n in _nodes) n.id: n.pinned};
    for (final id in ids) {
      if (frozen.contains(id) || pinned[id] == true) {
        vel[id] = Offset.zero;
        continue;
      }
      final v = (vel[id]! + force[id]! * alpha) * params.velocityDecay;
      vel[id] = v;
      pos[id] = pos[id]! + v;
    }

    // Collision relaxation — push overlapping pairs apart (radii already cover labels). 碰撞松弛:推开重叠对。
    for (var pass = 0; pass < params.collisionIterations; pass++) {
      for (var a = 0; a < ids.length; a++) {
        for (var b = a + 1; b < ids.length; b++) {
          final ia = ids[a], ib = ids[b];
          final ra = _radius[ia] ?? 0, rb = _radius[ib] ?? 0;
          final minSep = ra + rb;
          var delta = pos[ib]! - pos[ia]!;
          var dist = delta.distance;
          if (dist >= minSep) continue;
          if (dist < params.minDist) {
            final ang = (a + 1) * 2.399963229728653;
            delta = Offset(math.cos(ang), math.sin(ang)) * params.minDist;
            dist = params.minDist;
          }
          final overlap = (minSep - dist) * params.collisionStrength;
          final push = (delta / dist) * (overlap / 2);
          final aFixed = frozen.contains(ia) || pinned[ia] == true;
          final bFixed = frozen.contains(ib) || pinned[ib] == true;
          if (aFixed && bFixed) continue;
          if (aFixed) {
            pos[ib] = pos[ib]! + push * 2;
          } else if (bFixed) {
            pos[ia] = pos[ia]! - push * 2;
          } else {
            pos[ia] = pos[ia]! - push;
            pos[ib] = pos[ib]! + push;
          }
        }
      }
    }
  }

  /// Advance one physics step (the live DRAG squeeze). Returns `false` when already [settled] (no
  /// displacement) so the caller can halt its Ticker. 走一步物理(拖拽挤压);已 settled 返 false。
  bool tick() {
    if (settled) return false;
    _alpha *= (1 - params.alphaDecay);
    final ids = [for (final id in _pos.keys) if (!_frozen.contains(id)) id]..sort();
    _stepForces(_pos, _vel, ids, _edges, _alpha, _frozen);
    return true;
  }

  /// Run to the terminal layout (or a [maxIterations] backstop) in one shot. On a fresh sim the constructor
  /// already computed the static layout (this is a no-op); after a drag [reheat] it converges the squeeze.
  /// 一次跑到终局:新仿真已在构造时算完(此为空转),拖拽 reheat 后收敛挤压。
  void settle({int maxIterations = 400}) {
    var i = 0;
    while (!settled && i < maxIterations) {
      tick();
      i++;
    }
  }

  /// Re-warm the sim (a drag started, a neighbor moved). 重加热(拖拽起/邻居动)。
  void reheat() {
    if (_alpha < params.reheatAlpha) _alpha = params.reheatAlpha;
  }

  /// Pin [id] at [pos] (a live drag) — the physics won't move it, but neighbors react. Reheats. A frozen
  /// isolate can still be dragged (it leaves the band for the drag). 钉住 id(拖拽中):物理不动它、邻居反应;孤点亦可拖。
  void pin(String id, Offset pos) {
    for (final n in _nodes) {
      if (n.id == id) n.pinned = true;
    }
    _frozen.remove(id);
    _pos[id] = pos;
    _vel[id] = Offset.zero;
    reheat();
  }

  /// Release a pinned node (drag ended) — it re-enters the physics. 松开钉住节点:重回物理。
  void unpin(String id) {
    for (final n in _nodes) {
      if (n.id == id) n.pinned = false;
    }
    reheat();
  }

  static Rect _boundsOf(List<String> ids, Map<String, Offset> pos) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final id in ids) {
      final p = pos[id]!;
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    // Pad by nothing here (node radii are small vs. component span); packing adds the gap. 分量间隙由 packing 加。
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Map<String, int> _undirectedDegrees(Iterable<ForceEdge> edges, Iterable<String> ids) {
    final d = {for (final id in ids) id: 0};
    for (final e in edges) {
      if (e.from == e.to) continue;
      if (d.containsKey(e.from)) d[e.from] = d[e.from]! + 1;
      if (d.containsKey(e.to)) d[e.to] = d[e.to]! + 1;
    }
    return d;
  }
}

/// Connected components over an undirected edge set (union-find), returned in a DETERMINISTIC order: each
/// component's ids sorted, and the components sorted by their smallest id. Every id in [nodeIds] appears in
/// exactly one component (a node with no edge is its own singleton = a zero-degree isolate). Pure +
/// headless-testable. 连通分量(并查集),确定性序:分量内 id 排序、分量按最小 id 排序;无边节点=单元素分量(孤点)。
List<List<String>> connectedComponents(Iterable<String> nodeIds, Iterable<ForceEdge> edges) {
  final parent = <String, String>{};
  String find(String x) {
    var r = x;
    while (parent[r] != r) {
      r = parent[r]!;
    }
    // Path-compress. 路径压缩。
    var c = x;
    while (parent[c] != r) {
      final next = parent[c]!;
      parent[c] = r;
      c = next;
    }
    return r;
  }

  for (final id in nodeIds) {
    parent[id] ??= id;
  }
  for (final e in edges) {
    if (e.from == e.to) continue;
    if (!parent.containsKey(e.from) || !parent.containsKey(e.to)) continue;
    final ra = find(e.from), rb = find(e.to);
    if (ra != rb) parent[find(ra)] = rb; // union
  }
  final groups = <String, List<String>>{};
  for (final id in parent.keys) {
    groups.putIfAbsent(find(id), () => []).add(id);
  }
  final result = [for (final g in groups.values) g..sort()];
  result.sort((a, b) => a.first.compareTo(b.first));
  return result;
}

/// Shelf-pack rectangular [boxes] left→right, wrapping to a new row when a row would exceed a target width,
/// with [gap] between neighbours. Returns each box's top-left origin (parallel to [boxes]); by construction
/// no two placed boxes overlap. The caller pre-orders boxes (e.g. larger first). Pure + testable. 面积打包:
/// 货架式左→右排、超目标宽换行,间隙 gap;返回各盒左上角(与入参平行),构造上互不相交。
List<Offset> packBoxes(List<Size> boxes, {double gap = 72, double? maxRowWidth}) {
  if (boxes.isEmpty) return const [];
  var area = 0.0, widest = 0.0;
  for (final b in boxes) {
    area += (b.width + gap) * (b.height + gap);
    widest = math.max(widest, b.width);
  }
  // Aim for a roughly square arrangement, but never narrower than the widest single box. 目标近方形、不窄于最宽盒。
  final rowLimit = math.max(widest, math.sqrt(area) * 1.3);

  final origins = List<Offset>.filled(boxes.length, Offset.zero);
  var x = 0.0, y = 0.0, rowHeight = 0.0;
  for (var i = 0; i < boxes.length; i++) {
    final b = boxes[i];
    if (x > 0 && x + b.width > rowLimit) {
      x = 0;
      y += rowHeight + gap;
      rowHeight = 0;
    }
    origins[i] = Offset(x, y);
    x += b.width + gap;
    rowHeight = math.max(rowHeight, b.height);
  }
  return origins;
}

/// In-degree of each node over a DIRECTED edge set — the count of edges POINTING AT it. The Overview graph
/// scales node radius by this (核心零件被越多实体挂载/引用越大); an entity nobody depends on has in-degree 0
/// (renders smallest/faintest). Pure + headless-testable. 入度(指向它的边数):视觉半径据此放大。
Map<String, int> inDegrees(Iterable<({String from, String to})> edges) {
  final d = <String, int>{};
  for (final e in edges) {
    if (e.from == e.to) continue;
    d[e.to] = (d[e.to] ?? 0) + 1;
  }
  return d;
}
