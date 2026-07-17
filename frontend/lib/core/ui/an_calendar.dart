import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/time_range.dart';
import 'an_a11y.dart';
import 'an_button.dart';
import 'icons.dart';

/// A fixed 6-row Monday-first month grid with RANGE selection — the calendar half of
/// [AnTimeRangePicker] (WRK-069 主页重建拍板 0717). 42 cells always ([monthGridDays]): constant
/// height across months so the popover's Apply button never jumps under the pointer (the DayPicker
/// `fixedWeeks` convention). Range visuals are the settled three states — start cap / in-range band
/// / end cap — plus the hover PREVIEW band while an end is still pending (start picked, hovering a
/// later day sweeps the band live). Pick sequencing (first = start, second ≥ start = end, earlier =
/// restart) belongs to the OWNER via [onPickDay] — the grid only reports the day.
///
/// Keyboard = the WAI-ARIA APG date-grid pattern on a ROVING cursor: the whole grid is ONE Tab stop
/// (42 stops would be the AnScheduleTrack 227-stop lesson all over), ←→ ±1 day, ↑↓ ±7, PgUp/PgDn
/// month (the grid follows the cursor across month edges via [onMonthChange]), Home/End week bounds,
/// Enter/Space picks. Focus never leaves the grid node, so cursor moves are announced via
/// [AnA11y.announce] (polite) — the focused-node mechanism has nothing to fire.
///
/// Zero copy in core: weekday/month labels and a11y sentences arrive as params.
///
/// 恒 6 行周一起手的月网格 + 范围选择——AnTimeRangePicker 的日历半边。42 格恒定（跨月不跳高，弹层应用钮
/// 不挪位）。范围三态视觉（起帽/带身/终帽）+ 终点未定时的 hover 预览带。**选择时序归宿主**（onPickDay
/// 只报日子）。键盘=APG 日期网格·roving 光标：整盘一个 Tab 停靠，←→ ±1 天、↑↓ ±7、PgUp/PgDn 翻月（光标
/// 越界经 onMonthChange 跟随）、Home/End 周首尾、Enter/Space 选。焦点不动，光标移动经 AnA11y.announce
/// 播报。core 零文案：星期/月份标签与 a11y 句子全由参数进。
class AnCalendar extends StatefulWidget {
  const AnCalendar({
    required this.month,
    required this.onPickDay,
    required this.onMonthChange,
    required this.weekdayLabels,
    required this.monthTitle,
    required this.prevMonthLabel,
    required this.nextMonthLabel,
    this.rangeStart,
    this.rangeEnd,
    this.daySemanticLabel,
    this.gridSemanticLabel = '',
    super.key,
  });

  /// Any day inside the visible month. 可见月内任一天。
  final DateTime month;

  /// The picked range's DATE endpoints (time-of-day ignored). 已选范围的日期端点（忽略时刻）。
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  final ValueChanged<DateTime> onPickDay;

  /// Chevrons / PgUp / PgDn / cursor walking off the visible month. 翻月（按钮/键盘/光标越界）。
  final ValueChanged<DateTime> onMonthChange;

  /// 7 labels, Monday first. 周一起手的 7 个标签。
  final List<String> weekdayLabels;

  /// Caller-formatted visible-month title (e.g. `2026-07`). 调用方格式化的月标题。
  final String monthTitle;

  final String prevMonthLabel;
  final String nextMonthLabel;

  /// Screen-reader sentence for one day cell; falls back to `YYYY-MM-DD`. 逐日读屏句。
  final String Function(DateTime day)? daySemanticLabel;

  /// Container summary for the grid. 网格容器摘要。
  final String gridSemanticLabel;

  @override
  State<AnCalendar> createState() => _AnCalendarState();
}

class _AnCalendarState extends State<AnCalendar> {
  static const double _cell = AnSize.controlSm; // 24 — matrix-cell scale 格尺同矩阵
  static const double _gap = AnSpace.s4;

  final FocusNode _focus = FocusNode(debugLabel: 'AnCalendar grid');

