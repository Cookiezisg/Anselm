import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_relation_graph.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AnRelationGraph (WRK-072) — the entity-relationship force graph. The contracts worth locking: the
/// caller's node/edge SET is what renders (hidden kinds vanish), a node tap reports its id / a background
/// tap reports null, an empty graph is a bare dot-grid (no node widgets, zero text), and — the perf law —
/// a SETTLED graph runs zero sim frames (static-when-settled → zero repaint).
EntityNode node(String kind, String id, String name) => EntityNode(kind: kind, id: id, name: name);
EntityRelation edge(String id, String fromKind, String from, String toKind, String to, {String verb = 'equip'}) =>
    EntityRelation(id: id, kind: verb, fromKind: fromKind, fromId: from, toKind: toKind, toId: to);

final _nodes = [
  node('function', 'fn_hub', 'core-lib'),
  node('workflow', 'wf_a', 'pipeline'),
  node('agent', 'ag_a', 'assistant'),
  node('skill', 'sk_a', 'writing'),
];
final _edges = [
  edge('e1', 'workflow', 'wf_a', 'function', 'fn_hub'), // wf_a equips fn_hub → fn_hub in-degree 1
  edge('e2', 'agent', 'ag_a', 'function', 'fn_hub'), // ag_a equips fn_hub → in-degree 2
  edge('e3', 'agent', 'ag_a', 'skill', 'sk_a'),
];

Widget _host(Widget child, {Size size = const Size(700, 460)}) => TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Center(child: SizedBox(width: size.width, height: size.height, child: child)),
        ),
      ),
    );

Finder _nodeFinder(String id) => find.byKey(ValueKey('relNode_$id'));

void main() {
  tearDown(() {
    RelationGraphProbe.onNodeBuild = null;
    RelationGraphProbe.onSimFrame = null;
  });

  testWidgets('renders one widget per node; names shown', (tester) async {
    await tester.pumpWidget(_host(AnRelationGraph(nodes: _nodes, edges: _edges)));
    await tester.pump();
    for (final n in _nodes) {
      expect(_nodeFinder(n.id), findsOneWidget, reason: '${n.id} node widget present');
      expect(find.text(n.name), findsOneWidget);
    }
  });

  testWidgets('hiddenKinds is a render filter — a hidden kind vanishes, others stay', (tester) async {
    await tester.pumpWidget(_host(
      AnRelationGraph(nodes: _nodes, edges: _edges, hiddenKinds: const {'skill'}),
    ));
    await tester.pump();
    expect(_nodeFinder('sk_a'), findsNothing, reason: 'skill hidden by the legend');
    expect(_nodeFinder('fn_hub'), findsOneWidget, reason: 'other kinds still render');
  });

  testWidgets('tapping a node reports its id', (tester) async {
    String? tapped = 'unset';
    await tester.pumpWidget(_host(
      AnRelationGraph(nodes: _nodes, edges: _edges, onNodeTap: (id) => tapped = id),
    ));
    await tester.pump();
    // Only the DOT (top of the slot) is the hit target — labels are IgnorePointer so overlapping labels
    // never steal a tap. The widget centre falls on the label gap, so aim near the top. 点=命中目标,标签不吞。
    final rect = tester.getRect(_nodeFinder('fn_hub'));
    await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.2));
    await tester.pump();
    expect(tapped, 'fn_hub');
  });

  testWidgets('empty graph is a bare dot-grid — no node widgets, zero text', (tester) async {
    await tester.pumpWidget(_host(const AnRelationGraph(nodes: [], edges: [])));
    await tester.pump();
    expect(find.byType(Text), findsNothing, reason: 'empty state carries zero text');
    // No node slots.
    expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('relNode_')),
        findsNothing);
  });

  testWidgets('a settled graph runs ZERO sim frames (static-when-settled)', (tester) async {
    var frames = 0;
    RelationGraphProbe.onSimFrame = () => frames++;
    await tester.pumpWidget(_host(AnRelationGraph(nodes: _nodes, edges: _edges)));
    await tester.pump(); // post-frame fit
    // The sim settles synchronously in build (settle()); the Ticker should never start at rest.
    frames = 0;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(frames, 0, reason: 'no Ticker frames when the layout is at rest → zero repaint');
  });

  testWidgets('a settled graph rebuilds no node widgets on an idle pump', (tester) async {
    await tester.pumpWidget(_host(AnRelationGraph(nodes: _nodes, edges: _edges)));
    await tester.pump();
    var builds = 0;
    RelationGraphProbe.onNodeBuild = () => builds++;
    await tester.pump(const Duration(milliseconds: 32));
    expect(builds, 0, reason: 'idle graph does not rebuild node widgets');
  });

  testWidgets('carries the caller container summary + per-node semantic sentence', (tester) async {
    await tester.pumpWidget(_host(AnRelationGraph(
      nodes: _nodes,
      edges: _edges,
      semanticSummary: '4 entities, 3 relations',
      nodeSemanticLabel: (n, deg) => '${n.name}, referenced by $deg',
    )));
    await tester.pump();
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('4 entities, 3 relations'), findsOneWidget);
    // fn_hub has in-degree 2 (wf_a + ag_a equip it).
    expect(find.bySemanticsLabel('core-lib, referenced by 2'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('framed flavour wraps in a fixed-height card', (tester) async {
    // Loose height (the real host is a scroll column) so the framed 320 applies. 松高:框定 320 生效。
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 700,
              child: AnRelationGraph(nodes: _nodes, edges: _edges, framed: true, framedHeight: 320),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    final box = tester.getSize(find.byType(AnRelationGraph));
    expect(box.height, 320);
  });
}
