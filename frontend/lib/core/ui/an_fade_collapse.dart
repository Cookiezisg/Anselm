import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_edge_fade.dart';
import 'an_interactive.dart';

/// A tall block collapsed to AT MOST [collapsedHeight] with a fade-out gradient and an expand/
/// collapse toggle underneath — for content that is *detail*, not interface (a long code body under
/// a signature hero). The caller decides whether collapsing applies at all ([collapsible] — a cheap
/// heuristic like char count); the PRIMITIVE then measures the truth: the collapsed viewport is a
/// max-height clamp (never a fixed box — a fixed box under-filled by short content left a void of
/// dead space with a stranded Expand, 用户 0719 值班手册帧), and the fade + toggle only render when
/// the content actually overflows the clamp. When false the child renders bare. The clipped child
/// keeps its intrinsic height inside a non-scrolling viewport, so no overflow errors and no layout
/// jump on toggle. [fadeColor] must match the backdrop the block sits on (default: canvas).
///
/// 渐隐收合块——超长内容收到**至多** [collapsedHeight] 高,底部渐隐 + 展开/收起开关;给「是细节、非
/// 界面」的内容用。调用方的 [collapsible] 只是便宜启发(如字符数),**真相由原语测量**:收起视口是
/// maxHeight 钳而非固定盒(固定盒被矮内容填不满曾留一段死空白+悬底 Expand,用户 0719 值班手册帧),
/// 渐隐与开关仅在内容真溢出钳高时渲。false 时裸渲。裁切用不可滚 viewport 保住子树固有高——零溢出
/// 报错、切换零跳动。[fadeColor] 须与所在底色一致(默认 canvas)。
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
  // Measured truth: does the content actually overflow the collapsed clamp? Starts false so short
  // content NEVER flashes a toggle; the post-layout probe flips it on for genuinely tall content.
  // 测量出的真相:内容真溢出钳高否?初始 false——矮内容绝不闪开关;后帧探针对真高内容才点亮。
  bool _overflows = false;
  final ScrollController _probe = ScrollController();

  @override
  void dispose() {
    _probe.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted || !_probe.hasClients) return;
    final over = _probe.position.maxScrollExtent > 0;
    if (over != _overflows) setState(() => _overflows = over);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.collapsible) return widget.child;
    final c = context.colors;
    final fade = widget.fadeColor ?? c.canvas;
    // Re-measure after every layout of the collapsed viewport (content可流式生长). 每次布局后重测。
    if (!_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
    return Column(
      // min: the block hugs its content — in bounded loose constraints a max Column would swallow
      // the leftover height and recreate the dead-void bug at the layout level. min:块贴内容高。
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_expanded)
          widget.child
        else
          Stack(
            children: [
              // AT MOST the clamp — short content sits at its own height (the fixed-height box left a
              // dead void under short bodies, 用户 0719). 至多钳高:矮内容贴自身高,固定盒死空白已修。
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.collapsedHeight),
                // A never-scrolling viewport: gives the child unbounded height and clips the rest —
                // the standard trick, no OverflowBox math. 不可滚 viewport:给子树无界高、裁掉其余。
                child: SingleChildScrollView(
                  controller: _probe,
                  physics: const NeverScrollableScrollPhysics(),
                  child: widget.child,
                ),
              ),
              if (_overflows)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: AnSize.row * 2,
                  child: AnEdgeFade(fromTop: false, color: fade),
                ),
            ],
          ),
        // The toggle exists only when there is genuinely more to reveal (or we are expanded and can
        // collapse back) — a toggle under fully-visible content is a dead affordance.
        // 开关仅在真有可展内容(或已展开可收回)时在场——全量可见下的开关是死示能。
        if (_overflows || _expanded)
          Semantics(
            button: true,
            child: AnInteractive(
              onTap: () => setState(() => _expanded = !_expanded),
              builder: (context, states) => SizedBox(
                height: AnSize.row,
                child: Center(
                  child: Text(
                    _expanded ? widget.collapseLabel : widget.expandLabel,
                    style: AnText.label.copyWith(
                      color: states.contains(WidgetState.hovered)
                          ? context.colors.ink
                          : context.colors.inkMuted,
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
