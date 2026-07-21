import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// A read-only **bordered prose table** — the reading-surface markdown table, PIXEL-1:1 with the document
/// editor's table (super_editor's `MarkdownTableComponent`). Distinct from [AnThinTable] (a *chrome-less*
/// aligned-column data display for tool cards / entity properties): this one is a GFM-style grid with a
/// hairline border on every cell, snug cell padding, an emphasis header, and RICH cell content.
///
/// It mirrors the editor tree verbatim so the two surfaces converge by construction: an outer
/// `FittedBox(scaleDown)` shrinks the table when it is wider than the reading column, and a
/// `ConstrainedBox(minWidth)` expands it to fill when narrower; columns hug their content
/// ([IntrinsicColumnWidth]); the border is [AnColors.line] at [AnSize.hairline]; every cell gets the ONE
/// [_cellPadding] (12h / 6v — GFM's canonical 6px, tightened from the old 8; the editor stylesheet uses the
/// identical value). Cells are arbitrary widgets — the caller renders them (chat via `MdWidget`, gallery via
/// plain `Text`) so alignment/rich-inline is the cell's own concern (a tight-width `Table` cell honours a
/// child `Text.rich(textAlign:)` with no wrapping `Align`). Header rows carry `header` semantics.
///
/// ⚠️ Contains a [LayoutBuilder]; like [AnCodeEditor] it must NEVER be placed under `IntrinsicWidth` /
/// `IntrinsicHeight` (LayoutBuilder throws on intrinsic queries — same lesson as the chat stage). In the
/// reading column it sits under normal sliver/box constraints, which never query intrinsics.
///
/// 只读**有框正文表**:阅读面的 markdown 表,与文档编辑器的表逐像素一致。区别于无框的 [AnThinTable](工具卡/实体属性用):
/// GFM 式发丝网格 + 紧凑内距 + 强调表头 + 富单元格。镜像编辑器树(FittedBox 缩 / ConstrainedBox 撑 / IntrinsicColumnWidth
/// 贴内容 / 发丝线框 / 每格 12h·6v)。单元格是任意 widget(chat 用 MdWidget、gallery 用 Text),对齐/富内联归单元格自理
/// (紧宽 Table 格里子 `Text.rich(textAlign:)` 自对齐、无需 Align 包裹)。表头行带 header 语义。
/// ⚠️ 含 LayoutBuilder,同 AnCodeEditor,**绝不可置于 IntrinsicWidth/Height 下**(intrinsic 查询会炸)。
class AnProseTable extends StatelessWidget {
  const AnProseTable({required this.rows, this.headerRowCount = 1, super.key});

  /// Row-major cells. The first [headerRowCount] rows are the header. Every row MUST have the same length
  /// (the markdown parser normalises ragged rows to the column count before this). 行优先单元格,列数须齐。
  final List<List<Widget>> rows;

  /// How many leading rows are header rows (emphasis is baked into the caller's cell widgets; this only
  /// drives `header` semantics). 前导表头行数(仅驱动 header 语义,强调样式由调用方烘进单元格)。
  final int headerRowCount;

  // The single cell padding shared with the editor stylesheet (an_editor_stylesheet.dart TableStyles.cellPadding):
  // 12 horizontal for column separation, 6 vertical (GFM 6px, tightened from 8). 与编辑器同一格内距。
  static const EdgeInsets _cellPadding = EdgeInsets.symmetric(
    horizontal: AnSpace.s12,
    vertical: AnSpace.s6,
  );

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty || rows.first.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit
            .scaleDown, // wider than the reading column → shrink to fit (verbatim with the editor)
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
          ), // narrower → expand to fill
          child: Table(
            border: TableBorder.all(color: c.line, width: AnSize.hairline),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            // defaultVerticalAlignment left unset → Flutter default TableCellVerticalAlignment.top (the editor
            // sets none either), so short cells hug the top when a sibling cell wraps. 默认顶对齐,同编辑器。
            children: [
              for (var r = 0; r < rows.length; r++)
                TableRow(
                  children: [
                    for (final cell in rows[r])
                      Padding(
                        padding: _cellPadding,
                        child: r < headerRowCount
                            ? Semantics(header: true, child: cell)
                            : cell,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
