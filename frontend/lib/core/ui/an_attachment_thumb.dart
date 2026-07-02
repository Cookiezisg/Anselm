import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_attachment_card.dart' show AnAttachmentState;
import 'an_interactive.dart';
import 'icons.dart';

/// The thumb's two size registers. 瓦片两档。
enum AnThumbVariant {
  /// The message's only image: bounded [AnSize.thumbMaxW]×[AnSize.thumbMaxH], aspect preserved. 单图。
  single,

  /// One of several: a square [AnSize.thumbTile] tile, cover-cropped. 多图方瓦片。
  tile,
}

/// A sent-image THUMBNAIL (chat user bubble): a real decoded image, rounded [AnRadius.button] (one notch
/// under the bubble's radius — correct optical nesting). The [image] provider comes from the caller (the
/// resolver later; dev fixtures pass MemoryImage) — this widget performs NO network I/O itself. States:
/// resolving → a calm skeleton slab; failed → a surface slab with the image glyph (tap retries via
/// [onTap]); ready → the image ([onTap] reserved for a future lightbox / right-island). Decode errors
/// degrade to the failed slab via [Image.errorBuilder]. [filename] is the a11y alt.
///
/// 已发送图片缩略(用户泡内):真图,圆角 button(比泡小一档,光学嵌套正确)。ImageProvider 由调用方给(解析器
/// 后建;dev 走 MemoryImage)——本件自身零网络。态:resolving→安静骨架板;failed→surface 板+图片字形(点按
/// 经 onTap 重试);ready→图(onTap 留给未来 lightbox/右岛)。解码错误经 errorBuilder 降级为 failed 板。
/// filename 作 a11y alt。
class AnAttachmentThumb extends StatelessWidget {
  const AnAttachmentThumb({
    required this.image,
    required this.filename,
    this.variant = AnThumbVariant.tile,
    this.state = AnAttachmentState.ready,
    this.onTap,
    super.key,
  });

  /// Decoded-image source; null while resolving / after a failed fetch. 图源;在途/失败时为 null。
  final ImageProvider? image;

  /// The a11y alt text (the attachment's filename). 无障碍 alt(文件名)。
  final String filename;
  final AnThumbVariant variant;
  final AnAttachmentState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = state == AnAttachmentState.ready && image != null;
    final Widget child;
    if (ready) {
      child = Image(
        image: image!,
        fit: variant == AnThumbVariant.tile ? BoxFit.cover : BoxFit.scaleDown,
        errorBuilder: (ctx, _, _) => _slab(ctx.colors), // decode error → failed slab 解码错→失败板
      );
    } else if (state == AnAttachmentState.resolving) {
      child = ColoredBox(color: c.skeletonBase); // calm bone, no sweep (transient) 安静骨,无扫光
    } else {
      child = _slab(c);
    }

    final sized = variant == AnThumbVariant.tile
        ? SizedBox(width: AnSize.thumbTile, height: AnSize.thumbTile, child: child)
        : ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AnSize.thumbMaxW,
              maxHeight: AnSize.thumbMaxH,
              minWidth: AnSize.thumbTile,
              minHeight: AnSize.thumbTile,
            ),
            child: child,
          );
    final clipped = ClipRRect(borderRadius: BorderRadius.circular(AnRadius.button), child: sized);

    final tappable = onTap != null && (ready || state == AnAttachmentState.failed);
    if (!tappable) {
      return Semantics(image: true, label: filename, child: ExcludeSemantics(child: clipped));
    }
    return MergeSemantics(
      child: Semantics(
        image: true,
        label: filename,
        child: AnInteractive(
          onTap: onTap,
          builder: (ctx, states) => ExcludeSemantics(child: clipped),
        ),
      ),
    );
  }

  // The failed/fallback slab: a bordered surface with the image glyph — honest, never a broken-image tear.
  // 失败/兜底板:描边 surface + 图片字形——诚实,不渲染破图。
  Widget _slab(AnColors c) => DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.button),
        ),
        child: Center(child: Icon(AnIcons.image, size: AnSize.iconLg, color: c.inkFaint)),
      );
}
