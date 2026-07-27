/// Inline video playback for the ONE card family (WRK-082 H5.5, rebased in H5.5R / ADR 0018).
///
/// Three constraints shaped this widget, and all three were discovered by RUNNING it:
///
/// **1. A sandboxed macOS app cannot hand a native player an arbitrary file path.** The entitlements
/// grant `files.user-selected.read-only` and nothing else, so anything under `/private/tmp` — or any
/// path the user did not personally pick — is refused. Loopback HTTP is the channel that IS already
/// open (`network.client`, granted so the app can reach its own sidecar), so the player streams the
/// attachment from the sidecar exactly as every other read in this app does. A 20MB clip starts
/// playing before it has finished downloading, and nothing is written to disk twice.
///
/// **2. The player is created only when the user asks for it.** A controller reaches into the native
/// layer, which does not exist in a widget test — a card that built one eagerly would blow up every
/// existing test that happens to render a video attachment. Lazily is also simply correct: a
/// transcript scrolled past ten clips must not start ten decoders.
///
/// **3. The implementation is chosen per platform, the API is not.** This file only ever names the
/// official `video_player`; macOS resolves that to AVFoundation, Windows/Linux to FVP (registered in
/// main()). Nothing here knows which — that is the whole point of picking an endorsed API.
///
/// 一族卡的内联视频播放(H5.5,H5.5R / ADR 0018 换底座)。
///
/// 有三条约束塑造了这个 widget,而三条都是**跑出来**的:
///
/// **1. 沙箱化的 macOS app 不能把任意文件路径交给原生播放器。** entitlements 只授了
/// `files.user-selected.read-only`,故 `/private/tmp` 下的东西——或任何不是用户亲手挑的路径——一律被拒。
/// 而 loopback HTTP 是**本来就开着**的那条通道(`network.client`,为让 app 够得着自己的 sidecar 而授),
/// 故播放器就像本应用其余每一次读取那样,从 sidecar **流式**拉这份附件。20MB 的片子在下完之前就开播,
/// 且没有任何字节被写两遍盘。
///
/// **2. 播放器只在用户开口时才创建。** controller 要伸到原生层,而 widget test 里没有那一层——一个急切
/// 构造它的卡片,会炸掉每一个恰好渲到视频附件的既有测试。惰性也**本就正确**:一份滚过十段片子的
/// transcript,不该起十个解码器。
///
/// **3. 实现按平台选,API 不选。** 本文件从头到尾只叫得出官方 `video_player` 这一个名字;macOS 把它解析
/// 成 AVFoundation,Windows/Linux 解析成 FVP(在 main() 里注册)。这里**不知道**是哪一个——选一个官方
/// 背书 API 的全部意义就在这儿。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:video_player/video_player.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/icons.dart';
import 'media_source.dart';

/// Selects the `video_player` implementation for the platforms the official one does not cover.
/// Must run after the binding and before any controller is built — every launch surface that can
/// render a media attachment calls it, which is all of them except onboarding.
///
/// **macOS and iOS are absent BY CONSTRUCTION, not by a flag.** There the endorsed AVFoundation
/// implementation already answers with the system decoder, and — this is the part that took two
/// attempts to get right — the packages that carry native code declare ONLY their own platform
/// (`video_player_win` → windows, `media_kit_libs_linux` → linux), so nothing they carry is even
/// linked into a macOS build. The bridge itself is pure Dart.
///
/// The first attempt used one all-platforms package and filtered platforms in Dart. That filter is
/// real, but it only chooses which implementation Dart REGISTERS — it does not stop Flutter from
/// linking the plugin's framework. The macOS bundle silently carried 26MB of unused decoder, and
/// that decoder's weak-linked optional ffmpeg resolved against whatever the user happened to have
/// installed via Homebrew: an app whose loaded libraries depend on the machine it runs on
/// (ADR 0018).
///
/// 为官方实现覆盖不到的平台选定 `video_player` 实现。必须在 binding 之后、任何 controller 构造之前跑
/// ——每个可能渲媒体附件的启动面都调它,除 onboarding 外的全部。
///
/// **macOS 与 iOS 不在这里,是「结构上就不在」、不是靠一个开关。** 那里官方背书的 AVFoundation 实现用
/// 系统解码器答上了;而——**这一点花了两次才做对**——带原生代码的包**只声明自己的平台**
/// (`video_player_win` → windows,`media_kit_libs_linux` → linux),故它们带的东西**根本不会被链进**
/// macOS 构建。桥接本身是纯 Dart。
///
/// 第一次尝试用了一个「全平台」包、在 Dart 里过滤平台。那个过滤是真的,但它只决定 Dart **注册**哪个实现
/// ——**拦不住** Flutter 去链那个插件的 framework。于是 macOS 包里静默多了 26MB 用不到的解码器,而那个
/// 解码器 weak 链接的可选 ffmpeg,会被解析到用户机器上碰巧用 Homebrew 装着的那份:**一个「加载了哪些库
/// 取决于它跑在谁的机器上」的 app**(ADR 0018)。
void initMediaPlayback() => VideoPlayerMediaKit.ensureInitialized(linux: true);

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
  VideoPlayerController? _controller;
  bool _starting = false;

  @override
  void dispose() {
    // The controller owns a native handle; letting it outlive the widget leaks a decoder per card
    // the user ever pressed play on.
    // controller 持一个原生句柄;让它活得比 widget 久,等于用户每按过一次播放就漏一个解码器。
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _controller != null) return;
    setState(() => _starting = true);
    final target = ref
        .read(mediaSourceProvider)
        .nativeTarget(widget.attachmentId);
    // The headers are NOT optional: the sidecar is loopback-hardened (RequireBearerToken), so a bare
    // GET is refused. The player does its own fetching, which is exactly why it must be told.
    // 这些头**不是可选的**:sidecar 做了 loopback 加固(RequireBearerToken),裸 GET 会被拒。播放器自己
    // 去取,这正是必须告诉它的原因。
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(target.uri),
      httpHeaders: target.headers,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() {
        _controller = controller;
        _starting = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _starting = false);
    }
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
              aspectRatio: controller?.value.aspectRatio ?? 16 / 9,
              child: controller == null ? _poster(c) : VideoPlayer(controller),
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
