// Dev screenshot harness for the Documents right-island properties inspector (P4c) — a fork skill's full
// frontmatter form (description / context / agent / allowed tools / arguments / invocation toggles). NOT
// part of the gate. Run: flutter test test/dev/capture_doc_inspector.dart → test/dev/out/doc_inspector.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
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

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

class _Pinned extends SelectedDocController {
  @override
  DocSelection? build() => (isSkill: true, id: 'commit-helper');
}

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture Documents skill properties inspector', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 1100);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    // A fork skill with a full frontmatter so every field shows (agent is revealed by context=fork).
    final skill = Skill(
      name: 'commit-helper',
      description: 'Draft a tidy conventional-commit message from the staged diff.',
      source: 'user',
      context: 'fork',
      body: '# commit-helper\n\nSummarize the staged changes…',
      frontmatter: const Frontmatter(
        name: 'commit-helper',
        description: 'Draft a tidy conventional-commit message from the staged diff.',
        context: 'fork',
        agent: 'coder',
        allowedTools: ['Read', 'Bash(git:*)', 'Grep'],
        arguments: ['scope'],
        userInvocable: true,
      ),
      updatedAt: DateTime.utc(2026, 7, 5),
    );
    final repo = FixtureDocumentsRepository(documents: const [], skills: [skill]);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repo),
          selectedDocProvider.overrideWith(_Pinned.new),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Builder(builder: (context) {
              return Scaffold(
                backgroundColor: context.colors.surface,
                body: const Center(
                  child: SizedBox(width: 340, height: 760, child: DocumentsInspector()),
                ),
              );
            }),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // The outline is fed by the CENTER editor view in the real app; feed it by hand here (panel-only shot).
    // 大纲由中心编辑视图喂;单截右岛此处手动喂。
    final container = ProviderScope.containerOf(tester.element(find.byType(DocumentsInspector)));
    container.read(docOutlineProvider.notifier).set(const [
      (level: 1, text: 'Commit helper'),
      (level: 2, text: 'Inputs'),
      (level: 2, text: 'Message shape'),
      (level: 3, text: 'Scope rules'),
    ]);
    await tester.pumpAndSettle();

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/doc_inspector.png').writeAsBytesSync(bytes);
  });
}
