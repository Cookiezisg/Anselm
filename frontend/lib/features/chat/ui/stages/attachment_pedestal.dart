import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/media/media_ref.dart';
import '../../../../core/media/media_cards.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
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
          // The ONE card family (不变量④) — dispatching on the attachment ROW's mime, exactly as
          // chat's tool card, the flowrun node inspector, the entity console and the document
          // editor do. This used to be a second rendering path that keyed on `kind == 'image'`
          // itself, so a generated CLIP showed up here as three rows of size/mime/sha with no card
          // and no way to watch it — the invariant says the family renders media everywhere, and a
          // surface that grows its own image branch quietly opts out of every future modality
          // (WRK-082 H6).
          // **唯一那族卡**(不变量④)——按附件**行的 mime** 分发,与 chat 工具卡、flowrun 节点检查器、
          // 实体调试台、文档编辑器**完全一样**。这里过去是**第二条**渲染路径、自己认 `kind == 'image'`,
          // 于是一段生成的**片子**在这儿只有 size/mime/sha 三行,没有卡、也没法看——不变量说的是「一族卡
          // 到处渲媒体」,而一个自己长出图像分支的面,等于**静默退出了此后每一个新模态**(H6)。
          AnMediaRefCard(
            mediaRef: AnMediaRef(attachmentId: attachmentId),
            maxWidth: AnSize.thumbMaxW,
          ),
          const SizedBox(height: AnSpace.s8),
          AnKv(
            dense: true,
            rows: [
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
