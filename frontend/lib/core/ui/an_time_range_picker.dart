import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/time_format.dart';
import '../model/time_range.dart';
import 'an_button.dart';
import 'an_calendar.dart';
import 'an_input.dart';
import 'an_interactive.dart';
import 'an_menu_surface.dart';
import 'an_pop_surface.dart';
import 'an_popover.dart';
import 'icons.dart';

/// The Grafana-family time-range control (WRK-069 主页重建拍板 0717): ONE capsule governs every
/// time-scoped zone on its page. The popover is the settled two-pane shape — quick presets on the
/// left (click = apply IMMEDIATELY and close; they stay LIVE, re-resolved at every fetch), the
/// absolute form on the right (date+time for BOTH endpoints, an [AnCalendar] range grid, and an
/// explicit Apply — absolute mode NEVER live-applies, half-filled pairs must not hit the wire).
/// End-before-start is an inline error and a refused Apply, never a silent swap. Re-opening with a
/// preset active keeps the preset highlighted while the form shows the currently-resolved instants
/// as a starting point (the preset itself is stored as an expression — freezing it is EUI #4026).
/// The capsule is faithful to intent: a preset shows its NAME, an absolute pair shows both instants.
///
/// Body chrome is [AnPopSurface] directly — NOT [AnMenuSurface], which is list chrome (scroll +
/// row-pill inset) and has no business wrapping a two-pane form. Zero copy in core: every string
/// arrives via [AnTimeRangePickerStrings].
///
/// Grafana 族时间范围控件（0717 拍板）：一颗胶囊治全页。弹层=定式双面板——左快捷预设（点即生效收起；
/// 预设是**活**的，每次取数现解析）、右绝对表单（起终点各带日期+时间、AnCalendar 范围网格、显式应用——
/// 绝对模式绝不 live-apply，半填的两端不许上线缆）。终点早于起点=就地报错+拒绝应用，绝不偷偷交换。带着
/// 预设重开：预设保持高亮、表单显示当下解析出的时刻作起点（预设按表达式存——冻结它是 EUI #4026）。胶囊
/// 忠于意图：预设显名、绝对显两端。壳直接用 AnPopSurface（AnMenuSurface 是列表壳，管不着双面板表单）。
/// core 零文案：字符串全经 AnTimeRangePickerStrings 进。
class AnTimeRangePickerStrings {
  const AnTimeRangePickerStrings({
    required this.presetLabels,
    required this.customTitle,
    required this.fromLabel,
    required this.toLabel,
    required this.applyLabel,
    required this.invalidError,
    required this.endBeforeStartError,
    required this.weekdayLabels,
    required this.monthTitle,
    required this.prevMonthLabel,
    required this.nextMonthLabel,
    required this.capsuleA11y,
    this.daySemanticLabel,
    this.gridSemanticLabel = '',
  });

  /// One label per preset — a missing key hides that row (a caller may offer a subset).
  /// 逐预设标签——缺键即藏行（调用方可只供子集）。
  final Map<AnTimePreset, String> presetLabels;
  final String customTitle;
  final String fromLabel;
  final String toLabel;
  final String applyLabel;

  /// A date/time field that parses under no known format. 任何格式都解析不了。
  final String invalidError;
  final String endBeforeStartError;

  /// 7 labels, Monday first. 周一起手 7 标签。
  final List<String> weekdayLabels;
  final String Function(DateTime month) monthTitle;
  final String prevMonthLabel;
  final String nextMonthLabel;

  /// Trigger capsule screen-reader label. 胶囊读屏标签。
  final String capsuleA11y;
  final String Function(DateTime day)? daySemanticLabel;
  final String gridSemanticLabel;
}

class AnTimeRangePicker extends StatefulWidget {
  const AnTimeRangePicker({
    required this.value,
    required this.onChanged,
    required this.strings,
    this.enabled = true,
    super.key,
  });

  final AnTimeRange value;
  final ValueChanged<AnTimeRange> onChanged;
  final AnTimeRangePickerStrings strings;
  final bool enabled;

  @override
  State<AnTimeRangePicker> createState() => _AnTimeRangePickerState();
}

class _AnTimeRangePickerState extends State<AnTimeRangePicker> {
  final AnPopoverController _popover = AnPopoverController();

