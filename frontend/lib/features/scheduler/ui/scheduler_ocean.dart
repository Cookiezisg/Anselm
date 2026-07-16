import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/selected_scheduler.dart';
import 'scheduler_overview.dart';

/// The Scheduler center ocean (WRK-069) — Overview (`/scheduler`) · a workflow's operations home
/// (`/scheduler/w/:id`) · the run flagship (`/scheduler/w/:id/runs/:frId`). S2a: the Overview board
/// is real ([SchedulerOverviewView]); the operations home / flagship / relay keep honest placeholders
/// until S3/S4. Scheduler 中心海洋——Overview 已是真页(S2a),主页/旗舰/中转仍诚实占位(S3/S4)。
class SchedulerOcean extends ConsumerWidget {
  const SchedulerOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedSchedulerProvider);
    if (selection is SchedulerOverview || selection == null) {
      return const SchedulerOverviewView();
    }
    final t = context.t;
    final c = context.colors;
    final subtitle = switch (selection) {
      SchedulerWorkflow(:final workflowId) => workflowId,
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
