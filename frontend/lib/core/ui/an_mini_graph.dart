import 'package:flutter/material.dart';

import '../contract/entities/values.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../graph/graph_model.dart';
import 'icons.dart';

/// A READ-ONLY mini workflow-graph preview (WRK-056 #22) — the light sibling of [AnGraphCanvas] (the
/// full editor): it reuses the SAME pure geometry ([layoutGraph]) so the mini and the editor lay a
/// graph out identically, but drops all of the editor's weight — no InteractiveViewer pan/zoom, no run
/// overlay, no connect handles, no drag. The whole graph is scaled to fit a bounded framed box
/// (BoxFit.contain), so it always shows in full inside a tool card. Nodes render as compact kind-tinted
/// chips (the 5-colour node family: trigger violet / action accent / agent teal / control warn /
/// approval danger); edges are the orthogonal routes [layoutGraph] already computed. It is the canvas
/// the F04 create_workflow / edit_workflow build cards embed; [GraphRevealState] (B2.4) will animate a
/// settle-then-replay growth on top of the same geometry.
///
/// 只读迷你工作流图预览——[AnGraphCanvas] 全编辑器的轻量弟弟:复用**同一纯几何** [layoutGraph](mini 与
/// 编辑器布局一致),但去掉编辑器全部重量(无 IV 平移缩放、无 run 覆层、无连接柄、无拖拽)。整图 fit 进
/// 定框(BoxFit.contain),tool 卡里永远整图可见。节点=紧凑 kind 五色 chip;边=layoutGraph 已算好的正交路由。
/// create_workflow/edit_workflow 构建卡内嵌它;GraphRevealState(B2.4)将在同几何上做 settle-then-replay 生长。
class AnMiniGraph extends StatelessWidget {
  const AnMiniGraph({
    required this.graph,
    this.dir = GraphDirection.lr,
    this.height = _defaultHeight,
    this.framed = true,
    this.onNodeTap,
    this.revealProgress,
    super.key,
  });

  final Graph graph;
  final GraphDirection dir;
  final double height;

  /// Framed = a bordered surface card (the tool-card embed); false = just the scaled scene. framed=带边卡。
  final bool framed;

  /// A node tap (deep-link to the workflow editor node); null = non-interactive. 节点点击(深链);null=不可点。
  final ValueChanged<String>? onNodeTap;

  /// The settle-then-replay GROWTH frame (WRK-056 #23): 0 = nothing yet, 1 = fully shown. As it sweeps
  /// 0→1 the geometry stays FROZEN (laid out once) and nodes fade+scale in by topological rank, edges
  /// draw in after their source lands. This is the PURE render frame — [AnMiniGraphGrowth] is the driver
  /// that animates it; null = a static, fully-shown graph. 生长帧(几何冻结、按 rank 浮现+边 draw-in);
  /// 纯渲染帧,驱动在 AnMiniGraphGrowth;null=静态整图。
  final double? revealProgress;

  static const double _defaultHeight = 220;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (graph.nodes.isEmpty) {
      final body = SizedBox(
        height: height,
        child: Center(
          child: Icon(AnIcons.workflow, size: AnSize.stateIcon, color: c.inkFaint),
        ),
      );
      return framed ? _frame(context, body) : body;
    }
    final layout = layoutGraph(graph, dir: dir);
    final ranks = graphRanks(layout);
    final maxRank = ranks.values.isEmpty ? 0 : ranks.values.reduce((a, b) => a > b ? a : b);
    final progress = revealProgress ?? 1.0;
    final scene = MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: layout.size.width,
        height: layout.size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MiniEdgePainter(
                    layout: layout,
                    color: context.graphColors.edge,
                    back: c.accent,
                    ranks: ranks,
                    maxRank: maxRank,
                    progress: progress,
                  ),
                ),
              ),
            ),
            for (final n in graph.nodes)
              if (layout.nodeRects[n.id] case final rect?)
                Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: _revealed(
                    nodeRevealAt(ranks[n.id] ?? 0, maxRank, progress),
                    _MiniNode(node: n, onTap: onNodeTap == null ? null : () => onNodeTap!(n.id)),
                  ),
                ),
          ],
        ),
      ),
    );
    // Fit the whole scene into the framed box — always full, never scrolls/pans. 整图 fit,永不滚不平移。
    final fitted = SizedBox(
      height: height,
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: scene,
      ),
    );
    return framed ? _frame(context, fitted) : fitted;
  }

  Widget _frame(BuildContext context, Widget child) {
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: child,
    );
  }
}

