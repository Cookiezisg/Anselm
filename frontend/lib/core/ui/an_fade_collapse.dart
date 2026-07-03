import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';

/// A tall block collapsed to [collapsedHeight] with a fade-out gradient and an expand/collapse
/// toggle underneath — for content that is *detail*, not interface (a long code body under a
/// signature hero). The caller decides whether collapsing applies at all ([collapsible] — it knows
/// the content size, e.g. line count > 50); when false the child renders bare. The clipped child
/// keeps its intrinsic height inside a non-scrolling viewport, so no overflow errors and no layout
/// jump on toggle. [fadeColor] must match the backdrop the block sits on (default: canvas).
///
/// 渐隐收合块——超长内容收到 [collapsedHeight] 高,底部渐隐 + 展开/收起开关;给「是细节、非界面」的
/// 内容用(签名 hero 下的长代码体)。是否收合由调用方判定([collapsible],它知道内容尺寸,如行数>50),
/// false 时裸渲。裁切用不可滚 viewport 保住子树固有高——零溢出报错、切换零跳动。[fadeColor] 须与
/// 所在底色一致(默认 canvas)。
class AnFadeCollapse extends StatefulWidget {
  const AnFadeCollapse({
    required this.child,
    required this.collapsible,
    required this.expandLabel,
    required this.collapseLabel,
    this.collapsedHeight = 400,
    this.fadeColor,
    super.key,
  });

  final Widget child;
  final bool collapsible;
  final String expandLabel;
  final String collapseLabel;
  final double collapsedHeight;
  final Color? fadeColor;

  @override
  State<AnFadeCollapse> createState() => _AnFadeCollapseState();
}

class _AnFadeCollapseState extends State<AnFadeCollapse> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.collapsible) return widget.child;
    final c = context.colors;
    final fade = widget.fadeColor ?? c.canvas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_expanded)
          widget.child
        else
          Stack(children: [
            SizedBox(
              height: widget.collapsedHeight,
              // A never-scrolling viewport: gives the child unbounded height and clips the rest —
              // the standard trick, no OverflowBox math. 不可滚 viewport:给子树无界高、裁掉其余。
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: widget.child,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: AnSize.row * 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [fade.withValues(alpha: 0), fade],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        Semantics(
          button: true,
          child: AnInteractive(
            onTap: () => setState(() => _expanded = !_expanded),
            builder: (context, states) => SizedBox(
              height: AnSize.row,
              child: Center(
                child: Text(
                  _expanded ? widget.collapseLabel : widget.expandLabel,
                  style: AnText.meta.copyWith(
                    color: states.contains(WidgetState.hovered) ? context.colors.ink : context.colors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
