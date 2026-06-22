import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_icon_button.dart';
import 'icons.dart';

/// The 右岛 context inspector: an on-demand panel that appears when something is selected
/// (a run, an entity, a node). Header (title + actions + close) over a scrollable body;
/// left-bordered. Mount/unmount it from the shell to slide it in/out.
/// 右岛上下文检查器:选中某物(运行/实体/节点)时按需出现。头部(标题+操作+关闭)压可滚主体;左描边。
class AnRightIsland extends StatelessWidget {
  const AnRightIsland({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.onClose,
    this.actions = const [],
    this.width = AnSize.rightIsland,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final VoidCallback? onClose;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.chip),
        boxShadow: c.shadowFloat,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: AnSize.islandHead,
            padding: const EdgeInsets.only(left: AnSpace.s16, right: AnSpace.s8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line, width: AnSize.hairline)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AnSize.icon, color: c.inkFaint),
                  const SizedBox(width: AnSpace.s8),
                ],
                Expanded(
                  child: Text(title,
                      style: AnText.strong.copyWith(color: c.ink),
                      overflow: TextOverflow.ellipsis),
                ),
                for (final a in actions) ...[a, const SizedBox(width: AnSpace.s4)],
                if (onClose != null)
                  AnIconButton(AnIcons.close, size: AnSize.controlSm, onPressed: onClose),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AnSpace.s16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
