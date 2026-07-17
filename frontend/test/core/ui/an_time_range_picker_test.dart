import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/time_range.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
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
    invalidError: '日期或时间无法解析',
    endBeforeStartError: '终点早于起点',
    weekdayLabels: const ['一', '二', '三', '四', '五', '六', '日'],
    monthTitle: (m) => '${m.year}-${m.month.toString().padLeft(2, '0')}',
    prevMonthLabel: '上个月',
    nextMonthLabel: '下个月',
    capsuleA11y: '时间范围',
  );

  Widget calendarHost({
    DateTime? start,
    DateTime? end,
    required void Function(DateTime) onPick,
    void Function(DateTime)? onMonth,
  }) {
    var month = DateTime(2026, 7, 1);
    return host(StatefulBuilder(
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
    ));
  }

  group('AnCalendar', () {
    testWidgets('fixed 6-row grid: leading + trailing out-month days render (42 cells)',
        (tester) async {
      await tester.pumpWidget(calendarHost(onPick: (_) {}));
      // Jul 2026 starts Wednesday → grid leads with Jun 29/30 and trails into August. 前导 6/29-30。
      expect(find.text('29'), findsNWidgets(2)); // Jun 29 + Jul 29
      expect(find.text('15'), findsOneWidget);
      // 42 cells = 6 rows × 7; every weekday header present. 恒 42 格。
      for (final w in ['一', '二', '三', '四', '五', '六', '日']) {
        expect(find.text(w), findsOneWidget);
      }
    });

    testWidgets('tapping a day reports it; chevrons walk months', (tester) async {
      final picked = <DateTime>[];
      final months = <DateTime>[];
      await tester.pumpWidget(calendarHost(onPick: picked.add, onMonth: months.add));

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

    testWidgets('keyboard: ONE grid stop, arrows walk days, Enter picks, PgDn drags the month',
        (tester) async {
      final picked = <DateTime>[];
      final months = <DateTime>[];
      await tester.pumpWidget(calendarHost(onPick: picked.add, onMonth: months.add));

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
      expect(months, [DateTime(2026, 8, 1)]); // cursor month-hop drags the visible month 光标拖月
    });

    testWidgets('day cells are NOT tab stops — the grid is ONE focus node (227-stop lesson)',
        (tester) async {
      await tester.pumpWidget(calendarHost(onPick: (_) {}));
      final scope = tester.binding.focusManager.rootScope;
      // Focusable descendants: the two chevron buttons + the one grid node. NOT 42 day cells.
      // 可聚焦后代:两个翻月钮 + 一个盘节点,绝非 42 个日格。
      final focusables = scope.traversalDescendants.where((n) => n.canRequestFocus).toList();
      // Chevron buttons contribute a handful of nodes; the load-bearing bound is that the count
      // does NOT scale with the 42 cells. 翻月钮贡献几个节点;承重界=计数不随 42 格走。
      expect(focusables.length, lessThan(10),
          reason: '日格若可聚焦,42 停靠会重演 AnScheduleTrack 227 停之鉴');
    });

    testWidgets('range endpoints carry selected semantics; plain days do not', (tester) async {
      await tester.pumpWidget(calendarHost(
          start: DateTime(2026, 7, 6), end: DateTime(2026, 7, 17), onPick: (_) {}));
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.bySemanticsLabel('2026-07-06')),
          isSemantics(isButton: true, isSelected: true, hasTapAction: true));
      expect(tester.getSemantics(find.bySemanticsLabel('2026-07-17')),
          isSemantics(isButton: true, isSelected: true));
      expect(tester.getSemantics(find.bySemanticsLabel('2026-07-10')),
          isSemantics(isButton: true, hasTapAction: true, isSelected: false));
      handle.dispose();
    });
  });

  group('AnTimeRangePicker', () {
    testWidgets('capsule shows the preset NAME; a preset click applies immediately and closes',
        (tester) async {
      final changes = <AnTimeRange>[];
      AnTimeRange value = const AnPresetRange(AnTimePreset.d7);
      await tester.pumpWidget(host(StatefulBuilder(
        builder: (context, setState) => AnTimeRangePicker(
          value: value,
          onChanged: (v) {
            changes.add(v);
            setState(() => value = v);
          },
          strings: strings,
        ),
      )));

      expect(find.text('近 7 天'), findsOneWidget);
      await tester.tap(find.byType(AnTimeRangePicker));
      await tester.pumpAndSettle();
      expect(find.text('自定义范围'), findsOneWidget); // panel open

      await tester.tap(find.text('今天'));
      await tester.pumpAndSettle();
      expect(changes, [const AnPresetRange(AnTimePreset.today)]);
      expect(find.text('自定义范围'), findsNothing); // closed
      expect(find.text('今天'), findsOneWidget); // echoed in the capsule
    });

    testWidgets(
        'absolute flow: calendar picks the dates, times survive, ONLY Apply commits — and the '
        'capsule echoes both instants', (tester) async {
      final changes = <AnTimeRange>[];
      AnTimeRange value =
          AnAbsoluteRange(from: DateTime(2026, 7, 6, 9, 0), to: DateTime(2026, 7, 17, 18, 0));
      await tester.pumpWidget(host(StatefulBuilder(
        builder: (context, setState) => AnTimeRangePicker(
          value: value,
          onChanged: (v) {
            changes.add(v);
            setState(() => value = v);
          },
          strings: strings,
        ),
      )));

      expect(find.textContaining('2026-07-06 09:00'), findsOneWidget);

      await tester.tap(find.byType(AnTimeRangePicker));
      await tester.pumpAndSettle();

      // First pick starts a new range, second (later) pick ends it. 首击起、次击收。
      await tester.tap(find.text('10'));
      await tester.pump();
      await tester.tap(find.text('20'));
      await tester.pump();
      expect(changes, isEmpty); // nothing hit the wire yet — Apply owns the commit 未应用不提交

      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(changes, [
        AnAbsoluteRange(from: DateTime(2026, 7, 10, 9, 0), to: DateTime(2026, 7, 20, 18, 0)),
      ]);
      expect(find.textContaining('2026-07-10 09:00'), findsOneWidget);
    });

    testWidgets('end before start: inline error, Apply refused, NEVER a silent swap',
        (tester) async {
      final changes = <AnTimeRange>[];
      await tester.pumpWidget(host(AnTimeRangePicker(
        value: AnAbsoluteRange(from: DateTime(2026, 7, 6, 9, 0), to: DateTime(2026, 7, 17, 18, 0)),
        onChanged: changes.add,
        strings: strings,
      )));

      await tester.tap(find.byType(AnTimeRangePicker));
      await tester.pumpAndSettle();

      // Hand-edit the END date to before the start. 手改终点到起点之前。
      await tester.enterText(find.byType(AnInput).at(2), '2026-07-01');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();

      expect(changes, isEmpty);
      expect(find.text('终点早于起点'), findsOneWidget);
      expect(find.text('自定义范围'), findsOneWidget); // still open 仍开着

      // Fixing the draft clears the error line immediately. 改好即灭。
      await tester.enterText(find.byType(AnInput).at(2), '2026-07-30');
      await tester.pump();
      expect(find.text('终点早于起点'), findsNothing);

      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(changes, [
        AnAbsoluteRange(from: DateTime(2026, 7, 6, 9, 0), to: DateTime(2026, 7, 30, 18, 0)),
      ]);
    });

    testWidgets('unparseable input: honest inline error, no commit', (tester) async {
      final changes = <AnTimeRange>[];
      await tester.pumpWidget(host(AnTimeRangePicker(
        value: AnAbsoluteRange(from: DateTime(2026, 7, 6, 9, 0), to: DateTime(2026, 7, 17, 18, 0)),
        onChanged: changes.add,
        strings: strings,
      )));
      await tester.tap(find.byType(AnTimeRangePicker));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AnInput).at(1), 'garbage');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.text('日期或时间无法解析'), findsOneWidget);
    });

    testWidgets('re-opening with a preset keeps its row highlighted (check mark) — the value '
        'stays an expression', (tester) async {
      await tester.pumpWidget(host(AnTimeRangePicker(
        value: const AnPresetRange(AnTimePreset.d30),
        onChanged: (_) {},
        strings: strings,
      )));
      await tester.tap(find.byType(AnTimeRangePicker));
      await tester.pumpAndSettle();
      // The d30 row carries the check icon. 近 30 天行带勾。
      final row = find.ancestor(of: find.text('近 30 天'), matching: find.byType(AnMenuRow));
      expect(find.descendant(of: row, matching: find.byIcon(AnIcons.check)), findsOneWidget);
    });
  });
}
