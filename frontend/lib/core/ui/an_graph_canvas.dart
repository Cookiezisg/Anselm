import 'dart:math' as math;
import 'dart:ui' show PathMetric, PointMode;

import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../contract/entities/values.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../graph/graph_model.dart';
import '../graph/graph_run_state.dart';
import 'an_button.dart';
import 'an_divider.dart';
import 'an_floating_bar.dart';
import 'icons.dart';

/// The workflow-graph canvas — the Flutter port of the demo's `an-graph-canvas`: node cards +
/// orthogonal rounded edges over a pannable/zoomable viewport, laid out by the pure [layoutGraph]
/// model. Hybrid architecture (the researched consensus for rich few-dozen-node DAGs): nodes are
/// REAL widgets (An* tokens, text, icons, semantics for free) positioned in a transformed Stack;
/// edges are a cached CustomPaint underlay. The viewport rides a plain [InteractiveViewer] (拍板:
/// adopt the battle-tested substrate, don't hand-manage a Matrix4): mouse wheel zooms TO THE CURSOR,
/// trackpad two-finger pans and pinch zooms (both free — IV's ScaleGestureRecognizer consumes the
/// PointerPanZoom stream), empty-space drag pans. The node/handle drags run on raw Listeners and flip
/// IV's `panEnabled` off for their duration, so the canvas holds still under a drag without the
/// scale-vs-pan arena stealing it. `framed` is the entity-page preview flavour (fixed height, hairline
/// card frame, auto-refit on resize); un-framed fills its parent (the editor ocean). Selection is
/// CONTROLLED ([selectedNodeId] + [onNodeTap]) — pages derive it from URL/state, the canvas never owns
/// it.
///
/// workflow 编排图画布——demo `an-graph-canvas` 的 Flutter 移植:节点卡 + 正交圆角边,铺在可平移缩放的
/// 视口上,几何来自纯模型 [layoutGraph]。混合架构(业界共识):节点=真 widget(An* token/文本/图标/
/// 语义全免费)、边=缓存 CustomPaint 底层。视口骑在原生 [InteractiveViewer] 上(拍板:采用久经考验的
/// 基座,不再手管 Matrix4):滚轮以光标为中心缩放,触控板双指=平移、pinch=缩放(都白拿——IV 的
/// ScaleGestureRecognizer 吃 PointerPanZoom 流),空白拖拽=平移。节点/柄拖走裸 Listener 并在其间把 IV 的
/// `panEnabled` 置 false,画布在拖拽下不动、不被 scale-vs-pan 竞技场抢走。framed=实体页预览形态(定高 +
/// hairline 框 + 尺寸变化自动重 fit);非 framed 占满父容器(编辑器海洋)。选中受控([selectedNodeId] +
/// [onNodeTap])——页面从 URL/state 派生,画布不持有。
///
/// A test-only hook fired each time a node card BUILDS — the C-016 drag-isolation test uses it to assert
/// that a pointer-move rebuilds only the cheap per-node Positioned wrappers, never the N node cards.
/// 测试钩子:每张节点卡 build 时触发——C-016 拖拽隔离测据此断言移动只重跑轻量 Positioned、不重建 N 张卡。
abstract final class GraphCanvasProbe {
  @visibleForTesting
  static void Function()? onNodeCardBuild;
}

class AnGraphCanvas extends StatefulWidget {
  const AnGraphCanvas({
    required this.graph,
    this.dir = GraphDirection.lr,
    this.run,
    this.framed = false,
    this.framedHeight,
    this.toolbar = true,
    this.toolbarAlignment = Alignment.topLeft,
    this.selectedNodeId,
    this.onNodeTap,
    this.editable = false,
    this.selectedEdgeId,
    this.onEdgeTap,
    this.onNodeMoved,
    this.onConnect,
    this.enterEditorLabel,
    this.onEnterEditor,
    super.key,
  });

  final Graph graph;
  final GraphDirection dir;

  /// The run overlay (W3): node states + walked/live edges painted over the definition. Null = pure
  /// definition view. 运行覆层:节点态 + 已走/活跃边;null = 纯定义视图。
  final GraphRunState? run;

  /// Entity-page preview flavour: fixed height + hairline card frame.
  /// 实体页预览形态:定高 + hairline 卡框。
  final bool framed;

  /// The [framed] height; null → [AnSize.graphPreview] (the entity-page default). A shorter override lets
  /// an embedded preview (a chat tool card) share the SAME framed rendering at a more compact height.
  /// framed 高;空=AnSize.graphPreview(实体页默认)。缩短值让内嵌预览(chat tool 卡)复用同款 framed 渲染、更紧凑。
  final double? framedHeight;

  /// Floating zoom toolbar. 悬浮缩放工具条。
  final bool toolbar;

