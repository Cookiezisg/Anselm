import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/state/title_reveals.dart';
import 'package:anselm/features/chat/ui/chat_head.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The head's two states (landing model picker / thread title+picker) and the auto-title FAKE STREAM:
// a queued reveal renders the one-shot typewriter, done → back to the renameable title + dequeued.
// 头两态(landing 选择器/线程 标题+选择器)+ 自动命名假流式:入队即打字机,完→可改名标题+出队。

Conversation _conv(String id, {String title = '', bool autoTitled = false}) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(
      id: id, title: title, autoTitled: autoTitled, createdAt: at, updatedAt: at, lastMessageAt: at);
}

class _Selected extends SelectedConversation {
  _Selected(this.value);
  final ConversationRef? value;
  @override
  ConversationRef? build() => value;
}

(Widget, ProviderContainer) _host(FixtureChatRepository repo, ConversationRef? selected) {
  final container = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    selectedConversationProvider.overrideWith(() => _Selected(selected)),
  ]);
  addTearDown(container.dispose);
  final w = UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: const Scaffold(body: Align(alignment: Alignment.topLeft, child: ChatHead())),
      ),
    ),
  );
  return (w, container);
}

void main() {
  testWidgets('landing (no selection) renders the sticky model picker, no title', (tester) async {
    final repo = FixtureChatRepository(conversations: [], messages: {});
    final (w, c) = _host(repo, null);
    await tester.pumpWidget(w);
    await tester.pump();
    final t = Translations.of(tester.element(find.byType(ChatHead)));
    expect(find.text(t.chat.modelAuto), findsOneWidget); // the picker anchor 选择器锚
    expect(find.byType(AnInlineEdit), findsNothing);
  });

  testWidgets('thread: title + model picker; a queued auto-title plays the typewriter then restores',
      (tester) async {
    final repo =
        FixtureChatRepository(conversations: [_conv('cv_1', title: '新标题', autoTitled: true)], messages: {'cv_1': []});
    final (w, c) = _host(repo, const ConversationRef('cv_1'));
    await tester.pumpWidget(w);
    await tester.pump(); // header fetch 头部取数
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(AnInlineEdit), findsOneWidget); // static title (no reveal queued) 静态标题

    c.read(titleRevealsProvider.notifier).add('cv_1');
    await tester.pump();
    expect(find.byType(AnTypewriter), findsOneWidget); // the fake stream 假流式
    expect(find.byType(AnInlineEdit), findsNothing);

    // type (4 chars) + hold + post-frame → done: dequeued, renameable title back. 播完出队回标题。
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    expect(c.read(titleRevealsProvider), isEmpty);
    await tester.pump();
    expect(find.byType(AnInlineEdit), findsOneWidget);
    expect(find.byType(AnTypewriter), findsNothing);
  });
}
