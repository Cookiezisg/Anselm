import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:anselm/core/ui/icons.dart';
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

AgentVersion _v({
  ModelRef? modelOverride,
  List<ToolRef> tools = const [],
  List<String> knowledge = const [],
}) => AgentVersion(
  id: 'ag_1_v1',
  agentId: 'ag_1',
  version: 1,
  prompt: 'You are a helpful assistant.',
  modelOverride: modelOverride,
  tools: tools,
  knowledge: knowledge,
  createdAt: _t,
  updatedAt: _t,
);

AgentEntity _agent({
  ModelRef? modelOverride,
  List<ToolRef> tools = const [],
  List<String> knowledge = const [],
  String description = 'Answers questions',
  List<String> tags = const [],
}) => AgentEntity(
  id: 'ag_1',
  name: 'researcher',
  description: description,
  tags: tags,
  activeVersionId: 'ag_1_v1',
  activeVersion: _v(
    modelOverride: modelOverride,
    tools: tools,
    knowledge: knowledge,
  ),
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

  testWidgets(
    'healthy knowledge mounts show the document title and retain the ID as metadata',
    (tester) async {
      const docID = 'doc_0011223344556677';
      await tester.pumpWidget(
        _host(
          AgentOverview(
            agent: _agent(knowledge: const [docID]),
            mountHealth: const MountHealthReport(
              mounts: [
                MountHealth(ref: docID, name: 'Research notes', healthy: true),
              ],
              allHealthy: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final namedRows = tester
          .widgetList<AnRow>(find.byType(AnRow))
          .where((row) => row.label == 'Research notes')
          .toList();
      expect(namedRows, hasLength(2));
      expect(namedRows.every((row) => row.meta == docID), isTrue);
    },
  );

  testWidgets('agent metadata uses the editable description and tags grammar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AgentOverview(
          agent: _agent(tags: const ['research', 'daily']),
          mountHealth: null,
        ),
      ),
    );
    await tester.pump();

    final d = TranslationProvider.of(
      tester.element(find.byType(AgentOverview)),
    ).translations.entities.detail;
    final meta = tester
        .widgetList<AnKv>(find.byType(AnKv))
        .firstWhere((kv) => kv.rows.any((row) => row.label == d.kv.desc));
    final description = meta.rows.firstWhere((row) => row.label == d.kv.desc);
    final tags = meta.rows.firstWhere((row) => row.label == d.kv.tags);
    expect(description.editable, isTrue);
    expect(tags.tags, const ['research', 'daily']);
    expect(find.text('research'), findsOneWidget);
    expect(find.text('daily'), findsOneWidget);
  });

  testWidgets(
    'each mount scheme reads as itself — a sys: capability tool is not a plain tool row',
    (tester) async {
      // The four BOUND-TOOL schemes the backend's mount resolver knows. `sys:` is the one whose
      // target is not a user entity (WRK-082 P14): rendering it with the generic tool glyph hides
      // that this agent can produce media, which is the single most consequential thing to know
      // when reading an agent's mounts. 四种绑定工具词法;`sys:` 是目标非用户实体的那一种,渲成通用
      // tool 字形会藏起「这个 agent 能产媒体」——而这恰是读一个 agent 挂载时最要紧的一条。
      await tester.pumpWidget(
        _host(
          AgentOverview(
            agent: _agent(
              tools: const [
                ToolRef(ref: 'fn_00112233445566aa', name: 'tally'),
                ToolRef(ref: 'hd_00112233445566bb.hello', name: 'greeter'),
                ToolRef(ref: 'mcp:srv/echo', name: 'echo'),
                ToolRef(ref: 'sys:generate_image', name: 'generate image'),
              ],
            ),
            mountHealth: null,
          ),
        ),
      );
      await tester.pump();
      IconData? glyphOf(String label) => tester
          .widgetList<AnRow>(find.byType(AnRow))
          .firstWhere((r) => r.label == label)
          .icon;
      expect(glyphOf('tally'), AnIcons.byKey('function'));
      expect(glyphOf('greeter'), AnIcons.byKey('handler'));
      expect(glyphOf('echo'), AnIcons.byKey('mcp'));
      expect(glyphOf('generate image'), AnIcons.byKey('capability'));
      expect(glyphOf('generate image'), isNot(AnIcons.byKey('tool')));
    },
  );
}
