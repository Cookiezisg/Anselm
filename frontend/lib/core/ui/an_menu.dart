import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
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
    this.onClose,
    super.key,
  });

  /// Builds the trigger; `toggle` opens/closes, `isOpen` is the current state. 建触发器(toggle/isOpen)。
  final Widget Function(BuildContext context, VoidCallback toggle, bool isOpen) anchorBuilder;

  final List<AnMenuEntry> entries;

  /// Right-align the menu to the anchor (the common case — a ⋯ at the right). 右对齐到锚(常见)。
  final bool alignEnd;

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
      targetAnchor: widget.alignEnd ? Alignment.bottomRight : Alignment.bottomLeft,
      followerAnchor: widget.alignEnd ? Alignment.topRight : Alignment.topLeft,
      overlayBuilder: (context, _) => _menu(context),
      anchor: widget.anchorBuilder(context, _popover.toggle, _popover.isOpen),
    );
  }

  Widget _menu(BuildContext context) {
    final c = context.colors;
    // Seed focus on the first non-disabled item so opening lands on item 0 (a descendant autofocus
    // wins over the overlay's FocusScope) — native menu behaviour, arrow keys engage immediately. 首项自动聚焦。
    final firstFocusable = widget.entries.indexWhere((e) => e is AnMenuItem && !e.disabled);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AnSize.menuMinWidth,
        maxWidth: AnSize.menuMaxWidth,
        maxHeight: AnSize.menuMaxHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AnRadius.chip),
          border: Border.all(color: c.line, width: AnSize.hairline),
          boxShadow: c.shadowPop,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AnRadius.chip),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AnSpace.s4),
            child: FocusTraversalGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                for (var i = 0; i < widget.entries.length; i++)
                  _entry(context, widget.entries[i], autofocus: i == firstFocusable),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, AnMenuEntry e, {bool autofocus = false}) {
    final c = context.colors;
    if (e is AnMenuSection) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: _labelIndent, end: AnSpace.s8, top: AnSpace.s8, bottom: AnSpace.s4),
        child: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AnText.meta.weight(FontWeight.w600).copyWith(color: c.inkFaint)),
      );
    }
    final item = e as AnMenuItem;
    final reduced = AnMotionPref.reduced(context);
    return AnInteractive(
      enabled: !item.disabled,
      autofocus: autofocus,
      onTap: () {
        item.onTap?.call();
        if (!item.keepOpen) _popover.close();
      },
      builder: (context, states) {
        final active = states.isActive;
        final fg = item.danger ? c.danger : (active ? c.ink : c.inkMuted);
        // Both branches route through the alpha-0 .whenActive idiom (no inline Color literal; the
        // resting fill fades from a same-hue alpha-0, avoiding Color.lerp's dark midpoint). 静止底走 alpha-0 单源。
        final bg = item.danger ? c.dangerSoft.whenActive(active) : c.surfaceHover.whenActive(active);
        // lead = icon, else the check when [checked] (selection lives in the lead, not trailing). 前导=图标或勾。
        final IconData? lead = item.icon ?? (item.checked ? AnIcons.check : null);
        return Opacity(
          opacity: item.disabled ? AnOpacity.disabled : 1,
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : AnMotion.fast, // hover tint = functional micro-feedback 功能性微反馈
            height: AnSize.row,
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AnRadius.button)),
            child: Row(
              children: [
                SizedBox(
                  width: AnSize.iconLg,
                  child: lead != null ? Icon(lead, size: AnSize.icon, color: fg) : null,
                ),
                const SizedBox(width: AnSpace.s8),
                Expanded(
                  child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.body.copyWith(color: fg)),
                ),
                if (item.meta != null) ...[
                  const SizedBox(width: AnSpace.s8),
                  Text(item.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.metaTabular().copyWith(color: c.inkFaint)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
