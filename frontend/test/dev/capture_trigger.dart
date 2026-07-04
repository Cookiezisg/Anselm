// Dev screenshot harness for the TRIGGER rail entity — overview (4-source-consistent template) +
// observability tabs (活动 activations / 派发 firings). NOT part of the gate.
// Run: flutter test test/dev/capture_trigger.dart → test/dev/out/trigger.png
// trigger 实体开发截图夹具:概览(4 源一致模板)+ 活动/派发观测面。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/detail/overview/trigger_overview.dart';
import 'package:anselm/features/entities/ui/detail/trigger_observability_tab.dart';
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

final _t = DateTime(2026, 7, 4, 9, 0);

final _cron = TriggerEntity(
  id: 'trg_3a1f', name: 'nightly-digest', description: 'Kick the daily digest at 09:00.',
  kind: TriggerSource.cron, config: const {'expression': '0 9 * * *'},
  outputs: const [Field(name: 'firedAt', type: 'string', description: 'When the trigger fired (RFC3339).')],
  refCount: 1, listening: true, lastFiredAt: _t, nextFireAt: _t.add(const Duration(hours: 18, minutes: 30)),
  createdAt: DateTime(2026, 6, 1), updatedAt: _t,
);

final _webhook = TriggerEntity(
  id: 'trg_wh1', name: 'github-push', description: 'Fire when GitHub pushes to main.',
  kind: TriggerSource.webhook,
  config: const {'path': 'gh/push', 'signatureAlgo': 'hmac-sha256-hex', 'signatureHeader': 'X-Hub-Signature-256'},
  outputs: const [Field(name: 'body', type: 'object', description: 'Posted body parsed as JSON.')],
  refCount: 2, listening: true, lastFiredAt: _t, createdAt: DateTime(2026, 6, 1), updatedAt: _t,
);

final _sensor = TriggerEntity(
  id: 'trg_sn1', name: 'queue-depth', description: 'Fire when the job queue backs up.',
  kind: TriggerSource.sensor,
  config: const {'targetKind': 'handler', 'targetId': 'hd_queue', 'method': 'depth', 'intervalSec': 30, 'condition': 'output.depth > 100'},
  outputs: const [Field(name: 'depth', type: 'number')],
  refCount: 1, listening: true, lastFiredAt: _t, createdAt: DateTime(2026, 6, 1), updatedAt: _t,
);

FixtureEntityRepository _repo() => FixtureEntityRepository(
      activations: {
        'trg_3a1f': [
          Activation(id: 'tra_9', triggerId: 'trg_3a1f', kind: TriggerSource.cron, fired: true, firingCount: 1, payload: const {'firedAt': '2026-07-04T09:00:00Z'}, createdAt: _t),
          Activation(id: 'tra_8', triggerId: 'trg_3a1f', kind: TriggerSource.cron, fired: true, firingCount: 1, createdAt: _t.subtract(const Duration(days: 1))),
        ],
      },
      firings: {
        'trg_3a1f': [
          Firing(id: 'trf_3', triggerId: 'trg_3a1f', workflowId: 'wf_digest', activationId: 'tra_9', status: FiringStatus.started, flowrunId: 'flr_done', createdAt: _t, updatedAt: _t),
          Firing(id: 'trf_2', triggerId: 'trg_3a1f', workflowId: 'wf_digest', activationId: 'tra_8', status: FiringStatus.skipped, createdAt: _t.subtract(const Duration(days: 1)), updatedAt: _t.subtract(const Duration(days: 1))),
        ],
      },
    );

Widget _label(BuildContext c, String s) => Padding(
      padding: const EdgeInsets.only(top: AnSpace.s24, bottom: AnSpace.s12),
      child: Text(s, style: AnText.strong.weight(AnText.emphasisWeight).copyWith(color: c.colors.accent)),
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

  testWidgets('capture trigger overview + observability', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 2900);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(_repo())],
      child: RepaintBoundary(
        key: key,
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 720,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Builder(builder: (context) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label(context, 'TRIGGER — nightly-digest (cron · 概览:headline + 运行时 + Fire 载荷)'),
                          TriggerOverview(trigger: _cron),
                          _label(context, 'TRIGGER — github-push (webhook · 可复制的挂载 URL headline)'),
                          TriggerOverview(trigger: _webhook),
                          _label(context, 'TRIGGER — queue-depth (sensor · CEL 条件 headline + 目标/间隔)'),
                          TriggerOverview(trigger: _sensor),
                          _label(context, '活动 tab (activations · 触发面)'),
                          const TriggerActivityTab('trg_3a1f'),
                          _label(context, '派发 tab (firings · 运行面)'),
                          const TriggerDispatchTab('trg_3a1f'),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    // Let the observability providers resolve their fixture futures. 让观测面 provider 解析 fixture future。
    await tester.pump();
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
    File('${dir.path}/trigger.png').writeAsBytesSync(bytes);
  });
}
