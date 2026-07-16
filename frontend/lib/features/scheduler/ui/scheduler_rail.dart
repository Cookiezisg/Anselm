import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';

/// The Scheduler rail — the operations projection of every workflow (WRK-069 §2: status dot ·
/// next-fire/last-run meta, activity-sorted, never-ran/inactive folded). S0 skeleton: the states shell
/// only; the live model (workflow list + 工单③ stats) lands in S1. Scheduler rail 运营投影——S0 只立
/// 状态壳,活模型(workflow 列表+工单③统计)随 S1。
class SchedulerRail extends ConsumerWidget {
  const SchedulerRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return AnRailStates(
      loading: false,
      error: false,
      empty: true,
      strings: AnRailStrings(
        errorTitle: t.scheduler.railErrorTitle,
        errorHint: t.scheduler.railErrorHint,
        retry: t.scheduler.retry,
        emptyTitle: t.scheduler.railEmptyTitle,
        emptyHint: t.scheduler.railEmptyHint,
      ),
      onRetry: () {},
      builder: () => const SizedBox.shrink(),
    );
  }
}
