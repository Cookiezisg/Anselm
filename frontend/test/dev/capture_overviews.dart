// Dev screenshot harness for the RESTORED function + handler overviews (transform-box hero removed,
// back to the clean KV document look). NOT part of the gate.
// Run: flutter test test/dev/capture_overviews.dart → test/dev/out/overviews.png
// function/handler 概览还原版开发截图夹具(摘掉变换盒 hero、回到干净 KV 文档 look)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/approval.dart';
import 'package:anselm/core/contract/entities/control.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/detail/overview/approval_overview.dart';
import 'package:anselm/features/entities/ui/detail/overview/control_overview.dart';
import 'package:anselm/features/entities/ui/detail/overview/function_overview.dart';
import 'package:anselm/features/entities/ui/detail/overview/handler_overview.dart';
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

final _t = DateTime(2026, 7, 1, 14, 30);

final _fn = FunctionEntity(
  id: 'fn_9f2c41aa77b0e310',
  name: 'normalize_address',
  description: 'Normalize a raw address string into structured components.',
  tags: const ['util', 'io'],
  activeVersionId: 'fv_1',
  createdAt: DateTime(2026, 6, 1),
  updatedAt: _t,
  activeVersion: FunctionVersion(
    id: 'fv_1',
    functionId: 'fn_9f2c41aa77b0e310',
    version: 3,
    code: 'def normalize_address(raw: str, country: str = "US") -> dict:\n'
        '    parts = _parse(raw)\n'
        '    return {"street": parts.street, "city": parts.city, "zip": parts.zip}',
    inputs: const [Field(name: 'raw', type: 'string'), Field(name: 'country', type: 'string')],
    outputs: const [Field(name: 'address', type: 'object')],
    dependencies: const ['usaddress', 'pydantic'],
    pythonVersion: '3.12',
    envId: 'env_7b3',
    envStatus: 'ready',
    envSyncedAt: _t,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: _t,
  ),
);

final _hd = HandlerEntity(
  id: 'hd_9f2c41aa77b0e310',
  name: 'GithubClient',
  description: 'Resident GitHub REST client — one authenticated session shared across every method call.',
  activeVersionId: 'hv_1',
  createdAt: DateTime(2026, 6, 1),
  updatedAt: _t,
  configState: 'ready',
  runtimeState: 'running',
  activeVersion: HandlerVersion(
    id: 'hv_1',
    handlerId: 'hd_9f2c41aa77b0e310',
    version: 3,
    imports: 'import requests',
    initBody: 'self.token = token\nself._s = requests.Session()',
    methods: const [
      MethodSpec(
        name: 'create_issue',
        inputs: [Field(name: 'repo', type: 'string'), Field(name: 'title', type: 'string')],
        outputs: [Field(name: 'number', type: 'number')],
        body: 'return self._post(repo, title)',
      ),
      MethodSpec(
        name: 'stream_events',
        inputs: [Field(name: 'repo', type: 'string')],
        outputs: [Field(name: 'event', type: 'object')],
        streaming: true,
      ),
      MethodSpec(
        name: 'close_issue',
        inputs: [Field(name: 'repo', type: 'string'), Field(name: 'number', type: 'number')],
        outputs: [],
        timeout: 30000,
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
    envSyncedAt: _t,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: _t,
  ),
);

Widget _label(BuildContext c, String s) => Padding(
      padding: const EdgeInsets.only(top: AnSpace.s24, bottom: AnSpace.s12),
      child: Text(s, style: AnText.strong.weight(AnText.emphasisWeight).copyWith(color: c.colors.accent)),
    );

final _control = ControlLogic(
  id: 'ctl_9f2c41aa77b0e310',
  name: 'quality-gate',
  description: 'Route a PR by its test results — merge when green, review on failures, else retry.',
  activeVersionId: 'ctlv_1',
  createdAt: DateTime(2026, 6, 1),
  updatedAt: _t,
  activeVersion: ControlVersion(
    id: 'ctlv_1',
    controlId: 'ctl_9f2c41aa77b0e310',
    version: 4,
    inputs: const [Field(name: 'failures', type: 'number'), Field(name: 'coverage', type: 'number')],
    branches: const [
      Branch(port: 'merge', when: 'input.failures == 0 && input.coverage > 0.8', emit: {'status': '"ready"'}),
      Branch(port: 'review', when: 'input.failures > 0'),
      Branch(port: 'retry', when: 'true'),
    ],
    createdAt: DateTime(2026, 6, 1),
    updatedAt: _t,
  ),
);

final _approval = ApprovalForm(
  id: 'apf_9f2c41aa77b0e310',
  name: 'deploy-gate',
  description: 'Human approval before a production deploy proceeds.',
  activeVersionId: 'apfv_1',
  createdAt: DateTime(2026, 6, 1),
  updatedAt: _t,
  activeVersion: ApprovalVersion(
    id: 'apfv_1',
    approvalId: 'apf_9f2c41aa77b0e310',
    version: 3,
    inputs: const [Field(name: 'service', type: 'string'), Field(name: 'version', type: 'string')],
    template: '## Deploy {{ input.service }} @ {{ input.version }} to production?\n\n'
        'Review the release notes and the staging soak before approving.',
    allowReason: true,
    timeout: '2d',
    timeoutBehavior: 'reject',
    createdAt: DateTime(2026, 6, 1),
    updatedAt: _t,
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

  testWidgets('capture restored function + handler overviews', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 3600);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = FixtureEntityRepository(functions: [_fn], handlers: [_hd]);

    await tester.pumpWidget(ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
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
                          _label(context, 'FUNCTION — normalize_address'),
                          FunctionOverview(fn: _fn),
                          _label(context, 'HANDLER — GithubClient'),
                          HandlerOverview(hd: _hd),
                          _label(context, 'CONTROL — quality-gate (支撑 kind · 无执行/日志)'),
                          ControlOverview(control: _control),
                          _label(context, 'APPROVAL — deploy-gate (支撑 kind · 模板 + 决策规则)'),
                          ApprovalOverview(approval: _approval),
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
    File('${dir.path}/overviews.png').writeAsBytesSync(bytes);
  });
}
