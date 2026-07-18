import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../contract/entities/relation.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../graph/force_layout.dart';
import 'an_a11y.dart';
import 'an_button.dart';
import 'an_floating_bar.dart';
import 'entity_kind_visual.dart';
import 'icons.dart';

/// The entity-relationship graph primitive — a force-directed node-link view of the workspace topology,
/// for the Entities Overview (observing state = a [framed] preview inside the 720 column) and the
/// full-page explore state. Same HYBRID architecture the design system mandates (§2, WRK-069 S5) and
/// [AnGraphCanvas] already proves: identity-bearing NODES are real widgets (colour dot + label + focus +
/// semantics — a painter's nodes can't be Tab-traversed on desktop), inert FURNITURE (edges + dot grid) is
/// a cached [CustomPaint] underlay, and the viewport rides a plain [InteractiveViewer] (pan / wheel-zoom /
/// pinch). Layout comes from the framework-free [ForceLayout] engine; this widget only DRIVES it (a Ticker
/// during the drag squeeze, stopped at rest → zero repaint) and RENDERS it.
///
/// Selection is CONTROLLED ([selectedId] + [onNodeTap]) — the page derives it from the URL, the graph
/// never owns it. Semantic sentences are caller callbacks ([nodeSemanticLabel] / [edgeSemanticLabel] /
/// [semanticSummary]) exactly as [AnRunMatrix] takes its label callbacks (the primitive stays i18n-light;
/// only the shared zoom chrome reads `t.a11y.graph*`).
///
/// 实体关系图原语——力导向节点连线,呈现 workspace 拓扑,供 Entities 总览(观赏态=720 列内 framed 预览)与全页
/// 探索态。混合架构(设计系统 §2 立法、AnGraphCanvas 已证):带身份的节点=真 widget(色点+标签+焦点+语义,
/// 画布节点桌面上无法 Tab 遍历),惰性家具(边+点阵)=缓存 CustomPaint 底层,视口骑原生 InteractiveViewer。布局来自
/// 框架无关的 ForceLayout;本 widget 只驱动它(拖拽挤压期一个 Ticker、静止即停→零重绘)+ 渲染。选中受控,语义句走
/// 调用方回调(照 AnRunMatrix)。
///
/// A test hook fired each time a node widget BUILDS — the stop-frame test asserts a settled graph rebuilds
/// nothing. 测试钩子:每个节点 build 触发——停帧测试据此断言 settled 图零重建。
abstract final class RelationGraphProbe {
  @visibleForTesting
  static void Function()? onNodeBuild;

  /// Fired each simulation frame (one per Ticker tick). The stop-frame test counts these to prove the
  /// sim stops at rest. 每仿真帧触发,停帧测试据此证明静止即停。
  @visibleForTesting
  static void Function()? onSimFrame;
}

class AnRelationGraph extends StatefulWidget {
  const AnRelationGraph({
    required this.nodes,
    required this.edges,
    this.selectedId,
    this.revealId,
    this.revealToken = 0,
    this.onNodeTap,
    this.hiddenKinds = const {},
    this.framed = false,
    this.framedHeight,
    this.toolbar = false,
    this.onExpand,
    this.expandLabel,
    this.nodeSemanticLabel,
    this.edgeSemanticLabel,
    this.semanticSummary,
    super.key,
  });

  /// The active node set for the current mode (observing = structural-node subset; explore = all, or all
  /// + provenance). The primitive lays out + renders whatever it is given. 当前模式的活节点集。
  final List<EntityNode> nodes;

  /// The active edge set (already filtered to structural verbs / provenance by the caller). 活边集。
  final List<EntityRelation> edges;

  /// Controlled selection — accent-ring the node with this id (an entity id, unique across kinds). 受控选中。
  final String? selectedId;

  /// Fly-to target — when [revealToken] changes, the viewport pans to CENTER this node (the explore
  /// state's relation-group "逐行可点=图内 fly-to"). Distinct from [selectedId] so selecting a node the
  /// user already clicked doesn't yank the viewport; only an explicit reveal pans. 飞到目标:revealToken 变时
  /// 视口平移居中该节点(探索态关系分组点行 fly-to);与 selectedId 分开,避免选中已点节点也夺视口。
  final String? revealId;
  final int revealToken;

