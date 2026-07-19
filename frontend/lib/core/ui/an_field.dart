import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_dropdown.dart';
import 'an_editable_value.dart';
import 'an_lead_value.dart';

/// C2 — a key/value big row: [label] (+ optional [hint]) left, value right. Three modes:
/// • [value] != null + [editable] (+ onChanged) → editable in place via [AnEditableValue] (far-right
///   pencil → field / dropdown, blur-commit, cancel-priority);
/// • [value] != null, not editable → a read-only value (right-aligned; [wrap] lets it fill + wrap);
/// • [value] == null → the [child] control (a dropdown / switch / button) sits right-aligned, no edit.
/// Taller than [AnKv] ([AnSize.islandHead]) — a reading-weight field, not a dense list. Field's label is
/// full-ink and the value inkMuted (vs Kv's muted key + faint value), via the shared core's params.
///
/// C2——键值大行:label(+ 可选 hint)左 + 值右。三态:value+editable→AnEditableValue 就地编辑;value 非可编辑→
/// 只读值(wrap 可换行);value 为空→渲 child 控件(下拉/开关,右对齐)。行高比 AnKv 高(islandHead)、阅读型字段。
/// Field label=ink、value=inkMuted(异于 Kv 的 muted key + faint value)。
class AnField extends StatelessWidget {
  const AnField({
    required this.label,
    this.hint,
    this.value,
    this.editable = false,
    this.editor = AnEditKind.input,
    this.options = const [],
    this.wrap = false,
    this.dense = false,
    this.child,
    this.onChanged,
    super.key,
  }) : assert(!(editable && wrap), 'wrap is for the read-only value mode — editable values are flush-right. wrap 仅限只读值');

  final String label;
  final String? hint;
  final String? value;
  final bool editable;
  final AnEditKind editor;
  final List<AnDropdownOption<String>> options;

  /// Long READ-ONLY value fills + wraps left-aligned. 只读长值换行。
  final bool wrap;

  /// Chrome-tier field (value 13, hint 12) — mirrors [AnKv.dense]; the default is the content tier
  /// (value [AnText.valueReading] 15, hint [AnText.label] 13). chrome 档(值 13/提示 12),镜像 AnKv.dense;
  /// 默认内容档(值 15/提示 13)。
  final bool dense;

  /// Control rendered when [value] is null (a dropdown / switch / button), right-aligned. value 为空时渲的控件。
  final Widget? child;
  final ValueChanged<String>? onChanged;

  TextStyle get _valueStyle => dense ? AnText.value() : AnText.valueReading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lead = _leading(c);

    // value + editable → shared edit core (handles pencil / field / Cancel/Save / blur / announce).
    if (value != null && editable && onChanged != null) {
      return AnEditableValue(
        leading: lead,
        fieldLabel: label,
        value: value!,
        rowHeight: AnSize.islandHead,
        valueColor: c.inkMuted,
        valueStyle: _valueStyle,
        editor: editor,
        options: options,
        onChanged: onChanged!, // guarded above (instance field isn't promoted by the null-check) 上文已判非空
      );
    }

    // read-only value, or the child-slot control.
    final String? semValue;
    final Widget right;
    if (value != null) {
      final shown = value!.isEmpty ? '—' : value!;
      semValue = shown;
      right = Text(
        shown,
        textAlign: wrap ? TextAlign.left : TextAlign.right,
        maxLines: wrap ? null : 1,
        softWrap: wrap,
        overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
        style: _valueStyle.copyWith(color: c.inkMuted),
      );
    } else {
      semValue = null;
      right = child ?? const SizedBox.shrink();
    }

    final row = Container(
      constraints: const BoxConstraints(minHeight: AnSize.islandHead),
      padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
      // label hugs content (capped), value/control fills the remainder + flush-right (AnLeadValue); only a
      // text value honours wrap — the child-slot control is non-wrap, Align-right. 标签贴内容、值/控件吃余量贴右。
      child: AnLeadValue(
        leading: lead,
        wrap: value != null && wrap,
        trailing: right,
      ),
    );

    // read-only value → one merged "label(, hint): value" node; child slot → label + child each
    // keep their own semantics (the control must stay reachable). 只读单节点;child 态各自可达。
    if (semValue != null) {
      final sem = hint != null ? '$label, $hint: $semValue' : '$label: $semValue';
      return Semantics(label: sem, child: ExcludeSemantics(child: row));
    }
    // child slot: container (NOT merged — the control must stay reachable) so label + control group,
    // matching the editable path's explicitChildNodes. 控件槽:容器不 merge(控件可达),三态语义齐。
    return Semantics(container: true, explicitChildNodes: true, child: row);
  }

  Widget _leading(AnColors c) {
    final labelText = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.body.copyWith(color: c.ink));
    if (hint == null) return labelText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelText,
        const SizedBox(height: AnSpace.s2), // demo .l gap = --grid/2 列内间距
        // hint: faint, wraps onto multiple lines (word boundaries) — a long mechanism / description.
        // Content tier reads it at label 13 (metadata inside content is never 12); dense keeps meta 12.
        // hint 多行换行;内容档 13(内容内元数据不用 12)、dense 守 12。
        Text(hint!, softWrap: true, style: (dense ? AnText.meta : AnText.label).copyWith(color: c.inkFaint)),
      ],
    );
  }
}
