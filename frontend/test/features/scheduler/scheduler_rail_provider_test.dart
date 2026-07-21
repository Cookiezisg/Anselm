import 'dart:async';

import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/sse/sse_connection.dart';
import 'package:anselm/core/sse/sse_gateway.dart';
import 'package:anselm/features/scheduler/data/scheduler_demo_fixture.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/state/scheduler_overview_provider.dart';
import 'package:anselm/features/scheduler/state/scheduler_rail_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The rail controller's LIVENESS LAW under adversarial frames (WRK-069 §2 活性军规): ephemeral ticks
// (seq=0) must NEVER trigger a refetch (→ never reorder rows); durable frames (seq>0) must (debounced).
// 对抗测:tick 绝不触发 refetch(=绝不重排),durable 必触发(去抖)。
//
// …and the controller's STALENESS LAW (真机验收发现): a cached next-fire that has aged into the past
// means OUR SNAPSHOT expired — the pulse must refetch, never let the board render «—» over a schedule
// that is alive. 陈旧律(真机验收发现):缓存的 next-fire 老成过去=**我们的快照**过期,脉搏必须重取,
// 绝不让看板在活着的调度上渲「—」。

class _FakeConn extends SseConnection {
  _FakeConn()
    : super(
        streamPath: '/x',
        baseUrl: 'http://localhost:1',
        workspaceId: () => null,
        authToken: () => null,
      );

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

/// A rail seam whose next-fire answer is SCRIPTABLE — [nextFire] is what the wire says right now, so
/// a battery can hand back a past instant (the aged-snapshot case the real app hits after a sleep)
/// and then the fresh one the real backend structurally always gives (`cron.Next(time.Now())` at read
/// time). [fail] makes a refetch never land. 可编脚本的 next-fire 数据缝:先递过去值(睡醒后的陈旧
/// 快照),再递真后端按构造必给的未来值;fail=重取落不了地。
class _FireRepo extends FixtureSchedulerRepository {
  _FireRepo(this.nextFire);

  DateTime? nextFire;
  int fetches = 0;
  bool fail = false;

  @override
  Future<List<SchedulerWorkflowRow>> listWorkflows() {
    fetches++;
    if (fail) throw StateError('backend down');
    return super.listWorkflows();
  }

  @override
  Future<List<TriggerEntity>> listTriggers() async => [
    TriggerEntity(
      id: 'tr_cron_clean',
      name: '每日 09:00',
      kind: TriggerSource.cron,
      config: const {'cron': '0 9 * * *'},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      listening: true,
      nextFireAt: nextFire,
    ),
  ];

