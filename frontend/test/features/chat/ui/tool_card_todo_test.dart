import 'dart:convert';

import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/core/ui/an_rundown_list.dart';
import 'package:anselm/features/chat/ui/tool_card_todo.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F11 todo (B7.1) — parse both sources (structured write args / rendered read), the AnRundownList
// board (批6 A-053 — TodoChecklist retired into it), receipt.

BlockNode _todoWrite(List<Map<String, String>> items) => BlockNode(id: 'tc_w', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'todo_write', 'arguments': jsonEncode({'items': items})}
  ..children.add(BlockNode(id: 'tr_w', kind: BlockKind.toolResult)..status = 'completed'..content = {'content': 'ok'});

BlockNode _todoRead(String rendered) => BlockNode(id: 'tc_r', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'todo_read', 'arguments': '{}'}
  ..children.add(BlockNode(id: 'tr_r', kind: BlockKind.toolResult)..status = 'completed'..content = {'content': rendered});

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 660, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('parseTodos', () {
    test('structured args: in_progress shows activeForm, else content', () {
      final items = parseTodos(argsJson: jsonEncode({'items': [
        {'content': 'do A', 'status': 'completed'},
        {'content': 'do B', 'activeForm': 'doing B', 'status': 'in_progress'},
        {'content': 'do C', 'status': 'pending'},
      ]}))!;
      expect(items.length, 3);
      expect(items[0], (text: 'do A', status: 'completed'));
      expect(items[1], (text: 'doing B', status: 'in_progress')); // activeForm for in_progress
      expect(items[2], (text: 'do C', status: 'pending'));
    });
    test('rendered lines: - [x]/[→]/[ ] map to statuses', () {
      final items = parseTodos(rendered: '- [x] done one\n- [→] doing two\n- [ ] todo three')!;
      expect(items.map((i) => i.status).toList(), ['completed', 'in_progress', 'pending']);
      expect(items[0].text, 'done one');
    });
    test('empty items → empty list (a cleared board); non-todo → null', () {
      expect(parseTodos(argsJson: jsonEncode({'items': []}))!.isEmpty, isTrue);
      expect(parseTodos(rendered: 'not a todo list'), isNull);
    });
  });

  test('todoReceipt: N 项 · M 完成; cleared', () {
    final r = todoReceipt(t, argsJson: jsonEncode({'items': [
      {'content': 'a', 'status': 'completed'}, {'content': 'b', 'status': 'pending'},
    ]}))!;
    expect(r.text, contains('2'));
    expect(r.text, contains('1'));
    expect(todoReceipt(t, argsJson: jsonEncode({'items': []}))!.text, t.chat.tool.todoCleared);
  });

  testWidgets('todo_write body: a checklist with a ✓ / ▶ / ☐ row per task', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _todoWrite([
      {'content': 'DONE_TASK', 'status': 'completed'},
      {'content': 'PENDING_LABEL', 'activeForm': 'DOING_TASK', 'status': 'in_progress'},
      {'content': 'TODO_TASK', 'status': 'pending'},
    ]))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.todoWrote), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AnRundownList), findsOneWidget); // 批6 A-053:全 App 一张清单脸
    expect(find.text('DONE_TASK'), findsOneWidget);
    expect(find.text('DOING_TASK'), findsOneWidget); // in_progress → activeForm, not content
    expect(find.text('PENDING_LABEL'), findsNothing);
    expect(find.text('TODO_TASK'), findsOneWidget);
  });

  testWidgets('todo_read body: parses the rendered checklist', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _todoRead('- [x] READ_DONE\n- [ ] READ_TODO'))));
    await tester.pump();
    await tester.tap(find.textContaining(t.chat.tool.todoRead), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('READ_DONE'), findsOneWidget);
    expect(find.text('READ_TODO'), findsOneWidget);
  });
}
