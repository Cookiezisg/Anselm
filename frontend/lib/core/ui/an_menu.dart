import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_menu_surface.dart';
import 'an_popover.dart';
import 'icons.dart';

/// One entry of an [AnMenu]: a [AnMenuSection] header label or an [AnMenuItem] command. AnMenu 条目。
sealed class AnMenuEntry {
  const AnMenuEntry();
}

/// A non-interactive section label (grouping is whitespace + a faint header, no divider line). 分组小标题。
class AnMenuSection extends AnMenuEntry {
  const AnMenuSection(this.label);
  final String label;
}

/// A menu command. [checked] shows a lead check (for toggle / multi-select menus — use [keepOpen] so the
/// menu stays open while toggling several); [icon] is an alternative lead glyph; [meta] is a trailing
/// secondary; [danger] reds it; [disabled] greys + inerts it. 菜单项(checked=前导勾、keepOpen=多选不收)。
class AnMenuItem extends AnMenuEntry {
  const AnMenuItem({
    required this.label,
    this.icon,
    this.meta,
    this.checked = false,
    this.danger = false,
    this.disabled = false,
    this.keepOpen = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? meta;
  final bool checked;
  final bool danger;
  final bool disabled;
  final bool keepOpen;
  final VoidCallback? onTap;
}

/// F2 — a floating command / option menu on [AnPopover]: section labels + rows of `lead (icon or check) |
/// label | meta`, with danger / disabled / checked flavors. [anchorBuilder] builds the trigger and is
/// handed a `toggle` callback + the open state (wire it to a button's onPressed). Picking an item runs its
/// onTap and closes the menu unless [AnMenuItem.keepOpen] (multi-check sliders stay open). The reusable
/// base for sidebar sliders (Sort / Display), row-more actions, and the shell ⋯ menu.
///
/// F2——浮层命令/选项菜单(搭 AnPopover):分组小标题 + `前导(icon 或 勾)| 标签 | meta` 行,带 danger/disabled/checked
/// 风味。anchorBuilder 建触发器、收到 toggle + 开合态(接到按钮 onPressed)。pick 跑 onTap 后收起,除非 keepOpen(多选 sliders
/// 不收)。sidebar sliders(Sort/Display)、row-more、壳 ⋯ 菜单的共享基座。
class AnMenu extends StatefulWidget {
  const AnMenu({
    required this.anchorBuilder,
    required this.entries,
    this.alignEnd = true,
    this.matchAnchorWidth = false,
    this.onClose,
    super.key,
  });

  /// Builds the trigger; `toggle` opens/closes, `isOpen` is the current state. 建触发器(toggle/isOpen)。
  final Widget Function(BuildContext context, VoidCallback toggle, bool isOpen)
  anchorBuilder;

  final List<AnMenuEntry> entries;

  /// Right-align the menu to the anchor (the common case — a ⋯ at the right). 右对齐到锚(常见)。
  final bool alignEnd;

  /// Make the menu EXACTLY the trigger's width (drops straight down from it) instead of hugging its
  /// widest row — for a full-width dropdown like the workspace switcher. 菜单与触发钮等宽(顺钮下展),而非贴内容宽。
  final bool matchAnchorWidth;

  /// Forwarded when the menu dismisses (consumer resets state). 收起回调。
  final VoidCallback? onClose;

  @override
  State<AnMenu> createState() => _AnMenuState();
}

class _AnMenuState extends State<AnMenu> {
  final AnPopoverController _popover = AnPopoverController();

  // Section-label indent + the item label's left edge: row pad + lead column + gap. 标签缩进=行 pad + 前导列 + 间距。
  static const double _labelIndent = AnSpace.s8 + AnSize.iconLg + AnSpace.s8;

  @override
  void initState() {
    super.initState();
    _popover.addListener(_onPopover);
  }

  void _onPopover() {
    if (!_popover.isOpen) widget.onClose?.call();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _popover.removeListener(_onPopover);
    _popover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnPopover(
      controller: _popover,
      alignEnd: widget.alignEnd,
      overlayBuilder: (context, anchorSize) => _menu(context, anchorSize),
      anchor: widget.anchorBuilder(context, _popover.toggle, _popover.isOpen),
    );
  }

  Widget _menu(BuildContext context, Size? anchorSize) {
    // Seed focus on the first non-disabled item so opening lands on item 0 (a descendant autofocus
    // wins over the overlay's FocusScope) — native menu behaviour, arrow keys engage immediately. 首项自动聚焦。
    final firstFocusable = widget.entries.indexWhere(
      (e) => e is AnMenuItem && !e.disabled,
    );
    // shared menu chrome (surface + s4-all-sides inset so each row's pill floats off the edge). 共用面板壳。
    final body = AnMenuSurface(
      children: [
        for (var i = 0; i < widget.entries.length; i++)
          _entry(context, widget.entries[i], autofocus: i == firstFocusable),
      ],
    );
    // Match the trigger width exactly (full-width dropdown, e.g. the workspace switcher). 与触发钮等宽。
    if (widget.matchAnchorWidth && anchorSize != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: AnSize.menuMaxHeight),
        child: SizedBox(width: anchorSize.width, child: body),
      );
    }
    return ConstrainedBox(
      // Hug the widest row's content (clamped to [min,max]) instead of always filling maxWidth — the
      // demo's shrink-to-fit menu (the surface's stretch fills the INTRINSIC width, rows share an edge). 贴内容宽。
      constraints: const BoxConstraints(
        minWidth: AnSize.menuMinWidth,
        maxWidth: AnSize.menuMaxWidth,
        maxHeight: AnSize.menuMaxHeight,
      ),
      child: IntrinsicWidth(child: body),
    );
  }

