import '../../../core/sse/frame.dart';

/// What a `conversation.<action>` lifecycle notification means for the conversation LIST. Coarse on
/// purpose — the rail only needs "add a row / drop a row / re-read this one row". The backend's fuller
/// action vocab (updated/archived/unarchived/pinned/unpinned/auto_titled/model_override/compacted) all
/// collapse to [updated]: the rail reconciles them identically by re-fetching that row and folding it in
/// (which re-buckets pinned, drops an archived row when archived is hidden, or updates the title).
///
/// 一条 `conversation.<动作>` 通知对列表的含义。刻意粗粒度——rail 只需「加行/删行/就地重读一行」。后端更全的
/// 动作词表(updated/archived/…/auto_titled/…)全坍缩为 [updated]:rail 一律重取该行并折入(重分置顶、隐藏时移出
/// 归档行、或更新标题)。
enum ConversationAction { created, deleted, updated, unknown }

/// A frontend-semantic projection of one `conversation.<action>` frame off the notifications SSE stream —
/// the unit the conversation list reconciles against. Like [EntitySignal], the notifications stream stamps
/// every frame `scope.kind = "notification"`, so the domain + action live in `node.type`
/// (`"conversation.auto_titled"`) and the id lives in the payload (`conversationId`). `durable` rides the
/// envelope seq (E2): durable (seq>0) → patch the list; ephemeral (seq=0) → leave the list untouched
/// (DB-row-is-truth). Conversation lifecycle is always emitted durable, but we guard anyway.
///
/// notifications 流上一条 `conversation.<动作>` 帧的前端语义投影——列表据此重排。同 EntitySignal:该流给每帧盖
/// `scope.kind="notification"`,故域+动作在 `node.type`、id 在 payload(`conversationId`)。`durable` 看信封 seq:
/// durable→patch 列表;ephemeral→不动列表(DB 行是真相)。对话生命周期恒 durable,仍照 guard。
class ConversationSignal {
  const ConversationSignal({
    required this.id,
    required this.action,
    required this.durable,
  });

  final String id;
  final ConversationAction action;
  final bool durable;

  /// Project a notifications envelope onto a conversation signal, or null if it is not a conversation
  /// lifecycle frame (wrong domain, not a Signal, or missing the id).
  ///
  /// 把一条 notifications 信封投影成对话信号;非对话生命周期帧则 null。
  static ConversationSignal? fromEnvelope(StreamEnvelope env) {
    final frame = env.frame;
    if (frame is! FrameSignal) return null;
    final type = frame.node.type; // "<domain>.<action>"
    final dot = type.indexOf('.');
    if (dot <= 0) return null;
    if (type.substring(0, dot) != 'conversation') return null;
    final id = frame.node.content?['conversationId'] as String?;
    if (id == null || id.isEmpty) return null;
    return ConversationSignal(
      id: id,
      action: _action(type.substring(dot + 1)),
      durable: env.durable,
    );
  }

  static ConversationAction _action(String verb) => switch (verb) {
    'created' => ConversationAction.created,
    'deleted' => ConversationAction.deleted,
    'updated' ||
    'archived' ||
    'unarchived' ||
    'pinned' ||
    'unpinned' ||
    'auto_titled' ||
    'model_override' ||
    // WRK-083 B1. The backend has emitted `conversation.work_dir` since WRK-077 WD1; this table never
    // learned the verb, so every residency mount/switch/leave fell through to [unknown] and the rail's
    // `_onSignal` returned without doing anything. That is the whole of "改驻地后左岛不刷新" — the rail's
    // regrouping machinery was already built for it (`applyUpdate` re-buckets by `_axisOf` and re-asks the
    // server for group counts, with a comment reasoning about the just-LEFT-a-residency case), it simply
    // never received the signal that would run it.
    // WRK-083 B1。后端自 WRK-077 WD1 起就在发 `conversation.work_dir`;本表从未学会这个动词,于是每一次挂/切/退
    // 驻地都落进 [unknown],rail 的 `_onSignal` 直接 return。这就是「改驻地后左岛不刷新」的全部——rail 的重分组
    // 机器**早就为它建好了**(`applyUpdate` 按 `_axisOf` 重新归段、并向服务端重问组计数,注释里连「刚离开驻地」
    // 那一格都推演过),它只是从没收到那个会让它跑起来的信号。
    'work_dir' ||
    'compacted' => ConversationAction.updated,
    // Unknown is a real fallback, not a dumping ground: the protocol is open (CLAUDE.md keeps SSE
    // `node.type` unsealed), so a verb this build has never heard of must degrade quietly rather than
    // crash. The cost is that a verb the backend DOES emit and this table forgot is also swallowed
    // quietly — which is exactly how B1 survived. `cmd/docs`'s signal-vocabulary drift pass exists to
    // make that impossible to repeat: it diffs this switch against the family registered in events.md.
    // unknown 是真兜底、不是垃圾桶:协议是开放的(CLAUDE.md 明写 SSE `node.type` 不封闭),故本构建没听过的动词
    // 必须安静降级、而不是崩。代价是**后端确实在发、而本表漏了**的动词同样被安静吞掉——B1 正是这么活下来的。
    // `cmd/docs` 的信号词表漂移 pass 就是为了让这件事不可能重演:它把这个 switch 与 events.md 里登记的族逐字 diff。
    _ => ConversationAction.unknown,
  };

  @override
  bool operator ==(Object other) =>
      other is ConversationSignal &&
      other.id == id &&
      other.action == action &&
      other.durable == durable;

  @override
  int get hashCode => Object.hash(id, action, durable);

  @override
  String toString() => 'ConversationSignal($id $action durable=$durable)';
}
