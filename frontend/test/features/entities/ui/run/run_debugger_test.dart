import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_dropdown.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/core/ui/an_ledger_row.dart';
import 'package:anselm/core/ui/an_switch.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/run/recent_runs_provider.dart';
import 'package:anselm/features/entities/state/run/run_draft_store.dart';
import 'package:anselm/features/entities/state/run/run_terminal_controller.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/run/run_terminal.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/router_harness.dart';

// The debugger's three laws (0718 拍板) under widget test: the form mirrors the entity contract
// (type-aware fields / method wheel / source picker with per-kind payload templates), values live in
// per-dimension session buckets, and the recent strip + reproduce key close the loop.

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
            inputs: const [
              Field(name: 'text', type: 'string', description: 'raw input'),
              Field(name: 'limit', type: 'number'),
              Field(name: 'strict', type: 'boolean'),
              Field(name: 'options', type: 'object'),
            ],
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ),
      ],
      handlers: [
        HandlerEntity(
          id: 'hd_1',
          name: 'mailer',
          createdAt: _t0,
          updatedAt: _t0,
          activeVersionId: 'hd_1_v1',
          activeVersion: HandlerVersion(
            id: 'hd_1_v1',
            handlerId: 'hd_1',
            version: 1,
            methods: const [
              MethodSpec(name: 'send', inputs: [Field(name: 'to', type: 'string')]),
              MethodSpec(name: 'archive', inputs: [Field(name: 'days', type: 'number')]),
            ],
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ),
      ],
      workflows: [
        WorkflowEntity(id: 'wf_1', name: 'pipeline', createdAt: _t0, updatedAt: _t0),
      ],
      triggerEntities: [
        TriggerEntity(id: 'tr_cron', name: 'nightly', kind: TriggerSource.cron, createdAt: _t0, updatedAt: _t0),
        TriggerEntity(id: 'tr_hook', name: 'stripe-hook', kind: TriggerSource.webhook, createdAt: _t0, updatedAt: _t0),
        TriggerEntity(id: 'tr_fs', name: 'watch-inbox', kind: TriggerSource.fsnotify, createdAt: _t0, updatedAt: _t0),
      ],
      relGraph: const EntityRelGraph(
        nodes: [
          EntityNode(kind: 'workflow', id: 'wf_1', name: 'pipeline'),
          EntityNode(kind: 'trigger', id: 'tr_cron', name: 'nightly'),
          EntityNode(kind: 'trigger', id: 'tr_hook', name: 'stripe-hook'),
          EntityNode(kind: 'trigger', id: 'tr_fs', name: 'watch-inbox'),
        ],
        edges: [
          EntityRelation(id: 'rel_1', kind: 'equip', fromKind: 'workflow', fromId: 'wf_1', toKind: 'trigger', toId: 'tr_cron', toName: 'nightly'),
          EntityRelation(id: 'rel_2', kind: 'equip', fromKind: 'workflow', fromId: 'wf_1', toKind: 'trigger', toId: 'tr_hook', toName: 'stripe-hook'),
          EntityRelation(id: 'rel_3', kind: 'equip', fromKind: 'workflow', fromId: 'wf_1', toKind: 'trigger', toId: 'tr_fs', toName: 'watch-inbox'),
        ],
      ),
      functionExecutions: {
        'fn_1': [
          for (var i = 0; i < 7; i++)
            FunctionExecution(
              id: 'fx_$i',
              functionId: 'fn_1',
              status: i == 0 ? 'failed' : 'ok',
              triggeredBy: 'manual',
              input: {'text': 'run-$i', 'strict': true},
              elapsedMs: 120 + i,
              startedAt: _t0.add(Duration(minutes: i)),
              createdAt: _t0.add(Duration(minutes: i)),
            ),
        ],
      },
      handlerCalls: {
        'hd_1': [
          HandlerCall(
            id: 'hc_1',
            handlerId: 'hd_1',
            method: 'archive',
            status: 'ok',
            triggeredBy: 'manual',
            input: const {'days': 30},
            elapsedMs: 40,
            startedAt: _t0,
            createdAt: _t0,
          ),
        ],
      },
    );

Widget _host(FixtureEntityRepository repo, EntityRef sel) => routedHost(
      Scaffold(body: SizedBox(width: 340, height: 900, child: const RunTerminal())),
      initialLocation: selectionLocation(sel.kind, sel.id),
      repository: repo,
    );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(RunTerminal)));

