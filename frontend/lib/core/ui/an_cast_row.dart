import 'package:flutter/widgets.dart';

import '../contract/touchpoint.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../../i18n/strings.g.dart';
import 'an_button.dart';
import 'an_status_dot.dart';
import 'an_tooltip.dart';
import 'an_freshness_halo.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// One Cast (演员表) row — the R-2 ENTITY view of the touchpoint ledger (WRK-061 §6-④): kind glyph
/// (with the freshness halo), display name (w400; tombstoned = struck + faint), the freshest verb as a
/// micro-word, the OTHER verbs as a micro-glyph sequence, a ×count superscript when the primary verb
/// repeated, and the relative time. [pulsing] marks the director's CURRENT SUBJECT (R-6: driven by the
/// subject's itemId, never by ledger rows) with a soft accent dot on the left edge. Pure props — the
/// ledger/aggregation lives in the provider.
///
/// 演员表一行——台账的 R-2 实体视图:kind 字形(带新鲜度晕)、显示名(w400;墓碑=划线+灰)、最新动词微词、
/// 其余动词微字形序列、主动词 ×count 上标、相对时间。[pulsing]=导演器当前主角(R-6:主角 itemId 驱动,
/// 非台账行)左缘柔 accent 点。纯 prop——聚合在 provider。
class AnCastRow extends StatelessWidget {
  const AnCastRow({
    required this.kind,
    required this.name,
    required this.verb,
    this.count = 1,
    this.secondaryVerbs = const [],
    required this.lastAt,
    this.tombstoned = false,
    this.pulsing = false,
    this.nameIsRawId = false,
    this.onTap,
    this.onJump,
    this.onNav,
    super.key,
  });

  final String kind;
  final String name;
  final TouchpointVerb verb;
  final int count;
  final List<TouchpointVerb> secondaryVerbs;
  final DateTime lastAt;
  final bool tombstoned;
  final bool pulsing;

  /// The name snapshot never resolved — [name] is the raw id (render mono + faint). 名未解出,裸 id。
  final bool nameIsRawId;

  final VoidCallback? onTap;

  /// 「跳到发生处」— revealed on hover/focus in the time slot; null (no lastMessageId) = hidden.
  /// 跳到发生处——hover/focus 时替换时间位;null(无 lastMessageId)= 藏。
  final VoidCallback? onJump;

  /// 「去实体页」— revealed beside [onJump]; null (no panel for this kind) = hidden.
  /// 去实体页——与 onJump 并列露出;null(该 kind 无面板)= 藏。
  final VoidCallback? onNav;

  static String verbWord(Translations t, TouchpointVerb v) => switch (v) {
    TouchpointVerb.mentioned => t.feedback.cast.verb.mentioned,
    TouchpointVerb.created => t.feedback.cast.verb.created,
    TouchpointVerb.edited => t.feedback.cast.verb.edited,
    TouchpointVerb.viewed => t.feedback.cast.verb.viewed,
    TouchpointVerb.executed => t.feedback.cast.verb.executed,
    TouchpointVerb.attached => t.feedback.cast.verb.attached,
    TouchpointVerb.deleted => t.feedback.cast.verb.deleted,
    TouchpointVerb.unknown => t.feedback.cast.verb.unknown,
  };

