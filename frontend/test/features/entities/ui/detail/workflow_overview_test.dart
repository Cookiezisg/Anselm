import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_field.dart';
import 'package:anselm/core/ui/an_graph_canvas.dart';
import 'package:anselm/core/ui/an_tags.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_format.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/core/graph/graph_run_state.dart';
import 'package:anselm/features/entities/state/run/run_terminal_controller.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/detail/overview/workflow_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 W2 gate — the workflow overview: graph hero FIRST (framed canvas), meta via the mature
// AnKv edit path → patchWorkflowMeta, governance/alerts intact; plus the graph-structural version
// summary + the fixture write plane.

final _t = DateTime.utc(2026, 7, 3);

const _graphV2 =
    '{"nodes":[{"id":"on_schedule","kind":"trigger","ref":"tr_cron"},{"id":"research","kind":"agent","ref":"ag_researcher"},{"id":"gate","kind":"control","ref":"ctl_quality"},{"id":"post","kind":"action","ref":"hd_slack.post"}],"edges":[{"id":"e1","from":"on_schedule","to":"research"},{"id":"e2","from":"research","to":"gate"},{"id":"e3","from":"gate","fromPort":"pass","to":"post"},{"id":"e4","from":"gate","fromPort":"retry","to":"research"}]}';
const _graphV1 =
    '{"nodes":[{"id":"on_schedule","kind":"trigger","ref":"tr_cron"},{"id":"research","kind":"agent","ref":"ag_old"},{"id":"post","kind":"action","ref":"hd_slack.post"}],"edges":[{"id":"e1","from":"on_schedule","to":"research"},{"id":"e2","from":"research","to":"post"}]}';

WorkflowVersion _v(int version, String graph) => WorkflowVersion(
    id: 'wf_1_v$version',
    workflowId: 'wf_1',
    version: version,
    graph: graph,
    createdAt: _t,
    updatedAt: _t);

