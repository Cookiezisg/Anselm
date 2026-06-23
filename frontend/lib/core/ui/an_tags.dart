import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'an_input.dart';
import 'an_interactive.dart';
import 'an_status_dot.dart';
import 'dry_intrinsic_width.dart';
import 'icons.dart';
import 'tone.dart';

/// A tag with an optional [tone] and an optional [health] status dot. 标签:可选语气 + 健康点。
class AnTag {
  const AnTag(this.label, {this.tone, this.health});

  final String label;
  final AnTone? tone;
  final AnStatus? health;
}

/// C6 — an editable tag set: a [Wrap] of pills (optional health dot + label + remove-×) with an
/// inline seamless add field. HAND-ROLL (textfield_tags is stale + bakes Material chrome; InputChip
/// brings Material tap-targets/selection-blue and has no separately-focusable delete). Composes on
/// AnInteractive (the ×, kit-canonical hover/focus/press) + AnBadge geometry + AnStatusDot + the
/// seamless AnInput grown by [DryIntrinsicWidth]. Stateful — owns + disposes the add field's
/// controller/focus node.
///
/// [readOnly] (or a null [onChanged]) drops the × and the add field → pure display pills (so AnTags is
/// the canonical tag DISPLAY too). [single] enforces the one-value invariant in STATE. Adding a
/// DUPLICATE is rejected and briefly FLASHES the existing pill (decision ④). Backspace removes the
/// last tag only when the field is empty (scoped, so it never eats a normal backspace).
///
/// a11y: each remove-× is its OWN focusable Semantics(button, label "remove {tag}"); the health dot
/// is decorative (ExcludeSemantics); [FocusTraversalGroup] walks pills then the field in reading order.
///
/// C6——可编辑标签集:Wrap 药丸(健康点+标签+移除×)+ 内联 seamless 添加框。HAND-ROLL,搭 AnInteractive(×)+
/// AnBadge 几何 + AnStatusDot + DryIntrinsicWidth 撑的 seamless AnInput。Stateful 持有并 dispose 添加框
/// controller/focus。readOnly/onChanged 空=纯展示。single 在状态层强制单值。重复添加=拒 + 闪现已存在药丸(决策④)。
/// 空框时 Backspace 删末标签(作用域化、不吃正常退格)。a11y:每个 × 自有可聚焦 button 标签,健康点装饰排除,
/// FocusTraversalGroup 阅读序。
class AnTags extends StatefulWidget {
  const AnTags({
    required this.tags,
    this.onChanged,
    this.readOnly = false,
    this.single = false,
    this.placeholder,
    super.key,
  });

  final List<AnTag> tags;

  /// null (or [readOnly]) → display-only pills. 空/只读=纯展示。
  final ValueChanged<List<AnTag>>? onChanged;
  final bool readOnly;

  /// Single mode: adding replaces the one value (enforced in state). 单值模式。
  final bool single;
  final String? placeholder;

  @override
  State<AnTags> createState() => _AnTagsState();
}

class _AnTagsState extends State<AnTags> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  int? _flash; // index of a duplicate pill flashing to draw attention 重复时闪现的药丸下标
  Timer? _flashTimer; // held so dispose cancels a pending flash-clear (no "Timer still pending") 持有以便 dispose 取消

  bool get _editable => widget.onChanged != null && !widget.readOnly;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _indexOf(String label) {
    for (var i = 0; i < widget.tags.length; i++) {
      if (widget.tags[i].label.toLowerCase() == label.toLowerCase()) return i;
    }
    return -1;
  }

  void _add() {
    final label = _ctl.text.trim();
    if (label.isEmpty) return;
    final dup = _indexOf(label);
    if (dup >= 0) {
      // decision ④: reject + briefly flash the existing pill (don't add, don't silently swallow). 拒+闪现。
      _ctl.clear();
      setState(() => _flash = dup);
      _flashTimer?.cancel();
      _flashTimer = Timer(AnMotion.breath, () {
        if (mounted) setState(() => _flash = null);
      });
      return;
    }
    final next = widget.single ? [AnTag(label)] : [...widget.tags, AnTag(label)];
    _ctl.clear();
    widget.onChanged!(next);
  }

  void _remove(int i) {
    widget.onChanged!([...widget.tags]..removeAt(i));
  }

  // Backspace on an EMPTY field removes the last tag (scoped so it never eats a normal backspace).
  // 空框退格删末标签(作用域化、不吃正常退格)。
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _ctl.text.isEmpty &&
        widget.tags.isNotEmpty) {
      _remove(widget.tags.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusTraversalGroup(
      child: Wrap(
        spacing: AnSpace.s6,
        runSpacing: AnSpace.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < widget.tags.length; i++) _pill(c, i, widget.tags[i]),
          if (_editable) _addField(c),
        ],
      ),
    );
  }

  Widget _pill(AnColors c, int i, AnTag tag) {
    final tone = tag.tone ?? AnTone.none;
    final flashing = _flash == i;
    final reduced = AnMotionPref.reduced(context);
    return AnimatedContainer(
      duration: reduced ? Duration.zero : AnMotion.fast,
      height: AnSize.badge,
      padding: const EdgeInsets.symmetric(horizontal: AnSize.badgePadX),
      decoration: BoxDecoration(
        color: flashing ? c.accentSoft : tone.softBg(c),
        borderRadius: BorderRadius.circular(AnRadius.pill),
        border: flashing ? Border.all(color: c.accent, width: AnSize.hairline) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.health != null) ...[
            ExcludeSemantics(child: AnStatusDot(tag.health!)),
            const SizedBox(width: AnSpace.s6),
          ],
          // Flexible + ellipsis: a single tag wider than the row truncates instead of overflowing.
          // Flexible+省略:单标签超宽则截断、不溢出。
          Flexible(
            child: Text(tag.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AnText.meta.copyWith(color: tone == AnTone.none ? c.ink : tone.fg(c))),
          ),
          if (_editable) ...[
            const SizedBox(width: AnSpace.s6),
            _removeX(c, i, tag),
          ],
        ],
      ),
    );
  }

  Widget _removeX(AnColors c, int i, AnTag tag) {
    return MergeSemantics(
      child: Semantics(
        label: context.t.feedback.removeTag(name: tag.label),
        child: AnInteractive(
          onTap: () => _remove(i),
          builder: (ctx, states) => SizedBox(
            width: AnSize.tagRemoveHit,
            height: AnSize.tagRemoveHit,
            child: Icon(AnIcons.close, size: AnSize.iconSm, color: states.isActive ? c.ink : c.inkFaint),
          ),
        ),
      ),
    );
  }

  Widget _addField(AnColors c) {
    // Grows with the typed content (DryIntrinsicWidth), floored at inlineEditMin so an empty field
    // stays clickable. 随输入增长,空框不塌、可点。
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.menuMaxWidth),
      child: DryIntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: AnSize.inlineEditMin),
          child: Focus(
            onKeyEvent: _onKey,
            child: AnInput(
              controller: _ctl,
              focusNode: _focus,
              seamless: true,
              placeholder: widget.placeholder,
              onSubmitted: (_) => _add(),
            ),
          ),
        ),
      ),
    );
  }
}
