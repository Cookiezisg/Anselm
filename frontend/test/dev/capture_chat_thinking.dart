// Dev screenshot harness for ChatThinking — NOT part of the gate. Run explicitly:
//   flutter test test/dev/capture_chat_thinking.dart
// Renders the reasoning "whisper + flow-window" states on a WHITE board (= the real white ocean, so the top
// fade dissolves into true white) → test/dev/out/chat_thinking.png. Non-reduced motion (so the run dot
// breathes); pump (never pumpAndSettle).
//
// ChatThinking 开发截图夹具(非门禁)。衬白板(=真实白海洋,顶部渐隐化进真白)→ chat_thinking.png。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/features/chat/ui/chat_thinking.dart';
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

const String _long =
    '用户想按季度汇总发票总额。我得先确认 sync_inventory 这个 function 的输出结构——它返回的是逐行的 line items 还是'
    '已经聚合过的。如果是逐行的,我要先按 issue_date 把每条落到对应季度桶里,再对每桶的 amount 求和。跨年的边界要小心:'
    'Q4 和次年 Q1 不能混。退款行(amount 为负)默认应计入,因为它冲减当季营收。还要考虑币种——若有多币种,得先归一到本位币'
    '再汇总,否则数字没有可比性。另外税额要不要单独拆出来?用户没明说,但财务口径通常看不含税的净额,我倾向默认给净额、'
    '再把含税总额作为附加列。时间范围也得定——是本财年还是滚动 12 个月?先按本财年,给个参数让用户能切。最后把结果按季度'
    '升序排列,附上环比变化,并标出波动超过 10% 的季度供用户重点关注,顺便生成一张简单的季度趋势图放在右岛。';

ChatThinking _t({required bool streaming, bool expanded = false, String? text}) => ChatThinking(
      text: text ?? _long,
      streaming: streaming,
      initiallyExpanded: expanded,
      liveLabel: 'thinking',
      settledLabel: 'thought for 12s',
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

  testWidgets('capture chat thinking states', (tester) async {
    const key = ValueKey('cap');
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(720, 1180);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Builder(builder: (context) {
          final c = context.colors;
          Widget row(String label, Widget w) => Padding(
                padding: const EdgeInsets.only(bottom: AnSpace.s32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
                  const SizedBox(height: AnSpace.s8),
                  SizedBox(width: 600, child: w),
                ]),
              );
          return Material(
            color: c.surface, // white ocean
            child: Padding(
              padding: const EdgeInsets.all(AnSpace.s32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  row('思考中 · 流窗(超 5 行 → 裁 + 顶部渐隐)', _t(streaming: true)),
                  row('思考中 · 短(未满 5 行,全显)',
                      _t(streaming: true, text: '用户想按季度汇总发票,我先拉出行项目再按季度聚合求和。')),
                  row('想完 · 收起(默认一行)', _t(streaming: false)),
                  row('想完 · 展开(回看全文)', _t(streaming: false, expanded: true)),
                ],
              ),
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    // Pump to mid-sweep (breath=1800ms, v≈0.5) so the shimmer band sits over the "thinking" label. 扫光中段。
    await tester.pump(const Duration(milliseconds: 900));

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/chat_thinking.png').writeAsBytesSync(bytes);
  });
}
