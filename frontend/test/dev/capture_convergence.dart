// Dev screenshot harness for the 6 convergence primitives (housecleaning) — NOT part of the gate.
// Run: flutter test test/dev/capture_convergence.dart → test/dev/out/convergence.png
// 收敛原语开发截图夹具(非门禁):AnSunkenPanel / AnFloatingBar / AnDivider / AnFormField / AnCodeBlock / AnEdgeFade。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_code_block.dart';
import 'package:anselm/core/ui/an_divider.dart';
import 'package:anselm/core/ui/an_edge_fade.dart';
import 'package:anselm/core/ui/an_floating_bar.dart';
import 'package:anselm/core/ui/an_form_field.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/core/ui/an_sunken_panel.dart';
import 'package:anselm/core/ui/icons.dart';
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

Widget _label(BuildContext c, String s) => Padding(
      padding: const EdgeInsets.only(top: AnSpace.s16, bottom: AnSpace.s6),
      child: Text(s, style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.colors.inkFaint)),
    );

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
  });

  testWidgets('capture convergence primitives', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 1180);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Builder(builder: (context) {
          final c = context;
          return Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(c, 'AnSunkenPanel — 凹陷面板 (聊天泡 / 机器窗)'),
                      const AnSunkenPanel(child: Text('A contained non-interactive well — the chat user bubble.')),
                      const SizedBox(height: AnSpace.s8),
                      AnSunkenPanel(
                        header: Text('\$ ls -la', style: AnText.codeInline.copyWith(color: c.colors.inkMuted)),
                        child: Text('total 4\ndrwxr-xr-x  lib\n-rw-r--r--  README.md',
                            style: AnText.code.copyWith(color: c.colors.inkMuted)),
                      ),
                      _label(c, 'AnFloatingBar + AnDivider.vertical — 浮动工具条'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AnFloatingBar(children: [
                          AnButton.iconOnly(AnIcons.zoomOut, size: AnButtonSize.sm, semanticLabel: 'out', onPressed: () {}),
                          AnButton.iconOnly(AnIcons.zoomIn, size: AnButtonSize.sm, semanticLabel: 'in', onPressed: () {}),
                          const AnDivider.vertical(),
                          AnButton(label: 'Editor', icon: AnIcons.workflow, size: AnButtonSize.sm, onPressed: () {}),
                        ]),
                      ),
                      _label(c, 'AnDivider — 横向通栏'),
                      const AnDivider(),
                      _label(c, 'AnFormField — 纵向表单字段'),
                      const AnFormField(label: 'Method', child: AnInput(placeholder: 'select…', block: true)),
                      const SizedBox(height: AnSpace.s12),
                      AnFormField(
                        label: 'city',
                        labelTrailing: Text('string', style: AnText.meta.copyWith(color: c.colors.inkFaint)),
                        desc: 'the target city name',
                        child: const AnInput(block: true),
                      ),
                      _label(c, 'AnCodeBlock — 只读代码/数据块'),
                      const AnCodeBlock('{\n  "number": 42,\n  "state": "open"\n}'),
                      _label(c, 'AnEdgeFade — 边缘渐隐 (内容溶入两端)'),
                      ClipRect(
                        child: SizedBox(
                          height: 64,
                          child: Stack(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
                              child: Text([for (var i = 0; i < 8; i++) 'scrolling content line $i'].join('\n'),
                                  style: AnText.body.copyWith(color: c.colors.inkMuted)),
                            ),
                            Positioned(top: 0, left: 0, right: 0, height: 20, child: AnEdgeFade(fromTop: true, color: c.colors.surface)),
                            Positioned(bottom: 0, left: 0, right: 0, height: 20, child: AnEdgeFade(fromTop: false, color: c.colors.surface)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ));
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
    File('${dir.path}/convergence.png').writeAsBytesSync(bytes);
  });
}
