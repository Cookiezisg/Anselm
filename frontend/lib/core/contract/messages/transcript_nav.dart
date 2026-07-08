import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_message.dart';

part 'transcript_nav.freezed.dart';
part 'transcript_nav.g.dart';

/// The `?around=` deep-jump window — the REST projection of the backend's window envelope
/// (`GET /conversations/{id}/messages?around=<messageId>`): a newest-first slice of turns centered
/// on [targetId] plus BOTH continuation coordinates. [olderCursor] feeds the plain `?cursor=` list
/// read; [newerCursor] feeds `?cursor=&dir=newer`; '' (absent on the wire) = that direction is
/// exhausted. The transcript's jump path REPLACES its window with this (re-anchor) — it is never
/// stitched into contiguous pages.
///
/// `?around=` 深跳窗——后端窗 envelope 的 REST 投影:以 [targetId] 为中心的 newest-first 回合切片 +
/// **双向**续翻坐标。[olderCursor] 喂普通 `?cursor=` 读、[newerCursor] 喂 `?cursor=&dir=newer`;
/// ''(线缆缺省)= 该方向已尽。transcript 跳转径以它**整窗替换**(re-anchor)——绝不缝进连续分页。
@freezed
abstract class MessagesWindow with _$MessagesWindow {
  const factory MessagesWindow({
    // Wire key `data` — the window envelope keeps its coordinates top-level BESIDE the array
    // (the same rule as the paged envelope). 线缆键 `data`——窗 envelope 坐标在顶层与数组并列。
    @JsonKey(name: 'data') @Default(<ChatMessage>[]) List<ChatMessage> messages,
    @Default('') String targetId,
    @Default('') String olderCursor,
    @Default('') String newerCursor,
    @Default(false) bool hasOlder,
    @Default(false) bool hasNewer,
  }) = _MessagesWindow;

  factory MessagesWindow.fromJson(Map<String, dynamic> json) => _$MessagesWindowFromJson(json);
}

/// One navigation anchor row (场次条) — the REST projection of `GET /conversations/{id}/anchors`.
/// [kind] stays an open wire string with the current vocabulary user | tools | danger | compaction
/// | abnormal | gate (unknown-safe: render nothing rather than lie). [messageId] anchors the jump
/// (`?around=`; '' on a gate = no jump). [blockId] pins the exact block for block-born kinds and
/// carries the toolCallId for a gate. [count] is the folded size of a `tools` cluster.
///
/// 一条导航锚点行(场次条)——`GET /conversations/{id}/anchors` 的 REST 投影。[kind] 线缆开放字符串,
/// 当前词表 user|tools|danger|compaction|abnormal|gate(unknown 兜底:宁不渲不撒谎)。[messageId] 锚定
/// 跳转(`?around=`;gate 上 ''=无跳)。[blockId] 钉块生 kind 的确切块、gate 上携 toolCallId。[count]
/// 是 tools 簇折叠数。
@freezed
abstract class TranscriptAnchor with _$TranscriptAnchor {
  const factory TranscriptAnchor({
    required String kind,
    @Default('') String messageId,
    @Default('') String blockId,
    @Default('') String title,
    @Default(0) int count,
    required DateTime at,
  }) = _TranscriptAnchor;

  factory TranscriptAnchor.fromJson(Map<String, dynamic> json) => _$TranscriptAnchorFromJson(json);
}
