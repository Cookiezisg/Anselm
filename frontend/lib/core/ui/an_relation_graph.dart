import 'dart:collection';
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
import '../graph/relation_graph_config.dart';
import 'an_a11y.dart';
import 'an_button.dart';
import 'an_floating_bar.dart';
import 'icons.dart';

/// The entity-relationship graph primitive — a force-directed node-link view of the workspace topology,
/// for the Entities Overview (observing state = a [framed] preview inside the 720 column) and the
/// full-page explore state. v2「涟漪焦点星图」(用户 0719 拍板): one FOCUS node (default = the most-recently-
/// touched entity, [focusId], supplied by the caller since [EntityNode] has no timestamp) glows and sits a
/// touch larger; colour intensity ripples OUT from it by graph distance — near = vivid, far fades to a quiet
/// veil (hue never changes, only opacity). Hovering any node moves the ripple there as a preview; moving off
/// returns it to the definitive focus. All colour / radius / ripple / force numbers live in
/// [RelationGraphConfig]; this widget carries no visual literal.
///
/// Same HYBRID architecture the design system mandates (§2) and [AnGraphCanvas] proves: identity-bearing
/// NODES are real widgets (fog dot + label + focus + semantics), inert FURNITURE (edges + dot grid) is a
/// cached [CustomPaint] underlay, and the viewport rides a plain [InteractiveViewer]. Layout comes from the
/// framework-free [ForceLayout] engine (four forces + component packing); this widget only DRIVES it (a
/// Ticker during the drag squeeze, stopped at rest → zero repaint) and RENDERS it.
///
/// Selection stays CONTROLLED ([selectedId] + [onNodeTap]); a double-tap fires [onNodeDoubleTap] (→ open the
/// entity page); a background tap reports null (→ deselect / return to the default focus). Semantic
/// sentences are caller callbacks exactly as [AnRunMatrix] takes its label callbacks.
///
/// 实体关系图原语 v2 涟漪焦点星图:一个焦点(默认=最近碰过的实体 focusId,由调用方喂——EntityNode 无时间戳)发柔光、
/// 稍大;色彩强度从它按图距离向外涟漪衰减(近浓远淡,色相不变、只降不透明度)。hover 任意节点=涟漪临时移过去预览,
/// 移开回定焦。全部色/半径/涟漪/力系数在 RelationGraphConfig,本件零视觉字面量。混合架构(节点真 widget、家具缓存
/// CustomPaint、视口原生 InteractiveViewer);布局来自 force_layout(四力+分量打包),本件只驱动(拖拽 Ticker、静止即停)
/// +渲染。选中受控,双击开实体页,点空白报 null。
///
/// A test hook fired each time a node widget BUILDS — the stop-frame test asserts a settled graph rebuilds
/// nothing. 测试钩子:每个节点 build 触发。
abstract final class RelationGraphProbe {
  @visibleForTesting
  static void Function()? onNodeBuild;

  /// Fired each simulation frame (one per Ticker tick). 每仿真帧触发。
  @visibleForTesting
  static void Function()? onSimFrame;
}

