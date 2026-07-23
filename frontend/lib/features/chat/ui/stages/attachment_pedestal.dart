import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/byte_format.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/attachment_image_provider.dart';
import '../../data/chat_providers.dart';
import '../../state/attachment_meta.dart';

/// The attachment settled-row body (WRK-064) — the still-life pedestal: an image renders its real
/// thumbnail, then the byte size · mime · the sha256 prefix as the content-addressed fingerprint. An
/// attachment has no stage body / no truth snapshot (it enters via the composer, not a build tool), so
/// it does NOT ride sceneFromTruth; this is its own settled face. A tombstoned / 404 attachment reads
/// «Deleted». 附件落定行:展品座静物卡(图渲缩略图 + 字节·mime·sha256 指纹);附件无 stage body/无真身快照,
/// 不走 sceneFromTruth,自成落定面。
class AttachmentPedestal extends ConsumerWidget {
  const AttachmentPedestal({required this.attachmentId, super.key});

  final String attachmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final meta = ref.watch(attachmentMetaProvider(attachmentId));
    return switch (meta) {
      AsyncData(value: final m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.kind == 'image') ...[
            // The ONE sent-image thumbnail primitive (A-111) — same bounded single-image register
            // as the chat bubble (thumbMaxW×thumbMaxH), decode errors degrade to the honest slab,
            // filename is the a11y alt. 唯一缩略图原语:与用户泡同档单图界(私铸 180 顶退役),解码错降级
            // 诚实板,文件名作 a11y alt。
            AnAttachmentThumb(
              image: AttachmentImageProvider(
                attachmentId,
                fetch: () => ref
                    .read(chatRepositoryProvider)
                    .getAttachmentBytes(attachmentId),
              ),
              filename: m.filename,
              variant: AnThumbVariant.single,
            ),
            const SizedBox(height: AnSpace.s8),
          ],
          AnKv(
            dense: true,
            rows: [
              AnKvRow('size', formatBytes(m.sizeBytes)),
              if (m.mimeType.isNotEmpty)
                AnKvRow('mime', m.mimeType, mono: true),
              if (m.sha256.isNotEmpty)
                AnKvRow(
                  'sha256',
                  m.sha256.substring(
                    0,
                    m.sha256.length < 8 ? m.sha256.length : 8,
                  ),
                  mono: true,
                ),
            ],
          ),
        ],
      ),
      // G10/A3-39 — only a true NOT_FOUND is a tombstone; a transient error must say so (the old
      // face read «已删除» for every failure and the poisoned cache made it permanent). 只有真 404
      // 才是墓碑;瞬时错误要如实说错(旧脸对一切失败渲「已删除」)。
      AsyncError(:final error) => Text(
        '$error'.contains('NOT_FOUND') || '$error'.contains('404')
            ? Translations.of(context).feedback.cast.tombstone
            : Translations.of(context).feedback.cast.loadFailed,
        style: AnText.meta.copyWith(color: c.inkFaint),
      ),
      _ => const AnSkeleton.lines(2),
    };
  }
}
