import 'dart:async';

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_button.dart';
import 'an_interactive.dart';
import 'icons.dart';
import 'tone.dart';

/// F3 — ONE toast (WRK-041 G6.2). A self-contained, presentational, Riverpod-FREE chip: it owns its
/// own enter/exit animation + auto-dismiss [Timer] and calls [onDismissed] when it has finished
/// leaving — so the stack host ([AnOverlayHost]) just lays a column of these and removes the data
/// once told. Being a plain widget (not coupled to the controller) makes it gallery-showable and
/// unit-testable on its own (pass [duration] `Duration.zero` for a sticky specimen). NON-anchored,
/// non-blocking, never steals focus (it announces via a polite [Semantics.liveRegion], NEVER
/// SemanticsService.announce — that's desktop-broken + VoiceOver-hijacking + deprecated). The op tint
/// is a LEFT bar only; the surface is the shared white-island idiom (= AnMenuSurface) with a pop
/// shadow. Auto-dismiss defaults to 4s; [Duration.zero] = sticky (close-only, WCAG 2.2.1 escape hatch).
///
/// F3——单条 toast。自含、纯展示、无 Riverpod:自管进出动画 + 自动消隐 Timer,离场完成回调 onDismissed
/// (host 只管堆列 + 收到通知后移数据)。纯 widget(不耦合 controller)→ 可单独进 gallery / 单测(duration=zero=常驻)。
/// 非锚定 / 非阻断 / 不夺焦(polite liveRegion 播报,绝不用桌面失效且会被 VoiceOver 抢读的 announce)。tone 仅左色条;
/// 面=白岛(同 AnMenuSurface)+ 浮影。自动消隐缺省 4s;Duration.zero=常驻(仅手动关,WCAG 2.2.1 兜底)。
/// Tone is the shared semantic [AnTone] (批7 B-035 — the toast enum was a strict subset). tone=公共 AnTone。

/// An optional inline action on a toast (e.g. "Undo"). 可选行内动作(如「撤销」)。
@immutable
class AnToastAction {
  const AnToastAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

/// Auto-dismiss default — the [AnMotion.toast] tier (public alias kept so consumers keep a
/// zero-import name). [Duration.zero] (or any non-positive) = sticky.
/// 自动消隐缺省=AnMotion.toast 档(公开别名保留);非正=常驻。
const Duration anToastDefaultDuration = AnMotion.toast;

class AnToast extends StatefulWidget {
  const AnToast({
    required this.text,
    required this.onDismissed,
    this.tone = AnTone.none,
    this.action,
    this.duration = anToastDefaultDuration,
    super.key,
  });

  final String text;

  /// Called AFTER the exit animation completes (the host removes the data then). 离场动画完成后回调。
  final VoidCallback onDismissed;
  final AnTone tone;
  final AnToastAction? action;

  /// Auto-dismiss delay; [Duration.zero]/non-positive = sticky. 自动消隐延时;非正=常驻。
  final Duration duration;

  @override
  State<AnToast> createState() => _AnToastState();
}

class _AnToastState extends State<AnToast> with SingleTickerProviderStateMixin {
  // EAGER controller (never a late-final lazy initialiser — the AnPopover dispose-time crash lesson):
  // duration is patched to zero under reduced-motion on the first didChangeDependencies, before the
  // single forward(). 急切建 controller(绝不 late-final 懒初始化);reduced 在首个 didChangeDependencies 把时长改 0。
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AnMotion.mid,
  );
  Timer? _timer;
  bool _inited = false;
  bool _leaving = false;