class AnRelationGraph extends StatefulWidget {
  const AnRelationGraph({
    required this.nodes,
    required this.edges,
    this.selectedId,
    this.focusId,
    this.revealId,
    this.revealToken = 0,
    this.onNodeTap,
    this.onNodeDoubleTap,
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

  /// The active node set for the current mode. 当前模式的活节点集。
  final List<EntityNode> nodes;

  /// The active edge set (already filtered to structural verbs / provenance by the caller). 活边集。
  final List<EntityRelation> edges;

  /// Controlled selection — accent-ring the node with this id. 受控选中。
  final String? selectedId;

  /// The DEFAULT ripple focus — the most-recently-touched entity's id, computed by the caller (the graph
  /// node carries no timestamp). When nothing is selected/hovered the ripple emanates from here; if null (or
  /// stale) the primitive falls back to the highest-degree node. 默认涟漪焦点=最近碰过实体 id(调用方算);
  /// 无选中/hover 时涟漪从此发出,空/失效则回落入度最高节点。
  final String? focusId;

  /// Fly-to target — when [revealToken] changes, the viewport pans to CENTER this node. 飞到目标。
  final String? revealId;
  final int revealToken;

  /// Node tap → id (a background tap reports null → deselect / return to default focus). 点节点→id(点空白→null)。
  final ValueChanged<String?>? onNodeTap;

  /// Node double-tap → id (→ open the entity page). 双击→id(进实体页)。
  final ValueChanged<String>? onNodeDoubleTap;

  /// Kinds hidden by the explore legend — a RENDER-ONLY filter. 图例隐藏的 kind:仅渲染过滤。
  final Set<String> hiddenKinds;

  /// Observing flavour: a fixed-height hairline card. 观赏形态:定高 hairline 卡。
  final bool framed;
  final double? framedHeight;

  /// Explore flavour: show the floating zoom toolbar. 探索形态:显示悬浮缩放条。
  final bool toolbar;

  /// Observing: hovering the box floats a corner "展开 ↗". 观赏:悬停浮出「展开」。
  final VoidCallback? onExpand;
  final String? expandLabel;

  /// Per-node a11y sentence. 节点语义句。
  final String Function(EntityNode node, int inDegree)? nodeSemanticLabel;

  /// Per-edge relation sentence. 边关系句。
  final String Function(EntityRelation edge)? edgeSemanticLabel;

  /// The container semantic summary. 容器摘要句。
  final String? semanticSummary;

  @override
  State<AnRelationGraph> createState() => _AnRelationGraphState();
}

class _AnRelationGraphState extends State<AnRelationGraph> with SingleTickerProviderStateMixin {
  // Interaction constants (NOT visual tuning — those live in RelationGraphConfig). 交互常量(非视觉调参)。
  static const double _tapSlop = 5.0;
  static const double _dragSlop = 3.0;
  static const double _edgeHoverThreshold = 10; // scene px
  static const int _doubleTapMs = 300;
  static const double _slotW = 132; // fixed label slot width 定宽标签槽

  final TransformationController _tc = TransformationController();
  late ForceLayout _sim;
  String _signature = '';

  // Adjacency (undirected) over the current edge set — the BFS the ripple hops walk. 无向邻接:涟漪 BFS 走它。
  Map<String, List<String>> _adj = const {};
  Set<String> _idSet = const {};

  // Ripple hops from the effective focus — recomputed each build, read live by the edge painter. 涟漪跳数图。
  Map<String, int> _hops = const {};

  // The effective focus node's fog hue — ALL edges wear it (never ink); a faint grey fallback when there is
  // no focus at all. Set each build, read live by the edge painter. 焦点节点雾彩色相:全图边都用它(绝不 ink)。
  Color _focusColor = const Color(0x00000000);

  Offset _origin = Offset.zero;
  Size _contentSize = const Size(600, 400);

  Size _viewport = Size.zero;
  bool _fitted = false;
  bool _labelsHidden = false;

  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;

  String? _hoverNodeId;
  String? _hoverEdgeId;
  bool _boxHover = false;

  String? _dragId;
  Offset _dragSceneCenter = Offset.zero;
  bool _draggedThisPress = false;
  Offset? _tapDownViewport;
  String? _pressedNodeId;
  String? _lastTapId;
  int _lastTapMs = 0;

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

  String _sigOf(List<EntityNode> nodes, List<EntityRelation> edges) {
    final ns = [for (final n in nodes) n.id]..sort();
    final es = [for (final e in edges) '${e.fromId}>${e.toId}']..sort();
    return '${ns.join(',')}|${es.join(',')}';
  }

  void _rebuildSim() {
    _signature = _sigOf(widget.nodes, widget.edges);
    _idSet = {for (final n in widget.nodes) n.id};
    // Undirected adjacency for the ripple BFS. 涟漪 BFS 的无向邻接。
    final adj = <String, List<String>>{for (final n in widget.nodes) n.id: []};
    for (final e in widget.edges) {
      adj[e.fromId]?.add(e.toId);
      adj[e.toId]?.add(e.fromId);
    }
    _adj = adj;
    // Collision radius bakes the label box in (RelationGraphConfig) so the layout keeps labels apart. 碰撞半径含标签盒。
    final inDeg = _inDeg;
    _sim = ForceLayout(
      params: RelationGraphConfig.forceParams,
      nodes: [
        for (final n in widget.nodes)
          ForceNode(
            n.id,
            radius: RelationGraphConfig.collisionRadius(
              RelationGraphConfig.nodeRadius(inDeg[n.id] ?? 0),
              n.name,
            ),
          ),
      ],
      edges: [for (final e in widget.edges) ForceEdge(e.fromId, e.toId)],
    );
    _sim.settle(); // static first paint (deterministic, zero-repaint at rest); drag animates later
    _recomputeBounds();
    final live = _idSet;
    _focusNodes.removeWhere((k, v) {
      if (live.contains(k)) return false;
      v.dispose();
      return true;
    });
    if (_cursorId == null || !live.contains(_cursorId)) {
      _cursorId = _degreeFallback();
    }
    _fitted = false;
  }

  // Highest-degree node — the natural centre; the keyboard cursor's home and the ripple's fallback focus.
  // 入度最高节点:光标之家 + 涟漪回落焦点。
  String? _degreeFallback() {
    if (widget.nodes.isEmpty) return null;
    final deg = _inDeg;
    final ids = [for (final n in widget.nodes) n.id]..sort();
    ids.sort((a, b) => (deg[b] ?? 0).compareTo(deg[a] ?? 0));
    return ids.first;
  }

  Map<String, int> get _inDeg => inDegrees([for (final e in widget.edges) (from: e.fromId, to: e.toId)]);

  // The definitive ripple focus, before the hover preview: selection, else the caller's default (most
  // recent), else the highest-degree fallback. 定焦(hover 之前):选中→默认(最近)→入度回落。
  String? _definitiveFocus() {
    for (final f in [widget.selectedId, widget.focusId]) {
      if (f != null && _idSet.contains(f)) return f;
    }
    return _degreeFallback();
  }

  // The EFFECTIVE focus = the hovered node (temporary preview) if any, else the definitive focus. 有效焦点。
  String? _effectiveFocus() {
    final h = _hoverNodeId;
    if (h != null && _idSet.contains(h)) return h;
    return _definitiveFocus();
  }

  // BFS graph distance (hop count) from [focus]; unreached nodes are absent (→ clamped to the far tier).
  // 从焦点的 BFS 图距;未达节点缺席(→衰减到最远档)。
  Map<String, int> _computeHops(String? focus) {
    if (focus == null || !_adj.containsKey(focus)) return const {};
    final hops = <String, int>{focus: 0};
    final q = Queue<String>()..add(focus);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      final d = hops[cur]!;
      for (final nb in _adj[cur] ?? const <String>[]) {
        if (!hops.containsKey(nb)) {
          hops[nb] = d + 1;
          q.add(nb);
        }
      }
    }
    return hops;
  }

  int _hopOf(String id) => _hops[id] ?? (RelationGraphConfig.nodeOpacityByHop.length - 1);

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
    const m = RelationGraphConfig.sceneMargin;
    _origin = Offset(m - minX, m - minY);
    _contentSize = Size(maxX - minX + m * 2, maxY - minY + m * 2);
  }

