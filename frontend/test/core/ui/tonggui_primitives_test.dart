import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
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

    testWidgets('批5: dot slot renders the typed status dot before the label', (tester) async {
      await tester.pumpWidget(_host(const AnChip('completed', tone: AnTone.ok, dot: AnStatusDot(AnStatus.done))));
      await tester.pump();
      expect(find.byType(AnStatusDot), findsOneWidget);
      expect(tester.getTopLeft(find.byType(AnStatusDot)).dx, lessThan(tester.getTopLeft(find.text('completed')).dx));
    });

    testWidgets('批5: an EMPTY label renders icon-only with no orphan gap', (tester) async {
      await tester.pumpWidget(_host(const AnChip('', copyValue: 'v', look: AnChipLook.outlined)));
      await tester.pump();
      expect(find.byIcon(AnIcons.copy), findsOneWidget);
      expect(find.byType(Text), findsNothing); // no empty Text, no gap 无空文本无孤儿距
    });

    testWidgets('批5: a STILL chip renders without a TranslationProvider (host-agnostic)', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AnTheme.light(), home: const Scaffold(body: AnChip('quiet'))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('quiet'), findsOneWidget);
    });

    testWidgets('批5: semanticLabel OVERRIDES a11y on a STILL chip (scope-badge preset contract)', (tester) async {
      // The override must differ from the visible label — a same-string fixture is a tautology
      // that stays green when the override channel breaks (复审 #24). 覆盖标签须异串,同串=空真。
      await tester.pumpWidget(_host(const AnChip('本机', semanticLabel: '存储域: 本机')));
      await tester.pump();
      expect(find.bySemanticsLabel('存储域: 本机'), findsOneWidget);
    });
  });

  group('AnStatusDot.raw 批5', () {
    testWidgets('solid raw colour at a tiered size', (tester) async {
      await tester.pumpWidget(_host(const Center(child: AnStatusDot.raw(Color(0xFF112233), size: AnSize.swatch))));
      await tester.pump();
      expect(tester.getSize(find.byType(AnStatusDot)), const Size(AnSize.swatch, AnSize.swatch));
    });
    testWidgets('hollow renders a ring (no fill) and never animates', (tester) async {
      await tester.pumpWidget(_host(const AnStatusDot.raw(null, hollow: true)));
      await tester.pump();
      final box = tester.widget<Container>(find.descendant(of: find.byType(AnStatusDot), matching: find.byType(Container)));
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, isNull);
      expect(deco.border, isNotNull);
      await tester.pump(const Duration(seconds: 2));
      // REAL zero-frame assertion: no live tickers after settle (复审 #25:注释宣称≠断言). 真断言。
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('AnAttachmentThumb onRemove a11y 批5', () {
    testWidgets('the remove button is a LIVE semantic node (never excluded with the pixels)', (tester) async {
      await tester.pumpWidget(_host(AnAttachmentThumb(
        image: null,
        filename: 'photo.png',
        state: AnAttachmentState.failed,
        onRemove: () {},
        removeLabel: '移除附件',
      )));
      await tester.pump();
      expect(find.bySemanticsLabel('移除附件'), findsOneWidget); // 复审 MED:曾整体被 ExcludeSemantics 剥除
    });
  });

  group('AnLedgerRow 批6 三槽', () {
    testWidgets('sub renders under the primary, left-aligned with it (lead offset structural)', (tester) async {
      await tester.pumpWidget(_host(const AnLedgerRow(
          lead: AnStatusDot(AnStatus.done), primary: 'fnexec_01', sub: 'chat 触发', measure: '942ms', meta: '2m')));
      await tester.pump();
      expect(tester.getTopLeft(find.text('chat 触发')).dx, tester.getTopLeft(find.text('fnexec_01')).dx);
      // measure sits LEFT of the meta iron line. measure 居铁线之左。
      expect(tester.getTopRight(find.text('942ms')).dx, lessThan(tester.getTopLeft(find.text('2m')).dx));
    });
    testWidgets('danger sub wears the error-code voice', (tester) async {
      await tester.pumpWidget(_host(const AnLedgerRow(primary: 'charge', sub: 'TIMEOUT', subTone: AnTone.danger)));
      await tester.pump();
      final t = tester.widget<Text>(find.text('TIMEOUT'));
      expect(t.style!.fontFamily, AnText.code.fontFamily);
    });
    testWidgets('expandChild insets EQUALLY from both edges — the phantom frame s8, lead or not '
        '(WRK-070 0718 用户裁,推翻批6 的仅左 lead 沟缩进)', (tester) async {
      // The reveal Align(topCenter) centres shrink-wrapped children — feed a stretched child like
      // real bodies are. 揭示层水平居中收身子件,喂撑满子件如真实用点。
      await tester.pumpWidget(_host(const AnLedgerRow(
          lead: AnStatusDot(AnStatus.done),
          primary: 'row',
          expanded: true,
          expandChild: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [Text('BODY')]))));
      await tester.pump();
      final host = tester.getRect(find.byType(AnLedgerRow));
      final body = tester.getRect(find.text('BODY'));
      expect(body.left - host.left, AnSpace.s8, reason: '左退=假想框 s8');
      // The body COLUMN stretches to the inset width — its right edge mirrors the left. 体列右缘镜像左缘。
      final col = tester.getRect(find
          .ancestor(of: find.text('BODY'), matching: find.byType(Column))
          .first);
      expect(host.right - col.right, AnSpace.s8, reason: '右退=左退(两边一样)');
    });
    testWidgets('a lead-less row expands with the SAME both-side inset (缩进不再随 lead)', (tester) async {
      await tester.pumpWidget(_host(const AnLedgerRow(
          primary: 'row',
          expanded: true,
          expandChild: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [Text('BODY')]))));
      await tester.pump();
      expect(
          tester.getTopLeft(find.text('BODY')).dx - tester.getTopLeft(find.byType(AnLedgerRow)).dx,
          AnSpace.s8,
          reason: '无 lead 同样 s8——假想框与 lead 无关');
    });
    testWidgets('sub is trimmed for render AND geometry: leading \\n paints, whitespace-only stays one line (批6 复审)',
        (tester) async {
      // Wire subs arrive with leading '\n' (LLM finalText) — untrimmed, maxLines:1 paints the empty
      // first line and the whole sub vanishes. 线缆 sub 常带首换行,不 trim 则整行空白。
      await tester.pumpWidget(_host(const Column(children: [
        AnLedgerRow(primary: 'a', sub: '\nDone — created 3 functions.', key: Key('nl')),
        AnLedgerRow(primary: 'b', sub: '   ', key: Key('ws')),
        AnLedgerRow(primary: 'c', key: Key('none')),
      ])));
      await tester.pump();
      // The trimmed text is what renders (find.text matches the FULL data payload). 渲 trim 后文本。
      expect(find.text('Done — created 3 functions.'), findsOneWidget);
      // A whitespace-only sub must not switch the row to two-line geometry with a ghost lane.
      // 纯空白 sub 不得切双行几何留幽灵道。
      expect(tester.getSize(find.byKey(const Key('ws'))).height,
          tester.getSize(find.byKey(const Key('none'))).height);
    });
  });

  group('AnLedgerList 批6', () {
    testWidgets('caps at N, escape reveals the rest in place', (tester) async {
      await tester.pumpWidget(_host(AnLedgerList(cap: 2, children: [
        for (var i = 0; i < 5; i++) AnLedgerRow(primary: 'r$i'),
      ])));
      await tester.pump();
      expect(find.text('r1'), findsOneWidget);
      expect(find.text('r2'), findsNothing);
      await tester.tap(find.textContaining('3'));
      await tester.pump();
      expect(find.text('r4'), findsOneWidget);
    });
    testWidgets('exactly-cap shows no escape; cap+1 does (批6 复审 — a reused State kept _showAll and voided this pin)',
        (tester) async {
      // Fresh State per pump (distinct Keys) — the earlier same-slot pump let a stale _showAll=true
      // suppress the escape row regardless of the boundary. 每泵新 State,防陈旧 _showAll 空真。
      await tester.pumpWidget(_host(AnLedgerList(
          key: const Key('exact'),
          cap: 2,
          children: [AnLedgerRow(primary: 'a'), AnLedgerRow(primary: 'b')])));
      await tester.pump();
      expect(find.textContaining('展开'), findsNothing);
      await tester.pumpWidget(_host(AnLedgerList(
          key: const Key('over'),
          cap: 2,
          children: [AnLedgerRow(primary: 'a'), AnLedgerRow(primary: 'b'), AnLedgerRow(primary: 'x')])));
      await tester.pump();
      expect(find.textContaining('展开'), findsOneWidget);
    });
  });

  group('AnLadder 批6', () {
    testWidgets('numbers every rung; the last rung has no descent line', (tester) async {
      await tester.pumpWidget(_host(const AnLadder(children: [Text('one'), Text('two'), Text('three')])));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // The descent line is the ONE Expanded-Container in each rung's number column — 3 rungs bind
      // with exactly 2 lines, the last rung ends clean (批6 复审:此前测试名主张、测试体零断言).
      // 降线=序号列唯一 Expanded-Container:3 级恰 2 线,末级收线。
      expect(
          find.descendant(
              of: find.byType(AnLadder),
              matching: find.byWidgetPredicate((w) => w is Expanded && w.child is Container)),
          findsNWidgets(2));
    });
  });

  group('AnKvRow.flag 批6', () {
    testWidgets('renders ✓/— and speaks localized yes/no (never «check mark»)', (tester) async {
      await tester.pumpWidget(_host(const AnKv(rows: [AnKvRow.flag('listening', true), AnKvRow.flag('archived', false)])));
      await tester.pump();
      expect(find.text('✓'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      // EXACT labels — a bare-glyph regression ('listening: ✓') must go red, which a RegExp
      // contains-match never did (批6 复审空真). 精确整标签,裸字形回归必红。
      expect(find.bySemanticsLabel('listening: 是'), findsOneWidget);
      expect(find.bySemanticsLabel('archived: 否'), findsOneWidget);
    });
    testWidgets('the flag row wears the family inset — edges align with sibling rows (批6 复审)', (tester) async {
      await tester.pumpWidget(_host(const AnKv(rows: [AnKvRow('plain', 'v'), AnKvRow.flag('listening', true)])));
      await tester.pump();
      // Same h-inset as the read-only row: keys align on one left edge. 与只读行同水平内距,键同缘。
      expect(tester.getTopLeft(find.text('listening')).dx, tester.getTopLeft(find.text('plain')).dx);
    });
  });

  group('AnKeycap 批5c', () {
    testWidgets('tri-state renders and taps; the keycap is NEVER focusable (host owns the keyboard)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AnKeycap('⌘ K', onTap: () => taps++)));
      await tester.pump();
      await tester.tap(find.text('⌘ K'));
      expect(taps, 1);
      // Focus-order contract: the keycap SUBTREE hosts no Focus/AnInteractive node — the shortcuts
      // panel's recording Focus must not compete (settings 战役教训). 键帽子树零可聚焦节点。
      expect(find.descendant(of: find.byType(AnKeycap), matching: find.byType(Focus)), findsNothing);
      expect(find.descendant(of: find.byType(AnKeycap), matching: find.byType(AnInteractive)), findsNothing);
    });

    testWidgets('compact tier (0719): per-key caps at rest — one 20-high plate per fragment, fits a 32 row',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
          AnKeycap('⌘⇧B', keys: const ['⌘', '⇧', 'B'], onTap: () => taps++)));
      await tester.pump();
      // Three separate caps; no whole-chord text. 三枚独立帽,无整弦文本。
      for (final k in ['⌘', '⇧', 'B']) {
        expect(find.text(k), findsOneWidget);
      }
      expect(find.text('⌘⇧B'), findsNothing);
      // Cap height = the keycap token (20) — the settings row keeps its 32 rhythm. 帽高 20,行回 32。
      expect(tester.getSize(find.byType(AnKeycap)).height, AnSize.keycap);
      // The whole chord is ONE tap target and ONE semantics label. 整弦一个点击靶+单语义。
      await tester.tap(find.text('⇧'));
      expect(taps, 1);
      expect(find.bySemanticsLabel('⌘⇧B'), findsOneWidget);
    });

    testWidgets('recording keeps the wide plate (the big form is recording-dedicated)', (tester) async {
      await tester.pumpWidget(_host(const AnKeycap('按下快捷键…',
          keys: ['⌘', 'B'], state: AnKeycapState.recording)));
      await tester.pump();
      expect(find.text('按下快捷键…'), findsOneWidget, reason: '录制态渲宽板文本');
      expect(find.text('⌘'), findsNothing, reason: '录制态不渲逐键帽');
    });
  });

  group('AnSwatch 批5c', () {
    testWidgets('pick cell speaks selected semantics; dot face is inert', (tester) async {
      await tester.pumpWidget(_host(Row(mainAxisSize: MainAxisSize.min, children: [
        AnSwatch(const Color(0xFF5B8DEF), selected: true, onTap: () {}),
        const AnSwatch(Color(0xFF4CAF7D), size: AnSwatchSize.dot),
      ])));
      await tester.pump();
      // ONE merged node: selected flag + real button/tap together (双节点病回归钉). 并单节点钉。
      final node = tester.getSemantics(find.byType(AnSwatch).first);
      expect(node, matchesSemantics(hasSelectedState: true, isSelected: true, isButton: true, hasTapAction: true, isFocusable: true, hasFocusAction: true, hasEnabledState: true, isEnabled: true));
      expect(tester.getSize(find.byType(AnSwatch).last), const Size(AnSize.swatch, AnSize.swatch));
    });
  });

  group('AnFollowPill.jump 批5', () {
    testWidgets('static: renders label + never subscribes to the pulse clock', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AnFollowPill.jump(label: '回到最新', onTap: () => taps++)));
      await tester.pump();
      expect(find.text('回到最新'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      // REAL no-clock assertion: zero live tickers (the breathing faces subscribe; jump must not).
      // 真断言:零活 ticker(呼吸脸挂钟,jump 绝不)。
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.text('回到最新'));
      expect(taps, 1);
    });
  });

  group('AnCodeEditor 批2', () {
    test('collapsedHeightFor locks the family geometry (B-002: features never re-derive font math)', () {
      expect(AnCodeEditor.collapsedHeightFor(50, reading: true),
          50 * AnText.codeReading.fontSize! * AnText.codeReading.height! + 44);
      expect(AnCodeEditor.collapsedHeightFor(8),
          8 * AnText.code.fontSize! * AnText.code.height! + 44);
    });

    test('langOf / langOfEntityKind — the ONE ext→lang table (A-023)', () {
      expect(langOf('/ws/a.py'), 'python');
      expect(langOf('x.ts'), 'typescript'); // 批2 改判钉死(旧私表误标 javascript)
      expect(langOf('SKILL.md'), 'markdown');
      expect(langOf('noext'), isNull);
      expect(langOfEntityKind('function'), 'python');
      expect(langOfEntityKind('skill'), 'markdown');
      expect(langOfEntityKind('workflow'), isNull);
    });

    testWidgets('zero-jump: live and settled faces have the SAME frame height at the same tier (缺口A)',
        (tester) async {
      final code = List.generate(60, (i) => 'line_$i = $i').join('\n');
      Future<double> frameH({required bool live}) async {
        await tester.pumpWidget(_host(AnCodeEditor(
            code: code, lang: 'python', live: live, maxHeight: AnSize.codeViewportSm)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        return tester.getSize(find.byType(AnCodeSurface)).height;
      }

      final liveH = await frameH(live: true);
      final settledH = await frameH(live: false);
      // The settle only un-pins — the whole-frame clamp used to make settled 44px SHORTER (复审).
      // 落定仅解除钉底——旧整框钳曾让落定矮 44px。
      expect(settledH, liveH);
    });

    testWidgets('live face slices its own O(tail): huge code renders, gutter numbers stay honest',
        (tester) async {
      final huge = List.generate(20000, (i) => 'v${i + 1} = ${i + 1}').join('\n');
      await tester.pumpWidget(_host(AnCodeEditor(code: huge, live: true, maxHeight: AnSize.codeViewport)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      // The newest line is present; the head is sliced away (AnCap.window). 最新行在场,头部已切。
      expect(find.textContaining('v20000 = 20000'), findsOneWidget);
      expect(find.textContaining('v1 = 1\n'), findsNothing);
      // Gutter continues from the true line number (not restarting at 1). 行号续排不归一。
      final gutter = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').firstWhere(
          (d) => d.contains('\n') && RegExp(r'^\d+\n').hasMatch(d), orElse: () => '');
      expect(gutter.startsWith('1\n'), isFalse);
    });
  });

  group('AnVersionDiff 批2', () {
    testWidgets('zero-jump: live and settled diff faces have the SAME frame height (复审: diff 孪生件同病)',
        (tester) async {
      final before = List.generate(40, (i) => 'old_$i').join('\n');
      final after = List.generate(40, (i) => 'new_$i').join('\n');
      Future<double> frameH({required bool live}) async {
        await tester.pumpWidget(_host(AnVersionDiff(
            before: before, after: after, live: live, maxHeight: AnSize.codeViewport)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        return tester.getSize(find.byType(AnCodeSurface)).height;
      }

      expect(await frameH(live: false), await frameH(live: true)); // 落定瞬间不再矮 32px
    });

    testWidgets('bounded host + maxHeight stays silent-safe (复审: 裸钳曾溢出)', (tester) async {
      final after = List.generate(60, (i) => 'l$i').join('\n');
      await tester.pumpWidget(_host(SizedBox(
          height: 120,
          child: AnVersionDiff(before: '', after: after, maxHeight: AnSize.codeViewport))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('AnCodeEditor live 增量与换源 批2', () {
    testWidgets('gutter numbering stays honest across APPEND frames (kills the += → = mutation)',
        (tester) async {
      String make(int lines) => List.generate(lines, (i) => 'ln${(i + 1).toString().padLeft(5, '0')}').join('\n');
      int firstGutterLine(WidgetTester t) {
        final g = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').firstWhere(
            (d) => d.contains('\n') && RegExp(r'^\d+\n').hasMatch(d));
        return int.parse(g.split('\n').first);
      }

      // Frame 1: 1200 lines × 8 chars ≈ 9.6k chars > AnCap.window → sliced. 首帧已切。
      await tester.pumpWidget(_host(AnCodeEditor(code: make(1200), live: true, maxHeight: AnSize.codeViewport)));
      await tester.pump();
      final start1 = firstGutterLine(tester);
      expect(start1, greaterThan(1)); // head sliced 头已切
      // Frame 2: SAME State, 300 more lines appended → the gutter start must advance by exactly 300
      // (the incremental count; a `=` mutation would reset the head count and lie). 追加 300 行,
      // 起始行号必须恰好前进 300(增量计数;`=` 突变会重置头计数撒谎)。
      await tester.pumpWidget(_host(AnCodeEditor(code: make(1500), live: true, maxHeight: AnSize.codeViewport)));
      await tester.pump();
      expect(firstGutterLine(tester), start1 + 300);
    });

    testWidgets('a same-State SOURCE SWAP recounts from scratch (复审: 仅比切点的守卫铸假行号)',
        (tester) async {
      final a = List.generate(1200, (i) => 'aaaaaaa').join('\n'); // 8 chars/line
      final b = List.generate(4000, (i) => 'bbb').join('\n'); // 4 chars/line, LONGER text
      await tester.pumpWidget(_host(AnCodeEditor(code: a, live: true, maxHeight: AnSize.codeViewport)));
      await tester.pump();
      // Swap to unrelated content on the SAME State. 同 State 整替。
      await tester.pumpWidget(_host(AnCodeEditor(code: b, live: true, maxHeight: AnSize.codeViewport)));
      await tester.pump();
      final gutter = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').firstWhere(
          (d) => d.contains('\n') && RegExp(r'^\d+\n').hasMatch(d));
      final start = int.parse(gutter.split('\n').first);
      // Fresh-mount truth for B: 16k chars, cap 6000 → head ≈ 10k chars ≈ 2500 lines. The stale-count
      // failure mode produced a start near A's head count (~500) instead. B 的真值起始 ≈ 2501。
      final freshHeadLines = ((b.length - AnCap.window) / 4).ceil();
      expect((start - (freshHeadLines + 1)).abs(), lessThan(3)); // within alignment slack 对齐容差
    });

    testWidgets('bounded host + maxHeight stays silent-safe (复审: 裸钳曾溢出 152px)', (tester) async {
      final code = List.generate(60, (i) => 'line_$i').join('\n');
      await tester.pumpWidget(_host(SizedBox(
          height: 120, child: AnCodeEditor(code: code, maxHeight: AnSize.codeViewport))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('AnStatBar', () {
    testWidgets('leading credential renders BEFORE the status badge (批3: the bar subject leads)',
        (tester) async {
      await tester.pumpWidget(_host(const AnStatBar(
        leading: [AnChip('fn_1', mono: true)],
        status: AnStatus.done,
        stats: [AnStat('v4', tabular: true)],
      )));
      await tester.pump();
      final pillX = tester.getTopLeft(find.text('fn_1')).dx;
      final badgeX = tester.getTopLeft(find.text(Translations.of(tester.element(find.byType(AnStatBar))).status.done)).dx;
      expect(pillX, lessThan(badgeX));
    });

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

  group('AnSpinner 批7', () {
    testWidgets('spins live; freezes to the still glyph under assistive tech (orAssistive gate, B-054)',
        (tester) async {
      await tester.pumpWidget(_host(const AnSpinner()));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // accessibleNavigation ON → the DECORATIVE loop must freeze (a reduced-only gate misses this).
      // 读屏活跃→装饰循环必须冻结(只门 reduced 会漏)。
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: _host(const AnSpinner()),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(AnIcons.spin), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0); // truly zero frames 真零帧
    });
  });

  group('装饰循环 orAssistive 门 批7 复审', () {
    testWidgets('AnFollowPill live + AnRadarSweep freeze under assistive tech (立法3, mutation-locked)',
        (tester) async {
      // A reduced-only gate misses the screen-reader case — this pin goes red if either site
      // regresses to AnMotionPref.reduced. 只门 reduced 会漏读屏——回退即红。
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: _host(Column(children: [
          AnFollowPill(kind: AnFollowPillKind.live, subjectName: 'x', onTap: () {}),
          const AnRadarSweep(),
        ])),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0); // both loops frozen 双循环冻结
    });
  });

  group('AnFadeRiseIn 批7', () {
    testWidgets('animates entry once; renders static (no ticker) under reduced motion', (tester) async {
      await tester.pumpWidget(_host(const AnFadeRiseIn(child: Text('hi'))));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0)); // entry in flight 入场在飞
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1.0);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(const AnFadeRiseIn(key: Key('r'), child: Text('hi2'))),
      ));
      await tester.pump();
      expect(find.byType(Opacity), findsNothing); // static path 静态径
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('AnDropVeil 批7', () {
    testWidgets('veils at the token alpha and never intercepts the pointer', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(SizedBox(
        width: 200,
        height: 120,
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(onTap: () => taps++, behavior: HitTestBehavior.opaque),
          AnDropVeil(icon: AnIcons.attach, label: 'drop here'),
        ]),
      )));
      await tester.pump();
      expect(find.text('drop here'), findsOneWidget);
      final box = tester.widget<ColoredBox>(find.descendant(
          of: find.byType(AnDropVeil), matching: find.byType(ColoredBox)));
      expect(box.color.a, closeTo(AnOpacity.veil, 0.005)); // token alpha, not a private literal 走档
      await tester.tap(find.text('drop here'), warnIfMissed: false);
      expect(taps, 1); // IgnorePointer holds 指针穿透
    });
  });

  group('批7 铸档', () {
    test('AnIndent derives marker+gap; AnMenuSurface reports its own height', () {
      expect(AnIndent.dot, AnSize.dot + AnGap.inline);
      expect(AnIndent.icon, AnSize.icon + AnGap.inline);
      expect(AnMenuSurface.estHeight(3), 3 * AnSize.row + AnSpace.s4 * 2);
    });
    test('dangerLine exists in BOTH themes as a line-weight danger (镜像 accentLine)', () {
      // Read the extensions straight off the ThemeData — pumping two MaterialApps lerps the
      // extension across the theme transition and reads a mid-flight value. 直接读扩展,避开主题过渡 lerp。
      final light = AnTheme.light().extension<AnColors>()!;
      final dark = AnTheme.dark().extension<AnColors>()!;
      expect(light.dangerLine.a, closeTo(0.30, 0.005));
      expect(dark.dangerLine.a, closeTo(0.40, 0.005));
    });
  });
}