  // Auto-dismiss is PAUSED while the pointer is over the toast (WCAG 2.2.1 — a user reading / reaching for
  // the action must not have it vanish). [_remaining] tracks the time left; [_sw] measures the run since
  // the last (re)arm so pause can subtract it. Sticky toasts (duration ≤ 0) never arm — hover is a no-op.
  // 指针悬停时暂停自动消隐(WCAG 2.2.1:正在读/够按钮的用户不该让它消失)。_remaining=剩余时长,_sw=本段计时。
  Duration _remaining = Duration.zero;
  final Stopwatch _sw = Stopwatch();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      // reduced-motion needs an inherited lookup (illegal in initState) → gate the FIRST forward here.
      // reduced 需继承查找(initState 非法)→ 首次 forward 在此门控。
      if (AnMotionPref.reduced(context)) _anim.duration = Duration.zero;
      _anim.forward();
      if (widget.duration > Duration.zero) {
        _remaining = widget.duration;
        _arm(_remaining);
      }
    }
  }

  // Start (or restart) the auto-dismiss countdown for [d]. 起(或重起)消隐倒计时。
  void _arm(Duration d) {
    _timer?.cancel();
    _sw
      ..reset()
      ..start();
    _timer = Timer(d, _dismiss);
  }

  // Pointer entered → freeze the countdown, banking the time already run. 悬停→冻结,记下已跑时间。
  void _pause() {
    if (_leaving || _timer == null || !_sw.isRunning) return;
    _timer?.cancel();
    _remaining -= _sw.elapsed;
    _sw.stop();
    if (_remaining < Duration.zero) _remaining = Duration.zero;
  }

  // Pointer left → resume from the banked remainder (sticky/expired never re-arm). 离开→从剩余续跑。
  void _resume() {
    if (_leaving || widget.duration <= Duration.zero || _remaining <= Duration.zero) return;
    _arm(_remaining);
  }

  void _dismiss() {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    // Drive the exit, THEN tell the host to drop the data (so it animates out, not snaps). 自驱离场→再通知移除。
    _anim.reverse().whenComplete(() {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  // none → inkFaint (demo --ink-3), NOT AnToneColors.none's inkMuted: the resting bar is the
  // faintest neutral, brighter only when toned. none→inkFaint(非 AnToneColors 的 inkMuted)。
  Color _barColor(AnColors c) =>
      widget.tone == AnTone.none ? c.inkFaint : widget.tone.fg(c);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.t;
    final reduced = AnMotionPref.reduced(context);
    // Re-sync the controller duration every build so a RUNTIME reduced-motion toggle reaches the EXIT
    // too (didChangeDependencies only gated the first enter; _dismiss's reverse() reuses this). Setting
    // duration is cheap — it governs the next forward/reverse, never restarts. 每帧同步:运行期切 reduced 亦作用离场。
    _anim.duration = reduced ? Duration.zero : AnMotion.mid;
    final curved = _anim.drive(CurveTween(curve: AnMotion.spring));

    // The text drives the chip height (wraps to 2 lines); the buttons centre within it; the tone bar
    // runs the FULL content height as a Positioned overlay. NOT an IntrinsicHeight+Row(Expanded) — a
    // RenderFlex with a flex child can't answer intrinsic-height queries (it throws). A Stack sidesteps
    // intrinsics entirely. 文字定高、按钮居中、色条经 Positioned 满高(避开 IntrinsicHeight+Expanded 的内在尺寸禁区)。
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.toastMaxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AnRadius.chip),
          border: Border.all(color: c.line, width: AnSize.hairline),
          boxShadow: c.shadowPop,
        ),
        // Material(transparency): floating overlay text needs a Material ancestor for its default text
        // style — without it Flutter paints the debug yellow underline (the chip lives in the host's
        // Stack, outside any Scaffold). No fill/elevation, so the surface + shadow stay on DecoratedBox.
        // 浮层文字须 Material 祖先取默认文字样式,否则黄色下划线 debug 标记(chip 在 host 的 Stack、无 Scaffold)。
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Padding(
                // Left inset leaves room for the full-height tone bar (s8 edge + s4 bar + s8 gap). 左留位给满高色条。
                padding: const EdgeInsets.fromLTRB(
                  AnSpace.s8 + AnSpace.s4 + AnSpace.s8,
                  AnSpace.s8,
                  AnSpace.s12,
                  AnSpace.s8,
                ),
                child: Row(
                  children: [
                    // Text absorbs the slack so the close button pins to the right edge; 2-line ellipsis. 文字吸余、关钮钉右。
                    // liveRegion sits on the TEXT only (polite announce on appear), NOT the whole chip —
                    // wrapping the chip would merge the close/action buttons into one node (their labels +
                    // isButton leak in, and the text dupes). ExcludeSemantics drops the Text's own node so
                    // the label isn't announced twice. liveRegion 仅在文字(包整 chip 会把按钮并进来)。
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        label: widget.text,
                        child: ExcludeSemantics(
                          child: Text(
                            widget.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AnText.body.copyWith(color: c.ink),
                          ),
                        ),
                      ),
                    ),
                    if (widget.action != null) ...[
                      const SizedBox(width: AnSpace.s8),
                      _action(c, reduced),
                    ],
                    const SizedBox(width: AnSpace.s8),
                    AnButton.iconOnly(
                      AnIcons.close,
                      size: AnButtonSize.sm,
                      semanticLabel: t.feedback.dismiss,
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
              // Full-height tone bar (demo .an-toast-bar align-self:stretch), inset by the vertical pad,
              // rounded, decorative-only. 满高 tone 色条(内距内、圆角、纯装饰)。
              Positioned(
                left: AnSpace.s8,
                top: AnSpace.s8,
                bottom: AnSpace.s8,
                width: AnSpace.s4, // demo --grid one cell 色条 = --grid 一格
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _barColor(c),
                      borderRadius: BorderRadius.circular(AnRadius.pill),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Enter: fade + an 8px upward nudge (spring). The polite liveRegion announce lives on the text node
    // inside [chip] (not here — see above). Hover pauses auto-dismiss (WCAG). 进场:淡入 + 8px 上移;悬停暂停消隐。
    return MouseRegion(
      onEnter: (_) => _pause(),
      onExit: (_) => _resume(),
      child: FadeTransition(
        opacity: _anim,
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, (1 - curved.value) * AnSpace.s8),
            child: child,
          ),
          child: chip,
        ),
      ),
    );
  }

  // Inline accent-text action (AnButton has no accent variant — WRK-041 decision U1). 行内 accent 文字钮。
  Widget _action(AnColors c, bool reduced) {
    return AnInteractive(
      onTap: () {
        widget.action!.onPressed();
        _dismiss();
      },
      builder: (context, states) {
        final active = states.isActive;
        return AnimatedContainer(
          duration: reduced ? Duration.zero : AnMotion.fast,
          height: AnSize.controlSm,
          padding: const EdgeInsets.symmetric(horizontal: AnSize.btnPadXSm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accentSoft.whenActive(active),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Text(
            widget.action!.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.meta
                .weight(AnText.emphasisWeight)
                .copyWith(color: c.accent),
          ),
        );
      },
    );
  }
}