  /// Where the zoom toolbar floats (default top-left; the frameless editor moves it to bottom-left so
  /// it clears the top chrome + the OS traffic lights). 缩放工具条停靠(默认左上;无边框编辑器移到左下、
  /// 让开顶部 chrome + 红绿灯)。
  final Alignment toolbarAlignment;

  /// Controlled selection — accent-ring the node with this id. 受控选中(accent 环)。
  final String? selectedNodeId;

  /// Node tap (background tap reports null → deselect). 点节点回调(点空白报 null → 取消选中)。
  final ValueChanged<String?>? onNodeTap;

  /// Edit plane (W5): node drag → [onNodeMoved]; four-side connect handles → [onConnect]; edge tap →
  /// [onEdgeTap] ([selectedEdgeId] accent-highlights). 编辑面:节点拖拽/连接柄/边点选。
  final bool editable;
  final String? selectedEdgeId;
  final ValueChanged<String>? onEdgeTap;
  final void Function(String id, NodePosition pos)? onNodeMoved;
  final void Function(String from, String to)? onConnect;

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
  // Wheel step: exp(-dy / _wheelScaleFactor); ≈666.67 reproduces the demo's 0.0015-per-pixel feel
  // (InteractiveViewer's mousewheel path uses the same exp(-dy/scaleFactor) zoom-to-cursor).
  // 滚轮步长:与 demo 0.0015/px 手感等价(IV 滚轮同款 exp(-dy/scaleFactor) 到光标缩放)。
  static const double _wheelScaleFactor = 666.6667;
  // Max press travel (viewport px) still counted as a tap (vs a drag/pan). 判为点击的最大按下位移(视口px)。
  static const double _tapSlop = 6.0;

  // The viewport transform lives in InteractiveViewer's controller (adopt its battle-tested
  // pan/zoom/pinch + wheel-to-cursor instead of hand-managing a Matrix4). We SET .value for fit and
  // the zoom toolbar, and READ entry(0,0) for scene-space measures. 视口变换托管在 IV 的 controller
  // (采用其久经考验的平移/缩放/pinch/滚轮到光标,不再手管 Matrix4);fit 与缩放工具条写它、量度读它。
  final TransformationController _tc = TransformationController();
  GraphLayout? _layout;
  Size _viewport = Size.zero;
  bool _fitted = false;

  // While a node/handle interaction owns the pointer, IV's pan switches OFF (panEnabled=false) so the
  // canvas doesn't slide under the drag; the drag itself runs on a raw Listener (arena-free) whose
  // localDelta is already scene space. 节点/柄交互占用指针时关掉 IV 平移,画布在拖拽下不滑;拖拽本身走
  // 裸 Listener(不进竞技场),其 localDelta 天然是场景坐标。
  bool _suppressPan = false;

  // Pointer-down position for the arena-free tap detector (viewport coords), and the node whose card
  // the press landed on (recorded by the card's own Listener → the reliable, frame-sync-proof node id
  // for a tap; toScene is used only for edges/empty). 裸点击探测的按下位(视口坐标)+ 按下命中的节点卡 id
  // (由卡自己的 Listener 记 → 点击选中的可靠、无帧同步问题的节点 id;toScene 只用于边/空白)。
  Offset? _tapDown;
  String? _pressedNodeId;
  // Set once a press crosses the node/handle drag slop → the viewport tap detector then suppresses the
  // tap, so a small node drag never ALSO toggles selection (the two slops differ: node drag is scene
  // space, tap is viewport space, leaving an overlap band that would fire both). 一旦按下越过节点/柄拖拽
  // 阈值即置位 → 视口点击探测抑制 tap,微拖不再顺带切换选中(两阈值坐标系不同、有重叠带会齐发)。
  bool _draggedThisPress = false;

  // Edit-mode interaction state (W5). A node drag tracks the dragged id + its live scene top-left
  // (committed on release); a connect drag tracks the source id + the pointer scene position (a
  // rubber-band edge). 编辑态:节点拖(id + 活场景左上,松手提交)/ 连接拖(源 id + 指针场景位,橡皮筋)。
  String? _dragId;
  // C-016: the live drag position lives in a ValueNotifier, NOT setState — a pointer-move drives ONLY
  // the per-node [ValueListenableBuilder] wrappers (cheap Positioned re-layout), never a whole-canvas
  // rebuild of every _NodeCard. 活拖拽位在 ValueNotifier(非 setState):移动只驱动逐节点 VLB 的轻量 Positioned,
  // 不整画布重建 N 张卡。
  final ValueNotifier<Offset?> _dragScenePos = ValueNotifier(null);
  String? _connectFrom;
  Offset? _connectScene;
  String? _hoverNodeId; // the node whose connect handles are shown (edit mode) 显连接柄的节点

