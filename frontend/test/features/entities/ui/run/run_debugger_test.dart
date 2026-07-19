import 'dart:convert';

import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/an_dropdown.dart';
import 'package:anselm/core/ui/an_ledger_row.dart';
import 'package:anselm/core/ui/an_panel_head.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/run/recent_runs_provider.dart';
import 'package:anselm/features/entities/state/run/run_draft_store.dart';
import 'package:anselm/features/entities/state/run/run_terminal_controller.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/run/run_terminal.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/router_harness.dart';

// The debugger v3 (JSON-first, 0719 拍板) under widget test: the input IS one prefilled JSON editor + a
// Lambda/Postman toolbar (payload source · method/source chip · verb), values live as JSON TEXT in
// per-dimension session buckets, live lint gates the verb, ⌘↵ submits from inside the editor (its
// toolbar keycap glyph was removed later the same day — visual clutter, chord stays wired), and the
// recent strip + «用这份输入» close the loop (relative time · human origin · IO expand · wf deep-link).

final _t0 = DateTime.utc(2026, 6, 27);

Map<String, dynamic> _json(String s) => jsonDecode(s) as Map<String, dynamic>;
AnCodeEditor _editor(WidgetTester tester) => tester.widget<AnCodeEditor>(find.byType(AnCodeEditor).first);

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
      flowruns: {
        'wf_1': [
          Flowrun(
            id: 'fr_1',
            workflowId: 'wf_1',
            status: 'completed',
            origin: 'cron',
            startedAt: _t0,
            completedAt: _t0.add(const Duration(seconds: 9)),
            updatedAt: _t0,
          ),
        ],
      },
    );

Widget _host(FixtureEntityRepository repo, EntityRef sel) => routedHost(
      Scaffold(body: SizedBox(width: 360, height: 900, child: const RunTerminal())),
      initialLocation: selectionLocation(sel.kind, sel.id),
      repository: repo,
    );

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(RunTerminal)));

