import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A floating chrome pill — a [AnColors.surface] fill on a [AnRadius.button] rounded box with a hairline
/// [AnColors.line] border and the [AnColors.shadowFloat] elevation, holding a tight `Row` of controls
/// (s4 inset). Readable when it floats over busy content (a dotted graph canvas). Collapses the byte-for-
/// byte pill chrome that the graph-canvas zoom toolbar and the workflow-editor toolbars each hand-rolled.
/// Put [AnDivider.vertical] between [children] to separate control clusters.
///
/// 浮动 chrome 药丸——surface 底 + r-button 圆角 + line 发丝边 + shadowFloat 浮影,收一排紧凑控件(s4 内距);
/// 浮在繁忙内容(点阵图画布)上仍可读。收口画布缩放条与工作流编辑器各自手搓的逐字同款药丸 chrome。段间放
/// [AnDivider.vertical] 分隔。
class AnFloatingBar extends StatelessWidget {
  const AnFloatingBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.button),
        border: Border.all(color: c.line, width: AnSize.hairline),
        boxShadow: c.shadowFloat,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AnSpace.s4),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
