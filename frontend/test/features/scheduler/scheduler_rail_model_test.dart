import 'package:anselm/core/contract/entities/scheduler_stats.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/features/scheduler/ui/scheduler_rail_model.dart';
import 'package:flutter_test/flutter_test.dart';

// The rail projection's rule table (WRK-069 §2) — dot priority / single meta / sections / sorting,
// all pure. rail 投影规则表(纯函数直测)。

final _labels = SchedulerRailLabels(
  overview: 'Overview',
  sectionNeverRan: 'Never ran',
  sectionInactive: 'Inactive',
  runningFor: (d) => 'running · $d',
  nextFireIn: (d) => '⏱ in $d',
  ago: (d) => '$d ago',
  neverRan: '—',
  newLabel: 'New',
  filterPlaceholder: 'Filter',
);

final _now = DateTime.utc(2026, 7, 16, 12);

SchedulerWorkflowRow _wf(String id, {String lifecycle = 'active', bool attention = false, DateTime? updated}) =>
    SchedulerWorkflowRow(
        id: id, name: id, lifecycleState: lifecycle, needsAttention: attention, updatedAt: updated);

WorkflowRunStats _stats(String id,
        {int running = 0, int parked = 0, int consecutiveFailures = 0, DateTime? lastRunAt}) =>
    WorkflowRunStats(
        workflowId: id,
        running: running,
        parkedNodes: parked,
        consecutiveFailures: consecutiveFailures,
        lastRunAt: lastRunAt);

void main() {
  group('schedulerRailDot — 蓝>琥珀>红>无', () {
    test('running beats parked beats failures', () {
      expect(schedulerRailDot(_stats('w', running: 1, parked: 2, consecutiveFailures: 3), needsAttention: true),
          AnStatus.run);
      expect(schedulerRailDot(_stats('w', parked: 1, consecutiveFailures: 3), needsAttention: true),
          AnStatus.wait);
      expect(schedulerRailDot(_stats('w', consecutiveFailures: 1), needsAttention: false), AnStatus.err);
      expect(schedulerRailDot(_stats('w'), needsAttention: false), isNull);
    });

    test('needsAttention (REST persistent field) backs the red dot when stats are absent', () {
      expect(schedulerRailDot(null, needsAttention: true), AnStatus.err);
      expect(schedulerRailDot(null, needsAttention: false), isNull);
    });
  });

  group('schedulerRailMeta — 运行中 > ⏱下次 > 上次 > —', () {
    final nextFire = _now.add(const Duration(minutes: 3));

    test('running wins even with a next fire pending', () {
      final s = _stats('w', running: 1, lastRunAt: _now.subtract(const Duration(minutes: 2)));
      expect(schedulerRailMeta(s, nextFire, _labels, now: _now), 'running · 2m');
    });

    test('next fire when idle', () {
      final s = _stats('w', lastRunAt: _now.subtract(const Duration(hours: 2)));
      expect(schedulerRailMeta(s, nextFire, _labels, now: _now), '⏱ in 3m');
    });

    test('last-run relative when no schedule; em-dash when never ran', () {
      final s = _stats('w', lastRunAt: _now.subtract(const Duration(hours: 2)));
      expect(schedulerRailMeta(s, null, _labels, now: _now), '2h ago');
      expect(schedulerRailMeta(null, null, _labels, now: _now), '—');
      expect(schedulerRailMeta(_stats('w'), null, _labels, now: _now), '—');
    });

    test('a stale next fire (already past) never renders', () {
      final s = _stats('w', lastRunAt: _now.subtract(const Duration(hours: 1)));
      expect(schedulerRailMeta(s, _now.subtract(const Duration(minutes: 1)), _labels, now: _now), '1h ago');
    });
  });

  group('buildSchedulerRailModel — sections + sorting + overview badge', () {
    SchedulerRailBuilt build() {
      final model = buildSchedulerRailModel(
        workflows: [
          _wf('idle_old'),
          _wf('running_now'),
          _wf('never_ran', updated: _now),
          _wf('retired', lifecycle: 'inactive'),
          _wf('idle_recent'),
        ],
        stats: {
          'idle_old': _stats('idle_old', lastRunAt: _now.subtract(const Duration(days: 2))),
          'running_now': _stats('running_now', running: 1, lastRunAt: _now.subtract(const Duration(minutes: 1))),
          'idle_recent': _stats('idle_recent', lastRunAt: _now.subtract(const Duration(hours: 1))),
        },
        nextFireByWorkflow: const {},
        waitingCount: 2,
        labels: _labels,
        now: _now,
      );
      final types = model.groups.single.types;
      return (
        overview: types[0].rows.single,
        main: types[1].rows.map((r) => r.id).toList(),
        folded: types.skip(2).toList(),
      );
    }

    test('running sorts above recent above old; never-ran and inactive sink into folded sections', () {
      final b = build();
      expect(b.main, ['running_now', 'idle_recent', 'idle_old']);
      expect(b.folded.map((t) => t.label), ['Never ran', 'Inactive']);
      expect(b.folded.every((t) => t.initiallyFolded), isTrue);
      expect(b.folded[0].rows.single.id, 'never_ran');
      expect(b.folded[1].rows.single.id, 'retired');
    });

    test('the Overview row carries the waiting badge — the rail\'s one number', () {
      final b = build();
      expect(b.overview.id, schedulerOverviewRowId);
      expect(b.overview.meta, '2');
      expect(b.overview.dot, AnStatus.wait);
    });

    test('zero waiting → no badge, no dot', () {
      final model = buildSchedulerRailModel(
        workflows: [_wf('w')],
        stats: const {},
        nextFireByWorkflow: const {},
        waitingCount: 0,
        labels: _labels,
        now: _now,
      );
      final overview = model.groups.single.types[0].rows.single;
      expect(overview.meta, isNull);
      expect(overview.dot, isNull);
    });
  });
}

typedef SchedulerRailBuilt = ({
  dynamic overview,
  List<String> main,
  List<dynamic> folded,
});
