import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_a11y.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// C3 — a step-progress indicator: a row of nodes showing done / current / upcoming for a [count]-step
/// flow at the 1-based [current] step. HAND-ROLL (a Row of AnimatedContainers; the step-progress
/// packages ship their own theme system + ZERO Semantics, the only hard part). Stateful only for the
/// announce lifecycle — a stepper advances DISCRETELY, so there is NO repeating motion (a breath pulse
/// would violate 动效克制); the only motion is an implicit AnimatedContainer on the current-step change,
/// frozen under reduced.
///
/// Three DISTINCT treatments per node (never colour alone): done = accent (+ a check glyph in
/// [numbered]), current = accent emphasis (an elongated dot / filled circle), upcoming = a faint
/// line/outline. One [Semantics] carries "<label>. Step N of M" for a reader that walks here, and an
/// ADVANCE (not a mount — see [didUpdateWidget]) pushes it politely; the decorative nodes are excluded.
/// (`liveRegion` used to sit on that container and is a desktop no-op — see [AnA11y].) When [onStepTap]
/// is set, COMPLETED nodes become AnInteractive (a soft focus/hover ring + Enter/Space + a "go to step N"
/// button label); current/upcoming stay non-focusable.
///
/// C3——步骤进度:一排节点显 done/current/upcoming(1-based current)。HAND-ROLL。**仅为播报生命周期而 Stateful**,
/// 离散推进、无循环动效(breath 违背克制),仅当前步变化有隐式 AnimatedContainer、降级冻结。三态各异(不靠色单独):
/// done=accent(numbered 带 check)、current=accent 强调、upcoming=淡线。一个 Semantics 带「<label>. 第N/共M」供
/// 读屏走到时读到,**推进**时(非挂载,见 didUpdateWidget)礼貌推一次;装饰节点排除(此容器原挂 liveRegion=桌面
/// no-op,见 AnA11y)。onStepTap 时已完成节点变 AnInteractive(柔焦点/悬停环 + Enter/Space + 「跳到第N步」标签)。
enum AnStepperVariant { dots, numbered }

enum _Status { done, current, upcoming }

class AnStepper extends StatefulWidget {
  const AnStepper({
    required this.count,
    required this.current,
    this.variant = AnStepperVariant.dots,
    this.labels,
    this.onStepTap,
    this.semanticLabel,
    super.key,
  });

  /// Total steps M. 总步数。
  final int count;

  /// The 1-based current step (count+1 = all done). 当前步(1-based;count+1=全完成)。
  final int current;

  final AnStepperVariant variant;

  /// Optional short label under each node (uses labels[i-1] when present). 每步短标签(可选)。
  final List<String>? labels;

  /// Tap a COMPLETED step to jump back (1-based). null = pure indicator. 点已完成步跳回。
  final void Function(int step)? onStepTap;

  /// Process name for the a11y value. 流程名(无障碍)。
  final String? semanticLabel;

  @override
  State<AnStepper> createState() => _AnStepperState();
}

class _AnStepperState extends State<AnStepper> {
  _Status _statusOf(int i) => i < widget.current
      ? _Status.done
      : i == widget.current
          ? _Status.current
          : _Status.upcoming;

  String _value(BuildContext context) =>
      context.t.feedback.stepOf(n: widget.current.clamp(1, widget.count), m: widget.count);

