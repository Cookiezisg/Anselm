import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';

/// One segment. [disabled] renders it faint and inert (e.g. the dark theme notch before its
/// lighting pass lands — visible so the roadmap shows, un-pickable so it can't lie). 一段;disabled=
/// 压暗且不可点(如 dark 档点亮前:看得见路线、点不出谎)。
class AnSegmentedOption<T> {
  const AnSegmentedOption({
    required this.value,
    required this.label,
    this.icon,
    this.disabled = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool disabled;
}

/// The horizontal segmented control (2–6 options) — the settings rows' enum picker. A sunken pill
/// rail with EQUAL-width segments; the selected one carries a raised white card that GLIDES between
/// positions (matched-geometry via [AnimatedAlign], jumps under reduced motion — the same grammar
/// as [AnOceanSwitcher]'s sliding pill, horizontal and generic). Controlled: [value] + [onChanged].
/// NOT tabs (no panes — a value picker), NOT the ocean switcher (that one is bespoke chrome).
///
/// 水平分段器(2–6 段)——设置行的枚举选择器。凹底轨 + 等宽段;选中段驮一张白卡在段间滑动
/// (AnimatedAlign matched-geometry,reduced 直跳——与海洋切换器同文法、横排通用化)。受控:value+
/// onChanged。不是 tabs(无面板,是取值器),也不是海洋切换器(那是专用 chrome)。
class AnSegmented<T> extends StatelessWidget {
  const AnSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  }) : assert(
         options.length >= 2 && options.length <= 6,
         '2–6 segments 段数 2–6',
       );

  final List<AnSegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    final index = options.indexWhere((o) => o.value == value);
    final n = options.length;
    // Equal-width segments → the thumb's alignment is a pure function of the index. 等宽段,滑块位置纯函数。
    final align = n == 1
        ? Alignment.center
        : Alignment(-1 + 2 * (index.clamp(0, n - 1)) / (n - 1), 0);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Opacity(
        opacity: enabled ? 1 : AnOpacity.disabled,
        child: Container(
          height: AnSize.control,
          padding: const EdgeInsets.all(AnSpace.s2),
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: BorderRadius.circular(AnRadius.button + 2),
            border: Border.all(color: c.line, width: AnSize.hairline),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final segW = box.maxWidth / n;
              return Stack(
                children: [
                  // The gliding raised card under the selected segment. 选中段下的滑动白卡。
                  if (index >= 0)
                    AnimatedAlign(
                      duration: reduced ? Duration.zero : AnMotion.fast,
                      curve: AnMotion.easeOut,
                      alignment: align,
                      child: Container(
                        width: segW,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(AnRadius.button),
                          border: Border.all(
                            color: c.line,
                            width: AnSize.hairline,
                          ),
                          // Resting-card lift via the theme token (same tier the graph node cards use) — it
                          // inverts to the dark theme's heavier black so the selected pill stays elevated in
                          // BOTH themes; a fixed black literal would go invisible on the near-black dark surface.
                          // 走主题 shadowIsland 档(与图节点卡同层):dark 档翻成更重的黑,选中丸两档都抬得起来;定值黑在近黑面上会隐形。
                          boxShadow: c.shadowIsland,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (final (i, o) in options.indexed)
                        Expanded(
                          // ONE node per segment. `button`/`selected` are AnInteractive's to state — annotating
                          // them again below made the two Semantics an INCOMPATIBLE pair, so the framework split
                          // each unselected segment into parent+child and the LABEL landed on the child while
                          // `focus` stayed on the parent: keyboard-focusing a segment announced an UNNAMED button
                          // (dump-verified). MergeSemantics folds the label back onto the focusable node.
                          // 每段一个节点。button/selected 归 AnInteractive 说;下面再标一遍会让两个 Semantics 成为
                          // **不兼容**配置 → 框架把每个未选中段拆成父+子,label 落到子上、focus 留在父上 = 键盘聚焦时
                          // 念出一个**无名按钮**(dump 实证)。MergeSemantics 把 label 折回被聚焦的那个节点。
                          child: MergeSemantics(
                            child: AnInteractive(
                              enabled: enabled && !o.disabled,
                              onTap: enabled && !o.disabled && i != index
                                  ? () => onChanged(o.value)
                                  : null,
                              selected: i == index,
                              builder: (context, states) {
                                final active = i == index;
                                final hovered =
                                    states.contains(WidgetState.hovered) &&
                                    !o.disabled;
                                return Semantics(
                                  label: o.label,
                                  // The SELECTED segment is deliberately not tappable (`i != index`), so
                                  // AnInteractive's onTap-derived `button` would drop off it — leaving the one
                                  // segment a reader most needs to identify reading as bare text. State it here;
                                  // MergeSemantics keeps it one node. 选中段刻意不可点,故 AnInteractive 由 onTap
                                  // 推导的 button 会从它身上掉;最该被认出的那一段反而读成纯文本。此处补上,merge 保持单节点。
                                  button: true,
                                  excludeSemantics: true,
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (o.icon != null) ...[
                                          Icon(
                                            o.icon,
                                            size: AnSize.iconSm,
                                            color: o.disabled
                                                ? c.inkFaint.withValues(
                                                    alpha: AnOpacity.disabled,
                                                  )
                                                : active
                                                ? c.ink
                                                : (hovered
                                                      ? c.inkMuted
                                                      : c.inkFaint),
                                          ),
                                          const SizedBox(width: AnSpace.s4),
                                        ],
                                        Flexible(
                                          child: Text(
                                            o.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AnText.body.copyWith(
                                              color: o.disabled
                                                  ? c.inkFaint.withValues(
                                                      alpha: AnOpacity.disabled,
                                                    )
                                                  : active
                                                  ? c.ink
                                                  : (hovered
                                                        ? c.inkMuted
                                                        : c.inkFaint),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
