import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/syntax.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// A collapsible JSON viewer for node results / tool args / configs. Objects and arrays are
/// expandable (top level open by default); scalars are colored by type via [AnSyntax].
/// 可折叠 JSON 查看器(节点结果/工具入参/配置)。对象与数组可展开(顶层默认开);标量按类型用 [AnSyntax] 着色。
class AnJsonTree extends StatelessWidget {
  const AnJsonTree(this.data, {super.key});

  final Object? data;

  @override
  Widget build(BuildContext context) => _Node(value: data, depth: 0);
}

class _Node extends StatefulWidget {
  const _Node({required this.value, required this.depth, this.keyName});

  final Object? value;
  final int depth;
  final String? keyName;

  @override
  State<_Node> createState() => _NodeState();
}

class _NodeState extends State<_Node> {
  late bool _open = widget.depth < 1;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sx = context.syntax;
    final v = widget.value;
    final indent = EdgeInsets.only(left: widget.depth * AnSpace.s16);

    if (v is! Map && v is! List) {
      final (String text, Color color) = switch (v) {
        String s => ('"$s"', sx.string),
        num n => ('$n', sx.number),
        bool b => ('$b', sx.keyword),
        null => ('null', sx.keyword),
        _ => ('$v', c.ink),
      };
      return Padding(
        padding: indent.add(const EdgeInsets.symmetric(vertical: 1)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.keyName != null)
              Text('${widget.keyName}: ', style: AnText.mono.copyWith(color: c.inkMuted)),
            Flexible(child: Text(text, style: AnText.mono.copyWith(color: color))),
          ],
        ),
      );
    }

    final entries = v is Map
        ? v.entries.map((e) => (e.key.toString(), e.value as Object?)).toList()
        : [for (var i = 0; i < (v as List).length; i++) ('$i', v[i] as Object?)];
    final summary = v is Map ? '{${entries.length}}' : '[${entries.length}]';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: indent.add(const EdgeInsets.symmetric(vertical: 1)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_open ? AnIcons.chevronDown : AnIcons.chevronRight,
                    size: 12, color: c.inkFaint),
                const SizedBox(width: 2),
                if (widget.keyName != null)
                  Text('${widget.keyName}: ', style: AnText.mono.copyWith(color: c.inkMuted)),
                Text(summary, style: AnText.mono.copyWith(color: c.inkFaint)),
              ],
            ),
          ),
        ),
        if (_open)
          for (final (k, val) in entries)
            _Node(value: val, depth: widget.depth + 1, keyName: k),
      ],
    );
  }
}
