import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/relation.dart';
import '../../../core/contract/entities/scheduler_matrix.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/trigger_schedule.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/page.dart';
import '../scheduler_windows.dart';
import 'scheduler_repository.dart';

// The Scheduler demo battery (WRK-069 §15) — PURE DATA seeds covering every rail/overview/home state
// so `make demo` shows the whole grammar with zero backend: running / waiting-on-human (deadline soon
// · no deadline · soft-deleted host) / consecutive failures / self-healed / cron-scheduled / paused
// trigger / never-ran / inactive / a 25+-run keyset-paged history across every origin (cron / manual
// / chat / webhook / legacy-null) with failures carrying real errors + per-run node rows (the linked
// pane's gantt/graph). Deterministic relative to [_anchor] (the repo shifts seed times against the
// real clock at read so «2h ago» stays honest). S2b/S3: decide / cancel / replay / runNow / kill /
// pause / resume are STATEFUL so the demo walks the full grammar without a backend.
// demo 电池:纯数据种子铺全态;种子时刻相对固定锚,读时对真钟平移。S3 加:25+ 条多页 run 史(全来源+
// 失败带错误+逐 run 节点行供联动格)、paused trigger、replay/runNow/kill/pause/resume 全有状态。
final _anchor = DateTime.utc(2026, 7, 16, 9);

/// The demo's ONE clock reading, taken once — so every seam re-bases every seed against the SAME
/// instant, and two seams asked about one fact answer with one value.
///
/// **This is fidelity, not tidiness.** Re-reading `DateTime.now()` per call made a cron tick a function
/// of WHEN YOU ASKED: `listTriggers` and `trigger-schedule` project the same 「每日 09:00」 tick and
/// returned instants **919µs apart** (measured), so the 「下次调度」 tile could never find its own tick on
/// the track and was inert in the demo forever — a state the demo is required to reach (D 轨:demo 全展示).
/// The backend has this property for free and that is exactly why the tile trusts it: `cron.Next(expr,
/// now)` is a pure function of the EXPRESSION, so two reads a moment apart land on the same instant.
/// A fixture whose ticks slide with the read clock is not a cheaper backend — it is a different one.
///
/// Pinning also makes every relative label monotonic, which is what a clock does: a refetch used to
/// slide `createdAt` forward and reset 「waiting 18m」 to 18m for ever.
///
/// demo 的**唯一**一次读钟,只读一次——故每条缝把每个种子**对同一个瞬间**重定基,两条缝对同一个事实给出同一个值。
/// **这是保真,不是整洁**:每次调用重读 `DateTime.now()`,会让一个 cron 刻度变成**「你什么时候问」的函数**——
/// listTriggers 与 trigger-schedule 投影同一个「每日 09:00」刻度,实测返回的两个时刻相差 **919µs**,于是
/// 「下次调度」牌**永远**在它自己的轨上找不到自己的刻度、在 demo 里永久惰性——而那是 demo 必须到达的状态
/// (D 轨:demo 全展示)。后端**白送**这条性质,而牌信任的正是它:`cron.Next(expr, now)` 是**表达式**的纯函数,
/// 故相隔一瞬的两次读落在同一个时刻上。刻度随读钟滑动的 fixture 不是一个更便宜的后端,是**另一个**后端。
/// 钉住它顺带让每个相对标签单调——那才是钟该干的事:以前一次重取就把 createdAt 往前滑、把「waiting 18m」
/// 永远重置回 18m。
final _base = DateTime.now();

DateTime _shift(DateTime seed) {
  // Seeds are authored against _anchor; at read we re-base them onto [_base] so relative labels
  // («2h ago» / «in 3m») render as designed regardless of when the demo runs.
  // 以锚点写种子,读时重定基到 _base。
  final offset = seed.difference(_anchor);
  return _base.add(offset);
}

class FixtureSchedulerRepository implements SchedulerRepository {
  /// Decided approvals ('$flowrunId/$nodeId') — gone from the inbox; deciding twice loses the
  /// first-wins race (422). 已决集合:收件箱除名,二决 422。
  final Set<String> _decided = {};

  /// Cancelled run ids — gone from the running zone (and their parked rows from the inbox, the
  /// backend's CancelParkedNodes); cancelling a non-running run earns 422. 已取消集合。
  final Set<String> _cancelled = {};

  /// Replayed run ids — a failed run flips back to running (`:replay`); replaying a non-failed run
  /// earns the honest 422. 已重放集合:失败翻回 running,非失败 422。
  final Set<String> _replayed = {};

  /// Killed workflows — lifecycle flips inactive + every running run cancels. 已终止 workflow。
  final Set<String> _killed = {};

  /// Runtime pause switch overrides (工单⑦) — id → paused. 暂停开关覆写。
  final Map<String, bool> _paused = {};

  /// «Run now» births (newest first). 手动新 run。
  final List<Flowrun> _manualRuns = [];
  int _runSeq = 0;

  String _statusOf(Flowrun r) {
    if (_cancelled.contains(r.id)) return 'cancelled';
    if (_replayed.contains(r.id) && r.status == 'failed') return 'running';
    return r.status;
  }

  @override
  Future<List<SchedulerWorkflowRow>> listWorkflows() async => [
        for (final w in _workflowSeeds())
          _killed.contains(w.id)
              ? SchedulerWorkflowRow(
                  id: w.id,
                  name: w.name,
                  lifecycleState: 'inactive',
                  needsAttention: w.needsAttention,
                  updatedAt: w.updatedAt)
              : w,
      ];

