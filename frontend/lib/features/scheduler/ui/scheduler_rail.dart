import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/scheduler_rail_provider.dart';
import '../state/selected_scheduler.dart';
import 'scheduler_rail_model.dart';

/// The Scheduler rail (WRK-069 §2) — the operations projection of every workflow. Selection navigates
/// (URL is the truth); the Overview fixed row goes home; Enter on an `fr_…` filter text deep-jumps to
/// the run relay. Row order re-derives only when the provider refetches (durable events) — the
/// half-minute [AnTimePulse] refreshes META TEXT only (running elapsed / next-fire), never order
/// (活性军规:脉搏只改字,不改序). Scheduler rail:运营投影;选中=导航;fr_ 回车直达;脉搏只刷 meta 字。
class SchedulerRail extends ConsumerStatefulWidget {
  const SchedulerRail({super.key});

  @override
  ConsumerState<SchedulerRail> createState() => _SchedulerRailState();
}

class _SchedulerRailState extends ConsumerState<SchedulerRail> {
  @override
  void initState() {
    super.initState();
    AnTimePulse.instance.addListener(_onPulse);
  }

  @override
  void dispose() {
    AnTimePulse.instance.removeListener(_onPulse);
    super.dispose();
  }

  void _onPulse() {
    if (mounted) setState(() {});
  }

  void _onSelect(String id) {
    if (id == schedulerOverviewRowId) {
      context.go('/scheduler');
    } else {
      context.go('/scheduler/w/$id');
    }
  }

  void _onFilterSubmit(String text) {
    final id = text.trim();
    if (id.startsWith('fr_') && id.length > 3) context.go('/scheduler/runs/$id');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final data = ref.watch(schedulerRailProvider);
    final selection = ref.watch(selectedSchedulerProvider);

    final selectedId = switch (selection) {
      SchedulerOverview() => schedulerOverviewRowId,
      SchedulerWorkflow(:final workflowId) => workflowId,
      SchedulerRun(:final workflowId) => workflowId,
      _ => null,
    };

    return AnRailStates(
      loading: data.isLoading && !data.hasValue,
      error: data.hasError && !data.hasValue,
      empty: data.hasValue && data.value!.workflows.isEmpty,
      strings: AnRailStrings(
        errorTitle: t.scheduler.railErrorTitle,
        errorHint: t.scheduler.railErrorHint,
        retry: t.scheduler.retry,
        emptyTitle: t.scheduler.railEmptyTitle,
        emptyHint: t.scheduler.railEmptyHint,
      ),
      onRetry: () => ref.read(schedulerRailProvider.notifier).refresh(),
      builder: () {
        final d = data.value!;
        final model = buildSchedulerRailModel(
          workflows: d.workflows,
          stats: d.stats,
          nextFireByWorkflow: d.nextFireByWorkflow,
          waitingCount: d.waitingCount,
          labels: SchedulerRailLabels(
            overview: t.scheduler.overviewTitle,
            sectionNeverRan: t.scheduler.sectionNeverRan,
            sectionInactive: t.scheduler.sectionInactive,
            runningFor: (d) => t.scheduler.runningFor(d: d),
            nextFireIn: (d) => t.scheduler.nextFireIn(d: d),
            ago: (d) => t.scheduler.agoMeta(d: d),
            neverRan: t.scheduler.neverRan,
            newLabel: t.scheduler.overviewTitle, // showNew=false — unused, satisfies the model. 不渲。
            filterPlaceholder: t.scheduler.filterPlaceholder,
          ),
          now: DateTime.now(),
        );
        return AnSidebarList(
          model: model,
          selectedId: selectedId,
          onSelect: _onSelect,
          onFilterSubmit: _onFilterSubmit,
          // Creation belongs to entities (定义面) — the scheduler rail observes, never creates.
          // 创建归 entities;本 rail 只观测。
          showNew: false,
        );
      },
    );
  }
}
