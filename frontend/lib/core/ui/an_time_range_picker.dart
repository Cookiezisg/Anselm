import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/time_format.dart';
import '../model/time_range.dart';
import 'an_button.dart';
import 'an_calendar.dart';
import 'an_interactive.dart';
import 'an_menu_surface.dart';
import 'an_pop_surface.dart';
import 'an_popover.dart';
import 'an_time_wheel.dart';
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

  // Endpoint DATES are calendar picks and TIMES are wheel values (用户 0718 拍板:三列布局——预设 |
  // 日历只管日期 | 起/终时刻滚轮) — nothing is typed, so every draft is valid by construction and the
  // only judgeable error left is end-before-start. 端点日期归日历、时刻归滚轮——无可打字之物,草稿构造
  // 即合法,唯一可判错误只剩「终点早于起点」。
  DateTime _fromDay = dateOnly(DateTime.now());
  DateTime _toDay = dateOnly(DateTime.now());
  AnWheelTime _fromTod = (hour: 0, minute: 0);
  AnWheelTime _toTod = (hour: 0, minute: 0);

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
    _fromDay = dateOnly(from);
    _fromTod = (hour: from.hour, minute: from.minute);
    _toDay = dateOnly(to);
    _toTod = (hour: to.hour, minute: to.minute);
    _month = DateTime(to.year, to.month, 1);
    _awaitingEnd = false;
    _error = null;
  }

  static String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
  /// restart). Apply still owns the commit. 日历只报日子；时序在此；提交仍归应用钮。
  void _pickDay(DateTime day) {
    if (!_awaitingEnd || day.isBefore(_fromDay)) {
      _fromDay = dateOnly(day);
      _toDay = dateOnly(day);
      _awaitingEnd = true;
    } else {
      _toDay = dateOnly(day);
      _awaitingEnd = false;
    }
    _revalidateIfErrored();
    setState(() {});
  }

  /// An endpoint echo tap ARMS that end (用户拍板:回显可点=聚焦日历对应端): the calendar's next pick
  /// writes it, and the visible month jumps to where that end lives.
  /// 回显点击=上膛该端:日历下一击写它,可见月跳到该端所在月。
  void _armEnd(bool end) {
    setState(() {
      _awaitingEnd = end;
      final d = end ? _toDay : _fromDay;
      _month = DateTime(d.year, d.month, 1);
    });
  }

  ({DateTime from, DateTime to}) get _draft => (
        from: DateTime(
            _fromDay.year, _fromDay.month, _fromDay.day, _fromTod.hour, _fromTod.minute),
        to: DateTime(_toDay.year, _toDay.month, _toDay.day, _toTod.hour, _toTod.minute),
      );

  void _apply() {
    final draft = _draft;
    if (draft.to.isBefore(draft.from)) {
      // Refuse + say it — never a silent swap. 拒绝并明说——绝不偷偷交换。
      setState(() => _error = widget.strings.endBeforeStartError);
      return;
    }
    _popover.close();
    widget.onChanged(AnAbsoluteRange(from: draft.from, to: draft.to));
  }

  /// The error is judged at Apply only — but once shown, any pick that FIXES the draft clears the
  /// line immediately. 错误只在应用时判；一旦亮起，改好即灭。
  void _revalidateIfErrored() {
    if (_error == null) return;
    if (!_draft.to.isBefore(_draft.from)) setState(() => _error = null);
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
                  // ── column 2: the calendar — DATES live here, nowhere else (用户 0718 三列拍板).
                  // Left border = the divider (a border stretches for free). 第二列:日历,日期只归它;左边框即分隔线。
                  Container(
                    decoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(color: c.line, width: AnSize.hairline))),
                    padding: const EdgeInsets.all(AnSpace.s12),
                    child: AnCalendar(
                      month: _month,
                      rangeStart: _fromDay,
                      rangeEnd: _awaitingEnd ? null : _toDay,
                      onPickDay: _pickDay,
                      onMonthChange: (m) => setState(() => _month = m),
                      weekdayLabels: widget.strings.weekdayLabels,
                      monthTitle: widget.strings.monthTitle(_month),
                      prevMonthLabel: widget.strings.prevMonthLabel,
                      nextMonthLabel: widget.strings.nextMonthLabel,
                      daySemanticLabel: widget.strings.daySemanticLabel,
                      gridSemanticLabel: widget.strings.gridSemanticLabel,
                    ),
                  ),
                  // ── column 3: the endpoints — date ECHOES (tap = arm that end on the calendar)
                  // + HH:MM wheels + the explicit Apply. 第三列:端点——日期回显(点=日历上膛该端)+时刻滚轮+应用。
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
                        _endpoint(context, widget.strings.fromLabel, _fromDay,
                            armed: !_awaitingEnd,
                            onArm: () => _armEnd(false),
                            tod: _fromTod,
                            onTod: (v) => setState(() {
                                  _fromTod = v;
                                  _revalidateIfErrored();
                                })),
                        const SizedBox(height: AnSpace.s8),
                        _endpoint(context, widget.strings.toLabel, _toDay,
                            armed: _awaitingEnd,
                            onArm: () => _armEnd(true),
                            tod: _toTod,
                            onTod: (v) => setState(() {
                                  _toTod = v;
                                  _revalidateIfErrored();
                                })),
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

  /// One endpoint block: [label + date echo] over its HH:MM wheel. The echo is not an input — it
  /// REPORTS the calendar's pick and, tapped, ARMS its end (accent = the end the next calendar tap
  /// writes). 端点块:标签+日期回显(非输入——回报日历所选;点=上膛,accent=日历下一击写谁)+时刻滚轮。
  Widget _endpoint(BuildContext context, String label, DateTime day,
      {required bool armed,
      required VoidCallback onArm,
      required AnWheelTime tod,
      required ValueChanged<AnWheelTime> onTod}) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              child: Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
            Semantics(
              button: true,
              label: '$label ${_dateText(day)}',
              child: AnInteractive(
                onTap: onArm,
                builder: (context, states) => Container(
                height: AnSize.controlSm,
                padding: const EdgeInsets.symmetric(horizontal: AnSize.btnPadXSm),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: c.surfaceHover.whenActive(states.isActive),
                  borderRadius: BorderRadius.circular(AnRadius.button),
                ),
                  child: ExcludeSemantics(
                    child: Text(_dateText(day),
                        style: AnText.value().copyWith(color: armed ? c.accent : c.ink)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s4),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: AnTimeWheel(value: tod, onChanged: onTod, semanticLabel: label),
        ),
      ],
    );
  }
}
