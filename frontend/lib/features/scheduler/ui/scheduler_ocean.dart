import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shell/shell_chrome.dart';
import '../state/selected_scheduler.dart';
import 'scheduler_home.dart';
import 'scheduler_overview.dart';
import 'scheduler_run.dart';
import 'scheduler_run_relay.dart';

/// The Scheduler center ocean (WRK-069) — the four routes of §11, all real as of S4: Overview
/// (`/scheduler`) · a workflow's operations home (`/scheduler/w/:id`) · the run flagship
/// (`/scheduler/w/:id/runs/:frId`) · the id-only `fr_` relay (`/scheduler/runs/:frId`), which
/// resolves the host workflow and hands over to the flagship.
/// Scheduler 中心海洋:§11 四条路由 S4 起全为真页——Overview / 运营主页 / run 旗舰 / fr_ 直达中转位。
class SchedulerOcean extends ConsumerWidget {
  const SchedulerOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedSchedulerProvider);
    switch (selection) {
      case SchedulerWorkflow(:final workflowId, :final linkedRunId):
        return SchedulerHomeView(workflowId: workflowId, linkedRunId: linkedRunId);
      case SchedulerRun(:final workflowId, :final flowrunId, :final nodeId, :final iteration):
        return SchedulerRunView(
          // A constant KEY per run so switching runs rebuilds the page state (scroll, pulse
          // listener) instead of grafting the new run onto the old one's. 每 run 常量 key:换 run 重建
          // 页状态,而非把新 run 嫁接到旧 run 的壳上。
          key: ValueKey(flowrunId),
          workflowId: workflowId,
          flowrunId: flowrunId,
          nodeId: nodeId,
          iteration: iteration,
        );
      case SchedulerRunRelay(:final flowrunId):
        return SchedulerRunRelayView(flowrunId: flowrunId);
      case SchedulerOverview():
      case null:
        // The Overview owns no crumb — clear a stale «Scheduler / 名» left by the home/flagship.
        // Overview 无面包屑:清掉主页/旗舰留下的旧 crumb。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) ref.read(shellHeadProvider.notifier).clear();
        });
        return const SchedulerOverviewView();
    }
  }
}
