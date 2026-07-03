import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../contract/entities/values.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../graph/graph_model.dart';
import '../graph/graph_run_state.dart';
import 'an_button.dart';
import 'icons.dart';

/// The workflow-graph canvas (read plane) — the Flutter port of the demo's `an-graph-canvas`:
/// node cards + orthogonal rounded edges over a pannable/zoomable viewport, laid out by the pure
/// [layoutGraph] model. Hybrid architecture (the researched consensus for rich few-dozen-node
/// DAGs): nodes are REAL widgets (An* tokens, text, icons, semantics for free) positioned in a
/// transformed Stack; edges are a cached CustomPaint underlay. The viewport is self-managed
/// (Matrix4 + gestures, not InteractiveViewer): mouse wheel zooms TO THE CURSOR (拍板 #4;
/// InteractiveViewer's built-in wheel handling would win the PointerSignalResolver and can't be
/// disabled alone), trackpad two-finger pans and pinch zooms (they arrive as distinct pan-zoom
/// gestures on desktop), empty-space drag pans. `framed` is the entity-page preview flavour
/// (fixed height, hairline card frame, auto-refit on resize); un-framed fills its parent (the
/// editor ocean). Selection is CONTROLLED ([selectedNodeId] + [onNodeTap]) — pages derive it from
/// URL/state, the canvas never owns it. Run/edit planes land in later batches (WRK-055 W3/W5).
///
/// workflow 编排图画布(只读面)——demo `an-graph-canvas` 的 Flutter 移植:节点卡 + 正交圆角边,
/// 铺在可平移缩放的视口上,几何来自纯模型 [layoutGraph]。混合架构(业界共识):节点=真 widget
/// (An* token/文本/图标/语义全免费)、边=缓存 CustomPaint 底层。视口自管(Matrix4 + 手势、
/// 不用 InteractiveViewer):滚轮以光标为中心缩放(拍板 #4;IV 内置滚轮抢 PointerSignalResolver
/// 且无法单独关),触控板双指=平移、pinch=缩放(桌面端两者是独立 pan-zoom 手势),空白拖拽=平移。
/// framed=实体页预览形态(定高 + hairline 框 + 尺寸变化自动重 fit);非 framed 占满父容器(编辑器
/// 海洋)。选中受控([selectedNodeId] + [onNodeTap])——页面从 URL/state 派生,画布不持有。
/// 运行/编辑两面在后续批(WRK-055 W3/W5)。
class AnGraphCanvas extends StatefulWidget {
  const AnGraphCanvas({
    required this.graph,
    this.dir = GraphDirection.lr,
    this.run,
    this.framed = false,
    this.toolbar = true,
    this.selectedNodeId,
    this.onNodeTap,
    this.enterEditorLabel,
    this.onEnterEditor,
    super.key,
  });

  final Graph graph;
  final GraphDirection dir;

  /// The run overlay (W3): node states + walked/live edges painted over the definition. Null = pure
  /// definition view. 运行覆层:节点态 + 已走/活跃边;null = 纯定义视图。
  final GraphRunState? run;

  /// Entity-page preview flavour: fixed [AnSize.graphPreview] height + hairline card frame.
  /// 实体页预览形态:定高 + hairline 卡框。
  final bool framed;

  /// Floating zoom toolbar (top-left). 悬浮缩放工具条(左上)。
  final bool toolbar;

  /// Controlled selection — accent-ring the node with this id. 受控选中(accent 环)。
  final String? selectedNodeId;

  /// Node tap (background tap reports null → deselect). 点节点回调(点空白报 null → 取消选中)。
  final ValueChanged<String?>? onNodeTap;

  /// Both set → the toolbar grows the demo's "enter editor" action (label is caller i18n).
  /// 两者都给 → 工具条长出「进入编辑器」(文案由调用方 i18n)。
  final String? enterEditorLabel;
  final VoidCallback? onEnterEditor;

  @override
  State<AnGraphCanvas> createState() => _AnGraphCanvasState();
}

