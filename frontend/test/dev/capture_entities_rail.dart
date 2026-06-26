// Dev screenshot harness for the entity rail (Phase 4.1 STEP 3) — renders the rail in the left island
// of the three-island shell, driven by a zero-backend FixtureEntityRepository, headlessly via Skia →
// test/dev/out/entities_rail.png. Run:  flutter test test/dev/capture_entities_rail.dart
// Verifies the REAL widget tree paints (the white-screen class of bug shows as a blank PNG), at retina
// scale so the thin-Lucide + MiSans render can be eyeballed.
// 实体 rail 截图夹具:无头渲染左岛 rail(fixture 驱动、零后端)成 PNG 供肉眼核对。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_shell.dart';
import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/entity_rail.dart';
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
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

final _t = DateTime.utc(2026, 6, 25, 14, 30);

FixtureEntityRepository _seed() => FixtureEntityRepository(
      functions: [
        FunctionEntity(id: 'fn_1', name: 'normalize-input', createdAt: _t, updatedAt: _t),
        FunctionEntity(id: 'fn_2', name: 'validate-schema', createdAt: _t, updatedAt: _t),
        FunctionEntity(id: 'fn_3', name: 'fetch-weather', createdAt: _t, updatedAt: _t),
        FunctionEntity(id: 'fn_4', name: 'summarize-text', createdAt: _t, updatedAt: _t),
      ],
      handlers: [
        HandlerEntity(id: 'hd_1', name: 'slack', createdAt: _t, updatedAt: _t, runtimeState: 'running'),
        HandlerEntity(id: 'hd_2', name: 'postgres', createdAt: _t, updatedAt: _t, runtimeState: 'running'),
        HandlerEntity(id: 'hd_3', name: 'stripe', createdAt: _t, updatedAt: _t, runtimeState: 'crashed'),
      ],
      agents: [
        AgentEntity(id: 'ag_1', name: 'researcher', createdAt: _t, updatedAt: _t),
        AgentEntity(id: 'ag_2', name: 'triager', createdAt: _t, updatedAt: _t),
      ],
      workflows: [
        WorkflowEntity(
            id: 'wf_1', name: 'daily-digest', createdAt: _t, updatedAt: _t, active: true, lifecycleState: 'active'),
        WorkflowEntity(
            id: 'wf_2',
            name: 'invoice-sync',
            createdAt: _t,
            updatedAt: _t,
            lifecycleState: 'active',
            needsAttention: true),
      ],
    );

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    // Thin Lucide weight (matches AnIcons._family) so kind/section icons render, not tofu. 加载细 Lucide。
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
    LocaleSettings.setLocaleRaw('zh-CN');
  });

  testWidgets('entities rail', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(AnSize.windowInitialWidth * 2, AnSize.windowInitialHeight * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(_seed())],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const RepaintBoundary(
            key: key,
            child: AnShell(sidebar: EntityRail(), inspectorOpen: false),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // let the 4 list futures resolve

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/entities_rail.png').writeAsBytesSync(bytes);
  });
}
