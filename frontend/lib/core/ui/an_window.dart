import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_edge_fade.dart';
import 'an_fade_collapse.dart';

/// The WINDOW family head (WRK-066「同轨」族一 · 2026-07-11 拍板) — the ONE content container, ONE
/// face: white surface + hairline border + card radius. The grey «sunken well» material is RETIRED
/// app-wide (the user chat bubble is the only grey survivor — a bubble, not a window; interaction
/// greys are controls, not containers). Slots: a left [header] (single-line, ellipsized), a right
/// [actions] row (chip family), an [AnSize]-tier [maxHeight] clamp — [collapsible] fades past it
/// with the standard expand affordance, otherwise the crop is SILENT-SAFE (an inner unbounded
/// scroll region, so a flex child never overflows — 复审 #3) and signalled by a bottom edge fade —
/// and an optional [footer] (the muted NOTE slot under the body: truncation notes, settle lines —
/// codex rule ④). A null [child] is a HEADER-ONLY window (no dead body gap — 批1 复审). Windows are
/// LEAF containers: window-in-window is a defect, enforced by a debug assert (复审 #48).
///
/// 窗族当家件(拍板)——唯一内容容器唯一脸:白底+发丝边+card 圆角;灰凹面退役(用户泡唯一例外)。槽:
/// 左 header(单行省略)、右 actions、AnSize 档 maxHeight 钳(collapsible=标准折叠;否则**静默安全**
/// 硬裁——内层无界滚动区,flex 子不溢出——并以底缘渐隐示意)、footer(体下 muted 注记槽:截断注/结算行,
/// 法典规则④)。child=null 即**头独窗**(无死体距,批1 复审)。**窗是叶子容器:窗内套窗=缺陷,debug
/// assert 强制**(规则可执行)。
class AnWindow extends StatelessWidget {
  const AnWindow({
    this.child,
    this.header,
    this.actions = const [],
    this.maxHeight,
    this.collapsible = false,
    this.footer,
    super.key,
  })  : assert(!collapsible || maxHeight != null,
            'collapsible needs a maxHeight tier (else it silently does nothing) 折叠须配钳高档'),
        assert(child != null || header != null || footer != null,
            'an AnWindow needs at least one of child/header/footer 至少给一个槽');

  /// The body. null = a header-only window (e.g. a just-opened card with nothing to say yet) —
  /// the head↔body gap is skipped so no dead space is paid. 体;null=头独窗(刚开播无话可说的卡),
  /// 免付头体死距。
  final Widget? child;

  /// Left header slot (command echo / title line) — single line, ellipsized. 左头槽(单行省略)。
  final Widget? header;

  /// Right action slot (copy chips etc.), flush-right on the header row. 右动作槽。
  final List<Widget> actions;

  /// Height clamp — pass an [AnSize] viewport tier, never a bare number. 高钳(AnSize 档,禁裸数)。
  final double? maxHeight;

  /// Past [maxHeight], fade-collapse with the standard expand/collapse affordance (instead of the
  /// silent crop). 超高时 FadeCollapse(标准展开/收起),替代静默硬裁。
  final bool collapsible;

  /// Footer slot under the body — the muted note voice (truncation notes, settle lines; codex 族一
  /// 规则 ④). 体下 footer 槽——muted 注记声(截断注/结算行,法典规则④)。
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // LEAF rule, executable: a window may not host another window (double hairlines touching read
    // as a defect — 文法 #11). 叶子律可执行:窗内禁套窗(双发丝边贴脸=缺陷,文法 #11)。
    assert(
      context.getElementForInheritedWidgetOfExactType<_AnWindowScope>() == null,
      'AnWindow inside AnWindow — windows are leaf containers (文法 #11 窗禁套窗); '
      'separate sibling windows with spacing instead.',
    );
    final c = context.colors;
    final head = (header == null && actions.isEmpty)
        ? null
        : Row(children: [
            if (header != null)
              Expanded(
                child: DefaultTextStyle.merge(
                  style: AnText.label.copyWith(color: c.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: header!,
                ),
              )
            else
              const Spacer(),
            for (final a in actions)
              Padding(padding: const EdgeInsets.only(left: AnSpace.s4), child: a),
          ]);

    Widget? body = child;
    if (body != null && maxHeight != null) {
      body = collapsible
          ? AnFadeCollapse(
              collapsible: true,
              collapsedHeight: maxHeight!,
              expandLabel: context.t.action.expand,
              collapseLabel: context.t.action.collapse,
              fadeColor: c.surface,
              child: body,
            )
          // Silent-SAFE crop: the inner scroll region hands the child unbounded height (a flex child
          // never RenderFlex-overflows — 复审 #3, AnFadeCollapse's own idiom), the clamp crops the
          // viewport, and a bottom fade signals «there is more». 静默安全硬裁:内层滚动区给子树无界高
          // (flex 子不溢出),钳裁视口,底缘渐隐示意「下有更多」。
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!),
              child: ClipRect(
                child: Stack(children: [
                  SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: body),
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: AnSpace.s16,
                    child: AnEdgeFade(fromTop: false, color: c.surface),
                  ),
                ]),
              ),
            );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?head,
        // The head↔body gap is only paid when there IS a body (复审: a header-only window must not
        // carry a dead 6px). 头体距只在有体时付(头独窗不背死距)。
        if (head != null && body != null) const SizedBox(height: AnSpace.s6),
        ?body,
        if (footer != null) ...[
          if (head != null || body != null) const SizedBox(height: AnSpace.s4),
          DefaultTextStyle.merge(style: AnText.meta.copyWith(color: c.inkFaint), child: footer!),
        ],
      ],
    );

    // Width-safe block behaviour (复审 #7): stretch in bounded hosts; in an UNBOUNDED-width host
    // (a Row's rigid slot, a horizontal scroller) shrink-wrap instead of throwing
    // «BoxConstraints forces an infinite width». 宽安全块级:有界撑满;无界宽宿主收身而非炸约束。
    return _AnWindowScope(
      child: LayoutBuilder(
        builder: (ctx, constraints) => Container(
          width: constraints.hasBoundedWidth ? double.infinity : null,
          padding: AnInset.card,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line, width: AnSize.hairline),
            borderRadius: BorderRadius.circular(AnRadius.card),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Marker for the leaf-container assert. 叶子律标记。
class _AnWindowScope extends InheritedWidget {
  const _AnWindowScope({required super.child});

  @override
  bool updateShouldNotify(_AnWindowScope oldWidget) => false;
}
