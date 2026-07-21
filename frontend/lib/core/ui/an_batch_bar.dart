import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_action_group.dart';
import 'an_button.dart';
import 'an_interactive.dart';
import 'icons.dart';

// AnBatchBar (WRK-069 判决② S2b) — the ONE multi-select batch-operation bar: it floats in above a
// list once the user has selected enough rows («已选 N · [动作…] ✕»), and its companion [AnBatchCheck]
// is the hover row-selection checkbox that puts rows INTO that selection. Batch semantics are the
// caller's (front-end sequential dispatch with explicit per-row settling — never fake atomicity);
// this primitive only renders the count + actions + clear, and [busy] freezes them while a batch is
// in flight so a second batch can't start mid-run.
// AnBatchBar 批量操作条:多选浮出「已选 N · [动作…] ✕」;配套 AnBatchCheck 行首 hover 选择框。批量语义归
// 调用方(前端逐发+显式挂账,绝不装原子);本原语只渲 计数+动作+清除,busy 冻结防批中再批。

/// One batch action on the bar. [tone] picks the button voice (danger → the danger button; ok/accent →
/// primary; none → outline ghost). 批量动作:tone 定按钮声(danger 红/ok·accent 主/none 描边)。
class BatchAction {
  const BatchAction({
    required this.label,
    this.icon,
    this.tone = AnTone.none,
    required this.onRun,
  });

  final String label;
  final IconData? icon;
  final AnTone tone;
  final VoidCallback onRun;
}

/// The batch bar. Renders nothing when [count] ≤ 0 (no selection = no bar — the caller usually gates
/// the reveal itself, this is the honest floor). [busy] disables every action AND the clear while a
/// batch runs. 批量条:count≤0 渲空(无选无条);busy 压全部动作与清除。
class AnBatchBar extends StatelessWidget {
  const AnBatchBar({
    required this.count,
    required this.actions,
    required this.onClear,
    this.busy = false,
    super.key,
  });

  final int count;
  final List<BatchAction> actions;
  final VoidCallback onClear;

  /// A batch is in flight — freeze the bar (rows settle one by one beneath it). 批量在途,冻结条。
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final c = context.colors;
    final t = Translations.of(context);
    // A flat bordered bar — NO float shadow (WRK-070 B10 用户裁「别人都没阴影,整它干啥」;the hairline
    // border already lifts it off the list). 全宽平条,无浮影(发丝边已托起,全 app 别处无浮影)。
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.button),
        border: Border.all(color: c.line, width: AnSize.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AnSpace.s12,
          vertical: AnSpace.s6,
        ),
        child: Row(
          children: [
            Text(
              t.feedback.batch.selected(n: '$count'),
              style: AnText.meta
                  .weight(AnText.emphasisWeight)
                  .copyWith(color: c.ink),
            ),
            const SizedBox(width: AnSpace.s12),
            // The action cluster rides the kit's button group (D7): unified gaps, and a too-narrow
            // host WRAPS instead of overflowing (Wrap 文法); overlong labels still ellipsize inside
            // their buttons. 动作簇走 AnActionGroup(D7):统一间距、过窄换行不溢出;超长标签钮内裁切。
            Expanded(
              child: AnActionGroup([
                for (final a in actions)
                  AnButton(
                    label: a.label,
                    icon: a.icon,
                    size: AnButtonSize.sm,
                    variant: switch (a.tone) {
                      AnTone.danger => AnButtonVariant.danger,
                      AnTone.ok || AnTone.accent => AnButtonVariant.primary,
                      _ => AnButtonVariant.ghost,
                    },
                    outline: a.tone == AnTone.none || a.tone == AnTone.warn,
                    onPressed: busy ? null : a.onRun,
                  ),
              ]),
            ),
            const SizedBox(width: AnSpace.s8),
            AnButton.iconOnly(
              AnIcons.close,
              size: AnButtonSize.sm,
              semanticLabel: t.feedback.batch.clear,
              onPressed: busy ? null : onClear,
            ),
          ],
        ),
      ),
    );
  }
}

/// The companion row-selection checkbox — sized for a ledger row's fixed lead cell
/// ([AnSize.iconSm]), so it can hover-swap with the row's status dot without moving the primary.
/// A real toggle for a11y (Semantics checked + tap), NOT a Material Checkbox (oversized + tap-target
/// padding — the an_markdown verdict). 配套行选择框:12px 合台账行 lead 定宽格,与状态点原位互换;
/// 真勾选语义(checked+tap),不用超尺寸 Material Checkbox(an_markdown 同判)。
class AnBatchCheck extends StatelessWidget {
  const AnBatchCheck({
    required this.checked,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        checked: checked,
        child: AnInteractive(
          onTap: () => onChanged(!checked),
          builder: (context, states) {
            final hovered = states.contains(WidgetState.hovered);
            return Container(
              width: AnSize.iconSm,
              height: AnSize.iconSm,
              decoration: BoxDecoration(
                color: checked
                    ? c.accent
                    : (hovered ? c.surfaceHover : const Color(0x00000000)),
                borderRadius: BorderRadius.circular(AnRadius.tag),
                border: checked
                    ? null
                    : Border.all(
                        color: hovered ? c.inkFaint : c.line,
                        width: AnSize.hairline,
                      ),
              ),
              child: checked
                  ? Icon(
                      AnIcons.check,
                      size: AnSize.iconSm - 3,
                      color: c.onAccent,
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}