  /// Node tap → id (a background tap reports null → deselect). 点节点→id(点空白→null 取消)。
  final ValueChanged<String?>? onNodeTap;

  /// Kinds hidden by the explore legend — a RENDER-ONLY filter (the layout keeps them so positions stay
  /// stable when a kind is toggled back on). 图例隐藏的 kind:仅渲染过滤(布局保留、切回时位置稳定)。
  final Set<String> hiddenKinds;

  /// Observing flavour: a fixed-height hairline card that pans/zooms in its own box (no page width ask).
  /// 观赏形态:定高 hairline 卡,框内平移缩放。
  final bool framed;
  final double? framedHeight;

  /// Explore flavour: show the floating zoom toolbar. 探索形态:显示悬浮缩放条。
  final bool toolbar;

  /// Observing: hovering the box floats a corner "展开 ↗" that enters explore with no selection. 观赏:悬停浮出「展开」。
  final VoidCallback? onExpand;
  final String? expandLabel;

  /// Per-node a11y sentence (coordinates baked in — desktop a11y §2). `(node, inDegree) → String`. 节点语义句。
  final String Function(EntityNode node, int inDegree)? nodeSemanticLabel;

  /// Per-edge relation sentence — the hover tooltip + a11y. `(edge) → String`. 边关系句(hover tooltip + a11y)。
  final String Function(EntityRelation edge)? edgeSemanticLabel;

  /// The container semantic summary (WRK-069 §2 — the whole-graph sentence a screen reader reads). 容器摘要句。
  final String? semanticSummary;

  @override
  State<AnRelationGraph> createState() => _AnRelationGraphState();
}

class _AnRelationGraphState extends State<AnRelationGraph> with SingleTickerProviderStateMixin {
  static const double _minScale = 0.25;
  static const double _maxScale = 2.5;
  static const double _fitMaxScale = 1.45; // small graphs may fill the box rather than float tiny in it
  static const double _fitMinScale = 0.3;
  static const double _wheelScaleFactor = 666.6667;
  static const double _tapSlop = 5.0;
  static const double _dragSlop = 3.0;
  static const double _labelScaleThreshold = 0.5; // below this zoom, drop labels → dots only
  static const double _minRadius = 5.5;
  static const double _maxRadius = 15.0;
  static const int _degreeCap = 6; // in-degree at which the radius saturates
  static const double _sceneMargin = 84; // scene padding around the node cloud (fit headroom, not empty bulk)
  static const double _edgeHoverThreshold = 10; // scene px

  final TransformationController _tc = TransformationController();
  late ForceLayout _sim;
  String _signature = '';

  // Positions are centered near origin; [_origin] translates to positive scene space and [_contentSize]
  // sizes the unconstrained child. Recomputed only on a full re-settle (init / data change), NOT per
  // frame, so the scene never jitters. 位置以原点为中心;_origin 平移到正场景坐标,_contentSize 定尺寸;仅整体
  // 重 settle 时重算、非逐帧,故场景不抖。
  Offset _origin = Offset.zero;
  Size _contentSize = const Size(600, 400);

  Size _viewport = Size.zero;
  bool _fitted = false;
  bool _labelsHidden = false;

  // The sim-frame pulse: bumped each Ticker tick → drives node Positioned re-layout + the edge painter's
  // repaint, WITHOUT rebuilding node widgets (C-016 isolation). 仿真脉冲:逐 tick 自增→驱节点重定位 + 边重绘,
  // 不重建节点 widget。
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;

  // Interaction state (hover / drag / roving cursor) — setState-guarded so a mouse-move that stays on the
  // same node/edge is a no-op. 交互态:hover/拖拽/roving 光标,变了才 setState。
  String? _hoverNodeId;
  String? _hoverEdgeId;
  Set<String> _oneHop = const {};
  bool _boxHover = false;

  String? _dragId;
  Offset _dragSceneCenter = Offset.zero;
  bool _draggedThisPress = false;
  Offset? _tapDownViewport;
  String? _pressedNodeId;

  // Roving a11y — one FocusNode per node id, exactly one (the cursor) answers Tab (see AnRunMatrix).
  // roving:每 node 一个 FocusNode,恰一个(光标)应 Tab。
  final Map<String, FocusNode> _focusNodes = {};
  String? _cursorId;

