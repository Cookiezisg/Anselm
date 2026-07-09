import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/model_capability.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/data/conversation_signal.dart';
import 'package:anselm/core/model/model_capabilities.dart';
import 'package:anselm/features/chat/state/conversation_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The head controller: fetch-on-open, AUTO-TITLE lands live via the lifecycle echo (the whole point),
// rename/model PATCH from the authoritative response, ephemeral signals ignored.
// 头控制器:打开即取、**自动命名经回声活着落**(重点)、改名/选模型走权威响应、ephemeral 不理。

Conversation _conv(String id, {String title = '', ModelRef? model}) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(
      id: id, title: title, modelOverride: model, createdAt: at, updatedAt: at, lastMessageAt: at);
}

void main() {
  (ProviderContainer, FixtureChatRepository) setup() {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.listen(conversationHeaderProvider('cv_1'), (_, _) {});
    return (c, repo);
  }

  test('auto-title: the lifecycle echo re-reads the row — the head title fills in live', () async {
    final (c, repo) = setup();
    await c.read(conversationHeaderProvider('cv_1').future);
    expect(c.read(conversationHeaderProvider('cv_1')).value!.title, '');

    repo.upsert(_conv('cv_1', title: '季度对账问题')); // the backend titled it 后端已命名
    repo.emitSignal(const ConversationSignal(
        id: 'cv_1', action: ConversationAction.updated, durable: true));
    await pumpEventQueue();
    expect(c.read(conversationHeaderProvider('cv_1')).value!.title, '季度对账问题');
  });

  test('an ephemeral signal or another thread\'s signal never patches', () async {
    final (c, repo) = setup();
    await c.read(conversationHeaderProvider('cv_1').future);
    repo.upsert(_conv('cv_1', title: '不该出现'));
    repo.emitSignal(const ConversationSignal(
        id: 'cv_1', action: ConversationAction.updated, durable: false)); // ephemeral
    repo.emitSignal(const ConversationSignal(
        id: 'cv_other', action: ConversationAction.updated, durable: true)); // other thread
    await pumpEventQueue();
    expect(c.read(conversationHeaderProvider('cv_1')).value!.title, '');
  });

  test('rename + setModel patch from the authoritative response (tristate clear works)', () async {
    final (c, repo) = setup();
    await c.read(conversationHeaderProvider('cv_1').future);
    final ctl = c.read(conversationHeaderProvider('cv_1').notifier);

    await ctl.rename('  改个名  ');
    expect(c.read(conversationHeaderProvider('cv_1')).value!.title, '改个名');

    await ctl.setModel((apiKeyId: 'ak_1', modelId: 'deepseek-chat'));
    expect(c.read(conversationHeaderProvider('cv_1')).value!.modelOverride?.modelId, 'deepseek-chat');

    await ctl.setModel(null); // Auto — explicit clear 显式清
    expect(c.read(conversationHeaderProvider('cv_1')).value!.modelOverride, isNull);
  });

  test('model capability options come through the CORE seam (S-15 moved off the chat repo)', () async {
    final c = ProviderContainer(overrides: [
      modelCapabilitiesProvider.overrideWith((ref) async => const [
            ModelCapability(
                apiKeyId: 'ak_1', modelId: 'deepseek-chat', displayName: 'DeepSeek', provider: 'anselm'),
          ]),
    ]);
    addTearDown(c.dispose);
    final caps = await c.read(modelCapabilitiesProvider.future);
    expect(caps.single.modelId, 'deepseek-chat');
  });
}