/// The DRIVER for [AnMiniGraph]'s settle-then-replay growth: on first mount it animates the reveal 0→1
/// ONCE (duration ≈ ranks × 250ms, capped 3s), then rests at the settled graph. Under reduced motion it
/// jumps straight to the settled graph (no ticker) — the growth is decoration, the graph is the info
/// (WCAG 2.3.3). The tool card mounts this once the workflow's op stream has settled.
///
/// AnMiniGraph 生长驱动:首次挂载 0→1 播一次(rank×250ms 封顶 3s)后停在终态;reduced 直落终态(无
/// ticker)——生长是装饰、图才是信息。tool 卡在 workflow op 流落定后挂载它。
class AnMiniGraphGrowth extends StatefulWidget {
  const AnMiniGraphGrowth({
    required this.graph,
    this.dir = GraphDirection.lr,
    this.height = AnMiniGraph._defaultHeight,
    this.framed = true,
    this.onNodeTap,
    super.key,
  });

  final Graph graph;
  final GraphDirection dir;
  final double height;
  final bool framed;
  final ValueChanged<String>? onNodeTap;

  @override
  State<AnMiniGraphGrowth> createState() => _AnMiniGraphGrowthState();
}

class _AnMiniGraphGrowthState extends State<AnMiniGraphGrowth>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Duration scales with the number of columns (each rank gets ~250ms — a scaling-formula
    // coefficient anchored here, not a tier), hard-capped at [AnMotion.revealCap]. 时长随列数(250=公式系数),封顶走档。
    final rankCount = widget.graph.nodes.isEmpty ? 1 : graphRanks(layoutGraph(widget.graph, dir: widget.dir)).values.fold<int>(0, (m, r) => r > m ? r : m) + 1;
    final ms = (rankCount * 250).clamp(250, AnMotion.revealCap.inMilliseconds);
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: ms));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AnMotionPref.reducedOrAssistive(context)) {
      _c.value = 1.0; // settled frame, no motion 终态帧、无动效
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => AnMiniGraph(
        graph: widget.graph,
        dir: widget.dir,
        height: widget.height,
        framed: widget.framed,
        onNodeTap: widget.onNodeTap,
        revealProgress: _c.value,
      ),
    );
  }
}

// ── settle-then-replay growth (WRK-056 #23) ──────────────────────────────────

/// Each node's topological RANK = its layout column (distinct x-positions, left→right from 0). The
/// growth reveals rank by rank. 节点拓扑 rank = 布局列(相异 x,从左到右自 0)。
Map<String, int> graphRanks(GraphLayout layout) {
  final lefts = <double>{for (final r in layout.nodeRects.values) _q(r.left)}.toList()..sort();
  final rankOf = {for (var k = 0; k < lefts.length; k++) lefts[k]: k};
  return {for (final e in layout.nodeRects.entries) e.key: rankOf[_q(e.value.left)] ?? 0};
}

// Quantize x so tiny float drift within a column groups to one rank. 量化 x,同列微差归一 rank。
double _q(double x) => (x / 4).roundToDouble();

/// The reveal amount (0..1) of a node at [rank] when the growth is at [progress] — the sweep passes
/// left→right so rank r lands around progress r/(maxRank+1), over a one-step window. progress ≥ 1 = full.
/// 节点浮现量:progress 从左扫到右,rank r 约在 r/(maxRank+1) 落定。
double nodeRevealAt(int rank, int maxRank, double progress) {
  if (progress >= 1.0) return 1.0;
  final span = maxRank + 1;
  return (progress * span - rank).clamp(0.0, 1.0);
}

/// The draw-in fraction (0..1) of an edge whose SOURCE is at [fromRank] — an edge draws only after its
/// source node has landed (a small lead keeps the line from outrunning the node). 边 draw-in:源节点落定后才画。
double edgeDrawAt(int fromRank, int maxRank, double progress) {
  if (progress >= 1.0) return 1.0;
  final span = maxRank + 1;
  return (progress * span - fromRank - 0.4).clamp(0.0, 1.0);
}

