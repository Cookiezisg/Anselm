import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_button.dart';
import 'an_dropdown.dart';
import 'an_editable_value.dart';
import 'an_lead_value.dart';
import 'an_tags.dart';
import 'icons.dart';

/// One row of an [AnKv] definition list — a TEXT row (default ctor) or a TAGS row ([AnKvRow.tags]).
/// [editable] (with the list's `onChanged`) makes a text value editable in place via
/// [AnEditableValue]; [editor] picks free-text vs an enum dropdown. [wrap] lets a long READ-ONLY
/// value fill + wrap left-aligned (label top-pinned) — it is per-row and excluded from editable rows
/// (editable values are flush-right single-line by decree). The text field is named `label` (not
/// `key`) to avoid clashing with [Widget.key].
/// AnKv 行:文本行 / 标签行两种。editable=就地编辑;wrap 仅限只读文本行(长值左对齐换行);可编辑值恒贴右单行。
class AnKvRow {
  const AnKvRow(
    this.label,
    this.value, {
    this.editable = false,
    this.editor = AnEditKind.input,
    this.options = const [],
    this.wrap = false,
  })  : tags = null,
        tagsPlaceholder = null,
        assert(!(editable && wrap), 'wrap is for read-only display rows — editable values are flush-right. wrap 仅限只读行');

  /// A TAGS row: the value is a SET of tags. At rest = plain pills flush right; on row hover/focus a
  /// ✕ per pill and a far-right ➕ reveal (the same rail + idiom as the text rows' pencil); pressing ➕
  /// mounts an autofocused inline input (Enter chains, Esc/blur dismisses). Emitted through the list
  /// [AnKv.onChanged] like any other row (the emitted row carries the new [tags]).
  /// 标签行:静态干净药丸贴右;hover/聚焦揭示每丸 ✕ + 最右 ➕(与铅笔同轨同手感);按 ➕ 才挂出自聚焦输入框
  /// (Enter 连加、Esc/失焦收);经列表 onChanged 派出(行携新 tags)。
  const AnKvRow.tags(this.label, List<String> this.tags, {this.tagsPlaceholder})
      : value = null,
        editable = false,
        editor = AnEditKind.input,
        options = const [],
        wrap = false;

  final String label;
  final String? value;
  final bool editable;
  final AnEditKind editor;

  /// Options for [AnEditKind.select]. 枚举选项。
  final List<AnDropdownOption<String>> options;

  /// Long read-only value fills + wraps left-aligned. 只读长值换行。
  final bool wrap;

  /// Non-null → this is a tags row (see [AnKvRow.tags]). 非空=标签行。
  final List<String>? tags;
  final String? tagsPlaceholder;

  AnKvRow _withValue(String v) =>
      AnKvRow(label, v, editable: editable, editor: editor, options: options, wrap: wrap);
  AnKvRow _withTags(List<String> t) => AnKvRow.tags(label, t, tagsPlaceholder: tagsPlaceholder);
}

/// C3 — a compact definition list: key (left) · value flush-RIGHT, one [AnSize.row] per row, layered
/// by ink colour + whitespace (no rule lines). Editable text rows ([AnKvRow.editable] + a non-null
/// [onChanged]) edit in place via the shared [AnEditableValue] core (far-right hover pencil → field /
/// ghost dropdown, blur-commit, cancel-priority); tags rows ([AnKvRow.tags]) edit via ➕/✕ pills;
/// read-only rows are a single merged "label: value" semantics node. [mono] sets values monospace
/// (+ tabular figures) for ids / hashes. Editing one row rebuilds the list with that row's new value
/// and emits the WHOLE list via [onChanged] (aligned with AnTags, not the demo's positional callback).
/// [rows] are treated as position-stable (each row's edit state is reused by list position) — a
/// consumer that reorders / filters rows must wrap them in keys.
///
/// **The affordance rail**: every edit affordance (pencil, Cancel/Save, ➕, the select ghost's inset)
/// lives in a far-right rail of width [AnSize.controlSm] (an iconOnly-sm button is a controlSm square
/// by construction — see an_button.dart). When the list is EDITABLE (a non-null [onChanged] with at
/// least one editable/tags row), read-only rows reserve the same rail so every value shares ONE right
/// edge; a pure display list has no rail and its values sit flush to the true edge (unchanged). The
/// one documented exception: the actively-edited row's Cancel/Save pair is transiently wider than the
/// rail, so that row's value edge shifts left during the edit — approved far-right-affordance behavior.
///
/// C3——紧凑定义列表:key 左 · value **贴右**,每行 row 高,靠字色 + 留白分层。可编辑文本行经 AnEditableValue
/// (最右 hover 铅笔→框/下拉),标签行经 ➕/✕ 药丸;只读行单一 merge 语义节点。改一行→重建整列经 onChanged 派出。
/// **触点轨**:一切编辑触点住在宽 controlSm 的最右轨(iconOnly-sm 按钮=controlSm 方块,构造性相等);列表可编辑时
/// 只读行留同宽轨、全列值共一右缘;纯展示列表零轨、值贴真边。唯一例外:编辑中行的 取消/保存 短暂比轨宽,该行值缘
/// 编辑期间左移——即钦定的「触点贴值最右」行为。
class AnKv extends StatelessWidget {
  const AnKv({
    required this.rows,
    this.onChanged,
    this.mono = false,
    super.key,
  });

