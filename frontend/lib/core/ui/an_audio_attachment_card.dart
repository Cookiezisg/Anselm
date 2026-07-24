import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_attachment_card.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// A sent audio attachment surface. Unlike a generic file card it always exposes the audio mental
/// model: play affordance, timeline, and duration/status slot. The host owns actual playback and passes
/// [onPlayTap]/[playing]/[progress]; without a player it renders an explicit unavailable state instead
/// of pretending playback works.
///
/// 已发送音频附件面。不同于通用文件卡，它固定呈现音频心智：播放位、时间轴、时长/状态槽。真实播放由宿主
/// 注入 [onPlayTap]/[playing]/[progress]；没有播放器时明确显示不可播放，不假装已接通。
class AnAudioAttachmentCard extends StatelessWidget {
  const AnAudioAttachmentCard({
    required this.filename,
    required this.metaLine,
    this.state = AnAttachmentState.ready,
    this.durationLabel,
    this.statusLine,
    this.busy = false,
    this.progress = 0,
    this.playing = false,
    this.onPlayTap,
    this.onTap,
    super.key,
  });

  final String filename;
  final String metaLine;
  final AnAttachmentState state;
  final String? durationLabel;
  final String? statusLine;
  final bool busy;
  final double progress;
  final bool playing;
  final VoidCallback? onPlayTap;

  /// failed/oversized fallback action; ready opening is intentionally separate from playback.
  /// 失败/超大回退动作；ready 打开与播放刻意分离。
  final VoidCallback? onTap;

  bool get _playable =>
      state == AnAttachmentState.ready && onPlayTap != null && !busy;

  bool get _fallbackInteractive =>
      onTap != null &&
      (state == AnAttachmentState.failed ||
          state == AnAttachmentState.oversized);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    if (state == AnAttachmentState.resolving) {
      return AnAttachmentCard(
        kind: 'audio',
        filename: filename,
        metaLine: metaLine,
        state: state,
      );
    }

    final missing = state == AnAttachmentState.missing;
    final stateLine = switch (state) {
      AnAttachmentState.missing => t.attach.unavailable,
      AnAttachmentState.failed => t.attach.retry,
      AnAttachmentState.oversized => t.attach.tapToLoad,
      AnAttachmentState.ready when statusLine != null => statusLine!,
      AnAttachmentState.ready when !_playable =>
        t.attach.audioPlaybackUnavailable,
      _ => metaLine,
    };
    final duration = durationLabel ?? '–:––';
    final clamped = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: AnSize.control,
              height: AnSize.control,
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                borderRadius: BorderRadius.circular(AnRadius.button),
              ),
              child: Icon(
                missing ? AnIcons.fileMissing : AnIcons.audio,
                size: AnSize.icon,
                color: c.inkFaint,
              ),
            ),
            const SizedBox(width: AnSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.body
                        .weight(AnText.emphasisWeight)
                        .copyWith(color: missing ? c.inkFaint : c.ink),
                  ),
                  Text(
                    stateLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.label.copyWith(color: c.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AnSpace.s8),
            _PlayButton(
              enabled: _playable,
              playing: playing,
              disabledLabel: statusLine,
              onTap: onPlayTap,
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s8),
        Row(
          children: [
            Expanded(
              child: _AudioTimeline(
                progress: clamped,
                disabled: !_playable || missing,
              ),
            ),
            const SizedBox(width: AnSpace.s8),
            Text(duration, style: AnText.mono.copyWith(color: c.inkFaint)),
          ],
        ),
      ],
    );

    final semantics = '$filename, $stateLine, $duration';
    if (!_fallbackInteractive) {
      return Semantics(
        container: true,
        label: semantics,
        child: _frame(c, active: false, child: body),
      );
    }
    return MergeSemantics(
      child: Semantics(
        container: true,
        label: semantics,
        child: AnInteractive(
          onTap: onTap,
          builder: (ctx, states) =>
              _frame(ctx.colors, active: states.isActive, child: body),
        ),
      ),
    );
  }

  Widget _frame(AnColors c, {required bool active, required Widget child}) =>
      Container(
        width: AnSize.attachCard,
        padding: const EdgeInsets.all(AnSpace.s8),
        decoration: BoxDecoration(
          color: active ? c.surfaceHover : c.surface,
          border: Border.all(color: c.line, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.chip),
        ),
        child: child,
      );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.enabled,
    required this.playing,
    required this.disabledLabel,
    required this.onTap,
  });

  final bool enabled;
  final bool playing;
  final String? disabledLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final label = enabled
        ? (playing ? t.attach.pauseAudio : t.attach.playAudio)
        : disabledLabel ?? t.attach.audioPlaybackUnavailable;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: AnInteractive(
          onTap: onTap,
          enabled: enabled,
          builder: (ctx, states) {
            final c = ctx.colors;
            final active = states.isActive && enabled;
            return Container(
              width: AnSize.control,
              height: AnSize.control,
              decoration: BoxDecoration(
                color: active ? c.accentSoft : c.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(
                playing ? AnIcons.pause : AnIcons.run,
                size: AnSize.iconSm,
                color: enabled ? c.accent : c.inkFaint,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AudioTimeline extends StatelessWidget {
  const _AudioTimeline({required this.progress, required this.disabled});

  final double progress;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AnSize.attachCard;
        final fill = math.max(0.0, width * progress);
        return Container(
          height: AnSize.gripLine,
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(AnRadius.pill),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: fill,
              color: disabled ? c.inkFaint : c.accent,
            ),
          ),
        );
      },
    );
  }
}
