import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/time_format.dart';
import '../model/time_range.dart';
import 'an_button.dart';
import 'an_calendar.dart';
import 'an_expand_reveal.dart';
import 'an_interactive.dart';
import 'an_menu_surface.dart';
import 'an_pop_surface.dart';
import 'an_popover.dart';
import 'an_time_wheel.dart';
import 'icons.dart';

/// The Grafana-family time-range control (WRK-069 拍板 0717;渐进披露重造 用户 0718 拍板「为 5% 场景
/// 付 100% 代价」诊断): ONE capsule governs every time-scoped zone on its page. The popover is
/// PROGRESSIVE DISCLOSURE, three tiers —
///
/// 1. **Presets** (default): a compact preset menu; a click applies IMMEDIATELY and closes (presets
///    stay LIVE, re-resolved at every fetch). The 95% path costs two clicks and one small panel.
/// 2. **Custom** («自定义范围…» row): the calendar range pane — first pick starts, second ≥ start
///    ends, an earlier pick restarts (never a swap); the range paints as ONE continuous ribbon with
///    round caps; a plain-ink preview line echoes the pair (the old link-blue faux buttons are
///    gone); «back to today» lives in the month head. Custom commits via ONE explicit Apply.
/// 3. **Times** («精确到时刻» reveal): endpoints default to the FULL DAY (00:00–23:59, hidden);
///    only this disclosure shows the HH:MM wheels. Re-opening a pair that carries non-default
///    times reveals the tier honestly.
///
/// The calendar is the ONE authority: presets are shortcuts that write a range; the ✓ follows the
/// VALUE (a preset shows its name, an absolute pair shows both days). End-before-start is judged at
/// Apply (dates can't misorder by construction — only times can), shown inline, never swapped.
/// Body chrome is [AnPopSurface]; zero copy in core — every string arrives via
/// [AnTimeRangePickerStrings].
///
/// Grafana 族时间范围控件(0717 拍板;0718 渐进披露重造)。弹层三层:①预设小单(默认;点即生效收起,预设
/// 是活的逐次现解析——95% 路径两击一小面板)②「自定义范围…」=日历范围面板(首击起、次击 ≥ 起点收终、
/// 更早重开绝不交换;范围=连续缎带+圆帽;纯墨预览行回显两端[假链接蓝退役];月头带回今天;唯一显式应用)
/// ③「精确到时刻」披露(端点默认整天 00:00–23:59 不展示;点开才出时刻滚轮;重开带非默认时刻的绝对对时
/// 诚实自动展开)。日历是唯一权威:预设=写入范围的快捷方式,✓ 随值;终点早于起点只在应用时判(日期构造
/// 上不可能错序,只有时刻能)、就地报错、绝不偷偷交换。壳 AnPopSurface;core 零文案。
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
    required this.backLabel,
    required this.todayLabel,
    required this.preciseTimeLabel,
    required this.dayText,
    this.daySemanticLabel,
    this.gridSemanticLabel = '',
  });

  /// One label per preset — a missing key hides that row (a caller may offer a subset).
  /// 逐预设标签——缺键即藏行（调用方可只供子集）。
  final Map<AnTimePreset, String> presetLabels;

  /// Tier-2 title AND the tier-1 «Custom range…» row word (core appends the ellipsis glyph).
  /// 二级标题,兼一级「自定义范围…」行词(省略号由 core 拼)。
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

  /// Tier-2 back button a11y (returns to presets). 返回预设钮读屏词。
  final String backLabel;

  /// Calendar «back to today» a11y. 回今天钮读屏词。
  final String todayLabel;

  /// The tier-3 disclosure button label («精确到时刻»). 三级披露钮词。
  final String preciseTimeLabel;

  /// Localized DAY text for the preview line and capsule (e.g. «7 月 11 日» / «7/11» — the caller
  /// owns year handling for cross-year days). 本地化日期词(预览行/胶囊用;跨年含年由调用方定)。
  final String Function(DateTime day) dayText;

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

/// Full-day defaults — endpoints without an explicit time pick span their whole days (the resolve
/// layer pushes the inclusive 23:59 one minute past, so the range truly covers the last day).
/// 整天默认:未显式选时刻的端点覆盖整日(解析层把闭端 23:59 后推一分钟,末日真被含住)。
const AnWheelTime _kDayStart = (hour: 0, minute: 0);
const AnWheelTime _kDayEnd = (hour: 23, minute: 59);

