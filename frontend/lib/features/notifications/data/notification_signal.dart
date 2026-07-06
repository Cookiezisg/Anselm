import '../../../core/sse/frame.dart';

/// A frontend-semantic projection of ONE notifications-stream frame — the tick the notification center
/// reconciles against. Unlike [ConversationSignal]/[EntitySignal], this is the only consumer that cares
/// about notification rows THEMSELVES (not another domain's lifecycle echo), so its job is narrow: tell
/// the badge + tray "the notification stream moved — reconcile".
///
/// Why a NUDGE, not an increment: post-N0 the stream carries BOTH tiers of durable signal — inbox-backed
/// (Emit → a row exists) and frame-only (Broadcast → no row) — shaped identically, and some types are
/// genuinely ambiguous (`memory.updated` is a persisted content-write OR a frame-only pin echo, same
/// node.type + payload). So a frame can NEVER be trusted to mean "+1 unread"; the source of truth is the
/// REST list / `unread-count`. This signal only says "refetch". [inboxCandidate] is a pure PERF filter —
/// it drops the loudest guaranteed-frame-only echoes (conversation.*, document tree refreshes) so a burst
/// of chat activity doesn't trigger a refetch storm — never a correctness filter (the ambiguous types
/// stay candidates and simply cost a reconciling refetch that returns the authoritative count).
///
/// notifications 流一帧的前端语义投影——通知中心据此对账的 tick。它是唯一关心「通知行本体」的消费者(非别域
/// 生命周期回声),故职责窄:告诉 badge+托盘「流动了、去对账」。为何是 nudge 而非 +1:N0 后流承载两档 durable
/// 信号——落行(Emit)与仅帧(Broadcast)——帧形一致,且有的 type 真歧义(`memory.updated` 可能是落行内容写、
/// 也可能是仅帧 pin 回声,同 node.type+payload)。故一帧绝不能当「+1 未读」,真相是 REST list/unread-count。
/// 此信号只说「refetch」。inboxCandidate 是纯性能过滤——滤掉最吵的确定仅帧回声(conversation.* / documents
/// 树刷新),免聊天爆发触发 refetch 风暴;非正确性过滤(歧义 type 仍是候选、只多一次对账 refetch 拿权威计数)。
class NotificationSignal {
  const NotificationSignal({
    required this.type,
    required this.durable,
    required this.inboxCandidate,
  });

  /// The `<domain>.<action>` event type off `node.type`. 事件类型。
  final String type;

  /// seq>0 — a reconnect replays it. Non-durable notification frames don't exist today, but we guard so a
  /// hypothetical ephemeral one never advances the inbox. durable(seq>0);非 durable 帧不参与对账。
  final bool durable;

  /// False for types that are DEFINITELY frame-only reconciliation echoes (never an inbox row) — a perf
  /// hint so the badge/list refetch on inbox-worthy ticks only. 确定仅帧回声=false(纯性能提示)。
  final bool inboxCandidate;

  /// Project a notifications envelope. null when it is not a lifecycle Signal (wrong frame kind, or a
  /// node.type without a `<domain>.<action>` dot). 投影;非生命周期 Signal 则 null。
  static NotificationSignal? fromEnvelope(StreamEnvelope env) {
    final frame = env.frame;
    if (frame is! FrameSignal) return null;
    final type = frame.node.type; // "<domain>.<action>"
    final dot = type.indexOf('.');
    if (dot <= 0) return null;
    return NotificationSignal(
      type: type,
      durable: env.durable,
      inboxCandidate: !_isReconciliationEcho(type),
    );
  }

  /// The guaranteed-frame-only echoes (events.md ⤳ that carry NO ambiguity): every conversation.* event
  /// and the document tree-refresh trio. The ambiguous ⤳ types (memory.updated pin, handler.restarted
  /// ok:true, sandbox installing/env_deleted) are intentionally NOT here — they stay candidates so a real
  /// sibling row is never missed; the cost is one reconciling refetch. 确定无歧义的仅帧回声(会话全族 +
  /// 文档树刷新三件);歧义的仅帧 type 故意不列(留候选,免漏真行,代价=一次对账 refetch)。
  static bool _isReconciliationEcho(String type) =>
      type.startsWith('conversation.') ||
      type == 'document.created' ||
      type == 'document.updated' ||
      type == 'document.moved';

  @override
  bool operator ==(Object other) =>
      other is NotificationSignal &&
      other.type == type &&
      other.durable == durable &&
      other.inboxCandidate == inboxCandidate;

  @override
  int get hashCode => Object.hash(type, durable, inboxCandidate);

  @override
  String toString() => 'NotificationSignal($type durable=$durable inbox=$inboxCandidate)';
}
