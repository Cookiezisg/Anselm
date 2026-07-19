import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/conversation_header.dart';
import 'package:anselm/features/chat/state/new_conversation.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/ui/chat_composer.dart';
import 'package:anselm/features/chat/ui/chat_ocean.dart';
import 'package:anselm/features/chat/ui/chat_transcript.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The center composition: no selection → the landing (STATIC greeting + floating composer, NO
// transcript); a selection → transcript + docked composer. Plus the landing model stamp: the sticky
// choice is PATCHed onto the new thread between create and send.
// 中心组合:无选区=landing(静态问候+浮起 composer);有选区=transcript+停靠 composer。外加 landing 模型
// 盖章:粘性选择在 create 与 send 之间 PATCH 到新线程。

Conversation _conv(String id) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(id: id, title: 'T', createdAt: at, updatedAt: at, lastMessageAt: at);
}

class _Selected extends SelectedConversation {
  _Selected(this.value);
  final ConversationRef? value;
  @override
  ConversationRef? build() => value;
}

Widget _host(FixtureChatRepository repo, ConversationRef? selected) => ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        selectedConversationProvider.overrideWith(() => _Selected(selected)),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: ChatOcean()),
        ),
      ),
    );

void main() {
  testWidgets('no selection → landing: static greeting + floating composer, no transcript', (tester) async {
    final repo = FixtureChatRepository(conversations: [], messages: {});
    await tester.pumpWidget(_host(repo, null));
    await tester.pump(const Duration(milliseconds: 400)); // entry fade done (240ms, one-shot) 入场淡入完
    final t = Translations.of(tester.element(find.byType(ChatOcean)));
    expect(find.text(t.chat.landingGreeting), findsOneWidget); // static — no typewriter 静态
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.byType(ChatTranscriptView), findsNothing);
  });

  testWidgets('a selection → transcript + docked composer, no greeting', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    await tester.pumpWidget(_host(repo, const ConversationRef('cv_1')));
    await tester.pump(const Duration(milliseconds: 40));
    final t = Translations.of(tester.element(find.byType(ChatOcean)));
    expect(find.byType(ChatTranscriptView), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.text(t.chat.landingGreeting), findsNothing);
  });

  test('first send stamps the landing model choice: create → modelOverride PATCH → send', () async {
    final repo = FixtureChatRepository(conversations: [], messages: {});
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);

    c.read(landingModelProvider.notifier).set((apiKeyId: 'ak_1', modelId: 'deepseek-v4-flash'));
    final id = await c.read(startConversationProvider)('你好');

    final conv = await repo.getConversation(id);
    expect(conv.modelOverride?.modelId, 'deepseek-v4-flash'); // stamped before the turn 首回合前盖章
    expect(repo.lastSend?.conversationId, id); // and the send went through 发送已走
    expect(c.read(landingModelProvider)?.modelId, 'deepseek-v4-flash'); // sticky for the next new chat 粘性
  });

  test('Auto (null) landing choice skips the PATCH', () async {
    final repo = FixtureChatRepository(conversations: [], messages: {});
    final c = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);

    final id = await c.read(startConversationProvider)('你好');
    final conv = await repo.getConversation(id);
    expect(conv.modelOverride, isNull);
  });
}
