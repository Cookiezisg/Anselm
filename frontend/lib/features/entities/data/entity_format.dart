import 'dart:convert';

import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';

/// Pure formatting helpers shared by the detail state + UI (no widgets, no Flutter — lives in data so
/// both layers may import it). 纯格式化助手(无 widget,放 data 供 state+ui 共用)。

/// A handler has no single `code` field — its source is the class shape spread across imports / init /
/// shutdown / each method body. Concatenate it ONCE here so the overview code view and the version diff
/// show identical text. handler 无单一 code 字段,在此唯一拼接,使概览代码与版本 diff 同源。
String handlerSourceOf(HandlerVersion v) {
  final parts = <String>[
    if (v.imports.trim().isNotEmpty) v.imports.trim(),
    if (v.initBody.trim().isNotEmpty) 'def __init__(self):\n${_indent(v.initBody.trim())}',
    if (v.shutdownBody.trim().isNotEmpty) 'def __del__(self):\n${_indent(v.shutdownBody.trim())}',
    for (final m in v.methods)
      'def ${m.name}(self):${m.body.trim().isEmpty ? ' ...' : '\n${_indent(m.body.trim())}'}',
  ];
  return parts.join('\n\n');
}

String _indent(String body) => body.split('\n').map((l) => '    $l').join('\n');

/// Absolute timestamp `YYYY-MM-DD HH:MM` (deterministic — no timezone conversion, so tests are stable);
/// null → em-dash. 绝对时间戳(确定性、不转时区);null → 破折号。
String fmtTime(DateTime? t) {
  if (t == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// The decoded workflow graph for the overview stub. `graphParsed` is null in production (the backend
/// sends only the raw `graph` blob), so fall back to decoding it; an unparseable blob → null (the
/// overview then shows the graph section's error inset). 工作流图:graphParsed 生产为空 → 解析 raw blob。
Graph? graphOf(WorkflowVersion v) {
  if (v.graphParsed != null) return v.graphParsed;
  if (v.graph.trim().isEmpty) return const Graph();
  try {
    return Graph.fromJson(jsonDecode(v.graph) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Pretty-print a JSON-ish value for a detail row; non-encodable → its toString. 美化 JSON(不可编码→toString)。
String prettyJson(Object? value) {
  if (value == null) return '—';
  if (value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}
