// Dev screenshot — the Write tool card's expanded body, to eyeball B6 (the code box must NOT sit inside
// a second grey sunken frame). Run: flutter test test/dev/capture_write_card.dart → test/dev/out/write_card.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/ui/tool_card_skins.dart';
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

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('write card', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(640 * 2, 520 * 2);
    addTearDown(tester.view.reset);

    final node = BlockNode(id: 'tc_w', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {
        'name': 'Write',
        'arguments':
            '{"file_path":"/ws/functions/quarters.py","content":"def quarter_of(date):\\n    return (date.month - 1) // 3 + 1\\n"}',
      };
    node.children.add(BlockNode(id: 'tr_w', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': 'Wrote /ws/functions/quarters.py'});

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                width: 640,
                color: const Color(0xFFFFFFFF),
                padding: const EdgeInsets.all(20),
                // Render the Write body directly (bypasses the fold) so we see the code box + whether
                // it sits inside a grey frame (B6). 直接渲 Write 体,验代码框外有无灰框。
                child: Builder(builder: (ctx) => writeToolBody(ctx, ToolCardState.of(node))),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/write_card.png').writeAsBytesSync(bytes);
  });
}
