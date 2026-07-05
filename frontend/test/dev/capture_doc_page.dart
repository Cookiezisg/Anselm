// Dev screenshot harness for the reworked documents center page — the entities-style AnOceanHeader
// (breadcrumb + big renamable title) sharing ONE scroll with the editor body, plus the skill variant
// (slug title + meta line, LEFT-aligned — the centered-title bug regression). NOT part of the gate.
// Run: flutter test test/dev/capture_doc_page.dart → test/dev/out/doc_page_{doc,skill}.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/documents/data/documents_demo_fixture.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/ui/document_ocean.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

import '../support/router_harness.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

class _NoMentions extends MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async => const [];
}

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  Future<void> capture(WidgetTester tester, {required String location, required String out}) async {
    LocaleSettings.setLocaleRaw('en');
    BlinkController.indeterminateAnimationsEnabled = false;
    addTearDown(() => BlinkController.indeterminateAnimationsEnabled = true);
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 780);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = demoDocumentsRepository();
    final router = buildTestRouter(
        initialLocation: location, page: const Scaffold(body: DocumentOcean()));

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repo),
          goRouterProvider.overrideWithValue(router),
          mentionSourceProvider.overrideWithValue(_NoMentions()),
        ],
        child: TranslationProvider(
          child: Builder(builder: (context) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AnTheme.light(),
              routerConfig: router,
            );
          }),
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
    Directory('test/dev/out').createSync(recursive: true);
    File('test/dev/out/$out').writeAsBytesSync(bytes);
  }

  testWidgets('capture document page (header + editor, one scroll)', (tester) async {
    await capture(tester, location: '/documents/doc_00000000000a11ce', out: 'doc_page_doc.png');
  });

  testWidgets('capture skill page (left-aligned slug title + meta)', (tester) async {
    await capture(tester, location: '/documents/skill/commit-helper', out: 'doc_page_skill.png');
  });

  testWidgets('capture task-list page (An-styled checkboxes)', (tester) async {
    await capture(tester, location: '/documents/doc_00000000000d44f0', out: 'doc_page_tasks.png');
  });
}
