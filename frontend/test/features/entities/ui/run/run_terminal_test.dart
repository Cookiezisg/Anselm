import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/core/ui/an_term_viewport.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/run/block_tree_view.dart';
import 'package:anselm/features/entities/ui/run/run_editor_card.dart';
import 'package:anselm/features/entities/ui/run/run_terminal.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/router_harness.dart';

// STEP 5.5/6 gate (widget) — the run terminal is bound to the SELECTED entity (route-driven, STEP 6):
// idle shows the typed input form + idle state; pressing the verb runs and renders the streamed output +
// result; the agent trace renders reasoning collapsed-by-default + a danger badge.

final _t0 = DateTime.utc(2026, 6, 27);

FixtureEntityRepository _fix() => FixtureEntityRepository(
      runDelay: Duration.zero,
      functions: [
        FunctionEntity(
          id: 'fn_1',
          name: 'normalize',
          createdAt: _t0,
          updatedAt: _t0,
          activeVersionId: 'fn_1_v1',
          activeVersion: FunctionVersion(
            id: 'fn_1_v1',
            functionId: 'fn_1',
            version: 1,
            inputs: const [Field(name: 'text', type: 'string', description: 'raw input')],
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ),
      ],
      agents: [
        AgentEntity(
          id: 'ag_1',
          name: 'researcher',
          createdAt: _t0,
          updatedAt: _t0,
          activeVersionId: 'ag_1_v1',
          activeVersion: AgentVersion(
            id: 'ag_1_v1',
            agentId: 'ag_1',
            version: 1,
            inputs: const [Field(name: 'topic', type: 'string')],
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ),
      ],
    );

Widget _host(FixtureEntityRepository repo, {EntityRef? sel, Widget child = const RunTerminal()}) =>
    routedHost(
      Scaffold(body: SizedBox(width: 340, height: 800, child: child)),
      initialLocation: sel == null ? '/' : selectionLocation(sel.kind, sel.id),
      repository: repo,
    );

void main() {
  final r = t.entities.run;

  testWidgets('function idle → JSON editor card prefilled, ZERO tombstone (零墓碑)', (tester) async {
    await tester.pumpWidget(_host(_fix(), sel: const EntityRef(EntityKind.function, 'fn_1')));
    await tester.pump(const Duration(milliseconds: 50)); // detail load
    expect(find.byType(RunEditorCard), findsOneWidget); // the JSON-first input card
    expect(find.byType(AnCodeEditor), findsOneWidget); // one prefilled JSON editor 预填 JSON 编辑器
    expect(find.byType(AnState), findsNothing); // never-ran = air, not a tombstone 没跑过=空气
    expect(tester.takeException(), isNull);
  });

  testWidgets('run function → ok, streamed output + result', (tester) async {
    await tester.pumpWidget(_host(_fix(), sel: const EntityRef(EntityKind.function, 'fn_1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(AnButton, t.entities.detail.verb.run));
    await tester.pumpAndSettle();
    expect(find.text(r.resultHeading), findsOneWidget);
    expect(find.textContaining('done'), findsWidgets); // live stderr from the run node
    expect(find.text(t.status.done), findsOneWidget); // ok badge
  });

  testWidgets('fn RUNNING streams through the bounded scrollback terminal — same component settled (批1)',
      (tester) async {
    final repo = FixtureEntityRepository(
      runDelay: const Duration(milliseconds: 200),
      functions: [
        FunctionEntity(
          id: 'fn_1',
          name: 'normalize',
          createdAt: _t0,
          updatedAt: _t0,
          activeVersionId: 'fn_1_v1',
          activeVersion: FunctionVersion(
            id: 'fn_1_v1',
            functionId: 'fn_1',
            version: 1,
            inputs: const [Field(name: 'text', type: 'string', description: 'raw input')],
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ),
      ],
    );
    await tester.pumpWidget(_host(repo, sel: const EntityRef(EntityKind.function, 'fn_1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(AnButton, t.entities.detail.verb.run));
    // Fixture cadence: delay→open→(delay→delta)×3→delay→close (200ms steps) — land mid-deltas.
    // fixture 节奏 200ms 一步,落在 delta 中段。
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(AnTermViewport), findsOneWidget); // scroll-back survives mid-run 运行中可回看
    // Really still running — the head phase badge retired (三段式文法, WRK-073 批 3: pure-identity
    // AnPanelHead), so the running signal is now the verb CTA flipping to «取消/Cancel». 头徽退役,
    // 运行信号=动词钮翻成「取消」。
    expect(find.widgetWithText(AnButton, t.entities.run.cancel), findsOneWidget);
    // Walk the remaining fixture steps (pumpAndSettle stops on idle frames, not pending timers).
    // 逐步走完剩余节奏(pumpAndSettle 不等挂起的 timer)。
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();
    expect(find.byType(AnTermViewport), findsOneWidget); // settled = SAME component, no material flip 落定同件零换脸
    expect(find.text(t.status.done), findsOneWidget);
  });

  testWidgets('agent invoke → ReAct trace with the tool name', (tester) async {
    await tester.pumpWidget(_host(_fix(), sel: const EntityRef(EntityKind.agent, 'ag_1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(AnButton, t.entities.detail.verb.invoke));
    await tester.pumpAndSettle();
    expect(find.text(r.traceHeading), findsOneWidget);
    expect(find.text('web-search'), findsWidgets); // tool_call name
  });

  testWidgets('block tree: reasoning collapsed by default, danger badge on a dangerous tool_call', (tester) async {
    const scope = StreamScope(kind: 'agent', id: 'a');
    final reducer = BlockTreeReducer()
      ..apply(const StreamEnvelope(seq: 1, scope: scope, id: 'b1', frame: FrameOpen(node: StreamNode(type: 'reasoning'))))
      ..apply(StreamEnvelope(seq: 2, scope: scope, id: 'b1', frame: FrameClose(status: 'completed', result: const StreamNode(type: 'reasoning', content: {'content': 'secret thought'}))))
      ..apply(const StreamEnvelope(seq: 1, scope: scope, id: 'b2', frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'rm'}))))
      ..apply(StreamEnvelope(seq: 2, scope: scope, id: 'b2', frame: FrameClose(status: 'completed', result: const StreamNode(type: 'tool_call', content: {'name': 'rm', 'arguments': '{}', 'danger': 'dangerous'}))));

    await tester.pumpWidget(_host(_fix(), child: SingleChildScrollView(child: BlockTreeView(roots: reducer.roots))));
    await tester.pump();
    expect(find.text('rm'), findsOneWidget); // tool name
    expect(find.text(r.danger.dangerous), findsOneWidget); // danger badge (header, always visible)
    expect(find.text('secret thought'), findsNothing); // reasoning collapsed by default

    await tester.tap(find.text(r.reasoning)); // expand the reasoning disclosure
    await tester.pumpAndSettle();
    expect(find.text('secret thought'), findsOneWidget);
  });
}
