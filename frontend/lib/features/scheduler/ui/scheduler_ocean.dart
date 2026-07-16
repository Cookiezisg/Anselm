import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/selected_scheduler.dart';
import 'scheduler_home.dart';
import 'scheduler_overview.dart';

/// The Scheduler center ocean (WRK-069) — Overview (`/scheduler`) · a workflow's operations home
/// (`/scheduler/w/:id`, S3 real) · the run flagship (`/scheduler/w/:id/runs/:frId`). The Overview
/// board and the operations home are real; the flagship / relay keep honest placeholders until S4.
/// Scheduler 中心海洋——Overview 与运营主页已是真页(S2/S3),旗舰/中转仍诚实占位(S4)。
class SchedulerOcean extends ConsumerWidget {
  const SchedulerOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedSchedulerProvider);
    if (selection is SchedulerWorkflow) {
      return SchedulerHomeView(
        workflowId: selection.workflowId,
        linkedRunId: selection.linkedRunId,
      );
    }
    if (selection is SchedulerOverview || selection == null) {
      // The Overview owns no crumb — clear a stale «Scheduler / 名» left by the home page.
      // Overview 无面包屑:清掉主页留下的旧 crumb。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ref.read(shellHeadProvider.notifier).clear();
      });
      return const SchedulerOverviewView();
    }
    final t = context.t;
    final c = context.colors;
    final subtitle = switch (selection) {
      SchedulerRun(:final flowrunId) => flowrunId,
      SchedulerRunRelay(:final flowrunId) => flowrunId,
      _ => t.scheduler.overviewTitle,
    };
    return ColoredBox(
      color: c.surface,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AnIcons.scheduler, size: AnSize.iconLg, color: c.inkFaint),
          const SizedBox(height: AnSpace.s12),
          Text(subtitle, style: AnText.h2.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s6),
          Text(t.scheduler.underConstruction, style: AnText.body.copyWith(color: c.inkMuted)),
        ]),
      ),
    );
  }
}
