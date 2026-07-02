// Dev screenshot harness — how an @entity mention DISPLAYS inside the sent user bubble (AnRefPill
// inline via WidgetSpan, on the bubble's surfaceSunken fill). NOT part of the gate.
//   flutter test test/dev/capture_mention.dart  → test/dev/out/mention.png
// @提及在用户泡内的真实显示(AnRefPill 经 WidgetSpan 内联,衬泡的 surfaceSunken)。非门禁。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/ui/chat_turn.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  await (FontLoader(family)
        ..addFont(Future.value(ByteData.view(
            f.readAsBytesSync().buffer, 0, f.readAsBytesSync().length))))
      .load();
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

  testWidgets('capture mention pill in user bubble', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 560);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Builder(builder: (context) {
            final c = context.colors;
            final ink = AnText.body.copyWith(color: c.ink);
            InlineSpan pill(String kind, String name) => WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: AnRefPill(kind: kind, label: name, id: 'x', onTap: (_) {}),
                );
            Widget bubble(List<InlineSpan> spans) => ChatTurn(
                  role: ChatRole.user,
                  child: Text.rich(TextSpan(style: ink, children: spans)),
                );
            Widget row(String label, Widget w) => Padding(
                  padding: const EdgeInsets.only(bottom: AnSpace.s24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
                    const SizedBox(height: AnSpace.s6),
                    SizedBox(width: 620, child: w),
                  ]),
                );

            return Material(
              color: c.surface,
              child: Padding(
                padding: const EdgeInsets.all(AnSpace.s32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    row('泡内单提及(function)', bubble([
                      const TextSpan(text: '帮我看下 '),
                      pill('function', 'sync_inventory'),
                      const TextSpan(text: ' 为什么失败'),
                    ])),
                    row('泡内多提及(agent + document)', bubble([
                      const TextSpan(text: '让 '),
                      pill('agent', 'deploy-bot'),
                      const TextSpan(text: ' 按 '),
                      pill('document', '发布手册'),
                      const TextSpan(text: ' 的流程走一遍,漏了就补'),
                    ])),
                    row('超长名省略(封顶 280)', bubble([
                      const TextSpan(text: '跑一下 '),
                      pill('workflow', '一个名字特别特别长的季度对账工作流v3-final-final(真的final)'),
                    ])),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    Directory('test/dev/out').createSync(recursive: true);
    File('test/dev/out/mention.png').writeAsBytesSync(bytes);
  });
}
