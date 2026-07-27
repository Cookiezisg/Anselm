import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/icons.dart';
import 'media_player_chrome.dart';

import 'package:video_player/video_player.dart';

/// The ENLARGED view of one artifact — the second consumer of the direct-`RawDialogRoute` pattern
/// [anConfirmRoute] introduced (WRK-041 F4), and the reason that file's "a rich-content openDialog
/// waits for a 2nd island card" note finally comes due.
///
/// **Why it has to exist at all.** A generated image is 1536×1024 and the card slot is 320 logical px
/// wide — the artifact the user just paid for is displayed at a fifth of its size, with no way to see
/// it. Video is worse: it played inline with NO transport at all, so a clip could be watched exactly
/// once and never paused, scrubbed or replayed. Both were found by the WRK-082 B1 human-eye pass;
/// neither is visible to any assertion, because in both cases the widget is present and correct.
///
/// **One route, two payloads.** Image and video share the chrome (scrim, close, Escape, barrier tap,
/// filename caption) and differ only in the body, so the enlarging gesture means one thing everywhere
/// the card family renders — chat, the flowrun inspector, the entity console, the document editor.
///
/// 一件产物的**放大**视图——[anConfirmRoute](WRK-041 F4)那套「直接构造 RawDialogRoute」的第二个消费者,
/// 也让那份文件里「富内容 openDialog 等第二张岛卡」的注记到期。
///
/// **它为什么非有不可**:一张生成图是 1536×1024,而卡槽宽 320 逻辑 px——用户刚花钱买到的东西以五分之一
/// 的尺寸显示,且**没有任何办法看清**。视频更糟:它内联播放却**完全没有走带控件**,于是一段片子一辈子
/// 只能看一次,不能暂停、不能拖动、不能重播。两条都是 B1 人眼验收查出来的;**任何断言都看不见它们**,
/// 因为两处的 widget 都在树上、也都是对的。
///
/// **一条路由两种载荷**:图与视频共用外壳(遮罩/关闭/Escape/点遮罩/文件名),只在主体上分岔,故「放大」
/// 这个手势在卡族渲染的每一处——chat、flowrun 检查器、实体调试台、文档编辑器——含义完全一致。
Future<void> openImageViewer(
  BuildContext context, {
  required ImageProvider image,
  required String caption,
}) => _open(
  context,
  caption: caption,
  // InteractiveViewer rather than a hand-rolled zoom: it already handles trackpad scale, drag-pan and
  // the boundary math on every desktop platform (原则 #8).
  // 用 InteractiveViewer 而非手搓缩放:触控板缩放、拖拽平移、边界数学它在每个桌面平台上都做好了(#8)。
  body: (context) => InteractiveViewer(
    minScale: 1,
    maxScale: 6,
    child: Image(image: image, fit: BoxFit.contain),
  ),
);

/// The fullscreen face of a clip. It takes the LIVE controller rather than making its own: a second
/// controller would re-fetch and re-decode the same bytes, start from zero, and leave two decoders
/// running for one clip. Two [VideoPlayer]s over one controller render the same texture, so position
/// and play state are shared by construction — closing the viewer cannot desync them because there is
/// only one of them.
///
/// 片子的全屏面。它接**活的** controller、不自己造:第二个 controller 会把同样的字节**重下重解**、从零
/// 开始,并让一段片子同时开两个解码器。两个 [VideoPlayer] 共用一个 controller 渲的是同一张纹理,故位置与
/// 播放态**天然**共享——关掉查看器不可能让两者走偏,因为它们本来就只有一个。
Future<void> openVideoViewer(
  BuildContext context, {
  required VideoPlayerController controller,
  required String caption,
}) => _open(
  context,
  caption: caption,
  body: (context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
      const SizedBox(height: AnSpace.s8),
      AnVideoControls(controller: controller),
    ],
  ),
);

Future<void> _open(
  BuildContext context, {
  required WidgetBuilder body,
  required String caption,
}) {
  final t = Translations.of(context);
  final reduced = AnMotionPref.reduced(context);
  final route = RawDialogRoute<void>(
    barrierColor: context.colors.scrimMedia,
    barrierDismissible: true,
    barrierLabel: t.attach.mediaViewer,
    transitionDuration: reduced ? Duration.zero : AnMotion.mid,
    // NOT defaulted on direct construction — without it Tab walks out of the modal (same gotcha
    // an_dialog.dart calls out). 直接构造不默认;少了它 Tab 会走出 modal(与 an_dialog 同一个坑)。
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    pageBuilder: (context, animation, secondary) =>
        _ViewerChrome(caption: caption, body: body),
    transitionBuilder: (context, animation, secondary, child) =>
        reduced ? child : FadeTransition(opacity: animation, child: child),
  );
  return Navigator.of(context, rootNavigator: true).push(route);
}

class _ViewerChrome extends StatelessWidget {
  const _ViewerChrome({required this.caption, required this.body});

  final String caption;
  final WidgetBuilder body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    // RawDialogRoute gives scopesRoute + explicitChildNodes but NOT the route name, so a screen
    // reader entering the modal would announce nothing (an_dialog.dart verified this against the SDK
    // source). RawDialogRoute 给 scopesRoute/explicitChildNodes,**不给**路由名,故屏读进 modal 无播报。
    return Semantics(
      namesRoute: true,
      label: t.attach.mediaViewer,
      // Material(transparency): this lives in a RawDialogRoute, outside any Scaffold — without a
      // Material ancestor every Text here paints the debug yellow underline. The same line
      // an_dialog.dart carries, for the same reason; the B1 capture caught it on the first shot.
      // Material(transparency):它住在 RawDialogRoute 里、在任何 Scaffold 之外——没有 Material 祖先时
      // 这里每一段 Text 都会画上调试用的黄下划线。与 an_dialog.dart 同一行、同一个理由;B1 截图第一张就抓到了。
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(AnSpace.s24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.label.copyWith(color: c.inkMuted),
                    ),
                  ),
                  const SizedBox(width: AnSpace.s8),
                  AnMediaIconAction(
                    icon: AnIcons.close,
                    label: t.attach.closeViewer,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AnSpace.s8),
              Expanded(child: Center(child: body(context))),
            ],
          ),
        ),
      ),
    );
  }
}