  List<SchedulerWorkflowRow> _workflowSeeds() => [
        SchedulerWorkflowRow(
            id: 'wf_clean', name: '数据清洗流水线', lifecycleState: 'active', updatedAt: _shift(_anchor)),
        SchedulerWorkflowRow(
            id: 'wf_report',
            name: '周报生成',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(days: 1)))),
        SchedulerWorkflowRow(
            id: 'wf_deploy',
            name: '发布上线',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(minutes: 5)))),
        SchedulerWorkflowRow(
            id: 'wf_inventory',
            name: '库存同步',
            lifecycleState: 'active',
            needsAttention: true,
            updatedAt: _shift(_anchor.subtract(const Duration(days: 2)))),
        SchedulerWorkflowRow(
            id: 'wf_archive',
            name: '邮件归档',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(days: 3)))),
        SchedulerWorkflowRow(
            id: 'wf_new', name: '发票对账(新)', lifecycleState: 'active', updatedAt: _shift(_anchor)),
        SchedulerWorkflowRow(
            id: 'wf_draft',
            name: '草稿清理(新)',
            lifecycleState: 'active',
            updatedAt: _shift(_anchor.subtract(const Duration(hours: 5)))),
        SchedulerWorkflowRow(
            id: 'wf_retired',
            name: '旧版同步(停用)',
            lifecycleState: 'inactive',
            updatedAt: _shift(_anchor.subtract(const Duration(days: 30)))),
      ];

  int _runningCount(String wfId) =>
      _allRuns().where((r) => r.workflowId == wfId && _statusOf(r) == 'running').length;

  @override
  Future<SchedulerStats> stats(List<String> workflowIds,
      {int recentN = 10, String since = SchedulerWindows.statsSince, String? until}) async {
    final all = <WorkflowRunStats>[
      // Running now (blue dot). Recent beads mirror the seeded 25+-run history. 在跑;珠串映史。
      WorkflowRunStats(
        workflowId: 'wf_clean',
        running: _runningCount('wf_clean'),
        lastRunAt: _shift(_anchor.subtract(const Duration(seconds: 90))),
        recent: const [
          'running', 'completed', 'completed', 'failed', 'completed',
          'completed', 'completed', 'failed', 'completed', 'completed',
        ],
        successRate: 0.8,
        avgElapsedMs: 42000,
      ),
      // Waiting on a human (amber; a parked approval 18m old, deadline ~2h out). 等人(带期限)。
      WorkflowRunStats(
        workflowId: 'wf_report',
        running: _runningCount('wf_report'),
        parkedNodes: _parkedCount('fr_9a12b34c56d78e90'),
        lastRunAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
        recent: const ['running', 'completed', 'completed'],
        successRate: 1.0,
        avgElapsedMs: 8000,
      ),
      // Waiting on a human, NO deadline (the approval never times out). 等人(无期限)。
      WorkflowRunStats(
        workflowId: 'wf_deploy',
        running: _runningCount('wf_deploy'),
        parkedNodes: _parkedCount('fr_de91f20a3b4c5d6e'),
        lastRunAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
        recent: const ['running', 'completed'],
        successRate: 1.0,
        avgElapsedMs: 15000,
      ),
      // Consecutive failures ×4 (red dot; last failed 1h ago). 连败。
      WorkflowRunStats(
        workflowId: 'wf_inventory',
        running: _runningCount('wf_inventory'),
        lastRunAt: _shift(_anchor.subtract(const Duration(hours: 1))),
        recent: const ['failed', 'failed', 'failed', 'failed', 'completed'],
        successRate: 0.2,
        avgElapsedMs: 12000,
        consecutiveFailures: 4,
      ),
      // Self-healed (had failures, latest completed — no dot). 自愈。
      WorkflowRunStats(
        workflowId: 'wf_archive',
        running: _runningCount('wf_archive'),
        lastRunAt: _shift(_anchor.subtract(const Duration(hours: 26))),
        recent: const ['completed', 'failed', 'failed', 'completed'],
        successRate: 0.5,
        avgElapsedMs: 60000,
      ),
      // wf_new / wf_draft: never ran (no stats row). wf_retired: inactive (no stats row).
    ];
    // Window-aware failed count — DERIVED from the seeds through the SAME predicate the 「24h 失败」 zone
    // lists with ([_failedRunsMatching]), never a hand-tuned bucket, so the tile (`failedRuns.length`)
    // and the count feeding its delta are one number by construction (工单⑮ — the whole point of
    // `completedAfter`). With the seeds this yields 24h=5, 48h=6 (fr_e5f6 landed 30h ago), 7d=6 →
    // delta = 5 − (6−5) = +4 (▲4). It reads the ABSOLUTE instant [since] carries, so it re-derives per
    // window rather than matching a wire word.
    // 窗口感知失败数——从种子经**与**「24h 失败」区列表所用的**同一份**谓词(_failedRunsMatching)**派生**,
    // 绝非手调分档,故牌(failedRuns.length)与喂它 delta 的数**构造上**是一个数(工单⑮ completedAfter 的全部
    // 意义)。当前种子:24h=5、48h=6(fr_e5f6 落定于 30h 前)、7d=6 → delta=5−(6−5)=+4(▲4)。
    final failedSince = _failedRunsMatching(_sinceInstant(since)).length;
    // Live totals track the stateful cancels/decides (the demo stays honest after an action).
    // totals 跟随有状态操作(动作之后 demo 不撒谎)。
    final running = [for (final s in all) s.running].fold(0, (a, b) => a + b);
    final parked = [for (final s in all) s.parkedNodes].fold(0, (a, b) => a + b);
    return SchedulerStats(
      totals: SchedulerTotals(
          running: running,
          completedSince: 23,
          failedSince: failedSince,
          parkedNodes: parked,
          // 工单⑭ — counted through THE predicate, so this number and the page `listFirings` serves for
          // the same window are the same rows by construction, exactly as the backend's shared
          // `firingQuery` makes them. 经**那份**谓词计数,故此数与 listFirings 对同一窗口给出的那页**构造上**
          // 是同一批行——正如后端共用的 firingQuery 所保证的那样。
          missed: _firingsMatching(
                  status: FiringStatus.missed, createdAfter: _sinceInstant(since))
              .length),
      byWorkflow: workflowIds.isEmpty
          ? all
          : [for (final s in all) if (workflowIds.contains(s.workflowId)) s],
    );
  }

  int _parkedCount(String flowrunId) {
    if (_cancelled.contains(flowrunId)) return 0;
    return _inboxSeeds().where((r) => r.node.flowrunId == flowrunId && !_decided.contains('${r.node.flowrunId}/${r.node.nodeId}')).length;
  }

  /// The seeded run rows (newest first, mirroring the backend's keyset order). wf_clean carries a
  /// 25+-run history across every origin (multi-page at limit 25) so the S3 big table exercises
  /// keyset paging, the origin filter and the source phrases with zero backend.
  /// 种子 run 行(新→旧):wf_clean 带 25+ 条全来源 run 史(limit 25 下必翻页)。
  List<Flowrun> _allRuns() {
    final runs = <Flowrun>[
      ..._manualRuns,
      // wf_clean: the live run (blue, started 90s ago, cron-born). 在跑。
      Flowrun(
        id: 'fr_0a1b2c3d4e5f6071',
        workflowId: 'wf_clean',
        versionId: 'wfv_clean00000007',
        pinnedRefs: const {'fetch': 'fnv_fetch00000003', 'analyze': 'agv_analyze000005'},
        origin: 'cron',
        triggerId: 'tr_cron_clean',
        firingId: 'trf_clean00000091',
        status: 'running',
        startedAt: _shift(_anchor.subtract(const Duration(seconds: 90))),
        updatedAt: _shift(_anchor),
      ),
      // wf_clean: the LOOP run — analyze ×3, the last turn holding a 650KB result (§15 大 I/O 注入).
      // The S4 flagship folds it to one ×3 line that unfolds per turn. 循环 run:analyze ×3,末轮
      // 650KB;旗舰折成一行 ×3、可逐轮展开。
      Flowrun(
        id: 'fr_loop00000000d1',
        workflowId: 'wf_clean',
        versionId: 'wfv_clean00000007',
        pinnedRefs: const {'analyze': 'agv_analyze000005'},
        origin: 'manual',
        status: 'completed',
        startedAt: _shift(_anchor.subtract(const Duration(minutes: 12))),
        completedAt: _shift(_anchor.subtract(const Duration(minutes: 12))).add(const Duration(seconds: 22)),
        updatedAt: _shift(_anchor.subtract(const Duration(minutes: 12))),
      ),
      // wf_clean: the COLD-OPEN run (§5.5) — genuinely mid-flight with NO node row yet (the engine
      // has not settled anything). Deep-linking into it must render the pinned graph + an honest
      // empty ledger, never a blank page and never a fake «running» authority.
      // 冷打开态:真在飞但还没有任何节点行——深链进去必须渲钉版图 + 诚实空台账,绝不空白也绝不装权威。
      Flowrun(
        id: 'fr_cold00000000e1',
        workflowId: 'wf_clean',
        versionId: 'wfv_clean00000007',
        origin: 'cron',
        triggerId: 'tr_cron_clean',
        status: 'running',
        startedAt: _shift(_anchor.subtract(const Duration(seconds: 4))),
        updatedAt: _shift(_anchor),
      ),
      // The ORPHAN run (§5.7) — its host workflow was soft-deleted, so it is absent from the rail and
      // getWorkflow 404s, yet the archive page stays reachable (the inbox still carries its parked
      // approval). Tombstone head; every action but replay is off.
      // 孤儿 run:宿主已软删(rail 里没有、getWorkflow 404),但档案页仍可达(收件箱里还有它的 parked
      // 审批)。头戴墓碑,除 replay 外动作全禁。
      Flowrun(
        id: 'fr_gh05t16273a4b5c6',
        workflowId: 'wf_ghost',
        versionId: 'wfv_ghost000000001',
        origin: 'cron',
        status: 'running',
        startedAt: _shift(_anchor.subtract(const Duration(days: 2))),
        updatedAt: _shift(_anchor.subtract(const Duration(days: 2))),
      ),
      // wf_clean: a chat-born run — conversation coordinate rides the row (工单①). 对话来源。
      Flowrun(
        id: 'fr_chat00000000a1',
        workflowId: 'wf_clean',
        origin: 'chat',
        conversationId: 'cv_demo000000000001',
        status: 'completed',
        startedAt: _shift(_anchor.subtract(const Duration(minutes: 40))),
        completedAt: _shift(_anchor.subtract(const Duration(minutes: 39, seconds: 18))),
        updatedAt: _shift(_anchor.subtract(const Duration(minutes: 39))),
      ),
      // wf_clean: a webhook-born FAILED run (error first line feeds the row's danger sub). webhook 失败。
      Flowrun(
        id: 'fr_hook0000000fa1',
        workflowId: 'wf_clean',
        origin: 'webhook',
        triggerId: 'tr_hook_invoice',
        status: 'failed',
        error: 'HTTP 400 Bad Request: invoice payload missing "amount"\nat notify step',
        startedAt: _shift(_anchor.subtract(const Duration(hours: 2))),
        completedAt: _shift(_anchor.subtract(const Duration(hours: 2))),
        updatedAt: _shift(_anchor.subtract(const Duration(hours: 2))),
      ),
      // wf_clean: a manual run. 手动。
      Flowrun(
        id: 'fr_manual000000b2',
        workflowId: 'wf_clean',
        origin: 'manual',
        status: 'completed',
        startedAt: _shift(_anchor.subtract(const Duration(hours: 3))),
        completedAt: _shift(_anchor.subtract(const Duration(hours: 3))).add(const Duration(seconds: 39)),
        updatedAt: _shift(_anchor.subtract(const Duration(hours: 3))),
      ),
      // wf_clean: a pre-provenance row — origin NULL on the wire → the honest unknown face. 旧行。
      Flowrun(
        id: 'fr_legacy000000c3',
        workflowId: 'wf_clean',
        status: 'completed',
        startedAt: _shift(_anchor.subtract(const Duration(days: 6))),
        completedAt: _shift(_anchor.subtract(const Duration(days: 6))).add(const Duration(seconds: 41)),
        updatedAt: _shift(_anchor.subtract(const Duration(days: 6))),
      ),
    ];
    // wf_clean cron history: 96 hourly runs (~4 天,周期性失败) — enough pages (10/页 → 10+) to
    // exhibit the FOLDED pager + quick jumper (WRK-070 B4;用户 0718「来一个很多执行记录的」).
    // cron 史 96 条:页数破折叠阈,折叠翻页器+跳页在 demo 可见。
    for (var i = 0; i < 96; i++) {
      final started = _anchor.subtract(Duration(hours: 4 + i));
      final failed = i % 12 == 3;
      runs.add(Flowrun(
        id: 'fr_hist${i.toString().padLeft(12, '0')}',
        workflowId: 'wf_clean',
        origin: 'cron',
        triggerId: 'tr_cron_clean',
        status: failed ? 'failed' : 'completed',
        error: failed ? 'timeout: LLM did not answer within 30s\nanalyze step aborted' : null,
        replayCount: i == 3 ? 1 : 0,
        startedAt: _shift(started),
        completedAt: _shift(started.add(Duration(seconds: failed ? 8 : 42))),
        updatedAt: _shift(started.add(Duration(seconds: failed ? 8 : 42))),
      ));
    }
    runs.addAll([
      // wf_deploy: running but parked on a no-deadline approval. 等人(running∧parked,无期限)。
      Flowrun(
        id: 'fr_de91f20a3b4c5d6e',
        workflowId: 'wf_deploy',
        origin: 'manual',
        status: 'running',
        startedAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
        updatedAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
      ),
      // wf_report: running but parked on an approval (the waiting-on-human run). 等人(running∧parked)。
      Flowrun(
        id: 'fr_9a12b34c56d78e90',
        workflowId: 'wf_report',
        origin: 'cron',
        triggerId: 'tr_cron_report',
        status: 'running',
        startedAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
        updatedAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
      ),
      // wf_inventory: the ×4 streak — latest failed run carries the error the aggregation quotes.
      // 连败最新失败 run(错误首句来源)。
      // Both carry the cron that BORE them (tr_cron_inventory, 6h apart = its cadence) — a cron-origin
      // run with no triggerId is a run nothing fired. 两条都带把它们生出来的那个 cron(相隔 6h=它的节拍)
      // ——cron 来源却无 triggerId 的 run,是没有任何东西触发过的 run。
      Flowrun(
        id: 'fr_c3d4e5f607182930',
        workflowId: 'wf_inventory',
        origin: 'cron',
        triggerId: 'tr_cron_inventory',
        status: 'failed',
        error: 'HTTP 502 Bad Gateway: upstream inventory API did not respond\nretried 3 times',
        replayCount: 1,
        startedAt: _shift(_anchor.subtract(const Duration(hours: 1, seconds: 12))),
        completedAt: _shift(_anchor.subtract(const Duration(hours: 1))),
        updatedAt: _shift(_anchor.subtract(const Duration(hours: 1))),
      ),
      Flowrun(
        id: 'fr_b2c3d4e5f6071829',
        workflowId: 'wf_inventory',
        origin: 'cron',
        triggerId: 'tr_cron_inventory',
        status: 'failed',
        error: 'HTTP 502 Bad Gateway: upstream inventory API did not respond',
        startedAt: _shift(_anchor.subtract(const Duration(hours: 7))),
        completedAt: _shift(_anchor.subtract(const Duration(hours: 7))),
        updatedAt: _shift(_anchor.subtract(const Duration(hours: 7))),
      ),
      // wf_archive: self-healed — latest completed over an older failure. Both name the cron that bore
      // them (tr_cron_archive, now paused: it fired these two, then a human stopped it — which is why
      // its lastFiredAt is this newest run's, never older than the runs it fired).
      // 自愈:两条都点名把它们生出来的 cron(tr_cron_archive,现已暂停:它先发了这两次,然后被人停掉——
      // 故它的 lastFiredAt 就是这条最新 run 的时刻,绝不早于它自己发出去的 run)。
      Flowrun(
        id: 'fr_d4e5f60718293a4b',
        workflowId: 'wf_archive',
        origin: 'cron',
        triggerId: 'tr_cron_archive',
        status: 'completed',
        startedAt: _shift(_anchor.subtract(const Duration(hours: 26))),
        completedAt: _shift(_anchor.subtract(const Duration(hours: 26))),
        updatedAt: _shift(_anchor.subtract(const Duration(hours: 26))),
      ),
      Flowrun(
        id: 'fr_e5f60718293a4b5c',
        workflowId: 'wf_archive',
        origin: 'cron',
        triggerId: 'tr_cron_archive',
        status: 'failed',
        error: 'disk full: /var/anselm/archive',
        startedAt: _shift(_anchor.subtract(const Duration(hours: 30))),
        completedAt: _shift(_anchor.subtract(const Duration(hours: 30))),
        updatedAt: _shift(_anchor.subtract(const Duration(hours: 30))),
      ),
    ]);
    return [
      for (final r in runs)
        Flowrun(
          id: r.id,
          workflowId: r.workflowId,
          versionId: r.versionId,
          pinnedRefs: r.pinnedRefs,
          triggerId: r.triggerId,
          firingId: r.firingId,
          origin: r.origin,
          conversationId: r.conversationId,
          status: _statusOf(r),
          replayCount: r.replayCount,
          error: _statusOf(r) == 'failed' ? r.error : null,
          startedAt: r.startedAt,
          completedAt: _statusOf(r) == 'running' ? null : r.completedAt,
          updatedAt: r.updatedAt,
        ),
    ];
  }

  @override
  Future<List<Flowrun>> listRunningRuns() async =>
      [for (final r in _allRuns()) if (_statusOf(r) == 'running') r];

  /// THE failed-in-window predicate, expressed ONCE — shared by [listFailedSince] (the 「24h 失败」
  /// zone's rows) and [stats]' `totals.failedSince` (the tile's delta source), exactly as the backend's
  /// `failedSince` and `?completedAfter` share one `completed_at >= ?` (工单⑮). Two copies would be a
  /// bug with a timer on it: the tile says 5, the zone it opens shows 4. Newest-LANDED first (the
  /// window's axis is completed_at). A running run has completedAt=null and is dropped, as the wire
  /// `NULL >= ?` drops it. 那份「窗内失败」谓词,只表达一次——listFailedSince(区的行)与 stats 的
  /// failedSince(牌的 delta 源)共用,正如后端 failedSince 与 ?completedAfter 共用一个 `completed_at >= ?`。
  List<Flowrun> _failedRunsMatching(DateTime since) => [
        for (final r in _allRuns())
          if (r.status == 'failed' && r.completedAt != null && !r.completedAt!.isBefore(since)) r,
      ]..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

  @override
  Future<List<Flowrun>> listFailedSince(DateTime completedAfter) async =>
      _failedRunsMatching(completedAfter);

  @override
  Future<Page<Flowrun>> listFlowruns(
      {required String workflowId,
      String? status,
      String? origin,
      String? triggerId,
      DateTime? startedAfter,
      DateTime? startedBefore,
      DateTime? completedAfter,
      DateTime? completedBefore,
      String? cursor,
      int? limit}) async {
    final rows = [
      for (final r in _allRuns())
        if (r.workflowId == workflowId &&
            (status == null || r.status == status) &&
            (origin == null || r.origin == origin) &&
            (triggerId == null || r.triggerId == triggerId) &&
            (startedAfter == null || (r.startedAt != null && !r.startedAt!.isBefore(startedAfter))) &&
            (startedBefore == null || (r.startedAt != null && r.startedAt!.isBefore(startedBefore))) &&
            // completed_at window (工单⑮) — drops the unlanded (null completed_at), like NULL >= ?.
            (completedAfter == null ||
                (r.completedAt != null && !r.completedAt!.isBefore(completedAfter))) &&
            (completedBefore == null ||
                (r.completedAt != null && r.completedAt!.isBefore(completedBefore))))
          r,
    ]..sort((a, b) {
        final sa = a.startedAt, sb = b.startedAt;
        if (sa == null || sb == null) return sa == sb ? 0 : (sa == null ? 1 : -1);
        return sb.compareTo(sa);
      });
    // Keyset paging mirrored as an offset cursor (fixture-internal; the wire shape is opaque anyway).
    // keyset 以偏移游标模拟(fixture 内部;线缆游标本就不透明)。
    final offset = cursor != null ? (int.tryParse(cursor) ?? 0) : 0;
    final cap = limit ?? 25;
    final page = rows.skip(offset).take(cap).toList();
    final hasMore = offset + page.length < rows.length;
    return Page(items: page, nextCursor: hasMore ? '${offset + page.length}' : null, hasMore: hasMore);
  }

  @override
  Future<OffsetPage<Flowrun>> listFlowrunsPage(
      {required String workflowId,
      String? status,
      String? origin,
      DateTime? startedAfter,
      DateTime? startedBefore,
      required int offset,
      required int limit}) async {
    // The offset page rides the SAME filter+sort path (线缆同律:同过滤同序,total=全集数). 同径。
    final all = await listFlowruns(
        workflowId: workflowId,
        status: status,
        origin: origin,
        startedAfter: startedAfter,
        startedBefore: startedBefore,
        limit: 1 << 30);
    final page = all.items.skip(offset).take(limit).toList();
    return OffsetPage(
        items: page, total: all.items.length, hasMore: offset + page.length < all.items.length);
  }

  /// The three inbox seed FORMS (工单④): deadline soon (~2h, amber countdown) / no deadline (no
  /// countdown) / soft-deleted host (name fell back to the bare id on the backend join; overdue
  /// deadline shows the danger face). 收件箱三形种子:将超时/无期限/宿主软删名回落(且已超时)。
  List<SchedulerInboxRow> _inboxSeeds() => [
        SchedulerInboxRow(
          node: FlowrunNode(
            id: 'frn_report_approve',
            flowrunId: 'fr_9a12b34c56d78e90',
            nodeId: 'approve_send',
            kind: 'approval',
            status: 'parked',
            result: const {'rendered': '本周报可以发出吗?', 'allowReason': true},
            createdAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
            updatedAt: _shift(_anchor.subtract(const Duration(minutes: 18))),
          ),
          workflowId: 'wf_report',
          workflowName: '周报生成',
          deadline: _shift(_anchor.add(const Duration(hours: 2))),
        ),
        SchedulerInboxRow(
          node: FlowrunNode(
            id: 'frn_deploy_approve',
            flowrunId: 'fr_de91f20a3b4c5d6e',
            nodeId: 'approve_deploy',
            kind: 'approval',
            status: 'parked',
            result: const {'rendered': '可以发布 v2.4.1 到生产吗?', 'allowReason': false},
            createdAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
            updatedAt: _shift(_anchor.subtract(const Duration(minutes: 5))),
          ),
          workflowId: 'wf_deploy',
          workflowName: '发布上线',
          // No deadline: the approval never times out → no countdown. 无期限,不渲倒计时。
        ),
        SchedulerInboxRow(
          node: FlowrunNode(
            id: 'frn_ghost_approve',
            flowrunId: 'fr_gh05t16273a4b5c6',
            nodeId: 'approve_cleanup',
            kind: 'approval',
            status: 'parked',
            result: const {'rendered': '继续清理 2019 年之前的归档?', 'allowReason': true},
            createdAt: _shift(_anchor.subtract(const Duration(days: 2))),
            updatedAt: _shift(_anchor.subtract(const Duration(days: 2))),
          ),
          // The host workflow was soft-deleted — the backend's name join fell back to the bare id.
          // 宿主软删,名回落裸 id。
          workflowId: 'wf_ghost',
          workflowName: 'wf_ghost',
          deadline: _shift(_anchor.subtract(const Duration(minutes: 30))),
        ),
      ];

  @override
  Future<List<SchedulerInboxRow>> listInbox() async => [
        for (final r in _inboxSeeds())
          if (!_decided.contains('${r.node.flowrunId}/${r.node.nodeId}') &&
              !_cancelled.contains(r.node.flowrunId))
            r,
      ];

  @override
  Future<FlowrunComposite> decideApproval(String flowrunId, String nodeId,
      {required String decision, String? reason}) async {
    final key = '$flowrunId/$nodeId';
    final live = await listInbox();
    if (!live.any((r) => r.node.flowrunId == flowrunId && r.node.nodeId == nodeId)) {
      // Lost the first-wins race (or the node never parked) — the honest 422. 输家诚实 422。
      throw const ApiException(
          code: 'FLOWRUN_APPROVAL_NOT_PARKED',
          message: 'approval is not parked',
          httpStatus: 422);
    }
    _decided.add(key);
    final run = _allRuns().firstWhere((r) => r.id == flowrunId);
    return FlowrunComposite(flowrun: run);
  }

  @override
  Future<FlowrunComposite> cancelRun(String flowrunId) async {
    final run = _allRuns().where((r) => r.id == flowrunId).firstOrNull;
    if (run == null || run.status != 'running') {
      throw const ApiException(
          code: 'FLOWRUN_NOT_CANCELLABLE',
          message: 'only a running flowrun can be cancelled',
          httpStatus: 422);
    }
    _cancelled.add(flowrunId);
    return FlowrunComposite(
        flowrun: Flowrun(
            id: run.id, workflowId: run.workflowId, status: 'cancelled', updatedAt: DateTime.now()));
  }

  @override
  Future<FlowrunComposite> replayRun(String flowrunId) async {
    final run = _allRuns().where((r) => r.id == flowrunId).firstOrNull;
    if (run == null || run.status != 'failed') {
      // cancelled is a final terminal — only failed replays (api.md). 只有 failed 可重放。
      throw const ApiException(
          code: 'FLOWRUN_NOT_REPLAYABLE',
          message: 'only a failed flowrun can be replayed',
          httpStatus: 422);
    }
    _replayed.add(flowrunId);
    return getRunFull(flowrunId);
  }

  @override
  Future<String> runNow(String workflowId) async {
    final id = 'fr_now${(_runSeq++).toString().padLeft(12, '0')}';
    _manualRuns.insert(
      0,
      Flowrun(
        id: id,
        workflowId: workflowId,
        origin: 'manual',
        status: 'running',
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return id;
  }

  @override
  Future<WorkflowEntity> killWorkflow(String workflowId) async {
    _killed.add(workflowId);
    for (final r in _allRuns()) {
      if (r.workflowId == workflowId && r.status == 'running') _cancelled.add(r.id);
    }
    return _workflowEntity(workflowId);
  }

  @override
  Future<WorkflowEntity> getWorkflow(String id) async => _workflowEntity(id);

  /// wf_clean carries the 4-node graph the linked pane's graph face renders; the rest are bare
  /// entities (no active version → the honest «no graph» sentence). wf_clean 带 4 节点图;其余裸实体。
  WorkflowEntity _workflowEntity(String id) {
    final row = _workflowSeeds().where((w) => w.id == id).firstOrNull;
    if (row == null) {
      throw const ApiException(
          code: 'WORKFLOW_NOT_FOUND', message: 'workflow not found', httpStatus: 404);
    }
    final created = _shift(_anchor.subtract(const Duration(days: 30)));
    return WorkflowEntity(
      id: row.id,
      name: row.name,
      active: !_killed.contains(id) && row.lifecycleState == 'active',
      lifecycleState: _killed.contains(id) ? 'inactive' : row.lifecycleState,
      needsAttention: row.needsAttention,
      createdAt: created,
      updatedAt: row.updatedAt ?? created,
      activeVersion: id == 'wf_clean'
          ? WorkflowVersion(
              id: 'wfv_clean00000007',
              workflowId: 'wf_clean',
              version: 7,
              createdAt: created,
              updatedAt: created,
              graphParsed: _cleanGraph,
            )
          : null,
    );
  }

  static const _cleanGraph = Graph(
    nodes: [
      Node(id: 'fetch', kind: NodeKind.action, ref: 'fn_fetch'),
      Node(id: 'gate', kind: NodeKind.control, ref: 'ctl_gate'),
      Node(id: 'analyze', kind: NodeKind.agent, ref: 'ag_analyze'),
      Node(id: 'notify', kind: NodeKind.action, ref: 'fn_notify'),
    ],
    edges: [
      Edge(id: 'e1', from: 'fetch', to: 'gate'),
      Edge(id: 'e2', from: 'gate', fromPort: 'high', to: 'analyze'),
      Edge(id: 'e3', from: 'analyze', to: 'notify'),
    ],
  );

  @override
  Future<Flowrun> getRun(String flowrunId) async {
    final run = _allRuns().where((r) => r.id == flowrunId).firstOrNull;
    if (run == null) {
      throw const ApiException(
          code: 'FLOWRUN_NOT_FOUND', message: 'flowrun not found', httpStatus: 404);
    }
    return run;
  }

  @override
  Future<FlowrunComposite> getRunFull(String flowrunId) async {
    final run = await getRun(flowrunId);
    return FlowrunComposite(flowrun: run, nodes: _nodesFor(run));
  }

  /// Per-run node rows for the linked pane + the S4 flagship — derived from the run's own stamps so
  /// gantt spans stay honest under _shift. Every scheduled row carries the ⑫ QUEUE STAMPS
  /// (readyAt ≤ startedAt ≤ completedAt), so the demo's gantt shows the real three-part bar; the
  /// legacy run (fr_legacy…) deliberately carries NONE, so the two-part degradation is on screen
  /// too. completed runs walk all 4 nodes; failed runs stop at analyze (notify 未及); the live/parked
  /// runs carry their partial walks (analyze is then the SYNTHESIZED front — the 推测执行中 state).
  /// 逐 run 节点行:按 run 自身时刻派生;每个被调度的行都带 ⑫ 排队戳(故 demo 甘特出真三段条),而旧行
  /// 刻意不带(两段回退也在屏上);失败停在 analyze;活/停车 run 走到一半(analyze 即推测前沿)。
  List<FlowrunNode> _nodesFor(Flowrun run) {
    final started = run.startedAt;
    if (started == null) return const [];
    // A run born before the queue columns — no stamps, so its bars degrade honestly. 旧行:无戳。
    final legacy = run.id == 'fr_legacy000000c3';
    FlowrunNode node(String nodeId, String kind, String status, Duration at, Duration? span,
            {Map<String, Object?> result = const {},
            String? error,
            int iteration = 0,
            Duration queued = const Duration(milliseconds: 120)}) =>
        FlowrunNode(
          id: 'frn_${run.id}_${nodeId}_$iteration',
          flowrunId: run.id,
          nodeId: nodeId,
          iteration: iteration,
          kind: kind,
          status: status,
          result: result,
          error: error,
          // readyAt = when the walk found it ready; startedAt = when the engine picked it up; the
          // gap between them IS the grey queue segment (工单⑫). readyAt/startedAt 之间的空档就是灰
          // 排队段。
          readyAt: legacy ? null : started.add(at - queued),
          startedAt: legacy ? null : started.add(at),
          // createdAt = the row's WRITE time = the terminal / park moment (never the node's start).
          // createdAt=行写入时刻=终态/停车时刻,绝非节点起点。
          createdAt: started.add(span != null ? at + span : at),
          completedAt: span != null ? started.add(at + span) : null,
          updatedAt: started.add(at),
        );

    // The 650KB payload (§15 大 I/O 注入) — physically isolated in the right island's JSON tree and
    // NOWHERE else, so this seed is the page's proof that a monstrous result costs the flagship
    // nothing. 650KB 大 I/O:物理隔离在右岛 JSON 树,别处不渲——本种子就是「巨大结果不拖垮旗舰」的证明。
    Map<String, Object?> bigResult() => {
          'rows': 4200,
          'digest': 'sha256:${'a' * 64}',
          'payload': 'x' * 650000,
        };

    switch (run.status) {
      case 'failed':
        return [
          node('fetch', 'action', 'completed', Duration.zero, const Duration(milliseconds: 900)),
          node('gate', 'control', 'completed', const Duration(milliseconds: 950),
              const Duration(milliseconds: 30), result: const {'__port': 'high'}),
          node('analyze', 'agent', 'failed', const Duration(seconds: 1),
              const Duration(seconds: 5),
              error: run.error,
              queued: const Duration(milliseconds: 800)),
        ];
      case 'running':
        // A live run with NO rows at all is the COLD-OPEN case (§5.5): deep-linking into it must not
        // blank out — the page renders the pinned graph's stubs + an honest empty ledger rather than
        // pretending. 无任何行的活 run=冷打开态:深链进去绝不空白,渲钉版图占位 + 诚实空台账。
        if (run.id == 'fr_cold00000000e1') return const [];
        // Parked runs surface their gate; plain live runs have walked fetch+gate (analyze is the
        // synthesized-running front). parked 露闸;活 run 走完前两节点。
        final parked = _inboxSeeds().where((r) => r.node.flowrunId == run.id).firstOrNull;
        return [
          node('fetch', 'action', 'completed', Duration.zero, const Duration(milliseconds: 900)),
          node('gate', 'control', 'completed', const Duration(milliseconds: 950),
              const Duration(milliseconds: 30), result: const {'__port': 'high'}),
          if (parked != null) parked.node,
        ];
      case 'completed':
        // The loop run: analyze ran three turns (§5.4 ×N 折叠) and its last turn returned the 650KB
        // monster. 循环 run:analyze 跑了三轮,末轮返回 650KB 巨物。
        if (run.id == 'fr_loop00000000d1') {
          return [
            node('fetch', 'action', 'completed', Duration.zero, const Duration(milliseconds: 900)),
            node('gate', 'control', 'completed', const Duration(milliseconds: 950),
                const Duration(milliseconds: 30), result: const {'__port': 'high'}),
            for (var i = 0; i < 3; i++)
              node('analyze', 'agent', 'completed', Duration(seconds: 1 + i * 6),
                  const Duration(seconds: 5),
                  iteration: i,
                  result: i == 2 ? bigResult() : {'turn': i},
                  queued: Duration(milliseconds: 200 + i * 150)),
            node('notify', 'action', 'completed', const Duration(seconds: 20),
                const Duration(seconds: 2)),
          ];
        }
        return [
          node('fetch', 'action', 'completed', Duration.zero, const Duration(milliseconds: 900)),
          node('gate', 'control', 'completed', const Duration(milliseconds: 950),
              const Duration(milliseconds: 30), result: const {'__port': 'high'}),
          node('analyze', 'agent', 'completed', const Duration(seconds: 1),
              const Duration(seconds: 34)),
          node('notify', 'action', 'completed', const Duration(seconds: 36),
              const Duration(seconds: 2)),
        ];
      default:
        // cancelled — whatever had settled before the cut. 取消:留已落定的。
        return [
          node('fetch', 'action', 'completed', Duration.zero, const Duration(milliseconds: 900)),
        ];
    }
  }

  /// The ⑤ activity aggregation, derived from the SAME node rows so the demo can never show a gantt
  /// whose exec segment disagrees with its ledger. Only DISPATCHED entity nodes leave audit rows —
  /// control/approval evaluate inline and legitimately have none (the exec segment then falls back
  /// to the row's own stamps, which is the normal path for them, not a degraded one).
  /// ⑤ 活动聚合:与节点行同源派生(demo 里甘特执行段与台账不可能打架)。只有被派发的实体节点留审计行——
  /// control/approval 内联求值、本就没有(执行段回落行自身戳,那是它们的正常路径而非降级)。
  @override
  Future<List<FlowrunActivityRow>> listActivity(String flowrunId) async {
    final run = _allRuns().where((r) => r.id == flowrunId).firstOrNull;
    if (run == null) {
      throw const ApiException(
          code: 'FLOWRUN_NOT_FOUND', message: 'flowrun not found', httpStatus: 404);
    }
    final rows = <FlowrunActivityRow>[];
    for (final n in _nodesFor(run)) {
      // No audit row for inline kinds, nor for a row still parked (nothing executed yet).
      // 内联 kind 与仍 parked 的行无审计行。
      if (n.kind == 'control' || n.kind == 'approval' || n.startedAt == null) continue;
      final end = n.completedAt ?? n.createdAt;
      rows.add(FlowrunActivityRow(
        nodeId: n.nodeId,
        iteration: n.iteration,
        kind: n.kind == 'agent' ? 'agent' : 'function',
        execId: '${n.kind == 'agent' ? 'agx' : 'fne'}_${n.nodeId}${n.iteration}0000000',
        status: n.status == 'failed' ? 'failed' : 'ok',
        readyAt: n.readyAt,
        startedAt: n.startedAt!,
        endedAt: end,
        elapsedMs: end.difference(n.startedAt!).inMilliseconds,
      ));
    }
    // The wire is startedAt ASC (the gantt's natural order). 线缆按 startedAt 升序。
    rows.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return rows;
  }

  /// The PINNED version (§5.2) — wf_clean's v7 is the one graph the demo's runs walked. An unknown
  /// version id 404s, which is exactly what makes the flagship's «couldn't pin the map» banner
  /// reachable in the demo (the orphan run's host is gone, so its version is too).
  /// 钉版:wf_clean 的 v7 即 demo 各 run 走过的图。未知版本 404——旗舰的「钉版取不到」横幅因此在 demo
  /// 里可达(孤儿 run 的宿主没了,版本也没了)。
  @override
  Future<WorkflowVersion> getWorkflowVersion(String workflowId, String versionId) async {
    if (versionId != 'wfv_clean00000007' || workflowId != 'wf_clean') {
      throw const ApiException(
          code: 'WORKFLOW_VERSION_NOT_FOUND', message: 'version not found', httpStatus: 404);
    }
    final created = _shift(_anchor.subtract(const Duration(days: 30)));
    return WorkflowVersion(
      id: 'wfv_clean00000007',
      workflowId: 'wf_clean',
      version: 7,
      createdAt: created,
      updatedAt: created,
      graphParsed: _cleanGraph,
    );
  }

  /// `:triage` — 202 → a conversation id the caller deep-links into chat. The demo hands back the
  /// seeded conversation so `make demo` walks the whole gesture. AI 诊断:返对话 id;demo 给种子对话,
  /// 让整个动作在零后端下走通。
  @override
  Future<String> triageRun(String flowrunId) async => 'cv_demo000000000001';

  @override
  Future<List<TriggerEntity>> listTriggers() async => [
        _trigger(
          id: 'tr_cron_clean',
          name: '每日 09:00',
          kind: TriggerSource.cron,
          config: const {'cron': '0 9 * * *'},
          createdDaysAgo: 30,
          lastFired: _anchor.subtract(const Duration(minutes: 2)),
          nextFire: _anchor.add(const Duration(minutes: 3)),
        ),
        _trigger(
          id: 'tr_hook_invoice',
          name: '发票回调',
          kind: TriggerSource.webhook,
          config: const {'path': '/invoice'},
          createdDaysAgo: 12,
          lastFired: _anchor.subtract(const Duration(hours: 2)),
        ),
        _trigger(
          id: 'tr_cron_report',
          name: '每周一 08:00',
          kind: TriggerSource.cron,
          config: const {'cron': '0 8 * * 1'},
          createdDaysAgo: 60,
          lastFired: _anchor.subtract(const Duration(days: 2)),
          nextFire: _anchor.add(const Duration(days: 5)),
        ),
        // The cron BEHIND the ×4 streak — a cron-born run needs a cron to be born FROM. Without this
        // trigger + its edge, wf_inventory's run rows read «cron · 01:11» while its TRIGGERS zone says
        // «no triggers equip this workflow»: a workflow with no cron, firing on cron. The 6h cadence
        // is the streak's own story — its two seeded failures are exactly 6h apart (D 轨:自洽互锁世界).
        // 连败 ×4 背后的那个 cron:cron 来源的 run 总得有个 cron 把它生出来。没有这条 trigger 与它的边,
        // wf_inventory 的 run 行写着「cron · 01:11」、而同页 TRIGGERS 区却说「没有 trigger 装备本
        // workflow」——一个没有 cron 的 workflow 却有 cron 触发的 run。6 小时的节拍就是连败叙事本身:
        // 两条失败种子恰好相隔 6h(D 轨自洽互锁世界)。
        _trigger(
          id: 'tr_cron_inventory',
          name: '每 6 小时',
          kind: TriggerSource.cron,
          config: const {'cron': '0 */6 * * *'},
          createdDaysAgo: 20,
          lastFired: _anchor.subtract(const Duration(hours: 1, seconds: 12)),
          nextFire: _anchor.add(const Duration(hours: 5)),
        ),
        // Seeded PAUSED (判决①) — greyed card + «已暂停» chip + no nextFireAt; resume flips it live.
        // 种子即暂停:灰卡+已暂停徽+无 nextFireAt;恢复翻活。
        _trigger(
          id: 'tr_cron_archive',
          name: '每晚归档',
          kind: TriggerSource.cron,
          config: const {'cron': '0 1 * * *'},
          createdDaysAgo: 90,
          // = the newest run it fired (fr_d4e5f60718293a4b, -26h). A trigger cannot have last fired
          // BEFORE the runs it fired: the run flagship's ProvenanceLine walks cron → firing → run, and
          // a «上次触发 4 天前» card hanging off a 26h-old cron run is that chain contradicting itself.
          // = 它发出的最新那条 run(-26h)。trigger 的「上次触发」不可能早于它自己发出的 run:旗舰的
          // ProvenanceLine 走 cron → firing → run,一张「上次触发 4 天前」的卡挂在 26h 前的 cron run 上,
          // 就是这条链在自相矛盾。
          lastFired: _anchor.subtract(const Duration(hours: 26)),
          nextFire: _anchor.add(const Duration(hours: 16)),
          seedPaused: true,
        ),
      ];

  TriggerEntity _trigger({
    required String id,
    required String name,
    required TriggerSource kind,
    required Map<String, dynamic> config,
    required int createdDaysAgo,
    DateTime? lastFired,
    DateTime? nextFire,
    bool seedPaused = false,
  }) {
    final paused = _paused[id] ?? seedPaused;
    final created = _shift(_anchor.subtract(Duration(days: createdDaysAgo)));
    return TriggerEntity(
      id: id,
      name: name,
      kind: kind,
      config: config,
      createdAt: created,
      updatedAt: created,
      refCount: 1,
      // Paused reads with the listener cold and nextFireAt ABSENT (工单⑦ wire truth). 暂停即缺席。
      listening: !paused,
      paused: paused,
      lastFiredAt: lastFired != null ? _shift(lastFired) : null,
      nextFireAt: paused || nextFire == null ? null : _shift(nextFire),
    );
  }

  @override
  Future<TriggerEntity> pauseTrigger(String triggerId) => _flipPause(triggerId, true);

  @override
  Future<TriggerEntity> resumeTrigger(String triggerId) => _flipPause(triggerId, false);

  Future<TriggerEntity> _flipPause(String triggerId, bool paused) async {
    // Idempotent, like the backend (repeat = harmless no-op). 幂等。
    _paused[triggerId] = paused;
    final t = (await listTriggers()).where((t) => t.id == triggerId).firstOrNull;
    if (t == null) {
      throw const ApiException(
          code: 'TRIGGER_NOT_FOUND', message: 'trigger not found', httpStatus: 404);
    }
    return t;
  }

  // ── S5: 未来调度 / 矩阵 / 保留线 ──

  /// The forward schedule (工单⑧). Seeded to walk the WHOLE track grammar: a dense `*/5`-flavoured
  /// lane that MUST bucket-fold (else it is sub-pixel confetti), a sparse daily lane, and — the point
  /// of 判决① — the paused trigger contributing NOTHING, exactly as the real endpoint behaves (only
  /// listening, unpaused crons emit ticks). The demo therefore proves the paused lane survives on
  /// LANE data alone, which is the only way the real app can prove it too.
  /// 前瞻调度(⑧)。种子走**整套轨道文法**:一条密集泳道(必须 bucket 折叠,否则是亚像素纸屑)、一条稀疏
  /// 日更泳道,以及——判决① 的要害——**暂停的 trigger 一个刻度都不贡献**,与真端点行为逐字一致(只有监听中
  /// 且未暂停的 cron 发刻度)。故 demo 证明的是「暂停泳道仅靠**泳道**数据存活」,而这正是真 app 唯一能证
  /// 明它的方式。
  @override
  Future<TriggerSchedule> triggerSchedule(
      {String within = SchedulerWindows.trackWithin, int limit = 200}) async {
    final points = <SchedulePoint>[
      // 每日 09:00 — one tick in the next 24h. 日更:窗内一刻。
      SchedulePoint(
        at: _shift(_anchor.add(const Duration(minutes: 3))),
        triggerId: 'tr_cron_clean',
        triggerName: '每日 09:00',
        workflowIds: const ['wf_clean'],
      ),
      SchedulePoint(
        at: _shift(_anchor.add(const Duration(hours: 24))),
        triggerId: 'tr_cron_clean',
        triggerName: '每日 09:00',
        workflowIds: const ['wf_clean'],
      ),
      // 每 6 小时 — the streak's cron keeps its promise inside the window (4 ticks). Its lane must be
      // ON the track for the same reason its trigger card must exist: a workflow whose runs say «cron»
      // has a cron, and the board that shows the schedule must show it.
      // 连败那个 cron 在窗内的 4 刻。它的泳道必须在轨道上,理由与它的 trigger 卡必须存在的理由相同:
      // run 写着「cron」的 workflow 就是有 cron,展示调度的看板就得展示它。
      for (var i = 1; i <= 4; i++)
        SchedulePoint(
          at: _shift(_anchor.add(Duration(hours: 5 + (i - 1) * 6))),
          triggerId: 'tr_cron_inventory',
          triggerName: '每 6 小时',
          workflowIds: const ['wf_inventory'],
        ),
      // A dense sampler — 96 ticks across the window force the bucket fold on screen. 密集:96 刻,
      // 逼出 bucket 折叠。
      for (var i = 1; i <= 96; i++)
        SchedulePoint(
          at: _shift(_anchor.add(Duration(minutes: i * 15))),
          triggerId: 'tr_cron_report',
          triggerName: '每周一 08:00',
          workflowIds: const ['wf_report'],
        ),
    ]..sort((a, b) => a.at.compareTo(b.at));
    // Honest overflow: the seed really does hold more than a small cap would show. 诚实溢出。
    final capped = points.length > limit;
    return TriggerSchedule(
      points: capped ? points.sublist(0, limit) : points,
      truncated: capped,
    );
  }

  /// The firing ledger (工单⑭/判决⑥) — the timeline's PAST half, and the demo's whole disposition
  /// palette in one place: `started` (the tick became a run), `skipped` (overlap policy skip found one
  /// already in flight), `superseded` (buffer_one kept only the newest pending), `shed` (the fan-out
  /// reached a workflow that had been deleted) and `missed` (§15「skipped·superseded·shed 各一」+
  /// 「missed 预留」, now real).
  ///
  /// **The story is one machine's night.** `tr_cron_inventory` fires every 6h; the laptop slept through
  /// the −19h and −13h ticks, so the sweep booked them `missed` on wake and — 判决⑥ — did NOT catch them
  /// up. It woke in time for −7h and −1h, and those two ran and failed: they are exactly the streak the
  /// failure aggregation already tells (6h apart = the cadence itself). So the ✕ marks, the red streak
  /// and the trigger's 6h cron are three views of ONE seeded history, not three unrelated props.
  ///
  /// **Self-consistency the seeds must keep** (D 轨自洽互锁世界, and every one of these is a rule the real
  /// backend enforces): a `missed` row's `createdAt` is the MISSED TICK, never a wake instant, and it
  /// carries NO flowrunId and NO activationId (booking is not an action, and no run was ever made); a
  /// trigger's `lastFiredAt` can never be older than a firing it produced, so every in-window row here
  /// belongs to one of the only two triggers that fired inside 24h; and `missed` is cron-only, because
  /// the sweep only ever looks at unpaused crons.
  ///
  /// firing 账(工单⑭/判决⑥)——时间轴的**过去**半,也是 demo 的处置调色板:started(刻度成了 run)/ skipped
  /// (overlap 跳过:已有 run 在途)/ superseded(buffer_one 只留最新的 pending)/ shed(扇出扇到了一个已被删的
  /// workflow)/ missed。**故事是一台机器的一夜**:tr_cron_inventory 每 6h 一次,笔记本睡过了 −19h 与 −13h 两刻,
  /// 醒来 sweep 把它们记成 missed 且**不补跑**(判决⑥);它在 −7h 与 −1h 醒着,那两刻跑了、且失败了——正是失败聚合
  /// 已经在讲的那条连败(相隔 6h=它的节拍本身)。故 ✕、红连败、6h cron 是**同一段**种子历史的三个视图,不是三件互不
  /// 相干的道具。**种子必须守的自洽**(每一条都是真后端强制的规则):missed 行的 createdAt 是**错过的刻度**、绝非
  /// 睡醒时刻,且**无** flowrunId、**无** activationId(记账不是一次动作,更没有 run);trigger 的 lastFiredAt 不可能
  /// 早于它自己产出的 firing,故此处每一条窗内行都属于 24h 内**真的 fire 过**的那仅有的两个 trigger;而 missed
  /// **只属于 cron**,因为 sweep 只看未暂停的 cron。
  List<Firing> _firingSeeds() => [
        // tr_cron_clean × wf_clean — the live run's own firing (the run row cites this very id).
        // Stamped at the trigger's lastFiredAt (−2m), NOT at the run's startedAt (−90s): the fire comes
        // FIRST and the run it claims starts ~30s later. Getting this backwards makes the trigger card
        // claim it last fired before a firing it produced — the ProvenanceLine's cron → firing → run
        // chain contradicting itself, which is the same law the 0717 pass had to learn.
        // 活 run 自己的 firing(run 行引用的正是这个 id)。盖在 trigger 的 lastFiredAt(−2m)、**不是** run 的
        // startedAt(−90s):火**先**烧,它 claim 出来的 run 约 30s 后才起跑。盖反了,trigger 卡就会自称「上次触发」
        // 早于它自己产出的 firing —— ProvenanceLine 的 cron → firing → run 链自相矛盾,与 0717 那条同一律。
        _firing('trf_clean00000091', 'tr_cron_clean', 'wf_clean', FiringStatus.started,
            const Duration(minutes: 2),
            flowrunId: 'fr_0a1b2c3d4e5f6071'),
        // Overlap policy «skip»: the tick came due while the previous run was still in flight.
        // overlap 策略 skip:刻度到期时上一个 run 还在跑。
        _firing('trf_clean00000082', 'tr_cron_clean', 'wf_clean', FiringStatus.skipped,
            const Duration(hours: 3)),
        // buffer_one collapsed the waiting queue to the newest — this older pending lost.
        // buffer_one 把等待队列收敛到最新的一条,这条更早的 pending 输了。
        _firing('trf_clean00000073', 'tr_cron_clean', 'wf_clean', FiringStatus.superseded,
            const Duration(hours: 6)),
        // The SAME fire fanned out to a workflow that had been deleted → shed. It is deliberately NOT
        // reachable from any lane (wf_ghost has no edge): a `shed` orphan is context nothing counts, so
        // the track drops it — unlike an orphaned `missed`, which the KPI card DOES count and which
        // therefore must never be dropped. This seed is what proves those two paths differ.
        // **同一次** fire 扇到了一个已被删的 workflow → shed。它**刻意**从任何泳道都够不着(wf_ghost 无边):
        // shed 孤儿是没人数的上下文,故轨道丢弃它——而 missed 孤儿会被 KPI 牌数进去、绝不可丢。这条种子正是用来
        // 证明这两条路径不同的。
        _firing('trf_ghost00000064', 'tr_cron_clean', 'wf_ghost', FiringStatus.shed,
            const Duration(hours: 3)),
        // tr_cron_inventory × wf_inventory — awake for these two; both ran, both failed (the ×4 streak).
        // 这两刻它醒着;都跑了、都失败了(×4 连败)。
        _firing('trf_inv000000051', 'tr_cron_inventory', 'wf_inventory', FiringStatus.started,
            const Duration(hours: 1, seconds: 12),
            flowrunId: 'fr_c3d4e5f607182930'),
        _firing('trf_inv000000042', 'tr_cron_inventory', 'wf_inventory', FiringStatus.started,
            const Duration(hours: 7),
            flowrunId: 'fr_b2c3d4e5f6071829'),
        // Asleep for these two — booked on wake, never caught up (判决⑥). The 「错过 N」 card counts
        // exactly these. 这两刻它睡着——醒来记账、绝不补跑;「错过 N」牌数的正是它们。
        _firing('trf_inv000000033', 'tr_cron_inventory', 'wf_inventory', FiringStatus.missed,
            const Duration(hours: 13)),
        _firing('trf_inv000000024', 'tr_cron_inventory', 'wf_inventory', FiringStatus.missed,
            const Duration(hours: 19)),
      ];

  Firing _firing(String id, String triggerId, String workflowId, FiringStatus status, Duration ago,
      {String flowrunId = ''}) {
    final at = _shift(_anchor.subtract(ago));
    final missed = status == FiringStatus.missed;
    return Firing(
      id: id,
      triggerId: triggerId,
      workflowId: workflowId,
      // A missed row is bookkeeping, not an action — the sweep records no activation for it, and only
      // a requeue would ever stamp one. missed 是记账不是动作:sweep 不为它记 activation。
      activationId: missed ? '' : 'tra_${id.substring(4)}',
      dedupKey: '$triggerId@${at.toUtc().toIso8601String()}',
      status: status,
      // Only a started firing ever has a run. 只有 started 才有 run。
      flowrunId: flowrunId,
      createdAt: at,
      updatedAt: at,
    );
  }

  /// **THE firing predicate** — the single expression of what a filter MEANS, shared by [listFirings]
  /// (the page) and [stats]' `totals.missed` (the number), exactly as the backend's `firingQuery` is
  /// shared by `SearchFirings` and `CountFirings`. Two copies would be a bug with a countdown on it:
  /// the 「错过 N」 card would say 3 and the ✕ marks its click reveals would show 4. Cursor/limit are the
  /// page's alone and are NOT applied here — a count is not a page.
  /// **那份 firing 谓词**:filter 语义的**唯一**表达,由 listFirings(一页)与 stats 的 totals.missed(一个数)共用
  /// ——正如后端的 firingQuery 由 SearchFirings 与 CountFirings 共用。两份拷贝就是一个装了倒计时的 bug:牌上写 3、
  /// 它点开的 ✕ 显示 4。cursor/limit 只属于分页,不在此施加(计数不是一页)。
  List<Firing> _firingsMatching({
    String? triggerId,
    FiringStatus? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) =>
      [
        for (final f in _firingSeeds())
          // Half-open [createdAfter, createdBefore) — the wire's window, verbatim. 半开窗,逐字同线缆。
          if (triggerId == null || f.triggerId == triggerId)
            if (status == null || f.status == status)
              if (createdAfter == null || !f.createdAt.isBefore(createdAfter))
                if (createdBefore == null || f.createdAt.isBefore(createdBefore)) f,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first, as the endpoint pages 新→旧

  @override
  Future<Page<Firing>> listFirings({
    String? triggerId,
    FiringStatus? status,
    DateTime? createdAfter,
    DateTime? createdBefore,
    String? cursor,
    int? limit,
  }) async {
    final rows = _firingsMatching(
        triggerId: triggerId,
        status: status,
        createdAfter: createdAfter,
        createdBefore: createdBefore);
    final cap = limit ?? 50;
    final capped = rows.length > cap;
    return Page(
      items: capped ? rows.sublist(0, cap) : rows,
      hasMore: capped,
      nextCursor: capped ? 'demo-firings-1' : null,
    );
  }

  /// Resolve a `since` word the way the backend's `parseSince` does — RFC3339 absolute FIRST, then a
  /// `<n>d` day form, then a Go duration; anything else falls to the backend's 7d default. The absolute
  /// form is the one the Overview actually sends (工单⑭: the anchor is computed client-side ONCE so the
  /// card and the firing list share one predicate), so a fixture that only matched the literal words
  /// `'24h'`/`'48h'` would silently answer the 7d question to every KPI read.
  /// 照后端 parseSince 解 since:先 RFC3339 绝对起点,再 `<n>d`,再 Go duration,其余落后端的 7d 默认。**绝对形**
  /// 正是 Overview 真正在发的那个(工单⑭:锚点在前端只算一次,好让牌与 firing 列表共用一份谓词),故一个只认字面
  /// `'24h'`/`'48h'` 的 fixture 会静默地拿 7d 的答案去回答每一次 KPI 读取。
  DateTime _sinceInstant(String since) {
    final absolute = DateTime.tryParse(since);
    if (absolute != null) return absolute;
    final now = DateTime.now();
    final m = RegExp(r'^(\d+)([smhd])$').firstMatch(since.trim());
    if (m != null) {
      final n = int.parse(m.group(1)!);
      return now.subtract(switch (m.group(2)!) {
        's' => Duration(seconds: n),
        'm' => Duration(minutes: n),
        'h' => Duration(hours: n),
        _ => Duration(days: n),
      });
    }
    return now.subtract(const Duration(days: 7));
  }

  /// The node×run grid (工单⑩). Seeded so the face earns its keep: `analyze` fails in a STREAK (the
  /// horizontal red band a gantt/graph structurally cannot show), a loop cell carries ×3, a parked
  /// cell waits, and the newest run is still going (no elapsed → no column bar) with its later nodes
  /// simply ABSENT (sparse 「未及」, not a status).
  /// 节点×run 格阵(⑩)。种子让这张脸值回票价:analyze **连续**失败(甘特/图结构上给不出的那道横向红条)、
  /// 一格 ×3 循环、一格 parked、最新一次 run 仍在跑(无 elapsed→列无条)且它后面的节点**直接缺席**
  /// (稀疏「未及」,不是一种状态)。
  @override
  Future<FlowrunMatrix> runMatrix(List<String> flowrunIds) async {
    // Mirrors the wire law: answer EXACTLY the requested ids, canonical (startedAt, id) DESC
    // regardless of request order, unknown ids silently absent. 镜像线缆律:恰答请求 id、正典序、
    // 未知缺席。
    final wanted = flowrunIds.toSet();
    final runs = _allRuns().where((r) => wanted.contains(r.id)).toList()
      ..sort((a, b) {
        final sa = a.startedAt, sb = b.startedAt;
        if (sa == null || sb == null) return sa == sb ? 0 : (sa == null ? 1 : -1);
        final c = sb.compareTo(sa);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    final cols = <MatrixCol>[];
    for (final r in runs) {
      final started = r.startedAt;
      if (started == null) continue;
      final status = _statusOf(r);
      final done = r.completedAt;
      cols.add(MatrixCol(
        flowrunId: r.id,
        startedAt: started,
        status: status,
        // Still running → the key is ABSENT (never a 0 that reads as «instant»). 在跑=键缺席。
        elapsedMs: status == 'running' || done == null
            ? null
            : done.difference(started).inMilliseconds,
      ));
    }
    // Rows = first-appearance order across the columns (newest→oldest), the endpoint's own law.
    // 行=跨列(新→旧)的首次出现序,端点自身之律。
    final rows = <MatrixRow>[];
    final cells = <MatrixCell>[];
    final seen = <String>{};
    for (final col in cols) {
      final run = runs.firstWhere((r) => r.id == col.flowrunId);
      for (final n in _nodesFor(run)) {
        if (seen.add(n.nodeId)) rows.add(MatrixRow(nodeId: n.nodeId, kind: n.kind));
        // One cell per (run, node): fold the iterations, WORST disposition wins. 每 (run,节点) 一格:
        // 折叠迭代,取最坏处置。
        final prior = cells.indexWhere((c) => c.flowrunId == col.flowrunId && c.nodeId == n.nodeId);
        final rank = {'failed': 3, 'parked': 2, 'completed': 1};
        if (prior < 0) {
          cells.add(MatrixCell(
              flowrunId: col.flowrunId, nodeId: n.nodeId, status: n.status, iteration: n.iteration));
        } else {
          final was = cells[prior];
          final worse = (rank[n.status] ?? 0) >= (rank[was.status] ?? 0);
          cells[prior] = MatrixCell(
            flowrunId: col.flowrunId,
            nodeId: n.nodeId,
            status: worse ? n.status : was.status,
            iteration: worse ? n.iteration : was.iteration,
            iterations: was.iterations + 1,
          );
        }
      }
    }
    return FlowrunMatrix(cols: cols, rows: rows, cells: cells);
  }


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
            toName: '每日 09:00'),
        EntityRelation(
            id: 'rel_2',
            kind: 'equip',
            fromKind: 'workflow',
            fromId: 'wf_report',
            fromName: '周报生成',
            toKind: 'trigger',
            toId: 'tr_cron_report',
            toName: '每周一 08:00'),
        EntityRelation(
            id: 'rel_3',
            kind: 'equip',
            fromKind: 'workflow',
            fromId: 'wf_clean',
            fromName: '数据清洗流水线',
            toKind: 'trigger',
            toId: 'tr_hook_invoice',
            toName: '发票回调'),
        EntityRelation(
            id: 'rel_4',
            kind: 'equip',
            fromKind: 'workflow',
            fromId: 'wf_archive',
            fromName: '邮件归档',
            toKind: 'trigger',
            toId: 'tr_cron_archive',
            toName: '每晚归档'),
        // The streak's cron edge — makes wf_inventory's cron-born runs POSSIBLE (see tr_cron_inventory).
        // 连败的 cron 边:让 wf_inventory 那些 cron 来源的 run 成为可能。
        EntityRelation(
            id: 'rel_5',
            kind: 'equip',
            fromKind: 'workflow',
            fromId: 'wf_inventory',
            fromName: '库存同步',
            toKind: 'trigger',
            toId: 'tr_cron_inventory',
            toName: '每 6 小时'),
      ];
}

SchedulerRepository demoSchedulerRepository() => FixtureSchedulerRepository();
