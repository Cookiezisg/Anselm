import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// One persisted transcript block — the REST projection of `messages.Block` (`GET
/// /conversations/{id}/messages` returns each message with its blocks). Distinct from the SSE frame
/// payloads in `block_content.dart`: this is the DURABLE row (`blk_`), the stream is the realtime echo;
/// hydration folds THIS shape into the same `BlockNode` tree a live frame produces. [type] stays an open
/// string on the wire (the producer-owned vocabulary — text/reasoning/tool_call/tool_result/progress/
/// compaction today); classification to `BlockKind` happens at fold time, `unknown`-safe. [attrs] carries
/// the persisted per-type extras (tool name/summary/danger, reasoning signature, entityRef…) that ride
/// inline on live frames — hydration must read BOTH homes.
///
/// 一条持久 transcript 块——`messages.Block` 的 REST 投影(blk_)。区别于 `block_content.dart` 的 SSE 帧载荷:
/// 这是**耐久行**、流是实时回声;水化把此形折进与 live 帧同一棵 `BlockNode` 树。[type] 线缆上保持开放字符串
/// (归类到 BlockKind 在折叠时做、unknown 兜底)。[attrs] 装持久化的分型附加(tool 名/summary/danger、reasoning
/// signature、entityRef…)——live 帧里这些在 content 内联,水化须两处都读。
@freezed
abstract class ChatBlock with _$ChatBlock {
  const factory ChatBlock({
    required String id,
    @Default('') String conversationId,
    @Default('') String messageId,
    @Default('') String parentBlockId,
    @Default(0) int seq,
    required String type,
    Map<String, dynamic>? attrs,
    @Default('') String content,
    @Default('') String status,
    @Default('') String error,
    // The row's write time (P1-e) — the backend has always serialized it; anchors/场次条 order
    // turns by message createdAt and blocks WITHIN a turn by seq, but a block-born anchor (a
    // dangerous tool, a compaction mark) timestamps by this. Nullable: live frames have no row
    // time until the close snapshot lands.
    // 行落盘时刻(P1-e)——后端一直在序列化;场次条按回合 createdAt 排、回合内按 seq,块生锚点
    // (危险工具/压缩标记)以此计时。可空:live 帧在 close 快照前无行时刻。
    DateTime? createdAt,
  }) = _ChatBlock;

  factory ChatBlock.fromJson(Map<String, dynamic> json) => _$ChatBlockFromJson(json);
}

/// One persisted transcript turn — the REST projection of `messages.MessageWithBlocks` (`msg_`).
/// [role] user|assistant; assistant terminals carry [status]/[stopReason]/[errorCode]/[errorMessage] +
/// token tallies (the honest turn-end banner reads these). [attrs] freezes the user turn's send-time
/// extras: `attachments` (id array, send order) + `mentions` (snapshots {type,id,name,content?} — a
/// broken reference degrades to name "(unavailable)" with NO content key). [subagentId] ≠ '' marks a
/// nested subagent turn (excluded from the top-level transcript). List order on the wire is keyset
/// newest-first; hydration reverses to chronological.
///
/// 一条持久回合——`messages.MessageWithBlocks` 的 REST 投影(msg_)。assistant 终态带 status/stopReason/
/// errorCode/errorMessage + token 计数(终态 banner 读它们)。[attrs] 冻结 user 回合发送时刻的附加:
/// `attachments`(id 数组、发送序)+ `mentions`(快照 {type,id,name,content?}——坏引用降级 name
/// "(unavailable)" 且**无 content 键**)。[subagentId]≠'' = 嵌套 subagent 回合(不入顶层 transcript)。
/// 线缆序 = keyset 新→旧;水化反转为时间序。
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    @Default('') String conversationId,
    @Default('') String subagentId,
    required String role,
    @Default('') String status,
    @Default('') String stopReason,
    @Default('') String errorCode,
    @Default('') String errorMessage,
    @Default(0) int inputTokens,
    @Default(0) int outputTokens,
    @Default('') String provider,
    @Default('') String modelId,
    Map<String, dynamic>? attrs,
    @Default(<ChatBlock>[]) List<ChatBlock> blocks,
    required DateTime createdAt,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
}