  bool get _reduced => AnMotionPref.reducedOrAssistive(context);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _rebuildSim();
  }

  @override
  void didUpdateWidget(AnRelationGraph old) {
    super.didUpdateWidget(old);
    final sig = _sigOf(widget.nodes, widget.edges);
    if (sig != _signature) {
      _rebuildSim();
      if (!widget.framed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fit();
        });
      }
    }
    // A fly-to request (revealToken bump) pans the viewport to centre the target. 飞到请求:平移居中目标。
    if (old.revealToken != widget.revealToken && widget.revealId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerOn(widget.revealId!);
      });
    }
  }

  void _centerOn(String id) {
    if (_viewport == Size.zero || !_sim.positions.containsKey(id)) return;
    final p = _sceneOf(id);
    final k = _scale;
    _tc.value = Matrix4.identity()
      ..translateByDouble(_viewport.width / 2 - p.dx * k, _viewport.height / 2 - p.dy * k, 0, 1)
      ..scaleByDouble(k, k, k, 1);
    _syncLabels();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _tc.dispose();
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  // A cheap structural key: node ids + edge endpoints (sorted). A rename (name-only change) does NOT
  // re-layout. 廉价结构键:node id + 边端点(排序);改名不触发重布局。
  String _sigOf(List<EntityNode> nodes, List<EntityRelation> edges) {
    final ns = [for (final n in nodes) n.id]..sort();
    final es = [for (final e in edges) '${e.fromId}>${e.toId}']..sort();
    return '${ns.join(',')}|${es.join(',')}';
  }

  void _rebuildSim() {
    _signature = _sigOf(widget.nodes, widget.edges);
    _sim = ForceLayout(
      nodes: [for (final n in widget.nodes) ForceNode(n.id)],
      edges: [for (final e in widget.edges) ForceEdge(e.fromId, e.toId)],
    );
    _sim.settle(); // static first paint (deterministic, zero-repaint at rest); drag animates later
    _recomputeBounds();
    // Prune focus nodes for departed ids. 剪掉已离场 id 的焦点节点。
    final live = {for (final n in widget.nodes) n.id};
    _focusNodes.removeWhere((k, v) {
      if (live.contains(k)) return false;
      v.dispose();
      return true;
    });
    if (_cursorId == null || !live.contains(_cursorId)) {
      _cursorId = _defaultCursor();
    }
    _fitted = false;
  }

  // Default keyboard cursor = the most-referenced node (the natural centre), else the first by id. 默认光标=入度最高。
  String? _defaultCursor() {
    if (widget.nodes.isEmpty) return null;
    final deg = _inDeg;
    final ids = [for (final n in widget.nodes) n.id]..sort();
    ids.sort((a, b) => (deg[b] ?? 0).compareTo(deg[a] ?? 0));
    return ids.first;
  }

  Map<String, int> get _inDeg => inDegrees([for (final e in widget.edges) (from: e.fromId, to: e.toId)]);

  void _recomputeBounds() {
    final pos = _sim.positions;
    if (pos.isEmpty) {
      _origin = Offset(_contentSize.width / 2, _contentSize.height / 2);
      return;
    }
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pos.values) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    _origin = Offset(_sceneMargin - minX, _sceneMargin - minY);
    _contentSize = Size(maxX - minX + _sceneMargin * 2, maxY - minY + _sceneMargin * 2);
  }

  Offset _sceneOf(String id) => _sim.positionOf(id) + _origin;

  double _radiusOf(String id) {
    final d = (_inDeg[id] ?? 0).clamp(0, _degreeCap) / _degreeCap;
    return _minRadius + (_maxRadius - _minRadius) * d;
  }

  double get _scale => _tc.value.entry(0, 0);

  // ── ticker / physics ────────────────────────────────────────────────────
  void _onTick(Duration _) {
    RelationGraphProbe.onSimFrame?.call();
    final moved = _sim.tick();
    _frame.value++;
    if (!moved) _ticker.stop(); // static-when-settled: stop → zero repaint (next drag restarts)
  }

  void _wake() {
    if (_reduced) {
      _sim.settle(maxIterations: 90);
      _frame.value++;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  // ── fit / zoom ──────────────────────────────────────────────────────────
  void _fit() {
    if (_viewport == Size.zero) return;
    var k = math.min(
      (_viewport.width - _sceneMargin) / _contentSize.width,
      (_viewport.height - _sceneMargin) / _contentSize.height,
    );
    k = k.isFinite && k > 0 ? math.min(k, _fitMaxScale) : 1;
    k = math.max(_fitMinScale, k);
    final x = (_viewport.width - _contentSize.width * k) / 2;
    final y = (_viewport.height - _contentSize.height * k) / 2;
    _tc.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(k, k, k, 1);
    _syncLabels();
  }

  void _zoomAt(Offset anchor, double factor) {
    final k = _scale;
    final nk = (k * factor).clamp(_minScale, _maxScale);
    final r = nk / k;
    if (r == 1) return;
    _tc.value = (Matrix4.identity()
          ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
          ..scaleByDouble(r, r, r, 1)
          ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1))
        .multiplied(_tc.value);
    _syncLabels();
  }

  void _zoomBy(double f) => _zoomAt(Offset(_viewport.width / 2, _viewport.height / 2), f);

  // Labels drop below a zoom threshold — only on the CROSSING (guarded) so a continuous wheel doesn't
  // rebuild every frame. 缩放阈下藏标签,仅越界时(带门)rebuild、连续滚轮不逐帧重建。
  void _syncLabels() {
    final hide = _scale < _labelScaleThreshold;
    if (hide != _labelsHidden) setState(() => _labelsHidden = hide);
  }

  // ── hover ─────────────────────────────────────────────────────────────────
  void _setHoverNode(String? id) {
    if (_hoverNodeId == id) return;
    setState(() {
      _hoverNodeId = id;
      if (id == null) {
        _oneHop = const {};
      } else {
        final s = <String>{id};
        for (final e in widget.edges) {
          if (e.fromId == id) s.add(e.toId);
          if (e.toId == id) s.add(e.fromId);
        }
        _oneHop = s;
      }
    });
  }

  void _onSceneHover(Offset scene) {
    if (_hoverNodeId != null) {
      if (_hoverEdgeId != null) setState(() => _hoverEdgeId = null);
      return;
    }
    final id = _edgeAt(scene);
    if (id != _hoverEdgeId) setState(() => _hoverEdgeId = id);
  }

  String? _edgeAt(Offset scene) {
    String? best;
    var bestD = _edgeHoverThreshold;
    for (final e in widget.edges) {
      if (_hidden(e.fromKind) || _hidden(e.toKind)) continue;
      final a = _sceneOf(e.fromId), b = _sceneOf(e.toId);
      final d = _segDist(scene, a, b);
      if (d < bestD) {
        bestD = d;
        best = e.id;
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

  bool _hidden(String kind) => widget.hiddenKinds.contains(kind.toLowerCase());

  // ── drag (raw Listener, arena-free; scene-space delta) ─────────────────────
  void _startDrag(String id) {
    _draggedThisPress = true;
    _dragId = id;
    _dragSceneCenter = _sceneOf(id);
    setState(() {});
  }

  void _updateDrag(Offset sceneDelta) {
    final id = _dragId;
    if (id == null) return;
    _dragSceneCenter += sceneDelta;
    _sim.pin(id, _dragSceneCenter - _origin);
    _wake();
  }

  void _endDrag() {
    final id = _dragId;
    _dragId = null;
    if (id != null) {
      _sim.unpin(id);
      _wake();
    }
    setState(() {});
  }

  // ── keyboard roving ─────────────────────────────────────────────────────
  FocusNode _focusFor(String id, {required bool cursor}) {
    final n = _focusNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'AnRelationGraph $id'));
    n.skipTraversal = !cursor;
    return n;
  }

  List<String> get _visibleIds =>
      [for (final n in widget.nodes) if (!_hidden(n.kind)) n.id];

  // Directional nearest-neighbour: from the cursor, pick the visible node best matching [dir] — inside a
  // 90° cone, scored by along-axis distance + a perpendicular penalty. Off the cone → false (traversal
  // escapes). 方向最近邻:光标出发,90° 锥内按轴向距 + 垂直惩罚选最优;锥外返 false 让遍历逃出。
  bool _move(TraversalDirection dir) {
    final from = _cursorId;
    if (from == null) return false;
    final origin = _sceneOf(from);
    final (ax, ay) = switch (dir) {
      TraversalDirection.up => (0.0, -1.0),
      TraversalDirection.down => (0.0, 1.0),
      TraversalDirection.left => (-1.0, 0.0),
      TraversalDirection.right => (1.0, 0.0),
    };
    String? best;
    var bestScore = double.infinity;
    for (final id in _visibleIds) {
      if (id == from) continue;
      final v = _sceneOf(id) - origin;
      final along = v.dx * ax + v.dy * ay;
      if (along <= 1) continue; // wrong side / same
      final perp = (v.dx * -ay + v.dy * ax).abs();
      if (perp > along) continue; // outside the 90° cone
      final score = along + perp * 2;
      if (score < bestScore) {
        bestScore = score;
        best = id;
      }
    }
    if (best == null) return false;
    setState(() => _cursorId = best);
    final node = _focusFor(best, cursor: true);
    node.requestFocus();
    final n = widget.nodes.firstWhere((e) => e.id == best);
    AnA11y.announceFocusMove(context, _nodeSentence(n));
    return true;
  }

  String _nodeSentence(EntityNode n) =>
      widget.nodeSemanticLabel?.call(n, _inDeg[n.id] ?? 0) ?? n.name;

  void _activate(String id) {
    setState(() => _cursorId = id);
    widget.onNodeTap?.call(id);
  }

  // ── build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gc = context.graphColors;

    final stage = ClipRect(
      child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        if (size != _viewport) {
          _viewport = size;
          if ((!_fitted || widget.framed) && size.width > 0 && size.height > 0) {
            _fitted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fit();
            });
          }
        }
        return Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: (e) {
            _tapDownViewport = e.localPosition;
            _draggedThisPress = false;
          },
          onPointerUp: (e) {
            final down = _tapDownViewport;
            final pressed = _pressedNodeId;
            final dragged = _draggedThisPress;
            _tapDownViewport = null;
            _pressedNodeId = null;
            if (dragged) return;
            if (down == null || (e.localPosition - down).distance > _tapSlop) return;
            if (pressed != null) {
              _activate(pressed);
            } else {
              widget.onNodeTap?.call(null); // background tap → deselect
            }
          },
          child: MouseRegion(
            onExit: (_) {
              _setHoverNode(null);
              if (_hoverEdgeId != null) setState(() => _hoverEdgeId = null);
            },
            child: Stack(children: [
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _GridPainter(dot: gc.gridDot))),
              ),
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
                    panEnabled: _dragId == null,
                    onInteractionUpdate: (_) => _syncLabels(),
                    child: _scene(context, c, gc),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );

    Widget content = Actions(
      actions: <Type, Action<Intent>>{
        DirectionalFocusIntent: _RelationDirectionalFocusAction(this),
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.semanticSummary ?? '',
        child: Stack(children: [
          Positioned.fill(child: stage),
          if (widget.toolbar)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(AnSpace.s12),
                  child: _toolbar(context),
                ),
              ),
            ),
          if (widget.onExpand != null && _boxHover)
            Positioned(
              top: AnSpace.s8,
              right: AnSpace.s8,
              child: AnButton(
                label: widget.expandLabel,
                icon: AnIcons.expand,
                size: AnButtonSize.sm,
                onPressed: widget.onExpand,
              ),
            ),
        ]),
      ),
    );

    if (widget.onExpand != null) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _boxHover = true),
        onExit: (_) => setState(() => _boxHover = false),
        child: content,
      );
    }

    if (!widget.framed) return content;
    return Container(
      height: widget.framedHeight ?? AnSize.graphPreview,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: content,
    );
  }

  Widget _scene(BuildContext context, AnColors c, GraphColors gc) {
    // Canvas text is geometry-locked; a11y font scaling would overflow — magnification is the zoom's job.
    // 画布文本几何锁定,辅助字号放大会溢出——放大归缩放。
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: _contentSize.width,
        height: _contentSize.height,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) => _onSceneHover(e.localPosition),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _EdgePainter(
                      state: this,
                      edge: gc.edge,
                      ink: c.ink,
                      accent: c.accent,
                      repaint: _frame,
                    ),
                  ),
                ),
              ),
            ),
            for (final n in widget.nodes)
              if (!_hidden(n.kind))
                ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  child: _RelationNode(
                    key: ValueKey('relNode_${n.id}'),
                    node: n,
                    radius: _radiusOf(n.id),
                    color: entityKindColor(context, n.kind),
                    selected: n.id == widget.selectedId,
                    dim: _hoverNodeId != null && !_oneHop.contains(n.id),
                    hovered: _hoverNodeId == n.id,
                    labelHidden: _labelsHidden,
                    focusNode: _focusFor(n.id, cursor: n.id == _cursorId),
                    semanticLabel: _nodeSentence(n),
                    onActivate: () => _activate(n.id),
                    onHover: (h) => _setHoverNode(h ? n.id : null),
                    onPressStart: () => _pressedNodeId = n.id,
                    onDragStart: () => _startDrag(n.id),
                    onDragUpdate: _updateDrag,
                    onDragEnd: _endDrag,
                    dragSlop: _dragSlop,
                  ),
                  builder: (context, _, child) {
                    final p = _sceneOf(n.id);
                    final r = _radiusOf(n.id);
                    // Fixed-width slot centered on the node position; the dot sits at top-center, label
                    // below. 定宽槽居中于节点位:点在顶部居中,标签在下。
                    return Positioned(
                      left: p.dx - _slotW / 2,
                      top: p.dy - r,
                      width: _slotW,
                      child: child!,
                    );
                  },
                ),
            if (_hoverEdgeId != null) _edgeTooltip(context, c),
          ]),
        ),
      ),
    );
  }

  static const double _slotW = 132;

  Widget _edgeTooltip(BuildContext context, AnColors c) {
    final edge = widget.edges.where((e) => e.id == _hoverEdgeId).firstOrNull;
    if (edge == null || widget.edgeSemanticLabel == null) return const SizedBox.shrink();
    final mid = (_sceneOf(edge.fromId) + _sceneOf(edge.toId)) / 2;
    return Positioned(
      left: mid.dx,
      top: mid.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1.2),
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AnRadius.button),
              border: Border.all(color: c.line, width: AnSize.hairline),
              boxShadow: c.shadowPop,
            ),
            child: Text(
              widget.edgeSemanticLabel!(edge),
              style: AnText.meta.copyWith(color: c.inkMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final t = context.t;
    return AnFloatingBar(children: [
      AnButton.iconOnly(AnIcons.zoomOut,
          size: AnButtonSize.sm, onPressed: () => _zoomBy(1 / 1.2), semanticLabel: t.a11y.graphZoomOut),
      AnButton.iconOnly(AnIcons.zoomIn,
          size: AnButtonSize.sm, onPressed: () => _zoomBy(1.2), semanticLabel: t.a11y.graphZoomIn),
      AnButton.iconOnly(AnIcons.expand,
          size: AnButtonSize.sm, onPressed: _fit, semanticLabel: t.a11y.graphFit),
    ]);
  }
}