void main() {
  final r = t.entities.run;
  const fnRef = EntityRef(EntityKind.function, 'fn_1');
  const hdRef = EntityRef(EntityKind.handler, 'hd_1');
  const wfRef = EntityRef(EntityKind.workflow, 'wf_1');

  testWidgets('fn: ONE JSON editor prefilled with the example skeleton (哪里填哪个消失)', (tester) async {
    await tester.pumpWidget(_host(_fix(), fnRef));
    await tester.pump(const Duration(milliseconds: 50));
    final ed = _editor(tester);
    expect(ed.lang, 'json');
    expect(ed.editable && ed.seamless, isTrue); // seamless in-place JSON editor 同款嵌入代码块
    final seed = _json(ed.code);
    expect(seed.keys, containsAll(<String>['text', 'limit', 'strict', 'options']));
    expect(seed['text'], ''); // string skeleton
    expect(seed['limit'], 0); // number skeleton
    expect(seed['strict'], false); // boolean skeleton
  });

  testWidgets('hd: the method chip re-seeds the example; drafts remembered PER METHOD', (tester) async {
    await tester.pumpWidget(_host(_fix(), hdRef));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(); // post-frame default method
    // payload-source chip + method chip = two ghost dropdowns. 两个 ghost 下拉。
    expect(find.byType(AnDropdown<String>), findsNWidgets(2));
    expect(_json(_editor(tester).code).keys, ['to']); // first method's schema 首方法示例

    final c = _container(tester);
    final ctrl = c.read(runTerminalProvider(hdRef).notifier);
    ctrl.setDraftText('{"to":"ops@x.dev"}'); // type into the send bucket 往 send 桶打字
    ctrl.setMethod('archive');
    await tester.pump();
    expect(_json(_editor(tester).code).keys, ['days']); // archive's schema, re-seeded 整体重生成

    ctrl.setMethod('send'); // switch back → the exact draft restores 切回原样
    await tester.pump();
    final store = c.read(runDraftStoreProvider);
    expect(store.textFor(runDraftKey(hdRef, 'send')), '{"to":"ops@x.dev"}');
    expect(store.textFor(runDraftKey(hdRef, 'archive')), isNotNull); // its own seeded bucket
  });

  testWidgets('wf: the source chip re-seeds the per-source FIRE-PAYLOAD template', (tester) async {
    await tester.pumpWidget(_host(_fix(), wfRef));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AnDropdown<String>), findsNWidgets(2)); // payload + source
    expect(_json(_editor(tester).code), <String, dynamic>{}); // manual (default) → a free {}

    final c = _container(tester);
    final ctrl = c.read(runTerminalProvider(wfRef).notifier);

    ctrl.setSource('tr_cron');
    await tester.pump(const Duration(milliseconds: 50)); // trigger detail loads (kind resolves)
    await tester.pump();
    expect(_json(_editor(tester).code).keys, ['firedAt']); // cron → {firedAt} ONLY (real payload)

    ctrl.setSource('tr_fs');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(_json(_editor(tester).code).keys, containsAll(<String>['firedAt', 'path', 'eventKind']));

    ctrl.setSource('tr_hook');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(_json(_editor(tester).code).keys,
        containsAll(<String>['firedAt', 'method', 'path', 'headers', 'body']));
  });

  testWidgets('lint: invalid JSON disables the verb + shows a red line; valid re-enables', (tester) async {
    await tester.pumpWidget(_host(_fix(), fnRef));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField).first, '{not json');
    await tester.pump();
    expect(find.text(r.payloadInvalid), findsOneWidget); // honest red line
    final verb = t.entities.detail.verb.run;
    expect(tester.widget<AnButton>(find.widgetWithText(AnButton, verb)).onPressed, isNull); // disabled
  });

  testWidgets('recent strip: top-5 rows, human origin word, expand to IO', (tester) async {
    await tester.pumpWidget(_host(_fix(), fnRef));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50)); // recent load
    expect(find.text(r.recentCount(n: 5)), findsOneWidget); // «最近执行 · 5»
    expect(find.byType(AnLedgerRow), findsNWidgets(5)); // seeded 7 → strip caps at 5
    expect(find.text(r.origin.manual), findsWidgets); // «manual» spoken as human 手动
    await tester.tap(find.byType(AnLedgerRow).at(1)); // an ok row 展开一行
    await tester.pumpAndSettle();
    expect(find.text(r.inputHeading), findsOneWidget);
    expect(find.textContaining('run-1'), findsWidgets); // that execution's raw input
  });

  testWidgets('用这份输入: fills the editor from a past run (method restored for hd)', (tester) async {
    await tester.pumpWidget(_host(_fix(), hdRef));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    final c = _container(tester);
    final ctrl = c.read(runTerminalProvider(hdRef).notifier);
    ctrl.loadInput(const RecentRun(
        id: 'hc_1', status: 'ok', method: 'archive', input: {'days': 30}, triggeredBy: 'manual'));
    await tester.pump();
    expect(c.read(runTerminalProvider(hdRef)).method, 'archive'); // method followed 方法跟随
    final store = c.read(runDraftStoreProvider);
    expect(_json(store.textFor(runDraftKey(hdRef, 'archive'))!), {'days': 30}); // pretty JSON of the input
    expect(_json(_editor(tester).code), {'days': 30}); // the editor shows it
  });

  testWidgets('wf recent row expands to «在运行页打开 →» (right island never hosts a long run)', (tester) async {
    await tester.pumpWidget(_host(_fix(), wfRef));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50)); // flowruns load
    expect(find.byType(AnLedgerRow), findsOneWidget);
    await tester.tap(find.byType(AnLedgerRow).first);
    await tester.pumpAndSettle();
    expect(find.text(r.openRunPage), findsOneWidget); // the deep link, not inline IO 深链而非内联
  });

  testWidgets('⌘↵ submits from inside the editor (0719 用户裁定: the toolbar keycap glyph is gone, the '
      'chord itself stays wired)', (tester) async {
    await tester.pumpWidget(_host(_fix(), fnRef));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(TextField).first); // focus the JSON editor 聚焦编辑器
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text(t.status.done), findsOneWidget); // ran to ok
  });

  testWidgets('recent strip stays SILENT when there is no ledger (no tombstone, no section)', (tester) async {
    final repo = FixtureEntityRepository(
      runDelay: Duration.zero,
      functions: [FunctionEntity(id: 'fn_2', name: 'bare', createdAt: _t0, updatedAt: _t0)],
    );
    await tester.pumpWidget(_host(repo, const EntityRef(EntityKind.function, 'fn_2')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('·'), findsNothing); // no «最近执行 · N» head
    expect(find.byType(AnLedgerRow), findsNothing);
  });

  // ── 三段式文法 §1+§2 (0719): the debugger head is AnPanelHead (icon+name+⋯+✕) + a §2 glance strip.
  // 调试台头=AnPanelHead + 速览带。
  group('head 三段式文法 (§1+§2)', () {
    FixtureEntityRepository glanceFix() {
      // Anchor to LOCAL NOON of the current day, not raw now(): the two "today" runs are this one + one
      // 2h earlier, and a now() within 2h of midnight pushed the earlier run into YESTERDAY — dropping the
      // today count to 1 and failing the n=2 glance (a latent date-boundary flaky). Noon keeps both runs
      // unambiguously the same calendar day at any wall-clock hour. 锚当天正午:近午夜时 -2h 会跨到昨天把
      // 「今天」计数打成 1(潜伏的日界 flaky);正午让两跑任何时刻都同一天。
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      return FixtureEntityRepository(
        runDelay: Duration.zero,
        functions: [
          FunctionEntity(
            id: 'fn_g',
            name: 'glance-fn',
            createdAt: _t0,
            updatedAt: _t0,
            activeVersionId: 'fn_g_v3',
            activeVersion: FunctionVersion(
                id: 'fn_g_v3', functionId: 'fn_g', version: 3, createdAt: _t0, updatedAt: _t0),
          ),
          // A versioned entity with an EMPTY ledger — the glance is just «v{N}» (缺段不渲). 有版本无跑。
          FunctionEntity(
            id: 'fn_v',
            name: 'versioned-only',
            createdAt: _t0,
            updatedAt: _t0,
            activeVersionId: 'fn_v_v5',
            activeVersion: FunctionVersion(
                id: 'fn_v_v5', functionId: 'fn_v', version: 5, createdAt: _t0, updatedAt: _t0),
          ),
        ],
        functionExecutions: {
          // Newest-first (the ledger order the provider pages): today ok 12ms, today ok 9ms, an OLD
          // failed one. today count = 2; last = ok 12ms. 新在前:今天 ok/ok + 一条旧的 failed。
          'fn_g': [
            FunctionExecution(
                id: 'g0', functionId: 'fn_g', status: 'ok', triggeredBy: 'manual',
                input: const {'x': 1}, elapsedMs: 12, startedAt: today, createdAt: today),
            FunctionExecution(
                id: 'g1', functionId: 'fn_g', status: 'ok', triggeredBy: 'manual',
                input: const {'x': 1}, elapsedMs: 9,
                startedAt: today.subtract(const Duration(hours: 2)), createdAt: today),
            FunctionExecution(
                id: 'g2', functionId: 'fn_g', status: 'failed', triggeredBy: 'manual',
                input: const {'x': 1}, elapsedMs: 4, startedAt: _t0, createdAt: _t0),
          ],
        },
      );
    }

    testWidgets('head = AnPanelHead (name title, NO ⋯ since the debugger has no panel action)',
        (tester) async {
      await tester.pumpWidget(_host(glanceFix(), const EntityRef(EntityKind.function, 'fn_g')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AnPanelHead), findsOneWidget);
      final head = tester.widget<AnPanelHead>(find.byType(AnPanelHead));
      expect(head.title, 'glance-fn');
      expect(head.menuEntries, isEmpty); // 无面板级动作 → no ⋯
      expect(find.byIcon(AnIcons.more), findsNothing);
    });

    testWidgets('glance: v{N} · 今天 {n} 次执行 · 上次成功 {ms} (all three segments, real data)',
        (tester) async {
      await tester.pumpWidget(_host(glanceFix(), const EntityRef(EntityKind.function, 'fn_g')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50)); // recentRuns resolves
      expect(find.textContaining('v3'), findsOneWidget);
      expect(find.textContaining(r.glanceToday(n: 2)), findsOneWidget); // 今天 2 次执行 (g2 is old)
      expect(find.textContaining(r.glanceLastOk), findsOneWidget); // last = g0 ok
    });

    testWidgets('glance omits absent segments — a versioned entity with no ledger shows only v{N}',
        (tester) async {
      await tester.pumpWidget(_host(glanceFix(), const EntityRef(EntityKind.function, 'fn_v')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('v5'), findsOneWidget); // just the version — no today, no last (缺段不渲)
      expect(find.textContaining('今天'), findsNothing);
      expect(find.textContaining(r.glanceLastOk), findsNothing);
    });
  });
}
