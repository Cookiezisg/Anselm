import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:anselm/core/ui/an_version_diff.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/detail/version_tab.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-077 VT gate — the versions tab as a FULL-WIDTH accordion: one row per version carrying its own
// information (time · note · summary · +N −N · active marker · ⋯), opening IN PLACE to a hunk-mode diff
// card, with the whole-file escape and «set active» reached from the row's ⋯ menu. Plus the five
// batteries (empty / single version / a 5000-char space-less line / a hundred versions / an extreme
// diff) and the open-set stickiness.
// VT 批门禁——版本 tab 全宽手风琴:一版一行信息给足、就地展开 hunk 卡、⋯ 菜单收纳整份逃生口与设为活跃;
// 外加五电池(空/单版本/无空格 5000 字符/百版本/极端 diff)与开合集粘性。

final _t = DateTime.utc(2026, 6, 26, 10, 30);
const _ref = EntityRef(EntityKind.function, 'fn_1');

String _body(int n, {int? changeAt, String? longLine}) => [
  for (var i = 0; i < n; i++)
    if (i == changeAt)
      'CHANGED_$i = mutate($i)'
    else if (i == 0 && longLine != null)
      longLine
    else
      'line_$i = compute($i)',
].join('\n');

FunctionVersion _v(
  int v, {
  String? code,
  String? reason,
  DateTime? createdAt,
}) => FunctionVersion(
  id: 'fn_1_v$v',
  functionId: 'fn_1',
  version: v,
  code: code ?? 'code v$v',
  changeReason: reason,
  createdAt: createdAt ?? _t,
  updatedAt: createdAt ?? _t,
);

