import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_icon_button.dart';
import 'icons.dart';

/// A modal dialog: title row (+ close) over content over right-aligned actions. Use
/// [showAnDialog] to present it over a scrim. Keep content small; this is for confirms and
/// short forms, not full pages.
/// 模态对话框:标题行(+关闭)→ 内容 → 右对齐操作。用 [showAnDialog] 在遮罩上呈现。内容宜小。
class AnDialog extends StatelessWidget {
  const AnDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.width = 420,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(AnSpace.s16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AnRadius.card),
            boxShadow: c.shadowPop,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: AnText.strong.copyWith(color: c.ink))),
                  AnIconButton(AnIcons.close,
                      size: AnSize.controlSm,
                      onPressed: () => Navigator.of(context).maybePop()),
                ],
              ),
              const SizedBox(height: AnSpace.s12),
              content,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AnSpace.s16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AnSpace.s8),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showAnDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  List<Widget> actions = const [],
  double width = 420,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: context.colors.scrim,
    builder: (ctx) => AnDialog(title: title, content: content, actions: actions, width: width),
  );
}
