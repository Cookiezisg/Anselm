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
              ClipRRect(
                borderRadius: BorderRadius.circular(AnRadius.button),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Image(
                    image: AttachmentImageProvider(attachmentId,
                        fetch: () => ref.read(chatRepositoryProvider).getAttachmentBytes(attachmentId)),
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(height: AnSpace.s8),
            ],
            AnKv(dense: true, rows: [
              AnKvRow('size', formatBytes(m.sizeBytes)),
              if (m.mimeType.isNotEmpty) AnKvRow('mime', m.mimeType, mono: true),
              if (m.sha256.isNotEmpty)
                AnKvRow('sha256', m.sha256.substring(0, m.sha256.length < 8 ? m.sha256.length : 8), mono: true),
            ]),
          ],
        ),
      AsyncError() =>
        Text(Translations.of(context).chat.stage.tombstone, style: AnText.meta.copyWith(color: c.inkFaint)),
      _ => const AnSkeleton.lines(2),
    };
  }
}
