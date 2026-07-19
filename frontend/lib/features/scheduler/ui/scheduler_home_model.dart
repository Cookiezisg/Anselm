/// Pure projections for the workflow operations home (WRK-069 §4 S3) — widget/context-free so the
/// filter grammar, the row's source identity and the replay real-numbers are unit-tested headless
/// (i18n words are assembled by the widget). 运营主页纯投影:过滤文法/行来源短语/replay 真数字,
/// 全部无 widget 可无头单测;i18n 文案由 widget 拼。
library;

import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/model/time_range.dart';
import '../data/scheduler_repository.dart';

/// The run big table's status filter. «waiting» is INBOX-DERIVED (parked is a NODE state, not in the
/// run-status closed set — `?status=parked` would 422): it fetches running runs and intersects the
/// workflow's inbox rows client-side. 状态过滤;「等人」=inbox 派生(绝不 ?status=parked——封闭集无此值)。
enum RunStatusFilter { all, running, failed, waiting }

/// Compose the `GET /flowruns` filter set for one (filter, origin, range) pick — the ONE query
/// grammar the table AND its failed-count probe share, so the count strip and the rows can never
/// disagree (they are the same wire question). The time bounds come from the PAGE-LEVEL
/// [AnTimeRange] (主页重建拍板 0717: one capsule governs matrix + table), resolved fresh against
/// [now] at every call — presets stay live expressions. «waiting» asks for running runs (the inbox
/// intersect happens after the fetch); «all» sends no status.
/// 组合一次 (状态,来源,范围) 的过滤集——表与失败计数探针共用同一文法,计数与行不可能不一致;时间界来自
/// **页级** AnTimeRange(0717 拍板:一颗胶囊治矩阵+大表),每次调用对新鲜 now 现解析——预设恒为活表达式;
/// 「等人」发 status=running(取回后与 inbox 交集);「全部」不发 status。
({String? status, String? origin, DateTime? startedAfter, DateTime? startedBefore}) runListFilter({
  required RunStatusFilter filter,
  String? origin,
  required AnTimeRange range,
  required DateTime now,
}) {
  final r = resolveTimeRange(range, now);
  return (
    status: switch (filter) {
      RunStatusFilter.all => null,
      RunStatusFilter.running || RunStatusFilter.waiting => 'running',
      RunStatusFilter.failed => 'failed',
    },
    origin: origin,
    startedAfter: r.from,
    startedBefore: r.to,
  );
}

/// The `flowrun-stats` wire words for one page-level range (需求②:成功率跟随选择器): presets ride
/// the duration grammar (live look-backs), «today» and absolute pairs ride RFC3339, «all» rides the
/// epoch (an honest absolute bound covering all history — stats has no unbounded spelling and its
/// absent-since default is 7d). `until` is RFC3339 or absent (presets are now-anchored).
/// 一页级范围的 flowrun-stats 线缆词:预设走时长文法(活回看),「今天」与绝对对走 RFC3339,「全部」走
/// epoch(覆盖全史的诚实绝对界——stats 无「无界」拼法,缺席默认 7d)。until 仅 RFC3339,预设锚 now 故缺席。
({String since, String? until}) statsWindowOf(AnTimeRange range, DateTime now) {
  switch (range) {
    case AnPresetRange(:final preset):
      switch (preset) {
        case AnTimePreset.today:
          return (
            since: DateTime(now.year, now.month, now.day).toUtc().toIso8601String(),
            until: null
          );
        case AnTimePreset.h24:
          return (since: '24h', until: null);
        case AnTimePreset.d7:
          return (since: '168h', until: null);
        case AnTimePreset.d30:
          return (since: '720h', until: null);
        case AnTimePreset.all:
          return (since: '1970-01-01T00:00:00Z', until: null);
      }
    case AnAbsoluteRange():
      final r = resolveTimeRange(range, now);
      return (
        since: r.from!.toUtc().toIso8601String(),
        until: r.to!.toUtc().toIso8601String(),
      );
  }
}

