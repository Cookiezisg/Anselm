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
    super.key,
  });

  final Graph graph;
  final GraphDirection dir;
  final double height;

  /// Framed = a bordered surface card (the tool-card embed); false = just the scaled scene. framed=带边卡。
  final bool framed;

  /// A node tap (deep-link to the workflow editor node); null = non-interactive. 节点点击(深链);null=不可点。
  final ValueChanged<String>? onNodeTap;

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
    final scene = MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: layout.size.width,
        height: layout.size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _MiniEdgePainter(layout: layout, color: context.graphColors.edge, back: c.accent)),
              ),
            ),
            for (final n in graph.nodes)
              if (layout.nodeRects[n.id] case final rect?)
                Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: _MiniNode(node: n, onTap: onNodeTap == null ? null : () => onNodeTap!(n.id)),
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
  _MiniEdgePainter({required this.layout, required this.color, required this.back});

  final GraphLayout layout;
  final Color color;
  final Color back;

  @override
  void paint(Canvas canvas, Size size) {
    for (final route in layout.routes) {
      if (route.points.length < 2) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AnSize.hairline * 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = route.isBack ? back : color;
      final path = Path()..moveTo(route.points.first.dx, route.points.first.dy);
      for (final p in route.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      // A small arrowhead at the destination so direction reads. 终点小箭头,方向可读。
      final a = route.points[route.points.length - 2];
      final b = route.points.last;
      _arrowhead(canvas, a, b, paint..style = PaintingStyle.fill);
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
      old.layout != layout || old.color != color || old.back != back;
}
