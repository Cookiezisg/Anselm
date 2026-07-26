import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/media/attachment_image_provider.dart';
import '../data/chat_providers.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';
import '../state/attachment_meta.dart';

/// generate_image family body (WRK-082 批B, 代拍 B7): the artifact is a FIRST-CLASS attachment, so
/// this body rides the exact same pipeline the transcript's user attachments use — meta via the
/// kept-alive provider, bytes via the id-keyed image cache, decode capped to the display width.
/// One card family, zero new media primitives (不变量④的第一个工具卡消费者).
///
/// generate_image 族体(批B,代拍 B7):产物是一等附件,本体走 transcript 用户附件的同一条管线——
/// 元数据经 keepAlive provider、字节经按 id 缓存的图源、解码封顶显示宽。一族卡、零新媒体原语
/// (不变量④的第一个工具卡消费者)。
Widget generatedImageBody(BuildContext context, ToolCardState state) {
  final r = parseGeneratedImage(state.resultText);
  if (r == null) return const SizedBox.shrink();
  return _GeneratedImageBody(receipt: r);
}

class _GeneratedImageBody extends ConsumerWidget {
  const _GeneratedImageBody({required this.receipt});

  final ({
    String attachmentId,
    String? mime,
    int? width,
    int? height,
    String? provider,
    String? model,
  })
  receipt;

  /// The widest the artifact renders inside a card body — a deliberate step above the transcript
  /// thumb (the generated image IS the deliverable), still decode-capped to what the slot shows.
  /// 卡体内产物最宽档——刻意高于 transcript 缩略档(生成图就是交付物),解码仍封顶槽位所需。
  static const double _maxW = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = receipt.attachmentId;
    final meta = ref.watch(attachmentMetaProvider(id));
    final c = context.colors;
    // hasError, not the AsyncError class pattern: Riverpod 3 auto-retries a failed provider, and
    // during each retry window the state is AsyncLoading again — the class pattern would flicker
    // the honest line back into a skeleton forever. hasError stays true across retries.
    // 用 hasError 而非 AsyncError 类模式:Riverpod 3 对失败 provider 自动重试,重试窗内状态又是
    // AsyncLoading——类模式会让诚实行永远闪回骨架。hasError 跨重试恒真。
    if (meta.hasError) {
      // The attachment row is the truth; a missing row is said out loud, never a broken image.
      // 附件行是真相;行缺失明说,绝不渲一张破图。
      return Text(id, style: AnText.label.copyWith(color: c.inkFaint));
    }
    return switch (meta) {
      AsyncData(value: final m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AnRadius.button),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxW),
              child: Image(
                image: AttachmentImageProvider(
                  id,
                  fetch: () =>
                      ref.read(chatRepositoryProvider).getAttachmentBytes(id),
                  targetWidth: (_maxW * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
                fit: BoxFit.contain,
                // While bytes stream in, hold layout with the receipt's real aspect so the card
                // never jumps when pixels arrive (dims ride the receipt precisely for this).
                // 字节到达前按 receipt 真实比例占位,像素落地卡不跳(receipt 带尺寸正为此)。
                frameBuilder: (context, child, frame, wasSync) {
                  if (frame != null || wasSync) return child;
                  final w = receipt.width, h = receipt.height;
                  final ratio = (w != null && h != null && w > 0 && h > 0)
                      ? w / h
                      : 1.0;
                  return AspectRatio(
                    aspectRatio: ratio,
                    child: ColoredBox(color: c.surfaceSubtle),
                  );
                },
                errorBuilder: (context, _, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
                  child: Text(
                    m.filename,
                    style: AnText.label.copyWith(color: c.inkMuted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AnSpace.s4),
          Text(
            _metaLine(m.filename),
            style: AnText.label.copyWith(color: c.inkMuted),
          ),
        ],
      ),
      _ => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxW),
        child: AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(color: c.surfaceSubtle),
        ),
      ),
    };
  }

  String _metaLine(String filename) {
    final parts = <String>[filename];
    final w = receipt.width, h = receipt.height;
    if (w != null && h != null && w > 0 && h > 0) parts.add('$w×$h');
    final model = receipt.model;
    if (model != null && model.isNotEmpty) parts.add(model);
    return parts.join(' · ');
  }
}
