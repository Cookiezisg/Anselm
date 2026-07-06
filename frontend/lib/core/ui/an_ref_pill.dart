import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// The target of a reference tap: the entity [kind] + its [id]. 提及目标:实体 kind + id。
typedef AnRefTarget = ({String kind, String id});

/// A3 — an inline entity-mention pill: kind glyph + label, optionally tappable. Mirrors the demo's
/// `<an-ref-pill>`: the icon resolves from [kind] via [AnIcons.byKey] (the kit's single kind→glyph
/// source — open, with a visible "?" fallback, NOT a re-copied map), so an unknown / forward kind
/// still renders. A non-empty [id] makes it a tappable mention coordinate (click cursor, hover-tint,
/// emits the {kind,id} target via [onTap] for the assembly layer to turn into a select intent — the
/// primitive never touches navigation); an empty / null [id] is a plain annotation (not focusable,
/// keyboard passes through). Caps at [AnSize.block] and ellipsis-truncates, so a long name can't blow
/// out a line; the [ConstrainedBox] bound also makes it safe inline in an unbounded-width context.
///
/// a11y: one node labelled "{kind}: {name}" (kind localized via i18n for known kinds, raw string for
/// open/unknown — WCAG 1.4.1, kind not by glyph alone); the icon is decorative (the whole visual is
/// [ExcludeSemantics], the outer [Semantics] carries the label). Interactive = button via [AnInteractive].
///
/// [kind] is the backend EntityKind wire value (relation/entitykind.go — `document` not `doc`,
/// incl. control/approval); [AnIcons.byKey] + the `ref.*` i18n both speak that vocabulary, so the
/// assembly layer passes the wire kind straight through (no normalization). The set is open — an
/// unknown kind still renders ("?" glyph + raw word).
///
/// A3——行内实体提及药丸:类型图标 + 文案,可点。kind = 后端 EntityKind 线缆值(document 非 doc,含 control/approval);
/// 图标由 kind 经 AnIcons.byKey 解析(kit 单源、开放 + "?" 兜底、不另抄表),
/// 未知/前向 kind 也能渲。id 非空 = 可点坐标(手型、hover 提墨、经 onTap 派 {kind,id} 供装配层转 select,原语不碰导航);
/// id 空 = 纯标注(不可聚焦、键盘穿透)。封顶 AnSize.block、超长省略,长名挤不破行;ConstrainedBox 界也让它在无界父下安全。
/// a11y:单节点标「{类型}: {名称}」(已知 kind 走 i18n、开放 kind 原样——WCAG 1.4.1 类型不靠字形单独);图标装饰、整 visual 排除语义、外层 Semantics 承载标签。
class AnRefPill extends StatelessWidget {
  const AnRefPill({required this.kind, required this.label, this.id, this.onTap, super.key});

  final String kind;
  final String label;

  /// Non-empty = a tappable mention coordinate; empty / null = a plain annotation. 非空=可点坐标;空=纯标注。
  final String? id;
  final ValueChanged<AnRefTarget>? onTap;

  // [id] is the sole interactivity gate: a non-empty id makes a tappable coordinate. A null/empty id
  // intentionally swallows [onTap] (a mention with no resolved target isn't navigable). id 是唯一交互闸门:空 id 故意吞掉 onTap。
  bool get _interactive => id != null && id!.isNotEmpty && onTap != null;

  // Localized kind word for the a11y prefix ("Agent: deploy-bot"). Cases = the backend EntityKind wire
  // (relation/entitykind.go: 'document' not 'doc', incl. control/approval) — the contract source of
  // truth, NOT the demo's icon-alias vocab. Unknown kind → raw string (the set is open, degrade
  // gracefully). 类型词(a11y 前缀):case = 后端 EntityKind 线缆值(事实源,非 demo 图标别名);未知 kind 原样(开放集降级)。
  String _kindWord(BuildContext context) {
    final r = context.t.ref;
    switch (kind.toLowerCase()) {
      case 'function':
        return r.function;
      case 'handler':
        return r.handler;
      case 'workflow':
        return r.workflow;
      case 'agent':
        return r.agent;
      case 'document':
      case 'doc': // demo alias for the same entity 文档(demo 别名)
        return r.document;
      case 'conversation':
        return r.conversation;
      case 'skill':
        return r.skill;
      case 'mcp':
        return r.mcp;
      case 'trigger':
        return r.trigger;
      case 'control':
        return r.control;
      case 'approval':
        return r.approval;
      default:
        return kind;
    }
  }

  @override
  Widget build(BuildContext context) {
    final semLabel = '${_kindWord(context)}: $label';
    if (!_interactive) {
      // Plain annotation: a single labelled node, not focusable (keyboard passes through). 纯标注。
      return Semantics(
        label: semLabel,
        child: ExcludeSemantics(child: _pill(context, active: false)),
      );
    }
    // Tappable: AnInteractive gives button/focus/Enter-Space; outer label + MergeSemantics → "{kind}: {name}, button".
    return MergeSemantics(
      child: Semantics(
        label: semLabel,
        child: AnInteractive(
          onTap: () => onTap!((kind: kind, id: id!)),
          builder: (ctx, states) => ExcludeSemantics(child: _pill(ctx, active: states.isActive)),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, {required bool active}) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.block),
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : AnMotion.fast, // hover-tint = functional micro-feedback 功能性微反馈
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6, vertical: AnSpace.s2),
        decoration: BoxDecoration(
          // Resting bg is the opaque island (demo --island), hover → island-3 — both light, no whenActive
          // (that fades FROM transparent, for transparent-resting rows). 静止=不透明白底,hover→提墨;非 whenActive。
          color: active ? c.surfaceHover : c.surface,
          border: Border.all(color: c.line, width: AnSize.hairline),
          borderRadius: BorderRadius.circular(AnRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AnIcons.entityKindGlyph(kind), size: AnSize.iconSm, color: c.inkFaint),
            const SizedBox(width: AnSpace.s4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                // body 13 · emphasis w400 via .weight() (the VF double-axis idiom — a bare
                // fontWeight is overridden by the pinned wght axis). body 13·w400,双轴重定权。
                style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: active ? c.ink : c.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
