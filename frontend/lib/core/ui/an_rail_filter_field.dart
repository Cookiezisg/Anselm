import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import 'an_button.dart';
import 'an_input.dart';
import 'an_menu.dart';
import 'icons.dart';

/// The ONE left-island filter/search field — a leading search glyph + a seamless [AnInput] + an optional
/// trailing options [AnMenu] (the ⚙/sliders anchor). One row-tall, s8 inset. [AnSidebarList]'s in-domain
/// filter and the notification tray's «搜索通知…» both ride this (same field, same look — #8). Filtering
/// itself is the host's job (this only owns the field chrome + forwards [onChanged]/[onSubmitted]).
///
/// 左岛唯一的过滤/搜索行:前导搜索字形 + 无缝 AnInput + 可选尾部选项菜单(⚙/sliders 锚)。一行高、s8 内距。
/// AnSidebarList 域内过滤 + 托盘「搜索通知…」共用它(同件同样式);过滤逻辑归宿主(本件只管字段壳 + 转发回调)。
class AnRailFilterField extends StatelessWidget {
  const AnRailFilterField({
    required this.controller,
    required this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.menuEntries = const [],
    this.menuSemanticLabel,
    super.key,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Trailing options menu entries; empty → no anchor rendered. 尾部选项菜单项,空则不渲锚。
  final List<AnMenuEntry> menuEntries;

  /// a11y label for the options anchor. Defaults to the shared display-options label. 选项锚 a11y 标签。
  final String? menuSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: AnSize.row,
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
      child: Row(
        children: [
          Icon(AnIcons.search, size: AnSize.icon, color: c.inkFaint),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: AnInput(
              controller: controller,
              seamless: true,
              placeholder: placeholder,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          if (menuEntries.isNotEmpty)
            AnMenu(
              entries: menuEntries,
              anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
                AnIcons.sliders,
                size: AnButtonSize.sm,
                semanticLabel:
                    menuSemanticLabel ?? context.t.a11y.displayOptions,
                onPressed: toggle,
              ),
            ),
        ],
      ),
    );
  }
}