/// Arrow-key navigation → nearest-neighbour hop; off the cone hands the intent back to the framework so
/// the user escapes the graph rather than being trapped (the MenuAnchor/AnRunMatrix precedent). 方向键→最近邻;
/// 锥外交还框架、用户逃出不被困。
class _RelationDirectionalFocusAction extends DirectionalFocusAction {
  _RelationDirectionalFocusAction(this.state);
  final _AnRelationGraphState state;

  @override
  void invoke(DirectionalFocusIntent intent) {
    if (state._move(intent.direction)) return;
    super.invoke(intent);
  }
}

/// One graph node — a kind-coloured dot (radius by in-degree) + a name label, a real widget so focus,
/// tooltip and semantics come free. The dot is the only hit target (labels IgnorePointer so overlapping
/// labels never steal a tap). 一个图节点:kind 色点(半径随入度)+ 名字标签,真 widget;点是唯一命中目标。
class _RelationNode extends StatefulWidget {
  const _RelationNode({
    required this.node,
    required this.radius,
    required this.color,
    required this.selected,
    required this.dim,
    required this.hovered,
    required this.labelHidden,
    required this.focusNode,
    required this.semanticLabel,
    required this.onActivate,
    required this.onHover,
    required this.onPressStart,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.dragSlop,
    super.key,
  });

