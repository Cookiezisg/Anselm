import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A titled section: a faint caption header (with optional trailing action) over a body.
/// The structural unit of detail panels and settings pages.
/// 带标题的分区:弱化标题(可带行尾操作)压住主体。详情面板/设置页的结构单元。
class AnSection extends StatelessWidget {
  const AnSection({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: AnSize.controlSm,
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: AnText.label.copyWith(color: c.inkFaint)),
              ),
              ?trailing,
            ],
          ),
        ),
        const SizedBox(height: AnSpace.s8),
        child,
      ],
    );
  }
}
