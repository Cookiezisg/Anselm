import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/features/entities/state/run/run_terminal_controller.dart';
import 'package:anselm/features/entities/state/run/run_terminal_state.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 5.5 gate — the run-terminal controller is a FAMILY (one per executable entity): each coerces its
// own draft → request, captures the execution stream, finalizes from the result, and stays independent
// (a run on A doesn't touch B). fn → ok + bare result + live stderr; agent → ReAct tree; workflow →
// durable flowrun nodes; API error → failed; cancel drops the stale result; bad JSON → inputError.

const _fnRef = EntityRef(EntityKind.function, 'fn_1');
const _agRef = EntityRef(EntityKind.agent, 'ag_1');
const _wfRef = EntityRef(EntityKind.workflow, 'wf_1');

(ProviderContainer, RunTerminalController) _harness(
  EntityRepository repo,
  EntityRef ref,
) {
  final c = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(
    runTerminalProvider(ref),
    (_, _) {},
  ); // keep the family member (+ its panel sub) alive
  return (c, c.read(runTerminalProvider(ref).notifier));
}

FixtureEntityRepository _wfRepo() => FixtureEntityRepository(
  runDelay: Duration.zero,
  workflows: [
    WorkflowEntity(
      id: 'wf_1',
      name: 'pipeline',
      createdAt: DateTime.utc(2026, 6, 27),
      updatedAt: DateTime.utc(2026, 6, 27),
      activeVersionId: 'wf_1_v1',
      activeVersion: WorkflowVersion(
        id: 'wf_1_v1',
        workflowId: 'wf_1',
        version: 1,
        graph:
            '{"nodes":[{"id":"n1","kind":"trigger","ref":"tr_cron"},{"id":"n2","kind":"agent","ref":"ag_r"},{"id":"n3","kind":"action","ref":"fn_s"}],"edges":[{"id":"e1","from":"n1","to":"n2"},{"id":"e2","from":"n2","to":"n3"}]}',
        createdAt: DateTime.utc(2026, 6, 27),
        updatedAt: DateTime.utc(2026, 6, 27),
      ),
    ),
  ],
);

class _ThrowRepo extends FixtureEntityRepository {
  _ThrowRepo() : super(runDelay: Duration.zero);
  @override
  Future<FunctionRunResult> runFunction(
    String id, {
    required Map<String, dynamic> args,
    int? version,
  }) async => throw const ApiException(
    code: 'FUNCTION_RUN_TIMEOUT',
    message: 'timed out',
    httpStatus: 504,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // CoalescingNotifier touches SchedulerBinding.instance

  test('function :run → ok + bare result + live stderr captured', () async {
    final (c, ctl) = _harness(
      FixtureEntityRepository(runDelay: Duration.zero),
      _fnRef,
    );
    await ctl.run();
    await pumpEventQueue();
    final st = c.read(runTerminalProvider(_fnRef));
    expect(st.phase, RunPhase.ok);
    expect(st.output, {'result': 'ok'});
    expect(ctl.stream.value.text, contains('done'));
  });

  test(
    'agent :invoke → ok + ReAct tree (reasoning, tool_call, text) + steps/tokens',
    () async {
      final (c, ctl) = _harness(
        FixtureEntityRepository(runDelay: Duration.zero),
        _agRef,
      );
      await ctl.run();
      await pumpEventQueue();
      final st = c.read(runTerminalProvider(_agRef));
      expect(st.phase, RunPhase.ok);
      expect(st.steps, 3);
      final roots = ctl.stream.value.tree.roots;
      expect(
        roots.map((b) => b.kind.name),
        containsAll(<String>['reasoning', 'toolCall', 'text']),
      );
      final tc = roots.firstWhere((b) => b.name == 'web-search');
      expect(tc.children.single.displayText, '3 results found');
    },
  );

  test(
    'workflow :trigger → reconcile-driven: running while walking, ok at terminal',
    () async {
      final (c, ctl) = _harness(_wfRepo(), _wfRef);
      await ctl.run();
      await pumpEventQueue();
      // The walk streamed ticks in (self-filtered to OUR flowrunId) — the debounced reconcile
      // hasn't landed yet, so the phase is honestly running. 走图 tick 已进,去抖对账未落 → 诚实 running。
      var st = c.read(runTerminalProvider(_wfRef));
      expect(st.flowrunId, isNotNull);
      expect(st.flowNodes.length, 3); // tick upserts tick 行已上
      await Future<void>.delayed(
        const Duration(milliseconds: 400),
      ); // debounce lands 对账落地
      st = c.read(runTerminalProvider(_wfRef));
      expect(st.phase, RunPhase.ok);
      expect(st.flowrunStatus, 'completed');
      // Truth rows replaced the tick rows. 真相行顶替 tick 行。
      expect(st.flowNodes.every((n) => !n.id.startsWith('tick_')), isTrue);
    },
  );

  test('API error → failed with code + message', () async {
    final (c, ctl) = _harness(_ThrowRepo(), _fnRef);
    await ctl.run();
    final st = c.read(runTerminalProvider(_fnRef));
    expect(st.phase, RunPhase.failed);
    expect(st.errorCode, 'FUNCTION_RUN_TIMEOUT');
    expect(st.errorMsg, 'timed out');
  });

  test(
    'cancel before completion drops the stale result (stays cancelled)',
    () async {
      final (c, ctl) = _harness(
        FixtureEntityRepository(runDelay: const Duration(milliseconds: 30)),
        _fnRef,
      );
      final fut = ctl.run();
      ctl.cancel();
      expect(c.read(runTerminalProvider(_fnRef)).phase, RunPhase.cancelled);
      await fut;
      await pumpEventQueue();
      expect(c.read(runTerminalProvider(_fnRef)).phase, RunPhase.cancelled);
    },
  );

  test(
    'invalid JSON text → payloadInvalid, no run (JSON-first coerce)',
    () async {
      final (c, ctl) = _harness(
        FixtureEntityRepository(runDelay: Duration.zero),
        _fnRef,
      );
      ctl.setDraftText('{not json');
      await ctl.run();
      final st = c.read(runTerminalProvider(_fnRef));
      expect(st.inputError, 'payloadInvalid');
      expect(st.phase, RunPhase.idle); // never ran
    },
  );

  test(
    'non-object JSON text → payloadObject, no run (top-level must be an object)',
    () async {
      final (c, ctl) = _harness(
        FixtureEntityRepository(runDelay: Duration.zero),
        _fnRef,
      );
      ctl.setDraftText('[1, 2, 3]');
      await ctl.run();
      final st = c.read(runTerminalProvider(_fnRef));
      expect(st.inputError, 'payloadObject');
      expect(st.phase, RunPhase.idle);
    },
  );

  test(
    'family members are independent (a run on one does not touch another)',
    () async {
      final repo = FixtureEntityRepository(runDelay: Duration.zero);
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.listen(runTerminalProvider(_fnRef), (_, _) {});
      c.listen(runTerminalProvider(_agRef), (_, _) {});
      await c.read(runTerminalProvider(_fnRef).notifier).run();
      await pumpEventQueue();
      expect(c.read(runTerminalProvider(_fnRef)).phase, RunPhase.ok);
      expect(
        c.read(runTerminalProvider(_agRef)).phase,
        RunPhase.idle,
      ); // untouched
    },
  );
}