  final List<AnKvRow> rows;

  /// null → all rows read-only (AnKv is also the canonical key/value DISPLAY). 空=纯展示。
  final ValueChanged<List<AnKvRow>>? onChanged;
  final bool mono;

  /// The list carries edit affordances → all rows reserve the far-right rail (see class doc).
  /// 列表带编辑触点 → 全列留最右轨。
  bool get _railed => onChanged != null && rows.any((r) => r.editable || r.tags != null);

  void _emitRow(int i, AnKvRow next) => onChanged!([...rows]..[i] = next);

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

    if (row.tags != null) {
      return _KvTagsRow(
        leading: keyText,
        fieldLabel: row.label,
        tags: row.tags!,
        placeholder: row.tagsPlaceholder,
        railed: _railed,
        onChanged: onChanged == null ? null : (t) => _emitRow(i, row._withTags(t)),
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
        onChanged: (v) => _emitRow(i, row._withValue(v)),
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
          // key hugs content (capped), value fills the remainder + sits flush-right (AnLeadValue);
          // in an editable list the rail placeholder keeps this value on the shared right edge.
          // 键贴内容、值吃余量贴右;可编辑列表中经轨占位与他行共右缘。
          child: AnLeadValue(
            leading: keyText,
            wrap: row.wrap,
            afterValue: _railed ? const SizedBox(width: AnSize.controlSm) : null,
            trailing: Text(
              shown,
              textAlign: row.wrap ? TextAlign.left : TextAlign.right,
              maxLines: row.wrap ? null : 1,
              softWrap: row.wrap,
              overflow: row.wrap ? TextOverflow.clip : TextOverflow.ellipsis,
              style: valueStyle,
            ),
          ),
        ),
      ),
    );
  }
}

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

  /// Control rendered when [value] is null (a dropdown / switch / button), right-aligned. value 为空时渲的控件。
  final Widget? child;
  final ValueChanged<String>? onChanged;

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

/// The tags-row body for [AnKv] (an [AnKvRow.tags]) — the pill sibling of [AnEditableValue], riding
/// the same non-wrap [AnLeadValue] geometry (flush-right value, everything vertically centered) and
/// the same reveal idiom: at rest, plain pills (or an em-dash when empty); on row hover — or when the
/// always-in-tree, opacity-0 far-right ➕ takes keyboard focus (the pencil's reachability idiom: the
/// affordances must be focusable BEFORE they are visible, or keyboard/AT users can never edit) — each
/// pill gains its ✕ and the ➕ fades in on the rail. Pressing ➕ mounts the autofocused inline add
/// input via [AnTags.showAddField]; Enter chains, Esc / blur dismisses ([AnTags.onAddDismissed] flips
/// [_adding] back off; drafts are cleared by AnTags on every dismissal). Each add/remove emits live
/// through [onChanged]. A null [onChanged] renders display-only pills (+ the rail placeholder when the
/// surrounding list is railed).
/// 标签行体——AnEditableValue 的药丸对偶,同走非 wrap AnLeadValue(值贴右、全员垂直居中)+ 同一揭示手感:
/// 静态干净药丸(空则 —);行 hover 或最右 opacity-0 常驻 ➕ 获键盘焦点(铅笔的可达性手法:触点先可聚焦、后可见,
/// 否则键盘/读屏永远进不了编辑)→ 每丸 ✕ + ➕ 显形;按 ➕ 经 AnTags.showAddField 挂出自聚焦输入框,Enter 连加、
/// Esc/失焦收(onAddDismissed 翻回;草稿由 AnTags 每次弃时清)。增删即时经 onChanged 派出。onChanged 空=纯展示。
class _KvTagsRow extends StatefulWidget {
  const _KvTagsRow({
    required this.leading,
    required this.fieldLabel,
    required this.tags,
    required this.railed,
    this.placeholder,
    this.onChanged,
  });

