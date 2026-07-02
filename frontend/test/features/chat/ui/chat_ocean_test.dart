import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/ui/chat_composer.dart';
import 'package:anselm/features/chat/ui/chat_ocean.dart';
import 'package:anselm/features/chat/ui/chat_transcript.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The center composition: no selection → the landing (greeting + floating composer, NO transcript);
// a selection → transcript + docked composer. 中心组合:无选区=landing;有选区=transcript+停靠 composer。

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
  testWidgets('no selection → landing: greeting typewriter + floating composer, no transcript', (tester) async {
    final repo = FixtureChatRepository(conversations: [], messages: {});
    await tester.pumpWidget(_host(repo, null));
    await tester.pump(const Duration(milliseconds: 400)); // typewriter mid-flight (loops caret — no settle)
    expect(find.byType(AnTypewriter), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.byType(ChatTranscriptView), findsNothing);
  });

  testWidgets('a selection → transcript + docked composer, no landing', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    await tester.pumpWidget(_host(repo, const ConversationRef('cv_1')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byType(ChatTranscriptView), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.byType(AnTypewriter), findsNothing);
  });
}
