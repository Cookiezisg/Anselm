import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'icons.dart';

/// The secret-entry field (WRK-062 S0/S2) — API keys, tokens, anything paste-shaped. Its three
/// REDEEMABLE promises (never marketing copy):
///  1. masked by default, eye-toggle to reveal — the value never echoes into a plain row;
///  2. the value lives ONLY in this controller — no prefs, no logs, no exception payloads
///     (submission hands the string to the caller and that's the whole custody chain);
///  3. [clear] after a successful submit — the caller empties the field so the secret doesn't
///     linger on screen (NOT a "wiped from memory" claim — Dart strings don't do that).
/// Paste hygiene: leading/trailing whitespace (the classic invisible copy artifact) is trimmed on
/// change. mono glyphs; block width.
///
/// 密钥输入框——三条**可兑现**承诺:①默认掩码+可见性切换,值绝不回显进普通行;②值只活在本 controller
/// ——不进 prefs/日志/异常载荷(提交把串交给调用方,监管链到此为止);③提交成功后 [clear](调用方清空,
/// 密钥不驻留屏上——不承诺「清内存」,Dart 字符串做不到)。粘贴卫生:首尾隐形空白 onChange 即 trim。
class AnSecretField extends StatefulWidget {
  const AnSecretField({
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.revealLabel,
    this.concealLabel,
    super.key,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;

  /// i18n labels for the eye toggle's semantics. 可见性切换的语义文案。
  final String? revealLabel;
  final String? concealLabel;

  @override
  State<AnSecretField> createState() => _AnSecretFieldState();
}

class _AnSecretFieldState extends State<AnSecretField> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  bool _revealed = false;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    // Paste hygiene: strip the invisible whitespace a copy so often drags along. 粘贴隐形空白即剪。
    final trimmed = v.trim();
    if (trimmed != v) {
      _controller.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    widget.onChanged?.call(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: AnSize.control,
      padding: const EdgeInsets.only(left: AnSpace.s8, right: AnSpace.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.button),
        border: Border.all(color: c.line, width: AnSize.hairline),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            obscureText: !_revealed,
            obscuringCharacter: '•',
            autocorrect: false,
            enableSuggestions: false,
            style: AnText.mono.copyWith(color: c.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.placeholder,
              hintStyle: AnText.body.copyWith(color: c.inkFaint),
            ),
            onChanged: _onChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
        AnButton.iconOnly(
          _revealed ? AnIcons.eyeOff : AnIcons.eye,
          size: AnButtonSize.sm,
          onPressed: () => setState(() => _revealed = !_revealed),
          semanticLabel: (_revealed ? widget.concealLabel : widget.revealLabel) ?? '',
        ),
      ]),
    );
  }
}
