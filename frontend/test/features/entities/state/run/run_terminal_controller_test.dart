import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/features/entities/state/run/run_terminal_controller.dart';
import 'package:anselm/features/entities/state/run/run_terminal_state.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 5 gate — the run-terminal controller wires each verb to the repository, captures the execution-time
// stream into the coalescer, and finalizes from the result: fn → ok + bare result + live stderr; agent →
// ReAct tree; workflow → durable flowrun nodes; API error → failed; cancel drops the stale result.

(ProviderContainer, RunTerminalController) _harness(EntityRepository repo) {
  final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  c.listen(runTerminalProvider, (_, _) {}); // keep the notifier (+ its panel sub) alive
  return (c, c.read(runTerminalProvider.notifier));
}

class _ThrowRepo extends FixtureEntityRepository {
  _ThrowRepo() : super(runDelay: Duration.zero);
  @override
  Future<FunctionRunResult> runFunction(String id, {required Map<String, dynamic> args, int? version}) async =>
      throw const ApiException(code: 'FUNCTION_RUN_TIMEOUT', message: 'timed out', httpStatus: 504);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // CoalescingNotifier touches SchedulerBinding.instance

  test('openFor → idle + open + bound ref; close hides', () {
    final (c, ctl) = _harness(FixtureEntityRepository(runDelay: Duration.zero));
    ctl.openFor(const EntityRef(EntityKind.function, 'fn_1'));
    var st = c.read(runTerminalProvider);
    expect(st.open, isTrue);
    expect(st.phase, RunPhase.idle);
    expect(st.ref, const EntityRef(EntityKind.function, 'fn_1'));
    ctl.close();
    st = c.read(runTerminalProvider);
    expect(st.open, isFalse);
    expect(st.ref, const EntityRef(EntityKind.function, 'fn_1')); // binding kept
  });

  test('function :run → ok + bare result + live stderr captured', () async {
    final (c, ctl) = _harness(FixtureEntityRepository(runDelay: Duration.zero));
    ctl.openFor(const EntityRef(EntityKind.function, 'fn_1'));
    await ctl.run(request: {'text': 'hi'});
    await pumpEventQueue();
    final st = c.read(runTerminalProvider);
    expect(st.phase, RunPhase.ok);
    expect(st.output, {'result': 'ok'});
    expect(ctl.stream.value.text, contains('done')); // streamed run-node stderr
  });

  test('agent :invoke → ok + ReAct tree (reasoning, tool_call, text) + steps/tokens', () async {
    final (c, ctl) = _harness(FixtureEntityRepository(runDelay: Duration.zero));
    ctl.openFor(const EntityRef(EntityKind.agent, 'ag_1'));
    await ctl.run(request: {'topic': 'x'});
    await pumpEventQueue();
    final st = c.read(runTerminalProvider);
    expect(st.phase, RunPhase.ok);
    expect(st.steps, 3);
    final roots = ctl.stream.value.tree.roots;
    expect(roots.map((b) => b.kind.name), containsAll(<String>['reasoning', 'toolCall', 'text']));
    final tc = roots.firstWhere((b) => b.name == 'web-search');
    expect(tc.children.single.displayText, '3 results found'); // nested tool_result
  });

  test('workflow :trigger → ok + durable flowrun nodes (GET /flowruns/{id})', () async {
    final (c, ctl) = _harness(FixtureEntityRepository(runDelay: Duration.zero));
    ctl.openFor(const EntityRef(EntityKind.workflow, 'wf_1'));
    await ctl.run(request: {});
    await pumpEventQueue();
    final st = c.read(runTerminalProvider);
    expect(st.phase, RunPhase.ok);
    expect(st.flowrunId, isNotNull);
    expect(st.flowNodes.length, 3);
    expect(st.flowNodes.every((n) => n.status == 'completed'), isTrue);
  });

  test('API error → failed with code + message', () async {
    final (c, ctl) = _harness(_ThrowRepo());
    ctl.openFor(const EntityRef(EntityKind.function, 'fn_1'));
    await ctl.run(request: {});
    final st = c.read(runTerminalProvider);
    expect(st.phase, RunPhase.failed);
    expect(st.errorCode, 'FUNCTION_RUN_TIMEOUT');
    expect(st.errorMsg, 'timed out');
  });

  test('cancel before completion drops the stale result (stays cancelled)', () async {
    final (c, ctl) = _harness(FixtureEntityRepository(runDelay: const Duration(milliseconds: 30)));
    ctl.openFor(const EntityRef(EntityKind.function, 'fn_1'));
    final fut = ctl.run(request: {});
    ctl.cancel();
    expect(c.read(runTerminalProvider).phase, RunPhase.cancelled);
    await fut; // the abandoned run finishes…
    await pumpEventQueue();
    expect(c.read(runTerminalProvider).phase, RunPhase.cancelled); // …but its result is dropped
  });
}
