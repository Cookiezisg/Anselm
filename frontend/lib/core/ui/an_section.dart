import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_action_group.dart';
import 'an_group_label.dart';
import 'an_two_zone.dart';

enum AnSectionVariant {
  /// Uppercase faint meta caption (rail / inspector sections). 大写灰 meta 小标(rail/检查器段)。
  caption,

  /// Document-tier heading (leans on whitespace, not rules). 文档级标题(靠留白)。
  plain,
}

/// D1 — a section: a small heading + an unbordered content area, organised by whitespace + hierarchy
/// (never rule lines). [variant] caption = the uppercase faint-meta label (reuses [AnGroupLabel], the
/// single caption source); plain = a document-tier heading ([AnText.strong] — a deliberate minimal
/// heading tier below h3). [actions] sit at the head's right via [AnTwoZone] (label fills, actions pin
/// right) + [AnActionGroup]; the head renders whenever there's a [label] OR actions (so an actions-only
/// head isn't silently dropped). [children] stack with a uniform inter-block gap — spacing is owned by
/// the container, children never self-margin.
///
/// a11y: a [Semantics] container with explicitChildNodes (children stay individually reachable, NOT
/// merged); the label is a `header` node reading the original-case text (the visual may be uppercased).
/// The responsive 2-col `grid` variant arrives with AnAutoGrid in G3.5.
///
/// D1——段:小标题 + 无边内容区,靠留白+层级组织(绝不横线)。caption=大写灰 meta(复用 AnGroupLabel 单源);
/// plain=文档级标题(AnText.strong,h3 之下有意的最小标题档)。actions 经 AnTwoZone 居 head 右 + AnActionGroup;
/// 有 label 或 actions 即渲 head(actions-only 不被吞)。children 统一间距堆叠(间距归容器、子件不自管外边距)。
/// a11y:Semantics 容器 + explicitChildNodes(子件各自可达、不 merge);label 为 header 节点、读原始大小写(视觉可能大写)。
/// 响应式 2 列 grid 变体随 AnAutoGrid 在 G3.5 到。
class AnSection extends StatelessWidget {
  const AnSection({
    this.label,
    this.actions = const [],
    this.variant = AnSectionVariant.caption,
    required this.children,
    this.semanticLabel,
    super.key,
  });

  final String? label;
  final List<Widget> actions;
  final AnSectionVariant variant;
  final List<Widget> children;

  /// Screen-reader label override (e.g. when the visible caption is an abbreviation). 屏读标签覆盖。
  final String? semanticLabel;

  bool get _caption => variant == AnSectionVariant.caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasHead = (label != null && label!.isNotEmpty) || actions.isNotEmpty;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: _caption ? AnSpace.s24 : AnSpace.s32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHead) ...[
              _head(context, c),
              SizedBox(height: _caption ? AnSpace.s8 : AnSpace.s12),
            ],
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AnSpace.s12),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _head(BuildContext context, AnColors c) {
    // Empty-string label (with actions) collapses to an actions-only head — no phantom empty header
    // node. Guard matches hasHead's isNotEmpty. 空串 label 退化为 actions-only,不发空 header 节点。
    final labelWidget = (label == null || label!.isEmpty) ? null : _label(context, c);
    // caption head has a slight optical inset (= --grid/2); plain head sits flush. 视觉内缩 grid/2。
    final inset = _caption ? const EdgeInsets.symmetric(horizontal: AnSpace.s2) : EdgeInsets.zero;
    final Widget head = actions.isEmpty
        ? (labelWidget ?? const SizedBox.shrink())
        // AnActionGroup WITHOUT `end` — AnTwoZone already pins trailing right; `end` would force an
        // infinite-width box that breaks the Row. 不用 end:AnTwoZone 已右锚,end 会撑无限宽崩 Row。
        : AnTwoZone(label: labelWidget ?? const SizedBox.shrink(), trailing: AnActionGroup(actions));
    return Padding(padding: inset, child: head);
  }

  Widget _label(BuildContext context, AnColors c) {
    final visible = _caption
        ? AnGroupLabel(label!, padding: EdgeInsets.zero)
        : Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.strong.copyWith(color: c.ink));
    // One header node reading the original-case label (caption visual is uppercased); exclude the
    // visual's own semantics so the reader hears "Inputs", not "INPUTS". 单 header 节点读原始大小写。
    return Semantics(header: true, label: semanticLabel ?? label!, child: ExcludeSemantics(child: visible));
  }
}
