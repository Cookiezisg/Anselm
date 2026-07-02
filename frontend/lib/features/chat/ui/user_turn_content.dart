import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_attachment_card.dart';
import '../../../core/ui/an_attachment_thumb.dart';
import '../../../core/ui/an_ref_pill.dart';
import '../model/mention_spans.dart';
import '../model/user_attachment.dart';

/// The user bubble's COMPLETE body — what goes inside `ChatTurn(role: user)` when a message carries more
/// than bare text. Composition (top→bottom, the frontier consensus "materials first, then the ask"):
/// ① image thumbs (a single image bounded large, several as square tiles, ALL shown — no +N hiding on a
/// desktop column), ② file cards (document/text/audio/video/other + any image that can't show bytes:
/// oversized/failed/missing render as honest cards), ③ the text with @mentions as inline [AnRefPill]s at
/// positions derived by [resolveMentionSegments] (frozen send-time names; tapping emits the live {kind,id}
/// — the shell later opens the right island on it). Wrap regions align end (the bubble is right-anchored).
/// Purely presentational: attachments arrive resolved ([UserAttachment]); no I/O here.
///
/// 用户泡的**完整体**——消息带附件/提及时 `ChatTurn(role: user)` 的 child。组成(上→下,前沿共识「先给材料
/// 再提问」):①图瓦片区(单图大而有界、多图方瓦片、**全展示**不藏 +N)②文件卡区(document/text/audio/video/
/// other + 显不出字节的图:超大/失败/missing 诚实渲卡)③提及文本([resolveMentionSegments] 推位、[AnRefPill]
/// 内联;冻结发送时名,点按派活体 {kind,id}——壳层后续接右岛展开)。Wrap 尾对齐(泡右锚)。纯呈现,零 I/O。
class UserTurnContent extends StatelessWidget {
  const UserTurnContent({
    required this.text,
    this.mentions = const [],
    this.attachments = const [],
    this.onMentionTap,
    super.key,
  });

  final String text;
  final List<MentionSnapshot> mentions;
  final List<UserAttachment> attachments;

  /// The live navigation intent off a pill tap; null → pills render but stay inert. 药丸点按意图;null=惰性。
  final ValueChanged<AnRefTarget>? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final thumbs = attachments.where((a) => a.rendersAsThumb).toList(growable: false);
    final cards = attachments.where((a) => !a.rendersAsThumb).toList(growable: false);
    final trimmed = text.trim();

    final sections = <Widget>[
      if (thumbs.isNotEmpty) _thumbRegion(thumbs),
      if (cards.isNotEmpty) _cardRegion(cards),
      if (trimmed.isNotEmpty) _mentionText(context, trimmed),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    // start (NEVER stretch): stretch forces the column — and so the bubble — to the full available
    // width; start lets the bubble hug its widest region. start(绝不 stretch):stretch 会把列/泡撑满可用宽;
    // start 让泡贴最宽的区。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: AnSpace.s8),
          sections[i],
        ],
      ],
    );
  }

  // One image → a large bounded single; several → square tiles, all shown, wrapping. 单图大;多图瓦片全展示。
  Widget _thumbRegion(List<UserAttachment> thumbs) {
    if (thumbs.length == 1) {
      final a = thumbs.single;
      return AnAttachmentThumb(
        image: a.thumb, filename: a.filename, variant: AnThumbVariant.single, onTap: a.onTap,
      );
    }
    return Wrap(
      spacing: AnSpace.s8,
      runSpacing: AnSpace.s8,
      children: [
        for (final a in thumbs)
          AnAttachmentThumb(image: a.thumb, filename: a.filename, onTap: a.onTap),
      ],
    );
  }

  Widget _cardRegion(List<UserAttachment> cards) => Wrap(
        spacing: AnSpace.s8,
        runSpacing: AnSpace.s8,
        children: [
          for (final a in cards)
            AnAttachmentCard(
              kind: a.kind,
              filename: a.filename,
              metaLine: attachmentMetaLine(
                  filename: a.filename, mimeType: a.mimeType, sizeBytes: a.sizeBytes),
              state: a.state,
              onTap: a.onTap,
            ),
        ],
      );

  Widget _mentionText(BuildContext context, String trimmed) {
    final c = context.colors;
    final style = AnText.body.copyWith(color: c.ink);
    final segments = resolveMentionSegments(trimmed, mentions);
    if (segments.length <= 1 && mentions.isEmpty) return Text(trimmed, style: style);
    return Text.rich(
      TextSpan(style: style, children: [
        for (final s in segments)
          switch (s) {
            MentionTextSegment(:final text) => TextSpan(text: text),
            MentionPillSegment(:final snapshot) => WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AnRefPill(
                  kind: snapshot.type,
                  label: snapshot.name,
                  id: snapshot.id,
                  onTap: onMentionTap,
                ),
              ),
          },
      ]),
    );
  }
}