  Offset _sceneOf(String id) => _sim.positionOf(id) + _origin;

  double _visualRadiusOf(String id) => RelationGraphConfig.nodeRadius(_inDeg[id] ?? 0);

  double get _scale => _tc.value.entry(0, 0);

  // ── ticker / physics ────────────────────────────────────────────────────
  void _onTick(Duration _) {
    RelationGraphProbe.onSimFrame?.call();
    final moved = _sim.tick();
    _frame.value++;
    if (!moved) _ticker.stop();
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
    const m = RelationGraphConfig.sceneMargin;
    var k = math.min(
      (_viewport.width - m) / _contentSize.width,
      (_viewport.height - m) / _contentSize.height,
    );
    k = k.isFinite && k > 0 ? math.min(k, RelationGraphConfig.fitMaxScale) : 1;
    k = math.max(RelationGraphConfig.fitMinScale, k);
    final x = (_viewport.width - _contentSize.width * k) / 2;
    final y = (_viewport.height - _contentSize.height * k) / 2;
    _tc.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(k, k, k, 1);
    _syncLabels();
  }

  void _zoomAt(Offset anchor, double factor) {
    final k = _scale;
    final nk = (k * factor).clamp(RelationGraphConfig.minScale, RelationGraphConfig.maxScale);
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

  void _syncLabels() {
    final hide = _scale < RelationGraphConfig.labelScaleThreshold;
    if (hide != _labelsHidden) setState(() => _labelsHidden = hide);
  }

  // ── hover ─────────────────────────────────────────────────────────────────
  // Hovering a node moves the ripple there (temporary focus preview); leaving returns to the definitive
  // focus. 涟漪临时移到 hover 的节点,移开回定焦。
  void _setHoverNode(String? id) {
    if (_hoverNodeId == id) return;
    setState(() => _hoverNodeId = id);
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

  List<String> get _visibleIds => [for (final n in widget.nodes) if (!_hidden(n.kind)) n.id];

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
      if (along <= 1) continue;
      final perp = (v.dx * -ay + v.dy * ax).abs();
      if (perp > along) continue;
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

  String _nodeSentence(EntityNode n) => widget.nodeSemanticLabel?.call(n, _inDeg[n.id] ?? 0) ?? n.name;

  void _activate(String id) {
    setState(() => _cursorId = id);
    widget.onNodeTap?.call(id);
  }

  // A tap is a double-tap if it lands on the same node within the window; the double fires the navigation
  // intent, the single fires selection. 同节点窗内二次点击=双击(导航),单击=选中。
  void _tapNode(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTapId == id && now - _lastTapMs < _doubleTapMs) {
      _lastTapId = null;
      widget.onNodeDoubleTap?.call(id);
      return;
    }
    _lastTapId = id;
    _lastTapMs = now;
    _activate(id);
  }

  // ── build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gc = context.graphColors;

    // Resolve the ripple focus, its hops, and its fog hue once per build; node widgets read their hop as a
    // prop, the edge painter reads [_hops] + [_focusColor] live. 每 build 解一次涟漪焦点+跳数+雾彩色相。
    final focus = _effectiveFocus();
    _hops = _computeHops(focus);
    final focusKind =
        focus == null ? null : widget.nodes.where((n) => n.id == focus).map((n) => n.kind).firstOrNull;
    _focusColor = focusKind == null ? gc.edge : RelationGraphConfig.fogColor(focusKind);

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
              _tapNode(pressed);
            } else {
              widget.onNodeTap?.call(null); // background tap → deselect / return to default focus
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
                    minScale: RelationGraphConfig.minScale,
                    maxScale: RelationGraphConfig.maxScale,
                    scaleFactor: RelationGraphConfig.wheelScaleFactor,
                    panEnabled: _dragId == null,
                    onInteractionUpdate: (_) => _syncLabels(),
                    child: _sceneWidget(context, c, gc),
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

  Widget _sceneWidget(BuildContext context, AnColors c, GraphColors gc) {
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
                    painter: _EdgePainter(state: this, focusColor: _focusColor, repaint: _frame),
                  ),
                ),
              ),
            ),
            for (final n in widget.nodes)
              if (!_hidden(n.kind)) _nodeWidget(n),
            if (_hoverEdgeId != null) _edgeTooltip(context, c),
          ]),
        ),
      ),
    );
  }

  // One node's Positioned+draw pair. hop/focus/label are resolved at THIS build (the state's build), baked
  // into the [_RelationNode] `child`; the ValueListenableBuilder only REPOSITIONS on each sim frame, never
  // rebuilds the child — so drag stays zero-node-rebuild (C-016). 节点定位+渲染:hop/焦点/标签在本次 build 定,
  // 烙进 child;帧仅重定位、不重建 child(拖拽零节点重建)。
  Widget _nodeWidget(EntityNode n) {
    final hop = _hopOf(n.id);
    final labelVisible = !_labelsHidden &&
        RelationGraphConfig.labelVisible(hop: hop, scale: _scale, nodeCount: _idSet.length);
    return ValueListenableBuilder<int>(
      valueListenable: _frame,
      child: _RelationNode(
        key: ValueKey('relNode_${n.id}'),
        node: n,
        radius: _visualRadiusOf(n.id),
        color: RelationGraphConfig.fogColor(n.kind),
        hop: hop,
        focused: hop == 0,
        selected: n.id == widget.selectedId,
        labelVisible: labelVisible,
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
        final r = _visualRadiusOf(n.id) + RelationGraphConfig.focusRadiusBonus;
        return Positioned(
          left: p.dx - _slotW / 2,
          top: p.dy - r,
          width: _slotW,
          child: child!,
        );
      },
    );
  }

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

