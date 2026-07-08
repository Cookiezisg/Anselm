import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'icons.dart';

/// One settings row — the preference pages' shared skeleton (WRK-062): label (+ optional second-line
/// description) on the left, the CONTROL in the trailing slot (switch / segmented / dropdown /
/// stepper — anything), a 2px accent bar on the leading edge while [modified] (value differs from
/// its default), and a hover-revealed single-row RESET ghost when both [modified] and [onReset] are
/// given. Limits rows and preference rows share this one primitive. Instant-apply model: the row
/// renders facts, the control writes — no save buttons here, ever.
///
/// 设置行——偏好页共享骨架:左=标签(+可选次行描述),行尾槽=控件(开关/分段/下拉/步进,皆可),
/// [modified](偏离默认)时左缘 2px accent 竖条,modified 且给了 [onReset] 时 hover 现「重置」ghost。
/// limits 行与偏好行共用本原语。即时生效模型:行渲事实、控件负责写——这里永远没有保存按钮。
class AnSettingRow extends StatefulWidget {
  const AnSettingRow({
    required this.label,
    this.desc,
    required this.child,
    this.modified = false,
    this.onReset,
    this.resetLabel,
    this.enabled = true,
    super.key,
  }) : assert(onReset == null || resetLabel != null, 'onReset needs its i18n resetLabel 重置须带文案');

  final String label;

  /// The quiet second line (what the setting does / a caveat). 次行描述。
  final String? desc;

  /// The trailing control. 行尾控件。
  final Widget child;

  /// Value differs from its declared default → leading accent bar + reset affordance. 偏离默认。
  final bool modified;

  /// Reset THIS row to its default (hover-revealed, only while [modified]). 单项重置。
  final VoidCallback? onReset;

  /// i18n label for the reset affordance (semantics + tooltip duty). 重置文案(语义层)。
  final String? resetLabel;

  final bool enabled;

  @override
  State<AnSettingRow> createState() => _AnSettingRowState();
}

class _AnSettingRowState extends State<AnSettingRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final showReset = widget.modified && widget.onReset != null && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: Container(
          constraints: const BoxConstraints(minHeight: AnSize.row),
          decoration: BoxDecoration(
            // The modified tell: a 2px accent bar on the leading edge (the quiet grammar the
            // blockquote/thinking rail already speak). 偏离默认的 2px accent 左缘条(既有静默文法)。
            border: Border(
              left: BorderSide(
                color: widget.modified ? c.accent : const Color(0x00000000),
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: AnSpace.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: AnText.body.copyWith(color: c.ink)),
                    if (widget.desc != null && widget.desc!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(widget.desc!, style: AnText.meta.copyWith(color: c.inkMuted)),
                      ),
                  ],
                ),
              ),
              if (showReset)
                Padding(
                  padding: const EdgeInsets.only(right: AnSpace.s6),
                  child: AnButton.iconOnly(
                    AnIcons.undo,
                    size: AnButtonSize.sm,
                    onPressed: widget.onReset!,
                    semanticLabel: widget.resetLabel!,
                  ),
                ),
              const SizedBox(width: AnSpace.s8),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}
