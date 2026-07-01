// Dev screenshot harness for AnComposer — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_composer.dart
// Renders the composer's states headlessly → test/dev/out/composer.png. Unlike capture_gallery, this
// board is NOT wrapped in the gallery's ExcludeFocus, so ONE composer can hold real focus to show the
// accent focus halo (the one state the passive gallery can't display). Full (non-reduced) motion; we
// capture with pump (never pumpAndSettle), so the focused caret's blink timer can't hang teardown.
//
// AnComposer 开发截图夹具(非门禁)。不裹 gallery 的 ExcludeFocus,故可让一个 composer 真聚焦、显 accent 光环
// (被动 gallery 唯一显不出的态)。全动效;用 pump 截图(绝不 pumpAndSettle),聚焦光标闪烁不卡 teardown。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/ui.dart';
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

  testWidgets('capture composer states', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(680, 1480);
    addTearDown(tester.view.reset);

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
    File('${dir.path}/composer.png').writeAsBytesSync(bytes);
  });
}

class _Board extends StatefulWidget {
  const _Board();

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  final _empty = TextEditingController();
  final _emptyF = FocusNode();
  final _halo = TextEditingController();
  final _haloF = FocusNode();
  final _one = TextEditingController(text: '帮我看下这个 workflow 为什么失败');
  final _oneF = FocusNode();
  final _multi = TextEditingController(
      text: '第一行……\n第二行,继续写更多内容,看它换行后钮组落到下面一排、圆角从药丸渐变到卡片\n第三行');
  final _multiF = FocusNode();
  final _gen = TextEditingController();
  final _genF = FocusNode();
  final _att = TextEditingController(text: '看下这两个文件');
  final _attF = FocusNode();
  final _land = TextEditingController();
  final _landF = FocusNode();

  @override
  void initState() {
    super.initState();
    // Focus the halo board so the accent focus glow renders in the still. 聚焦光环板显 accent 柔光。
    WidgetsBinding.instance.addPostFrameCallback((_) => _haloF.requestFocus());
  }

  @override
  void dispose() {
    for (final c in [_empty, _halo, _one, _multi, _gen, _att, _land]) {
      c.dispose();
    }
    for (final f in [_emptyF, _haloF, _oneF, _multiF, _genF, _attF, _landF]) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _lead() => Row(mainAxisSize: MainAxisSize.min, children: [
        AnButton.iconOnly(AnIcons.mention, semanticLabel: '提及', onPressed: () {}),
        AnButton.iconOnly(AnIcons.attach, semanticLabel: '附件', onPressed: () {}),
      ]);
  Widget _send() => AnButton.iconOnly(AnIcons.send, semanticLabel: '发送', onPressed: () {});
  Widget _stop() => AnButton.iconOnly(AnIcons.stop, semanticLabel: '停止', onPressed: () {});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget row(String label, Widget composer) => Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
            const SizedBox(height: AnSpace.s6),
            SizedBox(width: 560, child: composer),
          ]),
        );

    return Material(
      color: c.canvas,
      child: Padding(
        padding: const EdgeInsets.all(AnSpace.s32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          row('空态 · 单行药丸 (send 藏)',
              AnComposer(controller: _empty, focusNode: _emptyF, placeholder: '问点什么…', lead: [_lead()])),
          row('聚焦 · accent 光环',
              AnComposer(controller: _halo, focusNode: _haloF, placeholder: '问点什么…', lead: [_lead()])),
          row('有字 · 单行 (send ↑)',
              AnComposer(controller: _one, focusNode: _oneF, placeholder: '问点什么…', lead: [_lead()], trailing: _send())),
          row('多行 · 卡片 reflow',
              AnComposer(controller: _multi, focusNode: _multiF, placeholder: '问点什么…', lead: [_lead()], trailing: _send())),
          row('生成中 · stop',
              AnComposer(controller: _gen, focusNode: _genF, placeholder: '问点什么…', lead: [_lead()], trailing: _stop())),
          row('带附件条',
              AnComposer(
                controller: _att, focusNode: _attF, placeholder: '问点什么…', lead: [_lead()], trailing: _send(),
                attachments: const Wrap(spacing: AnSpace.s6, runSpacing: AnSpace.s6, children: [AnBadge('spec.md'), AnBadge('screenshot.png')]),
              )),
          row('landing · 浮起药丸',
              AnComposer(controller: _land, focusNode: _landF, placeholder: '下午好 · 今天想做点什么?', lead: [_lead()], floating: true)),
        ]),
      ),
    );
  }
}
