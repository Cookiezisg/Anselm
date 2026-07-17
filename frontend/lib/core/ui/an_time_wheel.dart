import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_focus_ring.dart';

/// A minute-grain time as plain fields — the wheel's value word (core stays material-free, so no
/// TimeOfDay). 分钟粒度时刻——轮的值词(core 不进 material,故不用 TimeOfDay)。
typedef AnWheelTime = ({int hour, int minute});

/// A compact two-column HH:MM wheel — [AnTimeRangePicker]'s time half (用户 0717-深夜拍板:「具体
/// 时间不要自己写,改成滚轮滑时间」— typing a time is replaced by DIRECT manipulation, so an endpoint
/// time can never be unparseable).
///
/// Each column is a looping [ListWheelScrollView] (23:59→00:00 wraps — the midnight-crossing pick
/// the flat list would dead-end). Desktop input is first-class: ONE mouse-wheel notch = ONE step
/// (the framework wheel's own pointer-scroll handling is not reliable across platforms, so a
/// [Listener] drives the controller explicitly — which is also the better cadence than momentum),
/// drag/fling works natively, each column is a Tab stop with ↑/↓ steps and a focus ring, and a
/// screen reader gets a per-column adjustable (onIncrease/onDecrease) with the OWNER's label —
/// zero copy in core: [semanticLabel] arrives as a param.
///
/// 紧凑双列 HH:MM 滚轮——AnTimeRangePicker 的时刻半边。逐列循环轮(23:59→00:00 可跨);桌面输入一等:
/// 鼠标滚轮一格=一步(框架轮的指针滚动跨平台不可靠,Listener 显式驱动——也比惯性更合桌面手感),拖拽原生,
/// 逐列 Tab 停靠+↑/↓ 步进+焦点环,读屏逐列可调节(宿主供标签,core 零文案)。
class AnTimeWheel extends StatelessWidget {
  const AnTimeWheel({
    required this.value,
    required this.onChanged,
    this.semanticLabel = '',
    super.key,
  });

  final AnWheelTime value;
  final ValueChanged<AnWheelTime> onChanged;

  /// The owner's name for this wheel (e.g. the From/To word) — prefixes both columns' a11y.
  /// 宿主给轮的名字(如「从/至」),两列读屏前缀。
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(alignment: Alignment.center, children: [
      // The selection band — one rounded bed under the centre row of BOTH columns, the wheel's
      // only chrome. 选中带:横贯两列中排的一张圆角床,轮的唯一 chrome。
      Positioned.fill(
        top: (_WheelColumn.height - _WheelColumn.itemExtent) / 2,
        bottom: (_WheelColumn.height - _WheelColumn.itemExtent) / 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceHover,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
        ),
      ),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _WheelColumn(
          count: 24,
          value: value.hour,
          onChanged: (h) => onChanged((hour: h, minute: value.minute)),
          semanticLabel: semanticLabel,
        ),
        Text(':', style: AnText.value().copyWith(color: c.inkFaint)),
        _WheelColumn(
          count: 60,
          value: value.minute,
          onChanged: (m) => onChanged((hour: value.hour, minute: m)),
          semanticLabel: semanticLabel,
        ),
      ]),
    ]);
  }
}

class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    required this.count,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final int count;
  final int value;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  /// Three rows visible — the neighbourly context that makes a wheel readable without dominating
  /// the panel. 三排可见:轮可读所需的邻里上下文,又不吞面板。
  static const double itemExtent = 20;
  static const double height = itemExtent * 3;
  static const double width = 30;

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.value);
  bool _focused = false;

  /// True while a PROGRAMMATIC re-seat is in flight — the jump fires onSelectedItemChanged like any
  /// scroll, and echoing it back as onChanged would turn every external set into a phantom user
  /// action (电池抓获). 程序性落座在飞——jump 同样触发选中回调,不压住就把每次外部赋值回声成幽灵操作。
  bool _seating = false;

  @override
  void didUpdateWidget(_WheelColumn old) {
    super.didUpdateWidget(old);
    // An external value (prefill on open, owner reset) re-seats the wheel; a value echoing our own
    // in-flight scroll must NOT be re-jumped — it would stutter the drag under the finger.
    // 外部值(开面板预填/宿主重置)重新落座;回声自己滚动的值绝不回跳——那会让拖拽在指下打嗝。
    if (widget.value != old.value &&
        _controller.hasClients &&
        _mod(_controller.selectedItem) != widget.value) {
      _seating = true;
      _controller.jumpToItem(widget.value);
      WidgetsBinding.instance.addPostFrameCallback((_) => _seating = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _mod(int item) => ((item % widget.count) + widget.count) % widget.count;

  void _step(int delta) {
    if (!_controller.hasClients) return;
    final target = _controller.selectedItem + delta;
    if (AnMotionPref.reduced(context)) {
      _controller.jumpToItem(target);
    } else {
      _controller.animateToItem(target,
          duration: AnMotion.fast, curve: Curves.easeOutCubic);
    }
  }

  String _label(int i) => i.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: widget.semanticLabel,
      value: _label(widget.value),
      increasedValue: _label(_mod(widget.value + 1)),
      decreasedValue: _label(_mod(widget.value - 1)),
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      container: true,
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _step(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _step(1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnFocusRing(
          active: _focused,
          radius: AnRadius.button,
          child: Listener(
            // ONE notch = ONE step, explicit (see class doc). 一格一步,显式驱动。
            onPointerSignal: (e) {
              if (e is PointerScrollEvent && e.scrollDelta.dy != 0) {
                _step(e.scrollDelta.dy > 0 ? 1 : -1);
              }
            },
            child: SizedBox(
              width: _WheelColumn.width,
              height: _WheelColumn.height,
              child: ExcludeSemantics(
                child: ListWheelScrollView.useDelegate(
                  controller: _controller,
                  itemExtent: _WheelColumn.itemExtent,
                  physics: const FixedExtentScrollPhysics(),
                  perspective: 0.002,
                  diameterRatio: 2.4,
                  onSelectedItemChanged: (i) {
                    if (_seating) return;
                    widget.onChanged(_mod(i));
                  },
                  childDelegate: ListWheelChildLoopingListDelegate(children: [
                    for (var i = 0; i < widget.count; i++)
                      Center(
                        child: Text(
                          _label(i),
                          // Selected = emphasis via .weight() (两档字重卫士), neighbours faint.
                          // 选中走 .weight() 加粗档,邻排 faint。
                          style: (i == widget.value
                                  ? AnText.value().weight(AnText.emphasisWeight)
                                  : AnText.value())
                              .copyWith(color: i == widget.value ? c.ink : c.inkFaint),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
