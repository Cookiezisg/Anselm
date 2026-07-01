// Dev GIF harness for the ChatThinking lifecycle — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_chat_thinking_gif.dart
// then: ffmpeg the frames in test/dev/out/gif_frames/ → chat_thinking.gif
// Drives the block through BORN (reveal + expand) → STREAM (growing text flows up) → SETTLE (dissolve to one
// line) → EXPAND (tap) → COLLAPSE (tap), capturing a frame every 40ms of animation.
//
// ChatThinking 生命线 GIF 夹具(非门禁):逐帧驱动全程,每 40ms 截一帧,再 ffmpeg 合成。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/features/chat/ui/chat_thinking.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)))).load();
}

const String _long =
    '用户想按季度汇总发票总额。我得先确认 sync_inventory 这个 function 的输出结构——它返回的是逐行的 line items 还是'
    '已经聚合过的。如果是逐行的,我要先按 issue_date 把每条落到对应季度桶里,再对每桶的 amount 求和。跨年的边界要小心:'
    'Q4 和次年 Q1 不能混。退款行(amount 为负)默认应计入,因为它冲减当季营收。还要考虑币种——若有多币种,得先归一到本位币'
    '再汇总,否则数字没有可比性。最后把结果按季度升序排列,附上环比变化,并标出波动超过 10% 的季度供用户重点关注。';

String _textAt(int t) {
  if (t >= 1100) return _long;
  final n = (_long.characters.length * (t / 1100)).round();
  return _long.characters.take(n).toString();
}

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture chat thinking lifecycle frames', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 300);
    addTearDown(tester.view.reset);

    final state = ValueNotifier<({String text, bool streaming})>((text: '', streaming: true));

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Builder(builder: (context) {
          return Material(
            color: context.colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(AnSpace.s24),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 620,
                  child: ValueListenableBuilder(
                    valueListenable: state,
                    builder: (context, v, _) => ChatThinking(
                      text: v.text.isEmpty ? '…' : v.text,
                      streaming: v.streaming,
                      liveLabel: 'thinking',
                      settledLabel: 'thought for 12s',
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ));

    final dir = Directory('test/dev/out/gif_frames');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    var frame = 0;
    Future<void> cap() async {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: 2.0);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/frame_${frame.toString().padLeft(3, '0')}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
      frame++;
    }

    var didExpand = false, didCollapse = false;
    for (var t = 0; t <= 3200; t += 40) {
      // Drive text growth + the settle. 驱动长文增长 + 融解。
      if (t < 1200) {
        state.value = (text: _textAt(t), streaming: true);
      } else if (t >= 1200 && state.value.streaming) {
        state.value = (text: _long, streaming: false); // SETTLE
      }
      await tester.pump(const Duration(milliseconds: 40));
      // Tap the settled label to expand, then to collapse. 点标签展开、再收起。
      if (t >= 1900 && !didExpand) {
        await tester.tap(find.text('thought for 12s'));
        didExpand = true;
      } else if (t >= 2700 && didExpand && !didCollapse) {
        await tester.tap(find.text('thought for 12s'));
        didCollapse = true;
      }
      await cap();
    }
  });
}
