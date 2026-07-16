import 'dart:async';

import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/sse/sse_connection.dart';
import 'package:anselm/core/sse/sse_gateway.dart';
import 'package:anselm/features/scheduler/data/scheduler_demo_fixture.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/state/scheduler_rail_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The rail controller's LIVENESS LAW under adversarial frames (WRK-069 §2 活性军规): ephemeral ticks
// (seq=0) must NEVER trigger a refetch (→ never reorder rows); durable frames (seq>0) must (debounced).
// 对抗测:tick 绝不触发 refetch(=绝不重排),durable 必触发(去抖)。

class _FakeConn extends SseConnection {
  _FakeConn()
      : super(streamPath: '/x', baseUrl: 'http://localhost:1', workspaceId: () => null, authToken: () => null);

  final ctrl = StreamController<StreamEnvelope>.broadcast();

  @override
  Stream<StreamEnvelope> get envelopes => ctrl.stream;

  @override
  void start() {} // never dials. 绝不拨号。
}

class _CountingRepo extends FixtureSchedulerRepository {
  int fetches = 0;

  @override
  Future<List<SchedulerWorkflowRow>> listWorkflows() {
    fetches++;
    return super.listWorkflows();
  }
}

StreamEnvelope _workflowFrame({required int seq, String type = 'run'}) => StreamEnvelope(
      seq: seq,
      scope: const StreamScope(kind: 'workflow', id: 'wf_clean'),
      id: 'n1',
      frame: FrameSignal(node: StreamNode(type: type)),
    );

void main() {
  test('ticks (seq=0) never refetch; durable frames (seq>0) do — debounced', () async {
    final conns = {for (final n in StreamName.values) n: _FakeConn()};
    final gateway = SseGateway(
      baseUrl: 'http://localhost:1',
      workspaceId: () => null,
      authToken: () => null,
      connectionFactory: (n) => conns[n]!,
    );
    final repo = _CountingRepo();
    final container = ProviderContainer(overrides: [
      sseGatewayProvider.overrideWithValue(gateway),
      schedulerRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(schedulerRailProvider.future);
    expect(repo.fetches, 1, reason: 'initial load');

    // A storm of ephemeral ticks — the rail must not move. tick 风暴,rail 纹丝不动。
    for (var i = 0; i < 20; i++) {
      conns[StreamName.entities]!.ctrl.add(_workflowFrame(seq: 0));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(repo.fetches, 1, reason: 'seq=0 帧绝不触发 refetch(活性军规)');

    // One durable ledger event → exactly one debounced refetch. durable 落账→恰一次去抖 refetch。
    conns[StreamName.entities]!.ctrl.add(_workflowFrame(seq: 7, type: 'run_started'));
    conns[StreamName.entities]!.ctrl.add(_workflowFrame(seq: 8, type: 'run_terminal'));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(repo.fetches, 2, reason: '两 durable 帧去抖成一次 refetch');
  });
}
