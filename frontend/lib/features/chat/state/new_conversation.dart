import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_providers.dart';
import '../model/mention_spans.dart';
import 'conversation_header.dart';
import 'conversation_stream_provider.dart';

/// The landing's first send — the backend has no create-and-send endpoint, so this is create → (stamp
/// the landing's model choice via the modelOverride PATCH — create takes only a title, PATCH is the only
/// path, and it must land before the first turn is picked up) → send through the new thread's controller
/// (whose keepAlive pin holds it streaming across the navigation that follows). The empty title
/// auto-fills after turn 1 via the notifications echo. Returns the new conversation id for `context.go`.
///
/// landing 首发——后端无 create-and-send 合并端点:建线程 →(landing 选了模型则经 modelOverride PATCH
/// **先于首条消息**盖章——建会话只收 title、PATCH 是唯一路径)→ 经新线程的控制器发送(keepAlive 钉住,
/// 随后的导航不断流)。空标题首回合后经 notifications 回声自动填。返新会话 id 供导航。
Future<String> startConversation(Ref ref, String text,
    {List<MentionSnapshot> mentions = const [], List<String> attachmentIds = const []}) async {
  final repo = ref.read(chatRepositoryProvider);
  final conv = await repo.createConversation();
  try {
    final model = ref.read(landingModelProvider);
    if (model != null) await repo.setModelOverride(conv.id, model);
    await ref.read(conversationStreamProvider(conv.id).notifier).send(text, mentions: mentions, attachmentIds: attachmentIds);
  } catch (_) {
    // Roll back the just-created thread so a failed model-stamp / first-send never leaves an empty-title
    // orphan in the rail (create succeeded but nothing rode it). Best-effort delete; RETHROW the original
    // error so the landing composer keeps the user's text for a retry (its submit-failure contract).
    // 回滚刚建线程:模型盖章/首发失败绝不留空标题孤儿(删尽力而为,重抛原错使 landing composer 留字供重试)。
    try {
      await repo.deleteConversation(conv.id);
    } catch (_) {/* best-effort rollback — the original error still surfaces 尽力回滚,原错照冒 */}
    rethrow;
  }
  return conv.id;
}

/// Riverpod-callable wrapper for widgets (WidgetRef lacks the plain Ref surface). widget 侧包装。
final startConversationProvider = Provider<
    Future<String> Function(String text,
        {List<MentionSnapshot> mentions, List<String> attachmentIds})>(
  (ref) => (text, {mentions = const [], attachmentIds = const []}) =>
      startConversation(ref, text, mentions: mentions, attachmentIds: attachmentIds),
);
