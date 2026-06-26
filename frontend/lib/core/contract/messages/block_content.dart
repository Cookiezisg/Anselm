/// The Quadrinity run-trace / chat block contract — the typed `content` payloads carried by a
/// messages-vocabulary stream node (text / reasoning / tool_call / tool_result / progress / compaction
/// / the message wrapper). Each is a 1:1 freezed mirror of a backend Go struct (cited per type); the
/// agent run-terminal (STEP 5) renders the LIVE entities-stream mirror with these, and the future Chat
/// feature (4.2) reuses the same DTOs for the messages stream. Wire = camelCase; `danger`/`status`/
/// `stopReason` stay open Strings (state strings are never sealed — forward-compat).
///
/// Quadrinity run 轨迹 / chat 块契约——messages 词汇流节点携带的 typed `content`。逐一镜像后端 Go 结构;
/// agent run 终端(STEP 5)用它渲实时 entities 镜像,未来 Chat(4.2)在 messages 流复用同一批 DTO。
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'block_content.freezed.dart';
part 'block_content.g.dart';

/// The sealed set of block types (CLAUDE.md "6 block 型"): the six persisted `message_blocks` kinds
/// (messages.go:55-81). `message` is the meta WRAPPER node (chat top-of-turn; NOT a persisted block,
/// NOT mirrored to the agent entities stream) and `unknown` is the forward-compat fallback — both are
/// modelled here so a reducer can classify any wire `node.type`. The on-wire string is OPEN
/// ([StreamNode.type]); this enum is only the consumer's classification.
///
/// block 型枚举:6 个持久化块型 + `message`(元包装,非持久块、不镜像到 agent entities 流)+ `unknown`
/// 兜底。线缆 node.type 是开放串([StreamNode.type]),本枚举只是消费方的归类。
@JsonEnum()
enum BlockKind {
  @JsonValue('text')
  text,
  @JsonValue('reasoning')
  reasoning,
  @JsonValue('tool_call')
  toolCall,
  @JsonValue('tool_result')
  toolResult,
  @JsonValue('progress')
  progress,
  @JsonValue('compaction')
  compaction,
  @JsonValue('message')
  message,
  unknown,
}

/// Classify a wire `node.type` string into a [BlockKind] (unknown for anything the client doesn't model
/// — never throws, the type set is producer-owned + open). 把线缆 node.type 归类(未知→unknown,不抛)。
BlockKind blockKindFromWire(String wire) => switch (wire) {
  'text' => BlockKind.text,
  'reasoning' => BlockKind.reasoning,
  'tool_call' => BlockKind.toolCall,
  'tool_result' => BlockKind.toolResult,
  'progress' => BlockKind.progress,
  'compaction' => BlockKind.compaction,
  'message' => BlockKind.message,
  _ => BlockKind.unknown,
};

/// The 3-level danger set an LLM self-reports per tool call (tool.go:28-38) — open String on the wire,
/// these constants are the ones the UI branches on for the danger badge. 危险三级(LLM 逐次自报)。
abstract final class Danger {
  static const safe = 'safe';
  static const cautious = 'cautious';
  static const dangerous = 'dangerous';
}

/// `text` / `reasoning` open+close content (`reasoning` adds an optional provider signature). The OPEN
/// frame carries `{content:""}`; deltas stream tokens; the CLOSE `result` snapshot carries the full
/// text (the reconnect truth). stream.go:30-36。
@freezed
abstract class TextContent with _$TextContent {
  const factory TextContent({
    @Default('') String content,
    String?
    signature, // reasoning only (reasoningContent.Signature, omitempty) 仅 reasoning
  }) = _TextContent;
  factory TextContent.fromJson(Map<String, dynamic> json) =>
      _$TextContentFromJson(json);
}

/// `tool_call` content: `name` on OPEN; `arguments` (the full args JSON, stringified) + the LLM's
/// self-reported `summary`/`danger` on the CLOSE snapshot (args stream as deltas in between).
/// stream.go:37-48。
@freezed
abstract class ToolCallContent with _$ToolCallContent {
  const factory ToolCallContent({
    @Default('') String name,
    String? arguments,
    String? summary,
    String? danger,
  }) = _ToolCallContent;
  factory ToolCallContent.fromJson(Map<String, dynamic> json) =>
      _$ToolCallContentFromJson(json);
}

/// `tool_result` content — the tool's output rides the OPEN frame (tool_result does NOT stream; CLOSE
/// carries status/error only). Nests under its `tool_call` (parentId). tools.go:28-30。
@freezed
abstract class ToolResultContent with _$ToolResultContent {
  const factory ToolResultContent({@Default('') String content}) =
      _ToolResultContent;
  factory ToolResultContent.fromJson(Map<String, dynamic> json) =>
      _$ToolResultContentFromJson(json);
}

/// The `message` WRAPPER node content: `role` + `subagent` on OPEN; the terminal `status`/`stopReason`/
/// token tally on the CLOSE snapshot. Emitted on the MESSAGES stream (chat) only — the agent's entities
/// mirror has NO message wrapper (top-level blocks are roots). chat/emit.go:26-54, subagent/emit.go:22。
@freezed
abstract class MessageContent with _$MessageContent {
  const factory MessageContent({
    @Default('') String role,
    bool? subagent,
    String? content, // user-turn close 用户回合
    String? status, // assistant-turn close 助手回合
    String? stopReason,
    int? inputTokens,
    int? outputTokens,
    String? errorCode,
    String? errorMessage,
  }) = _MessageContent;
  factory MessageContent.fromJson(Map<String, dynamic> json) =>
      _$MessageContentFromJson(json);
}
