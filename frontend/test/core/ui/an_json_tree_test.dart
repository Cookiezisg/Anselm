import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnJsonTree = the JSON / structured-data tree (TreeSliver). No-overflow + virtualization are matrix +
// real-run concerns; here: rendering, expand/collapse, type dispatch, circular, invalid JSON, showRoot,
// edges. It's a SCROLL HOST → host gives it a bounded height. AnJsonTree 渲染/折叠/类型/环/错误/边界。
void main() {
  Widget host(Widget child, {double width = 420, double height = 400}) =>
      TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, height: height, child: child),
            ),
          ),
        ),
      );

  testWidgets('renders object keys + values (type-coloured leaves)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnJsonTree(
          data: {'name': 'john', 'n': 3, 'ok': true},
          showRoot: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('name'), findsOneWidget);
    expect(find.textContaining('john'), findsOneWidget);
    expect(find.textContaining('3'), findsOneWidget);
    expect(find.textContaining('true'), findsOneWidget);
  });

  testWidgets(
    'branch expands on tap to reveal children (collapsed by open-depth)',
    (tester) async {
      // openDepth 0 → the depth-0 branch starts collapsed (expanded = depth < openDepth). openDepth 0 → 顶层折叠。
      await tester.pumpWidget(
        host(
          const AnJsonTree(
            data: {
              'outer': {'inner': 'v'},
            },
            showRoot: false,
            openDepth: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('outer'), findsOneWidget);
      expect(find.textContaining('inner'), findsNothing); // collapsed
      await tester.tap(find.textContaining('outer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('inner'), findsOneWidget); // expanded
    },
  );

  testWidgets('circular reference → [Circular], no stack overflow', (
    tester,
  ) async {
    final m = <String, Object?>{'name': 'node'};
    m['self'] = m;
    await tester.pumpWidget(host(AnJsonTree(data: m, openDepth: 3)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('[Circular]'), findsOneWidget);
  });

  testWidgets('invalid JSON → an error row, not a crash', (tester) async {
    await tester.pumpWidget(host(const AnJsonTree(jsonString: '{ bad,, }')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Invalid JSON'), findsOneWidget);
  });

  testWidgets('showRoot false omits the root row', (tester) async {
    await tester.pumpWidget(
      host(const AnJsonTree(data: {'a': 1, 'b': 2}, showRoot: false)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('root'), findsNothing);
    expect(find.textContaining('a'), findsWidgets);
  });

  testWidgets('showRoot true shows the labelled root branch', (tester) async {
    await tester.pumpWidget(
      host(const AnJsonTree(data: {'a': 1}, rootLabel: 'payload')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('payload'), findsOneWidget);
  });

  testWidgets('scalar / null / empty collections render without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AnJsonTree(
          data: {
            's': '',
            'nil': null,
            'emptyObj': <String, Object?>{},
            'emptyArr': <Object?>[],
          },
          showRoot: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('null'), findsOneWidget);
  });

  testWidgets('array root indexes its items', (tester) async {
    await tester.pumpWidget(
      host(const AnJsonTree(data: ['x', 'y'], rootLabel: 'list', openDepth: 2)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('x'), findsOneWidget);
    expect(find.textContaining('y'), findsOneWidget);
  });

  testWidgets(
    'special characters render as plain text (no injection surface)',
    (tester) async {
      await tester.pumpWidget(
        host(const AnJsonTree(data: {'html': '<b>x</b> & y'}, showRoot: false)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('<b>x</b> & y'), findsOneWidget);
    },
  );

  testWidgets(
    'a11y: container is a labelled tree; a branch exposes a toggling expanded state',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const AnJsonTree(
            data: {
              'cfg': {'a': 1},
              'x': 2,
            },
            showRoot: false,
            openDepth: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // container label (top-level item count) 容器 label
      expect(
        find.bySemanticsLabel(RegExp('JSON tree, 2 items')),
        findsOneWidget,
      );
      // 'cfg' is a branch button, collapsed (expanded false) 分支=按钮、折叠
      final branchFinder = find
          .ancestor(
            of: find.textContaining('cfg'),
            matching: find.byType(AnInteractive),
          )
          .first;
      expect(
        tester.getSemantics(branchFinder),
        isSemantics(isButton: true, isExpanded: false),
      );
      // toggle → expanded flips 展开翻转
      await tester.tap(find.textContaining('cfg'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(branchFinder), isSemantics(isExpanded: true));
      handle.dispose();
    },
  );

  testWidgets(
    'a large tree scrolls within its bounded viewport (virtualized, no overflow)',
    (tester) async {
      final big = {for (var i = 0; i < 50; i++) 'key_$i': 'value_$i'};
      await tester.pumpWidget(
        host(AnJsonTree(data: big, showRoot: false), height: 200),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('key_0'), findsOneWidget);
      // scroll down → later keys come into view, no overflow. 下滚 → 后面的键进视口、不溢出。
      await tester.drag(find.byType(AnJsonTree), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  // ───────────────────────── WRK-077 CR-3 ─────────────────────────
  // The reported bug ("the Output tree won't expand") was never a tree bug: the tree expanded, and the
  // host had pinned the viewport to the top-level key count, so every revealed row sat below an unmarked
  // fold. Two tests: the box must follow the LIVE row count, and a data refresh must not steal the
  // reader's expansions.
  // 用户报的「Output 树展不开」从来不是树的 bug:树展开了,而宿主把视口钉在顶层键数上,于是露出的行全在一条
  // 无标记的折线之下。两条:框须跟随**活行数**;数据刷新不得偷走读者的展开。

  // Self-sizing only means anything under a LOOSE height — which is what the real host gives (the tree
  // sits in an AnSection's Column inside the inspector's scrollable). A tight host would force the box to
  // the parent's height and the assertions would measure the host, not the fix.
  // 自量高只在**松**高度下有意义,而真宿主给的正是松约束(树坐在 AnSection 的 Column 里、外面是右岛的滚动
  // 体)。紧约束宿主会把框逼成父高,断言量到的就是宿主而不是这个修复。
  Widget looseHost(Widget child, {double width = 420}) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
          ),
        ),
      ),
    ),
  );

  testWidgets('CR-3: the self-sized box GROWS with the live row count, capped', (
    tester,
  ) async {
    // {length: 8, sorted: [1,2,3]} is the user's own frame, shrunk. Top level is open at openDepth 1, so
    // 'sorted' starts expanded; collapsing then re-expanding it must move the box.
    // {length: 8, sorted: [1,2,3]} 就是用户那一帧的缩小版。openDepth 1 下顶层开着,故 'sorted' 开局即展开;
    // 折叠再展开必须让框跟着动。
    await tester.pumpWidget(
      looseHost(
        const AnJsonTree(
          data: {
            'length': 8,
            'sorted': [1, 2, 3],
          },
          showRoot: false,
          openDepth: 1,
          maxHeight: 400,
        ),
      ),
    );
    await tester.pumpAndSettle();

    double boxHeight() => tester.getSize(find.byType(AnJsonTree)).height;

    // 2 top rows + 3 children of 'sorted' = 5 rows. 2 顶行 + 'sorted' 的 3 子行 = 5 行。
    final expanded = boxHeight();
    expect(expanded, 5 * AnSize.row);

    await tester.tap(find.textContaining('sorted'));
    await tester.pumpAndSettle();
    expect(
      boxHeight(),
      2 * AnSize.row,
      reason: 'collapsed → only the 2 top rows',
    );

    await tester.tap(find.textContaining('sorted'));
    await tester.pumpAndSettle();
    expect(boxHeight(), expanded, reason: 're-expanded → back to 5 rows');
  });

  testWidgets('CR-3: the cap holds — a huge tree never grows past maxHeight', (
    tester,
  ) async {
    await tester.pumpWidget(
      looseHost(
        AnJsonTree(
          data: {for (var i = 0; i < 200; i++) 'k$i': i},
          showRoot: false,
          openDepth: 1,
          maxHeight: 240,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AnJsonTree)).height, 240);
  });

  testWidgets(
    'CR-3: a refetch that yields an EQUAL-but-new object keeps the reader\'s expansions',
    (tester) async {
      // Dart compares Map/List by identity, so an SSE tick / poll / DTO rebuild upstream produced a "new"
      // value every time and wiped the expansion state. Verified as a real defect with a probe before the
      // fix. 上游每个 SSE tick / 轮询 / DTO 重建都产出「新」值,展开态被抹掉。修前用探针验过它是真缺陷。
      Widget at(Object data) => host(
        AnJsonTree(data: data, showRoot: false, openDepth: 1, maxHeight: 400),
        height: 600,
      );

      await tester.pumpWidget(
        at({
          'a': {
            'b': {'c': 1},
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('c'),
        findsNothing,
        reason: 'depth-1 branch starts closed',
      );

      await tester.tap(find.textContaining('b'));
      await tester.pumpAndSettle();
      expect(find.textContaining('c'), findsOneWidget);

      await tester.pumpWidget(
        at({
          'a': {
            'b': {'c': 1},
          },
        }),
      ); // equal content, new instance 内容相同的新实例
      await tester.pumpAndSettle();
      expect(
        find.textContaining('c'),
        findsOneWidget,
        reason: 'the reader opened this branch — a refetch must not close it',
      );
    },
  );

  testWidgets(
    'CR-3: a NEW openDepth re-seeds the shape (an explicit request, so no preservation)',
    (tester) async {
      Widget at(int depth) => host(
        AnJsonTree(
          data: const {
            'a': {
              'b': {'c': 1},
            },
          },
          showRoot: false,
          openDepth: depth,
          maxHeight: 400,
        ),
        height: 600,
      );

      await tester.pumpWidget(at(2));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('c'),
        findsOneWidget,
        reason: 'depth 2 opens b',
      );

      await tester.pumpWidget(at(1));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('c'),
        findsNothing,
        reason: 'openDepth changed — the seed wins, not the old open-set',
      );
    },
  );

  testWidgets(
    'CR-3: the REAL host shape (AnSection in a scrollable) leaves the height loose',
    (tester) async {
      // The fix is inert under a tight height, so assert the actual chain the inspector uses really is
      // loose — otherwise the primitive could be correct and the product still broken.
      // 紧高度下这个修复是空转的,故断言右岛真正使用的那条链确实是松的——否则原语对了、产品照旧坏着。
      await tester.pumpWidget(
        looseHost(
          const AnSection(
            label: 'Output',
            variant: AnSectionVariant.plain,
            children: [
              AnJsonTree(
                data: {
                  'length': 8,
                  'sorted': [1, 2, 3],
                },
                showRoot: false,
                openDepth: 1,
                maxHeight: 400,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnJsonTree)).height, 5 * AnSize.row);
    },
  );
}
