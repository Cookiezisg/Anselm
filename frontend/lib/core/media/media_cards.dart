import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_attachment_card.dart';
import 'attachment_image_provider.dart';
import 'media_ref.dart';
import 'media_source.dart';
import 'media_video.dart';

/// The ONE card family every surface renders a MediaRef with (WRK-082 批B' 不变量④). Dispatch is by
/// MIME, resolved from the attachment row — never from the receipt's hint and never per-surface:
/// images render inline, everything else falls back to the kit's file card with the right glyph.
/// Chat's tool card, the flowrun node inspector, the entity debug console and approval rendering all
/// consume this, so an artifact looks the same wherever it surfaces.
///
/// 各面渲 MediaRef 的**唯一**卡族(批B' 不变量④)。按 **MIME** 分发,取自附件行——不取 receipt 的提示、
/// 更不逐面自定:图内联渲,其余回落 kit 的文件卡配对应字形。chat 工具卡、flowrun 节点检查器、实体调试台、
/// approval 渲染同吃这一族,故同一件产物在哪儿露面都长一个样。
class AnMediaRefCard extends ConsumerWidget {
  const AnMediaRefCard({
    required this.mediaRef,
    this.maxWidth = 320,
    super.key,
  });

  final AnMediaRef mediaRef;

  /// Widest the inline image renders — also the decode cap (a 4000px artifact must not park a
  /// full-size bitmap in the global image cache for a 320px slot).
  ///
  /// 内联图最宽档,同时是**解码**上限(4000px 产物不得为一个 320px 槽位在全局图缓存里停一张全尺寸位图)。
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = mediaRef.attachmentId;
    final meta = ref.watch(mediaMetaProvider(id));
    final c = context.colors;

    // hasError, not the AsyncError class pattern: Riverpod auto-retries a failed provider and the
    // state flips back to AsyncLoading inside each retry window — the class pattern would flicker
    // the honest line back into a placeholder forever. hasError stays true across retries.
    // 用 hasError 而非 AsyncError 类模式:失败 provider 会自动重试,重试窗内状态又变回 AsyncLoading——
    // 类模式会让诚实行永远闪回占位。hasError 跨重试恒真。
    if (meta.hasError) {
      // The attachment row is the truth; a row we cannot read is said out loud, never a broken image.
      // 附件行是真相;读不到的行明说,绝不渲一张破图。
      return Text(id, style: AnText.label.copyWith(color: c.inkFaint));
    }

    return switch (meta) {
      AsyncData(value: final m) when m.mimeType.startsWith('image/') => _image(
        context,
        ref,
        filename: m.filename,
        sizeBytes: m.sizeBytes,
      ),
      // Video plays INLINE (WRK-082 H5.5) — the player is built only on tap, so a transcript
      // scrolled past ten clips starts zero libmpv instances and a widget test never touches the
      // native layer at all.
      // 视频**内联播放**(H5.5)——播放器只在点击时才建,故一份滚过十段片子的 transcript 起零个 libmpv,
      // 而 widget test 根本碰不到原生层。
      AsyncData(value: final m) when m.mimeType.startsWith('video/') =>
        AnVideoCard(
          attachmentId: id,
          filename: m.filename,
          metaLine: _metaLine(m.mimeType, m.sizeBytes),
          maxWidth: maxWidth,
        ),
      AsyncData(value: final m) => AnAttachmentCard(
        kind: m.kind,
        filename: m.filename.isEmpty ? id : m.filename,
        metaLine: _metaLine(m.mimeType, m.sizeBytes),
      ),
      _ => _placeholder(c),
    };
  }

  Widget _image(
    BuildContext context,
    WidgetRef ref, {
    required String filename,
    required int sizeBytes,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AnRadius.button),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Image(
              image: AttachmentImageProvider(
                mediaRef.attachmentId,
                fetch: () =>
                    ref.read(mediaSourceProvider).bytes(mediaRef.attachmentId),
                targetWidth: (maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .round(),
              ),
              fit: BoxFit.contain,
              // Hold layout with the receipt's own aspect while bytes stream in — the hint exists
              // precisely so the surrounding panel never jumps when pixels land.
              // 字节在途时按 receipt 自带比例占位——提示的存在就是为了像素落地时四周面板不跳。
              frameBuilder: (context, child, frame, wasSync) {
                if (frame != null || wasSync) return child;
                return _placeholder(c);
              },
              errorBuilder: (context, _, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
                child: Text(
                  filename.isEmpty ? mediaRef.attachmentId : filename,
                  style: AnText.label.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AnSpace.s4),
        Text(
          _metaLine('', sizeBytes, filename: filename),
          style: AnText.label.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }

  Widget _placeholder(AnColors c) {
    final w = mediaRef.width, h = mediaRef.height;
    final ratio = (w != null && h != null && w > 0 && h > 0) ? w / h : 1.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AspectRatio(
        aspectRatio: ratio,
        child: ColoredBox(color: c.surfaceSubtle),
      ),
    );
  }

  String _metaLine(String mime, int sizeBytes, {String? filename}) {
    final parts = <String>[];
    if (filename != null && filename.isNotEmpty) parts.add(filename);
    if (mime.isNotEmpty) parts.add(mime);
    final w = mediaRef.width, h = mediaRef.height;
    if (w != null && h != null && w > 0 && h > 0) parts.add('$w×$h');
    if (sizeBytes > 0) parts.add(_size(sizeBytes));
    return parts.join(' · ');
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Every MediaRef inside one payload, rendered as the family. Renders NOTHING when the payload
/// carries none — a surface can hand its whole result JSON here unconditionally without paying a
/// layout, an empty section header, or a decision it would otherwise have to duplicate.
///
/// 一个 payload 里的全部 MediaRef,按族渲出。payload 里没有时**什么都不渲**——各面可以无条件把整份结果
/// JSON 递进来,不必为此付一段版面、一个空段头,或一次它本来要各自重复一遍的判断。
class AnMediaRefStrip extends StatelessWidget {
  const AnMediaRefStrip({
    required this.payload,
    this.maxWidth = 320,
    this.spacing = AnSpace.s8,
    super.key,
  });

  /// Spread-friendly form for hosts whose container puts a gap between children (AnSection, AnRow
  /// stacks): an empty result must contribute NO slot, and a `SizedBox.shrink` in a gapped column
  /// is a visible band of nothing. Walks the payload once.
  ///
  /// 供「子件之间自带间距」的宿主(AnSection、AnRow 栈)展开用:没有引用时不得占一个槽位,而带间距的
  /// 列里一个 `SizedBox.shrink` 就是一条看得见的空带。payload 只走一遍。
  static List<Widget> forPayload(
    Object? payload, {
    double maxWidth = 320,
    double spacing = AnSpace.s8,
  }) {
    if (collectMediaRefs(payload).isEmpty) return const [];
    return [
      AnMediaRefStrip(payload: payload, maxWidth: maxWidth, spacing: spacing),
    ];
  }

  /// Any decoded JSON value (node result, tool result, approval payload …).
  ///
  /// 任意已解码 JSON 值(节点结果 / 工具结果 / approval payload …)。
  final Object? payload;
  final double maxWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final refs = collectMediaRefs(payload);
    if (refs.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final r in refs)
          AnMediaRefCard(
            key: ValueKey(r.attachmentId),
            mediaRef: r,
            maxWidth: maxWidth,
          ),
      ],
    );
  }
}
