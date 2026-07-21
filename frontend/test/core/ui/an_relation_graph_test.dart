import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/graph/relation_graph_config.dart';
import 'package:anselm/core/ui/an_relation_graph.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AnRelationGraph (WRK-072) — the entity-relationship force graph. The contracts worth locking: the
/// caller's node/edge SET is what renders (hidden kinds vanish), a node tap reports its id / a background
/// tap reports null, an empty graph is a bare dot-grid (no node widgets, zero text), and — the perf law —
/// a SETTLED graph runs zero sim frames (static-when-settled → zero repaint).
EntityNode node(String kind, String id, String name) =>
    EntityNode(kind: kind, id: id, name: name);
EntityRelation edge(
  String id,
  String fromKind,
  String from,
  String toKind,
  String to, {
  String verb = 'equip',
}) => EntityRelation(
  id: id,
  kind: verb,
  fromKind: fromKind,
  fromId: from,
  toKind: toKind,
  toId: to,
);

final _nodes = [
  node('function', 'fn_hub', 'core-lib'),
  node('workflow', 'wf_a', 'pipeline'),
  node('agent', 'ag_a', 'assistant'),
  node('skill', 'sk_a', 'writing'),
];
final _edges = [
  edge(
    'e1',
    'workflow',
    'wf_a',
    'function',
    'fn_hub',
  ), // wf_a equips fn_hub → fn_hub in-degree 1
  edge(
    'e2',
    'agent',
    'ag_a',
    'function',
    'fn_hub',
  ), // ag_a equips fn_hub → in-degree 2
  edge('e3', 'agent', 'ag_a', 'skill', 'sk_a'),
];

Widget _host(Widget child, {Size size = const Size(700, 460)}) =>
    TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );

Finder _nodeFinder(String id) => find.byKey(ValueKey('relNode_$id'));

