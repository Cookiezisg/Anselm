/// The framework-free force-directed LAYOUT engine (positions only) — the second pure model layer next
/// to [graph_model]'s Sugiyama-lite DAG layout, for the Entities Overview relationship graph. It answers
/// ONE question: given nodes + undirected spring edges, where does each node sit? Rendering (widgets,
/// InteractiveViewer, hover, a11y) is the primitive's job — this layer has no widget/socket, so the whole
/// physics unit-tests headless.
///
/// WHY hand-rolled, not a pub package (原则 #8, research 0719): every Flutter force-graph package is a
/// MONOLITHIC view widget (owns the canvas + gestures + node rendering) — none exposes a `layout(nodes,
/// edges) → positions` seam, and none satisfies all four constraints we need at once: real WIDGETS as
/// nodes (a11y — rules out the Flame/painter packages), our OWN InteractiveViewer canvas (every package
/// brings its own), DETERMINISTIC layout (FR impls seed `Random()`), and STATIC-WHEN-SETTLED / zero
/// repaint. The mature solution here is the textbook ALGORITHM (d3-force velocity-Verlet), not a
/// mismatched widget — ~120 lines reusing [AnGraphCanvas]'s render half.
///
/// THREE engineering laws (WRK-072):
///  1. DETERMINISM — initial placement is a phyllotaxis (sunflower) spiral keyed by SORTED id, NO RNG,
///     so the same workspace graph settles to the same shape every open (never re-shuffles). Forces are
///     summed in stable id order.
///  2. STATIC-WHEN-SETTLED — `alpha` cools each [tick] toward 0; once `alpha < alphaMin` the sim is
///     [settled] and [tick] returns `false` (no displacement) so the driving Ticker can stop → zero
///     repaint at rest. A drag or a data change [reheat]s.
///  3. REDUCED-MOTION — the caller (primitive) runs [settle] to the terminal frame directly instead of
///     animating tick-by-tick; dragging still works (no in-between tweening).
///
/// 框架无关的力导向布局引擎(仅算位置)——Entities 总览关系图用,与 graph_model 的 Sugiyama 分层并列的第二
/// 个纯模型层。只答一问:给定节点 + 无向弹簧边,每个节点落在哪。渲染(widget/InteractiveViewer/hover/a11y)
/// 归原语;本层零 widget/socket,整套物理可无头单测。自研而非取包:pub 每个力导向包都是独占视图 widget,
/// 无「喂节点边、查位置」的缝,且无一同时满足四约束(真 widget 节点做 a11y / 自有画布 / 确定性 / 静止即停)。
/// 三工程律:①确定性(phyllotaxis 按排序 id 铺,无 RNG,同图恒同形)②静止即停(alpha 冷却 <alphaMin 即 settled,
/// tick 返 false 让 Ticker 停、零重绘)③reduced-motion(直接 settle 到终帧,拖拽仍可、无补间)。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

/// One node in the simulation — an id and (transient) whether it is [pinned] (a dragged/held node the
/// physics must not move; the caller sets its position directly). 仿真节点:id + 是否钉住(拖拽中,物理不动它)。
class ForceNode {
  ForceNode(this.id, {this.pinned = false});
  final String id;
  bool pinned;
}

/// One undirected spring edge — the physics ignores direction (direction is a render/label concern), so
/// two edges A→B and B→A pull the same. 无向弹簧边:物理无视方向(方向是渲染/文字关切)。
class ForceEdge {
  const ForceEdge(this.from, this.to);
  final String from;
  final String to;
}

/// Tuned physics constants (all in scene px). Defaults picked for 20–60-node relation graphs — naive
/// O(n²) repulsion at n≤60 is ≤3,600 pair-ops/tick (trivial), so no Barnes-Hut. 物理常量(场景 px),按
/// 20–60 节点调;n≤60 朴素 O(n²) 斥力每 tick ≤3600 对、无需 Barnes-Hut。
class ForceParams {
  const ForceParams({
    this.idealLength = 96,
    this.repulsion = 8200,
    this.springStrength = 0.06,
    this.gravity = 0.028,
    this.velocityDecay = 0.4,
    this.alphaDecay = 0.0228, // 1 - 0.001^(1/300): settles in ~300 ticks
    this.alphaMin = 0.001,
    this.reheatAlpha = 0.6,
    this.minDist = 1.0,
    this.initialSpacing = 58,
  });

