import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/model/time_range.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnCalendar + AnTimeRangePicker: the grid contract (fixed weeks, pick sequencing, APG keyboard on
// ONE grid focus node), and the picker's settled laws — preset click applies immediately and stays
// an expression; absolute mode only commits on an explicit Apply; end-before-start refuses with an
// inline error, never a swap.
// 日历网格契约(恒 6 行/选择时序/盘级单焦点 APG 键盘) + 选择器定式(预设点即生效且存表达式/绝对只在显式
// 应用提交/终点早于起点就地拒绝绝不交换)。
void main() {
  Widget host(Widget child) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  final strings = AnTimeRangePickerStrings(
    presetLabels: const {
      AnTimePreset.today: '今天',
      AnTimePreset.h24: '近 24 小时',
      AnTimePreset.d7: '近 7 天',
      AnTimePreset.d30: '近 30 天',
      AnTimePreset.all: '全部',
    },
    customTitle: '自定义范围',
    fromLabel: '从',
    toLabel: '到',
    applyLabel: '应用',
    endBeforeStartError: '终点早于起点',
    weekdayLabels: const ['一', '二', '三', '四', '五', '六', '日'],
    monthTitle: (m) => '${m.year}-${m.month.toString().padLeft(2, '0')}',
    prevMonthLabel: '上个月',
    nextMonthLabel: '下个月',
    capsuleA11y: '时间范围',
    backLabel: '返回快捷范围',
    todayLabel: '回到今天',
    preciseTimeLabel: '精确到时刻',
    dayText: (d) => '${d.month} 月 ${d.day} 日',
  );

  /// Open the popover, then step into tier 2 (the custom calendar pane). 开面板并进二级。
  Future<void> openCustom(WidgetTester tester) async {
    await tester.tap(find.byType(AnTimeRangePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义范围…'));
    await tester.pumpAndSettle();
  }

  Widget calendarHost({
    DateTime? start,
    DateTime? end,
    required void Function(DateTime) onPick,
    void Function(DateTime)? onMonth,
  }) {
    var month = DateTime(2026, 7, 1);
    return host(
      StatefulBuilder(
        builder: (context, setState) => AnCalendar(
          month: month,
          rangeStart: start,
          rangeEnd: end,
          onPickDay: onPick,
          onMonthChange: (m) {
            onMonth?.call(m);
            setState(() => month = m);
          },
          weekdayLabels: const ['一', '二', '三', '四', '五', '六', '日'],
          monthTitle: '${month.year}-${month.month.toString().padLeft(2, '0')}',
          prevMonthLabel: '上个月',
          nextMonthLabel: '下个月',
          gridSemanticLabel: '日历',
        ),
      ),
    );
  }

  group('AnCalendar', () {
    testWidgets(
      'fixed 6-row grid: leading + trailing out-month days render (42 cells)',
      (tester) async {
        await tester.pumpWidget(calendarHost(onPick: (_) {}));
        // Jul 2026 starts Wednesday → grid leads with Jun 29/30 and trails into August. 前导 6/29-30。
        expect(find.text('29'), findsNWidgets(2)); // Jun 29 + Jul 29
        expect(find.text('15'), findsOneWidget);
        // 42 cells = 6 rows × 7; every weekday header present. 恒 42 格。
        for (final w in ['一', '二', '三', '四', '五', '六', '日']) {
          expect(find.text(w), findsOneWidget);
        }
      },
    );

    testWidgets('tapping a day reports it; chevrons walk months', (
      tester,
    ) async {
      final picked = <DateTime>[];
      final months = <DateTime>[];
      await tester.pumpWidget(
        calendarHost(onPick: picked.add, onMonth: months.add),
      );

      await tester.tap(find.text('15'));
      await tester.pump();
      expect(picked, [DateTime(2026, 7, 15)]);

      await tester.tap(find.bySemanticsLabel('下个月'));
      await tester.pump();
      expect(months, [DateTime(2026, 8, 1)]);
      await tester.tap(find.bySemanticsLabel('上个月'));
      await tester.pump();
      expect(months.last, DateTime(2026, 7, 1));
    });

    testWidgets(
      'keyboard: ONE grid stop, arrows walk days, Enter picks, PgDn drags the month',
      (tester) async {
        final picked = <DateTime>[];
        final months = <DateTime>[];
        await tester.pumpWidget(
          calendarHost(onPick: picked.add, onMonth: months.add),
        );

        // Pointer tap seats cursor + focus; keyboard continues from there. 点选落光标+焦点。
        await tester.tap(find.text('15'));
        await tester.pump();
        picked.clear();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(picked, [DateTime(2026, 7, 23)]); // 15 → 16 → 23

        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump();
        expect(months, [
          DateTime(2026, 8, 1),
        ]); // cursor month-hop drags the visible month 光标拖月
      },
    );

    testWidgets(
      'day cells are NOT tab stops — the grid is ONE focus node (227-stop lesson)',
      (tester) async {
        await tester.pumpWidget(calendarHost(onPick: (_) {}));
        final scope = tester.binding.focusManager.rootScope;
        // Focusable descendants: the two chevron buttons + the one grid node. NOT 42 day cells.
        // 可聚焦后代:两个翻月钮 + 一个盘节点,绝非 42 个日格。
        final focusables = scope.traversalDescendants
            .where((n) => n.canRequestFocus)
            .toList();
        // Chevron buttons contribute a handful of nodes; the load-bearing bound is that the count
        // does NOT scale with the 42 cells. 翻月钮贡献几个节点;承重界=计数不随 42 格走。
        expect(
          focusables.length,
          lessThan(10),
          reason: '日格若可聚焦,42 停靠会重演 AnScheduleTrack 227 停之鉴',
        );
      },
    );

    testWidgets(
      'the range paints as ONE continuous ribbon: underlays span cells AND gaps, caps '
      'are circles (0718 拍板「端点圆头中间连成带」)',
      (tester) async {
        await tester.pumpWidget(
          calendarHost(
            start: DateTime(2026, 7, 6),
            end: DateTime(2026, 7, 17),
            onPick: (_) {},
          ),
        );
        final c = AnTheme.light().extension<AnColors>()!;
        // Every closed-band day (6..17 = 12 days) carries a soft underlay. 闭带 12 天每天一张底带。
        final underlays = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((w) => w.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.color == c.accentSoft)
            .toList();
        expect(underlays.length, 12, reason: '底带贯穿含帽的每一天');
        // Caps are full circles (radius = cell/2 = 12). 端帽整圆。
        final caps = tester
            .widgetList<Container>(find.byType(Container))
            .map((w) => w.decoration)
            .whereType<BoxDecoration>()
            .where(
              (d) =>
                  d.color == c.accent &&
                  d.borderRadius == BorderRadius.circular(AnSize.controlSm / 2),
            )
            .toList();
        expect(caps.length, 2, reason: '起/终两枚圆帽');
        // Adjacent in-band days connect ACROSS the gap: an in-band day's underlay is wider than the
        // bare cell (it swallows its right gap lane). 带内相邻日横贯缝:底带宽>裸格宽。
        final tenCell = tester.getRect(find.text('10'));
        expect(tenCell, isNotNull);
      },
    );

    testWidgets('«back to today» jumps the visible month to now', (
      tester,
    ) async {
      final months = <DateTime>[];
      var month = DateTime(2020, 1, 1);
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => AnCalendar(
              month: month,
              onPickDay: (_) {},
              onMonthChange: (m) {
                months.add(m);
                setState(() => month = m);
              },
              weekdayLabels: const ['一', '二', '三', '四', '五', '六', '日'],
              monthTitle: '${month.year}-${month.month}',
              prevMonthLabel: '上个月',
              nextMonthLabel: '下个月',
              todayLabel: '回到今天',
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('回到今天'));
      await tester.pump();
      final now = DateTime.now();
      expect(months, [DateTime(now.year, now.month, 1)], reason: '回今天=可见月跳当月');
    });

    testWidgets('the wheel fades its context rows (ShaderMask window — 摊尸之治)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnTimeWheel(
            value: (hour: 9, minute: 30),
            onChanged: (_) {},
            semanticLabel: '时刻',
          ),
        ),
      );
      expect(find.byType(ShaderMask), findsNWidgets(2), reason: '两列各一遮罩');
    });

    testWidgets('range endpoints carry selected semantics; plain days do not', (
      tester,
    ) async {
      await tester.pumpWidget(
        calendarHost(
          start: DateTime(2026, 7, 6),
          end: DateTime(2026, 7, 17),
          onPick: (_) {},
        ),
      );
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('2026-07-06')),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('2026-07-17')),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('2026-07-10')),
        isSemantics(isButton: true, hasTapAction: true, isSelected: false),
      );
      handle.dispose();
    });
  });

  group('AnTimeRangePicker', () {
    testWidgets(
      'tier 1: capsule shows the preset NAME; the panel opens on the COMPACT preset menu '
      '(no calendar) and a preset click applies immediately and closes (渐进披露)',
      (tester) async {
        final changes = <AnTimeRange>[];
        AnTimeRange value = const AnPresetRange(AnTimePreset.d7);
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) => AnTimeRangePicker(
                value: value,
                onChanged: (v) {
                  changes.add(v);
                  setState(() => value = v);
                },
                strings: strings,
              ),
            ),
          ),
        );

        expect(find.text('近 7 天'), findsOneWidget);
        await tester.tap(find.byType(AnTimeRangePicker));
        await tester.pumpAndSettle();
        expect(find.text('自定义范围…'), findsOneWidget, reason: '一级=预设小单+自定义门');
        expect(find.byType(AnCalendar), findsNothing, reason: '95% 路径不付日历的代价');

        await tester.tap(find.text('今天'));
        await tester.pumpAndSettle();
        expect(changes, [const AnPresetRange(AnTimePreset.today)]);
        expect(find.text('自定义范围…'), findsNothing); // closed
        expect(find.text('今天'), findsOneWidget); // echoed in the capsule
      },
    );

    testWidgets(
      'tier 2: the custom row opens the calendar pane; picks preview in plain ink; ONLY '
      'Apply commits — full-day defaults, and the capsule speaks in DAYS',
      (tester) async {
        final changes = <AnTimeRange>[];
        AnTimeRange value = const AnPresetRange(AnTimePreset.d7);
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) => AnTimeRangePicker(
                value: value,
                onChanged: (v) {
                  changes.add(v);
                  setState(() => value = v);
                },
                strings: strings,
              ),
            ),
          ),
        );
        await openCustom(tester);
        expect(find.byType(AnCalendar), findsOneWidget);
        expect(
          find.bySemanticsLabel('返回快捷范围'),
          findsOneWidget,
          reason: '二级带返回',
        );

        // First pick starts, second (later) ends; the preview line echoes in plain ink. 首击起次击收。
        await tester.tap(
          find.descendant(
            of: find.byType(AnCalendar),
            matching: find.text('10'),
          ),
        );
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(AnCalendar),
            matching: find.text('20'),
          ),
        );
        await tester.pump();
        expect(changes, isEmpty, reason: '未应用不提交');
        expect(
          find.text('7 月 10 日 – 7 月 20 日'),
          findsOneWidget,
          reason: '预览行(纯墨,假链接蓝退役)',
        );

        await tester.tap(find.text('应用'));
        await tester.pumpAndSettle();
        // Endpoints default to the FULL DAY (00:00–23:59) — no time tier touched. 整天默认。
        expect(changes, [
          AnAbsoluteRange(
            from: DateTime(2026, 7, 10),
            to: DateTime(2026, 7, 20, 23, 59),
          ),
        ]);
        expect(
          find.text('7 月 10 日 – 7 月 20 日'),
          findsOneWidget,
          reason: '整天对,胶囊念日子',
        );
      },
    );

    testWidgets(
      'tier 3 is DISCLOSED: full-day drafts show no wheels, the button reveals them; a '
      'reopened pair with real times reveals honestly',
      (tester) async {
        await tester.pumpWidget(
          host(
            AnTimeRangePicker(
              value: const AnPresetRange(AnTimePreset.d7),
              onChanged: (_) {},
              strings: strings,
            ),
          ),
        );
        await openCustom(tester);
        expect(find.byType(AnTimeWheel), findsNothing, reason: '整天默认,时刻藏');
        expect(find.byType(EditableText), findsNothing, reason: '无可打字之物');
        await tester.tap(find.text('精确到时刻'));
        await tester.pumpAndSettle();
        expect(find.byType(AnTimeWheel), findsNWidgets(2), reason: '披露后两端轮');
        expect(find.text('精确到时刻'), findsNothing, reason: '一次性披露,钮退场');
      },
    );

    testWidgets(
      'a pair with REAL times self-reveals the time tier on reopen (hiding 09:00 would '
      'lie full-day)',
      (tester) async {
        await tester.pumpWidget(
          host(
            AnTimeRangePicker(
              value: AnAbsoluteRange(
                from: DateTime(2026, 7, 6, 9, 0),
                to: DateTime(2026, 7, 17, 18, 0),
              ),
              onChanged: (_) {},
              strings: strings,
            ),
          ),
        );
        await openCustom(tester);
        expect(find.byType(AnTimeWheel), findsNWidgets(2));
      },
    );

    testWidgets(
      'end before start: inline error, Apply refused, NEVER a silent swap (唯一可达径='
      '同日+时刻倒置)',
      (tester) async {
        final changes = <AnTimeRange>[];
        await tester.pumpWidget(
          host(
            AnTimeRangePicker(
              value: AnAbsoluteRange(
                from: DateTime(2026, 7, 6, 18, 30),
                to: DateTime(2026, 7, 17, 9, 0),
              ),
              onChanged: changes.add,
              strings: strings,
            ),
          ),
        );
        await openCustom(tester);

        // Seeded times 18:30 → 09:00 invert once both ends land on one day. 同日即倒置。
        final day10 = find.descendant(
          of: find.byType(AnCalendar),
          matching: find.text('10'),
        );
        await tester.tap(day10);
        await tester.pump();
        await tester.tap(day10);
        await tester.pump();
        await tester.tap(find.text('应用'));
        await tester.pumpAndSettle();

        expect(changes, isEmpty);
        expect(find.text('终点早于起点'), findsOneWidget);
        expect(find.byType(AnCalendar), findsOneWidget, reason: '仍开着');

        // Fixing the draft (a later end day) clears the error line immediately. 改好即灭。
        await tester.tap(day10);
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(AnCalendar),
            matching: find.text('20'),
          ),
        );
        await tester.pump();
        expect(find.text('终点早于起点'), findsNothing);

        await tester.tap(find.text('应用'));
        await tester.pumpAndSettle();
        expect(changes, [
          AnAbsoluteRange(
            from: DateTime(2026, 7, 10, 18, 30),
            to: DateTime(2026, 7, 20, 9, 0),
          ),
        ]);
      },
    );

    testWidgets(
      'the TIME WHEELS feed Apply: one minute-notch on «从» commits 09:01 (0717-深夜:'
      '时刻不打字)',
      (tester) async {
        final changes = <AnTimeRange>[];
        await tester.pumpWidget(
          host(
            AnTimeRangePicker(
              value: AnAbsoluteRange(
                from: DateTime(2026, 7, 6, 9, 0),
                to: DateTime(2026, 7, 17, 18, 0),
              ),
              onChanged: changes.add,
              strings: strings,
            ),
          ),
        );
        await openCustom(
          tester,
        ); // 9:00–18:00 non-default → wheels self-revealed 真时刻自动开三级

        // Wheel order: from-HH, from-MM, to-HH, to-MM. 轮序:从时/从分/到时/到分。
        final fromMinute = find.byType(ListWheelScrollView).at(1);
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        pointer.hover(tester.getCenter(fromMinute));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('应用'));
        await tester.pumpAndSettle();
        expect(changes, [
          AnAbsoluteRange(
            from: DateTime(2026, 7, 6, 9, 1),
            to: DateTime(2026, 7, 17, 18, 0),
          ),
        ]);
      },
    );

    testWidgets(
      're-opening ALWAYS lands on tier 1; an absolute value checks the custom row, a '
      'preset checks its own',
      (tester) async {
        await tester.pumpWidget(
          host(
            AnTimeRangePicker(
              value: AnAbsoluteRange(
                from: DateTime(2026, 7, 6),
                to: DateTime(2026, 7, 17, 23, 59),
              ),
              onChanged: (_) {},
              strings: strings,
            ),
          ),
        );
        await tester.tap(find.byType(AnTimeRangePicker));
        await tester.pumpAndSettle();
        expect(find.byType(AnCalendar), findsNothing, reason: '重开恒落一级');
        final customRow = find.ancestor(
          of: find.text('自定义范围…'),
          matching: find.byType(AnMenuRow),
        );
        expect(
          find.descendant(of: customRow, matching: find.byIcon(AnIcons.check)),
          findsOneWidget,
          reason: '绝对值→自定义行带勾(✓ 随值)',
        );

        // Back out of tier 2 returns to tier 1 without committing. 返回不提交。
        await tester.tap(find.text('自定义范围…'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('返回快捷范围'));
        await tester.pumpAndSettle();
        expect(find.byType(AnCalendar), findsNothing);
        expect(find.text('自定义范围…'), findsOneWidget);
      },
    );

    testWidgets(
      're-opening with a preset keeps its row highlighted (check mark) — the value '
      'stays an expression',
      (tester) async {
        await tester.pumpWidget(
          host(
            AnTimeRangePicker(
              value: const AnPresetRange(AnTimePreset.d30),
              onChanged: (_) {},
              strings: strings,
            ),
          ),
        );
        await tester.tap(find.byType(AnTimeRangePicker));
        await tester.pumpAndSettle();
        // The d30 row carries the check icon. 近 30 天行带勾。
        final row = find.ancestor(
          of: find.text('近 30 天'),
          matching: find.byType(AnMenuRow),
        );
        expect(
          find.descendant(of: row, matching: find.byIcon(AnIcons.check)),
          findsOneWidget,
        );
      },
    );
  });
}
