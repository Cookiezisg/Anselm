import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Per-column horizontal alignment. 列对齐。
enum AnTableAlign { left, right, center }

/// A column of an [AnThinTable]: a data [key], an optional header [label] (defaults to the key), and an
/// [align]. AnThinTable 的列:数据 key + 可选表头 label(缺省=key)+ 对齐。
class AnTableColumn {
  const AnTableColumn(this.key, {this.label, this.align = AnTableAlign.left});
  final String key;
  final String? label;
  final AnTableAlign align;
}

/// C4 — aligned multi-column display, NOT a table (no chrome: no heavy header rule, no row dividers, no
/// zebra) — layered by ink + whitespace like AnKv. Built on Flutter's built-in [Table] (its [RenderTable]
/// IS the CSS-subgrid equivalent: one shared set of column tracks, measured once, every row aligned;
/// Flutter has no subgrid — see WRK-038 附录 T1). Columns: the first takes the slack ([FlexColumnWidth]),
/// the rest hug content but cap + ellipsis ([MinColumnWidth] of intrinsic & a fixed max — bare intrinsic
/// has no upper bound and a long value would blow the table out). Header = faint meta column names,
/// bottom-aligned, no line. First data column is primary ink; the rest are muted + tabular figures.
///
/// [selectable] makes each row hover-tint + single-select (full-row highlight via [TableRow.decoration],
/// the subgrid-row equivalent; the hit area is a per-cell transparent layer because a [TableRow] isn't a
/// widget and can't hold a gesture — flutter#42609; NOT [TableRowInkWell], which is Material). For very
/// large / independently-scrolling data, prefer the official `two_dimensional_scrollables` TableView.
///
/// a11y: [Table]/[RenderTable] emits native table semantics (row/column/cell navigation); header cells
/// are marked `header`. A selectable row's first cell carries a button + a "col: val, …" row summary, so
/// a screen reader gets one actionable announcement per row without N repetitions.
///
/// C4 对齐多列展示(非表格、无 chrome):靠字色+留白分层(同 AnKv)。搭 Flutter 内置 Table(RenderTable 即 CSS subgrid
/// 等价:一组共享列轨、测一次、跨行对齐;Flutter 无 subgrid,见 WRK-038 附录 T1)。首列吃富余(FlexColumnWidth),其余
/// 贴内容但封顶省略(MinColumnWidth(intrinsic, fixed)——裸 intrinsic 无上限会撑破)。表头=灰 meta 列名、底对齐、无线;
/// 首列主值 ink、其余次级 inkMuted + tabular。selectable→行 hover 提墨 + 单选(TableRow.decoration 整行高亮;命中是每格
/// 透明层,因 TableRow 非 widget 不能挂手势 flutter#42609;非 Material 的 TableRowInkWell)。海量/独立滚动数据用官方
/// two_dimensional_scrollables TableView。a11y:Table 自带表格语义 + 表头 header;selectable 行首格携 button + 行摘要。
class AnThinTable extends StatefulWidget {
  const AnThinTable({
    required this.columns,
    required this.rows,
    this.selectable = false,
    this.onRowTap,
    super.key,
  });

  final List<AnTableColumn> columns;
  final List<Map<String, String>> rows;
  final bool selectable;
  final ValueChanged<Map<String, String>>? onRowTap;

  @override
  State<AnThinTable> createState() => _AnThinTableState();
}

class _AnThinTableState extends State<AnThinTable> {
  int? _hovered;
  int? _selected;

  bool get _interactive => widget.selectable && widget.onRowTap != null;

  @override
  void didUpdateWidget(AnThinTable old) {
    super.didUpdateWidget(old);
    // rows changed identity → a stale _selected/_hovered would point at the wrong (or gone) row. Clear.
    // rows 身份变 → 陈旧索引会高亮错位/越界行,清掉。
    if (widget.rows != old.rows) {
      _selected = null;
      _hovered = null;
    }
  }

