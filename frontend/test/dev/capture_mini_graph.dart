// Dev screenshot harness for AnMiniGraph — run: flutter test test/dev/capture_mini_graph.dart
// → test/dev/out/mini_graph.png. AnMiniGraph 无头截图夹具。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/an_mini_graph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

final _branch = Graph(nodes: const [
  Node(id: 'on_pr_merged', kind: NodeKind.trigger, ref: 'pr-merged'),
  Node(id: 'run_tests', kind: NodeKind.action, ref: 'run-tests'),
  Node(id: 'branch', kind: NodeKind.control, ref: 'passed?'),
  Node(id: 'approve', kind: NodeKind.approval, ref: 'approve-rollback'),
  Node(id: 'rollback', kind: NodeKind.agent, ref: 'do-rollback'),
], edges: const [
  Edge(id: 'e1', from: 'on_pr_merged', to: 'run_tests'),
  Edge(id: 'e2', from: 'run_tests', to: 'branch'),
  Edge(id: 'e3', from: 'branch', fromPort: 'fail', to: 'approve'),
  Edge(id: 'e4', from: 'approve', fromPort: 'yes', to: 'rollback'),
  Edge(id: 'e5', from: 'branch', fromPort: 'retry', to: 'run_tests'),
]);

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture mini graph', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(640, 340);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AnSpace.s24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Builder(builder: (ctx) => Text('AnMiniGraph · 分支(control 分叉 + 回边,kind 五色)',
                  style: AnText.meta.copyWith(color: Theme.of(ctx).colorScheme.outline))),
              const SizedBox(height: AnSpace.s6),
              AnMiniGraph(graph: _branch, height: 240),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    (Directory('test/dev/out')..createSync(recursive: true));
    File('test/dev/out/mini_graph.png').writeAsBytesSync(bytes);
  });
}