  /// Spring rest length (edges relax toward this). 弹簧静止长(边松弛到此)。
  final double idealLength;

  /// Charge strength: pairwise repulsion `F = repulsion / dist²`. 电荷强度:对间斥力。
  final double repulsion;

  /// Hooke constant for edge attraction `F = springStrength · (dist − idealLength)`. 弹簧系数。
  final double springStrength;

  /// Positional pull toward the origin — keeps disconnected components from drifting to infinity. 向心引力。
  final double gravity;

  /// Per-tick velocity damping. 逐 tick 速度阻尼。
  final double velocityDecay;

  /// Cooling: `alpha *= (1 − alphaDecay)` each tick. 冷却率。
  final double alphaDecay;

  /// Below this, the sim is settled and stops. 静止阈。
  final double alphaMin;

  /// Alpha a drag/data change reheats to. 拖拽/换数据重加热到的 alpha。
  final double reheatAlpha;

  /// Distance floor to keep repulsion from exploding at overlap. 距离下限(防重叠时斥力爆炸)。
  final double minDist;

  /// Phyllotaxis radius factor: node i sits at radius `initialSpacing·√i`. 初始铺开半径系数。
  final double initialSpacing;
}

/// The mutable force simulation. Construct with nodes + edges, then either [settle] to the terminal
/// layout (reduced-motion / tests / first paint) or drive [tick] from a Ticker for the live squeeze.
/// Positions are centered near the origin (can be negative); the primitive translates to scene space.
///
/// 可变力仿真。构造后要么 [settle] 到终局(reduced-motion/测试/首帧),要么用 Ticker 驱 [tick] 现场挤压。
/// 位置以原点为中心(可为负),原语再平移到场景坐标。
class ForceLayout {
  ForceLayout({
    required List<ForceNode> nodes,
    required List<ForceEdge> edges,
    this.params = const ForceParams(),
  })  : _nodes = nodes,
        // Sort edges by (from,to) so force summation is INPUT-ORDER-INDEPENDENT: float addition isn't
        // associative, so summing spring forces in a different edge order settles to different last bits.
        // Sorting (plus the sorted-id seed + sorted-id force loop) makes the settled shape bit-identical
        // for the same graph however the backend orders its edge list. 边按 (from,to) 排序,使力求和与输入
        // 顺序无关(浮点加法不结合;不排序则边序不同→末位不同),同图恒得逐位相同的形状。
        _edges = List.of(edges)
          ..sort((x, y) {
            final c = x.from.compareTo(y.from);
            return c != 0 ? c : x.to.compareTo(y.to);
          }) {
    _seed();
  }

  final ForceParams params;
  final List<ForceNode> _nodes;
  final List<ForceEdge> _edges;

  final Map<String, Offset> _pos = {};
  final Map<String, Offset> _vel = {};
  double _alpha = 1.0;

  /// Live positions (id → centered scene-ish coords). 活位置。
  Map<String, Offset> get positions => _pos;
  Offset positionOf(String id) => _pos[id] ?? Offset.zero;

  /// The cooling temperature; drops toward 0. 温度。
  double get alpha => _alpha;

  /// True once cooled below [ForceParams.alphaMin] — the driving Ticker should stop (zero repaint).
  /// 冷到阈下即真:Ticker 该停(零重绘)。
  bool get settled => _alpha < params.alphaMin;

  // Deterministic initial placement: a phyllotaxis (sunflower) spiral by SORTED id — even spread, no
  // RNG, identical every run regardless of input order. 确定性初铺:按排序 id 的向日葵螺旋,无 RNG、恒同。
  void _seed() {
    final ids = _nodes.map((n) => n.id).toList()..sort();
    const golden = 2.399963229728653; // 137.507764° in radians (the golden angle)
    for (var i = 0; i < ids.length; i++) {
      final r = params.initialSpacing * math.sqrt(i.toDouble());
      final a = i * golden;
      _pos[ids[i]] = Offset(r * math.cos(a), r * math.sin(a));
      _vel[ids[i]] = Offset.zero;
    }
  }

