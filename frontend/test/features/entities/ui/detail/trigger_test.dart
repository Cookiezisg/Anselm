import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_row.dart';
import 'package:anselm/features/entities/state/detail/entity_detail.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/detail/ocean_header.dart';
import 'package:anselm/features/entities/ui/detail/overview/trigger_overview.dart';
import 'package:anselm/features/entities/ui/detail/trigger_observability_tab.dart';
import 'package:anselm/features/entities/ui/entity_rail_model.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t = DateTime.utc(2026, 7, 4, 9);

TriggerEntity _trigger({
  required TriggerSource kind,
  Map<String, dynamic> config = const {},
  List<Field> outputs = const [],
  bool listening = true,
  int refCount = 1,
  DateTime? lastFired,
  DateTime? nextFire,
}) => TriggerEntity(
  id: 'trg_1',
  name: 'my-trigger',
  description: 'A demo trigger.',
  kind: kind,
  config: config,
  outputs: outputs,
  listening: listening,
  refCount: refCount,
  lastFiredAt: lastFired,
  nextFireAt: nextFire,
  createdAt: _t,
  updatedAt: _t,
);

Widget _wrap(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SizedBox(width: 720, child: SingleChildScrollView(child: child)),
    ),
  ),
);

Widget _hostProvider(FixtureEntityRepository repo, Widget child) =>
    ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      child: _wrap(child),
    );

void main() {
  group('TriggerOverview', () {
    testWidgets('cron: expression headline (only) + runtime + fire payload', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TriggerOverview(
            trigger: _trigger(
              kind: TriggerSource.cron,
              config: const {
                'expression': '0 9 * * *',
              }, // cron reads nothing else (config.go:56)
              outputs: const [Field(name: 'firedAt', type: 'string')],
              lastFired: _t,
              nextFire: _t.add(const Duration(hours: 18)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('0 9 * * *'),
        findsOneWidget,
      ); // the copyable headline spec
      expect(find.text('firedAt'), findsOneWidget); // fire payload field
      final r = t.entities.detail.trigger;
      expect(find.text(r.listening), findsWidgets); // runtime section label
      expect(find.text(r.nextFire), findsOneWidget); // cron-only next-fire row
    });

    testWidgets('webhook: renders the mounted URL as the headline (copyable)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TriggerOverview(
            trigger: _trigger(
              kind: TriggerSource.webhook,
              config: const {'path': 'gh/push'},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('/api/v1/webhooks/trg_1/gh/push'), findsOneWidget);
    });

    testWidgets(
      'sensor: condition headline + target/interval; no next-fire (non-cron)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TriggerOverview(
              trigger: _trigger(
                kind: TriggerSource.sensor,
                config: const {
                  'targetKind': 'handler',
                  'targetId': 'hd_q',
                  'method': 'depth',
                  'intervalSec': 30,
                  'condition': 'output.depth > 100',
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('output.depth > 100'), findsOneWidget);
        expect(find.text('30s'), findsOneWidget);
        expect(
          find.text(t.entities.detail.trigger.nextFire),
          findsNothing,
        ); // cron-only
      },
    );
  });

  group('EntityOceanHeader (trigger)', () {
    EntityDetail detail() => EntityDetail(
      ref: const EntityRef(EntityKind.trigger, 'trg_1'),
      trigger: _trigger(
        kind: TriggerSource.cron,
        config: const {'expression': '* * * * *'},
      ),
    );

    testWidgets('shows a Fire CTA, not a run verb CTA', (tester) async {
      await tester.pumpWidget(
        _wrap(EntityOceanHeader(detail: detail(), onFire: () {})),
      );
      await tester.pump();
      expect(find.text(t.entities.detail.trigger.fire), findsOneWidget);
      // No run/call/invoke/trigger verb BUTTON (support kind, not executable) — scoped to AnButton so the
      // «Entities / Trigger» crumb's kind segment (a plain Text = the same word) isn't mistaken for the
      // retired CTA. 无运行动词按钮;限定 AnButton,免与面包屑 kind 段(同词纯文本)混淆。
      expect(
        find.widgetWithText(AnButton, t.entities.detail.verb.trigger),
        findsNothing,
      );
    });

    testWidgets('tapping Fire invokes onFire', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(EntityOceanHeader(detail: detail(), onFire: () => fired = true)),
      );
      await tester.pump();
      await tester.tap(find.text(t.entities.detail.trigger.fire));
      expect(fired, isTrue);
    });
  });

  group('observability tabs', () {
    FixtureEntityRepository repo() => FixtureEntityRepository(
      activations: {
        'trg_1': [
          Activation(
            id: 'tra_2',
            triggerId: 'trg_1',
            kind: TriggerSource.sensor,
            fired: true,
            firingCount: 1,
            createdAt: _t,
          ),
          Activation(
            id: 'tra_1',
            triggerId: 'trg_1',
            kind: TriggerSource.sensor,
            fired: false,
            detail: 'condition false',
            createdAt: _t,
          ),
        ],
      },
      firings: {
        'trg_1': [
          Firing(
            id: 'trf_1',
            triggerId: 'trg_1',
            workflowId: 'wf_x',
            activationId: 'tra_2',
            status: FiringStatus.started,
            flowrunId: 'flr_1',
            createdAt: _t,
            updatedAt: _t,
          ),
        ],
      },
    );

    testWidgets('activity tab lists activations; fired-only filter narrows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _hostProvider(repo(), const TriggerActivityTab('trg_1')),
      );
      await tester.pump();
      await tester.pump();
      final r = t.entities.detail.trigger;
      expect(find.textContaining(r.fired), findsWidgets);
      expect(
        find.textContaining(r.notFired),
        findsOneWidget,
      ); // the non-fired probe row
      // Flip to fired-only → the non-fired probe drops.
      await tester.tap(find.text(r.allActivity));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r.firedOnly).last);
      await tester.pumpAndSettle();
      expect(find.textContaining(r.notFired), findsNothing);
    });

    testWidgets('dispatch tab lists firings', (tester) async {
      await tester.pumpWidget(
        _hostProvider(repo(), const TriggerDispatchTab('trg_1')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining(FiringStatus.started.name), findsWidgets);
      expect(find.textContaining('wf_x'), findsOneWidget);
    });

    testWidgets('empty activity shows the inset empty state', (tester) async {
      await tester.pumpWidget(
        _hostProvider(
          FixtureEntityRepository(),
          const TriggerActivityTab('trg_none'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(t.entities.detail.state.noActivations), findsOneWidget);
      expect(find.byType(AnState), findsOneWidget);
    });
  });

  group('railDot', () {
    EntityRow row({required bool listening}) => EntityRow(
      kind: EntityKind.trigger,
      id: 'trg_1',
      listening: listening,
      createdAt: _t,
      updatedAt: _t,
    );

    test('a hot listener → an accent (run) dot; idle → no dot', () {
      expect(railDot(row(listening: true)), AnStatus.run);
      expect(railDot(row(listening: false)), isNull);
    });
  });
}
