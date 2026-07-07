import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/tool_card_state.dart';
import '../model/tool_receipts.dart';

// F11 todo (B7.1) — the task checklist. todo_write carries the FULL list in its args ({content,
// activeForm, status}); todo_read returns the rendered `- [x]/[→]/[ ]` markdown. Both project onto a
// TodoChecklist: a checkbox row per task (✓ completed / ▶ in_progress / ☐ pending), the in_progress
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

/// TodoChecklist — a checkbox row per task. ✓ completed (dim + strikethrough) / ▶ in_progress (accent) /
/// ☐ pending. TodoChecklist:每任务一勾选行。
class TodoChecklist extends StatelessWidget {
  const TodoChecklist({required this.items, super.key});
  final List<TodoItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      for (final it in items) _row(c, it),
    ]);
  }

  Widget _row(AnColors c, TodoItem it) {
    final (icon, iconColor, textColor, strike) = switch (it.status) {
      'completed' => (AnIcons.check, c.ok, c.inkFaint, true),
      'in_progress' => (AnIcons.chevronRight, c.accent, c.ink, false),
      _ => (AnIcons.circle, c.inkFaint, c.inkMuted, false),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: AnSpace.s2), child: Icon(icon, size: AnSize.iconSm, color: iconColor)),
        const SizedBox(width: AnSpace.s8),
        Expanded(
          child: Text(it.text,
              style: AnText.body.copyWith(
                color: textColor,
                decoration: strike ? TextDecoration.lineThrough : null,
                decorationColor: c.inkFaint,
              )),
        ),
      ]),
    );
  }
}

/// todo_write body — the checklist off the args (the structured truth). todo_write 落定体。
Widget todoWriteBody(BuildContext context, ToolCardState state) {
  final items = parseTodos(argsJson: state.argsText, rendered: state.resultText) ?? const [];
  if (items.isEmpty) {
    return Text(Translations.of(context).chat.tool.todoCleared, style: AnText.meta.copyWith(color: context.colors.inkFaint));
  }
  return TodoChecklist(items: items);
}

/// todo_read body — the checklist off the rendered result. todo_read 落定体。
Widget todoReadBody(BuildContext context, ToolCardState state) {
  final items = parseTodos(rendered: state.resultText) ?? const [];
  if (items.isEmpty) {
    return Text(Translations.of(context).chat.tool.todoCleared, style: AnText.meta.copyWith(color: context.colors.inkFaint));
  }
  return TodoChecklist(items: items);
}
