import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'an_interactive.dart';
import 'icons.dart';

/// The co-located in-place edit triad: a pencil that swaps to cancel / save. The single source for
/// "edit this text right here" affordances (e.g. renaming an ocean-header title). The parent owns
/// the [editing] state + reveals the whole thing on hover/focus; this only switches pencil ↔
/// cancel+save and emits the intents. Save is the emphasis action (accent text + accent-soft hover) —
/// this widget owns the affordance skin so colouring it is legitimate.
///
/// 同处就地编辑三连:铅笔 ↔ 取消/保存。父持 editing 态 + 据 hover/focus 揭示整件,本件只切铅笔↔取消保存
/// 并派发意图。保存=强调动作(accent 字 + accent-soft 悬停)——本件是该 affordance 皮肤主人,着色合法。
class AnEditAffordance extends StatelessWidget {
  const AnEditAffordance({
    required this.editing,
    this.onEdit,
    this.onCommit,
    this.onAbort,
    this.size = AnButtonSize.sm,
    super.key,
  });

  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback? onCommit;
  final VoidCallback? onAbort;

  /// Control tier of the pencil/cancel/save — sm (default) inside dense 32px rows (a md pencil would
  /// outgrow the row's slack); md beside content-tier text (the chat head's 15 title, where a 12px
  /// glyph reads a system too small). 触点档位:密集 32 行守 sm(md 会撑破行余量);内容档文字旁(chat 头
  /// 15 标题)用 md,12px 铅笔在那里小一个体系。
  final AnButtonSize size;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (!editing) {
      return AnButton.iconOnly(
        AnIcons.edit,
        size: size,
        semanticLabel: t.action.edit,
        onPressed: onEdit,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AnSpace.s6,
      children: [
        AnButton(label: t.action.cancel, size: AnButtonSize.sm, onPressed: onAbort),
        _SaveButton(label: t.action.save, onPressed: onCommit),
      ],
    );
  }
}

// Save = a ghost button with accent text + accent-soft hover — the demo accents this via ::part;
// here the affordance owns its skin. 保存=accent 字 + accent-soft 悬停的 ghost 钮。
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Explicit button+label semantics so Save reads as a single named button (symmetric with the
    // AnButton-based Cancel; without this the name leans on the child Text node). 显式 button+label,与 Cancel 对称。
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: AnInteractive(
          enabled: onPressed != null,
          onTap: onPressed,
          builder: (context, states) {
            final c = context.colors;
            final active = states.isActive;
            final reduced = AnMotionPref.reduced(context);
            return AnimatedContainer(
              duration: reduced ? Duration.zero : AnMotion.fast,
              height: AnSize.controlSm,
              padding: const EdgeInsets.symmetric(horizontal: AnSize.btnPadXSm),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accentSoft.whenActive(active),
                borderRadius: BorderRadius.circular(AnRadius.button),
              ),
              // accent + emphasis w400 via .weight (VF double-axis: copyWith(fontWeight) alone renders Light). 双轴重定权。
              child: Text(label, style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.accent)),
            );
          },
        ),
      ),
    );
  }
}
