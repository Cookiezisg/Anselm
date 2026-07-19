import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';

/// One breadcrumb segment — a label and an optional tap that navigates to THAT level. A null [onTap] is
/// inert: the current-context root you're already at, or a level with no page of its own to open.
/// 一段面包屑:标签 + 可选点击(导航到该级);onTap 为 null=惰性(已在的根 / 无独立页可开的级)。
@immutable
class AnCrumb {
  const AnCrumb(this.label, {this.onTap});

  final String label;

  /// Non-null → the segment is clickable and navigates to its level. 非空则该段可点、导航到其层级。
  final VoidCallback? onTap;
}

/// The breadcrumb TRAIL — the parent PATH only, NEVER the page's own name (用户 0719 面包屑律:灰字=完整
/// 路径到上一级为止、绝不含自己;黑字大标题才是页面自己). Faint segments joined by a faint «/» separator,
/// each segment navigable when it carries an [AnCrumb.onTap]. A chain longer than [foldAfter] segments
/// collapses its MIDDLE to an inert «…» (Notion 同款), always keeping the first segment + the direct parent.
/// One line, ellipsized. The «/» separator is the PRIMITIVE's — callers pass STRUCTURED [AnCrumb]s, never a
/// pre-joined "A / B" string (禁止消费方自拼串,斜杠分隔符归原语渲染).
///
/// The default [style] is [AnText.label] (the chrome scale used atop [AnOceanHeader]); the reading-scale
/// headers ([AnDocHeader] / settings) pass [AnText.meta]. 面包屑路径:灰段 + 灰「/」,带 onTap 即可点导航;
/// 超 foldAfter 段折中段为惰性「…」(留首段+直属父);整行省略。默认 label 尺度,阅读头传 meta。
class AnCrumbs extends StatelessWidget {
  const AnCrumbs(this.crumbs, {this.style, this.foldAfter, super.key});

  final List<AnCrumb> crumbs;

  /// Base text style — defaults to [AnText.label]. 基础字样,默认 label。
  final TextStyle? style;

  /// A chain longer than this folds its middle to «…». null = never fold. 超此段数折中段;null=不折。
  final int? foldAfter;

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final base = style ?? AnText.label;
    final segments = _folded();

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6),
          child: Text('/', style: base.copyWith(color: c.lineStrong)),
        ));
      }
      children.add(Flexible(child: _segment(context, segments[i], base, c)));
    }
    // No mainAxisSize.min: the Row fills the crumb band and the [Flexible] segments ellipsize under a
    // tight width instead of overflowing (segments cluster left via the default start alignment).
    // 不 min:Row 铺满面包屑带,窄时 Flexible 段省略而非溢出(默认左对齐聚左)。
    return Row(children: children);
  }

  /// Keep the first segment + the direct parent, folding everything between into an inert «…» once the
  /// chain exceeds [foldAfter] (deep document trees, Notion 同款). 深链折中段:留首段+直属父。
  List<AnCrumb> _folded() {
    final f = foldAfter;
    if (f == null || crumbs.length <= f) return crumbs;
    return [crumbs.first, const AnCrumb('…'), crumbs.last];
  }

  Widget _segment(BuildContext context, AnCrumb crumb, TextStyle base, AnColors c) {
    Widget text(Color color) => Text(
          crumb.label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: color),
        );
    if (crumb.onTap == null) return text(c.inkFaint);
    // Clickable: faint at rest, a touch stronger when engaged (hover/focus/press) — the whole segment is
    // one hit target with the click cursor + button semantics from AnInteractive (原则 #8 不手搓命中/焦点).
    // 可点:静息灰,激活时略深;整段一个命中目标,光标/焦点/按钮语义走 AnInteractive。
    return AnInteractive(
      onTap: crumb.onTap,
      builder: (context, states) => text(states.isActive ? c.inkMuted : c.inkFaint),
    );
  }
}
