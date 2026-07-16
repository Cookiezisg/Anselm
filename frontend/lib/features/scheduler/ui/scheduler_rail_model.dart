import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/model/sidebar_model.dart';
import '../../../core/model/status_state.dart';
import '../../../core/model/time_format.dart';
import '../../../core/ui/icons.dart';
import '../data/scheduler_repository.dart';

/// Pure projection: workflows + stats + next-fires → the Scheduler rail's [SidebarModel] (WRK-069 §2).
/// Widget/context-free so every rule below is unit-tested without pumping UI; i18n injected.
///
/// The rail's grammar: it answers «now». One headless main section (ever-ran, activity-sorted) over two
/// sunk initially-folded sections («never ran (n)» / «inactive (n)»); a fixed Overview row on top carries
/// the ONE number worth a badge — runs waiting on a human. 纯投影:主段(跑过的,活动序)+两沉底折叠段+
/// Overview 固定行(徽=等人数,rail 唯一数字)。
class SchedulerRailLabels {
  const SchedulerRailLabels({
    required this.overview,
    required this.sectionNeverRan,
    required this.sectionInactive,
    required this.runningFor,
    required this.nextFireIn,
    required this.ago,
    required this.neverRan,
    required this.newLabel,
    required this.filterPlaceholder,
  });

  final String overview;
  final String sectionNeverRan;
  final String sectionInactive;
  final String Function(String d) runningFor;
  final String Function(String d) nextFireIn;
  final String Function(String d) ago;
  final String neverRan;
  final String newLabel;
  final String filterPlaceholder;
}

/// The fixed Overview row's model id (never a workflow id). Overview 固定行 id。
const schedulerOverviewRowId = '__scheduler_overview';

/// Status-dot priority (WRK-069 §2): blue running > amber waiting-on-human > red recent-failure > none.
/// Blue over amber follows the chat-rail mindset (a running run may self-heal its gate); red rides
/// consecutiveFailures/needsAttention and self-clears on the next success. 点位:蓝>琥珀>红>无。
AnStatus? schedulerRailDot(WorkflowRunStats? s, {required bool needsAttention}) {
  if (s == null) return needsAttention ? AnStatus.err : null;
  if (s.running > 0) return AnStatus.run;
  if (s.parkedNodes > 0) return AnStatus.wait;
  if (s.consecutiveFailures > 0 || needsAttention) return AnStatus.err;
  return null;
}

/// The single meta value (one row carries at most two facts — label + this): running elapsed (minute
/// granularity) > next cron fire > last-run relative time > «—». 单 meta 值:运行中>⏱ 下次>上次>—。
String schedulerRailMeta(
  WorkflowRunStats? s,
  DateTime? nextFire,
  SchedulerRailLabels labels, {
  required DateTime now,
}) {
  if (s != null && s.running > 0) {
    final since = s.lastRunAt;
    return labels.runningFor(since != null ? fmtWaited(now.difference(since)) : '<1m');
  }
  if (nextFire != null && nextFire.isAfter(now)) {
    return labels.nextFireIn(fmtWaited(nextFire.difference(now)));
  }
  if (s?.lastRunAt != null) return labels.ago(fmtWaited(now.difference(s!.lastRunAt!)));
  return labels.neverRan;
}

/// Build the rail model. [waitingCount] badges the Overview row (inbox-derived, workspace-wide).
/// Sorting is single-axis recent-activity (running ≡ active now); the CALLER re-derives only on durable
/// events (run_started / run_terminal) — never on ticks (活性军规:行序只随 durable 落账). 构建 rail 模型。
SidebarModel buildSchedulerRailModel({
  required List<SchedulerWorkflowRow> workflows,
  required Map<String, WorkflowRunStats> stats,
  required Map<String, DateTime> nextFireByWorkflow,
  required int waitingCount,
  required SchedulerRailLabels labels,
  required DateTime now,
}) {
  final main = <SchedulerWorkflowRow>[];
  final neverRan = <SchedulerWorkflowRow>[];
  final inactive = <SchedulerWorkflowRow>[];
  for (final w in workflows) {
    if (w.lifecycleState == 'inactive') {
      inactive.add(w);
    } else if (stats[w.id]?.lastRunAt == null && (stats[w.id]?.running ?? 0) == 0) {
      neverRan.add(w);
    } else {
      main.add(w);
    }
  }

  DateTime activity(SchedulerWorkflowRow w) {
    final s = stats[w.id];
    if (s != null && s.running > 0) return now;
    return s?.lastRunAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  main.sort((a, b) => activity(b).compareTo(activity(a)));
  neverRan.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
  inactive.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));

  SidebarRow row(SchedulerWorkflowRow w) => SidebarRow(
        id: w.id,
        label: w.name,
        dot: schedulerRailDot(stats[w.id], needsAttention: w.needsAttention),
        meta: schedulerRailMeta(stats[w.id], nextFireByWorkflow[w.id], labels, now: now),
      );

  return SidebarModel(
    newLabel: labels.newLabel,
    filterPlaceholder: labels.filterPlaceholder,
    groups: [
      SidebarGroup(types: [
        // The fixed Overview row — headless, above everything; its meta is the rail's ONE number.
        // Overview 固定行(headless,置顶);meta=rail 唯一数字(等人数)。
        SidebarType(rows: [
          SidebarRow(
            id: schedulerOverviewRowId,
            label: labels.overview,
            icon: AnIcons.scheduler,
            meta: waitingCount > 0 ? '$waitingCount' : null,
            dot: waitingCount > 0 ? AnStatus.wait : null,
          ),
        ]),
        SidebarType(rows: [for (final w in main) row(w)]),
        if (neverRan.isNotEmpty)
          SidebarType(
            label: labels.sectionNeverRan,
            count: neverRan.length,
            initiallyFolded: true,
            rows: [for (final w in neverRan) row(w)],
          ),
        if (inactive.isNotEmpty)
          SidebarType(
            label: labels.sectionInactive,
            count: inactive.length,
            initiallyFolded: true,
            rows: [for (final w in inactive) row(w)],
          ),
      ]),
    ],
  );
}