FixtureEntityRepository _repo(
  List<FunctionVersion> versions, {
  String activeId = 'fn_1_v2',
}) => FixtureEntityRepository(
  functions: [
    FunctionEntity(
      id: 'fn_1',
      name: 'normalize',
      activeVersionId: activeId,
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  functionVersions: {'fn_1': versions},
);

Future<void> _pump(
  WidgetTester tester,
  FixtureEntityRepository repo, {
  double width = 720,
  double height = 900,
}) async {
  final container = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  container.listen(entityDetailProvider(_ref), (_, _) {});
  await container.read(entityDetailProvider(_ref).future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: height,
              // The page owns the document scroll (AnPage's shape). 页持文档滚动(AnPage 形状)。
              child: SingleChildScrollView(child: VersionTab(_ref)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Open a row's ⋯ with a REAL mouse — the trail actions are hover-revealed and the idle layer is
// IgnorePointer'd, so a synthesized touch tap would fall through (the entity/conversation rail twins).
// 用真鼠标开 ⋯:行动作 hover 才揭示、静息层 IgnorePointer,合成触摸点击会穿过去。
Future<void> _openRowMenu(WidgetTester tester, String rowLabel) async {
  // FocusableActionDetector only reports hover while the focus highlight mode is «traditional»; a fresh
  // test binding sits in touch mode, so the reveal would never fire. 无此行则 FAD 在触摸模式下不报 hover。
  WidgetsBinding.instance.focusManager.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(find.text(rowLabel)));
  await tester.pump();
  // EVERY row keeps its ⋯ mounted (the idle layer is a zero-opacity inert twin — no reflow on hover),
  // so scope the target to THIS row. 每行的 ⋯ 都常驻(静息层是零透明惰性孪生、hover 不重排),故按行取。
  final p = tester.getCenter(
    find.descendant(
      of: find.ancestor(of: find.text(rowLabel), matching: find.byType(AnRow)),
      matching: find.byIcon(AnIcons.more),
    ),
  );
  await mouse.moveTo(p);
  await tester.pump();
  await mouse.down(p);
  await mouse.up();
  await tester.pumpAndSettle();
  // Retire the device before the next call adds one (MouseTracker asserts add-after-remove per device);
  // the popover is an overlay and outlives the pointer. 用完即撤设备(MouseTracker 逐设备断言添加/移除配对),
  // 浮层在 overlay 里、不随指针消失。
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  group('the accordion', () {
    testWidgets('one row per version, full width, newest card open', (
      tester,
    ) async {
      await _pump(tester, _repo([_v(2), _v(1)]));
      expect(find.byType(AnRow), findsNWidgets(2));
      // Full width: the row spans the whole content column, no left/right split. 行占整宽,无左右对切。
      expect(tester.getSize(find.byType(AnRow).first).width, 720);
      // Only the newest version's card is open. 只有最新版本的卡是开的。
      expect(find.byType(AnVersionDiff), findsOneWidget);
      expect(find.text('v1 → v2'), findsOneWidget);
    });

    testWidgets('tapping a row toggles its own card (and only its own)', (
      tester,
    ) async {
      await _pump(tester, _repo([_v(3), _v(2), _v(1)]));
      expect(find.byType(AnVersionDiff), findsOneWidget);
      await tester.tap(find.text('v2'));
      await tester.pumpAndSettle();
      expect(find.byType(AnVersionDiff), findsNWidgets(2));
      expect(find.text('v1 → v2'), findsOneWidget); // v2's own card 是 v2 自己的卡
      await tester.tap(find.text('v2'));
      await tester.pumpAndSettle();
      expect(find.byType(AnVersionDiff), findsOneWidget);
    });

    testWidgets(
      'the row is the selection + the disclosure: selected while open, chevron in the lead',
      (tester) async {
        await _pump(tester, _repo([_v(2), _v(1)]));
        AnRow rowOf(String label) => tester
            .widgetList<AnRow>(find.byType(AnRow))
            .firstWhere((r) => r.label == label);
        expect(rowOf('v2').open, isTrue);
        expect(rowOf('v2').selected, isTrue, reason: 'open IS the grey block');
        expect(
          rowOf('v2').collapsible,
          isTrue,
          reason: 'the lead is a chevron',
        );
        expect(rowOf('v1').open, isFalse);
        expect(rowOf('v1').selected, isFalse);
        // The lead slot carries no status dot — it belongs to the chevron now. lead 无状态点,归箭头。
        expect(rowOf('v2').dot, isNull);
        expect(rowOf('v2').icon, isNull);
      },
    );

    testWidgets(
      'the row says it all: time · note · summary in the hint, +N −N in the trail, active in the dot',
      (tester) async {
        await _pump(
          tester,
          _repo([
            _v(2, code: 'a\nb\nCHANGED', reason: 'rename the coercion'),
            _v(1, code: 'a\nb\nc'),
          ]),
        );
        AnRow rowOf(String label) => tester
            .widgetList<AnRow>(find.byType(AnRow))
            .firstWhere((r) => r.label == label);
        expect(rowOf('v2').hint, contains('rename the coercion'));
        expect(rowOf('v2').meta, '+1 −1');
        expect(
          rowOf('v2').trailingDot,
          AnStatus.done,
          reason:
              'the active version is marked in the TRAIL (the lead is the chevron)',
        );
        expect(rowOf('v1').trailingDot, isNull);
        // The oldest loaded row has no older neighbour → no counts at all, never «+0 −0». 末行无计数。
        expect(rowOf('v1').meta, isNull);
      },
    );

    testWidgets('the card shows only the changed hunk, and can show it all', (
      tester,
    ) async {
      // 40 identical lines with one change in the middle → the far reaches fold away. 中间一处变更。
      await _pump(
        tester,
        _repo([_v(2, code: _body(40, changeAt: 20)), _v(1, code: _body(40))]),
      );
      expect(find.textContaining('CHANGED_20'), findsOneWidget);
      expect(find.textContaining('line_17'), findsOneWidget); // 3-line context
      expect(find.textContaining('line_0 '), findsNothing); // folded away 已折叠
      expect(find.textContaining('unchanged lines'), findsNWidgets(2));

      // «Show all» (the escape row under the card) flips the whole file in. 卡下逃生行翻出整份。
      await tester.tap(find.textContaining('Show all'));
      await tester.pumpAndSettle();
      expect(find.textContaining('unchanged lines'), findsNothing);
      expect(find.textContaining('line_0 '), findsOneWidget);
      expect(find.text('Only changes'), findsOneWidget);
    });

    testWidgets('the ⋯ menu is the second entrance to the SAME state', (
      tester,
    ) async {
      await _pump(
        tester,
        _repo([_v(2, code: _body(40, changeAt: 20)), _v(1, code: _body(40))]),
      );
      // v1 is collapsed → its menu offers «Show diff». v1 收起→菜单给「展开 diff」。
      await _openRowMenu(tester, 'v1');
      expect(find.text('Show diff'), findsOneWidget);
      await tester.tap(find.text('Show diff'));
      await tester.pumpAndSettle();
      expect(find.byType(AnVersionDiff), findsNWidgets(2));

      // …and now the same menu offers «Hide diff» — one truth, two entrances. 同一真相,两个入口。
      await _openRowMenu(tester, 'v1');
      expect(find.text('Hide diff'), findsOneWidget);
    });

    testWidgets(
      '⋯ «Set active» calls :revert and re-marks the row; the active version is never offered it',
      (tester) async {
        final repo = _repo([_v(2), _v(1)]);
        await _pump(tester, repo);
        // The ACTIVE version's menu has no set-active item at all. 活动版本菜单无此项。
        await _openRowMenu(tester, 'v2');
        expect(find.text('Set active'), findsNothing);
        await tester.tapAt(Offset.zero); // dismiss the popover 收起浮层
        await tester.pumpAndSettle();

        await _openRowMenu(tester, 'v1');
        expect(find.text('Set active'), findsOneWidget);
        await tester.tap(find.text('Set active'));
        await tester.pumpAndSettle();
        expect((await repo.getFunction('fn_1')).activeVersionId, 'fn_1_v1');
        final rows = tester.widgetList<AnRow>(find.byType(AnRow)).toList();
        expect(
          rows.firstWhere((r) => r.label == 'v1').trailingDot,
          AnStatus.done,
        );
        expect(rows.firstWhere((r) => r.label == 'v2').trailingDot, isNull);
      },
    );

    testWidgets('open cards survive a page append (sticky open set)', (
      tester,
    ) async {
      await _pump(tester, _repo([for (var i = 25; i >= 1; i--) _v(i)]));
      expect(find.byType(AnRow), findsNWidgets(20)); // one page 一页
      // Rows below the viewport are BUILT (the page is a Column) but sit off-screen — scroll them in
      // before touching. 视口外的行已建但在屏外,先滚进来再点。
      await tester.ensureVisible(find.text('v10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('v10'));
      await tester.pumpAndSettle();
      expect(find.byType(AnVersionDiff), findsNWidgets(2)); // v25 + v10
      await tester.ensureVisible(find.text('Load more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.byType(AnRow), findsNWidgets(25));
      // Both stay open across the append. 追加后两张卡都还开着。
      expect(find.byType(AnVersionDiff), findsNWidgets(2));
      expect(find.text('v9 → v10'), findsOneWidget);
    });
  });

  group('five batteries', () {
    testWidgets('empty → the honest empty state, no rows', (tester) async {
      await _pump(tester, _repo(const []));
      expect(find.text('No versions'), findsOneWidget);
      expect(find.byType(AnRow), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single version → earliest label, whole text, no counts', (
      tester,
    ) async {
      await _pump(tester, _repo([_v(1, code: 'a\nb')], activeId: 'fn_1_v1'));
      expect(find.byType(AnRow), findsOneWidget);
      expect(find.text('v1 · earliest version'), findsOneWidget);
      expect(find.textContaining('unchanged lines'), findsNothing);
      expect(find.textContaining('a'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 5000-char space-less line does not hang or overflow', (
      tester,
    ) async {
      final wall = 'x' * 5000;
      await _pump(
        tester,
        _repo([_v(2, code: _body(6, longLine: wall)), _v(1, code: _body(6))]),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AnVersionDiff), findsOneWidget);
    });

    testWidgets('a hundred versions page in without exception', (tester) async {
      await _pump(tester, _repo([for (var i = 100; i >= 1; i--) _v(i)]));
      expect(find.byType(AnRow), findsNWidgets(20));
      expect(find.text('Load more'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 5 pages of appends keep working. 连翻五页仍好。
      for (var p = 0; p < 4; p++) {
        await tester.ensureVisible(find.text('Load more'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(AnRow), findsNWidgets(100));
      expect(find.text('Load more'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'an extreme diff (3000 lines, nothing in common → the LCS degrade) stays lazy',
      (tester) async {
        // Past lineDiffMaxCells the diff degrades to «all del then all add» — 6002 rows with NOT ONE
        // context line, so hunk folding has nothing to fold and virtualization is the only thing
        // between the reader and a 6002-widget frame. 超阈退化为整段替换:6002 行且零上下文,hunk 无可折,
        // 只剩虚拟化挡在读者与 6002 个 widget 之间。
        await _pump(
          tester,
          _repo([
            _v(2, code: [for (var i = 0; i < 3000; i++) 'new_$i'].join('\n')),
            _v(1, code: [for (var i = 0; i < 3000; i++) 'old_$i'].join('\n')),
          ]),
        );
        expect(tester.takeException(), isNull);
        // The row's trail and the card's bar count the SAME pair, so the string appears twice — that
        // agreement is the point. 行上计数与卡内 bar 数的是同一对,故出现两次——一致正是要点。
        expect(find.text('+3000 −3000'), findsNWidgets(2));
        final built = find
            .byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.padding == const EdgeInsets.only(right: 12),
            )
            .evaluate()
            .length;
        expect(
          built,
          lessThan(80),
          reason: '6002 rows must not be built into one frame',
        );
      },
    );
  });
}