/// Wrap a node in the reveal transform: fade + a subtle scale-up (0.9→1). At r≥1 the child is returned
/// untouched (no wasted Opacity/Transform layers on a settled graph). 浮现变换:淡入+微放大;r≥1 原样返回。
Widget _revealed(double r, Widget child) {
  if (r >= 1.0) return child;
  return Opacity(
    opacity: r,
    child: Transform.scale(scale: 0.9 + 0.1 * r, child: child),
  );
}

/// The 5-colour node-kind family (blueprint): trigger violet / action accent / agent teal / control
/// warn / approval danger / unknown faint. 节点 kind 五色族。
Color nodeKindColor(BuildContext context, NodeKind kind) {
  final c = context.colors;
  final g = context.graphColors;
  return switch (kind) {
    NodeKind.trigger => g.violet,
    NodeKind.agent => g.teal,
    NodeKind.action => c.accent,
    NodeKind.control => c.warn,
    NodeKind.approval => c.danger,
    NodeKind.unknown => c.inkFaint,
  };
}

/// A node's icon glyph — the entity/kind family. 节点字形。
IconData nodeKindIcon(NodeKind kind) => AnIcons.node(kind.name);

class _MiniNode extends StatelessWidget {
  const _MiniNode({required this.node, this.onTap});

  final Node node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kc = nodeKindColor(context, node.kind);
    final label = node.ref.isNotEmpty ? node.ref : node.id;
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(left: BorderSide(color: kc, width: AnSpace.s2)),
        borderRadius: BorderRadius.circular(AnRadius.card),
        boxShadow: [BoxShadow(color: c.line, blurRadius: 0, spreadRadius: AnSize.hairline)],
      ),
      child: Row(
        children: [
          Icon(nodeKindIcon(node.kind), size: AnSize.icon, color: kc),
          const SizedBox(width: AnGap.inline),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

/// The orthogonal edge routes [layoutGraph] computed — painted as straight polylines through the route
/// points (back edges in accent). The mini omits the editor's rounded-corner + arrowhead detail; the
/// routing itself is identical. 正交边路由(直折线穿路由点;回边 accent)。mini 省圆角/箭头细节,路由本身一致。
class _MiniEdgePainter extends CustomPainter {
  _MiniEdgePainter({
    required this.layout,
    required this.color,
    required this.back,
    required this.ranks,
    required this.maxRank,
    required this.progress,
  });

  final GraphLayout layout;
  final Color color;
  final Color back;
  final Map<String, int> ranks;
  final int maxRank;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final route in layout.routes) {
      if (route.points.length < 2) continue;
      // Draw-in: an edge appears only after its source node lands (growth). 边随源节点落定后 draw-in。
      final frac = edgeDrawAt(ranks[route.edge.from] ?? 0, maxRank, progress);
      if (frac <= 0.0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AnSize.ring
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = route.isBack ? back : color;
      final full = Path()..moveTo(route.points.first.dx, route.points.first.dy);
      for (final p in route.points.skip(1)) {
        full.lineTo(p.dx, p.dy);
      }
      if (frac >= 1.0) {
        canvas.drawPath(full, paint);
        final a = route.points[route.points.length - 2];
        final b = route.points.last;
        _arrowhead(canvas, a, b, paint..style = PaintingStyle.fill);
      } else {
        // Partial: extract the leading fraction of the routed path (the line grows toward the target).
        // 部分:抽路径前段(线朝目标生长);未到目标前不画箭头。
        for (final metric in full.computeMetrics()) {
          canvas.drawPath(metric.extractPath(0, metric.length * frac), paint);
        }
      }
    }
  }

  void _arrowhead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dir = (to - from);
    final len = dir.distance;
    if (len < 0.01) return;
    final u = dir / len;
    const size = 6.0;
    final base = to - u * size;
    final perp = Offset(-u.dy, u.dx) * (size * 0.5);
    final tri = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + perp.dx, base.dy + perp.dy)
      ..lineTo(base.dx - perp.dx, base.dy - perp.dy)
      ..close();
    canvas.drawPath(tri, paint);
  }

  @override
  bool shouldRepaint(_MiniEdgePainter old) =>
      old.layout != layout || old.color != color || old.back != back || old.progress != progress;
}
