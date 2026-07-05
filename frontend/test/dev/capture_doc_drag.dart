// Dev screenshot harness for the Documents rail tree drag-reorder (P4b) — freezes a drag mid-flight so
// the accent insertion line + the floating name-chip feedback are both visible. Two frames: an ABOVE
// (insertion line) drop and an INSIDE (nest highlight) drop. NOT part of the gate.
// Run: flutter test test/dev/capture_doc_drag.dart → test/dev/out/doc_drag_{line,nest}.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/documents/data/document_fixtures.dart';
import 'package:anselm/features/documents/data/document_repository.dart';
import 'package:anselm/features/documents/ui/document_rail.dart';
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

final _t = DateTime.utc(2026, 7, 5);
DocumentNode _doc(String id, String? parent, String name, int pos) =>
    DocumentNode(id: id, parentId: parent, name: name, position: pos, createdAt: _t, updatedAt: _t);
Skill _skill(String name) => Skill(name: name, description: 'x', context: 'inline', body: '', updatedAt: _t);

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  Future<void> capture(WidgetTester tester, {required Offset Function() to, required String out}) async {
    LocaleSettings.setLocaleRaw('en');
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(560, 760);
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
      skills: [_skill('commit-helper')],
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
                body: const Center(child: SizedBox(width: 280, height: 480, child: DocumentRail())),
              );
            }),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    // Freeze a drag of 'Playbooks' over the target point (insertion line / nest highlight showing).
    final g = await tester.startGesture(tester.getCenter(find.text('Playbooks')));
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveBy(const Offset(0, 6));
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveTo(to());
    await tester.pump(const Duration(milliseconds: 40));

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

    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('capture drag insertion line (above)', (tester) async {
    await capture(tester,
        to: () => tester.getCenter(find.text('Setup').first) - const Offset(0, 12), out: 'doc_drag_line.png');
  });

  testWidgets('capture drag nest highlight (inside)', (tester) async {
    await capture(tester,
        to: () => tester.getCenter(find.text('Concepts').first), out: 'doc_drag_nest.png');
  });
}
