// Dev GIF harness for the AnComposer transitions — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_composer_gif.dart   → frames in test/dev/out/composer_frames/
// then ffmpeg → composer.gif. Drives: empty pill → focus halo fades in → typing (send appears) → wrap
// (pill→card morph) → generating (send↔stop) → attachment strip grows in.
//
// AnComposer 转场 GIF 夹具(非门禁):空药丸→聚焦光环淡入→打字 send 出现→换行药丸↔卡片形变→生成 send↔stop→附件条长出。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
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

const String _target =
    '帮我看下这个 workflow 为什么失败,另外顺便看下 sync_inventory 的重试逻辑对不对,我担心跨年的边界没处理好。';

String _reveal(String s, double frac) {
  final n = (s.characters.length * frac.clamp(0.0, 1.0)).round();
  return s.characters.take(n).toString();
}

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture composer transition frames', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(680, 240);
    addTearDown(tester.view.reset);

    final ctrl = TextEditingController();
    final focus = FocusNode();
    final props = ValueNotifier<({bool generating, bool attach})>((generating: false, attach: false));
    addTearDown(() {
      ctrl.dispose();
      focus.dispose();
      props.dispose();
    });

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Builder(builder: (context) {
          final c = context.colors;
          return Material(
            color: c.surface,
            child: Center(
              child: SizedBox(
                width: 560,
                child: AnimatedBuilder(
                  animation: Listenable.merge([ctrl, props]),
                  builder: (context, _) {
                    final gen = props.value.generating;
                    final trailing = gen
                        ? AnButton.iconOnly(AnIcons.stop, semanticLabel: 'stop', onPressed: () {}, key: const ValueKey('stop'))
                        : (ctrl.text.isNotEmpty
                            ? AnButton.iconOnly(AnIcons.send, semanticLabel: 'send', onPressed: () {}, key: const ValueKey('send'))
                            : null);
                    return AnComposer(
                      controller: ctrl,
                      focusNode: focus,
                      placeholder: '问点什么…',
                      lead: [
                        AnButton.iconOnly(AnIcons.mention, semanticLabel: 'at', onPressed: () {}),
                        AnButton.iconOnly(AnIcons.attach, semanticLabel: 'attach', onPressed: () {}),
                      ],
                      trailing: trailing,
                      attachments: props.value.attach
                          ? const Wrap(spacing: AnSpace.s6, children: [AnBadge('spec.md'), AnBadge('shot.png')])
                          : null,
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    ));

    final dir = Directory('test/dev/out/composer_frames');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    var frame = 0;
    Future<void> cap() async {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: 2.0);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/frame_${frame.toString().padLeft(3, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
      frame++;
    }

    for (var t = 0; t <= 3200; t += 40) {
      if (t < 400) {
        ctrl.text = '';
      } else if (t <= 1500) {
        ctrl.text = _reveal(_target, (t - 400) / 1100);
      } else {
        ctrl.text = _target;
      }
      props.value = (generating: t >= 1700 && t < 2300, attach: t >= 2600);
      if (t == 120) focus.requestFocus(); // focus → halo fades in 聚焦→光环淡入
      await tester.pump(const Duration(milliseconds: 40));
      await cap();
    }
  });
}
