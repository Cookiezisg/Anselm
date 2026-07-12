import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_chip.dart';
import 'icons.dart';

/// The target of a reference tap: the entity [kind] + its [id]. 提及目标:实体 kind + id。
typedef AnRefTarget = ({String kind, String id});

/// A3 — an entity-mention pill, since WRK-066 批5 a THIN PRESET over the chip family head
/// ([AnChip], outlined look): its own knowledge is only the kind→glyph resolution
/// ([AnIcons.entityKindGlyph], the kit's single open source with a visible "?" fallback), the
/// localized kind word for the a11y label ("{kind}: {name}" — WCAG 1.4.1, kind never by glyph
/// alone), and the interactivity GATE: a non-empty [id] makes a tappable mention coordinate
/// (emits {kind,id} via [onTap] for the assembly layer — the primitive never navigates); an
/// empty/null id is a plain annotation that deliberately swallows [onTap].
///
/// [AnRefPill.inline] is the second face: a baseline-hugging capsule for INSIDE running text
/// (editor mentions, [[id]] pilled prose, CEL refs — A-029/030/042). The block chip (22-high box)
/// cannot sit in a text line, so the inline face has its own light shell: soft accent fill, tag
/// radius, the host's text style. Inline is DISPLAY-ONLY chrome — interactivity/IME belongs to the
/// host (super_editor caret hit-testing breaks on nested gesture targets).
///
/// A3——实体提及药丸,批5 起为芯片族当家件(AnChip outlined)的**薄预设**:自有知识仅 kind→字形单源、
/// a11y 类型词表(「{类型}: {名称}」,类型不靠字形单独)与交互闸门(id 非空=可点坐标,经 onTap 派
/// {kind,id};空 id=纯标注、故意吞 onTap)。[AnRefPill.inline]=第二张脸:行内贴基线药囊(编辑器提及/
/// [[id]] 散文/CEL 引用)——22 高块壳进不了文本行,行内脸自持轻壳(accentSoft 底+tag 圆角+宿主字体);
/// **仅展示**,交互/IME 归宿主(嵌套手势会破 super_editor 光标命中)。
class AnRefPill extends StatelessWidget {
  const AnRefPill({required this.kind, required this.label, this.id, this.onTap, super.key})
      : inline = false,
        textStyle = null;

  /// The baseline-hugging in-text face. 行内贴基线脸。
  const AnRefPill.inline({required this.kind, required this.label, this.textStyle, super.key})
      : inline = true,
        id = null,
        onTap = null;

  final String kind;
  final String label;

  /// Non-empty = a tappable mention coordinate; empty / null = a plain annotation. 非空=可点坐标;空=纯标注。
  final String? id;
  final ValueChanged<AnRefTarget>? onTap;

  final bool inline;

  /// Inline face only: the host line's text style (defaults to the reading tier). 行内脸宿主字体。
  final TextStyle? textStyle;

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
    if (inline) return _inline(context);
    final semLabel = '${_kindWord(context)}: $label';
    if (!_interactive) {
      // Plain annotation: a single labelled node, not focusable (keyboard passes through) — the
      // chip head only emits semantics on interactive chips. 纯标注:单节点标签、不可聚焦。
      return Semantics(
        label: semLabel,
        child: ExcludeSemantics(
          child: AnChip(label, look: AnChipLook.outlined, icon: AnIcons.entityKindGlyph(kind)),
        ),
      );
    }
    return AnChip(
      label,
      look: AnChipLook.outlined,
      icon: AnIcons.entityKindGlyph(kind),
      onTap: () => onTap!((kind: kind, id: id!)),
      semanticLabel: semLabel,
    );
  }

  // The baseline capsule: soft accent fill + tag radius + the host's text style — collapses the
  // three hand-rolled in-text pills (editor mention / [[id]] prose / CEL ref). height:1.0 keeps the
  // capsule from inflating the host line box. 贴基线药囊:收编三处手搓行内伪药丸;height 1.0 不撑行。
  Widget _inline(BuildContext context) {
    final c = context.colors;
    final style = (textStyle ?? AnText.reading).copyWith(color: c.accent, height: 1.0);
    return Semantics(
      label: '${_kindWord(context)}: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4, vertical: AnSize.capsulePadY),
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(AnRadius.tag),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(AnIcons.entityKindGlyph(kind), size: AnSize.iconSm, color: c.accent),
            const SizedBox(width: AnGap.inlineHair),
            Flexible(child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style)),
          ]),
        ),
      ),
    );
  }
}
