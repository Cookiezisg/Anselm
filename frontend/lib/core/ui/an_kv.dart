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

// The KEY-VALUE family (WRK-066 批6 A-067: physically split out of an_field.dart — AnKv was buried
// beside AnField and unfindable; API verbatim, zero behaviour change). AnField (label-left · control-
// right row) stays in an_field.dart. 键值族(批6 A-067:从 an_field.dart 物理拆出,埋件难寻即解;
// API 逐字零变)。AnField(标签左·控件右行)留原文件。

/// One row of an [AnKv] definition list — a TEXT row (default ctor) or a TAGS row ([AnKvRow.tags]).
/// [editable] (with the list's `onChanged`) makes a text value editable in place via
/// [AnEditableValue]; [editor] picks free-text vs an enum dropdown. [wrap] lets a long READ-ONLY
/// value fill + wrap left-aligned (label top-pinned) — it is per-row and excluded from editable rows
/// (editable values are flush-right single-line by decree). [meta] marks the value as METADATA
/// (timestamps, counts, refCounts): it renders on the chrome 13 value tier even inside a content
/// list (the locked two-tier — metadata never rides the 15 rung). The text field is named `label`
/// (not `key`) to avoid clashing with [Widget.key].
/// AnKv 行:文本行 / 标签行两种。editable=就地编辑;wrap 仅限只读文本行(长值左对齐换行);可编辑值恒贴右单行。
/// meta=元数据值(时间戳/计数):即便在内容列表里也渲 13 值档(两级钦定——元数据不上 15)。
class AnKvRow {
  const AnKvRow(
    this.label,
    this.value, {
    this.editable = false,
    this.editor = AnEditKind.input,
    this.options = const [],
    this.wrap = false,
    this.meta = false,
    this.mono = false,
  }) : tags = null,
       flag = null,
       tagsPlaceholder = null,
       assert(
         !(editable && wrap),
         'wrap is for read-only display rows — editable values are flush-right. wrap 仅限只读行',
       );

  /// A TAGS row: the value is a SET of tags. At rest = plain pills flush right; on row hover/focus a
  /// ✕ per pill and a far-right ➕ reveal (the same rail + idiom as the text rows' pencil); pressing ➕
  /// mounts an autofocused inline input (Enter chains, Esc/blur dismisses). Emitted through the list
  /// [AnKv.onChanged] like any other row (the emitted row carries the new [tags]).
  /// 标签行:静态干净药丸贴右;hover/聚焦揭示每丸 ✕ + 最右 ➕(与铅笔同轨同手感);按 ➕ 才挂出自聚焦输入框
  /// (Enter 连加、Esc/失焦收);经列表 onChanged 派出(行携新 tags)。
  const AnKvRow.tags(this.label, List<String> this.tags, {this.tagsPlaceholder})
    : value = null,
      flag = null,
      editable = false,
      editor = AnEditKind.input,
      options = const [],
      wrap = false,
      meta = false,
      mono = false;

  /// A BOOLEAN row — the family's ONE bool rendering (批6 A-051: '✓'/'—' was hand-copied per site):
  /// display-only ✓ / — glyph, a11y speaks the localized yes/no (a glyph-only semantic would read
  /// «check mark»). 布尔行——族内唯一 bool 渲法(✓/—);a11y 念本地化 是/否(裸字形读屏念「对勾」)。
  const AnKvRow.flag(this.label, bool this.flag)
    : value = null,
      tags = null,
      tagsPlaceholder = null,
      editable = false,
      editor = AnEditKind.input,
      options = const [],
      wrap = false,
      meta = true,
      mono = false;

  final String label;
  final String? value;

  /// Boolean row value (the .flag face). 布尔行值。
  final bool? flag;

  final bool editable;
  final AnEditKind editor;

  /// Options for [AnEditKind.select]. 枚举选项。
  final List<AnDropdownOption<String>> options;

