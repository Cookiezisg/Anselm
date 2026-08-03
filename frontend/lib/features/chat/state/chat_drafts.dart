import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory per-thread composer drafts (keyed by conversation id; [landingKey] for the New page).
/// A mutable store behind a plain Provider — draft keystrokes must never rebuild ANY provider watcher
/// (the composer's own TextField holds live state; this is just switch-away/switch-back restore).
/// Session-scoped by design; cross-restart persistence is a later polish.
///
/// 内存逐线程草稿(键=会话 id;landing 用 [landingKey])。可变 store 挂普通 Provider——逐键**绝不**重建任何
/// watcher(实时态在 TextField 里,这只管切走/切回恢复)。会话级;跨重启持久化留后。
class ChatDrafts {
  static const landingKey = '__landing__';

  final Map<String, String> _byKey = {};

  String of(String key) => _byKey[key] ?? '';

  void set(String key, String text) {
    if (text.isEmpty) {
      _byKey.remove(key);
    } else {
      _byKey[key] = text;
    }
  }

  void clear(String key) => _byKey.remove(key);
}

final chatDraftsProvider = Provider<ChatDrafts>((ref) => ChatDrafts());

/// Explicit New chat actions must remount an already-visible landing composer. The draft store is
/// intentionally non-reactive during typing, so a cheap generation signal keeps that boundary explicit.
/// 显式「新对话」必须让已在 landing 上的输入框重挂。逐字输入期间草稿仓刻意不响应式重建，故用廉价
/// generation 信号明确表达这个丢弃边界。
class ChatLandingReset extends Notifier<int> {
  @override
  int build() => 0;

  /// Advance the landing generation after an explicit New chat discard boundary.
  /// 显式「新对话」丢弃边界后推进 landing generation。
  void bump() => state++;
}

final chatLandingResetProvider = NotifierProvider<ChatLandingReset, int>(
  ChatLandingReset.new,
);
