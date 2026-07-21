import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_menu_surface.dart';
import 'icons.dart';

/// One row the @ picker offers: a kind icon + name + muted description. [kind] is the wire kind string
/// (resolved to a glyph via [AnIcons.byKey]). @ picker 行:kind 图标 + 名 + 次墨描述;kind=线缆字符串。
class AnMentionRowData {
  const AnMentionRowData({
    required this.kind,
    required this.name,
    this.description = '',
  });

  final String kind;
  final String name;
  final String description;
}

/// The @ typeahead PANEL — pure presentation on the shared popover chrome ([AnMenuSurface] +
/// [AnMenuRow], so it reads exactly like every other floating list). The composer hosts it above
/// itself and drives everything: [activeIndex] is the KEYBOARD-active row (focus stays in the text
/// field — aria-activedescendant style, rendered via [AnMenuRow.highlighted]; hover works
/// independently and a CLICK picks). Rows show a kind glyph + name + muted description, one line
/// each. The panel caps at [AnSize.menuMaxHeight] and scrolls; an EMPTY list is the HOST's cue to
/// close (this never renders an empty state).
///
/// @ typeahead 面板——共享浮层壳上的纯呈现(AnMenuSurface+AnMenuRow,与所有浮层列表同手感)。composer 在
/// 自身上方托管并全权驱动:[activeIndex]=键盘活动行(焦点留输入框,aria-activedescendant 式,经
/// AnMenuRow.highlighted 渲染;hover 独立、点击即选)。行=kind 字形+名+次墨描述,单行。面板封顶滚动;
/// **空列表由宿主关闭**(本件不渲空态)。
class AnMentionPanel extends StatelessWidget {
  const AnMentionPanel({
    required this.items,
    required this.activeIndex,
    required this.onPick,
    super.key,
  });

  final List<AnMentionRowData> items;
  final int activeIndex;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: AnSize.menuMaxHeight),
      child: AnMenuSurface(
        children: [
          for (var i = 0; i < items.length; i++)
            AnMenuRow(
              onTap: () => onPick(i),
              highlighted: i == activeIndex,
              builder: (context, active) => Row(
                children: [
                  Icon(
                    AnIcons.byKey(items[i].kind),
                    size: AnSize.icon,
                    color: active ? c.ink : c.inkMuted,
                  ),
                  const SizedBox(width: AnSpace.s8),
                  Flexible(
                    child: Text(
                      items[i].name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.body.copyWith(color: c.ink),
                    ),
                  ),
                  // No trailing Spacer on description-less rows — a Spacer(flex:2) capped the
                  // loose name Flexible at 1/3 of the row while 2/3 sat empty (long names
                  // ellipsized for nothing). 无描述行不放 Spacer——旧 flex:2 占位把名字压到 1/3 行宽。
                  if (items[i].description.isNotEmpty) ...[
                    const SizedBox(width: AnSpace.s8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        items[i].description,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AnText.meta.copyWith(color: c.inkFaint),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
