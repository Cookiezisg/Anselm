import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/attachment_image_provider.dart';
import '../data/chat_providers.dart';
import '../state/attachment_meta.dart';
import '../state/exhibit_provider.dart';
import '../state/touchpoint_ledger.dart';
import '../state/transcript_jump_provider.dart';
import 'tool_card_nav.dart';

/// The exhibit stage (WRK-061 exhibit mode) — a Cast row pinned onto the sidestage as SETTLED truth.
/// An `attachment` gets the 展品座 (exhibit pedestal): the museum-light entrance (opacity 0→1 +
/// scale 0.97→1), kind icon + filename at the emphasis weight + byte size + the sha256 prefix in
/// mono («content-addressed fingerprint»), an image renders its real thumbnail. No settle concept —
/// the exhibit IS the truth. Entity kinds get the identity face: kind glyph + name + id mono +
/// the row's verb history + last-touch time; a tombstone renders statically (never a GET). Both
/// faces carry the two navigation actions (jump-to-occurrence / open entity, each honestly hidden
/// when it has no target).
///
/// 展品舞台(WRK-061 exhibit mode)——Cast 行钉上侧幕的**落定真相**。attachment 得**展品座**:美术馆
/// 开灯入场(opacity 0→1 + scale 0.97→1),kind 图标+文件名(加粗档)+字节数+sha256 前缀 mono(「内容
/// 寻址指纹」),图片渲真缩略图。无落定概念——展品即真相。实体 kind 得身份面:kind 字形+名+id mono+
/// 该行动词史+最后触碰时刻;墓碑静态渲(绝不 GET)。两面都带双导航动作(跳到发生处/去实体页,无标的
/// 即诚实隐藏)。
class ExhibitStage extends ConsumerWidget {
  const ExhibitStage({required this.conversationId, required this.subject, super.key});

  final String conversationId;
  final ExhibitSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AnSpace.s12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(AnIcons.entityKindGlyph(subject.kind), size: AnSize.iconSm, color: c.inkMuted),
          const SizedBox(width: AnSpace.s6),
          Expanded(
            child: Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subject.tombstoned
                  ? AnText.label.copyWith(
                      color: c.inkFaint, decoration: TextDecoration.lineThrough, decorationColor: c.inkFaint)
                  : AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink),
            ),
          ),
          if (subject.lastMessageId.isNotEmpty)
            AnButton.iconOnly(
              AnIcons.locate,
              size: AnButtonSize.sm,
              semanticLabel: t.chat.stage.jumpToScene,
              onPressed: () => ref
                  .read(transcriptJumpProvider(conversationId).notifier)
                  .request(subject.lastMessageId),
            ),
          if (hasPanelFor(subject.kind) && !subject.tombstoned)
            AnButton.iconOnly(
              AnIcons.open,
              size: AnButtonSize.sm,
              semanticLabel: t.chat.stage.goToEntity,
              onPressed: () => toolNavTo(context, subject.kind, subject.id),
            ),
          AnButton.iconOnly(
            AnIcons.close,
            size: AnButtonSize.sm,
            semanticLabel: t.chat.stage.title,
            onPressed: () => ref.read(exhibitProvider(conversationId).notifier).dismiss(),
          ),
        ]),
        const SizedBox(height: AnSpace.s8),
        if (subject.kind == 'attachment')
          _AttachmentPedestal(conversationId: conversationId, attachmentId: subject.id)
        else
          _IdentityFace(conversationId: conversationId, subject: subject),
      ]),
    );
    // The museum-light entrance — one-shot, reduced-motion collapses to the end state. 开灯入场。
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(scale: 0.97 + 0.03 * v, child: child),
      ),
      child: body,
    );
  }
}

/// The attachment 展品座 — the still-life card: real thumbnail for an image, meta rows, the sha256
/// prefix as the content-addressed fingerprint. 附件展品座:静物卡。
class _AttachmentPedestal extends ConsumerWidget {
  const _AttachmentPedestal({required this.conversationId, required this.attachmentId});

  final String conversationId;
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
              AnKvRow('size', fmtBytes(m.sizeBytes)),
              if (m.mimeType.isNotEmpty) AnKvRow('mime', m.mimeType, mono: true),
              if (m.sha256.isNotEmpty)
                AnKvRow('sha256',
                    m.sha256.substring(0, m.sha256.length < 8 ? m.sha256.length : 8), mono: true),
            ]),
          ],
        ),
      AsyncError() => Text(Translations.of(context).chat.stage.tombstone,
          style: AnText.meta.copyWith(color: c.inkFaint)),
      _ => const AnSkeleton.lines(2),
    };
  }

  static String fmtBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// The entity identity face — the Cast row's aggregation unfolded: every verb with its count and
/// last-touch time. Settled-truth deep rendering rides the entity page (去实体页). 身份面:动词史陈列。
class _IdentityFace extends ConsumerWidget {
  const _IdentityFace({required this.conversationId, required this.subject});

  final String conversationId;
  final ExhibitSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final ledger = ref.watch(touchpointLedgerProvider(conversationId));
    final entity =
        ledger.entities.where((e) => e.kind == subject.kind && e.key == subject.id).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      AnKv(dense: true, rows: [
        AnKvRow('id', subject.id, mono: true),
        if (entity != null)
          for (final r in entity.byVerb.values)
            AnKvRow(
              AnCastRow.verbWord(t, r.verb),
              r.count > 1
                  ? '×${r.count} · ${AnCastRow.timeLabel(context, r.lastAt)}'
                  : AnCastRow.timeLabel(context, r.lastAt),
            ),
      ]),
      if (subject.tombstoned)
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s4),
          child: Text(t.chat.stage.tombstone, style: AnText.meta.copyWith(color: c.danger)),
        ),
    ]);
  }
}