class _AnGraphCanvasState extends State<AnGraphCanvas> with TickerProviderStateMixin {
  static const double _minScale = 0.2;
  static const double _maxScale = 2.5;
  static const double _fitMaxScale = 1.3; // fit never blows a small graph up past this fit 不放大过此
  static const double _fitMinScale = 0.25;

  Matrix4 _view = Matrix4.identity();
  GraphLayout? _layout;
  Size _viewport = Size.zero;
  bool _fitted = false;

  // Scale-gesture bookkeeping: matrix + focal at gesture start, so update composes fresh each
  // frame (never accumulates drift). 手势起点矩阵 + 焦点,每帧从起点重组、不累积漂移。
  Matrix4? _gestureStart;
  Offset? _gestureFocal;

  // Run-plane animation drivers, created lazily and only while needed: the comet rides the live
  // edges (1.1s lap, demo cadence), the pulse breathes the running nodes' rings (AnMotion.breath).
  // Both feed painters/transitions via `repaint`/Listenable — never AnimatedBuilder-rebuild storms.
  // 运行面动画驱动,按需惰性创建:彗星沿活跃边(1.1s/圈)、脉冲呼吸 running 环(breath)。都走
  // repaint/Listenable 直驱,绝不 AnimatedBuilder 重建风暴。
  AnimationController? _comet;
  AnimationController? _pulse;

