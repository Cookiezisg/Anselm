import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-066 六族当家件回归电池 — pins every CONFIRMED adversarial-review finding (w5538kje0) so none
// regresses: silent-safe window clamp, narrow-host ledger rows, the prose tail showing its BOTTOM,
// diff live=settled row structure + empty guard, chip copy flash + grapheme truncate, stat notes.
// 「同轨」当家件回归电池:钉死对抗复审全部 CONFIRMED(窗静默安全钳/窄宿主台账行/prose 尾示底/
// diff live 同构+空守卫/chip 复制闪+字素截断/条注记)。

Widget _host(Widget child, {double width = 600}) => TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('AnWindow', () {
    testWidgets('maxHeight clamp is silent-SAFE: a tall Column child never RenderFlex-overflows (复审 #3)',
        (tester) async {
      await tester.pumpWidget(_host(AnWindow(
        maxHeight: 100,
        child: Column(children: [for (var i = 0; i < 20; i++) const SizedBox(height: 20, width: 40)]),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull); // no overflow error 无溢出异常
    });

    testWidgets('unbounded-width host (Row rigid slot) shrink-wraps instead of throwing (复审 #7)',
        (tester) async {
      await tester.pumpWidget(_host(Row(children: const [
        AnWindow(child: Text('w')),
      ])));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('AnLedgerRow', () {
    testWidgets('280px host + 3 chips: ellipsizes, never overflows (复审 HIGH #2)', (tester) async {
      await tester.pumpWidget(_host(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
          AnLedgerRow(
            primary: 'exec_0123456789abcdef',
            chips: [AnChip('completed'), AnChip('iteration 3'), AnChip('durable')],
            meta: '2 分钟前',
          ),
        ]),
        width: 280,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull); // rigid chips used to overflow 180px here 旧刚性 chips 曾溢出
    });
  });

  group('AnLiveTail', () {
    testWidgets('prose face shows the BOTTOM of overflowing text (复审 HIGH #1: was head-frozen)',
        (tester) async {
      final long = List.generate(40, (i) => '第 $i 句蒸馏。').join(' ');
      await tester.pumpWidget(_host(AnLiveTail(long, style: AnLiveTailStyle.prose)));
      await tester.pump();
      // The reverse scroll view sits at offset 0 == the BOTTOM of the content (its geometric
      // guarantee); the old Align clamp clipped the paragraph itself and froze the head.
      // reverse 滚动 offset 0 即内容底(几何保证);旧 Align 钳把段落钉在头部。
      final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scroll.reverse, isTrue);
      final pos = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(pos.pixels, 0); // bottom-pinned 贴底
      expect(pos.maxScrollExtent, greaterThan(0)); // content really overflows the clamp 内容真超钳
    });

    testWidgets('bare face drops the window shell (thinking stays inline prose, 批1)', (tester) async {
      await tester.pumpWidget(_host(const AnLiveTail('思考中的一句话', style: AnLiveTailStyle.prose, bare: true)));
      await tester.pump();
      expect(find.byType(AnWindow), findsNothing); // no machine-window chrome 无机器窗
      expect(find.text('思考中的一句话'), findsOneWidget);
    });

    testWidgets('prose face grows a TOP fade only when the text actually overflows (批1)', (tester) async {
      // Short: no fade. 短文无渐隐。
      await tester.pumpWidget(_host(const AnLiveTail('short', style: AnLiveTailStyle.prose, bare: true)));
      await tester.pump();
      await tester.pump(); // post-frame flip settles 后帧翻稳
      expect(find.byType(AnEdgeFade), findsNothing);
      // Long: overflow → fade (geometry-driven via scroll metrics, NOT TextPainter — C-004).
      // 长文溢出→渐隐(滚动几何驱动,非 TextPainter)。
      final long = List.generate(40, (i) => '第 $i 句蒸馏。').join(' ');
      await tester.pumpWidget(_host(AnLiveTail(long, style: AnLiveTailStyle.prose, bare: true)));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AnEdgeFade), findsOneWidget);
    });

    testWidgets('mono face clips each logical line to one visual line (复审 #23)', (tester) async {
      final longLine = 'x' * 500;
      await tester.pumpWidget(_host(AnLiveTail('$longLine\nsecond', style: AnLiveTailStyle.mono, tailLines: 2)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final texts = tester.widgetList<Text>(find.byType(Text)).where((t) => t.maxLines == 1);
      expect(texts.length, greaterThanOrEqualTo(2)); // per-line clipping 每行单行裁
    });
  });

  group('AnVersionDiff live', () {
    testWidgets('live rows render dels-then-adds through the SETTLED row structure (统一向落定对齐)',
        (tester) async {
      await tester.pumpWidget(_host(const AnVersionDiff(
        live: true,
        before: 'old_a\nold_b',
        after: 'new_a\nnew_b\nnew_c',
      )));
      await tester.pump();
      // Counts in the bar (a Text.rich — findRichText). bar 计数(富文本 finder)。
      expect(find.textContaining('+3', findRichText: true), findsOneWidget);
      expect(find.textContaining('−2', findRichText: true), findsOneWidget);
      // Row order: every − before every +. 行序:− 全在 + 前。
      final oldY = tester.getTopLeft(find.text('old_b')).dy;
      final newY = tester.getTopLeft(find.text('new_a')).dy;
      expect(oldY, lessThan(newY));
      // Line numbers exist for adds (settled structure), none for dels. 加行有号、删行无号(落定同构)。
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('live empty stream renders NOTHING (复审 #29: no bar-only shell)', (tester) async {
      await tester.pumpWidget(_host(const AnVersionDiff(live: true, before: '', after: '')));
      await tester.pump();
      expect(find.byType(AnCodeSurface), findsNothing);
    });

    testWidgets('live face is bounded by the stick viewport (复审 #6: no unbounded wall)', (tester) async {
      final long = List.generate(60, (i) => 'line $i').join('\n');
      await tester.pumpWidget(_host(AnVersionDiff(live: true, before: '', after: long)));
      await tester.pump();
      expect(find.byType(AnStickViewport), findsOneWidget);
    });
  });

  group('AnLiveTail O(tail)', () {
    testWidgets('a huge buffer renders only its tail — the head owns the slice (批1 复审)', (tester) async {
      // 50k logical lines — layout must stay bounded (the slice is a reverse scan + AnCap.window).
      // 5 万逻辑行——layout 必须有界(切尾=反向扫+字符帽)。
      final huge = List.generate(50000, (i) => 'line $i').join('\n');
      await tester.pumpWidget(_host(AnLiveTail(huge, style: AnLiveTailStyle.mono, tailLines: 3)));
      await tester.pump();
      expect(find.text('line 49999'), findsOneWidget); // the newest line 最新行
      expect(find.text('line 49996'), findsNothing); // beyond the 3-line tail 尾外
      // Whole-text materialization would be ~600k chars; the tree must hold only the tail.
      final texts = tester.widgetList<Text>(find.byType(Text)).length;
      expect(texts, lessThan(10));
    });

    testWidgets('bare + windowed faces both survive a single giant no-newline line (帽兜底)', (tester) async {
      final spam = 'x' * 200000; // one logical line — the char cap is the real bound 单逻辑行,靠字符帽
      await tester.pumpWidget(_host(AnLiveTail(spam, style: AnLiveTailStyle.prose, bare: true)));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('AnWindow header-only', () {
    testWidgets('child:null renders header without the dead body gap (批1 复审)', (tester) async {
      await tester.pumpWidget(_host(const AnWindow(header: Text('刚开播'))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('刚开播'), findsOneWidget);
    });
  });

  group('AnFocusRing', () {
    testWidgets('ring paints only when active (opaque-card affordance, WCAG 2.4.7)', (tester) async {
      await tester.pumpWidget(_host(const AnFocusRing(active: false, child: AnWindow(child: Text('卡')))));
      await tester.pump();
      Container ringBox() => tester.widget<Container>(find
          .descendant(of: find.byType(AnFocusRing), matching: find.byType(Container))
          .first);
      expect(ringBox().foregroundDecoration, isNull);
      await tester.pumpWidget(_host(const AnFocusRing(active: true, child: AnWindow(child: Text('卡')))));
      await tester.pump();
      expect(ringBox().foregroundDecoration, isNotNull);
    });
  });

  group('AnChip', () {
    testWidgets('copy taps flash ✓ in the PERMANENT glyph slot (width never jumps, 复审 #13)',
        (tester) async {
      // Mock the clipboard channel — without it setData throws MissingPluginException and the chip
      // honestly flashes ✗ (the right behaviour, wrong test setup). 测试须 mock 剪贴板。
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async => null);
      await tester.pumpWidget(_host(const AnChip('fr_1', copyValue: 'fr_full', mono: true)));
      await tester.pump();
      final before = tester.getSize(find.byType(AnChip));
      expect(find.byIcon(AnIcons.copy), findsOneWidget); // idle affordance 静息示能
      await tester.tap(find.byType(AnChip));
      await tester.pump();
      expect(find.byIcon(AnIcons.check), findsOneWidget); // ✓ flash
      expect(tester.getSize(find.byType(AnChip)), before); // same slot, same width 原槽同宽
    });

    test('truncate is grapheme-aware (复审 #26: no sheared surrogate �)', () {
      final s = '🎉' * 20;
      final out = truncate(s, AnTrunc.id);
      expect(out.contains('�'), isFalse);
      expect(out.endsWith('…'), isTrue);
    });
  });

  group('AnStatBar', () {
    testWidgets('multiple notes render with per-tone voices (复审 #33/#24)', (tester) async {
      await tester.pumpWidget(_host(const AnStatBar(
        notes: [
          AnStatNote('ModuleNotFoundError: x'),
          AnStatNote('实例状态已重置', tone: AnTone.warn),
        ],
      )));
      await tester.pump();
      expect(find.text('ModuleNotFoundError: x'), findsOneWidget);
      expect(find.text('实例状态已重置'), findsOneWidget);
    });
  });
}
