import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A dense, hairline-ruled table. Columns carry a label + flex; rows are arbitrary cell
/// widgets. For execution logs, version lists, node tables — anywhere density matters.
/// 密集细线表。列含标签 + flex;行是任意单元 widget。用于执行日志、版本列表、节点表等需要密度处。
class AnColumn {
  const AnColumn(this.label, {this.flex = 1});
  final String label;
  final int flex;
}

class AnThinTable extends StatelessWidget {
  const AnThinTable({super.key, required this.columns, required this.rows});

  final List<AnColumn> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.lineStrong, width: AnSize.hairline)),
          ),
          child: Row(
            children: [
              for (final col in columns)
                Expanded(
                  flex: col.flex,
                  child: Text(col.label, style: AnText.label.copyWith(color: c.inkFaint)),
                ),
            ],
          ),
        ),
        for (final row in rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line, width: AnSize.hairline)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < row.length; i++)
                  Expanded(
                    flex: i < columns.length ? columns[i].flex : 1,
                    child: row[i],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
