import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../selected_entity.dart';

/// One recent execution of the terminal's entity, projected uniformly across the four ledgers
/// (fn executions / hd calls / ag executions / wf flowruns) — exactly what the debugger's «最近»
/// strip renders and what the reproduce key fills back from.
///
/// 终端实体的一次近期执行,四本账(函数执行/处理器调用/智能体执行/工作流 run)统一投影——「最近」段
/// 渲染与重现回填的数据单元。
class RecentRun {
  const RecentRun({
    required this.id,
    required this.status,
    this.startedAt,
    this.elapsedMs = 0,
    this.triggeredBy = '',
    this.input = const {},
    this.output,
    this.method = '',
    this.triggerId,
  });

  final String id;
  final String status; // raw ledger word (ok/failed/… or flowrun status) 账面词
  final DateTime? startedAt;
  final int elapsedMs;
  final String triggeredBy; // chat/agent/workflow/manual … or flowrun origin 来源微标
  final Map<String, Object?> input;
  final Object? output;
  final String method; // handler only 仅 handler
  final String? triggerId; // workflow only — restores the SOURCE on reproduce 仅 wf,重现还原来源
}

/// The last five executions, newest first — the debugger's working-bench strip. The full archive
/// stays in the Logs tab (档案馆/工作台分层: the island never carries history, only the bench).
/// Re-fetched after every run settles (the controller invalidates this).
///
/// 最近五次(新在前)——调试台工作台条。全史归 Logs tab(档案馆);每次运行落定由 controller 失效重取。
final recentRunsProvider =
    FutureProvider.autoDispose.family<List<RecentRun>, EntityRef>((ref, entity) async {
  final repo = ref.watch(entityRepositoryProvider);
  const n = 5;
  switch (entity.kind) {
    case EntityKind.function:
      final page = await repo.listFunctionExecutions(entity.id, limit: n);
      return [
        for (final e in page.items)
          RecentRun(
            id: e.id,
            status: e.status,
            startedAt: e.startedAt,
            elapsedMs: e.elapsedMs,
            triggeredBy: e.triggeredBy,
            input: e.input,
            output: e.output,
          ),
      ];
    case EntityKind.handler:
      final page = await repo.listHandlerCalls(entity.id, limit: n);
      return [
        for (final e in page.items)
          RecentRun(
            id: e.id,
            status: e.status,
            startedAt: e.startedAt,
            elapsedMs: e.elapsedMs,
            triggeredBy: e.triggeredBy,
            input: e.input,
            output: e.output,
            method: e.method,
          ),
      ];
    case EntityKind.agent:
      final page = await repo.listAgentExecutions(entity.id, limit: n);
      return [
        for (final e in page.items)
          RecentRun(
            id: e.id,
            status: e.status,
            startedAt: e.startedAt,
            elapsedMs: e.elapsedMs,
            triggeredBy: e.triggeredBy,
            input: e.input,
            output: e.output,
          ),
      ];
    case EntityKind.workflow:
      final page = await repo.listFlowruns(workflowId: entity.id, limit: n);
      return [
        for (final r in page.items)
          RecentRun(
            id: r.id,
            status: r.status,
            startedAt: r.startedAt,
            elapsedMs: (r.completedAt != null && r.startedAt != null)
                ? r.completedAt!.difference(r.startedAt!).inMilliseconds
                : 0,
            triggeredBy: r.origin ?? '',
            triggerId: r.triggerId,
          ),
      ];
    case EntityKind.control:
    case EntityKind.approval:
    case EntityKind.trigger:
      return const []; // support kinds have no execution ledger 支撑 kind 无执行账
  }
});