class _RelationDirectionalFocusAction extends DirectionalFocusAction {
  _RelationDirectionalFocusAction(this.state);
  final _AnRelationGraphState state;

  @override
  void invoke(DirectionalFocusIntent intent) {
    if (state._move(intent.direction)) return;
    super.invoke(intent);
  }
}

/// One graph node — a fog-coloured dot (its opacity rippling by [hop] from the focus; the FOCUS at hop 0
/// glows and grows) + a name label. A real widget so focus/tooltip/semantics come free; the dot is the only
/// hit target (labels IgnorePointer). 一个图节点:fog 色点(不透明度随距焦点跳数 hop 涟漪,焦点发柔光并变大)+名字。
class _RelationNode extends StatefulWidget {
  const _RelationNode({
    required this.node,
    required this.radius,
    required this.color,
    required this.hop,
    required this.focused,
    required this.selected,
    required this.labelVisible,
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
  final int hop;
  final bool focused;
  final bool selected;
  final bool labelVisible;
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
    // Ripple: hue fixed, opacity fades by hop. The focus grows a touch and wears a soft fog halo; the first
    // ring gets a fainter one. 涟漪:色相不变、不透明度随跳数淡;焦点稍大+柔光,一跳更弱柔光。
    final opacity = RelationGraphConfig.nodeOpacity(widget.hop);
    final r = widget.radius + (widget.focused ? RelationGraphConfig.focusRadiusBonus : 0);

    final List<BoxShadow>? glow = widget.focused
        ? [
            BoxShadow(
              color: widget.color.withValues(alpha: RelationGraphConfig.focusGlowAlpha),
              blurRadius: RelationGraphConfig.focusGlowBlur,
              spreadRadius: RelationGraphConfig.focusGlowSpread,
            ),
          ]
        : widget.hop == 1
            ? [
                BoxShadow(
                  color: widget.color.withValues(alpha: RelationGraphConfig.oneHopGlowAlpha),
                  blurRadius: RelationGraphConfig.focusGlowBlur * 0.6,
                ),
              ]
            : null;

    // Every dot wears a canvas-coloured halo stroke (Obsidian/Gephi) so it lifts off the edge layer; a
    // SELECTED node swaps it for the accent ring. 每个点画布色描边抬离边层;选中换 accent 环。
    final dot = Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.selected ? c.accent : c.canvas,
          width: widget.selected ? 2 : RelationGraphConfig.nodeStroke,
        ),
        boxShadow: glow,
      ),
    );

    // Text is EXEMPT from the no-ink rule (that bans LINES); the focus label is 13/emphasis ink, the ring
    // muted, the rest faint. Re-weight via `.weight()` (VF pinned-axis rule). 文字不在禁 ink 之列(禁的是线)。
    final labelStyle = (widget.focused ? AnText.label.weight(AnText.emphasisWeight) : AnText.meta).copyWith(
      color: widget.selected
          ? c.accent
          : widget.focused
              ? c.ink
              : widget.hop <= 1
                  ? c.inkMuted
                  : c.inkFaint,
    );
    final label = widget.labelVisible
        ? Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(
              widget.node.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          )
        : const SizedBox.shrink();

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