class _AnTimeRangePickerState extends State<AnTimeRangePicker> {
  final AnPopoverController _popover = AnPopoverController();

  /// Tier 1 (presets) vs tier 2 (custom calendar) — the popover ALWAYS reopens on presets (the
  /// cheap 95% path first, 渐进披露). 一级/二级;弹层永远先落一级。
  bool _custom = false;

  /// Tier-3 disclosure — hidden until asked for, or until a reopened pair carries non-default
  /// times (hiding a live 09:30 would misread as full-day). 三级披露;带非默认时刻重开时诚实自动开。
  bool _timeOpen = false;

  DateTime _fromDay = dateOnly(DateTime.now());
  DateTime _toDay = dateOnly(DateTime.now());
  AnWheelTime _fromTod = _kDayStart;
  AnWheelTime _toTod = _kDayEnd;

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
    if (_popover.isOpen) {
      _custom = false;
      _seedDraft();
    }
    setState(() {});
  }

  /// Seed the custom draft from the CURRENT value: an absolute pair verbatim (its times reveal the
  /// time tier when non-default); a live preset seeds its currently-resolved DAYS with full-day
  /// times (a starting point — the stored value stays the expression, EUI #4026).
  /// 落种:绝对逐字(非默认时刻自动开三级);预设按当下解析出的日子+整天时刻(仅作起点,存的仍是表达式)。
  void _seedDraft() {
    final now = DateTime.now();
    switch (widget.value) {
      case AnAbsoluteRange(from: final f, to: final t):
        _fromDay = dateOnly(f);
        _toDay = dateOnly(t);
        _fromTod = (hour: f.hour, minute: f.minute);
        _toTod = (hour: t.hour, minute: t.minute);
        _timeOpen = _fromTod != _kDayStart || _toTod != _kDayEnd;
      case AnPresetRange():
        final r = resolveTimeRange(widget.value, now);
        _fromDay = dateOnly(r.from ?? DateTime(now.year, now.month, now.day - 7));
        _toDay = dateOnly(now);
        _fromTod = _kDayStart;
        _toTod = _kDayEnd;
        _timeOpen = false;
    }
    _month = DateTime(_toDay.year, _toDay.month, 1);
    _awaitingEnd = false;
    _error = null;
  }

  String get _capsuleLabel {
    switch (widget.value) {
      case AnPresetRange(:final preset):
        return widget.strings.presetLabels[preset] ?? '';
      case AnAbsoluteRange(:final from, :final to):
        // Faithful to intent: a full-day pair speaks in DAYS; explicit times speak in instants.
        // 忠于意图:整天对念日子,显式时刻念时刻。
        final fullDay = from.hour == 0 &&
            from.minute == 0 &&
            to.hour == _kDayEnd.hour &&
            to.minute == _kDayEnd.minute;
        if (fullDay) {
          return '${widget.strings.dayText(from)} – ${widget.strings.dayText(to)}';
        }
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 480),
      child: AnPopSurface(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AnRadius.chip),
          child: SingleChildScrollView(
            child: FocusTraversalGroup(
              child: _custom ? _customPane(context) : _presetPane(context),
            ),
          ),
        ),
      ),
    );
  }

  // ── tier 1: the compact preset menu (点即生效;95% 路径) ──
  Widget _presetPane(BuildContext context) {
    final c = context.colors;
    final presets = [
      for (final p in AnTimePreset.values)
        if (widget.strings.presetLabels.containsKey(p)) p,
    ];
    final current = widget.value;
    final customActive = current is AnAbsoluteRange;

    return Padding(
      padding: const EdgeInsets.all(AnSpace.s4),
      child: SizedBox(
        width: 168,
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
                          style:
                              AnText.body.copyWith(color: active || selected ? c.ink : c.inkMuted),
                        ),
                      ),
                      if (selected) Icon(AnIcons.check, size: AnSize.iconSm, color: c.accent),
                    ],
                  );
                },
              ),
            // Divider, then the door to tier 2. 分隔线,然后是二级的门。
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
              child: Container(height: AnSize.hairline, color: c.line),
            ),
            AnMenuRow(
              onTap: () => setState(() => _custom = true),
              autofocus: customActive,
              builder: (context, active) => Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.strings.customTitle}…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.body
                          .copyWith(color: active || customActive ? c.ink : c.inkMuted),
                    ),
                  ),
                  if (customActive) ...[
                    Icon(AnIcons.check, size: AnSize.iconSm, color: c.accent),
                    const SizedBox(width: AnSpace.s4),
                  ],
                  Icon(AnIcons.chevronRight, size: AnSize.iconSm, color: c.inkFaint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── tier 2: the calendar range pane (日历=唯一权威;一个应用钮) ──
  Widget _customPane(BuildContext context) {
    final c = context.colors;
    final s = widget.strings;

    // Fixed width = the calendar's own grid width — without it the overlay's loose constraints
    // stretch the Column (and its right-aligned Apply) across the whole screen. IntrinsicWidth is
    // out (the subtree carries a LayoutBuilder, which cannot answer intrinsics).
    // 面板宽=日历网格宽(单源);不定宽则 overlay 把列拉满全屏。IntrinsicWidth 不可用(子树含
    // LayoutBuilder,答不了 intrinsics)。
    return SizedBox(
      width: AnCalendar.gridWidth + AnSpace.s12 * 2,
      child: Padding(
      padding: const EdgeInsets.all(AnSpace.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AnButton.iconOnly(AnIcons.chevronLeft,
                size: AnButtonSize.sm,
                semanticLabel: s.backLabel,
                onPressed: () => setState(() => _custom = false)),
            const SizedBox(width: AnSpace.s6),
            Text(s.customTitle,
                style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
          ]),
          const SizedBox(height: AnSpace.s8),
          AnCalendar(
            month: _month,
            rangeStart: _fromDay,
            rangeEnd: _awaitingEnd ? null : _toDay,
            onPickDay: _pickDay,
            onMonthChange: (m) => setState(() => _month = m),
            weekdayLabels: s.weekdayLabels,
            monthTitle: s.monthTitle(_month),
            prevMonthLabel: s.prevMonthLabel,
            nextMonthLabel: s.nextMonthLabel,
            todayLabel: s.todayLabel,
            daySemanticLabel: s.daySemanticLabel,
            gridSemanticLabel: s.gridSemanticLabel,
          ),
          const SizedBox(height: AnSpace.s8),
          // The preview line — plain ink, an ECHO not a control (假链接蓝退役: blue promised a
          // click it couldn't honour). 预览行:纯墨回显、非控件。
          Text(
            '${s.dayText(_fromDay)} – ${s.dayText(_toDay)}',
            style: AnText.value().copyWith(color: c.ink),
          ),
          // ── tier 3: exact times, disclosed on demand (端点默认整天,藏) ──
          if (!_timeOpen)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnButton(
                  label: s.preciseTimeLabel,
                  size: AnButtonSize.sm,
                  variant: AnButtonVariant.ghost,
                  icon: AnIcons.scheduler,
                  onPressed: () => setState(() => _timeOpen = true),
                ),
              ),
            ),
          AnExpandReveal(
            open: _timeOpen,
            child: Padding(
              padding: const EdgeInsets.only(top: AnSpace.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _todColumn(context, s.fromLabel, _fromTod, (v) => setState(() {
                        _fromTod = v;
                        _revalidateIfErrored();
                      })),
                  const SizedBox(width: AnSpace.s16),
                  _todColumn(context, s.toLabel, _toTod, (v) => setState(() {
                        _toTod = v;
                        _revalidateIfErrored();
                      })),
                ],
              ),
            ),
          ),
          const SizedBox(height: AnSpace.s8),
          if (_error != null) ...[
            Text(_error!, style: AnText.label.copyWith(color: c.danger)),
            const SizedBox(height: AnSpace.s8),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: AnButton(
              label: s.applyLabel,
              size: AnButtonSize.sm,
              variant: AnButtonVariant.primary,
              onPressed: _apply,
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// One time-of-day column: the endpoint word over its HH:MM wheel. 一端:标签+时刻滚轮。
  Widget _todColumn(BuildContext context, String label, AnWheelTime tod,
      ValueChanged<AnWheelTime> onTod) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnSpace.s4),
        AnTimeWheel(value: tod, onChanged: onTod, semanticLabel: label),
      ],
    );
  }
}
