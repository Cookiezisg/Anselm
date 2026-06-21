import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A single-line text field in the design language: surface fill, hairline border, an
/// ink (monochrome) focus ring. Optional [label] renders above as a muted caption.
/// 单行输入:表面填充、细线边、墨色(单色)焦点环。可选 [label] 作上方弱化标题。
class AnInput extends StatelessWidget {
  const AnInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnRadius.button),
          borderSide: BorderSide(color: color, width: width),
        );

    final field = TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      obscureText: obscureText,
      cursorColor: c.ink,
      style: AnText.body.copyWith(color: c.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: enabled ? c.surface : c.surfaceHover,
        hintText: hint,
        hintStyle: AnText.body.copyWith(color: c.inkFaint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8),
        enabledBorder: border(c.line, AnSize.hairline),
        focusedBorder: border(c.accentLine, AnSize.focusRing),
        disabledBorder: border(c.line, AnSize.hairline),
      ),
    );

    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s4),
          child: Text(label!, style: AnText.label.copyWith(color: c.inkMuted)),
        ),
        field,
      ],
    );
  }
}
