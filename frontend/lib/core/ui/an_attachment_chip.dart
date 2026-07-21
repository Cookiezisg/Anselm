import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_spinner.dart';
import 'an_attachment_card.dart';
import 'an_button.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// The composer's PENDING-attachment chip — the pre-send counterpart of [AnAttachmentCard] (which
/// renders SENT attachments in the bubble): a compact hairline pill with the kind glyph, one-line
/// filename, a muted meta line, a trailing ✕, and the upload lifecycle — [uploading] swaps the glyph
/// for a spinner; [failed] reds the meta and the CHIP BODY becomes the retry tap target. Sits in
/// [AnComposer]'s `attachments` strip (its presence flips the chrome pill→card).
///
/// composer 待发附件 chip——[AnAttachmentCard](泡内已发)的发送前对应物:发丝边小药丸 = kind 字形 +
/// 单行文件名 + 次墨 meta + 尾部 ✕,带上传生命周期——uploading 字形换转圈;failed meta 变红、**chip 体
/// 即重试点击区**。放 AnComposer 的 attachments 条(有它即 pill→card 形变)。
class AnAttachmentChip extends StatelessWidget {
  const AnAttachmentChip({
    required this.kind,
    required this.filename,
    required this.meta,
    this.uploading = false,
    this.failed = false,
    this.onRetry,
    this.onRemove,
    this.removeLabel,
    super.key,
  });

  /// The backend kind vocabulary (image|document|text|audio|video|other) — picks the glyph via
  /// [AnAttachmentCard.glyph] (one mapping, both surfaces). kind 词表,字形走同一映射。
  final String kind;
  final String filename;

  /// One muted line: size / "Uploading…" / the failed hint — the HOST words it (i18n lives there).
  /// 一行次墨:大小/上传中/失败提示——由宿主措辞(i18n 在宿主)。
  final String meta;
  final bool uploading;
  final bool failed;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  /// a11y label for the remove ✕ — worded by the host (core/ui never hardcodes copy). 移除的读屏文案由宿主给。
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Uploading rides the family spinner (批7 复审 — its orAssistive gate replaces the local
    // reduced-only gate; the host's "Uploading…" meta still carries the state under AT).
    // 上传走族转圈(orAssistive 门替换本地 reduced 门;AT 下状态仍由 meta 文本承载)。
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (uploading)
          const AnSpinner()
        else
          Icon(
            AnAttachmentCard.glyph(kind),
            size: AnSize.icon,
            color: failed ? c.danger : c.inkMuted,
          ),
        const SizedBox(width: AnSpace.s6),
        Flexible(
          child: Text(
            filename,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AnText.body.copyWith(color: c.ink),
          ),
        ),
        const SizedBox(width: AnSpace.s6),
        Flexible(
          child: Text(
            meta,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: AnText.label.copyWith(color: failed ? c.danger : c.inkFaint),
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: AnSpace.s2),
          AnButton.iconOnly(
            AnIcons.close,
            size: AnButtonSize.sm,
            semanticLabel: removeLabel ?? '',
            onPressed: onRemove,
          ),
        ],
      ],
    );
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.chip),
        border: Border.all(
          color: failed ? c.danger : c.line,
          width: AnSize.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AnSpace.s8,
          AnSpace.s4,
          AnSpace.s4,
          AnSpace.s4,
        ),
        child: body,
      ),
    );
    if (!failed || onRetry == null) return chip;
    // Failed: the chip body IS the retry affordance (the ✕ stays remove). failed:chip 体即重试。
    return AnInteractive(onTap: onRetry, builder: (context, _) => chip);
  }
}