  Widget _entry(BuildContext context, AnMenuEntry e, {bool autofocus = false}) {
    if (e is AnMenuSection) {
      final c = context.colors;
      return Padding(
        padding: const EdgeInsetsDirectional.only(
          start: _labelIndent,
          end: AnSpace.s8,
          top: AnSpace.s8,
          bottom: AnSpace.s4,
        ),
        child: Text(
          e.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AnText.meta
              .weight(AnText.emphasisWeight)
              .copyWith(color: c.inkFaint),
        ),
      );
    }
    final item = e as AnMenuItem;
    // Shared row standard (rounded inset pill, hover/active fill, reduced-gate, disabled) — same surface
    // AnDropdown options use; only the lead/label/meta content below is menu-specific. 共用行标准。
    return AnMenuRow(
      enabled: !item.disabled,
      danger: item.danger,
      autofocus: autofocus,
      onTap: () {
        item.onTap?.call();
        if (!item.keepOpen) _popover.close();
      },
      builder: (context, active) {
        final c = context.colors;
        final fg = item.danger ? c.danger : (active ? c.ink : c.inkMuted);
        // lead = icon, else the check when [checked] (selection lives in the lead, not trailing). 前导=图标或勾。
        final IconData? lead =
            item.icon ?? (item.checked ? AnIcons.check : null);
        return Row(
          children: [
            SizedBox(
              width: AnSize.iconLg,
              child: lead != null
                  ? Icon(lead, size: AnSize.icon, color: fg)
                  : null,
            ),
            const SizedBox(width: AnSpace.s8),
            // NOT [AnTwoZone], even though that primitive exists for exactly this two-zone shape and caps
            // meta at 45%. It is built on `LayoutBuilder`, and this popover wraps its body in
            // `IntrinsicWidth` (to hug the widest row) — `LayoutBuilder` throws outright when asked for an
            // intrinsic dimension ("does not support returning intrinsic dimensions"), which was verified
            // by probe rather than assumed. So the same RULE is expressed here with flex, which needs no
            // speculative layout pass. AnDropdown can and does use AnTwoZone: its popover is a plain
            // `ConstrainedBox` with no intrinsic pass.
            //
            // **不用 [AnTwoZone]**,尽管那个原语正是为这种两区形状而生、且把 meta 限在 45%。它建在 `LayoutBuilder`
            // 上,而本浮层把 body 包在 `IntrinsicWidth` 里(为了贴最宽那行)——`LayoutBuilder` 被问及 intrinsic 尺寸时
            // **直接抛**(「does not support returning intrinsic dimensions」),这一点是**探针实测**、不是推断。故此处
            // 用 flex 表达同一条**规则**,它不需要那趟推测性布局。AnDropdown 能用也确实在用 AnTwoZone:它的浮层是
            // 纯 `ConstrainedBox`、没有 intrinsic 那一趟。
            //
            // The label:meta flex split is the row family's ONE rule about secondary text (WRK-083 B2):
            // metadata may claim at most a third of the row, and it ellipsizes there rather than pushing
            // the row open. Written the obvious way — a bare `Text` for the meta — it is NOT flexible, so
            // `Row` lays it out with UNBOUNDED main-axis constraints, `TextOverflow.ellipsis` never
            // engages, and a long value paints straight past the popover's edge (the real report was a
            // 148px bar under 「最近目录」, whose meta is a full filesystem path). `IntrinsicWidth` makes it
            // worse, not better: it asks for the untruncated width, `menuMaxWidth` refuses, and the child
            // measured against the first is painted into the second.
            //
            // `Align` is what keeps the meta pinned RIGHT. A loose `Flexible` hands its child a 0..allowance
            // box; a bare `Text` would hug its content and sit immediately after the label's two-thirds,
            // stranded mid-row. `Align` takes the whole allowance and right-aligns inside it, which is
            // exactly where the meta used to land back when the label's `Expanded` pushed it there.
            //
            // label:meta 的 flex 配比就是行族关于**次要文本**的唯一规矩(WRK-083 B2):元信息最多占一行的三分之一,
            // 到那里就省略号、而不是把行撑开。按显然的写法(meta 用裸 `Text`)它**不是**弹性的,于是 `Row` 用**无界**
            // 主轴约束布局它,`TextOverflow.ellipsis` 根本不生效,长值直接画到浮层外(真实报告是「最近目录」下 148px
            // 的黄黑条,那一行的 meta 是一条完整文件系统路径)。`IntrinsicWidth` 让事情更糟而非更好:它按**未截断**
            // 的宽度索要,`menuMaxWidth` 拒绝,而按前者量过的 child 被画进后者。
            //
            // `Align` 是把 meta 钉在**右**边的那一手。loose 的 `Flexible` 给 child 一个 0..额度 的盒子;裸 `Text`
            // 会贴着内容、紧跟在标签那三分之二之后,搁浅在行中央。`Align` 吃满整个额度并在其中右对齐,那正是从前
            // 标签的 `Expanded` 把 meta 顶过去的位置。
            Expanded(
              flex: 2,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.body.copyWith(color: fg),
              ),
            ),
            if (item.meta != null) ...[
              const SizedBox(width: AnSpace.s8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    item.meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: AnText.metaTabular().copyWith(color: c.inkFaint),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
