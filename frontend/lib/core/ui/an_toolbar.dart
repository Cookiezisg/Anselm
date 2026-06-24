import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_action_group.dart';

/// D6 — a three-region toolbar: [leading] | main ([title]+[meta], or [center]) | [trailing]. NOT a card
/// (draws no border / island unless [bordered]) — it is only the alignment skeleton so panels and pages
/// stop hand-placing flex+border. The main is the FLEXIBLE middle track (CSS `auto 1fr auto`): the title
/// left-packs + ellipsizes and the trailing actions hug the right (it is NOT centered — the demo `.main`
/// is left-aligned `inline-flex`). [bordered] makes it a top bar (bottom hairline + island bg + pad);
/// [compact] tightens the height to a control row. The [leading] / [trailing] groups wrap (never overflow)
/// via [AnActionGroup] — used WITHOUT `end` (which would force infinite width and break the Row; the main's
/// Expanded already pushes [trailing] to the right edge).
///
/// D6——三区工具条:左附件 | 主体(title+meta 或 center)| 右动作。非卡(除非 bordered 才描边+island 底)——只给对齐骨架,
/// 页面/面板不再手摆 flex+border。主体=中间弹性轨(CSS auto 1fr auto):标题左 packed 省略、右动作贴右(**非居中**,
/// demo .main 是左对齐 inline-flex)。bordered=顶栏(底 hairline + island 底 + 内距);compact=收到 control 高。
/// 左右组经 AnActionGroup 换行不溢出——**不带 `end`**(end 撑无限宽崩 Row;主体 Expanded 已把 trailing 推到右缘)。
class AnToolbar extends StatelessWidget {
  const AnToolbar({
    this.leading = const [],
    this.trailing = const [],
    this.title,
    this.meta,
    this.center,
    this.compact = false,
    this.bordered = false,
    super.key,
  });

  /// Left attachments (wrapped in an [AnActionGroup]). 左附件。
  final List<Widget> leading;

  /// Right actions (wrapped in an [AnActionGroup]). 右动作。
  final List<Widget> trailing;

  /// Standard title (ink, w600, ellipsis). 标准标题。
  final String? title;

  /// Secondary meta after the title. 次级 meta。
  final String? meta;

  /// Custom main body when [title] / [meta] are both null. title/meta 全缺省时的自定义主体。
  final Widget? center;

  /// Tighten the height to a control row (vs the standard row). 收到 control 行高。
  final bool compact;

  /// Render as a top bar: bottom hairline + island bg + pad. 作顶栏。
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final Widget main;
    if (title != null || meta != null) {
      // title + meta left-pack and each ellipsizes (both Flexible → overflow-safe; the demo's meta:flex-none
      // is traded for a no-overflow guarantee). title 左 + meta 次级,各自省略、不溢出。
      main = Row(children: [
        if (title != null)
          Flexible(
            child: Text(title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.body.weight(FontWeight.w600).copyWith(color: c.ink)),
          ),
        if (title != null && meta != null) const SizedBox(width: AnSpace.s8),
        if (meta != null)
          Flexible(
            child: Text(meta!,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ]);
    } else {
      main = center ?? const SizedBox.shrink();
    }

    final bar = ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? AnSize.control : AnSize.row),
      child: Row(
        children: [
          if (leading.isNotEmpty) ...[
            AnActionGroup(leading),
            const SizedBox(width: AnSpace.s8),
          ],
          // main = the flexible 1fr track; the title left-packs + ellipsizes within it. 中间弹性轨。
          Expanded(child: main),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: AnSpace.s8),
            AnActionGroup(trailing),
          ],
        ],
      ),
    );

    if (!bordered) return bar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface, // island fill (AnIsland uses surface too) 岛底
        border: Border(bottom: BorderSide(color: c.line, width: AnSize.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s16, vertical: AnSpace.s8),
        child: bar,
      ),
    );
  }
}
