import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnSidebarList = New + in-domain filter + groups→types→rows tree (on AnRow/AnInput/AnMenu). Selection is
// controlled; filter hides non-matches + reveals ancestors. AnSidebarList 契约。
void main() {
  SidebarModel model() => SidebarModel(
    newLabel: 'New',
    filterPlaceholder: 'Filter…',
    groups: [
      SidebarGroup(
        types: [
          SidebarType(
            label: 'Functions',
            icon: AnIcons.function,
            count: 2,
            rows: const [
              SidebarRow(id: 'fn1', label: 'normalize-input'),
              SidebarRow(id: 'fn2', label: 'validate-schema'),
            ],
          ),
        ],
      ),
    ],
  );

  // TranslationProvider: the in-place rename row mounts AnInlineEdit → AnEditAffordance, which reads
  // context.t for its button labels. 就地改名行的 AnEditAffordance 读 context.t,故需 TranslationProvider。
  Widget host(Widget child) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 280, height: 400, child: child)),
      ),
    ),
  );

  testWidgets('renders New + filter + section head + rows', (tester) async {
    await tester.pumpWidget(
      host(AnSidebarList(model: model(), onNew: () {}, onSelect: (_) {})),
    );
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Functions'), findsOneWidget); // type head
    expect(find.text('normalize-input'), findsOneWidget);
    expect(find.text('validate-schema'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an entity row selects it', (tester) async {
    String? sel;
    await tester.pumpWidget(
      host(AnSidebarList(model: model(), onSelect: (id) => sel = id)),
    );
    await tester.tap(find.text('normalize-input'));
    await tester.pumpAndSettle();
    expect(sel, 'fn1');
  });

  testWidgets(
    'filter hides non-matching rows, keeps matches (+ reveals their type)',
    (tester) async {
      await tester.pumpWidget(
        host(AnSidebarList(model: model(), onSelect: (_) {})),
      );
      await tester.enterText(find.byType(TextField), 'normalize');
      await tester.pumpAndSettle();
      expect(find.text('normalize-input'), findsOneWidget);
      expect(find.text('validate-schema'), findsNothing); // filtered out
      expect(
        find.text('Functions'),
        findsOneWidget,
      ); // type stays (has a match)
    },
  );

  testWidgets(
    'the type head is a disclosure button — tapping it collapses its rows',
    (tester) async {
      await tester.pumpWidget(
        host(AnSidebarList(model: model(), onSelect: (_) {})),
      );
      expect(find.text('normalize-input'), findsOneWidget);
      await tester.tap(
        find.text('Functions'),
      ); // type head toggles (whole head; keyboard-operable, not mouse-only lead)
      await tester.pumpAndSettle();
      expect(find.text('normalize-input'), findsNothing); // type collapsed
    },
  );

  testWidgets(
    'editingRowId swaps that row for an in-place rename field; commit bubbles (id, value)',
    (tester) async {
      String? gotId, gotValue;
      await tester.pumpWidget(
        host(
          AnSidebarList(
            model: model(),
            onSelect: (_) {},
            editingRowId: 'fn1',
            onRenameCommit: (id, v) {
              gotId = id;
              gotValue = v;
            },
            onRenameCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The edited row is now the rename primitive (its value seeds the field); the OTHER row is untouched.
      // Scope to the AnInlineEdit's field — AnSidebarList also has the filter input. 限定到编辑框(列表还有过滤框)。
      final field = find.descendant(
        of: find.byType(AnInlineEdit),
        matching: find.byType(EditableText),
      );
      expect(find.byType(AnInlineEdit), findsOneWidget);
      expect(
        tester.widget<EditableText>(field).controller.text,
        'normalize-input',
      );
      expect(find.text('validate-schema'), findsOneWidget);

      await tester.enterText(field, 'renamed-fn');
      await tester.testTextInput.receiveAction(
        TextInputAction.done,
      ); // Enter → commit
      await tester.pumpAndSettle();
      expect(gotId, 'fn1');
      expect(gotValue, 'renamed-fn');
    },
  );

  testWidgets('Esc in the editing row fires onRenameCancel', (tester) async {
    var cancels = 0;
    await tester.pumpWidget(
      host(
        AnSidebarList(
          model: model(),
          onSelect: (_) {},
          editingRowId: 'fn1',
          onRenameCommit: (_, _) {},
          onRenameCancel: () => cancels++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(cancels, 1);
  });

  // ── five-battery ──────────────────────────────────────────────────────────
  group('sticky ancestor overlay', () {
    SidebarModel twoSections() => SidebarModel(
      newLabel: 'New',
      filterPlaceholder: 'Filter…',
      groups: [
        SidebarGroup(
          types: [
            SidebarType(
              label: 'ALPHA',
              icon: AnIcons.pin,
              rows: [
                for (var i = 0; i < 20; i++)
                  SidebarRow(id: 'a$i', label: 'alpha-$i'),
              ],
            ),
            SidebarType(
              label: 'BETA',
              icon: AnIcons.history,
              rows: [
                for (var i = 0; i < 20; i++)
                  SidebarRow(id: 'b$i', label: 'beta-$i'),
              ],
            ),
          ],
        ),
      ],
    );

    // The sticky copy of a head is the LAST match (the overlay stacks above the list). 吸顶副本=最后一个匹配。
    double headY(WidgetTester t, String label) =>
        t.getTopLeft(find.text(label).last).dy;

    testWidgets(
      'mid-section scrolling NEVER moves the pinned head (the tumble bug)',
      (tester) async {
        await tester.pumpWidget(host(AnSidebarList(model: twoSections())));
        final list = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;

        // Scroll into ALPHA's middle at several offsets INSIDE one row-height of each other — the old
        // depth-scan pushed the head once per row, so its y oscillated. 段中多个错相 offset:旧实现头逐行振荡。
        final ys = <double>[];
        for (final off in [
          4 * AnSize.row,
          4 * AnSize.row + 10,
          4 * AnSize.row + 20,
          5 * AnSize.row + 4,
        ]) {
          list.jumpTo(off);
          await tester.pump();
          ys.add(headY(tester, 'ALPHA'));
        }
        expect(ys.toSet(), hasLength(1)); // pinned STILL 钉死不动
      },
    );

    testWidgets(
      'the NEXT section head pushes the pinned one out smoothly; then replaces it',
      (tester) async {
        await tester.pumpWidget(host(AnSidebarList(model: twoSections())));
        final list = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;

        list.jumpTo(10 * AnSize.row);
        await tester.pump();
        final pinnedY = headY(tester, 'ALPHA');

        // BETA's head sits at flat index 21; push begins when it crosses the slot bottom. BETA 头临近:推走。
        list.jumpTo(21 * AnSize.row - AnSize.row / 2);
        await tester.pump();
        expect(headY(tester, 'ALPHA'), lessThan(pinnedY)); // mid-push 半推
        // The handover is a SHOVE: the successor rides exactly one row-height below the pushed head
        // (its top edge on the head's bottom edge) — the in-row text offsets cancel, so the text tops
        // differ by exactly AnSize.row. And nothing (no slot backing) may hide the riser.
        // 交接=顶走:接替头恰骑在被推头下一行高处(顶边贴底边)——行内文字偏移相消,文字 y 差恰一行高;
        // 且无物(整槽底)遮挡上升者。
        expect(
          headY(tester, 'BETA') - headY(tester, 'ALPHA'),
          closeTo(AnSize.row, 0.01),
        );
        list.jumpTo(22 * AnSize.row + 4);
        await tester.pump();
        expect(
          headY(tester, 'BETA'),
          pinnedY,
        ); // BETA now pinned where ALPHA was BETA 接棒钉住
      },
    );

    testWidgets(
      'a head reaching the top pins IMMEDIATELY (never scrolls out and pops back)',
      (tester) async {
        await tester.pumpWidget(host(AnSidebarList(model: twoSections())));
        final list = tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position;

        // The settled pinned position first (deep in BETA's section). 先取稳定钉住位。
        list.jumpTo(25 * AnSize.row);
        await tester.pump();
        final pinnedY = headY(tester, 'BETA');

        // Offset INSIDE the BETA head's own row (index 21): the old code left the sticky empty here —
        // the head scrolled out one row, then popped back. It must already sit at the pinned position.
        // offset 落在 BETA 头自己的行内:旧码此处吸顶为空(头滚出一行再跳回);现在必须已在钉住位。
        list.jumpTo(21 * AnSize.row + AnSize.row / 2);
        await tester.pump();
        expect(headY(tester, 'BETA'), pinnedY);
      },
    );
  });

  testWidgets(
    'battery empty: an empty model renders the chrome + nothing else, no throw',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AnSidebarList(
            model: SidebarModel(newLabel: 'New', filterPlaceholder: 'Filter…'),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.text('New'),
        findsOneWidget,
      ); // the New/filter chrome stays even with no rows
    },
  );

  testWidgets(
    'battery massive: a 5000-row section virtualizes — the far tail never builds',
    (tester) async {
      final big = SidebarModel(
        groups: [
          SidebarGroup(
            types: [
              SidebarType(
                label: 'All',
                icon: AnIcons.function,
                rows: [
                  for (var i = 0; i < 5000; i++)
                    SidebarRow(id: 'a$i', label: 'entity-$i'),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        host(AnSidebarList(model: big, onSelect: (_) {})),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('entity-0'), findsOneWidget); // head rows build
      expect(
        find.text('entity-4999'),
        findsNothing,
      ); // virtualized: the off-screen tail does not
    },
  );

  testWidgets(
    'battery overlong/injection: markup + long labels are inert plain text (no overflow/throw)',
    (tester) async {
      final m = SidebarModel(
        groups: [
          SidebarGroup(
            types: [
              SidebarType(
                label: 'Sec',
                icon: AnIcons.function,
                rows: const [
                  SidebarRow(
                    id: 'x',
                    label: '<b>not</b> & <i>html</i> 一个非常非常长的标题应当省略号截断而不撑破侧栏宽度',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(host(AnSidebarList(model: m, onSelect: (_) {})));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
