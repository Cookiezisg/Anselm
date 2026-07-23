import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// One ENTRY-ONLY content fade (S5) — async content SURFACES ([AnMotion.contentIn]) instead of
/// popping in when it replaces a skeleton / blank. Plays exactly once on mount; in-place rebuilds
/// (data updates at the same element position) never replay — fast beats fancy, so settled content
/// swaps with zero animation. Pure opacity, no rise: this is "the page material arriving", not an
/// entrance flourish (that is [AnFadeRiseIn]'s role). Static under reduced motion.
///
/// 仅入场一次的内容淡入(S5)——异步内容替换骨架/空白时**浮现**([AnMotion.contentIn])而非炸现。
/// 挂载播一次;原地 rebuild(同 element 位置的数据更新)不重播——快就是丝滑,落定内容零动画换。
/// 纯透明度、不上移:这是「页面材料到达」,不是入场花活(那是 [AnFadeRiseIn] 的角色)。reduced 静态。
class AnContentIn extends StatelessWidget {
  const AnContentIn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AnMotionPref.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AnMotion.contentIn,
      curve: AnMotion.easeOut,
      child: child,
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child!),
    );
  }
}
