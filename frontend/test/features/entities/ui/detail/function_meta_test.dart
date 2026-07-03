import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_field.dart';
import 'package:anselm/core/ui/an_tags.dart';
import 'package:anselm/core/ui/an_transform_box.dart';
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
    updatedAt: _t);

FunctionEntity _fn({String desc = 'Coerce fields', List<String> tags = const ['util']}) => FunctionEntity(
    id: 'fn_1',
    name: 'normalize',
    description: desc,
    tags: tags,
    activeVersionId: 'fn_1_v2',
    activeVersion: _v(2),
    createdAt: _t,
    updatedAt: _t);

FixtureEntityRepository _repo({List<String> tags = const ['util']}) => FixtureEntityRepository(
      functions: [_fn(tags: tags)],
      functionVersions: {
        'fn_1': [_v(2), _v(1)]
      },
    );

Widget _host(Widget child, FixtureEntityRepository repo) => ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 720, child: child))),
        ),
      ),
    );

void main() {
  group('meta section — AnKv (text row + tags row)', () {
    testWidgets('说明 = editable text row; 标签 = pills (not comma text), 1 edit pencil', (tester) async {
      await tester.pumpWidget(_host(FunctionOverview(fn: _fn(tags: const ['util', 'io'])), _repo()));
      expect(find.byType(AnTransformBox), findsOneWidget); // page assembled
      expect(find.byType(AnKv), findsWidgets); // meta + venv both AnKv
      expect(find.byType(AnTags), findsOneWidget); // the 标签 row renders pills, not text
      expect(find.text('util'), findsOneWidget);
      expect(find.text('io'), findsOneWidget);
      expect(find.text('util, io'), findsNothing); // NOT a comma-joined text value
      // only the 说明 text row carries a pencil; the tags row uses ✕/➕ instead. 仅说明行有铅笔。
      expect(find.byIcon(AnIcons.edit), findsOneWidget);
    });

    testWidgets('tags: rest=药丸净、hover→✕/➕、点➕→输入框、Enter 加、Esc 收、✕ 删', (tester) async {
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
            for (final e in find.ancestor(of: plus, matching: find.byType(Opacity)).evaluate())
              (e.widget as Opacity).opacity
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

    testWidgets('editing the 说明 row commits a description PATCH', (tester) async {
      final repo = _repo();
      final fn = await repo.getFunction('fn_1');
      await tester.pumpWidget(_host(FunctionOverview(fn: fn), repo));
      await tester.tap(find.byIcon(AnIcons.edit), warnIfMissed: false); // the lone 说明 pencil (far right)
      await tester.pumpAndSettle();
      final editing = find.byWidgetPredicate((w) => w is EditableText && !w.readOnly);
      expect(editing, findsOneWidget);
      await tester.enterText(editing, 'Trim + coerce v2');
      await tester.testTextInput.receiveAction(TextInputAction.done); // onSubmitted → commit
      await tester.pumpAndSettle();
      expect((await repo.getFunction('fn_1')).description, 'Trim + coerce v2');
    });
  });

  group('version tab — diff pinned, action below', () {
    Future<void> pump(WidgetTester tester, FixtureEntityRepository repo) async {
      final container = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      container.listen(entityDetailProvider(_ref), (_, _) {});
      await container.read(entityDetailProvider(_ref).future);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            theme: AnTheme.light(),
            home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 900, child: VersionTab(_ref)))),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('active version selected → diff shows, no set-active button', (tester) async {
      await pump(tester, _repo()); // v2 active, index 0 default
      expect(find.byType(AnVersionDiff), findsOneWidget);
      expect(find.text('Set active'), findsNothing);
    });

    testWidgets('older version selected → set-active appears BELOW the diff', (tester) async {
      await pump(tester, _repo());
      await tester.tap(find.text('v1'));
      await tester.pumpAndSettle();
      final diff = find.byType(AnVersionDiff);
      final btn = find.text('Set active');
      expect(diff, findsOneWidget);
      expect(btn, findsOneWidget);
      // The action's top edge is below the diff's bottom edge — it can never shift the diff. 动作在 diff 下方。
      expect(tester.getTopLeft(btn).dy, greaterThan(tester.getBottomLeft(diff).dy - 1));
    });
  });
}
