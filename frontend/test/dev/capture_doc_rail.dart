// Dev screenshot harness for the Documents rail CRUD (P4a) — hovers a page row to reveal its ⋯ menu and
// opens it (Rename / Duplicate / Delete), with the New row at the bottom. NOT part of the gate.
// Run: flutter test test/dev/capture_doc_rail.dart → test/dev/out/doc_rail.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/documents/ui/document_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
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

final _t = DateTime.utc(2026, 7, 5);
DocumentNode _doc(String id, String? parent, String name, int pos) =>
    DocumentNode(id: id, parentId: parent, name: name, position: pos, createdAt: _t, updatedAt: _t);
Skill _skill(String name) => Skill(name: name, description: 'x', context: 'inline', body: '# $name', updatedAt: _t);

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture Documents rail CRUD menu', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = FixtureDocumentsRepository(
      documents: [
        _doc('doc_a', null, 'Runbook — inventory', 0),
        _doc('doc_b', 'doc_a', 'Setup', 0),
        _doc('doc_c', 'doc_a', 'Concepts', 1),
        _doc('doc_d', null, 'Playbooks', 1),
      ],
      skills: [_skill('commit-helper'), _skill('triage')],
    );

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [documentsRepositoryProvider.overrideWithValue(repo)],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Builder(builder: (context) {
              return Scaffold(
                backgroundColor: context.colors.surface,
                body: const Center(
                  child: SizedBox(width: 280, height: 560, child: DocumentRail()),
                ),
              );
            }),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Hover a page row to reveal its ⋯, then open the menu. 悬停页行揭示 ⋯,再开菜单。
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Runbook — inventory')));
    await tester.pump();
    // Open the first page row's ⋯ menu (Rename / Duplicate / Delete). The hover-revealed actions stay
    // hit-testable at opacity 0, so tapping the first ellipsis opens that row's menu. 点第一个 ⋯ 开菜单。
    await tester.tap(find.byIcon(AnIcons.more).first);
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
    File('${dir.path}/doc_rail.png').writeAsBytesSync(bytes);
  });
}
