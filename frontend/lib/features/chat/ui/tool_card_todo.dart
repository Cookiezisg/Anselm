import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/contract/todo.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';

// F11 todo (B7.1) — the task checklist. todo_write carries the FULL list in its args ({content,
// activeForm, status}); todo_read returns the rendered `- [x]/[→]/[ ]` markdown. Both project onto a
// The checklist renders via AnRundownList (批6 A-053 — one three-state face app-wide), the in_progress
// one showing its activeForm. The user sees the board live. F11 任务清单。

/// One checklist item (its display text + status). 一条清单项。
typedef TodoItem = ({String text, String status});

/// Parse a todo checklist from a todo_write args JSON OR a todo_read rendered string. todo_write's args
/// is the structured truth (`{items:[{content, activeForm, status}]}`); todo_read is `- [x]/[→]/[ ]`
/// lines. Returns null when neither parses. 双源解析:write 结构 args / read 渲染行。
List<TodoItem>? parseTodos({String? argsJson, String? rendered}) {
  // Preferred: the structured args (todo_write). 优先结构 args。
  if (argsJson != null) {
    try {
      final d = jsonDecode(argsJson);
      if (d is Map && d['items'] is List) {
        return [
          for (final it in (d['items'] as List).whereType<Map>())
            (
              text: (it['status'] == 'in_progress' && (it['activeForm'] as String?)?.isNotEmpty == true)
                  ? it['activeForm'] as String
                  : (it['content'] as String? ?? ''),
              status: it['status'] as String? ?? 'pending',
            ),
        ];
      }
    } catch (_) {}
  }
  // Fallback: the rendered markdown (todo_read). 回落渲染行。
  if (rendered != null && rendered.contains('- [')) {
    final items = <TodoItem>[];
    for (final line in rendered.split('\n')) {
      final l = line.trimLeft();
      if (l.startsWith('- [x] ')) {
        items.add((text: l.substring(6), status: 'completed'));
      } else if (l.startsWith('- [→] ')) {
        items.add((text: l.substring(6), status: 'in_progress'));
      } else if (l.startsWith('- [ ] ')) {
        items.add((text: l.substring(6), status: 'pending'));
      }
    }
    return items;
  }
  return null;
}

/// The todo receipt — `{total} 项 · {done} 完成`, or «清单已清空» for an empty write. 清单回执。
ToolReceipt? todoReceipt(Translations t, {String? argsJson, String? rendered}) {
  final items = parseTodos(argsJson: argsJson, rendered: rendered);
  if (items == null) return null;
  if (items.isEmpty) return (text: t.chat.tool.todoCleared, tone: ToolReceiptTone.none);
  final done = items.where((i) => i.status == 'completed').length;
  return (text: t.chat.tool.todoRollup(total: '${items.length}', done: '$done'), tone: ToolReceiptTone.none);
}


/// todo_write body — the checklist off the args (the structured truth). todo_write 落定体。
Widget todoWriteBody(BuildContext context, ToolCardState state) {
  final items = parseTodos(argsJson: state.argsText, rendered: state.resultText) ?? const [];
  if (items.isEmpty) {
    return Text(Translations.of(context).chat.tool.todoCleared, style: AnText.meta.copyWith(color: context.colors.inkFaint));
  }
  // ONE three-state checklist face app-wide (批6 A-053: the bubble list and the sidestage rundown
  // wore two faces — 原则 #8 复用优先,TodoChecklist 渲染退役). 全 App 一张三态清单脸。
  return AnRundownList(todos: [for (final it in items) TodoEntry(content: it.text, status: it.status)]);
}

/// todo_read body — the checklist off the rendered result. todo_read 落定体。
Widget todoReadBody(BuildContext context, ToolCardState state) {
  final items = parseTodos(rendered: state.resultText) ?? const [];
  if (items.isEmpty) {
    return Text(Translations.of(context).chat.tool.todoCleared, style: AnText.meta.copyWith(color: context.colors.inkFaint));
  }
  return AnRundownList(todos: [for (final it in items) TodoEntry(content: it.text, status: it.status)]);
}
