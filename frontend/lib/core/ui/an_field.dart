import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_dropdown.dart';
import 'an_editable_value.dart';
import 'an_lead_value.dart';
import 'an_tags.dart';

/// One row of an [AnKv] definition list. [editable] (with the list's `onChanged`) makes the value
/// editable in place via [AnEditableValue]; [editor] picks free-text vs an enum dropdown. The text
/// field is named `label` (not `key`) to avoid clashing with [Widget.key]. AnKv 行:可编辑则就地编辑。
class AnKvRow {
  const AnKvRow(
    this.label,
    this.value, {
    this.editable = false,
    this.editor = AnEditKind.input,
    this.options = const [],
    this.tags,
    this.tagsPlaceholder,
  });

  /// A TAGS row: its value is a SET of tags edited via ➕add / ✕remove pills (revealed on row hover /
  /// focus, matching the far-right pencil so the whole list stays read-first) — NOT a text field /
  /// dropdown. [tags] is the current set; [tagsPlaceholder] labels the add field. Emitted through the
  /// list [AnKv.onChanged] like any other row (the emitted row carries the new [tags]).
  /// 标签行:值=一组标签,经 ➕/✕ 药丸编辑(hover/聚焦时显,与最右铅笔同手感、整列读优先),非文本/下拉。
  const AnKvRow.tags(this.label, List<String> this.tags, {this.tagsPlaceholder})
      : value = null,
        editable = true,
        editor = AnEditKind.input,
        options = const [];

  final String label;
  final String? value;
  final bool editable;
  final AnEditKind editor;

  /// Options for [AnEditKind.select]. 枚举选项。
  final List<AnDropdownOption<String>> options;

  /// Non-null → this is a tags row (see [AnKvRow.tags]). 非空=标签行。
  final List<String>? tags;
  final String? tagsPlaceholder;

  AnKvRow _withValue(String v) =>
      AnKvRow(label, v, editable: editable, editor: editor, options: options);
  AnKvRow _withTags(List<String> t) => AnKvRow.tags(label, t, tagsPlaceholder: tagsPlaceholder);
}

/// C3 — a compact definition list: key (left) · value (right), one [AnSize.row] per row, layered by
/// ink colour + whitespace (no rule lines). Editable rows ([AnKvRow.editable] + a non-null [onChanged])
/// edit in place via the shared [AnEditableValue] core (hover pencil → field / dropdown, blur-commit,
/// cancel-priority); read-only rows are a single merged "label: value" semantics node. [mono] sets the
/// value monospace (+ tabular figures) for ids / hashes; [wrap] lets a long value wrap. Editing one row
/// rebuilds the list with that row's new value and emits the WHOLE list via [onChanged] (aligned with
/// AnTags, not the demo's positional callback). [rows] are treated as position-stable (each row's edit
/// state is reused by list position) — a consumer that reorders / filters rows must wrap them in keys.
///
/// C3——紧凑定义列表:key 左 · value 右,每行 row 高,靠字色 + 留白分层(无横线)。可编辑行经共享 AnEditableValue 核
/// 就地编辑(hover 铅笔→框/下拉、失焦提交、取消优先);只读行为单一 merge 的「label: value」语义节点。mono=值等宽
/// (+ tabular)供 id/hash;wrap=长值换行。改一行→重建整列经 onChanged 派出(对齐 AnTags,非 demo 位置参回调)。
class AnKv extends StatelessWidget {
  const AnKv({
    required this.rows,
    this.onChanged,
    this.mono = false,
    this.wrap = false,
    super.key,
  });

  final List<AnKvRow> rows;

  /// null → all rows read-only (AnKv is also the canonical key/value DISPLAY). 空=纯展示。
  final ValueChanged<List<AnKvRow>>? onChanged;
  final bool mono;
  final bool wrap;