  final TextEditingController _fromDate = TextEditingController();
  final TextEditingController _fromTime = TextEditingController();
  final TextEditingController _toDate = TextEditingController();
  final TextEditingController _toTime = TextEditingController();

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// Calendar pick sequencing: false → next pick starts a new range, true → next pick ≥ start ends
  /// it (an earlier day restarts instead — never a swap). 日历时序：下一击开新范围/收终点。
  bool _awaitingEnd = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _popover.addListener(_onPopover);
  }

  @override
  void dispose() {
    _popover.removeListener(_onPopover);
    _popover.dispose();
    _fromDate.dispose();
    _fromTime.dispose();
    _toDate.dispose();
    _toTime.dispose();
    super.dispose();
  }

  void _onPopover() {
    if (_popover.isOpen) _seedDraft();
    setState(() {});
  }

  /// Seed the absolute form from the CURRENT value: an absolute pair verbatim; a live preset as its
  /// currently-resolved instants (a starting point for tweaking — the stored value stays the
  /// expression). 开层落种：绝对逐字、预设按当下解析出的时刻（供微调起点，存的仍是表达式）。
  void _seedDraft() {
    final now = DateTime.now();
    DateTime from;
    DateTime to;
    switch (widget.value) {
      case AnAbsoluteRange(from: final f, to: final t):
        from = f;
        to = t;
      case AnPresetRange():
        final r = resolveTimeRange(widget.value, now);
        from = r.from ?? DateTime(now.year, now.month, now.day - 7);
        to = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    }
    _fromDate.text = _dateText(from);
    _fromTime.text = _timeText(from);
    _toDate.text = _dateText(to);
    _toTime.text = _timeText(to);
    _month = DateTime(to.year, to.month, 1);
    _awaitingEnd = false;
    _error = null;
  }

  static String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _timeText(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String get _capsuleLabel {
    switch (widget.value) {
      case AnPresetRange(:final preset):
        return widget.strings.presetLabels[preset] ?? '';
      case AnAbsoluteRange(:final from, :final to):
        return '${fmtDateTime(from)} – ${fmtDateTime(to)}';
    }
  }

  void _pickPreset(AnTimePreset p) {
    _popover.close();
    widget.onChanged(AnPresetRange(p));
  }

  /// The calendar reports a day; sequencing lives here (first = start, later = end, earlier =
  /// restart). Dates land in the form fields — Apply still owns the commit.
  /// 日历只报日子；时序在此。日期落表单字段——提交仍归应用钮。
  void _pickDay(DateTime day) {
    final start = parseDateInput(_fromDate.text);
    if (!_awaitingEnd || start == null || day.isBefore(start)) {
      _fromDate.text = _dateText(day);
      _toDate.text = _dateText(day);
      _awaitingEnd = true;
    } else {
      _toDate.text = _dateText(day);
      _awaitingEnd = false;
    }
    _revalidateIfErrored();
    setState(() {});
  }

  ({DateTime from, DateTime to})? _parseDraft() {
    final fd = parseDateInput(_fromDate.text);
    final ft = parseTimeInput(_fromTime.text);
    final td = parseDateInput(_toDate.text);
    final tt = parseTimeInput(_toTime.text);
    if (fd == null || ft == null || td == null || tt == null) return null;
    return (
      from: DateTime(fd.year, fd.month, fd.day, ft.hour, ft.minute),
      to: DateTime(td.year, td.month, td.day, tt.hour, tt.minute),
    );
  }

  void _apply() {
    final draft = _parseDraft();
    if (draft == null) {
      setState(() => _error = widget.strings.invalidError);
      return;
    }
    if (draft.to.isBefore(draft.from)) {
      // Refuse + say it — never a silent swap. 拒绝并明说——绝不偷偷交换。
      setState(() => _error = widget.strings.endBeforeStartError);
      return;
    }
    _popover.close();
    widget.onChanged(AnAbsoluteRange(from: draft.from, to: draft.to));
  }

  /// Errors are judged at Apply, never mid-keystroke — but once shown, any edit that FIXES the
  /// draft clears the line immediately. 错误只在应用时判；一旦亮起，改好即灭。
  void _revalidateIfErrored() {
    if (_error == null) return;
    final draft = _parseDraft();
    if (draft != null && !draft.to.isBefore(draft.from)) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.enabled;

    final trigger = AnInteractive(
      enabled: enabled,
      onTap: _popover.toggle,
      builder: (context, states) {
        final active = _popover.isOpen || states.isActive;
        final feedback = AnMotionPref.reduced(context) ? Duration.zero : AnMotion.fast;
        return AnimatedContainer(
          duration: feedback,
          height: AnSize.controlSm,
          padding: const EdgeInsets.symmetric(horizontal: AnSize.btnPadXSm),
          decoration: BoxDecoration(
            color: c.surfaceHover.whenActive(active),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AnIcons.calendarRange, size: AnSize.iconSm, color: c.inkFaint),
              const SizedBox(width: AnSpace.s6),
              Flexible(
                child: Text(
                  _capsuleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: active ? c.ink : c.inkMuted),
                ),
              ),
              const SizedBox(width: AnSpace.s6),
              AnimatedRotation(
                duration: feedback,
                turns: _popover.isOpen ? 0.5 : 0,
                child: Icon(AnIcons.chevronDown, size: AnSize.iconSm, color: c.inkFaint),
              ),
            ],
          ),
        );
      },
    );

    return Opacity(
      opacity: enabled ? 1 : AnOpacity.disabled,
      child: AnPopover(
        controller: _popover,
        alignEnd: false,
        overlayBuilder: (context, _) => _panel(context),
        anchor: Semantics(label: widget.strings.capsuleA11y, child: trigger),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final c = context.colors;
    final presets = [
      for (final p in AnTimePreset.values)
        if (widget.strings.presetLabels.containsKey(p)) p,
    ];
    final current = widget.value;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: AnPopSurface(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AnRadius.chip),
          child: SingleChildScrollView(
            child: FocusTraversalGroup(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── quick presets (click = apply now) 快捷预设 ──
                  Padding(
                    padding: const EdgeInsets.all(AnSpace.s4),
                    child: SizedBox(
                      width: 132,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final p in presets)
                            AnMenuRow(
                              onTap: () => _pickPreset(p),
                              autofocus: current == AnPresetRange(p),
                              builder: (context, active) {
                                final selected = current == AnPresetRange(p);
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.strings.presetLabels[p]!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AnText.body.copyWith(
                                            color: active || selected ? c.ink : c.inkMuted),
                                      ),
                                    ),
                                    if (selected)
                                      Icon(AnIcons.check, size: AnSize.iconSm, color: c.accent),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  // ── absolute pane (explicit Apply); its left border IS the divider —
                  // IntrinsicHeight is off the table (AnInput carries a LayoutBuilder, which cannot
                  // answer intrinsics), a border stretches for free. 左边框即分隔线。
                  Container(
                    decoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(color: c.line, width: AnSize.hairline))),
                    padding: const EdgeInsets.all(AnSpace.s12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.strings.customTitle,
                            style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
                        const SizedBox(height: AnSpace.s8),
                        _endpointRow(context, widget.strings.fromLabel, _fromDate, _fromTime),
                        const SizedBox(height: AnSpace.s6),
                        _endpointRow(context, widget.strings.toLabel, _toDate, _toTime),
                        const SizedBox(height: AnSpace.s8),
                        AnCalendar(
                          month: _month,
                          rangeStart: parseDateInput(_fromDate.text),
                          rangeEnd: _awaitingEnd ? null : parseDateInput(_toDate.text),
                          onPickDay: _pickDay,
                          onMonthChange: (m) => setState(() => _month = m),
                          weekdayLabels: widget.strings.weekdayLabels,
                          monthTitle: widget.strings.monthTitle(_month),
                          prevMonthLabel: widget.strings.prevMonthLabel,
                          nextMonthLabel: widget.strings.nextMonthLabel,
                          daySemanticLabel: widget.strings.daySemanticLabel,
                          gridSemanticLabel: widget.strings.gridSemanticLabel,
                        ),
                        const SizedBox(height: AnSpace.s8),
                        if (_error != null) ...[
                          Text(_error!, style: AnText.label.copyWith(color: c.danger)),
                          const SizedBox(height: AnSpace.s8),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: AnButton(
                            label: widget.strings.applyLabel,
                            size: AnButtonSize.sm,
                            variant: AnButtonVariant.primary,
                            onPressed: _apply,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _endpointRow(
      BuildContext context, String label, TextEditingController date, TextEditingController time) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          child: Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
        SizedBox(
          width: 104,
          child: AnInput(
            controller: date,
            tabular: true,
            onChanged: (_) {
              _awaitingEnd = false; // hand-edited dates end the calendar's pick sequence 手改即收时序
              _revalidateIfErrored();
              setState(() {});
            },
            onSubmitted: (_) => _apply(),
          ),
        ),
        const SizedBox(width: AnSpace.s6),
        SizedBox(
          width: 64,
          child: AnInput(
            controller: time,
            tabular: true,
            onChanged: (_) {
              _revalidateIfErrored();
              setState(() {});
            },
            onSubmitted: (_) => _apply(),
          ),
        ),
      ],
    );
  }
}