  // Run-plane animation drivers, created lazily and only while needed: the comet rides the live
  // edges ([AnMotion.travel] lap), the pulse breathes the running nodes' rings (AnMotion.breath).
  // Both feed painters/transitions via `repaint`/Listenable — never AnimatedBuilder-rebuild storms.
  // 运行面动画驱动,按需惰性创建:彗星沿活跃边([AnMotion.travel]/圈)、脉冲呼吸 running 环(breath)。都走
  // repaint/Listenable 直驱,绝不 AnimatedBuilder 重建风暴。
  AnimationController? _comet;
  AnimationController? _pulse;

  void _syncTickers({required bool wantComet, required bool wantPulse}) {
    if (wantComet) {
      (_comet ??= AnimationController(vsync: this, duration: AnMotion.travel))
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
    _dragScenePos.dispose();
    _tc.dispose();
    super.dispose();
  }

  GraphLayout get layout => _layout ??= layoutGraph(widget.graph, dir: widget.dir);

  @override
  void didUpdateWidget(AnGraphCanvas old) {
    super.didUpdateWidget(old);
    // A real graph/dir change relayouts. In the READ/RUN planes it also re-fits (the demo's
    // setGraph/setDir contract); in the EDIT plane it must NOT — every structural edit changes the
    // graph, and re-fitting would yank the viewport the user is actively panning/zooming. freezed 深
    // 比较:真换图/换向重布局;只读/运行面重 fit,编辑面绝不(每次结构编辑都改图,重 fit 会夺走用户
    // 正在平移/缩放的视口)。
    if (old.graph != widget.graph || old.dir != widget.dir) {
      _layout = null;
      if (!widget.editable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fit();
        });
      }
    }
  }

  // The controller matrix is only ever translate∘uniform-scale (no rotation — rotateEnabled off), so
  // entry(0,0) IS the scale. We ALSO scale the z axis in lockstep (visually inert — the scene is 2D,
  // z=0) precisely so IV's own `getMaxScaleOnAxis` (which it reads to clamp wheel/pinch to
  // [minScale,maxScale]) equals the true scale; leaving z=1 would make it misread any fit<1 as 1 and
  // cap zoom-in / sink zoom-out wrongly. entry(0,0) 即缩放;z 轴同步缩放(2D 场景 z=0、视觉无影响)是
  // 为了让 IV 自己的 getMaxScaleOnAxis==真实缩放、min/max 夹得对(z 留 1 会把 fit<1 误读为 1)。
  double get _scale => _tc.value.entry(0, 0);

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
    _tc.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(k, k, k, 1); // z scaled too → IV's getMaxScaleOnAxis reads the true scale
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
      ..scaleByDouble(r, r, r, 1) // z in lockstep (see _scale) so IV's zoom clamp stays correct
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
    _tc.value = t.multiplied(_tc.value);
  }

  void _zoomBy(double factor) =>
      _zoomAt(Offset(_viewport.width / 2, _viewport.height / 2), factor);

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
          // One viewport-level tap detector, ARENA-FREE: a raw Listener sees every pointer no matter
          // who wins the gesture arena — a GestureDetector.onTap here would lose, because IV's
          // DESCENDANT scale recognizer is added first and out-sweeps an ancestor tap on a no-move
          // press. A press that lifts within _tapSlop is a tap → route by scene hit-test (node select /
          // edge select / deselect); a longer travel is a drag/pan, left to IV or the node Listener. It
          // covers the WHOLE viewport, so even a tap in the empty margin deselects. 单一视口级点击探测
          // (绕竞技场):裸 Listener 无视谁赢竞技场都收得到指针——此处用 GestureDetector.onTap 会输,因
          // IV 后代 scale 识别器先入、无移动 tap 上横扫掉祖先 tap。按下在 _tapSlop 内抬起=点击 → 场景命中
          // 路由;位移更大=拖拽/平移,交给 IV 或节点 Listener。覆盖整视口(空白边距点击也取消选中)。
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: (e) {
            _tapDown = e.localPosition;
            _draggedThisPress = false;
          },
          onPointerUp: (e) {
            final down = _tapDown;
            final pressed = _pressedNodeId; // set by the card's Listener on the same pointer-down
            final dragged = _draggedThisPress;
            _tapDown = null;
            _pressedNodeId = null;
            _draggedThisPress = false;
            // A press that became a node/handle drag is NOT a tap — never toggle selection after a move.
            // 已成为拖拽的按下不是点击——移动后绝不再切换选中。
            if (dragged) return;
            if (down == null || (e.localPosition - down).distance > _tapSlop) return;
            if (pressed != null) {
              widget.onNodeTap?.call(pressed); // reliable node id from the widget hit, not toScene
            } else {
              _onViewportTap(e.localPosition); // edge / empty via scene hit-test
            }
          },
          onPointerCancel: (_) {
            _tapDown = null;
            _pressedNodeId = null;
            _draggedThisPress = false;
          },
          child: Stack(children: [
            // Dot grid stays screen-fixed (demo .stage::before is untransformed backdrop). 网格钉屏。
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _GridPainter(dot: gc.gridDot))),
            ),
          // The scene rides InteractiveViewer: it owns pan (single-pointer drag + trackpad two-finger),
          // pinch zoom, and mousewheel zoom-to-cursor. panEnabled drops while a node/handle drag is
          // live so the canvas holds still under the drag (the drag runs on a raw Listener, so IV's
          // uncontested scale recognizer merely no-ops). 场景骑在 IV 上:平移(单指拖 + 触控板双指)/
          // pinch / 滚轮到光标全归它;节点/柄拖拽时 panEnabled 落下,画布在拖拽下不动(拖拽走裸 Listener,
          // IV 无对手的 scale 识别器仅空转)。
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: _minScale,
                  maxScale: _maxScale,
                  scaleFactor: _wheelScaleFactor,
                  panEnabled: !_suppressPan,
                  child: _scene(context),
                ),
              ),
            ),
          ]),
        );
      }),
    );

    final withTools = Stack(children: [
      Positioned.fill(child: stage),
      if (widget.toolbar)
        Positioned.fill(
          child: Align(
            alignment: widget.toolbarAlignment,
            child: Padding(
              padding: const EdgeInsets.all(AnSpace.s12),
              child: _toolbar(context),
            ),
          ),
        ),
    ]);

    if (!widget.framed) return withTools;
    return Container(
      height: widget.framedHeight ?? AnSize.graphPreview,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: withTools,
    );
  }

  /// The transformed scene: background tap layer → edges underlay → comet overlay → port pills →
  /// node cards → connect handles. Sized to the layout so the unconstrained Stack children position
  /// against content coords. 变换场景:背景点击层 → 边底层 → 彗星层 → 端口药丸 → 节点卡 → 连接柄。
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
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _EdgePainter(
                  layout: l,
                  edge: gc.edge,
                  back: c.accent,
                  run: run,
                  taken: c.ink,
                  future: gc.edgeFuture,
                  selectedEdgeId: widget.selectedEdgeId,
                  selected: c.accent,
                ),
              ),
            ),
          ),
        ),
        // The rubber-band connection line while dragging from a handle. 连接拖拽中的橡皮筋线。
        if (_connectFrom != null && _connectScene != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConnectPainter(
                  from: l.nodeRects[_connectFrom!]?.center ?? Offset.zero,
                  to: _connectScene!,
                  color: c.accent,
                ),
              ),
            ),
          ),
        if (liveRoutes.isNotEmpty && !still)
          Positioned.fill(
            child: IgnorePointer(
              // Isolated layer: the comet repaints every animation tick for the WHOLE run — without
              // a boundary that invalidates the entire scene picture at 60fps. 独立层:彗星整个 run
              // 逐 tick 重绘,无边界会 60fps 重绘全场景。
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _CometPainter(routes: liveRoutes, color: c.accent, t: _comet!),
                ),
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
            // C-016: the card is the STABLE `child` — built ONCE per canvas build and reused across every
            // drag-move notification; a pointer-move only re-runs the cheap builder below (a Positioned
            // re-layout), never the card (nor its raw-Listener drag gesture — the VLB is here from build
            // #1, so no reparent). 卡=稳定 child(每 build 建一次、拖拽移动复用);移动只重跑下方轻量 Positioned,
            // 不重建卡、不断手势(VLB 从首 build 就在,无 reparent)。
            ValueListenableBuilder<Offset?>(
              valueListenable: _dragScenePos,
              child: _NodeCard(
                key: ValueKey('graphNode_${n.id}'),
                node: n,
                selected: n.id == widget.selectedNodeId,
                onTap: widget.onNodeTap == null ? null : () => widget.onNodeTap!(n.id),
                runState: run == null ? null : (run.nodes[n.id] ?? GraphNodeRun.future),
                iters: run?.iters[n.id] ?? 0,
                pulse: still ? null : _pulse,
                editable: widget.editable,
                // Record the pressed node id (no rebuild — read only by the tap detector) and, in edit
                // mode, drop IV's pan for the press. 记按下的节点 id(不重建,仅点击探测读)+ 编辑态落下 IV 平移。
                onPressStart: () {
                  _pressedNodeId = n.id;
                  if (widget.editable) setState(() => _suppressPan = true);
                },
                onPressEnd: () {
                  if (widget.editable && mounted) setState(() => _suppressPan = false);
                },
                onDragStart: () => _startNodeDrag(n.id, rect),
                onDragUpdate: _updateNodeDrag,
                onDragEnd: _endNodeDrag,
                onHoverChange: (h) => setState(() {
                  if (h) {
                    _hoverNodeId = n.id;
                  } else if (_hoverNodeId == n.id) {
                    _hoverNodeId = null;
                  }
                }),
              ),
              builder: (context, dragPos, child) {
                // The dragged node floats at its live scene position; every other node sits at its
                // committed rect. 拖拽中的节点浮在活场景位,其余在提交 rect。
                final p = (_dragId == n.id && dragPos != null) ? dragPos : rect.topLeft;
                return Positioned(
                    left: p.dx, top: p.dy, width: rect.width, height: rect.height, child: child!);
              },
            ),
        // Connect handles for the hovered node — scene-level overlays ON TOP of the cards, so a
        // handle drag is consumed here (the node below never starts a move). Inset within the card
        // so the node's hover region still covers them. 悬停节点的连接柄:场景级覆层、盖在卡上,拖柄
        // 在此独占(下方节点不移);内嵌卡内使节点 hover 区仍覆盖它们。
        if (widget.editable && _hoverNodeId != null && l.nodeRects[_hoverNodeId!] != null)
          for (final side in _Side.values)
            _handleOverlay(context, _hoverNodeId!, l.nodeRects[_hoverNodeId!]!, side),
      ]),
    ));
  }

  Widget _handleOverlay(BuildContext context, String nodeId, Rect rect, _Side side) {
    final c = context.colors;
    const inset = 3.0;
    final center = switch (side) {
      _Side.top => Offset(rect.left + rect.width / 2, rect.top + inset),
      _Side.bottom => Offset(rect.left + rect.width / 2, rect.bottom - inset),
      _Side.left => Offset(rect.left + inset, rect.top + rect.height / 2),
      _Side.right => Offset(rect.right - inset, rect.top + rect.height / 2),
    };
    return Positioned(
      left: center.dx - 11,
      top: center.dy - 11,
      width: 22,
      height: 22,
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        // Keep the node hovered while the pointer is on a handle (else moving off the card clears it).
        // 指针在柄上时保持节点 hover(否则离卡即清)。
        onEnter: (_) => setState(() => _hoverNodeId = nodeId),
        // A raw Listener (NOT a GestureDetector) drives the connect drag: it bypasses the gesture
        // arena, so the drag is never cancelled by IV's scale recognizer or a mid-drag rebuild. Its
        // localDelta is scene space (it's inside the transformed child), so no /scale. _suppressPan
        // drops IV's pan for the drag. 裸 Listener(非 GestureDetector)驱动连接拖:绕开竞技场,不被
        // IV scale 或拖拽中重建取消;localDelta 天然场景坐标(在变换子树内),不除 scale;_suppressPan
        // 拖拽期间落下 IV 平移。
        child: Listener(
          key: ValueKey('graphHandle_${nodeId}_${side.name}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            setState(() => _suppressPan = true);
            _startConnect(nodeId, rect, side);
          },
          onPointerMove: (ev) => _updateConnect(ev.localDelta),
          onPointerUp: (_) {
            _endConnect();
            if (mounted) setState(() => _suppressPan = false);
          },
          onPointerCancel: (_) {
            _cancelConnect();
            if (mounted) setState(() => _suppressPan = false);
          },
          child: Center(
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.accent, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── edit-mode gestures (W5) ──
  // Node drag: track the live scene top-left. The delta arrives already in scene space (the node
  // Listener is inside the transformed child), so it is added straight — no /scale. 节点拖:记活场景
  // 左上;delta 已是场景坐标(节点 Listener 在变换子树内),直接相加、不除缩放。
  void _startNodeDrag(String id, Rect rect) {
    _draggedThisPress = true; // this press is a drag, not a tap → suppress the follow-up selection tap
    _dragScenePos.value = rect.topLeft;
    // setState only to record WHICH node is dragged (the per-node builders read _dragId); one rebuild at
    // drag start, then moves are notifier-only. 仅 setState 记哪个在拖(逐节点 builder 读 _dragId),此后移动只走通知器。
    setState(() => _dragId = id);
  }

  void _updateNodeDrag(Offset sceneDelta) {
    final cur = _dragScenePos.value;
    if (cur == null) return;
    // NO setState: only the dragged node's Positioned must move. The per-node ValueListenableBuilders
    // listen to this notifier, so a pointer-move re-runs the cheap Positioned wrappers, NOT every card.
    // 无 setState:只动被拖节点位;逐节点 VLB 听此通知器,移动只重跑轻量 Positioned、不重建每张卡。
    _dragScenePos.value = cur + sceneDelta;
  }

  void _endNodeDrag() {
    final id = _dragId, scene = _dragScenePos.value;
    _dragScenePos.value = null;
    setState(() => _dragId = null);
    if (id != null && scene != null) {
      widget.onNodeMoved?.call(id, NodePosition(x: scene.dx.round(), y: scene.dy.round()));
    }
  }

  // Connect drag: rubber-band from the source node anchor to the pointer; drop over a node connects.
  // sceneDelta is already scene space. 连接拖:源锚 → 指针橡皮筋;松手落在节点上则连;sceneDelta 已是场景。
  void _startConnect(String id, Rect rect, _Side side) {
    _draggedThisPress = true; // a connect drag is not a tap either
    setState(() {
      _connectFrom = id;
      _connectScene = _anchorOf(rect, side);
    });
  }

  void _updateConnect(Offset sceneDelta) {
    if (_connectScene == null) return;
    setState(() => _connectScene = _connectScene! + sceneDelta);
  }

  void _endConnect() {
    final from = _connectFrom, scene = _connectScene;
    setState(() {
      _connectFrom = null;
      _connectScene = null;
    });
    if (from == null || scene == null) return;
    final target = _nodeAt(scene);
    if (target != null && target != from) widget.onConnect?.call(from, target);
  }

  void _cancelConnect() {
    if (_connectFrom == null) return;
    setState(() {
      _connectFrom = null;
      _connectScene = null;
    });
  }

  Offset _anchorOf(Rect r, _Side side) => switch (side) {
        _Side.top => Offset(r.left + r.width / 2, r.top),
        _Side.bottom => Offset(r.left + r.width / 2, r.bottom),
        _Side.left => Offset(r.left, r.top + r.height / 2),
        _Side.right => Offset(r.right, r.top + r.height / 2),
      };

  /// The node whose rect contains [scene] (topmost). 含该场景点的节点。
  String? _nodeAt(Offset scene) {
    for (final n in layout.graph.nodes.reversed) {
      if (layout.nodeRects[n.id]?.contains(scene) ?? false) return n.id;
    }
    return null;
  }

  // A viewport tap, routed by scene hit-test: a node → select; else an edge (edit mode) → select;
  // else deselect. The point is viewport space (from the stage GestureDetector, which fills the
  // viewport as IV does) → toScene puts it in the child's coords. 视口点击,场景命中路由:节点→选/边→选
  // (编辑)/空白取消;入参是视口坐标(stage GestureDetector 与 IV 同占满视口)→ toScene 转子坐标。
  void _onViewportTap(Offset viewportPoint) {
    final scene = _tc.toScene(viewportPoint);
    // Node hits come from the widget-level press tracking (_pressedNodeId), never this scene math —
    // toScene reads the live controller matrix, which can trail the painted layout by a frame right
    // after a fit. Here only edges (painted, no widget to hit) and empty space are resolved.
    // 节点命中走 widget 级按下追踪(_pressedNodeId),不用这里的坐标反算——toScene 读活控制器矩阵,fit
    // 后可能落后绘制一帧;此处只判边(纯绘制、无 widget 可命中)与空白。
    if (widget.editable && widget.onEdgeTap != null) {
      final edgeId = _edgeAt(scene);
      if (edgeId != null) {
        widget.onEdgeTap!(edgeId);
        return;
      }
    }
    widget.onNodeTap?.call(null);
  }

  /// The nearest edge to [scene] within a scene-space threshold (segment distance over the route
  /// polyline). 场景点阈值内最近的边(沿折线段距)。
  String? _edgeAt(Offset scene) {
    const threshold = 12.0;
    String? best;
    var bestD = threshold;
    for (final r in layout.routes) {
      final pts = r.points;
      for (var i = 1; i < pts.length; i++) {
        final d = _segDist(scene, pts[i - 1], pts[i]);
        if (d < bestD) {
          bestD = d;
          best = r.edge.id;
        }
      }
    }
    return best;
  }

  static double _segDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// Floating zoom group — the canvas owns its zoom affordances (demo: 外设随画布走,消费点不重拼)。
  Widget _toolbar(BuildContext context) {
    final t = context.t;
    return AnFloatingBar(children: [
      AnButton.iconOnly(AnIcons.zoomOut,
          size: AnButtonSize.sm, onPressed: () => _zoomBy(1 / 1.2), semanticLabel: t.a11y.graphZoomOut),
      AnButton.iconOnly(AnIcons.zoomIn,
          size: AnButtonSize.sm, onPressed: () => _zoomBy(1.2), semanticLabel: t.a11y.graphZoomIn),
      AnButton.iconOnly(AnIcons.expand,
          size: AnButtonSize.sm, onPressed: _fit, semanticLabel: t.a11y.graphFit),
      if (widget.onEnterEditor != null && (widget.enterEditorLabel ?? '').isNotEmpty) ...[
        const AnDivider.vertical(),
        AnButton(
          label: widget.enterEditorLabel,
          icon: AnIcons.workflow,
          size: AnButtonSize.sm,
          onPressed: widget.onEnterEditor,
        ),
      ],
    ]);
  }
}

/// One node card: kind chip (soft family colour + icon) + id / ref double line, plus the run
/// overlay (state ring + status dot + breathing while running + ×N iteration stack + dashed future).
/// Real widget so text, tooltips and semantics come free. 节点卡:kind 色 chip + id/ref 双行 +
/// 运行覆层(状态环/状态点/running 呼吸/×N 叠卡/future 虚线),真 widget。
/// Which face a connection handle sits on. 连接柄所在面。
enum _Side { top, bottom, left, right }

class _NodeCard extends StatefulWidget {
  const _NodeCard({
    required this.node,
    required this.selected,
    required this.onTap,
    this.runState,
    this.iters = 0,
    this.pulse,
    this.editable = false,
    this.onPressStart,
    this.onPressEnd,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onHoverChange,
    super.key,
  });

  final Node node;
  final bool selected;
  final VoidCallback? onTap;

  /// Null = definition view (no run overlay). 运行态;null=纯定义视图。
  final GraphNodeRun? runState;
  final int iters;

  /// The shared breath driver (null under reduced motion → a static ring instead). 共享呼吸驱动。
  final Animation<double>? pulse;

  /// Edit mode: whole-card drag (move) + hover reporting (the canvas draws connect handles). The
  /// drag runs on a raw Listener with slop-based tap/drag disambiguation so it never fights IV's
  /// arena; [onPressStart]/[onPressEnd] bracket the whole pointer press (canvas drops IV pan for its
  /// span), [onDragUpdate] carries a SCENE-space delta. 编辑态:整卡拖移 + 悬停上报;拖拽走裸 Listener +
  /// slop 判 tap/drag、不打竞技场;press 起止括住整次按下(画布落下 IV 平移),onDragUpdate 是场景坐标 delta。
  final bool editable;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final VoidCallback? onDragStart;
  final ValueChanged<Offset>? onDragUpdate; // scene-space delta 场景坐标 delta
  final VoidCallback? onDragEnd;
  final ValueChanged<bool>? onHoverChange;

  @override
  State<_NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<_NodeCard> {
  // Beyond this scene-space travel a press becomes a drag (below it, a release is a tap → select).
  // 超过此场景位移即判为拖拽(不足则松手=点选)。
  static const double _dragSlop = 3.0;
  Offset? _downPos;
  bool _moved = false;

  Node get node => widget.node;
  bool get selected => widget.selected;
  VoidCallback? get onTap => widget.onTap;
  GraphNodeRun? get runState => widget.runState;
  int get iters => widget.iters;
  Animation<double>? get pulse => widget.pulse;

  @override
  Widget build(BuildContext context) {
    GraphCanvasProbe.onNodeCardBuild?.call(); // C-016: count card builds (drag-isolation proof) 数卡 build
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

    final overlay = Stack(clipBehavior: Clip.none, children: [
      // Iteration ghosts stack UNDER the card (demo's ×N 叠卡:offset shadows read as "this slot ran
      // multiple times"). 迭代影子叠在卡下(×N 叠卡)。
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
    ]);

    final body = MouseRegion(
      onEnter: widget.editable ? (_) => widget.onHoverChange?.call(true) : null,
      onExit: widget.editable ? (_) => widget.onHoverChange?.call(false) : null,
      cursor: widget.editable
          ? SystemMouseCursors.move
          : (onTap != null ? SystemMouseCursors.click : MouseCursor.defer),
      child: overlay,
    );

    return Semantics(
      label: t.a11y.graphNode(id: node.id, kind: _kindLabel(t, node.kind), ref: node.ref),
      button: onTap != null,
      // Assistive-tech activation only — sighted taps route through the canvas's viewport hit-test so
      // tap/edge/deselect share one path. 仅辅助技术激活——肉眼点击走画布视口命中(点/边/取消一条路)。
      onTap: onTap,
      // Edit mode: a raw Listener owns the press for DRAG (slop separates a real move from a tap) and
      // drops IV's pan for its span; a clean tap does nothing here — the stage hit-test selects the
      // node. Read mode: no gesture — taps and drags both fall to the stage / IV. 编辑态:裸 Listener
      // 掌管拖拽(slop 分真移动/点选)并落下 IV 平移;净点在此不动、由 stage 命中选中;只读态无手势。
      // A raw Listener owns the press in BOTH modes: onPressStart lets the canvas record this node as
      // the tap target (frame-sync-proof selection) and, in edit mode, drop IV's pan; edit-mode moves
      // (slop-gated, scene-space localDelta) run here too. A clean tap does nothing here — the canvas's
      // tap detector selects this node from the recorded id. 裸 Listener 两态都掌管按下:onPressStart 让
      // 画布记下本节点为点击目标(无帧同步问题的选中)+ 编辑态落下 IV 平移;编辑态拖移(slop 门控、场景坐标
      // localDelta)也在此。净点在此不动,画布点击探测据所记 id 选中本节点。
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _downPos = e.localPosition;
          _moved = false;
          widget.onPressStart?.call();
        },
        onPointerMove: widget.editable
            ? (e) {
                final start = _downPos;
                if (start == null) return;
                if (!_moved) {
                  if ((e.localPosition - start).distance <= _dragSlop) return;
                  _moved = true;
                  widget.onDragStart?.call();
                }
                widget.onDragUpdate?.call(e.localDelta);
              }
            : null,
        onPointerUp: (_) {
          if (_moved) widget.onDragEnd?.call();
          _downPos = null;
          _moved = false;
          widget.onPressEnd?.call();
        },
        onPointerCancel: (_) {
          if (_moved) widget.onDragEnd?.call();
          _downPos = null;
          _moved = false;
          widget.onPressEnd?.call();
        },
        child: body,
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
    this.selectedEdgeId,
    required this.selected,
  });

  final GraphLayout layout;
  final Color edge; // resting edge + arrow 静止边
  final Color back; // back edge / live (accent) 回边·活跃
  final GraphRunState? run;
  final Color taken; // walked edge (ink) 已走边
  final Color future; // not-yet-walked edge 未走边
  final String? selectedEdgeId; // edit-mode selection 编辑态选中边
  final Color selected;

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
      if (r.edge.id == selectedEdgeId) {
        color = selected;
        w = _liveW;
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
      old.future != future ||
      old.selectedEdgeId != selectedEdgeId ||
      old.selected != selected;
}

/// The rubber-band line while dragging a new connection (source anchor → pointer). 连接拖拽橡皮筋。
class _ConnectPainter extends CustomPainter {
  const _ConnectPainter({required this.from, required this.to, required this.color});

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // A dashed straight line + endpoint dot (matches the demo's connect preview). 虚直线 + 端点。
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy);
    canvas.drawPath(_EdgePainter._dash(path, on: 4, off: 4), paint);
    canvas.drawCircle(to, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ConnectPainter old) => old.from != from || old.to != to || old.color != color;
}

/// The comet overlay — one dot lapping each live edge, driven by the controller via `repaint` (the
/// painter repaints per tick; the widget tree never rebuilds). 彗星覆层:每条活跃边一点循环,
/// controller 经 repaint 直驱(逐 tick 重绘、树零重建)。
class _CometPainter extends CustomPainter {
  // The route Paths + their PathMetrics are computed ONCE here (per build, when the routes change), not
  // per animation tick (C-015): `repaint: t` drives paint() at 60fps on this SAME instance, but only the
  // comet's OFFSET along each metric changes — the rounded polyline + the native PathMetrics object don't.
  // 路由 Path+PathMetrics 构造时算一次(routes 变才重建),非每 tick;60fps 只 comet 沿线偏移变、折线/metric 不变。
  _CometPainter({required this.routes, required this.color, required this.t})
      : _metrics = _buildMetrics(routes),
        super(repaint: t);

  final List<GraphEdgeRoute> routes;
  final Color color;
  final Animation<double> t;
  final List<PathMetric> _metrics;

  static const double _r = 3.6;

  static List<PathMetric> _buildMetrics(List<GraphEdgeRoute> routes) => [
        for (final r in routes) ..._EdgePainter._rounded(r.points, GraphGeometry.corner).computeMetrics(),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final m in _metrics) {
      final tangent = m.getTangentForOffset(m.length * t.value);
      if (tangent != null) canvas.drawCircle(tangent.position, _r, paint);
    }
  }

  @override
  bool shouldRepaint(_CometPainter old) =>
      !identical(old.routes, routes) || old.color != color || old.t != t;
}

/// Hairline dashed rounded border — the future (not-yet-walked) node card frame. 虚线圆角边框(future 节点卡)。
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
    // ONE batched drawPoints instead of a drawCircle per grid cell (C-032): O(viewport area) individual
    // draw calls became O(1) draw calls (the raster batches the point list). A round point of diameter
    // 2×hairline is visually identical to a hairline-radius filled circle for this background grid.
    // 一次批量 drawPoints 替逐格 drawCircle:栅格点极小,round 点(直径 2×hairline)与 hairline 半径圆视觉一致。
    final paint = Paint()
      ..color = dot
      ..strokeWidth = AnSize.hairline * 2
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    for (var x = _spacing / 2; x < size.width; x += _spacing) {
      for (var y = _spacing / 2; y < size.height; y += _spacing) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.dot != dot;
}