  // Announce the ADVANCE, never the arrival — the one asymmetry that separates this from the toast /
  // callout / state family. Those three ARE the news (they appear from nowhere); a stepper is page
  // FURNITURE that was already here — announcing on mount would talk over the page a reader just
  // navigated to, and they will read the step when they get to it. What they cannot discover on their
  // own is the flow moving underneath them, so that — and only that — is pushed.
  // 播报**推进**、绝不播报**到场**——这是它与 toast/callout/state 一族唯一的不对称:那三个**本身就是新闻**
  // (凭空出现);而 stepper 是**本来就在**的页面家具——挂载即念会盖过读屏刚导航到的这一页,而他们走到时自会读到
  // 它。他们**自己发现不了**的是脚下这条流程在动,故只推这个。
  @override
  void didUpdateWidget(AnStepper old) {
    super.didUpdateWidget(old);
    if (old.current == widget.current && old.count == widget.count) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final label = widget.semanticLabel;
      final v = _value(context);
      AnA11y.announce(context, label == null || label.isEmpty ? v : '$label. $v');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();
    final dur = AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid;

    // The label/value are what a reader FINDS; the SPEAKING is [didUpdateWidget] (`liveRegion` sat here
    // and was a desktop no-op). label/value 供走到时找到;发声在 didUpdateWidget(此处原是 no-op)。
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: _value(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 1; i <= widget.count; i++) ...[
            if (i > 1) const SizedBox(width: AnSpace.s6),
            _node(context, i, _statusOf(i), dur),
          ],
        ],
      ),
    );
  }

  Widget _node(BuildContext context, int i, _Status status, Duration dur) {
    final c = context.colors;
    final tappable = widget.onStepTap != null && status == _Status.done;

    final Widget node = tappable
        ? MergeSemantics(
            child: Semantics(
              label: context.t.feedback.goToStep(n: i),
              child: AnInteractive(
                onTap: () => widget.onStepTap!(i),
                builder: (ctx, states) => _dot(ctx, i, status, dur, active: states.isActive),
              ),
            ),
          )
        : ExcludeSemantics(child: _dot(context, i, status, dur, active: false));

    final label = widget.labels != null && i <= widget.labels!.length ? widget.labels![i - 1] : null;
    if (label == null) return node;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        node,
        const SizedBox(height: AnSpace.s6),
        ExcludeSemantics(
          child: Text(label, style: AnText.meta.copyWith(color: status == _Status.upcoming ? c.inkFaint : c.ink)),
        ),
      ],
    );
  }

  Widget _dot(BuildContext context, int i, _Status status, Duration dur, {required bool active}) {
    final c = context.colors;
    // A soft accent ring marks a tappable node that's keyboard-focused / hovered (visible on either
    // bg colour, unlike a same-colour border). 柔色环标记可点节点的聚焦/悬停。
    final ring = active ? [BoxShadow(color: c.accentSoft, spreadRadius: AnSpace.s4)] : const <BoxShadow>[];

    if (widget.variant == AnStepperVariant.numbered) {
      final done = status == _Status.done;
      final upcoming = status == _Status.upcoming;
      return AnimatedContainer(
        duration: dur,
        curve: AnMotion.easeOut,
        width: AnSize.badge,
        height: AnSize.badge,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: upcoming ? c.surface : c.accent,
          shape: BoxShape.circle,
          border: Border.all(color: upcoming ? c.line : c.accent, width: AnSize.hairline),
          boxShadow: ring,
        ),
        child: done
            ? Icon(AnIcons.check, size: AnSize.iconSm, color: c.onAccent)
            : Text('$i',
                style: AnText.metaTabular().copyWith(color: upcoming ? c.inkFaint : c.onAccent)),
      );
    }

    // dots: done = accent dot, current = elongated accent pill, upcoming = faint line dot.
    final isCurrent = status == _Status.current;
    return Container(
      // a constant-height hit/centre box so dots align with the taller `current` pill and stay tappable
      // 定高居中盒:小圆点与拉长的 current 对齐、且有可点区
      height: AnSize.badge,
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: dur,
        curve: AnMotion.easeOut,
        width: isCurrent ? AnSize.stepCurrent : AnSize.dot,
        height: AnSize.dot,
        decoration: BoxDecoration(
          color: status == _Status.upcoming ? c.line : c.accent,
          borderRadius: BorderRadius.circular(AnRadius.pill),
          boxShadow: ring,
        ),
      ),
    );
  }
}