/// A run's start instant as the row phrase's time word: same local day → `HH:mm`, else `M/D HH:mm`
/// (需求⑦:每行都带唤起时刻——右缘不再有相对时间,这里就是「什么时候」的唯一答案).
/// 行短语的时刻词:当天 HH:mm,跨天 M/D HH:mm。
String fmtDayTime(DateTime t, DateTime now) {
  final l = t.toLocal();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  final sameDay = l.year == now.year && l.month == now.month && l.day == now.day;
  return sameDay ? hm : '${l.month}/${l.day} $hm';
}

/// A run row's source identity (§4 行身份=来源短语 — GHA「cron run 全长一样」之鉴). [origin] is the
/// wire word or null (pre-provenance rows — render the unknown word, never a zero-value lie);
/// [detail] is the per-origin summary (cron → the run's HH:mm start, webhook → the path, fsnotify/
/// sensor → the trigger name); [conversationId] rides only origin=chat.
/// 行来源身份:origin=线缆词或 null(旧行渲 unknown);detail=各来源摘要;conversationId 仅 chat。
class RunSource {
  const RunSource({this.origin, this.detail, this.conversationId});

  final String? origin;
  final String? detail;
  final String? conversationId;
}

String _hhmm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Fold one run + the trigger join into its [RunSource]. The trigger join comes from the rail's
/// already-fetched triggers (no N+1); a webhook trigger's `config['path']` beats its name.
/// 折一行的来源短语;trigger 连接来自 rail 已取的 triggers(零 N+1);webhook 的 path 优先于名。
RunSource runSourceOf(Flowrun run, Map<String, TriggerEntity> triggersById) {
  final trigger = run.triggerId != null ? triggersById[run.triggerId] : null;
  switch (run.origin) {
    case 'manual':
      return const RunSource(origin: 'manual');
    case 'chat':
      return RunSource(origin: 'chat', conversationId: run.conversationId);
    case 'cron':
      // The §4 mock's «cron · 09:00» — this RUN's fire time-of-day, from its own start stamp.
      // cron 摘要=本次 run 的当日时刻(取自它自己的 startedAt)。
      return RunSource(
          origin: 'cron', detail: run.startedAt != null ? _hhmm(run.startedAt!) : null);
    case 'webhook':
      final path = trigger?.config['path'];
      return RunSource(
          origin: 'webhook', detail: path is String && path.isNotEmpty ? path : trigger?.name);
    case 'fsnotify' || 'sensor':
      return RunSource(origin: run.origin, detail: trigger?.name);
    default:
      // NULL origin = a pre-provenance row (工单① wire omits the key) — honest unknown. 旧行诚实 unknown。
      return const RunSource();
  }
}

/// Distinct flowrun ids waiting on a human for THIS workflow (inbox-derived, order preserved) — the
/// «等人» filter's membership set AND the count strip's waiting number (same rows the Overview zone
/// and the rail badge count, so the three surfaces can never disagree).
/// 本 workflow 的等人 run id 去重集(保序)——等人过滤的成员集与计数条的等人数同源。
List<String> waitingRunIds(Iterable<SchedulerInboxRow> inbox, String workflowId) {
  final seen = <String>{};
  return [
    for (final r in inbox)
      if (r.workflowId == workflowId && seen.add(r.node.flowrunId)) r.node.flowrunId,
  ];
}

/// The replay confirm's REAL numbers (§10 记忆化承诺文案): `:replay` clears every FAILED node row and
/// rewalks from those points, reusing COMPLETED rows via record-once — so «重跑 N» counts failed
/// rows and «复用 M» counts completed rows (parked rows are neither: they stay parked).
/// replay 真数字:重跑=failed 行数(被清重走),复用=completed 行数(记忆化复用);parked 两不算。
({int failed, int completed}) replayCounts(Iterable<FlowrunNode> nodes) {
  var failed = 0, completed = 0;
  for (final n in nodes) {
    if (n.status == 'failed') failed++;
    if (n.status == 'completed') completed++;
  }
  return (failed: failed, completed: completed);
}