  /// A verb's micro-glyph (the secondary sequence). 动词微字形。
  static IconData verbGlyph(TouchpointVerb v) => switch (v) {
    TouchpointVerb.mentioned => AnIcons.chat,
    TouchpointVerb.created => AnIcons.forge,
    TouchpointVerb.edited => AnIcons.edit,
    TouchpointVerb.viewed => AnIcons.doc,
    TouchpointVerb.executed => AnIcons.run,
    TouchpointVerb.attached => AnIcons.attach,
    TouchpointVerb.deleted => AnIcons.trash,
    TouchpointVerb.unknown => AnIcons.tool,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final freshness = tombstoned ? AnFreshness.aged : freshnessOf(lastAt);
    final ink = tombstoned ? c.inkFaint : freshnessInk(freshness, c);
    final nameStyle = nameIsRawId
        ? AnText.code.copyWith(color: c.inkFaint)
        : AnText.body
              .weight(AnText.emphasisWeight)
              .copyWith(
                color: ink,
                decoration: tombstoned ? TextDecoration.lineThrough : null,
                decorationColor: c.inkFaint,
              );
    return AnInteractive(
      onTap: onTap,
      builder: (ctx, states) => Container(
        height: AnSize.row,
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        decoration: BoxDecoration(
          color: states.isActive ? c.surfaceHover : null,
          borderRadius: BorderRadius.circular(AnRadius.button),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            // Below ~230px the rigid tail can't coexist with any name — shed decorations. 窄档舍装饰件。
            final tight = box.maxWidth < 265;
            return Row(
              children: [
                // The subject pulse (R-6) — a static soft dot; breath belongs to the stage, not each row.
                // 主角点(R-6)——静态柔点;呼吸归舞台,不逐行。
                SizedBox(
                  width: AnSpace.s6,
                  child: pulsing
                      ? Center(
                          child: AnStatusDot.raw(c.accent, size: AnSize.dotSm),
                        )
                      : null,
                ),
                const SizedBox(width: AnSpace.s4),
                AnFreshnessHalo(
                  freshness: freshness,
                  child: Icon(
                    AnIcons.entityKindGlyph(kind),
                    size: AnSize.iconSm,
                    color: ink,
                  ),
                ),
                const SizedBox(width: AnSpace.s6),
                // Expanded (not Flexible+Spacer): the name yields ALL slack first, so the rigid tail (verb,
                // count, badges, time) never overflows a narrow row (AnRow precedent). 名先让位,刚性尾不溢。
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nameStyle,
                  ),
                ),
                const SizedBox(width: AnSpace.s6),
                // Graded degradation (kit idiom): tight rows shed the micro-badges first, then count — the
                // verb word and the time survive to the narrowest. 分级降显:窄行先舍微徽再舍 count;动词+时间恒在。
                Text(
                  tombstoned ? t.feedback.cast.tombstone : verbWord(t, verb),
                  style: AnText.meta.copyWith(
                    color: tombstoned ? c.danger : c.inkFaint,
                  ),
                ),
                if (count > 1 && !tight)
                  Padding(
                    padding: const EdgeInsets.only(left: AnSpace.s2),
                    child: Text(
                      '×$count',
                      style: AnText.meta.copyWith(color: c.inkFaint),
                    ),
                  ),
                if (secondaryVerbs.isNotEmpty && !tight) ...[
                  const SizedBox(width: AnSpace.s4),
                  for (final v in secondaryVerbs.take(2))
                    Padding(
                      padding: const EdgeInsets.only(left: AnSpace.s2),
                      child: Icon(
                        verbGlyph(v),
                        size: AnSize.iconXs,
                        color: c.inkFaint,
                      ),
                    ),
                ],
                const SizedBox(width: AnSpace.s6),
                // The tail slot: the relative time at rest; hover/focus swaps in the two micro-actions
                // (jump-to-occurrence / open entity) so the row width never shifts. 尾位:静息=相对时间;
                // hover/focus 换上两枚微动作(跳到发生处/去实体页),行宽零位移。
                if (states.isActive && (onJump != null || onNav != null))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onJump != null)
                        _microAction(
                          context,
                          AnIcons.locate,
                          t.feedback.cast.jumpToScene,
                          onJump!,
                        ),
                      if (onNav != null)
                        _microAction(
                          context,
                          AnIcons.open,
                          t.feedback.cast.goToEntity,
                          onNav!,
                        ),
                    ],
                  )
                else
                  Text(
                    timeLabel(context, lastAt),
                    style: AnText.meta.copyWith(color: c.inkFaint),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Relative time, reusing the rail's calendar-day formatter + chat.time strings. 相对时间(复用 rail)。
  Widget _microAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) => AnTooltip(
    message: label,
    child: AnButton.iconOnly(
      icon,
      size: AnButtonSize.sm,
      onPressed: onTap,
      semanticLabel: label,
    ),
  );

  static String timeLabel(BuildContext context, DateTime at) {
    final t = Translations.of(context);
    final now = DateTime.now();
    final local = at.toLocal();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(local.year, local.month, local.day)).inDays;
    if (days <= 0) {
      final mins = now.difference(local).inMinutes;
      if (mins < 1) return t.chat.time.justNow;
      if (mins < 60) return t.chat.time.minutesAgo(n: mins);
      return t.chat.time.hoursAgo(n: now.difference(local).inHours);
    }
    if (days == 1) return t.chat.time.yesterday;
    if (days <= 7) return t.chat.time.daysAgo(n: days);
    return '${local.year}/${local.month}/${local.day}';
  }
}
