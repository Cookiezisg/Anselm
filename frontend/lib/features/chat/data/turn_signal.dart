import '../../../core/sse/frame.dart';

/// What a turn-lifecycle frame means to the RAIL's activity dots. rail 活态点关心的回合生命周期。
enum TurnSignalKind {
  /// A durable top-level `message` OPEN — a turn began (the user echo opens first, so the blue
  /// generating dot lights at the earliest durable moment). 顶层 message open:回合开始(回声先开,蓝点最早点亮)。
  turnOpen,

  /// A durable `message` CLOSE — a turn reached a terminal (any status: completed / cancelled /
  /// error / max_steps / budget); the dot re-read derives blue-off + unread from the row.
  /// message close:回合终态(任意状态);重读行派生 蓝灭+未读。
  turnClose,

  /// An `interaction` signal — human-loop pending flipped (the amber dot; resolution without a
  /// resolved-frame converges via the eventual turnClose). interaction 信号:人在环翻转(琥珀;静默降位由终态收敛)。
  interaction,
}

typedef TurnSignal = ({String conversationId, TurnSignalKind kind});

/// Map one messages-stream envelope to a rail turn signal, or null for everything the dots don't
/// care about. PURE + O(1) — it runs on the RAW workspace feed (deltas included), so it must stay a
/// constant-cost plain-Dart filter (the demux-layer discipline: per-frame work is fine HERE, never
/// in a Riverpod build). Nested subagent message closes also map to turnClose — a harmless extra
/// debounced re-read (idempotent), cheaper than tracking the parent chain.
///
/// 把一条 messages 流信封映射成 rail 回合信号;点不关心的一律 null。**纯函数 + O(1)**——跑在 RAW
/// workspace 全量 feed 上(含 delta),必须保持常数代价的 plain-Dart 过滤(demux 层纪律:逐帧功在
/// **这里**没问题、绝不进 Riverpod build)。嵌套 subagent 的 message close 也映射 turnClose——
/// 多一次防抖重读(幂等)无害,比追踪父链便宜。
TurnSignal? turnSignalFromEnvelope(StreamEnvelope env) {
  if (env.scope.kind != 'conversation' || env.scope.id.isEmpty) return null;
  final frame = env.frame;
  if (frame is FrameSignal) {
    if (frame.node.type != 'interaction') return null;
    return (conversationId: env.scope.id, kind: TurnSignalKind.interaction);
  }
  if (env.seq <= 0) return null; // ephemeral (deltas/ticks) never drive the dots 瞬时帧不驱动点
  if (frame is FrameOpen) {
    if (frame.node.type != 'message' || (frame.parentId ?? '').isNotEmpty) return null;
    return (conversationId: env.scope.id, kind: TurnSignalKind.turnOpen);
  }
  if (frame is FrameClose) {
    if (frame.result?.type != 'message') return null;
    return (conversationId: env.scope.id, kind: TurnSignalKind.turnClose);
  }
  return null;
}