  void _syncTickers({required bool wantComet, required bool wantPulse}) {
    if (wantComet) {
      (_comet ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1100)))
          .repeat();
    } else {
      _comet?.stop();
    }
    if (wantPulse) {
      (_pulse ??= AnimationController(vsync: this, duration: AnMotion.breath)).repeat();
    } else {
      _pulse?.stop();
    }
  }

  @override
  void dispose() {
    _comet?.dispose();
    _pulse?.dispose();
    super.dispose();
  }

  GraphLayout get layout => _layout ??= layoutGraph(widget.graph, dir: widget.dir);

  @override
  void didUpdateWidget(AnGraphCanvas old) {
    super.didUpdateWidget(old);
    // Freezed deep == — an equal-value rebuild (the normal Riverpod map-from-DTO path) must NOT
    // relayout nor touch the user's viewport. A REAL graph/dir change re-fits right away (the demo's
    // setGraph/setDir contract); deferring via a flag would leave it to detonate on a later resize,
    // wiping a pan the user meant to keep. freezed 深比较——等值重建(Riverpod 正常 map 路径)不得
    // 重布局/动视口;真换图/换向当即重 fit(demo setGraph/setDir 契约),存旗延迟会在日后 resize
    // 时突爆、吞掉用户特意保留的平移。
    if (old.graph != widget.graph || old.dir != widget.dir) {
      _layout = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  // The view is only ever translate∘uniform-scale, so entry(0,0) IS the scale.
  // getMaxScaleOnAxis is a trap here: it includes the untouched z axis, so any k<1 reads as 1.
  // 视图矩阵只有平移∘等比缩放,(0,0) 项即缩放;getMaxScaleOnAxis 含未动的 z 轴,k<1 时错读为 1。
  double get _scale => _view.entry(0, 0);

  void _setView(Matrix4 m) => setState(() => _view = m);

  /// Fit the whole content into the viewport (demo fit): padded, centered, scale capped so tiny
  /// graphs don't balloon. 整图入框:留白、居中、上限防小图放大。
  void _fit() {
    if (_viewport == Size.zero) return;
    final content = layout.size;
    const pd = GraphGeometry.pad;
    var k = math.min(
      (_viewport.width - pd * 2) / content.width,
      (_viewport.height - pd * 2) / content.height,
    );
    k = k.isFinite && k > 0 ? math.min(k, _fitMaxScale) : 1;
    k = math.max(_fitMinScale, k);
    final x = (_viewport.width - content.width * k) / 2;
    final y = (_viewport.height - content.height * k) / 2;
    _setView(Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(k, k, 1, 1));
  }

  /// Zoom by [factor] keeping the scene point under [anchor] (viewport coords) still:
  /// `M' = T(anchor)·S(r)·T(-anchor)·M`. 以 anchor 下的场景点不动为约束缩放。
  void _zoomAt(Offset anchor, double factor) {
    final k = _scale;
    final nk = (k * factor).clamp(_minScale, _maxScale);
    final r = nk / k;
    if (r == 1) return;
    final t = Matrix4.identity()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(r, r, 1, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
    _setView(t.multiplied(_view));
  }

  void _zoomBy(double factor) =>
      _zoomAt(Offset(_viewport.width / 2, _viewport.height / 2), factor);

  void _onWheel(PointerScrollEvent e) =>
      _zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy * 0.0015));

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStart = _view.clone();
    _gestureFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final start = _gestureStart, focal = _gestureFocal;
    if (start == null || focal == null) return;
    // Compose from the gesture-start matrix: pan by focal travel, then pinch about the CURRENT
    // focal. 从起点矩阵重组:焦点位移=平移,pinch 绕当前焦点。
    final pan = Matrix4.identity()
      ..translateByDouble(d.localFocalPoint.dx - focal.dx, d.localFocalPoint.dy - focal.dy, 0, 1);
    var m = pan.multiplied(start);
    if (d.scale != 1) {
      final k = start.entry(0, 0);
      final nk = (k * d.scale).clamp(_minScale, _maxScale);
      final r = nk / k;
      final z = Matrix4.identity()
        ..translateByDouble(d.localFocalPoint.dx, d.localFocalPoint.dy, 0, 1)
        ..scaleByDouble(r, r, 1, 1)
        ..translateByDouble(-d.localFocalPoint.dx, -d.localFocalPoint.dy, 0, 1);
      m = z.multiplied(m);
    }
    _setView(m);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _gestureStart = null;
    _gestureFocal = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gc = context.graphColors;

    final stage = ClipRect(
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        if (size != _viewport) {
          _viewport = size;
          // Fit once on first real size; framed previews re-fit on every resize (demo's
          // ResizeObserver contract) — a fixed frame must always show the whole graph.
          // 首个真实尺寸 fit 一次;framed 随尺寸变化重 fit(定高框必须永远整图可见)。
          if ((!_fitted || widget.framed) && size.width > 0 && size.height > 0) {
            _fitted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fit();
            });
          }
        }
        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              GestureBinding.instance.pointerSignalResolver
                  .register(e, (e) => _onWheel(e as PointerScrollEvent));
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onTap: widget.onNodeTap == null ? null : () => widget.onNodeTap!(null),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Stack(children: [
                // Dot grid stays screen-fixed (demo .stage::before is untransformed backdrop).
                // 网格点钉屏幕、不随内容变换(同 demo)。
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _GridPainter(dot: gc.gridDot)),
                  ),
                ),
                Positioned.fill(
                  child: Transform(
                    // Keyed so tests (and later capture harnesses) can read the live view matrix
                    // precisely. 挂 key 让测试/截图 harness 精确读取视图矩阵。
                    key: const ValueKey('anGraphScene'),
                    transform: _view,
                    child: _scene(context),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );

    final withTools = Stack(children: [
      Positioned.fill(child: stage),
      if (widget.toolbar)
        Positioned(left: AnSpace.s12, top: AnSpace.s12, child: _toolbar(context)),
    ]);

    if (!widget.framed) return withTools;
    return Container(
      height: AnSize.graphPreview,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: withTools,
    );
  }

  /// The transformed scene: edges underlay → comet overlay → port pills → node cards. Sized to the
  /// layout so the unconstrained Stack children position against content coords.
  /// 变换场景:边底层 → 彗星层 → 端口药丸 → 节点卡。
  Widget _scene(BuildContext context) {
    final gc = context.graphColors;
    final c = context.colors;
    final l = layout;
    final run = widget.run;
    // Decorative loops gate off under reduced-motion/assistive tech (the live edge stays accent —
    // information survives, only the motion goes). 无障碍下装饰循环关停(活跃边仍 accent,信息不丢)。
    final still = AnMotionPref.reducedOrAssistive(context);
    final liveRoutes = run == null
        ? const <GraphEdgeRoute>[]
        : [for (final r in l.routes) if (run.liveEdges.contains(r.edge.id)) r];
    _syncTickers(
      wantComet: liveRoutes.isNotEmpty && !still,
      wantPulse: run != null && run.nodes.containsValue(GraphNodeRun.running) && !still,
    );
    // Canvas text is geometry-locked (node slots are GraphGeometry constants); accessibility text
    // scaling would overflow the 60px cards — magnification is the canvas ZOOM's job (demo SVG text
    // likewise ignores browser font scale). 画布文本几何钉死(节点槽是常量);辅助字号放大会撑破
    // 60px 卡——放大语义归画布缩放(demo SVG 文本同样不随浏览器字号)。
    return MediaQuery.withNoTextScaling(
        child: SizedBox(
      width: l.size.width,
      height: l.size.height,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _EdgePainter(
                layout: l,
                edge: gc.edge,
                back: c.accent,
                run: run,
                taken: c.ink,
                future: gc.edgeFuture,
              ),
            ),
          ),
        ),
        if (liveRoutes.isNotEmpty && !still)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CometPainter(routes: liveRoutes, color: c.accent, t: _comet!),
              ),
            ),
          ),
        for (final r in l.routes)
          if ((r.edge.fromPort ?? '').isNotEmpty)
            Positioned(
              left: r.mid.dx,
              top: r.mid.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: _PortPill(label: r.edge.fromPort!, isBack: r.isBack),
              ),
            ),
        for (final n in l.graph.nodes)
          if (l.nodeRects[n.id] case final rect?)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: _NodeCard(
                node: n,
                selected: n.id == widget.selectedNodeId,
                onTap: widget.onNodeTap == null ? null : () => widget.onNodeTap!(n.id),
                runState: run == null ? null : (run.nodes[n.id] ?? GraphNodeRun.future),
                iters: run?.iters[n.id] ?? 0,
                pulse: still ? null : _pulse,
              ),
            ),
      ]),
    ));
  }

  /// Floating zoom group — the canvas owns its zoom affordances (demo: 外设随画布走,消费点不重拼)。
  Widget _toolbar(BuildContext context) {
    final c = context.colors;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(AnSpace.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.button),
        border: Border.all(color: c.line, width: AnSize.hairline),
        boxShadow: c.shadowFloat,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnButton.iconOnly(AnIcons.zoomOut,
            size: AnButtonSize.sm, onPressed: () => _zoomBy(1 / 1.2), semanticLabel: t.a11y.graphZoomOut),
        AnButton.iconOnly(AnIcons.zoomIn,
            size: AnButtonSize.sm, onPressed: () => _zoomBy(1.2), semanticLabel: t.a11y.graphZoomIn),
        AnButton.iconOnly(AnIcons.expand,
            size: AnButtonSize.sm, onPressed: _fit, semanticLabel: t.a11y.graphFit),
        if (widget.onEnterEditor != null && (widget.enterEditorLabel ?? '').isNotEmpty) ...[
          Container(
            width: AnSize.hairline,
            height: AnSize.controlSm,
            margin: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
            color: c.line,
          ),
          AnButton(
            label: widget.enterEditorLabel,
            icon: AnIcons.workflow,
            size: AnButtonSize.sm,
            onPressed: widget.onEnterEditor,
          ),
        ],
      ]),
    );
  }
}

