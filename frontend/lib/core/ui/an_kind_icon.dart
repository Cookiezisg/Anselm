import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// An entity-kind glyph in a soft rounded tile — the monochrome way to mark kind (Function
/// / Agent / Workflow …): by ICON, never by color. Pass an [AnIcons] kind glyph.
/// 实体种类图标置于柔角小块——单色标记种类(Function/Agent/Workflow…)的方式:靠图标,绝不靠颜色。
/// 传入 [AnIcons] 的种类字形。
class AnKindIcon extends StatelessWidget {
  const AnKindIcon(this.icon, {super.key, this.size = AnSize.control});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceActive,
        borderRadius: BorderRadius.circular(AnRadius.button),
      ),
      child: Center(
        child: Icon(
          icon,
          size: size <= AnSize.controlSm ? 14 : AnSize.icon,
          color: c.inkMuted,
        ),
      ),
    );
  }
}
