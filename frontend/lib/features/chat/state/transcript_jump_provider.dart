import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot transcript jump command (Cast「跳到发生处」/ 场次条 anchors / the R-14 curtain →
/// the transcript view). The view is the SOLE consumer — it owns the ScrollController, so it
/// executes the jump (near = re-center the anchor; deep = fetch the `?around=` window and
/// re-anchor), scrolls, highlights, then clears the command. Every request is a fresh instance,
/// so repeat jumps to the same message still notify.
///
/// 一次性 transcript 跳转命令(Cast「跳到发生处」/ 场次条锚点 / R-14 谢幕 → transcript 视图)。
/// 视图是唯一消费者——它持有 ScrollController,负责执行(近跳=移锚;深跳=拉 `?around=` 窗重锚)、
/// 滚动、高亮、然后清除命令。每次请求都是新实例,重复跳同一条也会通知。
class TranscriptJumpRequest {
  const TranscriptJumpRequest(this.messageId, {this.blockId = ''});

  final String messageId;

  /// The exact block, when the anchor was block-born (a dangerous tool, a Subagent settle) — rows
  /// are message-keyed, so this only refines the future block-level highlight, never the scroll.
  /// 块生锚点的确切块——行按 message 键,此项只细化将来的块级高亮、不影响滚动。
  final String blockId;
}

class TranscriptJumpController extends Notifier<TranscriptJumpRequest?> {
  TranscriptJumpController(this.conversationId);

  final String conversationId;

  @override
  TranscriptJumpRequest? build() => null;

  void request(String messageId, {String blockId = ''}) =>
      state = TranscriptJumpRequest(messageId, blockId: blockId);

  void clear() => state = null;
}

/// Per-conversation jump channel (autoDispose family — dies with the thread's UI).
/// 每会话跳转通道(autoDispose family,随线程 UI 释放)。
final transcriptJumpProvider = NotifierProvider.autoDispose
    .family<TranscriptJumpController, TranscriptJumpRequest?, String>(TranscriptJumpController.new);