  final EntityNode node;
  final double radius;
  final Color color;
  final bool selected;
  final bool dim;
  final bool hovered;
  final bool labelHidden;
  final FocusNode focusNode;
  final String semanticLabel;
  final VoidCallback onActivate;
  final ValueChanged<bool> onHover;
  final VoidCallback onPressStart;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final double dragSlop;

  @override
  State<_RelationNode> createState() => _RelationNodeState();
}

class _RelationNodeState extends State<_RelationNode> {
  Offset? _downPos;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    RelationGraphProbe.onNodeBuild?.call();
    final c = context.colors;
    final r = widget.radius;
    final opacity = widget.dim ? 0.28 : 1.0;

    final dot = Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        border: widget.selected
            ? Border.all(color: c.accent, width: 2)
            : (widget.hovered ? Border.all(color: c.ink, width: 1.4) : null),
        boxShadow: widget.selected || widget.hovered ? c.shadowIsland : null,
      ),
    );

    final label = widget.labelHidden
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(
              widget.node.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AnText.meta.copyWith(
                color: widget.selected ? c.accent : c.inkMuted,
              ),
            ),
          );

    final interactive = FocusableActionDetector(
      focusNode: widget.focusNode,
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: widget.onHover,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onActivate();
          return null;
        }),
      },
      child: Semantics(
        label: widget.semanticLabel,
        button: true,
        selected: AnA11y.selected(widget.selected),
        onTap: widget.onActivate,
        child: ExcludeSemantics(child: dot),
      ),
    );

    // Raw Listener owns the press for drag (slop separates a move from a tap) + records the pressed node
    // for the viewport tap detector. 裸 Listener 掌管按下:slop 分拖/点 + 记按下节点供视口点击探测。
    final dotHit = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _downPos = e.localPosition;
        _moved = false;
        widget.onPressStart();
      },
      onPointerMove: (e) {
        final start = _downPos;
        if (start == null) return;
        if (!_moved) {
          if ((e.localPosition - start).distance <= widget.dragSlop) return;
          _moved = true;
          widget.onDragStart();
        }
        widget.onDragUpdate(e.localDelta);
      },
      onPointerUp: (_) {
        if (_moved) widget.onDragEnd();
        _downPos = null;
        _moved = false;
      },
      onPointerCancel: (_) {
        if (_moved) widget.onDragEnd();
        _downPos = null;
        _moved = false;
      },
      child: interactive,
    );

    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [dotHit, IgnorePointer(child: label)],
      ),
    );
  }
}

