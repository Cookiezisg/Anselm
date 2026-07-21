import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A single white island card — the shell's surface primitive: white fill, hairline border,
/// chip radius, float shadow. Depth reads from the shadow + hairline, never a heavy border, so
/// the chrome stays light and airy. The left island and the right island are both [AnIsland]s;
/// the ocean between them is the open window surface (no card).
///
/// 单张白岛卡——shell 的表面原语:白底、发丝边、chip 圆角、浮阴影。深度靠阴影+细线、非重边框,chrome
/// 通透轻盈。左岛、右岛都是 [AnIsland];中间海洋是敞开的窗体表面(无卡)。
class AnIsland extends StatelessWidget {
  const AnIsland({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AnSpace.s12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.chip),
        boxShadow: c.shadowFloat,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
