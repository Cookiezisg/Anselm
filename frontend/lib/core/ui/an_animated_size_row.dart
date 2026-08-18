import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// A top-anchored size tween whose child fades before it becomes too short to read.
///
/// [SliverAnimatedList] keeps the row mounted while it removes it. A bare
/// [SizeTransition] therefore clips text and icons through their glyph boxes in
/// the last part of the tween. Fading over that same tail preserves the rail
/// slide without exposing cropped content. The reverse path fades in only after
/// the row has enough height to read.
///
/// 顶锚高度补间的共享行原语:高度尚未足够承载字形时先隐去内容,保留轨道滑动而不露出
/// 被裁的文字残片。通知托盘与实体侧栏必须共用此配方。
class AnAnimatedSizeRow extends StatelessWidget {
  const AnAnimatedSizeRow({
    required this.animation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = animation.drive(
      CurveTween(curve: const Interval(0.55, 1.0, curve: AnMotion.easeOut)),
    );
    return FadeTransition(
      opacity: opacity,
      child: SizeTransition(
        sizeFactor: animation,
        alignment: AlignmentDirectional.topStart,
        child: child,
      ),
    );
  }
}
