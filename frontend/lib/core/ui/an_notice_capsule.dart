import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';

/// The chrome-band notice capsule — the ONLY floating surface for event notifications (用户 0720 拍板:
/// 右上 toast 退役,浮层文化降级为例外). A white-island pill that lives in the title band's idle middle:
/// it NEVER covers work content (the band's height is chrome), never reflows layout. Lifecycle is
/// self-driven: fade+drop entrance ([AnMotion.mid]) → hold ([AnMotion.toast], hover pauses, WCAG) →
/// fade+shrink exit ([AnMotion.slow]) → [onDismissed]. Reduced motion: instant in/out, hold unchanged.
/// Tapping fires [onTap] (deep link) — the host dismisses. The tone dot is the severity identity
/// (danger red / warn amber); the copy is one sentence + a muted "view" tail.
///
/// chrome 带通知胶囊——事件通知唯一的浮层(右上 toast 退役)。白岛药丸住顶带空闲中段:永不盖工作内容、
/// 永不顶开布局。生命周期自驱:淡入下滑登场(mid)→停留(toast 档,hover 暂停)→淡出缩回(slow)→onDismissed。
/// reduced 即时进出、停留不变。点击=深链(宿主负责收场)。tone 点=严重度身份(danger 红/warn 琥珀),
/// 文案=一句话+灰「查看」尾。
class AnNoticeCapsule extends StatefulWidget {
  const AnNoticeCapsule({
    required this.text,
    required this.viewLabel,
    this.icon,
    this.danger = true,
    this.onTap,
    required this.onDismissed,
    this.hold = AnMotion.toast,
    super.key,
  });

  final String text;

  /// The muted trailing affordance label (i18n "View"). 灰尾「查看」文案(i18n)。
  final String viewLabel;

  /// Optional kind glyph between the dot and the text. 点与文案间的可选 kind 图标。
  final IconData? icon;

  /// Severity: true = danger red dot, false = warn amber. 严重度点色。
  final bool danger;

  final VoidCallback? onTap;

  /// Fired once after the exit animation completes (NOT on tap — the host owns tap teardown).
  /// 退场动画完成后回调一次(点击收场由宿主管,不经此)。
  final VoidCallback onDismissed;

  /// On-screen dwell between entrance and exit. 登-退之间的停留时长。
  final Duration hold;

  @override
  State<AnNoticeCapsule> createState() => _AnNoticeCapsuleState();
}

class _AnNoticeCapsuleState extends State<AnNoticeCapsule> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _dwell;

  // Pause bookkeeping mirrors AnToast (WCAG hover-pause): remaining time shrinks across re-arms.
  // 暂停记账同 AnToast:剩余时长跨重臂递减。
  late int _remainingMs;
  int _armedAt = 0;
  bool _exiting = false;

  bool get _reduced => AnMotionPref.reduced(context);

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _remainingMs = widget.hold.inMilliseconds;
    _c = AnimationController(vsync: this, duration: AnMotion.mid, reverseDuration: AnMotion.slow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ignite HERE, not in a post-frame callback: this runs synchronously before the first build in every
    // pump regime (a post-frame callback silently never fired under the capture harness's frame pumping —
    // the capsule sat at opacity 0). Needs context anyway for the reduced-motion read.
    // 点火在此、不用 postFrame:首 build 前同步必执行(capture 泵帧下 postFrame 曾静默不触发,胶囊卡在
    // opacity 0);且 reduced 判断本就要 context。
    if (_started) return;
    _started = true;
    if (_reduced) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    _arm();
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _arm() {
    _armedAt = DateTime.now().millisecondsSinceEpoch;
    _dwell?.cancel();
    _dwell = Timer(Duration(milliseconds: _remainingMs), _exit);
  }

  void _pause() {
    if (_exiting || _dwell == null) return;
    _dwell?.cancel();
    _dwell = null;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _armedAt;
    _remainingMs = (_remainingMs - elapsed).clamp(0, widget.hold.inMilliseconds);
  }

  void _resume() {
    if (_exiting) return;
    _arm();
  }

  Future<void> _exit() async {
    if (_exiting || !mounted) return;
    _exiting = true;
    if (_reduced) {
      _c.value = 0;
    } else {
      await _c.reverse();
    }
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      onEnter: (_) => _pause(),
      onExit: (_) => _resume(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Opacity(
          opacity: _c.value,
          // Entrance drops 6px from above; exit shrinks in place (拍板:退场不做飞行,原地缩回).
          // 登场自上 6px 落下;退场原地缩回。
          child: Transform.translate(
            offset: Offset(0, (1 - _c.value) * -AnSpace.s6),
            child: Transform.scale(scale: 0.92 + 0.08 * _c.value, child: child),
          ),
        ),
        child: AnInteractive(
          onTap: widget.onTap,
          builder: (context, states) => Container(
            constraints: const BoxConstraints(maxWidth: AnSize.toastMaxWidth),
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s4),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AnRadius.pill),
              border: Border.all(color: c.line, width: AnSize.hairline),
              boxShadow: c.shadowIsland,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AnSize.dot,
                  height: AnSize.dot,
                  decoration: BoxDecoration(
                    color: widget.danger ? c.danger : c.warn,
                    shape: BoxShape.circle,
                  ),
                ),
                if (widget.icon != null) ...[
                  const SizedBox(width: AnSpace.s6),
                  Icon(widget.icon, size: AnSize.iconSm, color: c.inkMuted),
                ],
                const SizedBox(width: AnSpace.s6),
                Flexible(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.body.copyWith(color: c.ink),
                  ),
                ),
                if (widget.onTap != null) ...[
                  const SizedBox(width: AnSpace.s6),
                  Text('· ${widget.viewLabel}',
                      style: AnText.meta.copyWith(color: c.inkFaint)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
