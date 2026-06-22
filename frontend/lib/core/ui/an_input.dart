import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// B2 — the value leaf. Single-line by default; [multiline] grows to a textarea; [mono] is the
/// compact monospace variant; [full] fills width. Focus is quiet by design — the border deepens
/// (line → lineStrong) with a plain caret, NO blue ring/fill (monochrome). [enabled]/[readOnly]
/// share the kit's disabled/muted vocabulary.
///
/// B2——值叶子。默认单行;multiline→文本域;mono→等宽紧凑;full→占满。聚焦克制:边描深(line→lineStrong)
/// + 朴素光标,无蓝环/蓝底(单色)。enabled/readOnly 沿用套件禁用/静音语汇。
class AnInput extends StatefulWidget {
  const AnInput({
    this.controller,
    this.initialValue,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.multiline = false,
    this.mono = false,
    this.full = false,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool multiline;
  final bool mono;
  final bool full;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AnInput> createState() => _AnInputState();
}

class _AnInputState extends State<AnInput> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _focused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController(text: widget.initialValue));
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = widget.mono ? AnText.mono.copyWith(fontSize: AnText.meta.fontSize) : AnText.body;
    final style = base.copyWith(color: widget.readOnly ? c.inkFaint : c.ink);
    final borderColor = _focused ? c.lineStrong : c.line;

    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.multiline ? null : 1,
      minLines: widget.multiline ? 3 : 1,
      expands: false,
      cursorColor: c.ink,
      cursorWidth: 1.5,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        hintText: widget.placeholder,
        hintStyle: style.copyWith(color: c.inkFaint),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
    );

    final box = AnimatedContainer(
      duration: AnMotion.fast,
      height: widget.multiline ? null : AnSize.control,
      constraints: BoxConstraints(minHeight: widget.multiline ? AnSize.control * 2 : AnSize.control),
      padding: EdgeInsets.symmetric(
        horizontal: AnSpace.s12,
        vertical: widget.multiline ? AnSpace.s8 : 0,
      ),
      alignment: widget.multiline ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: borderColor, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.button),
      ),
      child: field,
    );

    final sized = widget.full ? box : SizedBox(width: AnSize.inputMin, child: box);
    return Opacity(opacity: widget.enabled ? 1 : 0.4, child: sized);
  }
}
