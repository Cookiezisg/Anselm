import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/contract/entities/workflow.dart';
import '../selected_entity.dart';

part 'run_terminal_state.freezed.dart';

/// The run lifecycle — a small state machine the terminal header renders (the streaming body lives in a
/// separate [CoalescingNotifier], NOT here, so a delta firehose never churns this Riverpod state).
/// idle = form shown, not yet run; running = in flight; ok/failed/cancelled = terminal.
/// 运行生命周期(小状态机,终端头渲染它;流式 body 在另一个 CoalescingNotifier、不在此,故 delta 风暴不搅这份态)。
enum RunPhase { idle, running, ok, failed, cancelled }

/// The right-island run terminal's lifecycle state — bound to ONE entity ([ref]), the request that was
/// sent, and the terminal outcome (per-kind result fields). The high-frequency streamed output is held
/// OUTSIDE this state (see [RunTerminalController.stream]) so this object only changes a handful of times
/// per run (open → running → terminal). `open` drives [AnShell.inspectorOpen].
///
/// 右岛 run 终端的生命周期态——绑定一个实体([ref])、发出的请求、终态结果(各 kind 字段)。高频流式输出
/// 在本态之外(见 controller.stream),故本对象每次运行只变几次。`open` 驱动 AnShell.inspectorOpen。
@freezed
abstract class RunTerminalState with _$RunTerminalState {
  const factory RunTerminalState({
    @Default(false) bool open,
    EntityRef? ref,
    @Default(RunPhase.idle) RunPhase phase,
    @Default('')
    String method, // handler only: the selected method 仅 handler:选中方法
    @Default(<String, Object?>{})
    Map<String, Object?> request, // the args/input/payload sent 发出的入参
    Object? output, // fn/hd/ag result output 结果输出
    String? errorCode,
    String? errorMsg,
    @Default(0) int elapsedMs,
    String? logs, // fn captured logs 函数日志
    @Default(0) int steps, // agent 步数
    @Default(0) int tokensIn,
    @Default(0) int tokensOut,
    String? flowrunId, // workflow 触发的 flowrun id
    @Default(<FlowrunNode>[])
    List<FlowrunNode> flowNodes, // workflow durable node list 工作流节点(真相)
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
}
