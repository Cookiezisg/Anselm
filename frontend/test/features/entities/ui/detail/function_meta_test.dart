import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_field.dart';
import 'package:anselm/core/ui/an_transform_box.dart';
import 'package:anselm/core/ui/icons.dart';
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

FixtureEntityRepository _repo() => FixtureEntityRepository(
      functions: [_fn()],
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
  group('meta section — AnKv editable', () {
    testWidgets('说明 + 标签 render as editable AnKv rows (tags comma-joined)', (tester) async {
      await tester.pumpWidget(_host(FunctionOverview(fn: _fn(tags: const ['util', 'io'])), _repo()));
      expect(find.byType(AnTransformBox), findsOneWidget); // page assembled
      expect(find.byType(AnKv), findsWidgets); // meta + venv both use the mature AnKv
      expect(find.text('util, io'), findsOneWidget); // tags round-trip through one comma-joined row
      expect(find.byIcon(AnIcons.edit), findsWidgets); // editable rows carry the hover pencil
    });

    testWidgets('editing the 说明 row commits a description PATCH', (tester) async {
      final repo = _repo();
      final fn = await repo.getFunction('fn_1');
      await tester.pumpWidget(_host(FunctionOverview(fn: fn), repo));
      // First pencil = the 说明 (description) row. 第一支铅笔=说明行。
      await tester.tap(find.byIcon(AnIcons.edit).first, warnIfMissed: false);
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
