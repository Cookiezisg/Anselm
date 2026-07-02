import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_stream_state.freezed.dart';

/// The transcript lifecycle. hydrating = first REST head in flight; ready = rendering (live frames fold
/// into the coalescer, NOT here); error = hydration failed (explicit retry). 生命周期:水化中/就绪/失败。
enum TranscriptPhase { hydrating, ready, error }

/// The LOW-FREQUENCY state of one open conversation — lifecycle + upward pagination only. The
/// high-frequency transcript body deliberately lives OUTSIDE Riverpod (a per-build
/// `CoalescingNotifier<ConversationTranscript>` on the controller), so a token firehose never rebuilds
/// provider watchers; this state changes a handful of times per session.
///
/// 一个打开会话的**低频**状态——仅生命周期 + 向上分页。高频 transcript 本体刻意在 Riverpod 之外(controller 上
/// 每 build 重建的 CoalescingNotifier),token 火喉永不重建 provider watcher;本状态每会话只变个位数次。
@freezed
abstract class ConversationStreamState with _$ConversationStreamState {
  const factory ConversationStreamState({
    @Default(TranscriptPhase.hydrating) TranscriptPhase phase,
    String? error,
    String? nextCursor,
    @Default(false) bool hasMoreOlder,
    @Default(false) bool loadingOlder,
  }) = _ConversationStreamState;
}
