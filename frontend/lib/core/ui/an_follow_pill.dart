import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../perf/pulse_clock.dart';
import '../../i18n/strings.g.dart';
import 'an_interactive.dart';
import 'an_status_dot.dart';
import 'icons.dart';

/// What the pill is offering. 药丸在提示什么。
enum AnFollowPillKind {
  /// «AI 正在编辑 X →» — new activity while the user holds the camera (pinned). Tapping resumes follow.
  /// 用户持镜期间的新活动;点=交还镜头。
  live,

  /// «AI 在等你决定 →» — the human gate, AMBER, pierces every silence (§2); tapping jumps to the
  /// transcript's white-island gate (the ONLY place decisions happen). 人闸琥珀,点=跳 transcript 白岛门。
  gate,

  /// «回到最新/回到现场 ↓» — a STATIC jump-back offer (scrolled-away viewport / transcript float).
  /// Never breathes, never subscribes to the clock: the reader chose to look away; the offer just
  /// sits there (WRK-066 批5, A-033/036 收编两处手搓回场药丸). 静态回场 offer:绝不呼吸不挂钟——
  /// 读者主动移开了视线,offer 安静候着。
  jump,
}

/// The FOLLOW PILL (WRK-061 §2): the stage's non-intrusive «something is happening elsewhere» offer.
/// It breathes via the SHARED [PulseClock] (own RepaintBoundary). Under reduced motion it neither
/// subscribes nor pokes — the static pose must SETTLE (WRK-037 reduced-motion standard). It offers,
/// never takes — tapping is the only camera move.
///
/// 跟随药丸:舞台的不打扰式「别处有事」提示。呼吸走共享 PulseClock(自带 RepaintBoundary);reduced 下
/// 完全不挂钟不起搏——静态姿态必须可 settle。只提示、绝不夺——点按是唯一的镜头动作。
class AnFollowPill extends StatefulWidget {
  const AnFollowPill({
    required this.kind,
    this.subjectName = '',
    required this.onTap,
    this.clock,
    super.key,
  }) : jumpLabel = '',
       elevated = false;

  /// The static jump-back face. [elevated] floats it over content (the transcript overlay) with a
  /// soft shadow. 静态回场脸;elevated=浮在内容上(transcript 浮层)带柔影。
  const AnFollowPill.jump({
    required String label,
    required this.onTap,
    this.elevated = false,
    super.key,
  }) : kind = AnFollowPillKind.jump,
       subjectName = '',
       jumpLabel = label,
       clock = null;

  final AnFollowPillKind kind;

  /// The jump face's label (site-specific: 回到最新 / 回到现场). jump 脸文案(站点各异)。
  final String jumpLabel;

  /// Jump face only: float shadow. 仅 jump 脸:浮影。
  final bool elevated;

  /// The live variant's subject display name (may be "" while a name is still resolving). live 主角名。
  final String subjectName;

  final VoidCallback onTap;

  /// Injectable for tests/gallery; defaults to the app-wide shared clock. 可注入;默认共享钟。
  final PulseClock? clock;

  @override
  State<AnFollowPill> createState() => _AnFollowPillState();
}

class _AnFollowPillState extends State<AnFollowPill> {
  PulseClock get _clock => widget.clock ?? PulseClock.shared;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Arriving IS activity — but the breath pulse is a DECORATIVE loop, so it gates on
    // reducedOrAssistive (screen readers get the static pose; the live/gate text carries the
    // meaning); the jump face never pokes at all. MediaQuery lives here, not initState.
    // 出现即起搏;呼吸=装饰循环走 reducedOrAssistive(读屏拿静态姿态,语义由文案承载);jump 脸永不起搏。
    if (widget.kind != AnFollowPillKind.jump &&
        !AnMotionPref.reducedOrAssistive(context)) {
      _clock.poke();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    if (widget.kind == AnFollowPillKind.jump) {
      return _JumpShell(
        label: widget.jumpLabel,
        elevated: widget.elevated,
        onTap: widget.onTap,
      );
    }
    final amber = widget.kind == AnFollowPillKind.gate;
    final tone = amber ? c.warn : c.accent;
    final label = amber
        ? t.feedback.cast.gatePill
        : t.feedback.cast.livePill(name: widget.subjectName);
    if (AnMotionPref.reducedOrAssistive(context)) {
      // Static pose, no clock subscription — zero frames requested. 静态姿态,零帧请求。
      return _PillShell(
        tone: tone,
        label: label,
        swell: 0,
        onTap: widget.onTap,
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          // Breath = a gentle alpha swell on the border; static pose at phase 0. 呼吸=描边柔胀;0 相静态。
          final phase = _clock.value;
          final swell = 0.5 + 0.5 * (1 - (phase - 0.5).abs() * 2);
          return _PillShell(
            tone: tone,
            label: label,
            swell: swell,
            onTap: widget.onTap,
          );
        },
      ),
    );
  }
}

class _PillShell extends StatelessWidget {
  const _PillShell({
    required this.tone,
    required this.label,
    required this.swell,
    required this.onTap,
  });

  final Color tone;
  final String label;
  final double swell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnInteractive(
      onTap: onTap,
      builder: (ctx, states) => Container(
        height: AnSize.row - AnSpace.s8,
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        decoration: BoxDecoration(
          color: states.isActive ? c.surfaceHover : c.surface,
          border: Border.all(
            color: tone.withValues(alpha: tone.a * (0.35 + 0.4 * swell)),
            width: AnSize.hairline,
          ),
          borderRadius: BorderRadius.circular(AnRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnStatusDot.raw(tone, size: AnSize.dotSm),
            const SizedBox(width: AnSpace.s6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
            ),
            const SizedBox(width: AnSpace.s4),
            Icon(AnIcons.chevronRight, size: AnSize.iconXs, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// The static jump-back shell: chevron-down + label on the family pill geometry; [elevated] floats
/// it with a soft shadow (the transcript overlay). 静态回场壳:家族药丸几何;elevated 浮影。
class _JumpShell extends StatelessWidget {
  const _JumpShell({
    required this.label,
    required this.elevated,
    required this.onTap,
  });

  final String label;
  final bool elevated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnInteractive(
      onTap: onTap,
      builder: (ctx, states) => Container(
        height: AnSize.row - AnSpace.s8,
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        decoration: BoxDecoration(
          color: states.isActive ? c.surfaceHover : c.surface,
          border: Border.all(color: c.line, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.pill),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: c.ink.withValues(alpha: AnOpacity.shadow),
                    blurRadius: AnSpace.s4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AnIcons.chevronDown, size: AnSize.iconSm, color: c.inkMuted),
            const SizedBox(width: AnSpace.s4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
