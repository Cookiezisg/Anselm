// Dev screenshot harness for ChatTurn — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_chat_turn.dart
// Renders the turn rhythm on a WHITE board (= the real white ocean, so the gray user bubble's contrast reads
// true) → test/dev/out/chat_turn.png. Reduced-motion still; pump (never pumpAndSettle).
//
// ChatTurn 开发截图夹具(非门禁)。衬白板(=真实白海洋,灰泡对比度才真)→ chat_turn.png。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/features/chat/ui/chat_turn.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture chat turn rhythm', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(740, 1120);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: const _Board(),
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
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/chat_turn.png').writeAsBytesSync(bytes);
  });
}

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    final ink = AnText.body.copyWith(color: context.colors.ink);
    Widget u(String s, {bool sending = false}) =>
        ChatTurn(role: ChatRole.user, sending: sending, child: Text(s, style: ink));
    Widget a(List<String> ps) => ChatTurn(
          role: ChatRole.assistant,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < ps.length; i++) ...[
              if (i > 0) const SizedBox(height: AnSpace.s12),
              Text(ps[i], style: ink),
            ],
          ]),
        );

    final turns = <Widget>[
      u('帮我把 sync_inventory 这个 function 加上失败重试'),
      a(const ['好的,我给 sync_inventory 加了指数退避重试——最多 3 次,间隔 1s→2s→4s。']),
      u('这个 workflow 昨晚跑到第 3 个节点就失败了,你能不能先帮我看下是哪个 handler 抛的错、再决定要不要加重试'),
      a(const [
        '失败超过 3 次会抛 SyncError,让上游 workflow 决定是否降级——不再静默吞掉。',
        '要不要我顺手把第 3 次失败自动开一个 issue?那样你早上就能直接看到,不用翻日志。',
      ]),
      u('第 3 次还失败呢?', sending: true),
    ];

    // WHITE board = the real ocean; the 620 reading column centered. 白板=真实海洋;620 阅读列居中。
    return Material(
      color: context.colors.surface,
      child: Center(
        child: SizedBox(
          width: 620,
          child: Padding(
            padding: const EdgeInsets.all(AnSpace.s32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < turns.length; i++) ...[
                  if (i > 0) const SizedBox(height: AnSpace.s24),
                  turns[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
