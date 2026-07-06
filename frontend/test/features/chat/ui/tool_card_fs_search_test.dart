import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_fs_search.dart';
import 'package:anselm/features/chat/ui/tool_hit_list.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F02 fs-search LS + Glob (B4) — line-template / JSON parsers + directory-like ToolHitList bodies.
// F02 LS/Glob 解析器 + 目录感命中窗。

BlockNode _node(String name, String args, String result) => BlockNode(id: 'tc_f', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': name, 'arguments': args}
  ..children.add(BlockNode(id: 'tr_f', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: c)))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('parseLsListing', () {
    test('header entry count + dir/file/link rows + truncation', () {
      const out = '/ws (5 entries)\n  dir   src\n  file  a.py   1.2 KB   2026-07-05 14:00\n  link  latest\n'
          '  ... showing 3 of 5 entries; raise limit to see more';
      final ls = parseLsListing(out)!;
      expect(ls.root, '/ws');
      expect(ls.total, 5);
      expect(ls.truncated, isTrue);
      expect(ls.entries.length, 3);
      expect(ls.entries[0].type, 'dir');
      expect(ls.entries[1].size, '1.2 KB');
      expect(ls.entries[2].type, 'link');
    });
    test('an error string is not a listing → null', () {
      expect(parseLsListing('Directory not found: /nope'), isNull);
    });
  });

  group('parseGlobResult', () {
    test('JSON matches + total + truncated', () {
      const out = '{"root":"/ws","total":2,"truncated":true,"matches":['
          '{"path":"/ws/a.py","type":"file","size":100,"mtime":"2026-07-05T14:00:00Z"}]}';
      final g = parseGlobResult(out)!;
      expect(g.root, '/ws');
      expect(g.total, 2);
      expect(g.truncated, isTrue);
      expect(g.matches.first.size, 100);
    });
    test('a non-JSON (error/timeout) string → null', () {
      expect(parseGlobResult('Search root not found: /x'), isNull);
      expect(parseGlobResult('Glob search exceeded the time budget…'), isNull);
    });
  });

  testWidgets('LS body: a directory ToolHitList (dir names get a trailing slash)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('LS', '{"path":"/ws"}',
        '/ws (2 entries)\n  dir   src\n  file  a.py   1 KB   2026-07-05 14:00'))));
    await tester.pump();
    await tester.tap(find.textContaining('已列出'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolHitList), findsOneWidget);
    expect(find.text('src/'), findsOneWidget); // dir trailing slash
    expect(find.text('a.py'), findsOneWidget);
  });

  testWidgets('Glob body: a matches ToolHitList (basename + full path subtitle)', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('Glob', '{"pattern":"**/*.py","path":"/ws"}',
        '{"root":"/ws","total":1,"truncated":false,"matches":[{"path":"/ws/functions/rollup.py","type":"file","size":1234,"mtime":"2026-07-05T14:00:00Z"}]}'))));
    await tester.pump();
    await tester.tap(find.textContaining('已检索'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolHitList), findsOneWidget);
    expect(find.text('rollup.py'), findsOneWidget); // basename
    expect(find.text('/ws/functions/rollup.py'), findsOneWidget); // full path subtitle
  });

  testWidgets('Glob receipt reads the JSON total, not a line count', (tester) async {
    await tester.pumpWidget(_host(ChatToolCard(node: _node('Glob', '{"pattern":"*"}',
        '{"root":"/ws","total":47,"truncated":true,"matches":[{"path":"/ws/a","type":"file","size":1,"mtime":"2026-07-05T14:00:00Z"}]}'))));
    await tester.pump();
    expect(find.textContaining(t.chat.tool.items(n: '47+')), findsOneWidget); // truncated → N+
  });
}
