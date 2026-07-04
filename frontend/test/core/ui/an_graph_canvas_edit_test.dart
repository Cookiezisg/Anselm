import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_graph_canvas.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 W5 — the canvas EDIT plane: node drag reports a moved position, a connect-handle drag
// reports a from→to connection, and a tap near an edge selects it.

Node n(String id, NodeKind k, {int x = 0, int y = 0}) =>
    Node(id: id, kind: k, ref: '${k.name}_$id', pos: NodePosition(x: x, y: y));
Edge e(String id, String from, String to) => Edge(id: id, from: from, to: to);

// All nodes carry pos so the layout respects them (drags land where expected). 全带 pos。
final g = Graph(nodes: [
  n('a', NodeKind.trigger, x: 0, y: 0),
  n('b', NodeKind.action, x: 300, y: 0),
], edges: [
  e('e1', 'a', 'b'),
]);

Widget host(Widget child) => TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: SizedBox(width: 900, height: 600, child: child)),
      ),
    );

void main() {
  testWidgets('node drag reports a moved position', (tester) async {
    (String, NodePosition)? moved;
    await tester.pumpWidget(host(AnGraphCanvas(
      graph: g,
      editable: true,
      onNodeMoved: (id, pos) => moved = (id, pos),
    )));
    await tester.pump();
    // Drag node 'a' to the right. 把 a 往右拖。
    await tester.drag(find.text('a'), const Offset(80, 20));
    await tester.pump();
    expect(moved, isNotNull);
    expect(moved!.$1, 'a');
    // The move is non-zero and rightward (delta / scale). 位移非零、向右。
    expect(moved!.$2.x, greaterThan(0));
  });

  testWidgets('dragging a connect handle from a hovered node reports from→to', (tester) async {
    (String, String)? connected;
    await tester.pumpWidget(host(AnGraphCanvas(
      graph: g,
      editable: true,
      onConnect: (from, to) => connected = (from, to),
    )));
    await tester.pump();
    // Hover node 'a' to reveal its handles. 悬停 a 显连接柄。
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('a')));
    await tester.pump();
    // Drag from a's RIGHT connect handle toward b (a connect gesture, not a node move). 从 a 右柄拖向 b。
    final handle = find.byKey(const ValueKey('graphHandle_a_right'));
    expect(handle, findsOneWidget);
    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveTo(tester.getCenter(find.text('b')));
    await tester.pump();
    await drag.up();
    await tester.pump();
    await gesture.removePointer();
    expect(connected, isNotNull);
    expect(connected!.$1, 'a');
    expect(connected!.$2, 'b');
  });

  testWidgets('a tap near an edge selects it', (tester) async {
    String? tapped;
    await tester.pumpWidget(host(AnGraphCanvas(
      graph: g,
      editable: true,
      onNodeTap: (_) {},
      onEdgeTap: (id) => tapped = id,
    )));
    await tester.pump();
    // Tap the midpoint between a and b (the edge runs horizontally there). 点 a、b 中点。
    final mid = (tester.getCenter(find.text('a')) + tester.getCenter(find.text('b'))) / 2;
    await tester.tapAt(mid);
    await tester.pump();
    expect(tapped, 'e1');
  });

  // Regression (rework review, MEDIUM): a small node drag (past the scene drag-slop but within the
  // viewport tap-slop) must move the node WITHOUT also firing a selection tap (which would toggle the
  // node off + close the inspector). 微拖只移动、不再顺带切换选中。
  testWidgets('a small node drag moves it without also toggling selection', (tester) async {
    (String, NodePosition)? moved;
    String? tapped = 'sentinel';
    await tester.pumpWidget(host(AnGraphCanvas(
      graph: g,
      editable: true,
      selectedNodeId: 'a',
      onNodeMoved: (id, pos) => moved = (id, pos),
      onNodeTap: (id) => tapped = id,
    )));
    await tester.pump();
    // A few px: past the 3-scene-px drag slop, within the 6-viewport-px tap slop. 几像素:越过拖拽阈值、仍在点击带内。
    await tester.drag(find.text('a'), const Offset(5, 0));
    await tester.pump();
    expect(moved, isNotNull); // it moved
    expect(moved!.$1, 'a');
    expect(tapped, 'sentinel'); // onNodeTap NOT fired → selection not toggled 选中未被切换
  });

  testWidgets('handles do not appear when not editable', (tester) async {
    await tester.pumpWidget(host(AnGraphCanvas(graph: g)));
    await tester.pump();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('a')));
    await tester.pump();
    // No move cursor / handle drag path (a read-only canvas ignores hover handles). 只读无连接柄。
    var moved = false;
    await tester.pumpWidget(host(AnGraphCanvas(graph: g, onNodeMoved: (_, _) => moved = true)));
    await tester.pump();
    await tester.drag(find.text('a'), const Offset(50, 0));
    await tester.pump();
    expect(moved, isFalse); // read-only: drag pans the canvas, never moves a node 只读:拖平移画布
    await gesture.removePointer();
  });
}
