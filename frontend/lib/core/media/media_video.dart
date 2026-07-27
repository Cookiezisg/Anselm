/// Inline video playback for the ONE card family (WRK-082 H5.5).
///
/// Two constraints shaped this widget, and both were discovered by running it rather than by
/// reasoning about it:
///
/// **1. A sandboxed macOS app cannot hand libmpv a file path.** The entitlements grant
/// `files.user-selected.read-only` and nothing else, so anything under `/private/tmp` — or any
/// path the user did not personally pick — comes back `Operation not permitted`. Loopback HTTP is
/// the channel that IS already open (`network.client`, granted so the app can reach its own
/// sidecar), so the player streams the attachment from the sidecar exactly as every other read in
/// this app does. It also means a 20MB clip starts playing before it has finished downloading, and
/// nothing is written to disk twice.
///
/// **2. The player is created only when the user asks for it.** A `Player()` reaches into the
/// native layer, which does not exist in a widget test — so a card that built one eagerly would
/// blow up every existing test that happens to render a video attachment. Lazily is also simply
/// correct: a transcript scrolled past ten clips must not start ten libmpv instances.
///
/// 一族卡的内联视频播放(H5.5)。
///
/// 有两条约束塑造了这个 widget,而两条都是**跑出来**的、不是想出来的:
///
/// **1. 沙箱化的 macOS app 不能把文件路径交给 libmpv。** entitlements 只授了
/// `files.user-selected.read-only`,故 `/private/tmp` 下的东西——或任何不是用户亲手挑的路径——一律
/// 回 `Operation not permitted`。而 loopback HTTP 是**本来就开着**的那条通道(`network.client`,为让
/// app 够得着自己的 sidecar 而授),故播放器就像本应用其余每一次读取那样,从 sidecar **流式**拉这份
/// 附件。这同时意味着 20MB 的片子在下完之前就开播,且没有任何字节被写两遍盘。
///
/// **2. 播放器只在用户开口时才创建。** `Player()` 要伸到原生层,而 widget test 里根本没有那一层——
/// 于是一个急切构造它的卡片,会炸掉每一个恰好渲到视频附件的既有测试。惰性也**本就正确**:一份滚过
/// 十段片子的 transcript,不该起十个 libmpv。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/icons.dart';
import 'media_source.dart';

/// Brings up the native playback layer. Must run after the binding and before any [Player] is
/// constructed — every launch surface that can render a media attachment calls it, which is all of
/// them except onboarding (a first-run roster page with no attachments).
///
/// It lives here rather than being pasted into five `main()`s because it is exactly the kind of
/// boilerplate the foundation should own (原则 #8): a surface that forgets it does not fail at
/// startup, it fails the first time a user presses play.
///
/// 起原生播放层。必须在 binding 之后、任何 [Player] 构造之前跑——每一个可能渲到媒体附件的启动面都调它,
/// 也就是除 onboarding(无附件的首启名册页)之外的全部。
///
/// 它放在这里而不是被抄进五个 `main()`,因为它正是地基该拥有的那类样板(原则 #8):一个忘了调它的面
/// **不会**在启动时失败,而是在用户第一次按下播放时失败。
void initMediaPlayback() => MediaKit.ensureInitialized();

/// The inline video card: a poster-shaped tap target until pressed, a real player after.
class AnVideoCard extends ConsumerStatefulWidget {
  const AnVideoCard({
    required this.attachmentId,
    required this.filename,
    required this.metaLine,
    this.maxWidth = 320,
    super.key,
  });

  final String attachmentId;
  final String filename;
  final String metaLine;
  final double maxWidth;

  @override
  ConsumerState<AnVideoCard> createState() => _AnVideoCardState();
}

class _AnVideoCardState extends ConsumerState<AnVideoCard> {
  Player? _player;
  VideoController? _controller;

  @override
  void dispose() {
    // The player owns a native handle; letting it outlive the widget leaks an mpv instance per
    // card the user ever pressed play on.
    // player 持一个原生句柄;让它活得比 widget 久,等于用户每按过一次播放就漏一个 mpv 实例。
    _player?.dispose();
    super.dispose();
  }

  void _start() {
    final target = ref
        .read(mediaSourceProvider)
        .nativeTarget(widget.attachmentId);
    final player = Player();
    final controller = VideoController(player);
    // The headers are not optional: the sidecar is loopback-hardened (RequireBearerToken), so a
    // bare GET is refused. libmpv does its own fetching, which is exactly why it needs to be told.
    // 这些头不是可选的:sidecar 做了 loopback 加固(RequireBearerToken),裸 GET 会被拒。libmpv 自己
    // 去取,这正是必须告诉它的原因。
    player.open(Media(target.uri, httpHeaders: target.headers));
    setState(() {
      _player = player;
      _controller = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AnRadius.button),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: controller == null
                  ? _poster(c)
                  : Video(
                      controller: controller,
                      controls: AdaptiveVideoControls,
                    ),
            ),
          ),
        ),
        const SizedBox(height: AnSpace.s4),
        Text(
          widget.filename.isEmpty
              ? widget.metaLine
              : '${widget.filename} · ${widget.metaLine}',
          style: AnText.label.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }

  Widget _poster(AnColors c) => GestureDetector(
    onTap: _start,
    child: ColoredBox(
      color: c.surfaceSunken,
      child: Center(child: Icon(AnIcons.run, size: 28, color: c.inkMuted)),
    ),
  );
}
