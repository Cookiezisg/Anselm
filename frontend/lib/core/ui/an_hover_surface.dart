import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A rounded HOVER fill for a tappable row/cell — transparent at rest, `surfaceHover` when [active] (the
/// pressed/hovered state an [AnInteractive] builder reports), with the tag radius. The row-background dual
/// of AnCard's border-hover: a hit list / menu row wants a soft fill, not an outline. 可点行的圆角 hover
/// 填充:静息透明、active 时 surfaceHover(AnInteractive builder 报的按/悬停态)+ tag 圆角。命中行/菜单行要柔填非描边。
class AnHoverSurface extends StatelessWidget {
  const AnHoverSurface({required this.child, required this.active, this.radius = AnRadius.tag, super.key});

  final Widget child;

  /// Whether the row is pressed/hovered (from an [AnInteractive] `states.isActive`). 是否按/悬停。
  final bool active;

  /// Corner radius (default the tag tier — a row-inline highlight). 圆角(默认 tag 档)。
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: active ? context.colors.surfaceHover : null,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
}
