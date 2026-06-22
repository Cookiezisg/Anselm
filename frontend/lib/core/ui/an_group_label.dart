import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A thin section/group caption (uppercase · meta size · w500 · faint ink) — the single source for
/// the small headers that label rail groups, inspector sections, etc. Vertical padding follows
/// proximity: more above (separates), less below (binds to its group).
///
/// 极薄分组/段小标题(uppercase · meta · w500 · faint 墨)——分组标签的单源。纵向内距按邻近原则:上多(分隔)、下少(贴附本组)。
class AnGroupLabel extends StatelessWidget {
  const AnGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AnSpace.s4, AnSpace.s8, AnSpace.s4, AnSpace.s4),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AnText.meta.copyWith(color: context.colors.inkFaint, fontWeight: FontWeight.w500),
      ),
    );
  }
}