  /// Advance one physics step. Returns `false` when already [settled] (no displacement) so the caller can
  /// halt its Ticker. Pinned nodes hold position (their velocity is zeroed). 走一步物理;已 settled 返 false。
  bool tick() {
    if (settled) return false;
    _alpha *= (1 - params.alphaDecay);

    final ids = _pos.keys.toList()..sort(); // stable order → deterministic force summation
    final force = {for (final id in ids) id: Offset.zero};

    // Repulsion (charge) — every pair, O(n²). Push i away from j by repulsion/dist². 斥力:每对,推开。
    for (var a = 0; a < ids.length; a++) {
      for (var b = a + 1; b < ids.length; b++) {
        final ia = ids[a], ib = ids[b];
        var delta = _pos[ib]! - _pos[ia]!;
        var dist = delta.distance;
        if (dist < params.minDist) {
          // Deterministic nudge on exact overlap (never RNG): offset along a per-index angle. 重叠确定性微推。
          final ang = (a + 1) * 2.399963229728653;
          delta = Offset(math.cos(ang), math.sin(ang)) * params.minDist;
          dist = params.minDist;
        }
        final dir = delta / dist;
        final f = params.repulsion / (dist * dist);
        force[ia] = force[ia]! - dir * f;
        force[ib] = force[ib]! + dir * f;
      }
    }

    // Attraction (springs) — pull edge endpoints toward idealLength. 弹簧:边端点拉向理想长。
    for (final e in _edges) {
      final pa = _pos[e.from], pb = _pos[e.to];
      if (pa == null || pb == null || e.from == e.to) continue;
      var delta = pb - pa;
      var dist = delta.distance;
      if (dist < params.minDist) dist = params.minDist;
      final dir = delta / dist;
      final f = params.springStrength * (dist - params.idealLength);
      force[e.from] = force[e.from]! + dir * f;
      force[e.to] = force[e.to]! - dir * f;
    }

    // Gravity toward origin — bounds disconnected components. 向心引力:钳住不连通分量。
    for (final id in ids) {
      force[id] = force[id]! - _pos[id]! * params.gravity;
    }

    // Integrate: velocity accumulates force·alpha, decays, then displaces (pinned nodes frozen).
    // 积分:速度累加 力·alpha,衰减,位移(钉住节点冻结)。
    final pinned = {for (final n in _nodes) n.id: n.pinned};
    for (final id in ids) {
      if (pinned[id] == true) {
        _vel[id] = Offset.zero;
        continue;
      }
      var v = (_vel[id]! + force[id]! * _alpha) * params.velocityDecay;
      _vel[id] = v;
      _pos[id] = _pos[id]! + v;
    }
    return true;
  }

  /// Run to the terminal layout (or a [maxIterations] backstop) in one shot — used for the first paint,
  /// reduced-motion, and headless tests. 一次跑到终局(或迭代封顶):首帧/reduced-motion/无头测试用。
  void settle({int maxIterations = 400}) {
    var i = 0;
    while (!settled && i < maxIterations) {
      tick();
      i++;
    }
  }

  /// Re-warm the sim (a drag started, a neighbor moved, or the data changed) so it re-squeezes and
  /// re-settles. 重加热(拖拽起/邻居动/数据变),让它重新挤压再静止。
  void reheat() {
    if (_alpha < params.reheatAlpha) _alpha = params.reheatAlpha;
  }

  /// Pin [id] at [pos] (a live drag) — the physics won't move it, but neighbors react. Reheats.
  /// 钉住 id 在 pos(拖拽中):物理不动它、邻居会反应。重加热。
  void pin(String id, Offset pos) {
    for (final n in _nodes) {
      if (n.id == id) n.pinned = true;
    }
    _pos[id] = pos;
    _vel[id] = Offset.zero;
    reheat();
  }

  /// Release a pinned node (drag ended) — it re-enters the physics. Reheats so it eases into place.
  /// 松开钉住节点(拖拽结束):重回物理;重加热让它归位。
  void unpin(String id) {
    for (final n in _nodes) {
      if (n.id == id) n.pinned = false;
    }
    reheat();
  }
}

/// In-degree of each node over a directed edge set — the count of edges POINTING AT it. The Overview
/// graph scales node radius by this (核心零件被越多实体挂载/引用越大); an entity nobody depends on has
/// in-degree 0 (renders smallest/faintest). Pure + headless-testable. 入度(指向它的边数):半径据此放大。
Map<String, int> inDegrees(Iterable<({String from, String to})> edges) {
  final d = <String, int>{};
  for (final e in edges) {
    if (e.from == e.to) continue;
    d[e.to] = (d[e.to] ?? 0) + 1;
  }
  return d;
}