/// One node card: kind chip (soft family colour + icon) + id / ref double line, plus the run
/// overlay (state ring + status dot + breathing while running + ×N iteration stack + dashed future).
/// Real widget so text, tooltips and semantics come free. 节点卡:kind 色 chip + id/ref 双行 +
/// 运行覆层(状态环/状态点/running 呼吸/×N 叠卡/future 虚线),真 widget。
class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.selected,
    required this.onTap,
    this.runState,
    this.iters = 0,
    this.pulse,
  });

  final Node node;
  final bool selected;
  final VoidCallback? onTap;

  /// Null = definition view (no run overlay). 运行态;null=纯定义视图。
  final GraphNodeRun? runState;
  final int iters;

  /// The shared breath driver (null under reduced motion → a static ring instead). 共享呼吸驱动。
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gc = context.graphColors;
    final (kindColor, kindSoft) = _kindColors(node.kind, c, gc);
    final t = context.t;
    final rs = runState;
    final future = rs == GraphNodeRun.future;
    final (Color ring, double ringW) = selected
        ? (c.accent, 1.5)
        : switch (rs) {
            GraphNodeRun.running => (c.accentLine, 1.6),
            GraphNodeRun.failed => (c.danger, 1.6),
            GraphNodeRun.parked => (c.warn, 1.6),
            // A future card carries NO solid border (the dashed overlay is the border). future 卡实线边让位虚线。
            GraphNodeRun.future => (const Color(0x00000000), AnSize.hairline),
            _ => (c.line, AnSize.hairline),
          };
    final dotColor = switch (rs) {
      GraphNodeRun.running => c.accent,
      GraphNodeRun.failed => c.danger,
      GraphNodeRun.parked => c.warn,
      _ => c.inkFaint,
    };

    final card = Container(
      decoration: BoxDecoration(
        color: future ? c.surfaceSubtle : c.surface,
        borderRadius: BorderRadius.circular(AnRadius.card),
        border: Border.all(color: ring, width: ringW),
        boxShadow: future ? null : c.shadowIsland,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: kindSoft,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Icon(AnIcons.node(node.kind.name), size: 18, color: kindColor),
        ),
        const SizedBox(width: AnSpace.s8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink),
              ),
              Text(
                node.ref,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.code.copyWith(color: c.inkFaint),
              ),
            ],
          ),
        ),
      ]),
    );

    return Semantics(
      label: t.a11y.graphNode(id: node.id, kind: _kindLabel(t, node.kind), ref: node.ref),
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
          child: Stack(clipBehavior: Clip.none, children: [
            // Iteration ghosts stack UNDER the card (demo's ×N 叠卡:offset shadows read as "this
            // slot ran multiple times"). 迭代影子叠在卡下(×N 叠卡)。
            if (iters > 1) ...[
              _ghost(c, ring, const Offset(6, 6), 0.35),
              _ghost(c, ring, const Offset(3, 3), 0.6),
            ],
            Positioned.fill(child: future ? _dashedWrap(c, card) : card),
            if (rs == GraphNodeRun.running)
              Positioned.fill(
                child: IgnorePointer(
                  child: pulse == null
                      ? _breathRing(c, 0.35)
                      : FadeTransition(
                          // 0→.5→0 over one breath (demo's opacity keyframes). 一次呼吸 0→.5→0。
                          opacity: pulse!.drive(TweenSequence([
                            TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.5), weight: 1),
                            TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.0), weight: 1),
                          ])),
                          child: _breathRing(c, 1),
                        ),
                ),
              ),
            if (rs != null)
              Positioned(
                right: AnSpace.s8,
                top: AnSpace.s8,
                child: IgnorePointer(
                  child: Container(
                    width: AnSize.dot,
                    height: AnSize.dot,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                ),
              ),
            if (iters > 1)
              Positioned(
                right: AnSpace.s8,
                bottom: AnSpace.s4,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(AnRadius.pill),
                    ),
                    child: Text('×$iters',
                        style: AnText.metaTabular().weight(AnText.emphasisWeight).copyWith(color: c.accent)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _ghost(AnColors c, Color ring, Offset offset, double opacity) => Positioned.fill(
        child: IgnorePointer(
          child: Transform.translate(
            offset: offset,
            child: Opacity(
              opacity: opacity,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AnRadius.card),
                  border: Border.all(color: c.line, width: AnSize.hairline),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _breathRing(AnColors c, double opacity) => Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnRadius.card),
            border: Border.all(color: c.accent, width: 2),
          ),
        ),
      );

  Widget _dashedWrap(AnColors c, Widget card) => CustomPaint(
        foregroundPainter: _DashedRRectPainter(color: c.line),
        child: card,
      );

  /// Localized node-kind word for assistive labels (the enum's Dart name is English and would
  /// read half-translated). 无障碍标签用的本地化 kind 词(枚举名是英文,直插读作夹生)。
  static String _kindLabel(Translations t, NodeKind k) => switch (k) {
        NodeKind.trigger => t.graph.kind.trigger,
        NodeKind.action => t.graph.kind.action,
        NodeKind.agent => t.graph.kind.agent,
        NodeKind.control => t.graph.kind.control,
        NodeKind.approval => t.graph.kind.approval,
        NodeKind.unknown => t.graph.kind.unknown,
      };

  /// Kind → (main, soft) family. action=accent / control=warn / approval=danger reuse the chrome
  /// palette; trigger/agent take the graph-only families; unknown degrades to neutral ink.
  /// kind → 色族:action/control/approval 复用 chrome 板;trigger/agent 用图专属族;unknown 降级中性。
  static (Color, Color) _kindColors(NodeKind k, AnColors c, GraphColors gc) => switch (k) {
        NodeKind.trigger => (gc.violet, gc.violetSoft),
        NodeKind.action => (c.accent, c.accentSoft),
        NodeKind.agent => (gc.teal, gc.tealSoft),
        NodeKind.control => (c.warn, c.warnSoft),
        NodeKind.approval => (c.danger, c.dangerSoft),
        NodeKind.unknown => (c.inkMuted, c.surfaceSunken),
      };
}

