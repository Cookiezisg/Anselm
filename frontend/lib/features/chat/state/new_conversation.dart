import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_providers.dart';
import 'conversation_stream_provider.dart';

/// The landing's first send — the backend has no create-and-send endpoint, so this is TWO calls: create
/// the thread (empty title; the backend auto-titles after turn 1, and the rail fills the name in place
/// via the notifications echo) then send through the new thread's controller (whose keepAlive pin holds
/// it streaming across the navigation that follows). Returns the new conversation id for `context.go`.
///
/// landing 首发——后端无 create-and-send 合并端点,故两步:建线程(空标题;首回合后自动命名,rail 经
/// notifications 回声原位填名)→ 经新线程的控制器发送(其 keepAlive 钉住,随后的导航不断流)。返新会话 id 供导航。
Future<String> startConversation(Ref ref, String text) async {
  final conv = await ref.read(chatRepositoryProvider).createConversation();
  await ref.read(conversationStreamProvider(conv.id).notifier).send(text);
  return conv.id;
}

/// Riverpod-callable wrapper for widgets (WidgetRef lacks the plain Ref surface). widget 侧包装。
final startConversationProvider = Provider<Future<String> Function(String text)>(
  (ref) => (text) => startConversation(ref, text),
);
