// Dev screenshot harness for the cross-run approval INBOX (the left-island bell tray) — approval's runtime
// "second face". NOT part of the gate.
// Run: flutter test test/dev/capture_flowrun_inbox.dart → test/dev/out/flowrun_inbox.png
// 审批收件箱(铃托盘)开发截图夹具:跨 run 待审逐卡决断。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/flowrun_inbox.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

final _t = DateTime(2026, 7, 4, 9, 30);

FlowrunComposite _run(String flr, String wf, String node, String rendered, {bool allowReason = true}) =>
    FlowrunComposite(
      flowrun: Flowrun(id: flr, workflowId: wf, status: 'running', updatedAt: _t),
      nodes: [
        FlowrunNode(
          id: 'frn_${node}_1',
          flowrunId: flr,
          nodeId: node,
          kind: 'approval',
          status: 'parked',
          result: {'rendered': rendered, 'allowReason': allowReason},
          createdAt: _t,
          updatedAt: _t,
        ),
      ],
    );

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture cross-run approval inbox', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(340, 620);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = FixtureEntityRepository(flowrunDetail: {
      'flr_deploy': _run('flr_deploy', 'wf_release', 'deploy_gate',
          'Approve production deploy of checkout-api @ v4.2.0? Staging soak is green.'),
      'flr_refund': _run('flr_refund', 'wf_refunds', 'over_limit',
          'Refund of \$1,240 exceeds the \$1,000 auto-limit — approve manual override?'),
      'flr_purge': _run('flr_purge', 'wf_ops', 'confirm_purge',
          'Purge 3 stale sandbox environments? This frees ~2.1GB and cannot be undone.',
          allowReason: false),
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      child: RepaintBoundary(
        key: key,
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: const Scaffold(
              body: SizedBox(width: 340, height: 620, child: FlowrunInbox()),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(); // provider resolves
    await tester.pump(const Duration(milliseconds: 60));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/flowrun_inbox.png').writeAsBytesSync(bytes);
  });
}
