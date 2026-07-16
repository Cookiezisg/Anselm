/// THE flowrun-watch reconcile seam (WRK-069 §9 «flowrun-watch 对账缝…三消费一源»). S0 deferred this
/// upstream to S4 on the scouting verdict that RunTerminalController could not be moved wholesale
/// (it is keyed by EntityRef and deeply coupled to entity_repository); what IS common — and what was
/// duplicated the moment the scheduler grew its own live run page — is the RULE, not the state
/// machine. That rule lives here:
///
///   • DB rows are the truth; a tick is ephemeral (seq=0), droppable and RESULTLESS. So a tick may
///     paint, but only a reconcile GET may be believed — hence [reconcileDelay] (coalesce a burst of
///     ticks into one read) + [pollEvery] (a backstop for a tick stream dropped whole).
///   • The tick scope is WORKFLOW-level, so concurrent runs interleave on it: [flowrunTickOf] parses
///     one, and the caller MUST drop ticks whose flowrunId isn't its own.
///   • A tick-born row is a placeholder — [upsertNodeRow] never lets one overwrite a truth row.
///
/// 唯一的 flowrun 对账缝(§9「三消费一源」;S0 判定 RunTerminalController 整收不现实、改排 S4)。可共享的
/// 是**规则**而非状态机:DB 行是真相、tick 可丢且无 result(故去抖 GET 落真相 + 慢轮询兜底);tick 是
/// workflow 级 scope(并发 run 混流,调用方须按 flowrunId 自滤);tick 行是占位——真相行绝不被它覆退。
library;

import '../contract/entities/workflow.dart';
import '../sse/frame.dart';

/// The reconcile cadence, shared by every live-flowrun surface (the entities run terminal, the
/// scheduler's run flagship). 对账节拍(各活 flowrun 面共用)。
abstract final class FlowrunWatch {
  // 批7 立法1 豁免锚:state 层合帧节流。exempt: state-layer coalescing.
  /// Coalesce a burst of ticks into ONE authoritative read. 一串 tick 合成一次权威读。
  static const Duration reconcileDelay = Duration(milliseconds: 300);

  /// Backstop for a tick stream dropped whole (ephemeral frames have no delivery guarantee).
  /// 全丢的 tick 流的兜底(ephemeral 无投递保证)。
  static const Duration pollEvery = Duration(seconds: 4);

  /// The synthetic id prefix marking a row as tick-born (= a placeholder, not truth). 占位行 id 前缀。
  static const String tickIdPrefix = 'tick_';
}

/// True when a row is a tick-born placeholder rather than a DB truth row. 是否 tick 占位行。
bool isTickRow(FlowrunNode n) => n.id.startsWith(FlowrunWatch.tickIdPrefix);

/// One parsed workflow-scope flowrun tick (`node.type="run"`, ephemeral, content
/// `{flowrunId, nodeId, iteration, status, port?}` — events.md workflow 行). 一条解析出的 flowrun tick。
class FlowrunTick {
  const FlowrunTick({
    required this.flowrunId,
    required this.nodeId,
    required this.iteration,
    required this.status,
    this.port,
  });

  final String flowrunId;
  final String nodeId;
  final int iteration;
  final String status;

  /// The branch a routing node chose — control's `__port` / approval's decision. Present only on
  /// routing nodes, so the client can light the taken branch live without a per-tick lazy GET.
  /// 路由节点所选分支(control 的 __port / approval 的 decision);仅路由节点携,免逐 tick 惰性 GET。
  final String? port;

  /// The EPHEMERAL row this tick implies — a placeholder carrying only what the tick actually said.
  /// Its stamps are deliberately absent (a tick knows no readyAt/startedAt), so a gantt built on it
  /// shows the node's arrival, never a fabricated duration; [now] stamps createdAt because the tick
  /// fires AT the node's terminal, which is the one time it does know.
  /// 本 tick 蕴含的 ephemeral 行:只带 tick 真说过的东西。刻意不带排队戳(tick 不知道)——甘特据此只显
  /// 「到达」绝不编时长;createdAt 用 now,因为 tick 恰在节点终态时发,那一刻它确实知道。
  FlowrunNode row(DateTime now) => FlowrunNode(
        id: '${FlowrunWatch.tickIdPrefix}${nodeId}_$iteration',
        flowrunId: flowrunId,
        nodeId: nodeId,
        iteration: iteration,
        status: status,
        result: port != null ? {'__port': port} : const {},
        createdAt: now,
        updatedAt: now,
      );
}

/// Parse a workflow-scope frame into a [FlowrunTick], or null when it isn't one (a build mirror, a
/// run_started/run_terminal signal, a malformed content map). The caller still self-filters by
/// flowrunId — the scope is the WORKFLOW, not the run. 解析 workflow scope 帧为 tick;非 tick 返 null。
/// 调用方仍须按 flowrunId 自滤(scope 是 workflow 不是 run)。
FlowrunTick? flowrunTickOf(StreamFrame frame) {
  if (frame is! FrameSignal) return null;
  if (frame.node.type != 'run') return null;
  final c = frame.node.content;
  final flowrunId = c?['flowrunId'] as String?;
  final nodeId = c?['nodeId'] as String?;
  final status = c?['status'] as String?;
  if (flowrunId == null || nodeId == null || status == null) return null;
  return FlowrunTick(
    flowrunId: flowrunId,
    nodeId: nodeId,
    iteration: (c?['iteration'] as num?)?.toInt() ?? 0,
    status: status,
    port: c?['port'] as String?,
  );
}

/// Record-once upsert by (nodeId, iteration) — the flowrun_nodes UNIQUE key. A truth row NEVER
/// regresses to a tick placeholder; an unseen key prepends (the list is newest-first).
/// 按 (节点,迭代)(= flowrun_nodes 唯一键)upsert:真相行绝不被 tick 占位覆退;新键前插(列表新→旧)。
List<FlowrunNode> upsertNodeRow(List<FlowrunNode> rows, FlowrunNode row) {
  final i = rows.indexWhere((r) => r.nodeId == row.nodeId && r.iteration == row.iteration);
  if (i < 0) return [row, ...rows];
  if (isTickRow(row) && !isTickRow(rows[i])) return rows;
  return [for (var j = 0; j < rows.length; j++) j == i ? row : rows[j]];
}
