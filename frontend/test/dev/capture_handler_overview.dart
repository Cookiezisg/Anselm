// Dev screenshot harness for the handler overview — NOT part of the gate.
// Run: flutter test test/dev/capture_handler_overview.dart → test/dev/out/handler_overview.png
// Renders the new transform-box hero (config → live instance → method ports + readiness pipeline) over
// the existing detail sections (state cards, init args, methods + full class code).
//
// handler 概览开发截图夹具(非门禁):变换盒 hero(config → 活实例 → 方法端口 + 就绪流水线)+ 现有详细段落。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/entities/ui/detail/overview/handler_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
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

final _hd = HandlerEntity(
  id: 'hd_9f2c41aa77b0e310',
  name: 'GithubClient',
  description: 'Resident GitHub REST client — one authenticated session shared across every method call.',
  activeVersionId: 'hv_1',
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 7, 1, 14, 32),
  configState: 'ready',
  runtimeState: 'running',
  activeVersion: HandlerVersion(
    id: 'hv_1',
    handlerId: 'hd_9f2c41aa77b0e310',
    version: 3,
    imports: 'import requests',
    initBody: 'self.token = token\nself.base_url = base_url\nself._s = requests.Session()\nself._s.headers["Authorization"] = f"Bearer {token}"',
    methods: const [
      MethodSpec(
        name: 'create_issue',
        inputs: [Field(name: 'repo', type: 'string'), Field(name: 'title', type: 'string')],
        outputs: [Field(name: 'number', type: 'number')],
        body: 'r = self._s.post(f"{self.base_url}/repos/{repo}/issues", json={"title": title})\nreturn r.json()["number"]',
      ),
      MethodSpec(
        name: 'stream_events',
        inputs: [Field(name: 'repo', type: 'string')],
        outputs: [Field(name: 'event', type: 'object')],
        streaming: true,
        body: 'with self._s.get(f"{self.base_url}/repos/{repo}/events", stream=True) as r:\n    for line in r.iter_lines():\n        yield json.loads(line)',
      ),
      MethodSpec(
        name: 'close_issue',
        inputs: [Field(name: 'repo', type: 'string'), Field(name: 'number', type: 'number')],
        outputs: [],
        timeout: 30000,
        body: 'self._s.patch(f"{self.base_url}/repos/{repo}/issues/{number}", json={"state": "closed"})',
      ),
    ],
    initArgsSchema: const [
      InitArgSpec(name: 'token', type: 'string', required: true, sensitive: true),
      InitArgSpec(name: 'base_url', type: 'string', defaultValue: 'https://api.github.com'),
    ],
    dependencies: const ['requests'],
    pythonVersion: '3.12',
    envId: 'env_7b3',
    envStatus: 'ready',
    envSyncedAt: DateTime(2026, 7, 1, 14, 30),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 7, 1),
  ),
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

  testWidgets('capture HandlerOverview (transform-box hero + detail)', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 1680);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(RepaintBoundary(
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
                  child: HandlerOverview(hd: _hd),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
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
    File('${dir.path}/handler_overview.png').writeAsBytesSync(bytes);
  });
}