/// The edge-port pill at the route midpoint (control branch names / approval yes·no). Back-edge
/// pills read accent (they mark the loop). 线中点端口药丸;回边药丸 accent(标记循环)。
class _PortPill extends StatelessWidget {
  const _PortPill({required this.label, required this.isBack});

  final String label;
  final bool isBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6, vertical: AnSpace.s2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.button),
        border: Border.all(color: isBack ? c.accentLine : c.line, width: AnSize.hairline),
      ),
      child: Text(
        label,
        style: AnText.meta.weight(AnText.emphasisWeight).copyWith(
              color: isBack ? c.accent : c.inkMuted,
            ),
      ),
    );
  }
}

/// Static edge underlay: rounded orthogonal polylines + arrowheads; back edges dashed accent. In
/// run mode each edge picks a tier (demo semantics): live (accent, bold — the comet rides on the
/// separate overlay) > taken (ink, bold) > base (target walked) > future (faint dashed). Colours
/// arrive resolved from build (painters can't read Theme — and theme flips must repaint, which the
/// shouldRepaint equality below guarantees). 静态边底层:圆角正交折线 + 箭头;回边虚线 accent。
/// 运行态每边取 tier:live(accent 粗,彗星在独立覆层)> taken(墨粗)> base(目标已走)>
/// future(淡虚线)。色值 build 解析后传入。
class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.layout,
    required this.edge,
    required this.back,
    this.run,
    required this.taken,
    required this.future,
  });

  final GraphLayout layout;
  final Color edge; // resting edge + arrow 静止边
  final Color back; // back edge / live (accent) 回边·活跃
  final GraphRunState? run;
  final Color taken; // walked edge (ink) 已走边
  final Color future; // not-yet-walked edge 未走边

  static const double _strokeW = 1.8;
  static const double _takenW = 2.3;
  static const double _liveW = 2.6;
  static const double _arrowLen = 7;
  static const double _arrowHalf = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final r0 = run;
    for (final r in layout.routes) {
      var color = r.isBack ? back : edge;
      var w = _strokeW;
      var dashed = r.isBack;
      if (r0 != null) {
        if (r0.liveEdges.contains(r.edge.id)) {
          color = back;
          w = _liveW;
        } else if (r0.takenEdges.contains(r.edge.id)) {
          color = taken;
          w = _takenW;
        } else if (!r0.nodes.containsKey(r.edge.to)) {
          color = future;
          dashed = true;
        }
      }
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      var path = _rounded(r.points, GraphGeometry.corner);
      if (dashed) path = _dash(path, on: r.isBack ? 6 : 5, off: 5);
      canvas.drawPath(path, paint);
      _arrow(canvas, r.points, color);
    }
  }

  /// Rounded polyline: cut [radius] short of each interior bend and quad through the corner —
  /// radius clamps to half the adjoining segments so short segments never fold back.
  /// 圆角折线:每个内拐角提前 r 停、二次贝塞尔过角;r 夹到邻段一半防短段回折。
  static Path _rounded(List<Offset> raw, double radius) {
    final pts = <Offset>[];
    for (final p in raw) {
      if (pts.isEmpty || (pts.last - p).distance > 0.5) pts.add(p);
    }
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    if (pts.length < 2) return path;
    for (var i = 1; i < pts.length - 1; i++) {
      final p = pts[i], a = pts[i - 1], b = pts[i + 1];
      final v1 = p - a, v2 = b - p;
      final l1 = v1.distance == 0 ? 1.0 : v1.distance;
      final l2 = v2.distance == 0 ? 1.0 : v2.distance;
      final r = math.min(radius, math.min(l1 / 2, l2 / 2));
      final inPt = p - v1 / l1 * r;
      final outPt = p + v2 / l2 * r;
      path.lineTo(inPt.dx, inPt.dy);
      path.quadraticBezierTo(p.dx, p.dy, outPt.dx, outPt.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  /// Filled triangle arrowhead oriented along the final segment. 沿末段方向的实心三角箭头。
  static void _arrow(Canvas canvas, List<Offset> pts, Color color) {
    if (pts.length < 2) return;
    final tip = pts.last;
    var i = pts.length - 2;
    while (i > 0 && (pts[i] - tip).distance < 0.5) {
      i--;
    }
    final dirV = tip - pts[i];
    if (dirV.distance == 0) return;
    final u = dirV / dirV.distance;
    final n = Offset(-u.dy, u.dx);
    final base = tip - u * _arrowLen;
    final tri = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + n.dx * _arrowHalf, base.dy + n.dy * _arrowHalf)
      ..lineTo(base.dx - n.dx * _arrowHalf, base.dy - n.dy * _arrowHalf)
      ..close();
    canvas.drawPath(tri, Paint()..color = color);
  }

  static Path _dash(Path source, {required double on, required double off}) {
    final out = Path();
    for (final PathMetric m in source.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
        d += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      !identical(old.layout, layout) ||
      old.edge != edge ||
      old.back != back ||
      !identical(old.run, run) ||
      old.taken != taken ||
      old.future != future;
}

/// The comet overlay — one dot lapping each live edge, driven by the controller via `repaint` (the
/// painter repaints per tick; the widget tree never rebuilds). 彗星覆层:每条活跃边一点循环,
/// controller 经 repaint 直驱(逐 tick 重绘、树零重建)。
class _CometPainter extends CustomPainter {
  _CometPainter({required this.routes, required this.color, required this.t}) : super(repaint: t);

  final List<GraphEdgeRoute> routes;
  final Color color;
  final Animation<double> t;

  static const double _r = 3.6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final r in routes) {
      final path = _EdgePainter._rounded(r.points, GraphGeometry.corner);
      for (final m in path.computeMetrics()) {
        final tangent = m.getTangentForOffset(m.length * t.value);
        if (tangent != null) canvas.drawCircle(tangent.position, _r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CometPainter old) =>
      !identical(old.routes, routes) || old.color != color || old.t != t;
}

/// Hairline dashed rounded border — the future (not-yet-walked) node card frame (same idiom as
/// AnTransformBox's empty slot). 虚线圆角边框(future 节点卡;同变换盒空槽做法)。
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AnRadius.card)));
    canvas.drawPath(
      _EdgePainter._dash(source, on: 4, off: 4),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AnSize.hairline,
    );
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color;
}

/// The screen-fixed dot grid backdrop. 钉屏幕的网格点背景。
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.dot});

  final Color dot;

  static const double _spacing = AnSpace.s24;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dot;
    for (var x = _spacing / 2; x < size.width; x += _spacing) {
      for (var y = _spacing / 2; y < size.height; y += _spacing) {
        canvas.drawCircle(Offset(x, y), AnSize.hairline, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.dot != dot;
}
