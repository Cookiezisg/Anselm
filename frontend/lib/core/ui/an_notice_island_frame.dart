import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The single coastline shared by every top-band notice presentation.
///
/// A compact pill and an expanded approval are two states of one island, so their fill, hairline,
/// elevation and clip must never drift. Geometry that changes during the morph (width / height /
/// radius) stays with the caller; this primitive owns the material identity only.
///
/// 顶带通知全形态共用的唯一海岸线。普通药丸与展开审批是同一座岛的两态,白面、发丝边、岛影与裁切
/// 必须逐字同源;变形中的宽/高/半径由调用方给,本件只守材质身份。
class AnNoticeIslandFrame extends StatelessWidget {
  const AnNoticeIslandFrame({
    required this.radius,
    required this.child,
    super.key,
  });

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: borderRadius,
        border: Border.all(color: c.line, width: AnSize.hairline),
        boxShadow: c.shadowIsland,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}
