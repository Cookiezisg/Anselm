import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_sunken_panel.dart';
import 'package:anselm/core/ui/an_window.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/ui/tool_card_memory_web.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// H2 contract batteries: the memory template parser + three-branch receipts, the web outcome
// classifiers (soft-fail HONESTY — status=completed failure sentences must classify red), and the
// schema digest. Template anchors are the backend's hardcoded strings — a backend template change
// must change these tests in the same commit (contract-sync discipline).
// H2 契约电池:记忆模板解析+三分支回执、web 结局分类器(soft-fail 诚实)、schema 摘要。模板锚是后端
// 硬编码串——后端改模板须同提交改此测试(契约同步纪律)。

ToolCardState _settled({String args = '{}', String result = '', String progress = ''}) =>
    ToolCardState(
      phase: ToolCardPhase.succeeded,
      toolName: 'x',
      summary: '',
      danger: 'safe',
      argsText: args,
      resultText: result,
      errorText: '',
      progressText: progress,
      progressLive: false,
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('parseMemoryTemplate 记忆模板反解', () {
    test('full note: name + source + description + body', () {
      final n = parseMemoryTemplate(
          '### retry-policy (source: ai)\n统一重试口径\n---\n指数退避,最多 3 次。\n超限抛 SyncError。');
      expect(n, isNotNull);
      expect(n!.name, 'retry-policy');
      expect(n.source, 'ai');
      expect(n.description, '统一重试口径');
      expect(n.body, '指数退避,最多 3 次。\n超限抛 SyncError。');
    });

    test('description absent + template mismatch → null (honest degradation)', () {
      final n = parseMemoryTemplate('### note (source: user)\n---\nbody');
      expect(n!.description, isEmpty);
      expect(n.source, 'user');
      expect(parseMemoryTemplate('Memory "x" not found.'), isNull);
      expect(parseMemoryTemplate('random prose'), isNull);
    });
  });

  group('memory receipts 三分支正向门控', () {
    test('write: Saved → N 行 off ARGS; Cannot save → danger; drift → none', () {
      final saved = memoryWriteReceipt(t,
          _settled(args: '{"name":"a","content":"一\\n二\\n三"}', result: 'Saved memory "a" (3 lines).'));
      expect(saved!.text, t.chat.tool.lines(n: '3'));

      final rejected =
          memoryWriteReceipt(t, _settled(result: 'Cannot save memory: name is invalid.'));
      expect(rejected!.text, t.chat.tool.memNotSaved);

      expect(memoryWriteReceipt(t, _settled(result: 'Totally new template')), isNull,
          reason: 'template drift → NO receipt (never a guessed success) 漂移无回执');
    });

    test('read: template hit → N 行; not found → grey miss', () {
      final hit = memoryReadReceipt(
          t, _settled(result: '### a (source: user)\n---\nl1\nl2'));
      expect(hit!.text, t.chat.tool.lines(n: '2'));
      final miss = memoryReadReceipt(t, _settled(result: 'Memory "a" not found.'));
      expect(miss!.text, t.chat.tool.memNotFound);
    });
  });

  group('web outcome classifiers 结局分类器', () {
    test('WebSearch: five degraded anchors + hits/empty', () {
      expect(webSearchOutcome('No search backend configured. …'), WebSearchOutcome.noBackend);
      expect(webSearchOutcome('The configured default search key is provider "x" …'),
          WebSearchOutcome.misconfig);
      expect(webSearchOutcome('Search provider "x" has no base URL configured.'),
          WebSearchOutcome.misconfig);
      expect(webSearchOutcome('Search via brave failed: 429'), WebSearchOutcome.providerFail);
      expect(webSearchOutcome('{"results":[]}'), WebSearchOutcome.empty);
      expect(
          webSearchOutcome(
              '{"source":"brave","results":[{"title":"T","url":"https://a.b/c","snippet":"s"}]}'),
          WebSearchOutcome.hits);
      expect(webSearchOutcome('not json at all'), WebSearchOutcome.unparsed);
    });

    test('WebFetch: failure/empty/raw/js-shell anchors classify red facts off a green status', () {
      expect(webFetchOutcome('Invalid URL "x"'), WebFetchOutcome.fail);
      expect(webFetchOutcome('Refusing to fetch a private address.'), WebFetchOutcome.fail);
      expect(webFetchOutcome('Failed to fetch: timeout'), WebFetchOutcome.fail);
      expect(webFetchOutcome('Fetched https://a.b but body was empty.'), WebFetchOutcome.empty);
      expect(webFetchOutcome('Summarisation unavailable (boom). Raw content (first 4 KB):\n<html>'),
          WebFetchOutcome.raw);
      expect(
          webFetchOutcome('The page at https://a.b rendered almost no readable text (12 chars). '
              'It is likely a JavaScript application.'),
          WebFetchOutcome.jsShell);
      expect(webFetchOutcome('# A fine summary\n正文'), WebFetchOutcome.summary);
    });
  });

  test('schemaParamDigest: framework fields filtered, required starred', () {
    final digest = schemaParamDigest({
      'properties': {
        'query': {'type': 'string'},
        'limit': {'type': 'integer'},
        'summary': {'type': 'string'},
        'danger': {'type': 'string'},
        'execution_group': {'type': 'integer'},
      },
      'required': ['query', 'summary'],
    });
    expect(digest, 'query*, limit');
  });

  testWidgets('MemoryNoteCard renders name + source badge + typeset body', (tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: MemoryNoteCard(
                note: (name: 'retry-policy', source: 'user', description: '口径', body: '**退避** 3 次')),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('retry-policy'), findsOneWidget);
    expect(find.text(t.chat.tool.memSourceUser), findsOneWidget);
    expect(find.text('口径'), findsOneWidget);
    expect(find.textContaining('退避', findRichText: true), findsOneWidget); // markdown 渲染态
  });

  testWidgets('webSearchBody renders clickable hit rows (title/snippet/host)', (tester) async {
    final state = _settled(
        result:
            '{"source":"brave","results":[{"title":"Anselm 文档","url":"https://docs.anselm.website/x","snippet":"本地优先平台"}]}');
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
            body: SizedBox(width: 420, child: Builder(builder: (c) => webSearchBody(c, state)))),
      ),
    ));
    await tester.pump();
    expect(find.text('Anselm 文档'), findsOneWidget);
    expect(find.text('本地优先平台'), findsOneWidget);
    expect(find.text('docs.anselm.website'), findsOneWidget); // host, mono 域名行
    expect(find.text('brave'), findsOneWidget); // source badge
  });

  testWidgets('an unparseable hit URL never crushes the title in a 280px host (批6 复审 — 尾格契约刚性)',
      (tester) async {
    // Uri.tryParse returns null on realistic scraped URLs (bad port here) → the fallback must be
    // WORD-truncated, never the full raw string (it measured 1600px+, zeroed the title and threw
    // RenderFlex overflow). 畸形 URL 回落必须词档截断,全原始串曾压垮标题列。
    final rawUrl = 'http://example.com:notaport/${'segment/' * 30}?q=1';
    final state = _settled(
        result: '{"source":"brave","results":[{"title":"A readable page title","url":"$rawUrl","snippet":"s"}]}');
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(width: 280, child: Builder(builder: (c) => webSearchBody(c, state))))),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no overflow 无溢出
    expect(tester.getSize(find.text('A readable page title')).width, greaterThan(0));
    expect(find.textContaining(rawUrl), findsNothing); // the raw string never renders 原始串绝不上屏
  });

  testWidgets('searchToolsBody renders the thin hit card: mono name + digest + description',
      (tester) async {
    final state = _settled(
        result: '{"tools":[{"name":"run_function","description":"执行一个函数",'
            '"parameters":{"properties":{"functionId":{},"payload":{},"summary":{}},"required":["functionId"]}}]}');
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
            body: SizedBox(width: 420, child: Builder(builder: (c) => searchToolsBody(c, state)))),
      ),
    ));
    await tester.pump();
    expect(find.text('run_function'), findsOneWidget);
    expect(find.text('functionId*, payload'), findsOneWidget); // starred + framework filtered
    expect(find.text('执行一个函数'), findsOneWidget); // one-line tease on the row 行上一行预览
    // The escape hatch now lives behind the row tap (批6 A-079: ledger row + expand body). 逃生口随行展开。
    expect(find.text(t.chat.tool.toolSchema), findsNothing);
    await tester.tap(find.text('run_function'));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.toolSchema), findsOneWidget);
  });

  group('MemoryNoteCard 壳 (WRK-066 批4 族一)', () {
    Widget host(Widget c) => TranslationProvider(
        child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 480, child: c)))));

    testWidgets('the shell is the ONE window — the grey well is retired', (tester) async {
      await tester.pumpWidget(host(const MemoryNoteCard(
          note: (name: 'note', source: 'user', description: 'd', body: 'hello body'))));
      await tester.pumpAndSettle();
      expect(find.byType(AnWindow), findsOneWidget);
      expect(find.byType(AnSunkenPanel), findsNothing);
    });

    testWidgets('a long body collapses with the standard expand affordance; markdown fences never nest a window', (tester) async {
      final long = "${'line\n' * 30}```dart\nvoid main() {}\n```\n${'tail\n' * 200}";
      await tester.pumpWidget(host(MemoryNoteCard(
          note: (name: 'note', source: 'ai', description: '', body: long))));
      await tester.pumpAndSettle();
      // Fenced code inside the window renders as AnCodeSurface (borderless-window-safe) — the
      // leaf-law debug assert would have thrown here otherwise. 围栏码走 AnCodeSurface,叶子律不炸。
      expect(find.byType(AnWindow), findsOneWidget);
      expect(find.textContaining('展开'), findsOneWidget);
    });
  });
}
