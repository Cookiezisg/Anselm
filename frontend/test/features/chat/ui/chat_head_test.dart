import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/model_capability.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/model_capabilities.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/state/title_reveals.dart';
import 'package:anselm/features/chat/ui/chat_head.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The head's two states (landing model picker / thread title+picker) and the auto-title FAKE STREAM:
// a queued reveal renders the one-shot typewriter, done → back to the renameable title + dequeued.
// 头两态(landing 选择器/线程 标题+选择器)+ 自动命名假流式:入队即打字机,完→可改名标题+出队。

Conversation _conv(String id, {String title = '', bool autoTitled = false}) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(
    id: id,
    title: title,
    autoTitled: autoTitled,
    createdAt: at,
    updatedAt: at,
    lastMessageAt: at,
  );
}

class _Selected extends SelectedConversation {
  _Selected(this.value);
  final ConversationRef? value;
  @override
  ConversationRef? build() => value;
}

(Widget, ProviderContainer) _host(
  FixtureChatRepository repo,
  ConversationRef? selected,
) {
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      selectedConversationProvider.overrideWith(() => _Selected(selected)),
      // Capabilities live in core (S-15) — feed them here or the picker hits real HTTP + retry timers.
      // 能力目录在 core(S-15)——不喂就打真 HTTP 还挂重试 timer。
      modelCapabilitiesProvider.overrideWith(
        (ref) async => const <ModelCapability>[],
      ),
    ],
  );
  addTearDown(container.dispose);
  final w = UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: const Scaffold(
          body: Align(alignment: Alignment.topLeft, child: ChatHead()),
        ),
      ),
    ),
  );
  return (w, container);
}

/// A ROUTED host — the lineage line navigates with `context.go`, which needs a real router (the plain
/// [_host] mounts a bare MaterialApp). 路由版宿主——血缘行用 context.go 导航,需要真 router。
(Widget, ProviderContainer, GoRouter) _hostRouted(
  FixtureChatRepository repo,
  ConversationRef? selected,
) {
  const head = Scaffold(
    body: Align(alignment: Alignment.topLeft, child: ChatHead()),
  );
  final router = GoRouter(
    initialLocation: '/chat/${selected?.id ?? ''}',
    routes: [
      GoRoute(path: '/', builder: (_, _) => head),
      GoRoute(path: '/chat/:id', builder: (_, _) => head),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      selectedConversationProvider.overrideWith(() => _Selected(selected)),
      goRouterProvider.overrideWithValue(router),
      modelCapabilitiesProvider.overrideWith(
        (ref) async => const <ModelCapability>[],
      ),
    ],
  );
  addTearDown(container.dispose);
  final w = UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  return (w, container, router);
}

void main() {
  testWidgets(
    'landing (no selection) renders the sticky model picker, no title',
    (tester) async {
      final repo = FixtureChatRepository(conversations: [], messages: {});
      final (w, c) = _host(repo, null);
      await tester.pumpWidget(w);
      await tester.pump();
      final t = Translations.of(tester.element(find.byType(ChatHead)));
      expect(
        find.text(t.chat.modelAuto),
        findsOneWidget,
      ); // the picker anchor 选择器锚
      expect(find.byType(AnInlineEdit), findsNothing);
    },
  );

  testWidgets(
    'thread: title + model picker; a queued auto-title plays the typewriter then restores',
    (tester) async {
      final repo = FixtureChatRepository(
        conversations: [_conv('cv_1', title: '新标题', autoTitled: true)],
        messages: {'cv_1': []},
      );
      final (w, c) = _host(repo, const ConversationRef('cv_1'));
      await tester.pumpWidget(w);
      await tester.pump(); // header fetch 头部取数
      await tester.pump(const Duration(milliseconds: 20));
      // The head title is a plain READ-ONLY Text now (rename goes through the rail's ⋯ → rename) — not
      // an inline-edit. 顶栏标题=纯只读 Text(改名走 rail 的 ⋯→改名),不再内联编辑。
      expect(find.text('新标题'), findsOneWidget); // static read-only title 静态只读标题
      expect(find.byType(AnInlineEdit), findsNothing);

      c.read(titleRevealsProvider.notifier).add('cv_1');
      await tester.pump();
      expect(find.byType(AnTypewriter), findsOneWidget); // the fake stream 假流式
      expect(find.byType(AnInlineEdit), findsNothing);

      // type (4 chars) + hold + post-frame → done: dequeued, renameable title back. 播完出队回标题。
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump();
      expect(c.read(titleRevealsProvider), isEmpty);
      await tester.pump();
      expect(
        find.text('新标题'),
        findsOneWidget,
      ); // back to the static read-only title 回静态只读标题
      expect(find.byType(AnTypewriter), findsNothing);
    },
  );

  // ── the fork lineage line (CH-b) ──

  testWidgets(
    'a forked thread shows「分叉自 ×××」in the head and clicking it goes back to the source',
    (tester) async {
      final src = _conv('cv_src', title: 'Original');
      final at = DateTime.utc(2026, 7, 2, 9);
      final fork = Conversation(
        id: 'cv_fork',
        title: 'Original (fork)',
        createdAt: at,
        updatedAt: at,
        lastMessageAt: at,
        forkedFromConversationId: 'cv_src',
        forkedFromMessageId: 'msg_a1',
      );
      final repo = FixtureChatRepository(
        conversations: [fork, src],
        messages: const {},
      );
      final (w, _, router) = _hostRouted(
        repo,
        const ConversationRef('cv_fork'),
      );
      await tester.pumpWidget(w);
      await tester.pumpAndSettle();
      final t = Translations.of(tester.element(find.byType(ChatHead)));

      // The line names the SOURCE by its CURRENT title (the wire carries only the id, so the name is
      // read fresh — a renamed source always shows its real name).
      // 血缘行用源的**当前**标题指名(线缆只带 id,故名字读时新鲜取——改过名的源永远显真名)。
      expect(find.text(t.chat.forkedFrom(title: 'Original')), findsOneWidget);
      await tester.tap(find.text(t.chat.forkedFrom(title: 'Original')));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/chat/cv_src',
      );
    },
  );

  testWidgets('an ordinary thread renders NO lineage line at all', (
    tester,
  ) async {
    final repo = FixtureChatRepository(
      conversations: [_conv('cv_plain', title: 'Plain')],
      messages: const {},
    );
    final (w, _, _) = _hostRouted(repo, const ConversationRef('cv_plain'));
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(ChatHead)));
    expect(find.textContaining(t.chat.forkedFromUnknown), findsNothing);
    expect(find.textContaining('Forked from'), findsNothing);
  });

  testWidgets(
    'a fork whose source is GONE degrades to the generic line — a fork outlives its parent by design',
    (tester) async {
      final at = DateTime.utc(2026, 7, 2, 9);
      final fork = Conversation(
        id: 'cv_fork',
        title: 'Orphan (fork)',
        createdAt: at,
        updatedAt: at,
        lastMessageAt: at,
        forkedFromConversationId: 'cv_deleted',
        forkedFromMessageId: 'msg_a1',
      );
      // The source is absent from the repo → getConversation throws (the fixture's 404 mirror).
      final repo = FixtureChatRepository(
        conversations: [fork],
        messages: const {},
      );
      final (w, _, _) = _hostRouted(repo, const ConversationRef('cv_fork'));
      await tester.pumpWidget(w);
      await tester.pumpAndSettle();
      final t = Translations.of(tester.element(find.byType(ChatHead)));
      expect(find.text(t.chat.forkedFromUnknown), findsOneWidget);
    },
  );
}
