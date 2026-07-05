// Dev screenshot harness for the document properties panel WITH backlinks (P5c) — a page linked by two
// others shows its incoming-link rows. NOT part of the gate.
// Run: flutter test test/dev/capture_doc_backlinks.dart → test/dev/out/doc_backlinks.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/state/document_state.dart';
import 'package:anselm/features/documents/ui/documents_inspector.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/router_harness.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

final _t = DateTime.utc(2026, 7, 5);
DocumentNode _doc(String id, String name, {String content = '', List<String> tags = const []}) => DocumentNode(
    id: id, name: name, content: content, tags: tags, path: '/$name', sizeBytes: content.length,
    createdAt: _t, updatedAt: _t);

class _Pinned extends SelectedDocController {
  @override
  DocSelection? build() => (isSkill: false, id: 'doc_a');
}

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture document properties with backlinks', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 1000);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = FixtureDocumentsRepository(
      documents: [
        _doc('doc_a', 'Runbook — inventory',
            content: '# Runbook\n\nReconcile stock…', tags: const ['ops', 'sync']),
        _doc('doc_b', 'Playbooks', content: 'start at [[doc_a]]'),
        _doc('doc_c', 'Onboarding', content: 'read [[doc_a]] before the first shift'),
      ],
      skills: const [],
    );
    final router = buildTestRouter(page: const SizedBox.shrink());

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repo),
          goRouterProvider.overrideWithValue(router),
          selectedDocProvider.overrideWith(_Pinned.new),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Builder(builder: (context) {
              return Scaffold(
                backgroundColor: context.colors.surface,
                body: const Center(child: SizedBox(width: 340, height: 720, child: DocumentsInspector())),
              );
            }),
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
    Directory('test/dev/out').createSync(recursive: true);
    File('test/dev/out/doc_backlinks.png').writeAsBytesSync(bytes);
  });
}
