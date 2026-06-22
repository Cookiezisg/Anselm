import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';
import 'an_popover.dart';
import 'icons.dart';

/// B3 — a controlled single-select dropdown (replaces the native select). The trigger echoes the
/// chosen label (+ optional mono meta + caret); tapping opens a rich-row menu (label / meta / icon
/// / check-current) on [AnPopover]. [variant] ghost is the borderless trigger; [menuAlignEnd]
/// right-aligns the menu (row-trailing controls). The menu scrolls past a cap so a huge option
/// list never overflows the screen.
///
/// B3——受控单选下拉(替原生 select)。触发器回显选中 label(+ 可选 mono meta + caret);点开富行菜单
/// (label/meta/icon/勾选当前)搭于 AnPopover。ghost=无边框触发器;menuAlignEnd=菜单右对齐。超量选项菜单滚动、不溢出。
class AnDropdownOption<T> {
  const AnDropdownOption({required this.value, required this.label, this.meta, this.icon});

  final T value;
  final String label;
  final String? meta;
  final IconData? icon;
}

enum AnDropdownVariant { normal, ghost }

class AnDropdown<T> extends StatefulWidget {
  const AnDropdown({
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = '—',
    this.variant = AnDropdownVariant.normal,
    this.block = false,
    this.enabled = true,
    this.menuAlignEnd = false,
    super.key,
  });

  final List<AnDropdownOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String placeholder;
  final AnDropdownVariant variant;
  final bool block;
  final bool enabled;
  final bool menuAlignEnd;

  @override
  State<AnDropdown<T>> createState() => _AnDropdownState<T>();
}

class _AnDropdownState<T> extends State<AnDropdown<T>> {
  final AnPopoverController _popover = AnPopoverController();

  @override
  void initState() {
    super.initState();
    _popover.addListener(_onPopover);
  }

  void _onPopover() => setState(() {});

  @override
  void dispose() {
    _popover.removeListener(_onPopover);
    _popover.dispose();
    super.dispose();
  }

  AnDropdownOption<T>? get _selected {
    for (final o in widget.options) {
      if (o.value == widget.value) return o;
    }
    return null;
  }

  void _pick(T value) {
    _popover.close();
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onChanged != null;
    final ghost = widget.variant == AnDropdownVariant.ghost;

    final trigger = AnInteractive(
      enabled: enabled,
      onTap: _popover.toggle,
      builder: (context, states) => _trigger(context, states, ghost),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: AnPopover(
        controller: _popover,
        targetAnchor: widget.menuAlignEnd ? Alignment.bottomRight : Alignment.bottomLeft,
        followerAnchor: widget.menuAlignEnd ? Alignment.topRight : Alignment.topLeft,
        overlayBuilder: (context, anchorSize) => _menu(context, anchorSize),
        anchor: widget.block ? SizedBox(width: double.infinity, child: trigger) : trigger,
      ),
    );
  }

  Widget _trigger(BuildContext context, Set<WidgetState> states, bool ghost) {
    final c = context.colors;
    final open = _popover.isOpen;
    final active = open || states.contains(WidgetState.hovered);
    final sel = _selected;

    final label = Text(
      sel?.label ?? widget.placeholder,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (ghost ? AnText.meta : AnText.body).copyWith(
        color: sel == null ? c.inkFaint : (ghost ? (active ? c.ink : c.inkMuted) : c.ink),
      ),
    );

    final caret = AnimatedRotation(
      duration: AnMotion.fast,
      turns: open ? 0.5 : 0,
      child: Icon(AnIcons.chevronDown, size: AnSize.iconSm, color: c.inkFaint),
    );

    final children = <Widget>[
      Flexible(child: label),
      if (sel?.meta != null) ...[
        const SizedBox(width: AnSpace.s8),
        Text(sel!.meta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.meta.copyWith(color: c.inkFaint, fontFeatures: const [FontFeature.tabularFigures()])),
      ],
      SizedBox(width: ghost ? AnSpace.s6 : AnSpace.s8),
      caret,
    ];

    if (ghost) {
      return AnimatedContainer(
        duration: AnMotion.fast,
        height: AnSize.controlSm,
        padding: const EdgeInsets.symmetric(horizontal: AnSize.btnPadXSm),
        decoration: BoxDecoration(
          color: active ? c.surfaceHover : const Color(0x00000000),
          borderRadius: BorderRadius.circular(AnRadius.button),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );
    }

    return AnimatedContainer(
      duration: AnMotion.fast,
      height: AnSize.control,
      constraints: const BoxConstraints(minWidth: AnSize.inputMin),
      padding: const EdgeInsets.symmetric(horizontal: AnSize.btnPadXSm),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: active ? c.lineStrong : c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.button),
      ),
      child: Row(children: children),
    );
  }

  Widget _menu(BuildContext context, Size? anchorSize) {
    final c = context.colors;
    // Menu is at least the trigger width; cap extra growth at 360 — but never below the trigger
    // (a block/full-width trigger makes minWidth large, so maxWidth must rise with it or the
    // constraints go non-normalized minWidth>maxWidth). 菜单≥触发器宽,上限≥触发器宽(否则 min>max 非法)。
    final triggerW = anchorSize?.width ?? AnSize.inputMin;
    final maxW = triggerW > AnSize.menuMaxWidth ? triggerW : AnSize.menuMaxWidth;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: triggerW,
        maxWidth: maxW,
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
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final o in widget.options)
                  _MenuRow(
                    option: o,
                    selected: o.value == widget.value,
                    onTap: () => _pick(o.value),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.option, required this.selected, required this.onTap});

  final AnDropdownOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnInteractive(
      onTap: onTap,
      builder: (context, states) {
        final c = context.colors;
        final active = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        return AnimatedContainer(
          duration: AnMotion.fast,
          height: AnSize.row,
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
          color: active ? c.surfaceHover : const Color(0x00000000),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: AnSize.icon, color: c.inkMuted),
                const SizedBox(width: AnSpace.s8),
              ],
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.body.copyWith(color: c.ink),
                ),
              ),
              if (option.meta != null) ...[
                const SizedBox(width: AnSpace.s8),
                Text(option.meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.copyWith(color: c.inkFaint)),
              ],
              SizedBox(
                width: AnSize.icon + AnSpace.s8,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: AnSpace.s8),
                        child: Icon(AnIcons.check, size: AnSize.iconSm, color: c.ink),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
