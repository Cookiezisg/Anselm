import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Node n(String id, NodeKind k, {String? ref}) => Node(id: id, kind: k, ref: ref ?? '${k.name}_$id');
Edge e(String id, String from, String to, {String? port}) =>
    Edge(id: id, from: from, fromPort: port, to: to);

final Graph branchGraph = Graph(nodes: [
  n('on_pr_merged', NodeKind.trigger),
  n('run_tests', NodeKind.action),
  n('branch_result', NodeKind.control),
  n('approve_rollback', NodeKind.approval),
  n('do_rollback', NodeKind.action),
], edges: [
  e('e1', 'on_pr_merged', 'run_tests'),
  e('e2', 'run_tests', 'branch_result'),
  e('e3', 'branch_result', 'approve_rollback', port: 'fail'),
  e('e4', 'approve_rollback', 'do_rollback', port: 'yes'),
  e('back', 'branch_result', 'run_tests', port: 'retry'),
]);

void main() {
  Widget host(Widget child, {Size size = const Size(900, 600)}) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: size.width, height: size.height, child: child),
            ),
          ),
        ),
      );

  Matrix4 viewOf(WidgetTester tester) =>
      tester.widget<Transform>(find.byKey(const ValueKey('anGraphScene'))).transform;
  // entry(0,0) = the uniform scale (getMaxScaleOnAxis mixes in the untouched z axis for k<1).
  double scaleOf(WidgetTester tester) => viewOf(tester).entry(0, 0);

  group('AnGraphCanvas', () {
    testWidgets('renders every node card (id + ref) and port pills', (tester) async {
      await tester.pumpWidget(host(AnGraphCanvas(graph: branchGraph)));
      await tester.pump(); // post-frame fit 首帧后 fit
      for (final node in branchGraph.nodes) {
        expect(find.text(node.id), findsOneWidget);
        expect(find.text(node.ref), findsOneWidget);
      }
      expect(find.text('fail'), findsOneWidget);
      expect(find.text('yes'), findsOneWidget);
      expect(find.text('retry'), findsOneWidget);
    });

    testWidgets('auto-fits on first frame: whole content visible, scale capped', (tester) async {
      await tester.pumpWidget(host(AnGraphCanvas(graph: branchGraph)));
      await tester.pump();
      final k = scaleOf(tester);
      expect(k, lessThanOrEqualTo(1.3));
      expect(k, greaterThan(0));
      // Every node's card center lies inside the viewport after fit. fit 后节点心全在视口内。
      final canvasBox = tester.getRect(find.byType(AnGraphCanvas));
      for (final node in branchGraph.nodes) {
        expect(canvasBox.contains(tester.getCenter(find.text(node.id))), isTrue);
      }
    });

    testWidgets('node tap reports id; background tap reports null', (tester) async {
      String? tapped = 'sentinel';
      await tester.pumpWidget(host(AnGraphCanvas(
        graph: branchGraph,
        onNodeTap: (id) => tapped = id,
      )));
      await tester.pump();
      await tester.tap(find.text('run_tests'));
      expect(tapped, 'run_tests');
      await tester.tapAt(tester.getRect(find.byType(AnGraphCanvas)).bottomRight - const Offset(8, 8));
      expect(tapped, isNull);
    });

    testWidgets('selectedNodeId is controlled (accent ring follows the prop)', (tester) async {
      await tester.pumpWidget(host(AnGraphCanvas(graph: branchGraph, selectedNodeId: 'run_tests')));
      await tester.pump();
      // The selected card's decoration border is thicker than hairline. 选中卡边框粗于 hairline。
      final cards = tester.widgetList<Container>(find.byType(Container));
      final ringed = cards.where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.border is Border && (d.border! as Border).top.width == 1.5;
      });
      expect(ringed, hasLength(1));
    });

    testWidgets('wheel zooms toward the cursor', (tester) async {
      await tester.pumpWidget(host(AnGraphCanvas(graph: branchGraph)));
      await tester.pump();
      final before = scaleOf(tester);
      final center = tester.getCenter(find.byType(AnGraphCanvas));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -240))); // scroll up = zoom in 上滚放大
      await tester.pump();
      expect(scaleOf(tester), greaterThan(before));
    });

    testWidgets('toolbar zooms and fit restores', (tester) async {
      await tester.pumpWidget(host(AnGraphCanvas(graph: branchGraph)));
      await tester.pump();
      final fitted = scaleOf(tester);
      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.pump();
      expect(scaleOf(tester), greaterThan(fitted));
      await tester.tap(find.bySemanticsLabel('Fit to view'));
      await tester.pump();
      expect(scaleOf(tester), moreOrLessEquals(fitted, epsilon: 1e-6));
    });

    testWidgets('drag on empty space pans the scene', (tester) async {
      await tester.pumpWidget(host(AnGraphCanvas(graph: branchGraph)));
      await tester.pump();
      final before = viewOf(tester).getTranslation();
      final rect = tester.getRect(find.byType(AnGraphCanvas));
      await tester.dragFrom(rect.bottomRight - const Offset(12, 12), const Offset(-60, -40));
      await tester.pump();
      final after = viewOf(tester).getTranslation();
      expect(after.x, lessThan(before.x));
      expect(after.y, lessThan(before.y));
    });

    testWidgets('enter-editor action shows only when both label and handler exist', (tester) async {
      var entered = false;
      await tester.pumpWidget(host(AnGraphCanvas(
        graph: branchGraph,
        framed: true,
        enterEditorLabel: 'Open editor',
        onEnterEditor: () => entered = true,
      )));
      await tester.pump();
      await tester.tap(find.text('Open editor'));
      expect(entered, isTrue);

      await tester.pumpWidget(host(AnGraphCanvas(graph: branchGraph, framed: true)));
      await tester.pump();
      expect(find.text('Open editor'), findsNothing);
    });

    testWidgets('framed fixes the preview height', (tester) async {
      await tester.pumpWidget(host(
        Align(alignment: Alignment.topLeft, child: AnGraphCanvas(graph: branchGraph, framed: true)),
      ));
      await tester.pump();
      expect(tester.getSize(find.byType(AnGraphCanvas)).height, 380);
    });

    // Five-battery stress: empty / hostile strings / huge / dangling edges. 五电池。
    testWidgets('empty graph renders without exploding', (tester) async {
      await tester.pumpWidget(host(const AnGraphCanvas(graph: Graph())));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('hostile ids, unknown kind and dangling edges stay safe', (tester) async {
      final g = Graph(nodes: [
        n('trigger_with_an_unreasonably_long_node_identifier_name', NodeKind.trigger,
            ref: 'trg_ffffffffffffffff_more_more_more'),
        n('<b>not</b> & html', NodeKind.unknown, ref: r'${injection}'),
      ], edges: [
        e('e1', 'trigger_with_an_unreasonably_long_node_identifier_name', '<b>not</b> & html',
            port: '{{cel}}'),
        e('dangling', 'nope', 'missing'),
      ]);
      await tester.pumpWidget(host(AnGraphCanvas(graph: g)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('<b>not</b> & html'), findsOneWidget); // literal, never parsed literal 渲染
      expect(find.text('{{cel}}'), findsOneWidget);
    });

    testWidgets('40-node fan renders and fits', (tester) async {
      final g = Graph(nodes: [
        n('t', NodeKind.trigger),
        for (var i = 0; i < 40; i++) n('x$i', NodeKind.action),
      ], edges: [
        for (var i = 0; i < 40; i++) e('e$i', 't', 'x$i'),
      ]);
      await tester.pumpWidget(host(AnGraphCanvas(graph: g)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('x0'), findsOneWidget);
    });
  });
}
