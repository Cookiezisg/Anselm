import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// A search input: leading search glyph + a clear button that appears once there is text.
/// 搜索输入:行首搜索图标 + 有文字时出现的清除按钮。
class AnSearchField extends StatefulWidget {
  const AnSearchField({super.key, this.controller, this.hint, this.onChanged});

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  State<AnSearchField> createState() => _AnSearchFieldState();
}

class _AnSearchFieldState extends State<AnSearchField> {
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnRadius.button),
          borderSide: BorderSide(color: color, width: width),
        );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _ctrl,
      builder: (context, value, _) {
        return TextField(
          controller: _ctrl,
          onChanged: widget.onChanged,
          cursorColor: c.ink,
          style: AnText.body.copyWith(color: c.ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.surface,
            hintText: widget.hint,
            hintStyle: AnText.body.copyWith(color: c.inkFaint),
            prefixIcon: Icon(AnIcons.search, size: AnSize.icon, color: c.inkFaint),
            prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 0),
            suffixIcon: value.text.isEmpty
                ? null
                : GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      widget.onChanged?.call('');
                    },
                    child: Icon(AnIcons.close, size: AnSize.iconSm, color: c.inkFaint),
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 0),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s8),
            enabledBorder: border(c.line, AnSize.hairline),
            focusedBorder: border(c.accentLine, AnSize.focusRing),
          ),
        );
      },
    );
  }
}
