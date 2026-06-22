import 'package:flutter/material.dart';

import 'an_card.dart';
import 'an_section.dart';

/// A titled card grouping detail rows (typically [AnKvRow]s) — the building block of the
/// right-island inspector and entity detail pages.
/// 带标题的卡,聚合详情行(通常是 [AnKvRow])——右岛检查器与实体详情页的积木。
class AnInfoCard extends StatelessWidget {
  const AnInfoCard({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AnCard(
      child: AnSection(
        title: title,
        trailing: trailing,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}