  /// Long read-only value fills + wraps left-aligned. 只读长值换行。
  final bool wrap;

  /// Metadata value (timestamp / count) — chrome 13 value tier even in a content list. 元数据值(恒 13 档)。
  final bool meta;

  /// ROW-LEVEL monospace (WRK-056 #9) — this one value is mono (an id / CEL / signature / `modelId @
  /// apiKeyId` / path) even in a prose-valued list, so an [EntityGetBody] can mix a wrapping
  /// description with a mono id in ONE list. OR-ed with the list-level [AnKv.mono]. 行级 mono:单值等宽
  /// (id/CEL/签名/path),与散文值混排一列;与列表级 mono 取或。
  final bool mono;

  /// Non-null → this is a tags row (see [AnKvRow.tags]). 非空=标签行。
  final List<String>? tags;
  final String? tagsPlaceholder;

  AnKvRow _withValue(String v) => AnKvRow(
    label,
    v,
    editable: editable,
    editor: editor,
    options: options,
    wrap: wrap,
    meta: meta,
    mono: mono,
  );
  AnKvRow _withTags(List<String> t) =>
      AnKvRow.tags(label, t, tagsPlaceholder: tagsPlaceholder);
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
/// **Value tier (the two-tier default)**: keys stay on the 13 label tier; VALUES default to the
/// CONTENT tier [AnText.valueReading] (15/1.4 + tabular; mono 13) — every current consumer is a
/// content surface (entity overviews, document properties). [dense] opts a list back to the chrome
/// tier ([AnText.value], 13/12) for operational panels (the run cockpit); [AnKvRow.meta] keeps a
/// single metadata row (timestamp / count) on the chrome tier inside a content list. The 32px row
/// holds the 15/1.4 value line (21 + 2×4 = 29) and the edit-frame bleed still fits.
///
/// **Two-end alignment**: at rest every value sits flush-right (NO reserved rail — the pencil/➕
/// collapse to zero width and only take room on hover/focus); the actively-edited row's Cancel/Save
/// pair transiently pushes that row's value left — the approved far-right-affordance behaviour.
///
/// C3——紧凑定义列表:key 左 · value **贴右**,每行 row 高,靠字色 + 留白分层。可编辑文本行经 AnEditableValue
/// (最右 hover 铅笔→框/下拉),标签行经 ➕/✕ 药丸;只读行单一 merge 语义节点。改一行→重建整列经 onChanged 派出。
/// **值档(两级默认)**:键守 13 标签档;值默认**内容档 valueReading**(15/1.4+tabular;mono 13)——现有消费者
/// 全是内容面;dense=退回 chrome 档(驾驶舱等操作面板);AnKvRow.meta=单行元数据(时间戳/计数)在内容列表内
/// 仍守 13。32 行放得下 15/1.4 值行(21+8=29),编辑框 bleed 依然成立。
/// **两端对齐**:静态值贴右、不留轨(铅笔/➕ 收 0 宽、悬停才占位);编辑中行的 取消/保存 短暂把该行值缘挤左——
/// 钦定的「触点贴值最右」行为。
class AnKv extends StatelessWidget {
  const AnKv({
    required this.rows,
    this.onChanged,
    this.mono = false,
    this.dense = false,
    super.key,
  });

  final List<AnKvRow> rows;

  /// null → all rows read-only (AnKv is also the canonical key/value DISPLAY). 空=纯展示。
  final ValueChanged<List<AnKvRow>>? onChanged;
  final bool mono;

  /// Chrome-tier list (values 13/12) — dense operational panels; default is the content tier (15).
  /// chrome 档列表(值 13/12)——密集操作面板;默认内容档(15)。
  final bool dense;

  void _emitRow(int i, AnKvRow next) => onChanged!([...rows]..[i] = next);

