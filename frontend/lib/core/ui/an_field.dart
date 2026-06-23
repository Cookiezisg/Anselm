import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_dropdown.dart';
import 'an_editable_value.dart';

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
  });

  final String label;
  final String? value;
  final bool editable;
  final AnEditKind editor;

  /// Options for [AnEditKind.select]. 枚举选项。
  final List<AnDropdownOption<String>> options;

  AnKvRow _withValue(String v) =>
      AnKvRow(label, v, editable: editable, editor: editor, options: options);
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
    // Value column → tabular figures UNCONDITIONALLY (demo .v tabular-nums always; mono only switches
    // family) so numeric columns align + match the editable rows. 值列无条件 tabular,mono 只切字体族。
    final valueStyle = (mono
            ? AnText.mono.copyWith(fontSize: AnText.meta.fontSize, fontFeatures: const [FontFeature.tabularFigures()])
            : AnText.body.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))
        .copyWith(color: c.inkFaint);
    return Semantics(
      label: '${row.label}: $shown',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: AnSize.row),
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
          child: Row(
            children: [
              Flexible(child: keyText),
              const SizedBox(width: AnSpace.s8),
              const Expanded(child: SizedBox.shrink()), // grow: pins the value right 撑开、值钉右
              Flexible(
                child: Text(
                  shown,
                  textAlign: wrap ? TextAlign.left : TextAlign.right,
                  maxLines: wrap ? null : 1,
                  softWrap: wrap,
                  overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