/// Edge underlay — hairline polylines, NO arrowheads. EVERY edge wears the FOCUS node's fog hue (用户 0719
/// 真机「黑腿」禁令: never ink/black — contrast is layering, not darkening); opacity ripples by the nearer
/// endpoint's hop (focus-incident edges medium ~0.55, unrelated a faint fog texture), and the one edge under
/// the cursor rides the same hue at [RelationGraphConfig.edgeHoverAlpha] + extra width. Reads live positions
/// + the state's [_hops] each paint. 边底层:全用焦点节点雾彩色相(绝不 ink/黑,对比靠层次),不透明度随较近端点
/// 跳数涟漪;光标下那条同色相高透明度+加宽。
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.state,
    required this.focusColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _AnRelationGraphState state;
  final Color focusColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    final hoverEdge = state._hoverEdgeId;
    for (final e in w.edges) {
      if (state._hidden(e.fromKind) || state._hidden(e.toKind)) continue;
      final a = state._sceneOf(e.fromId), b = state._sceneOf(e.toId);
      final isHover = e.id == hoverEdge;
      final Color color;
      final double width;
      if (isHover) {
        color = focusColor.withValues(alpha: RelationGraphConfig.edgeHoverAlpha);
        width = RelationGraphConfig.edgeWidthHover;
      } else {
        final hop = math.min(state._hopOf(e.fromId), state._hopOf(e.toId));
        color = focusColor.withValues(alpha: RelationGraphConfig.edgeOpacity(hop));
        width = hop == 0 ? RelationGraphConfig.edgeWidthFocus : RelationGraphConfig.edgeWidth;
      }
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.focusColor != focusColor || !identical(old.state, state);
}

/// The screen-fixed dot-grid backdrop. One batched drawPoints. 钉屏点阵背景;一次批量 drawPoints。
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