  final Widget leading;
  final String fieldLabel;
  final List<String> tags;
  final bool railed;
  final String? placeholder;
  final ValueChanged<List<String>>? onChanged;

  @override
  State<_KvTagsRow> createState() => _KvTagsRowState();
}

class _KvTagsRowState extends State<_KvTagsRow> {
  final FocusNode _plusFocus = FocusNode(debugLabel: 'KvTags.plus');
  bool _hovered = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _plusFocus.addListener(_onPlusFocus);
  }

  void _onPlusFocus() {
    if (mounted) setState(() {}); // reveal on keyboard focus, like the pencil 键盘聚焦即揭示,同铅笔
  }

  @override
  void dispose() {
    _plusFocus.removeListener(_onPlusFocus);
    _plusFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final editable = widget.onChanged != null;
    final reduced = AnMotionPref.reduced(context);
    final revealed = editable && (_hovered || _plusFocus.hasFocus || _adding);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : AnMotion.fast,
          constraints: const BoxConstraints(minHeight: AnSize.row),
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
          decoration: BoxDecoration(
            color: c.surfaceHover.whenActive(revealed),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          // Non-wrap AnLeadValue: value flush right, all four slots vertically centered. 非 wrap:值贴右、全员居中。
          child: AnLeadValue(
            leading: widget.leading,
            trailing: _value(c, revealed),
            afterValue: _rail(editable, revealed),
          ),
        ),
      ),
    );
  }

  // The far-right rail slot: the ➕ (always in tree, opacity-revealed — keyboard-reachable before
  // visible) when editable; a rail placeholder in a railed display list; nothing otherwise.
  // 最右轨:可编辑=常驻 opacity ➕(先可达后可见);railed 只读=占位;否则无。
  Widget? _rail(bool editable, bool revealed) {
    if (!editable) return widget.railed ? const SizedBox(width: AnSize.controlSm) : null;
    return Opacity(
      opacity: revealed ? 1 : 0,
      child: AnButton.iconOnly(
        AnIcons.plus,
        size: AnButtonSize.sm,
        semanticLabel: context.t.a11y.addTagTo(field: widget.fieldLabel),
        focusNode: _plusFocus,
        onPressed: () => setState(() => _adding = true),
      ),
    );
  }

  Widget _value(AnColors c, bool revealed) {
    if (widget.tags.isEmpty && !_adding) {
      // Empty at rest → em-dash flush right, exactly like an empty text row. 空静态显 —,与文本行同几何。
      final dash = Text('—', textAlign: TextAlign.right, style: AnText.value().copyWith(color: c.inkFaint));
      return revealed ? dash : Semantics(label: '${widget.fieldLabel}: —', child: ExcludeSemantics(child: dash));
    }
    final pills = AnTags(
      tags: [for (final t in widget.tags) AnTag(t)],
      readOnly: !revealed,
      end: true, // flush-right pill runs inside the flush-right value zone 值区贴右,行尾对齐
      placeholder: widget.placeholder,
      showAddField: _adding,
      onChanged: widget.onChanged == null
          ? null
          : (next) => widget.onChanged!([for (final t in next) t.label]),
      onAddDismissed: () {
        if (mounted) setState(() => _adding = false);
      },
    );
    // At rest, read as ONE merged "label: a, b" description (matching read-only text rows); revealed,
    // the pills/✕/input keep their own nodes. 静态=单 merge 语义;揭示后各触点自有节点。
    return revealed
        ? pills
        : Semantics(
            label: '${widget.fieldLabel}: ${widget.tags.join(', ')}',
            child: ExcludeSemantics(child: pills),
          );
  }
}
