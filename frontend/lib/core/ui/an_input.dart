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
    this.seamless = false,
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

  /// Borderless, text-height field for in-place edit — no box chrome, no min-height, so it occupies
  /// the SAME footprint as the display text it replaces (no layout jump). Caller sizes the width.
  /// 无边框、文字高的就地编辑字段——无框、无最小高,与被替换的展示文字同占位(不跳)。宽由调用方定。
  final bool seamless;
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

  // Cached (not getter-lazy) so listener management is deterministic across focusNode/controller
  // swaps — a getter re-evaluated in dispose would remove the listener from the WRONG node.
  // 缓存(非懒 getter):focusNode/controller 被父级替换时监听迁移确定,避免在错的节点上摘监听。
  late TextEditingController _controller;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? (_ownController = TextEditingController(text: widget.initialValue));
    _focus = widget.focusNode ?? (_ownFocus = FocusNode());
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AnInput old) {
    super.didUpdateWidget(old);
    if (widget.focusNode != old.focusNode) {
      _focus.removeListener(_onFocusChange);
      if (old.focusNode == null) {
        _ownFocus?.dispose();
        _ownFocus = null;
      }
      _focus = widget.focusNode ?? (_ownFocus = FocusNode());
      _focus.addListener(_onFocusChange);
      _focused = _focus.hasFocus;
    }
    if (widget.controller != old.controller) {
      if (old.controller == null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller = widget.controller ?? (_ownController = TextEditingController(text: widget.initialValue));
    }
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

    // Seamless: no box chrome, text-height — the caller sizes width (Flexible/Expanded) so it slots
    // in where the display text was, no jump. 无框、文字高:宽由调用方约束,原位替换展示文字、不跳。
    if (widget.seamless) {
      return Opacity(opacity: widget.enabled ? 1 : 0.4, child: field);
    }

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

    // full fills width — but only with a bounded parent; otherwise fall back to inputMin so an
    // empty full input doesn't collapse to a thin line (and doesn't crash unbounded).
    // full 占满需有界父;否则退化到 inputMin,空的 full 输入不塌成细线、也不在无界处崩。
    return Opacity(
      opacity: widget.enabled ? 1 : 0.4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.full && constraints.hasBoundedWidth) {
            return SizedBox(width: double.infinity, child: box);
          }
          return SizedBox(width: AnSize.inputMin, child: box);
        },
      ),
    );
  }
}
