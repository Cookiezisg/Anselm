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
