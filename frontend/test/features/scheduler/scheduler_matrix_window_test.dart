import 'package:anselm/core/contract/entities/scheduler_matrix.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/model/time_range.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/scheduler_windows.dart';
import 'package:anselm/features/scheduler/state/scheduler_home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stub_scheduler_repo.dart';

// SchedulerMatrixWindowController — the paging+merge core of the 0717 主页重建 (复审 [8]:这台
// 发动机曾零覆盖). Locks: page-1 shape (page ids → ONE flowrunIds batch), loadOlder merge (cols
// concat newest→oldest / rows first-seen union with the newest occurrence's kind / cells concat),
// the busy+exhausted guards, the error honesty (window keeps standing), and the mid-flight guard
// (a range change in the middle of loadOlder must DROP the stale older page, never mix two
// ranges' histories).
// 矩阵窗控制器:翻页+归并核心。锁:首页形(页 id→一次批查)、loadOlder 归并(列相接/行首见并集
// [kind 取最新一次出现]/格相接)、busy+翻尽守卫、错误诚实(窗照旧站着)、途中换范围守卫(在飞旧页
// 必须丢弃,绝不混两个范围的历史)。
void main() {
  final now = DateTime.now();

  /// [n] runs, newest = index 0 (started minutes ago, all inside the 7d default range), plus a
  /// scripted grid: node `n1` on every run, node `n2` ONLY on runs older than the first page —
  /// the union test's bait. 造 n 个 run(全在默认 7 天内)+ 剧本格阵:n1 全员、n2 只在首页之外的旧
  /// run 上——并集测试的饵。
  StubSchedulerRepo repo(int n) {
    final runs = [
      for (var i = 0; i < n; i++)
        Flowrun(
          id: 'fr_${i.toString().padLeft(3, '0')}',
          workflowId: 'wf_m',
          status: 'completed',
          startedAt: now.subtract(Duration(minutes: i + 1)),
          completedAt: now
              .subtract(Duration(minutes: i + 1))
              .add(const Duration(seconds: 5)),
          updatedAt: now,
        ),
    ];
    final grid = FlowrunMatrix(
      cols: [
        for (final r in runs)
          MatrixCol(
            flowrunId: r.id,
            startedAt: r.startedAt!,
            status: 'completed',
            elapsedMs: 5000,
          ),
      ],
      rows: const [
        MatrixRow(nodeId: 'n1', kind: 'action'),
        MatrixRow(nodeId: 'n2', kind: 'agent'),
      ],
      cells: [
        for (final r in runs)
          MatrixCell(flowrunId: r.id, nodeId: 'n1', status: 'completed'),
        for (final r in runs.skip(SchedulerWindows.matrixPageSize))
          MatrixCell(flowrunId: r.id, nodeId: 'n2', status: 'failed'),
      ],
    );
    return StubSchedulerRepo(
      workflows: [
        SchedulerWorkflowRow(
          id: 'wf_m',
          name: 'M',
          lifecycleState: 'active',
          updatedAt: now,
        ),
      ],
      runs: runs,
      matrixGrid: grid,
    );
  }

  ({ProviderContainer container, StubSchedulerRepo stub}) harness(int n) {
    final stub = repo(n);
    final container = ProviderContainer(
      overrides: [
        sseGatewayProvider.overrideWithValue(null),
        schedulerRepositoryProvider.overrideWithValue(stub),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose family — hold a listener so the window survives between reads. 持监听防自释。
    container.listen(schedulerMatrixWindowProvider('wf_m'), (_, _) {});
    return (container: container, stub: stub);
  }

  test(
    'page 1: the window pages the runs and batch-fetches EXACTLY that page of ids',
    () async {
      final h = harness(60);
      final s = await h.container.read(
        schedulerMatrixWindowProvider('wf_m').future,
      );
      expect(
        s.matrix.cols.length,
        SchedulerWindows.matrixPageSize,
        reason: '首页=页尺 50',
      );
      expect(s.matrix.cols.first.flowrunId, 'fr_000', reason: '正典新→旧');
      expect(s.hasMore, isTrue);
      expect(
        h.stub.matrixAsks.single.length,
        SchedulerWindows.matrixPageSize,
        reason: '一页一批:批查的就是这页的 id 集',
      );
      expect(h.stub.matrixAsks.single.first, 'fr_000');
      // n2 lives only on the unloaded older runs — page 1's row axis must not invent it. n2 未及。
      expect(s.matrix.rows.map((r) => r.nodeId), [
        'n1',
      ], reason: '行轴=已加载列的并集,不替未加载的历史发明行');
    },
  );

  test(
    'loadOlder merges: cols concat, rows first-seen union (older-only node APPENDS), cells pile',
    () async {
      final h = harness(60);
      await h.container.read(schedulerMatrixWindowProvider('wf_m').future);
      await h.container
          .read(schedulerMatrixWindowProvider('wf_m').notifier)
          .loadOlder();

      final s = h.container.read(schedulerMatrixWindowProvider('wf_m')).value!;
      expect(s.matrix.cols.length, 60, reason: '旧页并入');
      expect(s.matrix.cols.last.flowrunId, 'fr_059', reason: '最旧列在正典尾');
      expect(
        s.matrix.rows.map((r) => r.nodeId),
        ['n1', 'n2'],
        reason: '首见并集:只有旧 run 才有的节点**追加在后**,绝不插队(后端首次出现序同律)',
      );
      expect(s.matrix.cells.length, 60 + 10, reason: '格相接(n1×60 + n2×10)');
      expect(s.hasMore, isFalse, reason: '翻尽');

      // Exhausted → a further slide is a no-op, not a wire call. 翻尽后再滑=零线缆。
      final asks = h.stub.matrixAsks.length;
      await h.container
          .read(schedulerMatrixWindowProvider('wf_m').notifier)
          .loadOlder();
      expect(h.stub.matrixAsks.length, asks, reason: 'hasMore=false 守卫住了');
    },
  );

  test(
    'a failed older page keeps the window STANDING (busy flag dropped, nothing merged)',
    () async {
      final h = harness(60);
      await h.container.read(schedulerMatrixWindowProvider('wf_m').future);
      h.stub.failMatrix = true;
      await h.container
          .read(schedulerMatrixWindowProvider('wf_m').notifier)
          .loadOlder();

      final s = h.container.read(schedulerMatrixWindowProvider('wf_m')).value!;
      expect(
        s.matrix.cols.length,
        SchedulerWindows.matrixPageSize,
        reason: '窗照旧站着',
      );
      expect(s.loadingOlder, isFalse, reason: 'busy 旗收回');
      expect(s.hasMore, isTrue, reason: '旧页是可选历史,下次还能再试');
    },
  );

  test(
    'mid-flight range change DROPS the stale older page — two ranges never mix (复审 [4])',
    () async {
      final h = harness(60);
      await h.container.read(schedulerMatrixWindowProvider('wf_m').future);

      // The older page is slow; while it flies, the capsule switches range → build() replaces the
      // window. 旧页在飞,胶囊换范围 → build() 换窗。
      h.stub.matrixLatency = const Duration(milliseconds: 80);
      final older = h.container
          .read(schedulerMatrixWindowProvider('wf_m').notifier)
          .loadOlder();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      h.container
          .read(schedulerTimeRangeProvider.notifier)
          .set(const AnPresetRange(AnTimePreset.h24));
      await h.container.read(schedulerMatrixWindowProvider('wf_m').future);
      h.stub.matrixLatency = Duration.zero;
      await older;

      final s = h.container.read(schedulerMatrixWindowProvider('wf_m')).value!;
      expect(
        s.matrix.cols.length,
        SchedulerWindows.matrixPageSize,
        reason: '旧范围的一页被丢弃——绝不把两个范围的历史混进一扇窗',
      );
    },
  );
}
