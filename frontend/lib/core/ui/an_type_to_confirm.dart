import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'an_input.dart';

/// The distributed danger-zone block (WRK-062 拍板 #5): a red-bordered card that gates a destructive
/// action behind TYPING the subject's name. [body] carries the caller's real-numbers prose (S-11);
/// [warning] is the dynamic hazard line (rendered first, danger-red) — pass null when idle. The
/// confirm button enables only on an exact name match and re-locks if the text drifts.
///
/// 分布式危险区块(拍板 #5):红框卡,毁灭动作锁在「输入对象名字」之后。[body] 装调用方的真数字散文
/// (S-11);[warning] 是动态危险首行(红字置顶,无则 null)。确认钮仅在名字精确匹配时解锁,改字即回锁。
class AnTypeToConfirm extends StatefulWidget {
  const AnTypeToConfirm({
    required this.title,
    required this.expected,
    required this.inputHint,
    required this.confirmLabel,
    required this.onConfirm,
    this.body,
    this.warning,
    this.busy = false,
    super.key,
  });

  final String title;

  /// The exact string that unlocks the button (the subject's name). 解锁钮的精确字串(对象名)。
  final String expected;
  final String inputHint;
  final String confirmLabel;
  final VoidCallback onConfirm;

  /// The caller's explanation — real numbers, not boilerplate (S-11). 调用方的真数字散文。
  final Widget? body;

  /// The dynamic hazard line (e.g. "N runs in progress — deleting terminates them"). 动态危险首行。
  final String? warning;
  final bool busy;

  @override
  State<AnTypeToConfirm> createState() => _AnTypeToConfirmState();
}

class _AnTypeToConfirmState extends State<AnTypeToConfirm> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final matched = _text.text.trim() == widget.expected;
    return Container(
      padding: const EdgeInsets.all(AnSpace.s16),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(AnRadius.card),
        border: Border.all(color: c.dangerLine, width: AnSize.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AnText.body
                .weight(AnText.emphasisWeight)
                .copyWith(color: c.danger),
          ),
          if (widget.warning != null) ...[
            const SizedBox(height: AnSpace.s8),
            Text(
              widget.warning!,
              style: AnText.label.copyWith(color: c.danger),
            ),
          ],
          if (widget.body != null) ...[
            const SizedBox(height: AnSpace.s8),
            widget.body!,
          ],
          const SizedBox(height: AnSpace.s12),
          AnInput(
            controller: _text,
            placeholder: widget.inputHint,
            enabled: !widget.busy,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AnSpace.s12),
          AnButton(
            label: widget.confirmLabel,
            variant: AnButtonVariant.danger,
            onPressed: widget.busy || !matched ? null : widget.onConfirm,
          ),
        ],
      ),
    );
  }
}
