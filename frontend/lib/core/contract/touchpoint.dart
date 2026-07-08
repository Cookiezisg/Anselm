import 'package:freezed_annotation/freezed_annotation.dart';

part 'touchpoint.freezed.dart';
part 'touchpoint.g.dart';

/// How a conversation touched a thing — the backend's 7-verb CHECK-enforced closed set (DOC-049), plus
/// [unknown] as the standard forward-compat fallback. 触碰动词:后端 CHECK 强制 7 种 + unknown 兜底。
enum TouchpointVerb {
  mentioned,
  created,
  edited,
  viewed,
  executed,
  attached,
  deleted,
  unknown,
}

/// Who touched last — the backend's 3-actor closed set + fallback. 最后触碰者三种 + 兜底。
enum TouchpointActor {
  user,
  assistant,
  subagent,
  unknown,
}

/// One conversation-touchpoint AGGREGATE row — the backend projection of `conversation_touchpoints`
/// exactly as `GET /conversations/{id}/touchpoints` serves it (camelCase; mirrors
/// `references/backend/domains/touchpoint.md`). One row per (conversation, item, VERB) — count +
/// first/last timestamps, NOT an event log. The right island's Cast re-aggregates rows by
/// (kind,itemId) into entity rows (WRK-061 R-2) — that projection lives in the ledger provider, not
/// here. [itemKind] stays an OPEN string (relation's 11 entity kinds + `attachment`; the kind set
/// grows with the platform). [itemName] is the write-time display-name snapshot ("" = unresolved →
/// show [itemId] mono); [lastMessageId] anchors "jump to where it happened" ("" = hide the action).
///
/// 一条对话触点**聚合行**——`conversation_touchpoints` 的线缆投影(逐字镜像 DOC-049)。每 (对话,物,动词)
/// 一条:count + 首末时间,**非**事件日志。右岛演员表按 (kind,itemId) 二次聚合成实体行(WRK-061 R-2)——
/// 那层投影在 ledger provider、不在契约。itemKind 保持开放串(relation 11 实体种 + attachment,随平台长);
/// itemName 是写入时显示名快照(""=未解出→显 itemId mono);lastMessageId 锚「跳到发生处」(""=藏动作)。
@freezed
abstract class Touchpoint with _$Touchpoint {
  const Touchpoint._();

  const factory Touchpoint({
    required String id,
    @Default('') String conversationId,
    @Default('') String itemKind,
    @Default('') String itemId,
    @Default('') String itemName,
    @JsonKey(unknownEnumValue: TouchpointVerb.unknown)
    @Default(TouchpointVerb.unknown)
    TouchpointVerb verb,
    @JsonKey(unknownEnumValue: TouchpointActor.unknown)
    @Default(TouchpointActor.unknown)
    TouchpointActor lastActor,
    @Default(0) int count,
    required DateTime firstAt,
    required DateTime lastAt,
    @Default('') String lastMessageId,
  }) = _Touchpoint;

  factory Touchpoint.fromJson(Map<String, dynamic> json) => _$TouchpointFromJson(json);

  /// The display name, honestly falling back to the raw id (mono, muted at the call site) when the
  /// write-time snapshot resolved nothing. 显示名;快照空时诚实回退裸 id(调用处渲 mono 灰)。
  String get displayName => itemName.isNotEmpty ? itemName : itemId;
}