  /// The roving keyboard cursor. Seeded lazily on first focus/arrow: range start, else today when
  /// visible, else the 1st of the visible month. roving 光标；首次聚焦/方向键时落种。
  DateTime? _cursor;

  /// Hovered day — drives the pending-end preview band. hover 天，喂终点未定的预览带。
  DateTime? _hover;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  DateTime get _seed {
    final start = widget.rangeStart;
    if (start != null) return dateOnly(start);
    final now = DateTime.now();
    if (now.year == widget.month.year && now.month == widget.month.month) return dateOnly(now);
    return DateTime(widget.month.year, widget.month.month, 1);
  }

  void _moveCursor(DateTime next) {
    setState(() => _cursor = next);
    // Cursor stepping outside the visible month drags the month along — APG behaviour. 光标越界拖着月走。
    if (next.year != widget.month.year || next.month != widget.month.month) {
      widget.onMonthChange(DateTime(next.year, next.month, 1));
    }
    AnA11y.announce(context, widget.daySemanticLabel?.call(next) ?? _iso(next));
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final cur = _cursor ?? _seed;
    final key = event.logicalKey;
    DateTime? next;
    if (key == LogicalKeyboardKey.arrowLeft) {
      next = DateTime(cur.year, cur.month, cur.day - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      next = DateTime(cur.year, cur.month, cur.day + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      next = DateTime(cur.year, cur.month, cur.day - 7);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      next = DateTime(cur.year, cur.month, cur.day + 7);
    } else if (key == LogicalKeyboardKey.pageUp) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      next = _clampDay(DateTime(cur.year - (shift ? 1 : 0), cur.month - (shift ? 0 : 1), 1), cur.day);
    } else if (key == LogicalKeyboardKey.pageDown) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      next = _clampDay(DateTime(cur.year + (shift ? 1 : 0), cur.month + (shift ? 0 : 1), 1), cur.day);
    } else if (key == LogicalKeyboardKey.home) {
      next = DateTime(cur.year, cur.month, cur.day - ((cur.weekday - DateTime.monday + 7) % 7));
    } else if (key == LogicalKeyboardKey.end) {
      next = DateTime(cur.year, cur.month, cur.day + ((DateTime.sunday - cur.weekday + 7) % 7));
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      widget.onPickDay(cur);
      return KeyEventResult.handled;
    }
    if (next == null) return KeyEventResult.ignored;
    _moveCursor(next);
    return KeyEventResult.handled;
  }

