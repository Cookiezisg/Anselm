import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/ui/an_sidebar_list.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/data/chat_repository.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/ui/conversation_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// STEP 6 gate (widget) — the conversation rail end-to-end: grouped Pinned + Recents render off the repo
// seam, selection is route-derived (tap → context.go('/chat/:id') → selectedConversationProvider), and the
// ⚙ menu's toggles actually drive the list (turning "show time" off removes the row timestamps). The
// pixel look is verified separately by the PNG capture harness.

Conversation _c(String id, String title, {bool pinned = false, DateTime? at}) {
  final ts = at ?? DateTime.utc(2026, 6, 26, 12);
  return Conversation(id: id, title: title, pinned: pinned, createdAt: ts, updatedAt: ts, lastMessageAt: ts);
}

Widget _host(ChatRepository repo) {
  const rail = Scaffold(body: SizedBox(width: 320, height: 600, child: ConversationRail()));
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => rail),
      GoRoute(path: '/chat/:id', builder: (_, _) => rail),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      goRouterProvider.overrideWithValue(router),
      chatRepositoryProvider.overrideWithValue(repo),
    ],
    child: TranslationProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  testWidgets('loaded → AnSidebarList with Pinned + Recents sections', (tester) async {
    await tester.pumpWidget(_host(FixtureChatRepository(conversations: [
      _c('cv_pin', 'pinned one', pinned: true),
      _c('cv_a', 'recent one'),
    ])));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AnSidebarList), findsOneWidget);
    expect(find.text(t.chat.bucket.pinned), findsOneWidget);
    expect(find.text(t.chat.bucket.recents), findsOneWidget);
    expect(find.text('pinned one'), findsOneWidget);
    expect(find.text('recent one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row navigates → selection derives from the route', (tester) async {
    await tester.pumpWidget(_host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')])));
    await tester.pump(const Duration(milliseconds: 50));

    final container = ProviderScope.containerOf(tester.element(find.byType(ConversationRail)));
    expect(container.read(selectedConversationProvider), isNull);

    await tester.tap(find.text('thread A'));
    await tester.pumpAndSettle();

    expect(container.read(goRouterProvider).routerDelegate.currentConfiguration.uri.path, '/chat/cv_a');
    expect(container.read(selectedConversationProvider), const ConversationRef('cv_a'));
  });

  testWidgets('⚙ menu opens (Sort + Display); "show time" toggle removes the row timestamps', (tester) async {
    // A far-past date → the row meta is a stable numeric year ("2020/...") regardless of the real clock.
    await tester.pumpWidget(_host(FixtureChatRepository(
      conversations: [_c('cv_a', 'thread A', at: DateTime.utc(2020, 1, 1, 12))],
    )));
    await tester.pump(const Duration(milliseconds: 50));

    // The timestamp meta renders by default.
    expect(find.textContaining('2020'), findsOneWidget);

    // Open the ⚙ sliders menu — Sort + Display sections present.
    await tester.tap(find.byIcon(AnIcons.sliders));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(t.chat.sortLabel), findsOneWidget);
    expect(find.text(t.chat.sortName), findsOneWidget);
    expect(find.text(t.chat.displayLabel), findsOneWidget);
    expect(find.text(t.chat.showTime), findsOneWidget);

    // Toggle "show time" OFF → the row timestamp is gone (the toggle drives the list, not just the menu).
    await tester.tap(find.text(t.chat.showTime));
    await tester.pumpAndSettle();
    expect(find.textContaining('2020'), findsNothing);
  });
}
