import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_interactive.dart';
import '../ui/icons.dart';

/// The transport for a playing clip — and the answer to a defect that was invisible to every
/// assertion in the repo: [AnVideoCard] rendered a BARE `VideoPlayer(controller)`, and Flutter's
/// official `video_player` ships no chrome of its own. So a generated clip played exactly once and
/// then sat on its last frame: no pause, no scrub, no replay, no volume. Reloading the conversation
/// was the only way to watch it again. The widget was present and correct the whole time — which is
/// precisely why only the WRK-082 B1 human-eye pass could find it.
///
/// **Scrubbing is the package's own [VideoProgressIndicator]** (原则 #8), not a hand-rolled gesture →
/// duration conversion: it already owns the drag math, the buffered-range overlay and the listener
/// lifecycle. Only its colours are ours.
///
/// 一段正在播的片子的走带控件——也是一个**对本仓每一条断言都不可见**的缺陷的答案:[AnVideoCard] 渲的是
/// **裸的** `VideoPlayer(controller)`,而 Flutter 官方 `video_player` **自己不带任何控件**。于是一段生成
/// 的片子播完就停在最后一帧:不能暂停、不能拖动、不能重播、没有音量,想再看一遍只能重新加载对话。那个
/// widget 自始至终都在树上、也都是对的——这正是**只有** B1 人眼验收能查出它的原因。
///
/// **拖动用包自己的 [VideoProgressIndicator]**(原则 #8),不手搓「手势 → 时长」换算:拖拽数学、缓冲区间
/// 覆盖层、监听器生命周期它都已经拥有,我们只换配色。
class AnVideoControls extends StatelessWidget {
  const AnVideoControls({
    required this.controller,
    this.onFullscreen,
    super.key,
  });

  final VideoPlayerController controller;

  /// Absent inside the viewer itself — there is nowhere further to go. 在查看器里为空:没有更远的地方可去。
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    // AnimatedBuilder over the controller (a ValueNotifier<VideoPlayerValue>) — position ticks are
    // the whole reason this bar exists, so it must rebuild on them.
    // 用 AnimatedBuilder 订阅 controller(它是 ValueNotifier<VideoPlayerValue>)——位置在走,正是这条
    // 控件栏存在的理由,故它必须随之重建。
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        final ended =
            v.duration > Duration.zero &&
            v.position >= v.duration &&
            !v.isPlaying;
        return Row(
          children: [
            _ChromeButton(
              icon: ended
                  ? AnIcons.refresh
                  : v.isPlaying
                  ? AnIcons.pause
                  : AnIcons.run,
              label: ended
                  ? t.attach.replayVideo
                  : v.isPlaying
                  ? t.attach.pauseVideo
                  : t.attach.playVideo,
              onTap: () async {
                if (ended) {
                  // Seek BEFORE play: playing from the end position is a no-op that leaves the
                  // button stuck on "replay". 先 seek 再 play:从末尾位置起播是空操作,按钮会卡在「重播」。
                  await controller.seekTo(Duration.zero);
                  await controller.play();
                } else if (v.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
              },
            ),
            const SizedBox(width: AnSpace.s8),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
                colors: VideoProgressColors(
                  playedColor: c.accent,
                  bufferedColor: c.line,
                  backgroundColor: c.surfaceSunken,
                ),
              ),
            ),
            const SizedBox(width: AnSpace.s8),
            Text(
              '${_clock(v.position)} / ${_clock(v.duration)}',
              style: AnText.mono.copyWith(color: c.inkFaint),
            ),
            if (onFullscreen != null) ...[
              const SizedBox(width: AnSpace.s8),
              _ChromeButton(
                icon: AnIcons.expand,
                label: t.attach.enterFullscreen,
                onTap: onFullscreen!,
              ),
            ],
          ],
        );
      },
    );
  }

  /// m:ss — clips are seconds-to-minutes long, so an h:mm:ss ladder would be dead code.
  /// m:ss——片子是秒到分钟量级,h:mm:ss 阶梯会是死代码。
  static String _clock(Duration d) {
    final s = d.inSeconds.clamp(0, 1 << 30);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

/// A bare icon button for player/viewer chrome — the kit's hover/press states, no label slot.
/// 播放器/查看器外壳用的裸图标按钮:kit 的 hover/按下态,无标签位。
class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  // MergeSemantics + a labelled node: AnInteractive supplies its own `button` node, and a bare
  // sibling Semantics(label:) merges UP into whatever container encloses it — the label ends up
  // concatenated onto the caption row instead of naming this button. Merging makes the pair ONE node
  // that reads "Close, button", which is also what a screen reader should hear.
  // MergeSemantics + 带标签的节点:AnInteractive 自带 `button` 节点,而一个光杆
  // Semantics(label:) 会**向上**并进包着它的容器——标签会被拼到说明行上、而不是给这个按钮命名。
  // 合并使这一对成为**一个**节点,读作「关闭,按钮」,这也正是屏读该听到的。
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      label: label,
      child: AnInteractive(
        onTap: onTap,
        builder: (ctx, states) => Container(
          width: AnSize.control,
          height: AnSize.control,
          decoration: BoxDecoration(
            color: states.isActive ? ctx.colors.surfaceHover : null,
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Icon(icon, size: AnSize.icon, color: ctx.colors.inkMuted),
        ),
      ),
    ),
  );
}

/// The same button, exposed for the viewer's close affordance. 同一个按钮,供查看器的关闭用。
class AnMediaIconAction extends StatelessWidget {
  const AnMediaIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _ChromeButton(icon: icon, label: label, onTap: onTap);
}
