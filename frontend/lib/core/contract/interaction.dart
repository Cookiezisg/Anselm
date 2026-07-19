// The Dart projection of the human-loop `humanloop.Request` (backend app/humanloop/humanloop.go) —
// the payload of an `interaction` signal frame AND of one row in `GET /conversations/{id}/interactions`.
// It is a discriminated union on [kind]: a `danger` gate (a dangerous tool call awaiting approval) or
// an `ask` prompt (ask_user awaiting an answer). The SAME shape, with `resolved:true`, is broadcast as
// the symmetric resolution signal after a decision — there `kind`/`tool` arrive as EMPTY strings (the
// struct fields have no omitempty), so resolution is keyed on `resolved`, never on kind/tool absence.
//
// 人在环 humanloop.Request 的 Dart 投影——`interaction` 信号帧与 GET interactions 一行的 payload。按
// [kind] 判别:danger 门(危险调用待批)/ ask 提问(ask_user 待答)。决议后发同型 `resolved:true` 对称
// 信号,其 kind/tool 为**空串**(结构体无 omitempty)——判 resolved 一律看 resolved 位、绝不靠 kind/tool 缺席。
library;

/// The interaction variant. `unknown` covers the resolution signal (empty kind) and any future kind —
/// the parser never crashes on an unrecognized value (forward-compat, mirrors the SSE node.type rule).
/// 交互变体。unknown 兜住 resolved 信号(空 kind)与未来新 kind——解析器永不因未知值崩(前向兼容)。
enum InteractionKind { danger, ask, unknown }

class Interaction {
  const Interaction({
    required this.toolCallId,
    required this.kind,
    required this.tool,
    required this.resolved,
    this.summary,
    this.args,
    this.message,
    this.options,
  });

  /// The tool_call block id this interaction gates — the join key across the three sources. 门所在块 id、三源合一键。
  final String toolCallId;
  final InteractionKind kind;

  /// The gated tool's name (danger) / `ask_user` (ask) / empty (resolution signal). 被门工具名。
  final String tool;

  /// True only on the symmetric resolution signal — the awaiting record should clear. 仅决议对称信号为真。
  final bool resolved;

  // ── danger variant (prompt = {summary, args}) ──
  /// The LLM's self-reported one-line intent (the user's primary evidence). LLM 自报意图。
  final String? summary;

  /// The cleaned business args (framework keys already stripped) — render directly. 已剥框架键的干净 args。
  final Map<String, dynamic>? args;

  // ── ask variant (prompt = {message, options}) ──
  /// The question text (ask_user). 问题正文。
  final String? message;

  /// The offered choices (may be absent → free-text only). 选项(可缺→纯文本)。
  final List<String>? options;

  bool get isAwaiting => !resolved && kind != InteractionKind.unknown;

  /// Parse from either an `interaction` signal's `node.content` or a `GET interactions` row (same shape).
  /// 从 interaction 信号 content 或 GET interactions 一行解析(同形)。
  factory Interaction.fromJson(Map<String, dynamic> json) {
    final prompt = json['prompt'] as Map<String, dynamic>?;
    return Interaction(
      toolCallId: json['toolCallId'] as String? ?? '',
      kind: switch (json['kind']) {
        'danger' => InteractionKind.danger,
        'ask' => InteractionKind.ask,
        _ => InteractionKind.unknown,
      },
      tool: json['tool'] as String? ?? '',
      resolved: json['resolved'] == true,
      summary: prompt?['summary'] as String?,
      args: prompt?['args'] as Map<String, dynamic>?,
      message: prompt?['message'] as String?,
      options: (prompt?['options'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}

/// The closed set of resolution actions (backend `interactions.go` validates exactly these). ghost/deny is
/// the fail-safe default; `approveAlways` whitelists (conversation, tool) IN MEMORY ONLY (lost on restart).
/// 决议动作封闭集(后端逐字校验)。deny=fail-safe;approveAlways 仅内存白名单(重启即忘)。
enum InteractionAction {
  approve, // danger: run it
  approveAlways, // danger: run it + don't ask again this conversation (memory only)
  deny, // danger: refuse
  accept, // ask: submit an answer
  decline; // ask: refuse to answer

  /// The exact wire token the POST body carries. 线缆精确串。
  String get wire => switch (this) {
        InteractionAction.approve => 'approve',
        InteractionAction.approveAlways => 'approve_always',
        InteractionAction.deny => 'deny',
        InteractionAction.accept => 'accept',
        InteractionAction.decline => 'decline',
      };
}
