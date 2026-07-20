import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../notice/notice_center.dart';
import 'an_interactive.dart';
import 'an_notice_close_affordance.dart';
import 'an_status_dot.dart';
import 'an_tooltip.dart';
import 'tone.dart';

/// The fixed-cost candidate tail beside the top-band's current card:
///
/// - one pending message = one tone dot;
/// - two = two dots;
/// - more = two dots + a fixed 32px COUNT SLOT (N excludes those two);
/// - hover OR keyboard focus swaps `+N` to a centred tile-less X on a standard 28×28 hit face; activation
///   clears the stage snapshot. The layout slot stays fixed and never paints a nested square button.
///
/// It never builds pending cards or lays out their copy. Dot arrivals are one-shot scale/fades (no
/// breathing); count and X cross-fade in place. The host paint-links this tail to the current card's
/// right edge, so none of this geometry can shift the card off the screen centre.
///
/// 顶带当前卡右侧的定成本候场尾:1 条=1 点,2 条=2 点,更多=2 点 + 定盒 `+N`(N 不含前两点);hover
/// 或键盘 focus 时原盒换 X,激活清舞台快照。绝不构建候场卡/排版正文;点只出生一次、不呼吸;数字/X
/// 原位交叉淡换。宿主用 paint link 跟随当前卡右缘,尾巴任何变化都不能把当前卡挤离屏幕中心。
class AnNoticeQueueTail extends StatefulWidget {
  const AnNoticeQueueTail({
    required this.cues,
    required this.overflowCount,
    required this.clearLabel,
    required this.onClear,
    this.onEngagedChanged,
    super.key,
  });

  /// At most two cues; the message center enforces the bound. 最多两颗候场提示。
  final List<NoticeCue> cues;
  final int overflowCount;
  final String clearLabel;
  final VoidCallback onClear;

  /// Hover/focus pauses the current pill's dwell while the pointer/keyboard travels to bulk clear.
  /// 尾巴 hover/focus 时暂停当前药丸驻留,避免用户刚要点 X 卡先消失。
  final ValueChanged<bool>? onEngagedChanged;

  @override
  State<AnNoticeQueueTail> createState() => _AnNoticeQueueTailState();
}

class _AnNoticeQueueTailState extends State<AnNoticeQueueTail> {
  bool _hovered = false;
  bool _focusWithin = false;

  bool get _engaged => _hovered || _focusWithin;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    final before = _engaged;
    setState(() => _hovered = value);
    if (before != _engaged) widget.onEngagedChanged?.call(_engaged);
  }

  void _setFocusWithin(bool value) {
    if (_focusWithin == value) return;
    final before = _engaged;
    setState(() => _focusWithin = value);
    if (before != _engaged) widget.onEngagedChanged?.call(_engaged);
  }

  @override
  void didUpdateWidget(AnNoticeQueueTail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onEngagedChanged != widget.onEngagedChanged && _engaged) {
      oldWidget.onEngagedChanged?.call(false);
      widget.onEngagedChanged?.call(true);
    }
  }

  @override
  void dispose() {
    if (_engaged) widget.onEngagedChanged?.call(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cueChildren = <Widget>[];
    for (var i = 0; i < widget.cues.length; i++) {
      if (i > 0) cueChildren.add(const SizedBox(width: AnGap.inline));
      final cue = widget.cues[i];
      cueChildren.add(_CueDot(key: ValueKey<String>(cue.id), cue: cue));
    }
    final children = <Widget>[
      if (cueChildren.isNotEmpty)
        Row(mainAxisSize: MainAxisSize.min, children: cueChildren),
    ];
    if (widget.overflowCount > 0) {
      if (children.isNotEmpty) {
        // The points are one cluster; the destructive bulk action is a separate satellite.
        // 点是一簇,批清动作是另一颗卫星,二者拉开一档。
        children.add(const SizedBox(width: AnGap.inlineLoose));
      }
      children.add(_bulkControl(context));
    }
    return RepaintBoundary(
      child: SizedBox(
        height: AnSize.noticeBar,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _bulkControl(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    // The exact count remains in tooltip/semantics. Visual copy is capped so an event storm cannot
    // push beyond the 70px title-band runway at the minimum ocean width. 精确数留在提示/语义;视觉封顶,
    // 风暴也不把最窄 ocean 的 70px 跑道撑破。
    final visualCount = widget.overflowCount > 999
        ? '999+'
        : '+${widget.overflowCount}';
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(widget.overflowCount),
      tween: Tween<double>(begin: 0.86, end: 1),
      duration: reduced ? Duration.zero : AnMotion.fast,
      curve: AnMotion.easeOut,
      builder: (context, arrival, child) => Opacity(
        opacity: arrival,
        child: Transform.scale(scale: arrival, child: child),
      ),
      child: AnTooltip(
        message: widget.clearLabel,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: _setFocusWithin,
          child: MouseRegion(
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _setHovered(false),
            child: MergeSemantics(
              child: Semantics(
                label: widget.clearLabel,
                button: true,
                child: AnInteractive(
                  onTap: widget.onClear,
                  builder: (context, states) {
                    // 32px is only the number runway. The active visual is the island's tile-less
                    // 28px close face, centred without moving the slot. 32 只给数字跑道;激活面是岛内
                    // 同款无底 28px X,槽中心不动。
                    final active = _engaged || states.isActive;
                    final focused = states.contains(WidgetState.focused);
                    return SizedBox(
                      width: AnSize.noticeTailSlot,
                      height: AnSize.noticeBar,
                      child: Center(
                        child: ExcludeSemantics(
                          child: AnimatedSwitcher(
                            duration: reduced ? Duration.zero : AnMotion.fast,
                            switchInCurve: AnMotion.easeOut,
                            switchOutCurve: AnMotion.easeOut,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.center,
                              children: <Widget>[...previous, ?current],
                            ),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.86,
                                      end: 1,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: active
                                ? AnNoticeCloseFace(
                                    key: const ValueKey<String>('clear'),
                                    active: true,
                                    focused: focused,
                                    pressed: states.contains(
                                      WidgetState.pressed,
                                    ),
                                  )
                                : SizedBox(
                                    key: ValueKey<String>(visualCount),
                                    width: AnSize.noticeTailSlot,
                                    height: AnSize.control,
                                    child: Center(
                                      child: Text(
                                        visualCount,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: AnText.metaTabular().copyWith(
                                          color: c.inkFaint,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CueDot extends StatelessWidget {
  const _CueDot({required this.cue, super.key});

  final NoticeCue cue;

  @override
  Widget build(BuildContext context) {
    final reduced = AnMotionPref.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: reduced ? Duration.zero : AnMotion.fast,
      curve: AnMotion.easeOut,
      builder: (context, arrival, child) => Opacity(
        opacity: arrival,
        child: Transform.scale(scale: arrival, child: child),
      ),
      child: SizedBox(
        width: AnSize.dot,
        height: AnSize.noticeBar,
        child: Center(
          child: AnStatusDot.raw(
            cue.tone.fg(context.colors),
            key: ValueKey<String>(cue.id),
          ),
        ),
      ),
    );
  }
}
