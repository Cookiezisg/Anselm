import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_live_tail.dart';
import 'package:anselm/core/ui/an_window.dart';
import 'package:anselm/features/chat/ui/chat_thinking.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ChatThinking after 批1 (WRK-066): the streaming body is the live-tail family's BARE prose face —
// bottom-pinned clamp, NO window chrome (thinking stays inline prose), and the C-004 whole-text
// TextPainter path is gone. 批1 后的 thinking:流式体=活尾族 prose 无框脸(贴底钳、无窗 chrome),
// C-004 全文 TextPainter 路径已灭。

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SizedBox(width: 500, child: c))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('streaming body = the bare prose tail: AnLiveTail present, NO AnWindow', (tester) async {
    final long = List.generate(30, (i) => '思考第 $i 步。').join(' ');
    await tester.pumpWidget(_host(ChatThinking(
      text: long,
      streaming: true,
      liveLabel: 'thinking',
      settledLabel: 'thought for 3s',
    )));
    await tester.pump(); // born post-frame open 诞生后帧开
    await tester.pump(const Duration(milliseconds: 300)); // reveal tween (bounded pumps — shimmer never settles)
    expect(find.byType(AnLiveTail), findsOneWidget);
    expect(find.byType(AnWindow), findsNothing); // inline prose, not a machine window 内联散文非机器窗
    // Bottom-pinned FOR REAL (复审: pixels==0 alone is vacuously true for any unscrolled view) —
    // the viewport must be REVERSE (0 == content bottom) and the content must actually overflow.
    // 真贴底断言(复审:光 pixels==0 恒真)——须 reverse(0=内容底)且内容真溢出。
    final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scroll.reverse, isTrue);
    final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(pos.pixels, 0);
    expect(pos.maxScrollExtent, greaterThan(0));
  });

  testWidgets('settled + expanded body is the plain full prose (no tail machinery)', (tester) async {
    await tester.pumpWidget(_host(const ChatThinking(
      text: '完整想法。',
      streaming: false,
      liveLabel: 'thinking',
      settledLabel: 'thought for 3s',
      initiallyExpanded: true,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(AnLiveTail), findsNothing);
    expect(find.text('完整想法。'), findsOneWidget);
  });
}
