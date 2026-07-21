import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// The shared CODE-SURFACE frame (WRK-040 G5 — extracted at the 2nd consumer, AnVersionDiff). A single
/// framed container for code/data blocks: a hairline [AnColors.line] border on a [AnRadius.card] rounded
/// box, a [AnColors.surface] white-island fill, and a [ClipRRect] so internally-scrolling content stays
/// inside the rounded frame. No "gray corner tips" — Flutter strokes a uniform border as ONE continuous
/// round-rect path (unlike CSS's four mitered edges that double their opacity where they meet at a
/// corner), so even though [AnColors.line] is SEMI-TRANSPARENT it produces no doubled-opacity tip; that's
/// why a plain [Border.all] is safe here where the demo (version-diff.js) had to use an inset box-shadow.
/// [bare] drops the frame (transparent, no clip) for inline / borderless rows; [focused] swaps the border
/// to [AnColors.accentLine] (an editable code block while editing). NOT [AnCard] — AnCard forces uniform
/// padding, no clip, and no focus border, none of which suit a code surface whose bar/gutter/area manage
/// their own insets.
///
/// 共享代码面框(G5,在第二消费者 AnVersionDiff 处抽出)。代码/数据块的统一框:圆角盒发丝 line 边 + 白岛底 +
/// ClipRRect(内滚内容不溢出圆角)。**无灰尖**——Flutter 把 uniform 边描成**单条连续 round-rect 路径**(不像 CSS 四条
/// 斜接边在圆角处叠加不透明度),故即便 c.line 半透明也不产生 CSS 那种灰尖;这正是此处用 Border.all 安全、而 demo
/// (version-diff.js)须用 inset box-shadow 的原因。bare=无框透明(内联/无边行);focused=accentLine 边(编辑态)。非 AnCard
/// (其强制内距/无 clip/无 focus 边,均不适配自管内距的代码面)。
class AnCodeSurface extends StatelessWidget {
  const AnCodeSurface({
    required this.child,
    this.bare = false,
    this.focused = false,
    super.key,
  });

  final Widget child;
  final bool bare;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    if (bare) return child; // transparent, no frame/clip 无框透明
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(
          color: focused ? c.accentLine : c.line,
          width: AnSize.hairline,
        ),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AnRadius.card),
        child: child,
      ),
    );
  }
}
