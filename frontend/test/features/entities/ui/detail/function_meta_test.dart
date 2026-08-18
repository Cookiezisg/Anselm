import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_editable_value.dart';
import 'package:anselm/core/ui/an_kv.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/core/ui/an_tags.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:anselm/core/ui/an_version_diff.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/detail/overview/function_overview.dart';
import 'package:anselm/features/entities/ui/detail/version_tab.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// WRK-054 F2 rewrite gate — the function meta section (read-first, aligned, hover-pencil for BOTH
// description and tags) + the version tab (diff pinned, set-active below it, only for non-active).

final _t = DateTime.utc(2026, 6, 26);
const _ref = EntityRef(EntityKind.function, 'fn_1');

FunctionVersion _v(int v) => FunctionVersion(
  id: 'fn_1_v$v',
  functionId: 'fn_1',
  version: v,
  code: 'code v$v',
  inputs: const [Field(name: 'text', type: 'string')],
  outputs: const [Field(name: 'result', type: 'string')],
  createdAt: _t,
  updatedAt: _t,
);

FunctionEntity _fn({
  String desc = 'Coerce fields',
  List<String> tags = const ['util'],
}) => FunctionEntity(
  id: 'fn_1',
  name: 'normalize',
  description: desc,
  tags: tags,
  activeVersionId: 'fn_1_v2',
  activeVersion: _v(2),
  createdAt: _t,
  updatedAt: _t,
);

FixtureEntityRepository _repo({List<String> tags = const ['util']}) =>
    FixtureEntityRepository(
      functions: [_fn(tags: tags)],
      functionVersions: {
        'fn_1': [_v(2), _v(1)],
      },
    );

Widget _host(Widget child, FixtureEntityRepository repo) => ProviderScope(
  overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  child: TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 720, child: child)),
      ),
    ),
  ),
);

