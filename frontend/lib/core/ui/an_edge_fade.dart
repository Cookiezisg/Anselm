import 'package:flutter/widgets.dart';

/// An edge-fade scrim — a one-directional [LinearGradient] that is opaque AT the given edge and fades to
/// transparent away from it, so scrollable content dissolves under the edge instead of ending in a hard
/// cut. [IgnorePointer] so it never eats taps. The caller sizes/places it (usually a [Positioned] strip
/// along the fading edge). Collapses the fade gradient that the thinking-stream edges and
/// [AnFadeCollapse]'s bottom fade each hand-wrote.
///
/// 边缘渐隐 scrim——单向 LinearGradient,在给定边**不透明**、朝内渐隐,让可滚内容在边缘溶解而非硬切。
/// IgnorePointer 不吃点击。尺寸/定位交调用方(通常是沿渐隐边的 Positioned 条)。收口 thinking 流边与
/// AnFadeCollapse 底部各自手写的渐隐渐变。
class AnEdgeFade extends StatelessWidget {
  const AnEdgeFade({required this.fromTop, required this.color, super.key});

  /// Opaque at the top edge (fading downward) when true; opaque at the bottom edge otherwise.
  /// true=顶边不透明(向下渐隐);false=底边不透明。
  final bool fromTop;

  /// The backdrop colour to fade from — must match the surface the strip sits over. 渐隐起色(须配所在底色)。
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
