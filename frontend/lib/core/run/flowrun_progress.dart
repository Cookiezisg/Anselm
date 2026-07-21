import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One flowrun node's terminal tick off the entities stream (`node.type=run`, W6 backend:
/// `{flowrunId, nodeId, iteration, status, port?}` — `port` rides control's chosen branch /
/// approval's decision, so the taken path is visible live without a lazy GET).
///
/// entities 流上一个 flowrun 节点的终态 tick(W6 后端:`port` 捎带 control 选中分支/approval 决定,
/// 走向实时可见、免惰性 GET)。
class NodeTick {
  const NodeTick({
    required this.nodeId,
    required this.iteration,
    required this.status,
    this.port = '',
  });

  final String nodeId;
  final int iteration;
  final String status; // completed | failed | parked
  final String port;
}

/// The live progress of the flowrun behind ONE poll-type stage block (trigger_workflow): the
/// enqueue receipt opens it, node ticks append (newest last), the durable `run_terminal` closes
/// it. Ticks are EPHEMERAL presentation — flowrun_nodes rows stay the truth (E2); a missed tick
/// is a cosmetic gap, never a lie, and the terminal line always lands (durable).
///
/// 一个 poll 型舞台块(trigger_workflow)背后 flowrun 的活进度:入队回执开卷、节点 tick 追加(新在后)、
/// durable `run_terminal` 收卷。tick 是 ephemeral 呈现——flowrun_nodes 行仍是真相(E2);漏 tick 只是
/// 外观缺口、绝非谎言,终态行恒达(durable)。
class FlowrunProgress {
  const FlowrunProgress({
    required this.flowrunId,
    this.ticks = const [],
    this.terminal = '',
  });

  final String flowrunId;
  final List<NodeTick> ticks;

  /// '' while running; completed | failed | cancelled once the durable terminal lands.
  /// 运行中 '';durable 终态落地后为 completed/failed/cancelled。
  final String terminal;

  /// The stage renders only the LAST 12 ticks (stage_panel), so the scroll is bounded to this cap +
  /// headroom — a heavy iterative workflow (a node re-entered thousands of times) would otherwise grow
  /// the list unboundedly and make [withTick]'s copy O(n²) (measured: 905ms at 20k ticks) + leak memory
  /// (this provider is non-autoDispose). C-019. 舞台只显末 12,故有界(+ 余量);否则重迭代 workflow 令拷贝 O(n²)。
  static const maxTicks = 64;

  FlowrunProgress withTick(NodeTick t) {
    final next = ticks.length >= maxTicks
        ? [
            ...ticks.skip(ticks.length - maxTicks + 1),
            t,
          ] // drop the oldest, keep the last cap 丢最旧
        : [...ticks, t];
    return FlowrunProgress(
      flowrunId: flowrunId,
      ticks: next,
      terminal: terminal,
    );
  }

  FlowrunProgress withTerminal(String status) =>
      FlowrunProgress(flowrunId: flowrunId, ticks: ticks, terminal: status);
}

class FlowrunProgressController extends Notifier<FlowrunProgress?> {
  FlowrunProgressController(this.blockId);

  final String blockId;

  @override
  FlowrunProgress? build() => null;

  /// The enqueue receipt landed — open the scroll (the stage shows «listening» until ticks).
  /// 入队回执落地——开卷(有 tick 前舞台显「聆听中」)。
  void begin(String flowrunId) => state = FlowrunProgress(flowrunId: flowrunId);

  void tick(NodeTick t) =>
      state = (state ?? FlowrunProgress(flowrunId: '')).withTick(t);

  void terminal(String status) =>
      state = (state ?? FlowrunProgress(flowrunId: '')).withTerminal(status);
}

/// Per poll-block run progress. NOT autoDispose: the director host writes it from a stream
/// subscription with no watcher of its own — poll blocks are a handful per session, and each one's
/// footprint is now HARD-bounded to [FlowrunProgress.maxTicks] (C-019), so it dies with the app with a
/// tiny fixed cost (the same journal-beats-cache tradeoff the ledger makes).
///
/// 每 poll 块一份运行进度。非 autoDispose:导演器宿主从流订阅写入、自身无 watcher——poll 块每会话
/// 屈指可数,每份占用硬有界到 maxTicks(C-019)、随 app 释放(与台账同一取舍)。
final flowrunProgressProvider =
    NotifierProvider.family<
      FlowrunProgressController,
      FlowrunProgress?,
      String
    >(FlowrunProgressController.new);