// The ripple applies opacity via the node's root [Opacity] — read it to assert the decay tiers. 读节点根
// Opacity 断言涟漪档。
double _nodeOpacity(WidgetTester tester, String id) => tester
    .widget<Opacity>(
      find
          .descendant(of: _nodeFinder(id), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

// The dot is the top-center hit target of the fixed slot (the label below is IgnorePointer). 点=槽顶部居中命中目标。
Offset _dotOf(WidgetTester tester, String id) {
  final r = tester.getRect(_nodeFinder(id));
  return Offset(r.center.dx, r.top + 4);
}

void main() {
  tearDown(() {
    RelationGraphProbe.onNodeBuild = null;
    RelationGraphProbe.onSimFrame = null;
  });

  testWidgets('renders one widget per node; names shown', (tester) async {
    await tester.pumpWidget(
      _host(AnRelationGraph(nodes: _nodes, edges: _edges)),
    );
    await tester.pump();
    for (final n in _nodes) {
      expect(
        _nodeFinder(n.id),
        findsOneWidget,
        reason: '${n.id} node widget present',
      );
      expect(find.text(n.name), findsOneWidget);
    }
  });

  testWidgets(
    'hiddenKinds is a render filter — a hidden kind vanishes, others stay',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AnRelationGraph(
            nodes: _nodes,
            edges: _edges,
            hiddenKinds: const {'skill'},
          ),
        ),
      );
      await tester.pump();
      expect(
        _nodeFinder('sk_a'),
        findsNothing,
        reason: 'skill hidden by the legend',
      );
      expect(
        _nodeFinder('fn_hub'),
        findsOneWidget,
        reason: 'other kinds still render',
      );
    },
  );

  testWidgets('tapping a node reports its id', (tester) async {
    String? tapped = 'unset';
    await tester.pumpWidget(
      _host(
        AnRelationGraph(
          nodes: _nodes,
          edges: _edges,
          onNodeTap: (id) => tapped = id,
        ),
      ),
    );
    await tester.pump();
    // Only the DOT (top of the slot) is the hit target — labels are IgnorePointer so overlapping labels
    // never steal a tap. The widget centre falls on the label gap, so aim near the top. 点=命中目标,标签不吞。
    final rect = tester.getRect(_nodeFinder('fn_hub'));
    await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.2));
    await tester.pump();
    expect(tapped, 'fn_hub');
  });

  testWidgets('empty graph is a bare dot-grid — no node widgets, zero text', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AnRelationGraph(nodes: [], edges: [])));
    await tester.pump();
    expect(
      find.byType(Text),
      findsNothing,
      reason: 'empty state carries zero text',
    );
    // No node slots.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('relNode_'),
      ),
      findsNothing,
    );
  });

  testWidgets('a settled graph runs ZERO sim frames (static-when-settled)', (
    tester,
  ) async {
    var frames = 0;
    RelationGraphProbe.onSimFrame = () => frames++;
    await tester.pumpWidget(
      _host(AnRelationGraph(nodes: _nodes, edges: _edges)),
    );
    await tester.pump(); // post-frame fit
    // The sim settles synchronously in build (settle()); the Ticker should never start at rest.
    frames = 0;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      frames,
      0,
      reason: 'no Ticker frames when the layout is at rest → zero repaint',
    );
  });

  testWidgets('a settled graph rebuilds no node widgets on an idle pump', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AnRelationGraph(nodes: _nodes, edges: _edges)),
    );
    await tester.pump();
    var builds = 0;
    RelationGraphProbe.onNodeBuild = () => builds++;
    await tester.pump(const Duration(milliseconds: 32));
    expect(builds, 0, reason: 'idle graph does not rebuild node widgets');
  });

  testWidgets(
    'carries the caller container summary + per-node semantic sentence',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AnRelationGraph(
            nodes: _nodes,
            edges: _edges,
            semanticSummary: '4 entities, 3 relations',
            nodeSemanticLabel: (n, deg) => '${n.name}, referenced by $deg',
          ),
        ),
      );
      await tester.pump();
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('4 entities, 3 relations'), findsOneWidget);
      // fn_hub has in-degree 2 (wf_a + ag_a equip it).
      expect(
        find.bySemanticsLabel('core-lib, referenced by 2'),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  testWidgets('framed flavour wraps in a fixed-height card', (tester) async {
    // Loose height (the real host is a scroll column) so the framed 320 applies. 松高:框定 320 生效。
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 700,
                child: AnRelationGraph(
                  nodes: _nodes,
                  edges: _edges,
                  framed: true,
                  framedHeight: 320,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final box = tester.getSize(find.byType(AnRelationGraph));
    expect(box.height, 320);
  });

  group('ripple focus (v2 涟漪焦点星图)', () {
    // fn_hub adjacency: wf_a, ag_a (hop 1); sk_a via ag_a (hop 2). fn_hub 邻接:wf_a/ag_a 一跳、sk_a 二跳。
    testWidgets('opacity decays by graph distance from the focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AnRelationGraph(nodes: _nodes, edges: _edges, focusId: 'fn_hub')),
      );
      await tester.pump();
      expect(
        _nodeOpacity(tester, 'fn_hub'),
        RelationGraphConfig.nodeOpacity(0),
        reason: 'focus = full',
      );
      expect(
        _nodeOpacity(tester, 'wf_a'),
        RelationGraphConfig.nodeOpacity(1),
        reason: 'one-hop',
      );
      expect(
        _nodeOpacity(tester, 'ag_a'),
        RelationGraphConfig.nodeOpacity(1),
        reason: 'one-hop',
      );
      expect(
        _nodeOpacity(tester, 'sk_a'),
        RelationGraphConfig.nodeOpacity(2),
        reason: 'two-hop',
      );
    });

    testWidgets('no focusId → the ripple falls back to the highest-degree node', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AnRelationGraph(nodes: _nodes, edges: _edges)),
      );
      await tester.pump();
      // fn_hub has the highest in-degree (equipped by wf_a + ag_a) → it is the default focus. fn_hub 入度最高=默认焦点。
      expect(
        _nodeOpacity(tester, 'fn_hub'),
        RelationGraphConfig.nodeOpacity(0),
      );
    });

    testWidgets(
      'hover moves the ripple to the hovered node, leaving returns to the definitive focus',
      (tester) async {
        // FocusableActionDetector.onShowHoverHighlight only fires under the traditional (mouse) highlight
        // strategy; the test binding defaults to touch. 强制鼠标高亮策略,否则 hover 回调不触发(测试默认 touch)。
        final prevStrategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy = prevStrategy,
        );

        await tester.pumpWidget(
          _host(
            AnRelationGraph(nodes: _nodes, edges: _edges, focusId: 'fn_hub'),
          ),
        );
        await tester.pump();
        expect(
          _nodeOpacity(tester, 'sk_a'),
          RelationGraphConfig.nodeOpacity(2),
          reason: 'far before hover',
        );

        final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(() => g.removePointer());
        await g.addPointer(location: _dotOf(tester, 'sk_a')); // enter the dot
        await tester.pumpAndSettle();
        expect(
          _nodeOpacity(tester, 'sk_a'),
          RelationGraphConfig.nodeOpacity(0),
          reason:
              'hover = a temporary focus preview → the hovered node goes vivid',
        );

        await g.moveTo(const Offset(-800, -800)); // off every node
        await tester.pumpAndSettle();
        expect(
          _nodeOpacity(tester, 'sk_a'),
          RelationGraphConfig.nodeOpacity(2),
          reason: 'moving off returns the ripple to the definitive focus',
        );
      },
    );
  });

  group('interactions', () {
    testWidgets(
      'a background tap reports null (deselect / return to default focus)',
      (tester) async {
        String? tapped = 'unset';
        await tester.pumpWidget(
          _host(
            AnRelationGraph(
              nodes: _nodes,
              edges: _edges,
              onNodeTap: (id) => tapped = id,
            ),
          ),
        );
        await tester.pump();
        // A tap on empty canvas inside the graph box (a corner clear of the fit-centered cloud). 图内空角一点。
        final box = tester.getRect(find.byType(AnRelationGraph));
        await tester.tapAt(box.topLeft + const Offset(6, 6));
        await tester.pump();
        expect(tapped, isNull);
      },
    );

    testWidgets('a double tap fires the navigation intent', (tester) async {
      String? navigated;
      await tester.pumpWidget(
        _host(
          AnRelationGraph(
            nodes: _nodes,
            edges: _edges,
            onNodeTap: (_) {},
            onNodeDoubleTap: (id) => navigated = id,
          ),
        ),
      );
      await tester.pump();
      final dot = _dotOf(tester, 'fn_hub');
      await tester.tapAt(dot);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(dot);
      await tester.pump();
      expect(
        navigated,
        'fn_hub',
        reason: 'the second tap within the window fires the double-tap intent',
      );
    });
  });
}
