// Dev screenshot harness — renders the DEMO showcase conversations through the REAL fixture→transcript
// path (ConversationTranscript.hydrateTurn → ChatToolCard, exactly what ChatTranscriptView does), so we
// see every tool-card family as it appears live in `make demo`. NOT part of the gate.
//   flutter test test/dev/capture_demo_showcase.dart  → out/demo_showcase_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/core/design/colors.dart';
import 'package:anselm/features/chat/data/chat_showcase_fixture.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
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

/// Render one hydrated turn's blocks the way ChatTranscriptView._block does: tool_call → ChatToolCard,
/// text → markdown, reasoning → a dim line. 按 transcript 同法渲一回合的块。
List<Widget> _renderTurn(BuildContext context, BlockNode turn) {
  final out = <Widget>[];
  for (final b in turn.children) {
    switch (b.kind) {
      case BlockKind.toolCall:
        out.add(Padding(padding: const EdgeInsets.symmetric(vertical: AnSpace.s6), child: ChatToolCard(node: b)));
      case BlockKind.text:
        out.add(Padding(padding: const EdgeInsets.symmetric(vertical: AnSpace.s4), child: AnMarkdown(b.displayText)));
      case BlockKind.reasoning:
        out.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
            child: Text('💭 ${b.displayText}', style: AnText.meta.copyWith(color: Theme.of(context).colorScheme.outline))));
      default:
        break;
    }
  }
  return out;
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

  // One PNG per showcase conversation (they're tall), each rendered top-to-bottom with every tool card
  // expanded. 每个展台对话一张图,工具卡逐个展开。
  final shows = showcaseConversations();
  for (var ci = 0; ci < shows.length; ci++) {
    testWidgets('capture demo showcase $ci', (tester) async {
      LocaleSettings.setLocaleRaw('zh-CN');
      final s = shows[ci];
      final assistant = s.messages.firstWhere((m) => m.role == 'assistant');
      final turn = ConversationTranscript.hydrateTurn(assistant);

      const key = ValueKey('cap');
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(820, 5200);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        child: RepaintBoundary(
          key: key,
          child: TranslationProvider(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AnTheme.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(AnSpace.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context) => Text(s.conv.title, style: AnText.reading.weight(AnText.emphasisWeight).copyWith(color: context.colors.ink))),
                      const SizedBox(height: AnSpace.s12),
                      Builder(builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: _renderTurn(context, turn))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 60));
      // Expand each card via its OUTER row only (re-tapping inner copy chips starts a revert Timer that
      // hangs pumpAndSettle). 只点卡的外层行展开(避开复制 chip 的复位 Timer)。
      for (final card in find.byType(ChatToolCard).evaluate().toList()) {
        final rows = find.descendant(of: find.byWidget(card.widget), matching: find.byType(AnInteractive));
        if (rows.evaluate().isNotEmpty) {
          await tester.tap(rows.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 30));
        }
      }
      await tester.pump(const Duration(seconds: 1)); // settle without waiting on copy-chip revert timers

      late final Uint8List bytes;
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: 2.0);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = png!.buffer.asUint8List();
        image.dispose();
      });
      final dir = Directory('test/dev/out')..createSync(recursive: true);
      File('${dir.path}/demo_showcase_${ci}_${s.conv.id}.png').writeAsBytesSync(bytes);
    });
  }
}
