// Dev screenshot harness for AnDocEditor's @ mention typeahead (P3.4) — drives the real super_editor IME
// so the caret-anchored AnMentionPanel opens over live prose, then screenshots it. NOT part of the gate.
// Run: flutter test test/dev/capture_doc_mention.dart → test/dev/out/doc_mention.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/ui/an_doc_editor.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

const _md = '''# Runbook — inventory sync

When stock drifts, kick the reconciliation flow. The composer references entities inline, so you can wire a
paragraph straight to a function or agent by name:

Owner: ''';

/// A richer @ source for the capture — one of each Quadrinity kind so the panel shows real glyphs + rows.
/// 截图用更丰富的 @ 源:四类各一,面板显真图标 + 行。
class _CaptureMentions implements MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async {
    const all = [
      MentionCandidate(type: 'function', id: 'fn_1', name: 'sync_inventory', description: 'reconcile stock levels'),
      MentionCandidate(type: 'handler', id: 'hd_1', name: 'sync_webhook', description: 'on inventory.updated'),
      MentionCandidate(type: 'agent', id: 'ag_1', name: 'sync_auditor', description: 'explains drift'),
      MentionCandidate(type: 'workflow', id: 'wf_1', name: 'sync_nightly', description: 'scheduled reconcile'),
    ];
    final q = query.toLowerCase();
    return [for (final c in all) if (q.isEmpty || c.name.toLowerCase().contains(q)) c];
  }
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

  testWidgets('capture AnDocEditor @ mention picker', (tester) async {
    LocaleSettings.setLocaleRaw('en');
    BlinkController.indeterminateAnimationsEnabled = false; // no caret ticker → deterministic frame 关光标闪烁
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 900);
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
          home: Builder(builder: (context) {
            return Scaffold(
              backgroundColor: context.colors.surface,
              body: Center(
                child: SizedBox(
                  width: 720,
                  height: 620,
                  child: AnDocEditor(initialMarkdown: _md, autofocus: true, mentionSource: _CaptureMentions()),
                ),
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pump();

    // Place the caret after "Owner: " (the last paragraph) and type the @ trigger + a query to open the panel.
    final doc = SuperEditorInspector.findDocument()!;
    final lastId = doc.getNodeAt(doc.nodeCount - 1)!.id;
    await tester.placeCaretInParagraph(lastId, 'Owner: '.length);
    await tester.typeImeText('@sync');
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
    File('${dir.path}/doc_mention.png').writeAsBytesSync(bytes);
  });
}