  /// The row's value-tier style: chrome for [dense] lists and [AnKvRow.meta] rows, content otherwise.
  /// Monospace is the list-level [mono] OR the row-level [AnKvRow.mono] (per-row ids/CEL in a prose
  /// list). 行值档:dense/meta 走 chrome、余内容档;等宽=列表级 mono 或行级 row.mono。
  TextStyle _valueStyle(AnKvRow row) {
    final m = mono || row.mono;
    return (dense || row.meta)
        ? AnText.value(mono: m)
        : AnText.valueReading(mono: m);
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

    if (row.flag != null) {
      // The ONE bool rendering: ✓/— glyph, a11y speaks localized yes/no (批6 A-051). The row wears
      // the family inset (h:s8 v:s4) like its siblings — a bare row would misalign both edges by
      // 8px in mixed lists (批6 复审). 唯一布尔渲法;行内距随族(混排两缘不错位)。
      final t = Translations.of(context);
      return Semantics(
        label: '${row.label}: ${row.flag! ? t.a11y.flagYes : t.a11y.flagNo}',
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: AnSize.row),
            padding: const EdgeInsets.symmetric(
              horizontal: AnSpace.s8,
              vertical: AnSpace.s4,
            ),
            child: AnLeadValue(
              leading: keyText,
              trailing: Text(
                row.flag! ? '✓' : '—',
                style: _valueStyle(
                  row,
                ).copyWith(color: row.flag! ? c.ok : c.inkFaint),
              ),
            ),
          ),
        ),
      );
    }

    if (row.tags != null) {
      return _KvTagsRow(
        leading: keyText,
        fieldLabel: row.label,
        tags: row.tags!,
        placeholder: row.tagsPlaceholder,
        reading: !dense,
        onChanged: onChanged == null
            ? null
            : (t) => _emitRow(i, row._withTags(t)),
      );
    }

    if (row.editable && onChanged != null) {
      return AnEditableValue(
        leading: keyText,
        fieldLabel: row.label,
        value: row.value ?? '',
        rowHeight: AnSize.row,
        valueColor: c.inkFaint,
        valueStyle: _valueStyle(row),
        editor: row.editor,
        options: row.options,
        mono: mono,
        onChanged: (v) => _emitRow(i, row._withValue(v)),
      );
    }

    // Read-only row: one merged "label: value" node — no pencil, key→value connected for SR. 只读行单节点。
    final shown = (row.value == null || row.value!.isEmpty) ? '—' : row.value!;
    // Value column → the shared tiered value style ("值列 tabular 铁律"); mono only switches family. 值列样式单源。
    final valueStyle = _valueStyle(row).copyWith(color: c.inkFaint);
    return Semantics(
      label: '${row.label}: $shown',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: AnSize.row),
          padding: const EdgeInsets.symmetric(
            horizontal: AnSpace.s8,
            vertical: AnSpace.s4,
          ),
          // key hugs content (capped), value fills the remainder + sits flush-RIGHT (AnLeadValue). No
          // reserved rail — read-only values rest flush-right like every row; the editable rows' pencil
          // only reserves width on hover, so at rest the whole list is two-end aligned. 键贴内容、值吃余量
          // 贴右;不留轨——只读值与他行同样静态贴右,编辑行铅笔仅悬停才占宽,故静态全列两端对齐。
          child: AnLeadValue(
            leading: keyText,
            wrap: row.wrap,
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

/// The tags-row body for [AnKv] (an [AnKvRow.tags]) — the pill sibling of [AnEditableValue], riding
/// the same non-wrap [AnLeadValue] geometry (flush-right value, everything vertically centered) and
/// the same reveal idiom: at rest, plain pills (or an em-dash when empty); on row hover — or when the
/// always-in-tree, opacity-0 far-right ➕ takes keyboard focus (the pencil's reachability idiom: the
/// affordances must be focusable BEFORE they are visible, or keyboard/AT users can never edit) — each
/// pill gains its ✕ and the ➕ fades in on the rail. Pressing ➕ mounts the autofocused inline add
/// input via [AnTags.showAddField]; Enter chains, Esc / blur dismisses ([AnTags.onAddDismissed] flips
/// [_adding] back off; drafts are cleared by AnTags on every dismissal). Each add/remove emits live
/// through [onChanged]. A null [onChanged] renders display-only pills, flush-right like every
/// read-only value (no reserved rail — the 两端对齐 mechanic).
/// 标签行体——AnEditableValue 的药丸对偶,同走非 wrap AnLeadValue(值贴右、全员垂直居中)+ 同一揭示手感:
/// 静态干净药丸(空则 —);行 hover 或最右 opacity-0 常驻 ➕ 获键盘焦点(铅笔的可达性手法:触点先可聚焦、后可见,
/// 否则键盘/读屏永远进不了编辑)→ 每丸 ✕ + ➕ 显形;按 ➕ 经 AnTags.showAddField 挂出自聚焦输入框,Enter 连加、
/// Esc/失焦收(onAddDismissed 翻回;草稿由 AnTags 每次弃时清)。增删即时经 onChanged 派出。onChanged 空=纯展示。
class _KvTagsRow extends StatefulWidget {
  const _KvTagsRow({
    required this.leading,
    required this.fieldLabel,
    required this.tags,
    required this.reading,
    this.placeholder,
    this.onChanged,
  });

  final Widget leading;
  final String fieldLabel;
  final List<String> tags;

  /// Content-tier pills (see [AnTags.reading]) — follows the host list's tier. 内容档药丸(随宿主列表档)。
  final bool reading;
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
    if (mounted) {
      setState(() {}); // reveal on keyboard focus, like the pencil 键盘聚焦即揭示,同铅笔
    }
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
          padding: const EdgeInsets.symmetric(
            horizontal: AnSpace.s8,
            vertical: AnSpace.s4,
          ),
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

  // The far-right rail slot: the ➕ when editable (always in tree, keyboard-reachable before
  // visible); nothing otherwise. COLLAPSES to zero width at rest exactly like the pencil
  // (ClipRect + Align widthFactor) — a bare Opacity keeps its 24px layout width and shoved the
  // tags value zone 30px left of the sibling text rows' flush-right edge, breaking the 两端对齐
  // invariant this file decrees.
  // 最右轨:可编辑=常驻 ➕(先可达后可见),静态**收成 0 宽**(同铅笔的 ClipRect+widthFactor)——裸
  // Opacity 保留 24px 布局宽,曾把标签值区推离右缘 30px、破本文件钦定的两端对齐;只读=无。
  Widget? _rail(bool editable, bool revealed) {
    if (!editable) return null;
    return ClipRect(
      child: Align(
        alignment: Alignment.centerRight,
        widthFactor: revealed ? 1.0 : 0.0,
        child: Opacity(
          opacity: revealed ? 1 : 0,
          child: AnButton.iconOnly(
            AnIcons.plus,
            size: AnButtonSize.sm,
            semanticLabel: context.t.a11y.addTagTo(field: widget.fieldLabel),
            focusNode: _plusFocus,
            onPressed: () => setState(() => _adding = true),
          ),
        ),
      ),
    );
  }

  Widget _value(AnColors c, bool revealed) {
    if (widget.tags.isEmpty && !_adding) {
      // Empty at rest → em-dash flush right, exactly like an empty text row. 空静态显 —,与文本行同几何。
      final dash = Text(
        '—',
        textAlign: TextAlign.right,
        style: (widget.reading ? AnText.valueReading() : AnText.value())
            .copyWith(color: c.inkFaint),
      );
      return revealed
          ? dash
          : Semantics(
              label: '${widget.fieldLabel}: —',
              child: ExcludeSemantics(child: dash),
            );
    }
    final pills = AnTags(
      tags: [for (final t in widget.tags) AnTag(t)],
      reading: widget.reading,
      readOnly: !revealed,
      end:
          true, // flush-right pill runs inside the flush-right value zone 值区贴右,行尾对齐
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
