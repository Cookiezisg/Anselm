import '../../../core/sse/frame.dart';
import 'entity_kind.dart';

/// What a lifecycle notification means for the entity LIST. Coarse on purpose: the rail only needs
/// "add a row / drop a row / re-read this one row", so the long backend action vocab
/// (env_rebuilt/restarted/config_*/crashed/lifecycle_changed/attention_changed/run_failed/…) collapses
/// to [updated]. [edited] keeps its own value because the DETAIL view cares (a new active version).
///
/// 一条生命周期通知对实体列表的含义。刻意粗粒度:rail 只需"加行/删行/就地重读一行",故后端长动作词表
/// 坍缩为 [updated];[edited] 单列(详情关心新 active 版本)。
enum EntityAction { created, edited, deleted, updated, unknown }

/// A frontend-semantic projection of one lifecycle frame off the notifications SSE stream — the unit
/// the entity list reconciles against. The notifications stream stamps EVERY frame with
/// `scope.kind = "notification"` (the notification's own id), so the entity kind + action live in
/// `node.type` (`"function.created"`) and the entity id lives in the payload (`functionId` …). That is
/// why this is parsed here, not demuxed by scope. `durable` rides the envelope seq (E2): durable
/// (seq>0) → patch the list; ephemeral (seq=0) → leave the list untouched (DB-row-is-truth).
///
/// notifications 流上一条生命周期帧的前端语义投影。该流给每帧盖 `scope.kind="notification"`,故实体
/// kind+action 在 `node.type`、实体 id 在 payload——因此在此解析而非按 scope demux。`durable` 看
/// 信封 seq:durable→patch 列表;ephemeral→不动列表。
class EntitySignal {
  const EntitySignal({
    required this.kind,
    required this.id,
    required this.action,
    required this.durable,
  });

  final EntityKind kind;
  final String id;
  final EntityAction action;
  final bool durable;

  /// Project a notifications envelope onto a signal for [kind], or null if it is not a lifecycle frame
  /// for that kind (wrong domain, not a Signal, or missing the entity id).
  ///
  /// 把一条 notifications 信封投影成 [kind] 的信号;非该 kind 的生命周期帧则 null。
  static EntitySignal? fromEnvelope(EntityKind kind, StreamEnvelope env) {
    final frame = env.frame;
    if (frame is! FrameSignal) return null;
    final type = frame.node.type; // "<domain>.<action>"
    final dot = type.indexOf('.');
    if (dot <= 0) return null;
    if (type.substring(0, dot) != kind.scopeKind) return null;
    final id = frame.node.content?[kind.idField] as String?;
    if (id == null || id.isEmpty) return null;
    return EntitySignal(
      kind: kind,
      id: id,
      action: _action(type.substring(dot + 1)),
      durable: env.durable,
    );
  }

  static EntityAction _action(String verb) => switch (verb) {
        'created' => EntityAction.created,
        'deleted' => EntityAction.deleted,
        'edited' || 'reverted' => EntityAction.edited,
        'updated' ||
        'env_rebuilt' ||
        'restarted' ||
        'config_updated' ||
        'config_cleared' ||
        'crashed' ||
        'lifecycle_changed' ||
        'attention_changed' ||
        'run_failed' ||
        'approval_pending' =>
          EntityAction.updated,
        _ => EntityAction.unknown,
      };

  @override
  bool operator ==(Object other) =>
      other is EntitySignal &&
      other.kind == kind &&
      other.id == id &&
      other.action == action &&
      other.durable == durable;

  @override
  int get hashCode => Object.hash(kind, id, action, durable);

  @override
  String toString() => 'EntitySignal(${kind.name}:$id $action durable=$durable)';
}
