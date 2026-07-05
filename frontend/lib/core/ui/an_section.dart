import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_action_group.dart';
import 'an_auto_grid.dart';
import 'an_group_label.dart';
import 'an_two_zone.dart';

enum AnSectionVariant {
  /// Uppercase faint meta caption (rail / inspector sections). 大写灰 meta 小标(rail/检查器段)。
  caption,

  /// Document-tier heading (leans on whitespace, not rules). 文档级标题(靠留白)。
  plain,

  /// A QUIET lowercase meta label (no uppercase, no emphasis) over a tightly-spaced body — for compact
  /// stacks of headed groups like the run terminal's output / trace / nodes sections. 安静小写 meta 小标(紧凑头组,如 run 终端各段)。
  quiet,
}

/// D1 — a section: a small heading + an unbordered content area, organised by whitespace + hierarchy
/// (never rule lines). [variant] caption = the uppercase faint-meta label (reuses [AnGroupLabel], the
/// single caption source); plain = a content section heading ([AnText.readingH2] 18 — the +3-over-body
/// proportion above the 15 content prose). [actions] sit at the head's right via [AnTwoZone] (label fills, actions pin
/// right) + [AnActionGroup]; the head renders whenever there's a [label] OR actions (so an actions-only
/// head isn't silently dropped). [children] stack with a uniform inter-block gap — spacing is owned by
/// the container, children never self-margin.
///
/// [grid] lays the body out as a responsive auto-fit block grid (via [AnAutoGrid]) instead of a single
/// column — for side-by-side cards. a11y: a [Semantics] container with explicitChildNodes (children
/// stay individually reachable, NOT merged); the label is a `header` node reading the original-case
/// text (the visual may be uppercased).
///
/// D1——段:小标题 + 无边内容区,靠留白+层级组织(绝不横线)。caption=大写灰 meta(复用 AnGroupLabel 单源);
/// plain=内容分节头(AnText.readingH2 18,15 正文上的 +3 比例)。actions 经 AnTwoZone 居 head 右 + AnActionGroup;
/// 有 label 或 actions 即渲 head(actions-only 不被吞)。children 统一间距堆叠(间距归容器、子件不自管外边距);
/// grid=true 时 body 委托 AnAutoGrid 排成响应式块网格。
/// a11y:Semantics 容器 + explicitChildNodes(子件各自可达、不 merge);label 为 header 节点、读原始大小写(视觉可能大写)。
class AnSection extends StatelessWidget {
  const AnSection({
    this.label,
    this.actions = const [],
    this.variant = AnSectionVariant.caption,
    this.grid = false,
    this.gridMinColWidth,
    required this.children,
    this.semanticLabel,
    super.key,
  });

  final String? label;
  final List<Widget> actions;
  final AnSectionVariant variant;
  final List<Widget> children;

  /// Lay the body out as a responsive auto-fit block grid (via [AnAutoGrid]) instead of a single
  /// column — for side-by-side cards (an entity page's input/output/env blocks). 响应式块网格。
  final bool grid;

  /// Min column width for [grid] (defaults to [AnSize.block]). grid 列最小宽。
  final double? gridMinColWidth;

  /// Screen-reader label override (e.g. when the visible caption is an abbreviation). 屏读标签覆盖。
  final String? semanticLabel;

  bool get _caption => variant == AnSectionVariant.caption;

  // Section↔section bottom gap = AnGap.section (24) for both real headed variants — plain was s32, a 2.67×
  // jump over its own s12 children that read as a "slab" void on every entity overview (fixed). quiet stays
  // compact (16, the tight run-terminal stacks). 段↔段底距统一 24(plain 原 s32「板块感」已修);quiet 保紧凑 16。
  double get _bottomPad => switch (variant) {
        AnSectionVariant.caption => AnGap.section,
        AnSectionVariant.plain => AnGap.section,
        AnSectionVariant.quiet => AnSpace.s16,
      };
  // Heading→body ramp — a deliberate, now-NAMED 3-tier (sanctioned prose exception): plain 12 / caption 8 /
  // quiet 6. 标题→正文三档(命名后的合规例外)。
  double get _headGap => switch (variant) {
        AnSectionVariant.caption => AnFlow.headBodyTight,
        AnSectionVariant.plain => AnFlow.headBody,
        AnSectionVariant.quiet => AnFlow.headBodyDense,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasHead = (label != null && label!.isNotEmpty) || actions.isNotEmpty;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: _bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHead) ...[
              _head(context, c),
              SizedBox(height: _headGap),
            ],
            _body(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    // grid → responsive block grid (AnAutoGrid); else a single column with a uniform inter-block gap
    // (sp-3) — the container owns spacing, children never self-margin. grid 走块网格,否则单列统一块间距。
    if (grid) {
      return AnAutoGrid(minColWidth: gridMinColWidth ?? AnSize.block, children: children);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AnGap.block), // uniform inter-block gap (12) 统一块间距
          children[i],
        ],
      ],
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
    final visible = switch (variant) {
      AnSectionVariant.caption => AnGroupLabel(label!, padding: EdgeInsets.zero),
      AnSectionVariant.plain =>
        Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.readingH2.copyWith(color: c.ink)),
      // quiet: a small lowercase faint-meta label (NOT uppercased like caption). 安静小写灰 meta。
      AnSectionVariant.quiet =>
        Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkFaint)),
    };
    // One header node reading the original-case label (caption visual is uppercased); exclude the
    // visual's own semantics so the reader hears "Inputs", not "INPUTS". 单 header 节点读原始大小写。
    return Semantics(header: true, label: semanticLabel ?? label!, child: ExcludeSemantics(child: visible));
  }
}