  void _select(int r, Map<String, String> row) {
    setState(() => _selected = r);
    widget.onRowTap!(row);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (widget.columns.isEmpty) return const SizedBox.shrink();

    final cols = widget.columns;
    // Column tracks. First = FlexColumnWidth(1) (takes the slack = CSS minmax(0,1fr)). Non-first =
    // MIN(intrinsic, a fraction of the table) — hug short content, but cap+shrink long content with the
    // table so it can't blow out the right edge. A bare IntrinsicColumnWidth / Fixed cap does NOT shrink
    // below its preferred width (RenderTable only shrinks flex tracks), so a narrow table + a long
    // non-first value overflows silently (RenderTable never throws). FractionColumnWidth scales with the
    // table → always fits; cap = 0.9/(N-1) so the non-first cols sum ≤ 0.9·W, leaving ≥0.1·W for col 0.
    // 列轨:首列吃富余;非首列=min(内容, 表宽分数)——短内容贴合、长内容随表缩(裸 intrinsic/fixed 不缩→窄表撑破且不报错);
    // 分数随表宽伸缩、恒不溢出,cap=0.9/(N-1) 留 ≥0.1·W 给首列。
    final cap = cols.length > 1 ? 0.9 / (cols.length - 1) : 1.0;
    final columnWidths = <int, TableColumnWidth>{
      for (var i = 0; i < cols.length; i++)
        i: i == 0
            ? const FlexColumnWidth(1)
            : MinColumnWidth(const IntrinsicColumnWidth(), FractionColumnWidth(cap)),
    };

    final table = Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(c, cols),
        for (var r = 0; r < widget.rows.length; r++) _dataRow(c, cols, r, widget.rows[r]),
      ],
    );

    // One MouseRegion around the table clears hover on exit; per-cell onEnter sets the hovered row
    // (no per-cell onExit → no flicker moving between cells of a row). 表级 onExit 清,格级 onEnter 设,不闪。
    if (_interactive) {
      return MouseRegion(onExit: (_) => setState(() => _hovered = null), child: table);
    }
    return table;
  }

  TableRow _headerRow(AnColors c, List<AnTableColumn> cols) {
    return TableRow(
      children: [
        for (var i = 0; i < cols.length; i++)
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.bottom, // header sits on the baseline 底对齐
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AnSize.controlSm),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: i == 0 ? AnSpace.s8 : 0,
                  end: i == cols.length - 1 ? AnSpace.s8 : AnSpace.s16, // column gap (--sp-4) / row edge 列间/行缘
                  bottom: AnSpace.s4,
                ),
                child: Align(
                  alignment: _cellAlign(cols[i].align),
                  child: Semantics(
                    header: true,
                    child: Text(
                      cols[i].label ?? cols[i].key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: _textAlign(cols[i].align),
                      style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  TableRow _dataRow(AnColors c, List<AnTableColumn> cols, int r, Map<String, String> row) {
    final bg = r == _selected
        ? c.surfaceActive
        : (_interactive && r == _hovered ? c.surfaceHover : null);
    return TableRow(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AnRadius.button)),
      children: [
        for (var i = 0; i < cols.length; i++) _cell(c, cols, i, r, row),
      ],
    );
  }

  Widget _cell(AnColors c, List<AnTableColumn> cols, int i, int r, Map<String, String> row) {
    final col = cols[i];
    final value = row[col.key] ?? '';
    // First column = primary ink. Non-first = muted + tabular, but lifts to ink when the row is
    // hovered/selected (demo `.tr.row:hover .td / .on .td { color: ink }` — full-row 提墨). 整行提墨。
    final active = r == _selected || (_interactive && r == _hovered);
    final style = i == 0
        ? AnText.body.copyWith(color: c.ink)
        : AnText.body.copyWith(color: active ? c.ink : c.inkMuted, fontFeatures: const [FontFeature.tabularFigures()]);

    final content = Container(
      constraints: const BoxConstraints(minHeight: AnSize.row),
      alignment: _cellAlign(col.align),
      padding: EdgeInsetsDirectional.only(
        start: i == 0 ? AnSpace.s8 : 0,
        end: i == cols.length - 1 ? AnSpace.s8 : AnSpace.s16,
      ),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: _textAlign(col.align), style: style),
    );

    if (!_interactive) return content; // non-selectable → native Table cell semantics 原生格语义

    // Selectable: every cell is a pointer hit layer (a TableRow can't hold a gesture — flutter#42609),
    // but only the FIRST cell is a semantics node — a single button carrying the row summary + onTap, so
    // a screen reader gets ONE actionable node per row (others ExcludeSemantics, not N tap targets).
    // 各格都是指针命中层;仅首格为语义节点(单 button + 行摘要 + onTap),其余 ExcludeSemantics,不出 N 个 tap 目标。
    final hit = MouseRegion(
      onEnter: (_) => setState(() => _hovered = r),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _select(r, row), child: content),
    );
    if (i == 0) {
      return Semantics(
        button: true,
        selected: r == _selected,
        label: cols.map((col) => '${col.label ?? col.key}: ${row[col.key] ?? ''}').join(', '),
        onTap: () => _select(r, row),
        child: ExcludeSemantics(child: hit),
      );
    }
    return ExcludeSemantics(child: hit);
  }

  Alignment _cellAlign(AnTableAlign a) => switch (a) {
        AnTableAlign.right => Alignment.centerRight,
        AnTableAlign.center => Alignment.center,
        AnTableAlign.left => Alignment.centerLeft,
      };

  TextAlign _textAlign(AnTableAlign a) => switch (a) {
        AnTableAlign.right => TextAlign.right,
        AnTableAlign.center => TextAlign.center,
        AnTableAlign.left => TextAlign.left,
      };
}
