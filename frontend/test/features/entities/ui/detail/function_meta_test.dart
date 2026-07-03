import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_tags.dart';
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
  group('meta section — read-first', () {
    testWidgets('tags render as read-only pills (no × / add-field) at rest', (tester) async {
      await tester.pumpWidget(_host(FunctionOverview(fn: _fn()), _repo()));
      // The transform-box hero renders (page assembled). hero 存在=页面装配。
      expect(find.byType(AnTransformBox), findsOneWidget);
      final tags = tester.widget<AnTags>(find.byType(AnTags));
      expect(tags.readOnly, isTrue, reason: 'tags are display-only until the pencil is clicked');
      expect(find.text('util'), findsOneWidget);
    });

    testWidgets('clicking the tags pencil switches to an editable AnTags', (tester) async {
      await tester.pumpWidget(_host(FunctionOverview(fn: _fn()), _repo()));
      // Both description + tags carry an opacity-gated (but hit-testable) edit pencil (AnIcons.edit);
      // the tags one is last in tree order. 点标签行铅笔 → 可编辑 AnTags。
      final pencils = find.byIcon(AnIcons.edit);
      expect(pencils, findsWidgets);
      await tester.tap(pencils.last, warnIfMissed: false);
      await tester.pumpAndSettle();
      final tags = tester.widget<AnTags>(find.byType(AnTags));
      expect(tags.readOnly, isFalse, reason: 'editing → AnTags with × + add-field');
    });

    testWidgets('empty tags show an em-dash at rest (no bare add field)', (tester) async {
      await tester.pumpWidget(_host(FunctionOverview(fn: _fn(tags: const [])), _repo()));
      expect(find.byType(AnTags), findsNothing); // no pills, no add field — just the em-dash
      expect(find.text('—'), findsAtLeastNWidgets(1)); // the tags row (venv KV also em-dashes empties)
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
