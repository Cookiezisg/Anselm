import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/selected_scheduler.dart';

/// The Scheduler center ocean (WRK-069) — Overview (`/scheduler`) · a workflow's operations home
/// (`/scheduler/w/:id`) · the run flagship (`/scheduler/w/:id/runs/:frId`). S0 skeleton: the routed
/// shell with honest placeholders; the real pages land S2 (overview) / S3 (home) / S4 (flagship).
/// Scheduler 中心海洋——S0 只立路由壳与诚实占位,真页随 S2/S3/S4。
class SchedulerOcean extends ConsumerWidget {
  const SchedulerOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedSchedulerProvider);
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
