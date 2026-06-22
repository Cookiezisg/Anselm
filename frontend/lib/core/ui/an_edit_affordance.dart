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
/// cancel+save and emits the intents. Save is emphasis (ink, monochrome) — this widget owns the
/// affordance skin so colouring it is legitimate.
///
/// 同处就地编辑三连:铅笔 ↔ 取消/保存。父持 editing 态 + 据 hover/focus 揭示整件,本件只切铅笔↔取消保存
/// 并派发意图。保存=强调(墨,单色)——本件是该 affordance 皮肤主人,着色合法。
class AnEditAffordance extends StatelessWidget {
  const AnEditAffordance({
    required this.editing,
    this.onEdit,
    this.onCommit,
    this.onAbort,
    super.key,
  });

  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback? onCommit;
  final VoidCallback? onAbort;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (!editing) {
      return AnButton.iconOnly(
        AnIcons.edit,
        size: AnButtonSize.sm,
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

// Save = a ghost button with emphasis (ink) text — the demo accents this via ::part; here the
// affordance owns its skin. 保存=强调字的 ghost 钮。
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnInteractive(
      enabled: onPressed != null,
      onTap: onPressed,
      builder: (context, states) {
        final c = context.colors;
        final active = states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed);
        return AnimatedContainer(
          duration: AnMotion.fast,
          height: AnSize.controlSm,
          padding: const EdgeInsets.symmetric(horizontal: AnSize.btnPadXSm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c.accentSoft : c.accentSoft.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: Text(label, style: AnText.meta.copyWith(color: c.accent, fontWeight: FontWeight.w500)),
        );
      },
    );
  }
}
