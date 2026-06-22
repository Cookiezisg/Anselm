import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A generic labeled form-field wrapper: muted label above any control, with a hint or an
/// error caption below (error takes precedence and turns red). Wrap dropdowns, toggles,
/// pickers — anything that needs a form label, not just text inputs.
/// 通用表单字段包装:控件上方弱化标签,下方提示或错误(错误优先、变红)。可包 dropdown/toggle/picker 等。
class AnField extends StatelessWidget {
  const AnField({super.key, this.label, required this.child, this.hint, this.error});

  final String? label;
  final Widget child;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s4),
            child: Text(label!, style: AnText.label.copyWith(color: c.inkMuted)),
          ),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(error!, style: AnText.meta.copyWith(color: c.danger)),
          )
        else if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: Text(hint!, style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
      ],
    );
  }
}