  // The far-right edit affordance (pencil ↔ ✓✕) reserves a trailing gutter on editable rows; when the
  // list HAS such rows, read-only rows reserve a matching gutter so every value shares one right edge
  // (a pure read-only list keeps its values flush to the edge, unchanged). 有编辑触点时只读行留同宽右槽,值共右缘。
  bool get _hasEditAffordance => onChanged != null && rows.any((r) => r.editable || r.tags != null);

  void _emit(int i, String v) {
    final next = [...rows]..[i] = rows[i]._withValue(v);
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) _row(context, c, i, rows[i]),
      ],
    );
  }

  Widget _row(BuildContext context, AnColors c, int i, AnKvRow row) {
    final keyText = Text(
      row.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AnText.body.copyWith(color: c.inkMuted),
    );

    // Tags row: ➕add / ✕remove pills (hover-revealed), emitted through the list onChanged. A read-only
    // list (onChanged == null) still displays its pills. 标签行:➕/✕ 药丸(hover 显);只读列表也展示药丸。
    if (row.tags != null) {
      return _KvTagsRow(
        leading: keyText,
        tags: row.tags!,
        placeholder: row.tagsPlaceholder,
        onChanged: onChanged == null ? null : (t) => onChanged!([...rows]..[i] = rows[i]._withTags(t)),
      );
    }

    if (row.editable && onChanged != null) {
      return AnEditableValue(
        leading: keyText,
        fieldLabel: row.label,
        value: row.value ?? '',
        rowHeight: AnSize.row,
        valueColor: c.inkFaint,
        editor: row.editor,
        options: row.options,
        mono: mono,
        wrap: wrap,
        onChanged: (v) => _emit(i, v),
      );
    }

    // Read-only row: one merged "label: value" node — no pencil, key→value connected for SR. 只读行单节点。
    final shown = (row.value == null || row.value!.isEmpty) ? '—' : row.value!;
    // Value column → the shared tabular value style ("值列 tabular 铁律"); mono only switches family. 值列样式单源。
    final valueStyle = AnText.value(mono: mono).copyWith(color: c.inkFaint);
    return Semantics(
      label: '${row.label}: $shown',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: AnSize.row),
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
          // key hugs content (capped), value fills the remainder + sits flush-right (AnLeadValue). 键贴内容、值吃余量贴右。
          child: AnLeadValue(
            leading: keyText,
            wrap: wrap,
            // Match the editable rows' far-right affordance gutter so all values share one right edge. 留同宽右槽对齐。
            afterValue: _hasEditAffordance ? const SizedBox(width: AnSize.controlSm) : null,
            trailing: Text(
              shown,
              textAlign: wrap ? TextAlign.left : TextAlign.right,
              maxLines: wrap ? null : 1,
              softWrap: wrap,
              overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
        ),
      ),
    );
  }
}

/// C2 — a key/value big row: [label] (+ optional [hint]) left, value right. Three modes:
/// • [value] != null + [editable] (+ onChanged) → editable in place via [AnEditableValue] (pencil →
///   field / dropdown, blur-commit, cancel-priority);
/// • [value] != null, not editable → a read-only value (right-aligned, no pencil);
/// • [value] == null → the [child] control (a dropdown / switch / button) sits right-aligned, no edit.
/// Taller than [AnKv] ([AnSize.islandHead]) — a reading-weight field, not a dense list. Field's label is
/// full-ink and the value inkMuted (vs Kv's muted key + faint value), via the shared core's params.
/// [wrap] lets a long value wrap.
///
/// C2——键值大行:label(+ 可选 hint)左 + 值右。三态:value+editable→AnEditableValue 就地编辑;value 非可编辑→
/// 只读值;value 为空→渲 child 控件(下拉/开关,右对齐)。行高比 AnKv 高(islandHead)、阅读型字段。
/// Field label=ink、value=inkMuted(异于 Kv 的 muted key + faint value)。wrap=长值换行。
class AnField extends StatelessWidget {
  const AnField({
    required this.label,
    this.hint,
    this.value,
    this.editable = false,
    this.editor = AnEditKind.input,
    this.options = const [],
    this.wrap = false,
    this.child,
    this.onChanged,
    super.key,
  });