/// Edge underlay — hairline grey polylines, NO arrowheads (direction is textualized in the tooltip/card).
/// Reads live positions from the state each paint (repaint driven by the frame pulse). On node-hover the
/// one-hop edges stay ink-ish and the rest fade; a hovered edge goes ink. 边底层:hairline 灰线、无箭头
/// (方向文字化);逐帧读活位置;hover 节点时一跳边留深、其余淡,hover 边转 ink。
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.state,
    required this.edge,
    required this.ink,
    required this.accent,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _AnRelationGraphState state;
  final Color edge;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    final hoverNode = state._hoverNodeId;
    final hoverEdge = state._hoverEdgeId;
    for (final e in w.edges) {
      if (state._hidden(e.fromKind) || state._hidden(e.toKind)) continue;
      final a = state._sceneOf(e.fromId), b = state._sceneOf(e.toId);
      final incident = hoverNode != null && (e.fromId == hoverNode || e.toId == hoverNode);
      final isHover = e.id == hoverEdge;
      Color color;
      double width;
      if (isHover) {
        color = ink;
        width = 1.8;
      } else if (hoverNode != null) {
        color = incident ? accent.withValues(alpha: 0.75) : edge.withValues(alpha: 0.25);
        width = incident ? 1.6 : 1.0;
      } else {
        color = edge;
        width = 1.0;
      }
      canvas.drawLine(a, b, Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edge != edge || old.ink != ink || old.accent != accent || !identical(old.state, state);
}

/// The screen-fixed dot-grid backdrop (same look as the workflow canvas / empty state). One batched
/// drawPoints. 钉屏点阵背景(同 workflow 画布/空态);一次批量 drawPoints。
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.dot});
  final Color dot;
  static const double _spacing = AnSpace.s24;

  @override
  void paint(Canvas canvas, Size size) {
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
