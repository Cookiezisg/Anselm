import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/contract/entities/workflow.dart';

part 'run_terminal_state.freezed.dart';

/// The run lifecycle — a small state machine the terminal header renders (the streamed body lives in a
/// separate [CoalescingNotifier], NOT here, so a delta firehose never churns this Riverpod state).
/// idle = form shown, not yet run; running = in flight; ok/failed/cancelled = terminal.
/// 运行生命周期(小状态机,终端头渲染它;流式 body 在另一个 CoalescingNotifier、不在此,故 delta 风暴不搅这份态)。
enum RunPhase { idle, running, ok, failed, cancelled }

/// One executable entity's run state. The controller is a FAMILY keyed by [EntityRef] (so each entity has
/// its OWN run state + SSE subscription + coalescer): a run started on entity A keeps streaming when the
/// user selects B (background continue-streaming) and is intact when they return to A. The entity is the
/// family key — NOT in this state. The terminal's reveal (open/collapsed) is a SEPARATE concern
/// (`rightPanelProvider`), and the form's draft input lives on the controller (so the header verb CTA can
/// trigger a run too). Only `method` is here (it swaps the visible fields → must rebuild the form).
///
/// 一个可执行实体的运行态。controller 是按 [EntityRef] 的 family(每实体独立运行态 + SSE 订阅 + coalescer):
/// 在 A 上发起的运行,切到 B 仍后台续流、切回 A 完好。实体是 family 键、不在本态。揭示(开/收)是另一回事
/// (rightPanelProvider);表单草稿在 controller 上(故头部动词 CTA 也能触发 run)。仅 method 在此(它换可见字段、须重建表单)。
@freezed
abstract class RunTerminalState with _$RunTerminalState {
  const factory RunTerminalState({
    @Default(RunPhase.idle) RunPhase phase,
    @Default('')
    String
    method, // handler: the selected method (drives which fields render) 选中方法
    // workflow: the payload SOURCE — 'manual' or a mounted trigger id; drives which payload fields
    // render (来源选择器, 用户 0718 拍板: payload 是 trigger 释放信息的替身), and buckets the draft.
    // workflow 的 payload 来源('manual' 或挂载 trigger id):驱动 payload 字段渲染并给草稿分桶。
    @Default('manual') String source,
    Object? output, // fn/hd/ag result output 结果输出
    String? errorCode,
    String? errorMsg,
    String?
    inputError, // form validation (bad JSON in an object/array field) 入参校验错
    @Default(0) int elapsedMs,
    String? logs, // fn captured logs 函数日志
    @Default(0) int steps, // agent 步数
    @Default(0) int tokensIn,
    @Default(0) int tokensOut,
    String? flowrunId, // workflow 触发的 flowrun id
    // workflow node rows — REST truth merged with tick upserts (tick rows carry a `tick_` id and no
    // result until the reconcile lands). workflow 节点行:REST 真相 + tick upsert 合并(tick 行 id
    // 前缀 tick_、result 空,对账后被真相行顶替)。
    @Default(<FlowrunNode>[]) List<FlowrunNode> flowNodes,
    @Default('')
    String
    flowrunStatus, // flowrun header status from the last reconcile 最近对账的 run 头状态
    @Default(0)
    int
    runSeq, // generation counter — a stale run's result is dropped 运行代号,陈旧结果丢弃
  }) = _RunTerminalState;

  const RunTerminalState._();

  bool get isRunning => phase == RunPhase.running;
  bool get isTerminal =>
      phase == RunPhase.ok ||
      phase == RunPhase.failed ||
      phase == RunPhase.cancelled;

  /// The node currently parked on a human decision (its LATEST iteration is parked), if any —
  /// drives the approval gate. 正停车等人决断的节点(最新迭代 parked)——驱动审批门。
  FlowrunNode? get parkedNode {
    for (final r in flowNodes) {
      if (r.status != 'parked') continue;
      final newer = flowNodes.any(
        (o) => o.nodeId == r.nodeId && o.iteration > r.iteration,
      );
      if (!newer) return r;
    }
    return null;
  }
}