  final String label;
  final String? hint;
  final String? value;
  final bool editable;
  final AnEditKind editor;
  final List<AnDropdownOption<String>> options;
  final bool wrap;

  /// Control rendered when [value] is null (a dropdown / switch / button), right-aligned. value 为空时渲的控件。
  final Widget? child;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lead = _leading(c);

    // value + editable → shared edit core (handles pencil / field / ✓✕ / blur / focus / announce).
    if (value != null && editable && onChanged != null) {
      return AnEditableValue(
        leading: lead,
        fieldLabel: label,
        value: value!,
        rowHeight: AnSize.islandHead,
        valueColor: c.inkMuted,
        editor: editor,
        options: options,
        wrap: wrap,
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
        style: AnText.value().copyWith(color: c.inkMuted),
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
        // hint: faint meta, wraps onto multiple lines (word boundaries) — a long mechanism / description. hint 多行换行。
        Text(hint!, softWrap: true, style: AnText.meta.copyWith(color: c.inkFaint)),
      ],
    );
  }
}

/// The tags-row body for [AnKv] (an [AnKvRow.tags]) — the pill sibling of [AnEditableValue]: read-first
/// pills that reveal ✕remove (per pill) + a ➕add field on row hover / focus (the same idiom as the
/// far-right pencil), so a whole [AnKv] stays calm at rest. Focus keeps it revealed after the mouse
/// leaves (so a mid-add doesn't collapse). A null [onChanged] renders display-only pills. Shares the
/// [AnLeadValue] geometry + [AnSize.row] floor + s8 inset with the text rows, so columns align.
/// 标签行体(AnKv 的 AnKvRow.tags)——AnEditableValue 的药丸对偶:静态只读药丸,hover/聚焦揭示每枚 ✕ + ➕
/// 添加框(同最右铅笔手感);聚焦后鼠标移开仍保持揭示(不中断添加)。onChanged 空=纯展示。与文本行同几何、同行高、同内距,列对齐。
class _KvTagsRow extends StatefulWidget {
  const _KvTagsRow({
    required this.leading,
    required this.tags,
    this.placeholder,
    this.onChanged,
  });

  final Widget leading;
  final List<String> tags;
  final String? placeholder;
  final ValueChanged<List<String>>? onChanged;

  @override
  State<_KvTagsRow> createState() => _KvTagsRowState();
}

class _KvTagsRowState extends State<_KvTagsRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final editable = widget.onChanged != null;
    final reduced = AnMotionPref.reduced(context);
    // Revealed = the ✕/➕ affordances show. Mirrors AnEditableValue's hover/focus-revealed far-right
    // pencil so the whole AnKv reads read-first. 揭示=显 ✕/➕,与铅笔同门控、整列读优先。
    final revealed = editable && (_hovered || _focused);
    final Widget content = widget.tags.isEmpty && !revealed
        ? Text('—', style: AnText.value().copyWith(color: c.inkFaint))
        : AnTags(
            tags: [for (final t in widget.tags) AnTag(t)],
            readOnly: !revealed,
            placeholder: widget.placeholder,
            onChanged: editable ? (next) => widget.onChanged!([for (final t in next) t.label]) : null,
          );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        // A non-traversable Focus node just to observe descendant (add-field / ✕) focus so the reveal
        // survives the mouse leaving mid-add. 不可聚焦的 Focus 仅观察后代焦点,添加中鼠标移开仍揭示。
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : AnMotion.fast,
            constraints: const BoxConstraints(minHeight: AnSize.row),
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
            decoration: BoxDecoration(
              color: c.surfaceHover.whenActive(revealed),
              borderRadius: BorderRadius.circular(AnRadius.button),
            ),
            child: AnLeadValue(leading: widget.leading, wrap: true, trailing: content),
          ),
        ),
      ),
    );
  }
}
