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

BlockNode _node(String name, String args, String result) =>
    BlockNode(id: 'tc_f', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_f', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
      );

Widget _host(Widget c) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 640, child: c)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('parseLsListing', () {
    test('header entry count + dir/file/link rows + truncation', () {
      const out =
          '/ws (5 entries)\n  dir   src\n  file  a.py   1.2 KB   2026-07-05 14:00\n  link  latest\n'
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
    test('every non-listing payload is a failed result', () {
      expect(lsResultFailed('Directory not found: /nope'), isTrue);
      expect(
        lsResultFailed('Not a directory (use Read for a file): /tmp/a.txt'),
        isTrue,
      );
      expect(lsResultFailed('/tmp (0 entries)\n  (empty)'), isFalse);
    });
  });

  group('parseGlobResult', () {
    test('JSON matches + total + truncated', () {
      const out =
          '{"root":"/ws","total":2,"truncated":true,"matches":['
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
    test('every non-JSON payload is a failed result', () {
      expect(globResultFailed('Search root not found: /x'), isTrue);
      expect(
        globResultFailed('Search root must be a directory: /tmp/a.txt'),
        isTrue,
      );
      expect(
        globResultFailed(
          '{"root":"/ws","total":0,"truncated":false,"matches":[]}',
        ),
        isFalse,
      );
    });
  });

  group('Grep semantic parsing', () {
    const args = '{"pattern":"needle","path":"/ws","output_mode":"content"}';

    test('error payloads fail while no-match and text results stay valid', () {
      expect(grepResultFailed('Search root not found: /missing', args), isTrue);
      expect(
        grepResultFailed('path is denied by safety guard: /etc/', args),
        isTrue,
      );
      expect(
        grepResultFailed('No matches for "needle" in /ws.', args),
        isFalse,
      );
      expect(
        grepResultFailed('/ws/a.txt:2:needle\n/ws/a.txt-3-context', args),
        isFalse,
      );
    });
  });

  testWidgets(
    'LS body: a directory ToolHitList (dir names get a trailing slash)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'LS',
              '{"path":"/ws"}',
              '/ws (2 entries)\n  dir   src\n  file  a.py   1 KB   2026-07-05 14:00',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已列出'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(ToolHitList), findsOneWidget);
      expect(find.text('src/'), findsOneWidget); // dir trailing slash
      expect(find.text('a.py'), findsOneWidget);
    },
  );

  testWidgets('LS failure uses a failure verb and shows the error body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'LS',
            '{"path":"/missing"}',
            'Directory not found: /missing',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.listFailed), findsOneWidget);
    expect(find.textContaining(t.chat.tool.listed), findsNothing);
    expect(
      find.textContaining('Directory not found: /missing'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Glob body: a matches ToolHitList (basename + full path subtitle)',
    (tester) async {
      await tester.pumpWidget(
        _host(
          ChatToolCard(
            node: _node(
              'Glob',
              '{"pattern":"**/*.py","path":"/ws"}',
              '{"root":"/ws","total":1,"truncated":false,"matches":[{"path":"/ws/functions/rollup.py","type":"file","size":1234,"mtime":"2026-07-05T14:00:00Z"}]}',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.textContaining('已检索'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(ToolHitList), findsOneWidget);
      expect(find.text('rollup.py'), findsOneWidget); // basename
      expect(
        find.text('/ws/functions/rollup.py'),
        findsOneWidget,
      ); // full path subtitle
    },
  );

  testWidgets('Glob receipt reads the JSON total, not a line count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'Glob',
            '{"pattern":"*"}',
            '{"root":"/ws","total":47,"truncated":true,"matches":[{"path":"/ws/a","type":"file","size":1,"mtime":"2026-07-05T14:00:00Z"}]}',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining(t.chat.tool.items(n: '47+')),
      findsOneWidget,
    ); // truncated → N+
  });

  testWidgets('Glob failure uses a failure verb and shows the error body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'Glob',
            '{"pattern":"**/*.go","path":"/missing"}',
            'Search root not found: /missing',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.globFailed), findsOneWidget);
    expect(find.textContaining(t.chat.tool.globbed), findsNothing);
    expect(
      find.textContaining('Search root not found: /missing'),
      findsOneWidget,
    );
  });

  testWidgets('Grep content receipt counts matches, not context lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'Grep',
            '{"pattern":"needle","path":"/ws","output_mode":"content","-n":true,"-C":1}',
            '/ws/a.txt-1-before\n/ws/a.txt:2:needle one\n/ws/a.txt-3-after\n/ws/a.txt:5:needle two',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.matches(n: '2')), findsOneWidget);
    expect(find.textContaining(t.chat.tool.matches(n: '4')), findsNothing);
  });

  testWidgets('Grep files mode receipt counts files', (tester) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'Grep',
            '{"pattern":"needle","path":"/ws"}',
            '/ws/a.txt\n/ws/b.txt\n',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.files(n: '2')), findsOneWidget);
    expect(find.textContaining(t.chat.tool.matches(n: '2')), findsNothing);
  });

  testWidgets('Grep failure uses a failure verb and shows the error body', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'Grep',
            '{"pattern":"needle","path":"/missing"}',
            'Search root not found: /missing',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(t.chat.tool.grepFailed), findsOneWidget);
    expect(find.textContaining(t.chat.tool.grepped), findsNothing);
    expect(
      find.textContaining('Search root not found: /missing'),
      findsOneWidget,
    );
  });
}
