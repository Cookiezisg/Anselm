import 'package:flutter/widgets.dart';

import '../../core/design/tokens.dart';
import '../../core/model/time_range.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

/// AnTimeRangePicker / AnCalendar 标本(WRK-069 拍板 0717;渐进披露重造 0718)。
///
/// 设计裁决速记:
///   · 渐进披露三层:预设小单(点即生效,95% 路径两击)→「自定义范围…」日历面板(唯一显式应用)→
///     「精确到时刻」披露(端点默认整天,点开才出滚轮)。
///   · 日历是唯一权威:预设=写入范围的快捷方式,✓ 随值;胶囊忠于意图(预设显名/整天对显日子/带刻显时刻)。
///   · 范围=连续缎带+圆帽(格缝一体,不再是离散点);终点早于起点=就地报错+拒绝应用,绝不偷偷交换。
///   · 日历恒 6 行 42 格(跨月零跳高)+月头回今天;滚轮邻排向沿渐隐(读得出「停在哪」)。
///   · 键盘:日历整盘一个 Tab 停靠,←→↑↓ 走日、PgUp/PgDn 翻月(Shift=年)、Home/End 周首尾、Enter 选。
///
/// gallery 为 dev-only,文案中文直写(i18n 豁免);app 侧文案经 AnTimeRangePickerStrings 从 slang 进。
final _strings = AnTimeRangePickerStrings(
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
  monthTitle: (m) => '${m.year} 年 ${m.month} 月',
  prevMonthLabel: '上个月',
  nextMonthLabel: '下个月',
  capsuleA11y: '时间范围',
  backLabel: '返回快捷范围',
  todayLabel: '回到今天',
  preciseTimeLabel: '精确到时刻',
  dayText: (d) => '${d.month} 月 ${d.day} 日',
);

/// 受控宿主——gallery 里可真点开、真选(标本即活控件)。
class _PickerHost extends StatefulWidget {
  const _PickerHost({required this.initial});

  final AnTimeRange initial;

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  late AnTimeRange _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: AnTimeRangePicker(
        value: _value,
        onChanged: (v) => setState(() => _value = v),
        strings: _strings,
      ),
    );
  }
}

class _CalendarHost extends StatefulWidget {
  const _CalendarHost({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  State<_CalendarHost> createState() => _CalendarHostState();
}

class _CalendarHostState extends State<_CalendarHost> {
  DateTime _month = DateTime(2026, 7, 1);
  late DateTime? _start = widget.start;
  late DateTime? _end = widget.end;

  @override
  Widget build(BuildContext context) {
    return AnCalendar(
      month: _month,
      rangeStart: _start,
      rangeEnd: _end,
      onPickDay: (d) => setState(() {
        if (_start == null || _end != null || d.isBefore(_start!)) {
          _start = d;
          _end = null;
        } else {
          _end = d;
        }
      }),
      onMonthChange: (m) => setState(() => _month = m),
      weekdayLabels: const ['一', '二', '三', '四', '五', '六', '日'],
      monthTitle: '$_month'.substring(0, 7),
      prevMonthLabel: '上个月',
      nextMonthLabel: '下个月',
      todayLabel: '回到今天',
      gridSemanticLabel: '日历',
    );
  }
}

/// 滚轮宿主——真滚真变(标本即活控件)。
class _WheelHost extends StatefulWidget {
  const _WheelHost({required this.initial});

  final AnWheelTime initial;

  @override
  State<_WheelHost> createState() => _WheelHostState();
}

class _WheelHostState extends State<_WheelHost> {
  late AnWheelTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnTimeWheel(
        value: _value,
        onChanged: (v) => setState(() => _value = v),
        semanticLabel: '时刻',
      ),
    ]);
  }
}

final anTimeRangePickerGalleryItem = GalleryItem(
  'AnTimeRangePicker 时间范围',
  'Grafana 定式+渐进披露三层:预设小单点即生效→自定义日历面板(连续缎带+圆帽+回今天+唯一应用)→'
      '精确到时刻披露(默认整天);终点早于起点就地报错绝不交换;日历恒 6 行 42 格零跳高、整盘单 Tab 停靠 APG 键盘',
  [
    GallerySpecimen(
      '胶囊·预设态(点开真选)',
      (_) => const Padding(
        padding: EdgeInsets.all(AnSpace.s16),
        child: _PickerHost(initial: AnPresetRange(AnTimePreset.d7)),
      ),
      height: 80,
    ),
    GallerySpecimen(
      '胶囊·绝对态(冻结两端回显)',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: _PickerHost(
          initial: AnAbsoluteRange(
            from: DateTime(2026, 6, 1, 9, 0),
            to: DateTime(2026, 6, 30, 18, 0),
          ),
        ),
      ),
      height: 80,
    ),
    GallerySpecimen(
      '日历·连续缎带(圆帽坐带上,格缝一体)',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: _CalendarHost(start: DateTime(2026, 7, 6), end: DateTime(2026, 7, 17)),
      ),
    ),
    GallerySpecimen(
      '日历·终点未定(hover 扫预览带)',
      (_) => Padding(
        padding: const EdgeInsets.all(AnSpace.s16),
        child: _CalendarHost(start: DateTime(2026, 7, 6)),
      ),
    ),
    GallerySpecimen(
      '日历·空态(无选区,键盘可进)',
      (_) => const Padding(
        padding: EdgeInsets.all(AnSpace.s16),
        child: _CalendarHost(),
      ),
    ),
    GallerySpecimen(
      '时刻滚轮(HH:MM 循环轮;滚轮一格一步/拖拽/↑↓)',
      (_) => const Padding(
        padding: EdgeInsets.all(AnSpace.s16),
        child: _WheelHost(initial: (hour: 9, minute: 30)),
      ),
      height: 96,
    ),
  ],
);
