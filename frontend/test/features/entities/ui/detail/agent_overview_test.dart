import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_kv.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/features/entities/ui/detail/overview/agent_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-077 ⑫ — the agent overview's capability cards (tools/skill/knowledge/model) used to drop an
// inbox-icon tombstone ([AnState]) into the card body for "nothing here"; they now stay on the
// SAME AnKv/AnRow grammar as their populated siblings (a single dash row), and a no-active-version
// agent gets the shared "create first version" guide instead of the old blunt tombstone.

final _t = DateTime.utc(2026, 7, 25);

AgentVersion _v({ModelRef? modelOverride}) => AgentVersion(
  id: 'ag_1_v1',
  agentId: 'ag_1',
  version: 1,
  prompt: 'You are a helpful assistant.',
  modelOverride: modelOverride,
  createdAt: _t,
  updatedAt: _t,
);

AgentEntity _agent({ModelRef? modelOverride}) => AgentEntity(
  id: 'ag_1',
  name: 'researcher',
  description: 'Answers questions',
  activeVersionId: 'ag_1_v1',
  activeVersion: _v(modelOverride: modelOverride),
  createdAt: _t,
  updatedAt: _t,
);

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 720, child: child)),
    ),
  ),
);

void main() {
  testWidgets('no active version → the shared "create first version" guide, not the '
      'inbox-icon tombstone', (tester) async {
    // `_agent(activeVersion: null)` would collapse right back through the `??` default (Dart
    // can't tell "explicitly null" from "omitted" there) — copyWith is the honest way to force
    // a null activeVersion, same idiom as the sibling control/approval overview tests.
    final agent = _agent().copyWith(activeVersion: null);
    await tester.pumpWidget(
      _host(AgentOverview(agent: agent, mountHealth: null)),
    );
    await tester.pump();
    final d = TranslationProvider.of(
      tester.element(find.byType(AgentOverview)),
    ).translations.entities.detail;
    expect(find.byType(AnState), findsOneWidget); // one guide block
    expect(find.text(d.state.createFirstVersion), findsOneWidget);
    expect(find.text(d.state.createFirstVersionHint), findsOneWidget);
  });

  testWidgets(
    'empty tools/skill/knowledge render as a dash row — never the inbox-icon '
    'tombstone',
    (tester) async {
      await tester.pumpWidget(
        _host(AgentOverview(agent: _agent(), mountHealth: null)),
      );
      await tester.pump();
      // The tombstone (AnState) is gone entirely once there's an active version — every card
      // (populated or empty) stays on AnKv/AnRow.
      expect(find.byType(AnState), findsNothing);
    },
  );

  testWidgets(
    'model override == null renders as an INHERITED KV row (meta tier), not '
    'a tombstone',
    (tester) async {
      await tester.pumpWidget(
        _host(AgentOverview(agent: _agent(), mountHealth: null)),
      );
      await tester.pump();
      final d = TranslationProvider.of(
        tester.element(find.byType(AgentOverview)),
      ).translations.entities.detail;
      // Same "Model: value" row as a real override — just reading "Workspace default".
      expect(find.text(d.kv.model), findsOneWidget);
      expect(find.text(d.val.modelDefault), findsOneWidget);
      expect(find.byType(AnState), findsNothing);

      // It carries the WEAK "inherited" cue: meta:true rides the existing chrome-13 value tier
      // (no new primitive invented for this).
      final modelRow = tester
          .widgetList<AnKv>(find.byType(AnKv))
          .expand((kv) => kv.rows)
          .firstWhere((r) => r.label == d.kv.model);
      expect(modelRow.meta, isTrue);
    },
  );

  testWidgets('model override present renders modelId + options, WITHOUT the '
      'inherited meta tier', (tester) async {
    const mo = ModelRef(
      apiKeyId: 'key_1',
      modelId: 'claude-sonnet',
      options: {'temperature': '0.2'},
    );
    await tester.pumpWidget(
      _host(AgentOverview(agent: _agent(modelOverride: mo), mountHealth: null)),
    );
    await tester.pump();
    final d = TranslationProvider.of(
      tester.element(find.byType(AgentOverview)),
    ).translations.entities.detail;
    expect(find.text('claude-sonnet'), findsOneWidget);
    expect(find.text('temperature'), findsOneWidget);
    final modelRow = tester
        .widgetList<AnKv>(find.byType(AnKv))
        .expand((kv) => kv.rows)
        .firstWhere((r) => r.label == d.kv.model);
    expect(modelRow.meta, isFalse);
  });
}