void main() {
  group('meta section — AnKv (text row + tags row)', () {
    testWidgets(
      '说明 = editable text row; 标签 = pills (not comma text), 1 edit pencil',
      (tester) async {
        await tester.pumpWidget(
          _host(FunctionOverview(fn: _fn(tags: const ['util', 'io'])), _repo()),
        );
        expect(
          find.text('result'),
          findsOneWidget,
        ); // input/output cards assembled (signature shown as cards, not a hero)
        expect(find.byType(AnKv), findsWidgets); // meta + venv both AnKv
        expect(
          find.byType(AnTags),
          findsOneWidget,
        ); // the 标签 row renders pills, not text
        expect(find.text('util'), findsOneWidget);
        expect(find.text('io'), findsOneWidget);
        expect(
          find.text('util, io'),
          findsNothing,
        ); // NOT a comma-joined text value
        // only the 说明 text row carries a pencil; the tags row uses ✕/➕ instead. 仅说明行有铅笔。
        expect(find.byIcon(AnIcons.edit), findsOneWidget);
      },
    );

    testWidgets(
      'venv dependencies render as a LABELED tags row — never bare mystery words '
      '(WRK-070 B12 「pydantic」孤儿帧)',
      (tester) async {
        final v = _v(2).copyWith(dependencies: const ['pydantic', 'httpx']);
        final fn = _fn().copyWith(activeVersion: v);
        final repo = FixtureEntityRepository(
          functions: [fn],
          functionVersions: {
            'fn_1': [v],
          },
        );
        await tester.pumpWidget(_host(FunctionOverview(fn: fn), repo));
        expect(
          find.text(t.entities.detail.card.deps),
          findsOneWidget,
          reason: '「依赖」标签给包名身份——无标签裸行读作神秘词',
        );
        expect(find.text('pydantic'), findsOneWidget);
        expect(find.text('httpx'), findsOneWidget);
        expect(
          find.byType(AnTags),
          findsNWidgets(2),
          reason: '标签行 + 依赖行,同一套 KV tags 文法',
        );
      },
    );

    testWidgets(
      'no dependencies → a single dash KV row, not the inbox-icon tombstone '
      '(WRK-077 ⑫ 用户点名帧)',
      (tester) async {
        final v = _v(2).copyWith(dependencies: const []);
        final fn = _fn().copyWith(activeVersion: v);
        final repo = FixtureEntityRepository(
          functions: [fn],
          functionVersions: {
            'fn_1': [v],
          },
        );
        await tester.pumpWidget(_host(FunctionOverview(fn: fn), repo));
        // Same AnKv/tags grammar as the populated case — the label survives, the tombstone
        // (AnState) is gone entirely from the tree.
        expect(find.text(t.entities.detail.card.deps), findsOneWidget);
        expect(find.byType(AnState), findsNothing);
        final depsRow = tester
            .widgetList<AnKv>(find.byType(AnKv))
            .expand((kv) => kv.rows)
            .firstWhere((r) => r.label == t.entities.detail.card.deps);
        expect(depsRow.tags, isEmpty); // AnKvRow.tags self-renders the dash
      },
    );

    testWidgets(
      'empty interface cards use one marker row without repeating the card title',
      (tester) async {
        final v = _v(2).copyWith(inputs: const [], outputs: const []);
        final fn = _fn().copyWith(activeVersion: v);
        final repo = FixtureEntityRepository(
          functions: [fn],
          functionVersions: {
            'fn_1': [v],
          },
        );
        await tester.pumpWidget(_host(FunctionOverview(fn: fn), repo));

        expect(find.text(t.entities.detail.sec.interface), findsOneWidget);
        final emptyMarkers = tester
            .widgetList<AnRow>(find.byType(AnRow))
            .where((row) => row.label == t.entities.detail.val.none)
            .toList();
        expect(emptyMarkers, hasLength(2));
        expect(emptyMarkers.every((row) => row.leadless), isTrue);
        final fieldRows = tester
            .widgetList<AnKv>(find.byType(AnKv))
            .expand((kv) => kv.rows)
            .toList();
        expect(
          fieldRows.any((row) => row.label == t.entities.detail.sec.input),
          isFalse,
        );
        expect(
          fieldRows.any((row) => row.label == t.entities.detail.sec.output),
          isFalse,
        );
      },
    );

    testWidgets('tags: rest=药丸净、hover→✕/➕、点➕→输入框、Enter 加、Esc 收、✕ 删', (
      tester,
    ) async {
      final repo = _repo(tags: const ['util', 'io']);
      final fn = await repo.getFunction('fn_1');
      await tester.pumpWidget(_host(FunctionOverview(fn: fn), repo));
      // Rest: no ✕; the ➕ is IN THE TREE (keyboard-reachable) but transparent; no input field.
      // 静态:无 ✕;➕ 常驻树(键盘可达)但透明;无输入框。
      expect(find.byIcon(AnIcons.close), findsNothing);
      final plus = find.byIcon(AnIcons.plus);
      expect(plus, findsOneWidget);
      // The reveal gate is SOME ancestor Opacity at 0 (the button's own internal Opacity is 1). 揭示门=祖先里有 0。
      double minPlusOpacity() => [
        for (final e
            in find
                .ancestor(of: plus, matching: find.byType(Opacity))
                .evaluate())
          (e.widget as Opacity).opacity,
      ].reduce((a, b) => a < b ? a : b);
      expect(minPlusOpacity(), 0);
      expect(find.byType(TextField), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(() => mouse.removePointer());
      await mouse.moveTo(tester.getCenter(find.text('util')));
      await tester.pumpAndSettle();
      // Hover: a ✕ per pill + the ➕ turns visible — but STILL no input field (input is on demand).
      // hover:每丸 ✕ + ➕ 显形;输入框仍不出现(按需)。
      expect(find.byIcon(AnIcons.close), findsNWidgets(2));
      expect(minPlusOpacity(), 1);
      expect(find.byType(TextField), findsNothing);

      // Press ➕ → the add input mounts, focused. 按 ➕ → 输入框挂出并聚焦。
      await tester.tap(plus);
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      expect(tester.widget<TextField>(input).focusNode?.hasFocus, isTrue);

      // Type + Enter → tag PATCHes; the field STAYS for chaining. 输入+Enter → PATCH;字段留驻连加。
      await tester.enterText(input, 'net');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect((await repo.getFunction('fn_1')).tags, contains('net'));
      expect(find.byType(TextField), findsOneWidget);

      // Esc → the field dismisses. Esc → 收框。
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);

      // ✕ removes (row re-hovered — still under the pointer). ✕ 删除。
      await mouse.moveTo(tester.getCenter(find.text('util')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AnIcons.close).first);
      await tester.pumpAndSettle();
      expect((await repo.getFunction('fn_1')).tags, isNot(contains('util')));
    });

    testWidgets('editing the 说明 row commits a description PATCH', (
      tester,
    ) async {
      final repo = _repo();
      final fn = await repo.getFunction('fn_1');
      await tester.pumpWidget(_host(FunctionOverview(fn: fn), repo));
      // Hover the 说明 row to reveal its idle-hidden pencil (flush-right value → pencil pushes on hover). 悬停揭示。
      final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await hover.addPointer(
        location: tester.getCenter(find.byType(AnEditableValue).first),
      );
      addTearDown(hover.removePointer);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byIcon(AnIcons.edit),
        warnIfMissed: false,
      ); // the lone 说明 pencil (far right)
      await tester.pumpAndSettle();
      final editing = find.byWidgetPredicate(
        (w) => w is EditableText && !w.readOnly,
      );
      expect(editing, findsOneWidget);
      await tester.enterText(editing, 'Trim + coerce v2');
      await tester.testTextInput.receiveAction(
        TextInputAction.done,
      ); // onSubmitted → commit
      await tester.pumpAndSettle();
      expect((await repo.getFunction('fn_1')).description, 'Trim + coerce v2');
    });
  });

  // WRK-077 VT rewrote this tab from «left list | right diff» into a full-width accordion, so the two
  // gates below moved with it: the diff is no longer pinned at the top of a right column (there IS no
  // column) and «Set active» is no longer a footer button under it (it lives in the row's ⋯ menu). What
  // still MUST hold — and is what these two assert — is that opening the tab already answers «what
  // changed last» with exactly ONE card, and that a version's card opens BELOW its own row, so nothing
  // above the tapped row ever moves. The accordion's own behaviour (five batteries, hunks, the ⋯ menu,
  // sticky opens) lives in version_tab_test.dart.
  // VT 批把本 tab 从「左列表|右 diff」改成全宽手风琴,故这两道闸随之搬家:diff 不再钉在右列顶(已无右列)、
  // 「设为活跃版本」不再是它下面的 footer 钮(已进行内 ⋯ 菜单)。仍必须成立、也正是这两测断言的:打开 tab 即以
  // **恰一张**卡回答「最近改了什么」;某版本的卡在**它自己那行下面**展开,故被点行以上的一切不动。手风琴自身
  // 行为(五电池/hunk/⋯ 菜单/粘性)在 version_tab_test.dart。
  group('version tab — the newest card opens in place, below its own row', () {
    Future<void> pump(WidgetTester tester, FixtureEntityRepository repo) async {
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
              theme: AnTheme.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(width: 900, child: VersionTab(_ref)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'newest version opens with the tab → exactly one card, no stray set-active button',
      (tester) async {
        await pump(tester, _repo()); // v2 active + newest → its card is open
        expect(find.byType(AnVersionDiff), findsOneWidget);
        // The action is a ⋯ menu item now, so nothing says «Set active» until the menu is opened —
        // and never for the active version at all. 动作已进 ⋯ 菜单,未开菜单不出现,活动版本更不出现。
        expect(find.text('Set active'), findsNothing);
      },
    );

    testWidgets('an older version opens its own card BELOW its own row', (
      tester,
    ) async {
      await pump(tester, _repo());
      await tester.tap(find.text('v1'));
      await tester.pumpAndSettle();
      // Two cards now: the default-open newest + the one just opened. 两张卡:默认开的最新 + 刚展开的。
      expect(find.byType(AnVersionDiff), findsNWidgets(2));
      final v1Row = find.text('v1');
      final v1Card = find.byType(AnVersionDiff).last;
      // The card's top edge sits below the tapped row's bottom edge — expansion pushes DOWN only, so
      // nothing above the row can move. 卡顶在被点行之下:展开只向下推,行以上的一切不动。
      expect(
        tester.getTopLeft(v1Card).dy,
        greaterThan(tester.getBottomLeft(v1Row).dy - 1),
      );
    });
  });
}
