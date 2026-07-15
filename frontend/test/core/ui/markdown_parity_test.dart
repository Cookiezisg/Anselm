// The PERMANENT editor⇄chat 1:1 guard (WRK, markdown parity). Two lines of defense:
//   1. The exhaustive [buildMarkdownCorpus] renders on BOTH surfaces — chat ([AnMarkdown]) and the document
//      editor ([AnEditor]) — WITHOUT throwing. Every inline type in every block context + all the nesting /
//      adjacency / CJK edge cases. If either renderer regresses on any element, this goes red.
//   2. A plain table renders with IDENTICAL Table geometry on both surfaces (chat's [AnProseTable] and the
//      editor's super_editor table are BOTH a Flutter [Table]) — same column/row count and same rendered
//      size. Font-independent: both use the same test font, so equal geometry ⇔ equal rendering.
//
// Per-element behaviour (list-marker baseline, table header alignment, inline-code chip, heading gaps) is
// pinned by the element-specific tests (an_editor_baseline_test, an_editor_markdown_test, an_markdown_test);
// THIS test guards the cross-surface parity + whole-corpus resilience those can't see individually.
//
// 常驻编辑器⇄chat 1:1 守卫:①全谱语料在两面都不抛异常渲染(穷尽元素×上下文);②纯表格两面 Flutter Table 几何一致
// (列/行数 + 尺寸,与字体无关)。逐元素细节归各元素测试,此测守跨面一致 + 全谱韧性。
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/dev/markdown_corpus.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Chat host — AnMarkdown in a bounded, scrollable reading column. chat 宿主(有界可滚阅读列)。
  Widget chatHost(String md) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 720,
              child: SingleChildScrollView(child: AnMarkdown(md)),
            ),
          ),
        ),
      );

  // Editor host — AnEditor (its own scroll) under a ProviderScope, mirroring the demo/app wiring; the
  // mention id resolves to a name so the `[[id]]` pill renders. 编辑器宿主(自持滚动、ProviderScope)。
  Widget editorHost(String md) => ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Scaffold(
              body: SizedBox(
                width: 720,
                child: AnEditor(
                  initialMarkdown: md,
                  resolvedNames: const {kCorpusMentionId: kCorpusMentionName},
                ),
              ),
            ),
          ),
        ),
      );

  setUp(() {
    // super_editor's interactors read accessibility features; pin them so nothing animates/asserts.
    TestWidgetsFlutterBinding.instance.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.clearAccessibilityFeaturesTestValue());

  testWidgets('the whole markdown corpus renders on CHAT (AnMarkdown) without throwing', (tester) async {
    tester.view.physicalSize = const Size(760, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(chatHost(buildMarkdownCorpus()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AnMarkdown), findsOneWidget);
  });

  testWidgets('the whole markdown corpus renders on the EDITOR (AnEditor) without throwing', (tester) async {
    tester.view.physicalSize = const Size(760, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(editorHost(buildMarkdownCorpus()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AnEditor), findsOneWidget);
  });

  testWidgets('a plain table renders IDENTICAL Table geometry on chat and editor (1:1)', (tester) async {
    tester.view.physicalSize = const Size(760, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const md = '| Kind | Verb | Example |\n'
        '|---|:---:|---:|\n'
        '| function | run | fetch_weather |\n'
        '| handler | call | slack.post |\n'
        '| workflow | trigger | daily_digest |';

    await tester.pumpWidget(chatHost(md));
    await tester.pump();
    final chatSize = tester.getSize(find.byType(Table));
    final chatTable = tester.widget<Table>(find.byType(Table));

    await tester.pumpWidget(editorHost(md));
    await tester.pump();
    final editSize = tester.getSize(find.byType(Table));
    final editTable = tester.widget<Table>(find.byType(Table));

    // Same structure: identical row count (header + 3 data) and column count.
    expect(chatTable.children.length, editTable.children.length, reason: 'same row count');
    expect(chatTable.children.first.children.length, editTable.children.first.children.length,
        reason: 'same column count');
    // Same rendered geometry — both a Flutter Table filling the same 720 column with the same shared tokens
    // (border hairline, cellPadding 12h/6v, reading text). Sub-pixel tolerance for glyph rounding.
    expect((chatSize.width - editSize.width).abs(), lessThan(1.0), reason: 'same table width');
    expect((chatSize.height - editSize.height).abs(), lessThan(1.0), reason: 'same table height (row spacing)');
  });
}