void main() {
  final r = t.entities.run;

  testWidgets('fn form is the contract mirror: switch for bool, mono JSON area for object, description as placeholder',
      (tester) async {
    await tester.pumpWidget(_host(_fix(), const EntityRef(EntityKind.function, 'fn_1')));
    await tester.pump(const Duration(milliseconds: 50));
    // Every declared input renders under its own name. 逐参数按名渲染。
    for (final name in ['text', 'limit', 'strict', 'options']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.byType(AnSwitch), findsOneWidget); // boolean wears a switch 布尔=开关
    final inputs = tester.widgetList<AnInput>(find.byType(AnInput)).toList();
    expect(inputs.where((w) => w.multiline && w.mono), isNotEmpty); // object → mono JSON area
    expect(inputs.map((w) => w.placeholder), contains('raw input')); // description IS the placeholder
    // No Idle capsule anywhere (状态只在跑中/失败在场). Idle 胶囊死了。
    expect(find.byType(AnChip), findsNothing);
  });

  testWidgets('hd: the method wheel regenerates the fields; drafts are remembered PER METHOD', (tester) async {
    await tester.pumpWidget(_host(_fix(), const EntityRef(EntityKind.handler, 'hd_1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(); // post-frame default method
    expect(find.byType(AnDropdown<String>), findsOneWidget); // the wheel 方向盘
    expect(find.text('to'), findsOneWidget); // first method's field
    expect(find.text('days'), findsNothing);

    final c = _container(tester);
    const ref = EntityRef(EntityKind.handler, 'hd_1');
    final ctrl = c.read(runTerminalProvider(ref).notifier);
    ctrl.setField('to', 'ops@x.dev'); // type into the send bucket 往 send 桶打字
    ctrl.setMethod('archive');
    await tester.pump();
    expect(find.text('days'), findsOneWidget); // fields regenerated wholesale 整体重生成
    expect(find.text('to'), findsNothing);

    // Switching back restores the exact draft (session bucket per method). 切回原样。
    ctrl.setMethod('send');
    await tester.pump();
    final store = c.read(runDraftStoreProvider);
    expect(store.bucket(runDraftKey(ref, 'send'))['to'], 'ops@x.dev');
    expect(store.bucket(runDraftKey(ref, 'archive')), isEmpty);
  });

  testWidgets('wf source picker lists mounted triggers + manual; cron renders NO payload at all', (tester) async {
    await tester.pumpWidget(_host(_fix(), const EntityRef(EntityKind.workflow, 'wf_1')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AnDropdown<String>), findsOneWidget); // the source picker 来源选择器
    // manual (default) → one JSON payload area. 手动=单 JSON 框。
    expect(find.text(r.payload), findsOneWidget);

    final c = _container(tester);
    const ref = EntityRef(EntityKind.workflow, 'wf_1');
    final ctrl = c.read(runTerminalProvider(ref).notifier);

    ctrl.setSource('tr_cron');
    await tester.pump(const Duration(milliseconds: 50)); // trigger detail load
    await tester.pump();
    expect(find.text(r.payload), findsNothing); // cron releases nothing — form honestly renders nothing
    expect(find.byType(AnInput), findsNothing);

    ctrl.setSource('tr_fs');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('path'), findsOneWidget); // fsnotify template 模板字段
    expect(find.text('event'), findsOneWidget);

    ctrl.setSource('tr_hook');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text(r.payload), findsOneWidget); // webhook = request body JSON
    expect(find.text(r.webhookBody), findsOneWidget);
  });

  testWidgets('recent strip: top-5 ledger rows render idle; a row expands to its IO', (tester) async {
    await tester.pumpWidget(_host(_fix(), const EntityRef(EntityKind.function, 'fn_1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50)); // recent runs load
    expect(find.text(r.recent), findsOneWidget);
    expect(find.byType(AnLedgerRow), findsNWidgets(5)); // seeded 7 → strip caps at 5 只留五
    await tester.tap(find.byType(AnLedgerRow).first);
    await tester.pumpAndSettle();
    expect(find.text(r.inputHeading), findsOneWidget);
    expect(find.textContaining('run-0'), findsOneWidget); // that execution's raw input 原始输入
  });

  testWidgets('reproduce fills the draft from a past execution (method restored for hd)', (tester) async {
    await tester.pumpWidget(_host(_fix(), const EntityRef(EntityKind.handler, 'hd_1')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    final c = _container(tester);
    const ref = EntityRef(EntityKind.handler, 'hd_1');
    final ctrl = c.read(runTerminalProvider(ref).notifier);

    ctrl.reproduce(const RecentRun(
        id: 'hc_1', status: 'ok', method: 'archive', input: {'days': 30}, triggeredBy: 'manual'));
    await tester.pump();

    expect(c.read(runTerminalProvider(ref)).method, 'archive'); // the wheel followed 方向盘跟随
    final store = c.read(runDraftStoreProvider);
    expect(store.bucket(runDraftKey(ref, 'archive'))['days'], '30'); // number lands as editable text
    expect(find.text('days'), findsOneWidget); // fields regenerated for the restored method
  });

  testWidgets('recent strip stays SILENT when there is no ledger (no tombstone, no section)', (tester) async {
    final repo = FixtureEntityRepository(
      runDelay: Duration.zero,
      functions: [
        FunctionEntity(id: 'fn_2', name: 'bare', createdAt: _t0, updatedAt: _t0),
      ],
    );
    await tester.pumpWidget(_host(repo, const EntityRef(EntityKind.function, 'fn_2')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(r.recent), findsNothing); // empty ledger = air 空账=空气
    expect(find.byType(AnLedgerRow), findsNothing);
  });
}