  /// Same-day-of-month in another month, clamped to that month's length (the "Jan 31 → Feb 28"
  /// convention — constructor normalization alone would silently overflow into March).
  /// 另一月的同日，钳到该月长度（1-31 → 2-28；裸构造器会静默溢进 3 月）。
  static DateTime _clampDay(DateTime firstOfMonth, int day) {
    final max = daysInMonth(firstOfMonth);
    return DateTime(firstOfMonth.year, firstOfMonth.month, day > max ? max : day);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = monthGridDays(widget.month);
    final start = widget.rangeStart == null ? null : dateOnly(widget.rangeStart!);
    final end = widget.rangeEnd == null ? null : dateOnly(widget.rangeEnd!);
    // Pending-end preview: start picked, end not — hovering a day ≥ start sweeps the band live.
    // 终点未定预览：hover ≥ 起点即扫出带子。
    final previewEnd = (start != null && end == null && _hover != null && !_hover!.isBefore(start))
        ? _hover
        : null;
    final bandEnd = end ?? previewEnd;

    final width = 7 * _cell + 6 * _gap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header: title + chevrons. 月头：标题 + 翻月钮。
        SizedBox(
          width: width,
          child: Row(
            children: [
              Expanded(
                child: Text(widget.monthTitle,
                    style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
              ),
              AnButton.iconOnly(AnIcons.chevronLeft,
                  size: AnButtonSize.sm,
                  semanticLabel: widget.prevMonthLabel,
                  onPressed: () => widget.onMonthChange(addMonths(widget.month, -1))),
              const SizedBox(width: AnSpace.s4),
              AnButton.iconOnly(AnIcons.chevronRight,
                  size: AnButtonSize.sm,
                  semanticLabel: widget.nextMonthLabel,
                  onPressed: () => widget.onMonthChange(addMonths(widget.month, 1))),
            ],
          ),
        ),
        const SizedBox(height: AnSpace.s6),
        // Weekday header. 星期头。
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              SizedBox(
                width: _cell,
                child: Center(
                  child: Text(widget.weekdayLabels.length == 7 ? widget.weekdayLabels[i] : '',
                      style: AnText.meta.copyWith(color: c.inkFaint)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AnSpace.s4),
        // The grid — ONE focus node, roving cursor. 网格——单焦点、roving 光标。
        Semantics(
          label: widget.gridSemanticLabel.isEmpty ? null : widget.gridSemanticLabel,
          container: true,
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _onKey,
            child: ListenableBuilder(
              listenable: _focus,
              builder: (context, _) {
                final focused = _focus.hasFocus;
                final cursor = _cursor ?? _seed;
                return MouseRegion(
                  onExit: (_) => setState(() => _hover = null),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var r = 0; r < 6; r++)
                        Padding(
                          padding: EdgeInsets.only(top: r == 0 ? 0 : _gap),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var col = 0; col < 7; col++) ...[
                                if (col > 0) const SizedBox(width: _gap),
                                _day(context, days[r * 7 + col], start, end, bandEnd,
                                    focused && isSameDay(days[r * 7 + col], cursor)),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _day(BuildContext context, DateTime day, DateTime? start, DateTime? end,
      DateTime? bandEnd, bool isCursor) {
    final c = context.colors;
    final inMonth = day.month == widget.month.month;
    final isStart = start != null && isSameDay(day, start);
    final isEnd = end != null && isSameDay(day, end);
    final inBand = start != null &&
        bandEnd != null &&
        day.isAfter(start) &&
        day.isBefore(bandEnd) &&
        !isStart &&
        !isEnd;
    final isCap = isStart || isEnd || (bandEnd != null && isSameDay(day, bandEnd));

    final Color bg;
    final Color fg;
    if (isCap) {
      bg = c.accent;
      fg = c.surface;
    } else if (inBand) {
      bg = c.accentSoft;
      fg = inMonth ? c.ink : c.inkFaint;
    } else {
      bg = const Color(0x00000000);
      fg = inMonth ? c.inkMuted : c.inkFaint;
    }

    // Cells are DELIBERATELY not focus stops: 42 Tab stops per month is the AnScheduleTrack
    // 227-stop lesson. Pointer taps land here; the keyboard rides the ONE grid node's roving
    // cursor; screen readers get a per-day button node with an explicit tap action.
    // 日格**刻意**不做焦点停靠(42 停/月=AnScheduleTrack 227 停之鉴):指针点这里,键盘走盘级单节点
    // roving 光标,读屏每天一个带显式 tap 的按钮节点。
    void pick() {
      _focus.requestFocus();
      setState(() => _cursor = day);
      widget.onPickDay(day);
    }

    final hovered = _hover != null && isSameDay(_hover!, day);
    return Semantics(
      label: widget.daySemanticLabel?.call(day) ?? _iso(day),
      button: true,
      selected: AnA11y.selected(isStart || isEnd),
      onTap: pick,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = day),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: pick,
          child: Container(
            width: _cell,
            height: _cell,
            decoration: BoxDecoration(
              color: !isCap && !inBand && hovered ? c.surfaceHover : bg,
              borderRadius: BorderRadius.circular(AnRadius.tag),
              border: isCursor ? Border.all(color: c.accent, width: AnSize.ring) : null,
            ),
            child: Center(
              child: Text('${day.day}',
                  style: AnText.metaTabular()
                      .copyWith(color: isCap ? fg : (hovered ? c.ink : fg))),
            ),
          ),
        ),
      ),
    );
  }
}