WorkflowEntity _wf({String graph = _graphV2, List<String> tags = const ['daily']}) =>
    WorkflowEntity(
        id: 'wf_1',
        name: 'daily-digest',
        description: 'Summarize each morning',
        tags: tags,
        active: true,
        lifecycleState: 'active',
        concurrency: 'serial',
        activeVersionId: 'wf_1_v2',
        activeVersion: _v(2, graph),
        createdAt: _t,
        updatedAt: _t);

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
  group('workflow overview (W2)', () {
    testWidgets('graph hero renders FIRST as a framed canvas with node cards', (tester) async {
      final repo = FixtureEntityRepository(workflows: [_wf()]);
      await tester.pumpWidget(_host(WorkflowOverview(wf: _wf()), repo));
      await tester.pump();
      final canvas = find.byType(AnGraphCanvas);
      expect(canvas, findsOneWidget);
      // Hero sits above the meta rows. hero 在 meta 之上。
      expect(tester.getTopLeft(canvas).dy, lessThan(tester.getTopLeft(find.byType(AnKv).first).dy));
      expect(find.text('research'), findsOneWidget); // node card id
      expect(find.text('retry'), findsOneWidget); // back-edge port pill
      // No enter-editor affordance until the W5 route exists. W5 前无「进入编辑器」。
      expect(find.text(TranslationProvider.of(tester.element(canvas)).translations
          .entities.detail.graph.openEditor), findsNothing);
    });

    testWidgets('meta: description pencil-edit PATCHes workflow meta (no version bump)',
        (tester) async {
      final repo = FixtureEntityRepository(workflows: [_wf()]);
      await tester.pumpWidget(_host(WorkflowOverview(wf: _wf()), repo));
      await tester.pump();
      // The description row is the ONLY pencil row. 说明行是唯一铅笔行。
      await tester.tap(find.byIcon(AnIcons.edit));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'A better description');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect((await repo.getWorkflow('wf_1')).description, 'A better description');
      expect((await repo.getWorkflow('wf_1')).activeVersion!.version, 2); // no bump 不升版
    });

    testWidgets('meta: tags row edits via ➕/✕ and PATCHes tags', (tester) async {
      final repo = FixtureEntityRepository(workflows: [_wf(tags: const ['daily', 'ops'])]);
      await tester.pumpWidget(_host(WorkflowOverview(wf: _wf(tags: const ['daily', 'ops'])), repo));
      await tester.pump();
      expect(find.byType(AnTags), findsOneWidget);
      // Hover the tags row → ✕ per pill appears; remove 'ops'. 悬停出 ✕,删 ops。
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('ops')));
      await tester.pump();
      final removes = find.bySemanticsLabel(RegExp('Remove'));
      expect(removes, findsWidgets);
      await tester.tap(removes.last);
      await tester.pump();
      expect((await repo.getWorkflow('wf_1')).tags, ['daily']);
      await gesture.removePointer();
    });

    testWidgets('hero lights up from the SAME run state the right island drives (W3)',
        (tester) async {
      final repo = FixtureEntityRepository(workflows: [_wf()], runDelay: Duration.zero);
      await tester.pumpWidget(_host(WorkflowOverview(wf: _wf()), repo));
      await tester.pump();
      // Definition view first — no overlay. 未跑=纯定义。
      expect(tester.widget<AnGraphCanvas>(find.byType(AnGraphCanvas)).run, isNull);

      final container = ProviderScope.containerOf(tester.element(find.byType(WorkflowOverview)));
      const ref = EntityRef(EntityKind.workflow, 'wf_1');
      container.read(runTerminalProvider(ref).notifier).run();
      await tester.pump(); // trigger returns, walk scheduled
      await tester.pump(); // ticks land
      await tester.pump(const Duration(milliseconds: 400)); // reconcile lands truth rows
      final overlay = tester.widget<AnGraphCanvas>(find.byType(AnGraphCanvas)).run;
      expect(overlay, isNotNull);
      expect(overlay!.nodes['research'], GraphNodeRun.completed);
      // The control recorded __port=pass → the pass edge is taken, retry is not. pass 亮、retry 不亮。
      expect(overlay.takenEdges.contains('e3'), isTrue);
      expect(overlay.takenEdges.contains('e4'), isFalse);
    });

    testWidgets('unparseable graph blob → honest inset, not a blank hero', (tester) async {
      final wf = _wf(graph: '{nodes: broken');
      final repo = FixtureEntityRepository(workflows: [wf]);
      await tester.pumpWidget(_host(WorkflowOverview(wf: wf), repo));
      await tester.pump();
      expect(find.byType(AnGraphCanvas), findsNothing);
      expect(find.text('Orchestration graph unparseable'), findsOneWidget);
    });
  });

  group('workflowVersionSummary (pure)', () {
    test('nodes by id, edges by endpoints+port', () {
      final chips = workflowVersionSummary(_v(2, _graphV2), _v(1, _graphV1));
      expect(chips, containsAll(<String>[
        '+ node gate',
        'node research: ag_old→ag_researcher',
        '+ edge gate→post (pass)',
        '+ edge gate→research (retry)',
        '+ edge research→gate',
        '− edge research→post',
      ]));
      expect(chips.where((c) => c.startsWith('− node')), isEmpty);
    });

    test('identical graphs → no chips; unparseable side → no chips', () {
      expect(workflowVersionSummary(_v(2, _graphV2), _v(1, _graphV2)), isEmpty);
      expect(workflowVersionSummary(_v(2, 'broken{'), _v(1, _graphV1)), isEmpty);
    });

    test('prettyJsonSource pretty-prints valid JSON, passes garbage through', () {
      expect(prettyJsonSource('{"a":1}'), '{\n  "a": 1\n}');
      expect(prettyJsonSource('not json'), 'not json');
    });
  });

  group('fixture write plane', () {
    test('patchWorkflowMeta mutates seeds + emits a durable lifecycle signal', () async {
      final repo = FixtureEntityRepository(workflows: [_wf()]);
      final signals = repo.lifecycleSignals(EntityKind.workflow).take(1).toList();
      final next = await repo
          .patchWorkflowMeta('wf_1', {'name': 'renamed', 'tags': <String>['x']});
      expect(next.name, 'renamed');
      expect(next.tags, ['x']);
      expect((await repo.getWorkflow('wf_1')).name, 'renamed');
      final got = await signals;
      expect(got.single.durable, isTrue);
    });
  });
}