  @override
  Future<List<EntityRelation>> workflowTriggerEdges() async => const [
    EntityRelation(
      id: 'rel_1',
      kind: 'equip',
      fromKind: 'workflow',
      fromId: 'wf_clean',
      fromName: '数据清洗流水线',
      toKind: 'trigger',
      toId: 'tr_cron_clean',
      toName: '每日 09:00',
    ),
  ];
}

StreamEnvelope _workflowFrame({required int seq, String type = 'run'}) =>
    StreamEnvelope(
      seq: seq,
      scope: const StreamScope(kind: 'workflow', id: 'wf_clean'),
      id: 'n1',
      frame: FrameSignal(node: StreamNode(type: type)),
    );

void main() {
  test(
    'ticks (seq=0) never refetch; durable frames (seq>0) do — debounced',
    () async {
      final conns = {for (final n in StreamName.values) n: _FakeConn()};
      final gateway = SseGateway(
        baseUrl: 'http://localhost:1',
        workspaceId: () => null,
        authToken: () => null,
        connectionFactory: (n) => conns[n]!,
      );
      final repo = _CountingRepo();
      final container = ProviderContainer(
        overrides: [
          sseGatewayProvider.overrideWithValue(gateway),
          schedulerRepositoryProvider.overrideWithValue(repo),
        ],
      );
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
      conns[StreamName.entities]!.ctrl.add(
        _workflowFrame(seq: 7, type: 'run_started'),
      );
      conns[StreamName.entities]!.ctrl.add(
        _workflowFrame(seq: 8, type: 'run_terminal'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(repo.fetches, 2, reason: '两 durable 帧去抖成一次 refetch');
    },
  );

  // ── 陈旧律:缓存的未来变成过去 → 触发重取,不渲「—」(真机验收发现) ──

  group('staleFireFingerprint (the detector itself)', () {
    final now = DateTime.utc(2026, 7, 17, 9);

    test('all-future → null: nothing to heal', () {
      expect(
        staleFireFingerprint([now.add(const Duration(minutes: 1))], now),
        isNull,
      );
    });

    test(
      'empty → null: «no schedule» is not «a stale schedule» (a paused-only workspace is honest)',
      () {
        expect(staleFireFingerprint(const [], now), isNull);
      },
    );

    test(
      'a fire exactly AT now is already spent — isAfter is strict, as the backend\'s Next() is',
      () {
        expect(staleFireFingerprint([now], now), isNotNull);
      },
    );

    test(
      'order-independent: the fingerprint identifies the ANSWER, not the map\'s iteration order',
      () {
        final a = now.subtract(const Duration(minutes: 5));
        final b = now.subtract(const Duration(minutes: 9));
        expect(
          staleFireFingerprint([a, b], now),
          staleFireFingerprint([b, a], now),
        );
      },
    );

    test(
      'a DIFFERENT past answer is a different question — a moved value earns one more ask',
      () {
        expect(
          staleFireFingerprint([now.subtract(const Duration(minutes: 5))], now),
          isNot(
            staleFireFingerprint([
              now.subtract(const Duration(minutes: 6)),
            ], now),
          ),
        );
      },
    );

    test(
      'mixed → only the stale ones: a live lane never provokes a refetch',
      () {
        final past = now.subtract(const Duration(minutes: 5));
        expect(
          staleFireFingerprint([past, now.add(const Duration(hours: 2))], now),
          staleFireFingerprint([past], now),
        );
      },
    );
  });

  ProviderContainer railWith(_FireRepo repo) {
    final container = ProviderContainer(
      overrides: [
        sseGatewayProvider.overrideWithValue(
          null,
        ), // zero-backend, exactly like `make demo`
        schedulerRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a cached next-fire that AGED into the past refetches — the board never renders «—» over a '
      'live schedule (close the laptop at 17:00, open it at 09:05)', () async {
    final repo = _FireRepo(DateTime.now().subtract(const Duration(minutes: 5)));
    final container = railWith(repo);
    var data = await container.read(schedulerRailProvider.future);
    expect(repo.fetches, 1);
    // The PREMISE: this snapshot really does make the KPI say «—». Without this line the test could
    // pass while proving nothing. 前提:这份快照确实会让 KPI 渲「—」——没有这行,本测可能空过。
    expect(
      earliestNextFire(data.nextFireByWorkflow.values, DateTime.now()),
      isNull,
      reason: '陈旧快照下「下次调度」确实退化成「—」(这正是要修的谎)',
    );

    // The wire's real physics: nextFireAt is `cron.Next(now())` computed at READ time, so a listening
    // cron's answer is future BY CONSTRUCTION. 线缆真物理:读时投影,监听中的 cron 按构造必给未来。
    repo.nextFire = DateTime.now().add(const Duration(minutes: 3));
    container.read(schedulerRailProvider.notifier).onPulseForTest();
    await pumpEventQueue();

    expect(repo.fetches, 2, reason: '陈旧 ⇒ 重取(而不是假装没有调度)');
    data = container.read(schedulerRailProvider).value!;
    expect(
      earliestNextFire(data.nextFireByWorkflow.values, DateTime.now()),
      isNotNull,
      reason: '自愈:「下次调度」回来了,牌与 rail ⏱ meta 同源同愈',
    );
  });

  test(
    'a fresh snapshot never refetches — the pulse is a DETECTOR, not a poller',
    () async {
      final repo = _FireRepo(DateTime.now().add(const Duration(minutes: 3)));
      final container = railWith(repo);
      await container.read(schedulerRailProvider.future);
      expect(repo.fetches, 1);

      for (var i = 0; i < 5; i++) {
        container.read(schedulerRailProvider.notifier).onPulseForTest();
      }
      await pumpEventQueue();
      expect(repo.fetches, 1, reason: '未来的 fire 不是陈旧:半分钟脉搏绝不变成半分钟轮询器');
    },
  );

  test(
    'ONE ask per answer: a wire that keeps handing back the SAME past instant cannot spin the '
    'pulse (退避/单次语义)',
    () async {
      // Pathological — the answer does not move. Asking again is asking a question already answered.
      // 病态:答案不动。再问一次=问一个已经答过的问题。
      final repo = _FireRepo(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final container = railWith(repo);
      await container.read(schedulerRailProvider.future);
      final ctl = container.read(schedulerRailProvider.notifier);

      ctl.onPulseForTest();
      await pumpEventQueue();
      expect(repo.fetches, 2, reason: '第一次:问');

      for (var i = 0; i < 10; i++) {
        ctl.onPulseForTest();
        await pumpEventQueue();
      }
      expect(repo.fetches, 2, reason: '答案没变=已回答:绝不每 30s 空转一次(死循环风险的闸)');
    },
  );

  test(
    'a refetch that never LANDED releases the latch — one network blip must not wedge «—» until '
    'the next durable frame',
    () async {
      final repo = _FireRepo(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final container = railWith(repo);
      await container.read(schedulerRailProvider.future);
      final ctl = container.read(schedulerRailProvider.notifier);

      repo.fail = true;
      ctl.onPulseForTest();
      await pumpEventQueue();
      expect(repo.fetches, 2, reason: '问了');
      expect(
        container.read(schedulerRailProvider).hasValue,
        isTrue,
        reason: '重取失败保留旧真相:rail 不闪错态(重取期间/失败后都不闪)',
      );

      // The blip passes; the next pulse must ask AGAIN — the latch may only close on a real answer.
      // 抖动过去了,下个脉搏必须再问——闩只闩真收到的答案。
      repo.fail = false;
      repo.nextFire = DateTime.now().add(const Duration(minutes: 3));
      ctl.onPulseForTest();
      await pumpEventQueue();
      expect(repo.fetches, 3, reason: '没落地的重取不是答案:闩释放,后面的脉搏再问');
      expect(
        earliestNextFire(
          container
              .read(schedulerRailProvider)
              .value!
              .nextFireByWorkflow
              .values,
          DateTime.now(),
        ),
        isNotNull,
        reason: '抖动之后照样自愈',
      );
    },
  );
}
