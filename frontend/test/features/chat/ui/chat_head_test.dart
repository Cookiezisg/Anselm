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
    'model menu distinguishes a capability read failure from an empty catalog',
    (tester) async {
      var refreshes = 0;
      late Translations t;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: Builder(
              builder: (context) {
                t = Translations.of(context);
                return Scaffold(
                  body: chatModelMenu(
                    t: t,
                    caps: const [],
                    current: null,
                    catalogError: true,
                    onRetryCatalog: () => refreshes++,
                    onSelect: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Auto'), findsOneWidget);
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(find.text(t.chat.modelCatalogFailed), findsOneWidget);
      expect(find.text(t.chat.modelCatalogRetry), findsOneWidget);
      await tester.tap(find.text(t.chat.modelCatalogRetry));
      expect(refreshes, 1);
    },
  );

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
      final t = Translations.of(tester.element(find.byType(ChatHead)));
      final auto = find.text(t.chat.modelAuto);
      final autoXBeforeReveal = tester.getTopLeft(auto).dx;
      // The head title is a plain READ-ONLY Text now (rename goes through the rail's ⋯ → rename) — not
      // an inline-edit. 顶栏标题=纯只读 Text(改名走 rail 的 ⋯→改名),不再内联编辑。
      expect(find.text('新标题'), findsOneWidget); // static read-only title 静态只读标题
      expect(find.byType(AnInlineEdit), findsNothing);

      c.read(titleRevealsProvider.notifier).add('cv_1');
      await tester.pump();
      expect(find.byType(AnTypewriter), findsOneWidget); // the fake stream 假流式
      expect(find.byType(AnInlineEdit), findsNothing);
      expect(
        (tester.getTopLeft(auto).dx - autoXBeforeReveal).abs(),
        lessThan(0.5),
        reason: 'auto picker must not move while the title typewriter reveals',
      );

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
      expect(
        (tester.getTopLeft(auto).dx - autoXBeforeReveal).abs(),
        lessThan(0.5),
        reason: 'auto picker must keep its slot after reveal settles',
      );
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

      // The name is BEHIND the glyph now (WRK-083 B4): the breadcrumb carries no names, so the head shows
      // nothing until the button is opened. This assertion was inverted rather than deleted — it used to
      // demand the label on the closed head, and leaving that on record is what makes the change legible.
      // 名字现在**在字形背后**(WRK-083 B4):面包屑不带名字,故不点开时头部什么都不显。这条断言是**反转**而非
      // 删除——它原本要求收起态就显标签,把这次反转留在案上,改动才读得出来。
      expect(find.text(t.chat.forkedFrom(title: 'Original')), findsNothing);

      // Open it: the source's CURRENT title appears (the wire carries only the id, so the name is read
      // fresh — a renamed source always shows its real name), and that row navigates.
      // 点开:源的**当前**标题出现(线缆只带 id,故名字读时新鲜取——改过名的源永远显真名),点那一行导航。
      await tester.tap(find.byIcon(AnIcons.control).first);
      await tester.pumpAndSettle();
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
      // Behind the glyph, same as the named case (B4). 与具名那格同理,在字形背后(B4)。
      await tester.tap(find.byIcon(AnIcons.control).first);
      await tester.pumpAndSettle();
      expect(find.text(t.chat.forkedFromUnknown), findsOneWidget);
    },
  );

  // ── WRK-083 B3 + B4 · the breadcrumb's shape invariants ──
  //
  // These are CLASS guards, not instance guards. B3 was reported as "the residency button is the wrong
  // size — it should match the model picker", and B4 as "neither the fork nor the residency needs to spell
  // out a name in the breadcrumb". Pinning only those two widgets would let the next control added to the
  // head reintroduce either defect, so both assertions quantify over EVERY button in the head.
  //
  // 这两条是**类**守卫、不是实例守卫。B3 报的是「驻地按钮尺寸不对,应对齐模型选择器」,B4 报的是「分叉和驻地都
  // 不必在面包屑写出名字」。只钉住那两个 widget 的话,下一个加进头部的控件就能把两个缺陷再引入一次,故两条断言
  // 都对头部里的**每一个**按钮全称量化。
  testWidgets('B3: every breadcrumb control sits on the model picker rung', (
    tester,
  ) async {
    final src = _conv('cv_src', title: 'Original');
    final at = DateTime.utc(2026, 7, 2, 9);
    final fork = Conversation(
      id: 'cv_fork',
      title: 'Original (fork)',
      createdAt: at,
      updatedAt: at,
      lastMessageAt: at,
      workDir: '/tmp/some/deeply/nested/project',
      forkedFromConversationId: 'cv_src',
      forkedFromMessageId: 'msg_a1',
    );
    final repo = FixtureChatRepository(
      conversations: [fork, src],
      messages: const {},
    );
    final (w, _, _) = _hostRouted(repo, const ConversationRef('cv_fork'));
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();

    final buttons = tester.widgetList<AnButton>(
      find.descendant(
        of: find.byType(ChatHead),
        matching: find.byType(AnButton),
      ),
    );
    expect(buttons, isNotEmpty, reason: 'the head must render its controls');
    for (final b in buttons) {
      expect(
        b.size,
        AnButtonSize.md,
        reason:
            'a breadcrumb control at ${b.size} reads as a second-class box beside the '
            'md model picker and mis-centres in the 44pt head band (WRK-083 B3)',
      );
    }
  });

  testWidgets('B4: the closed breadcrumb spells out no names', (tester) async {
    final src = _conv('cv_src', title: 'Original');
    final at = DateTime.utc(2026, 7, 2, 9);
    final fork = Conversation(
      id: 'cv_fork',
      title: 'Original (fork)',
      createdAt: at,
      updatedAt: at,
      lastMessageAt: at,
      workDir: '/tmp/some/deeply/nested/project',
      forkedFromConversationId: 'cv_src',
      forkedFromMessageId: 'msg_a1',
    );
    final repo = FixtureChatRepository(
      conversations: [fork, src],
      messages: const {},
    );
    final (w, _, _) = _hostRouted(repo, const ConversationRef('cv_fork'));
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();

    // The residency's directory name — neither its basename nor its full path — is on the head.
    // 驻地的目录名——basename 与完整路径都不在头部。
    expect(find.textContaining('project'), findsNothing);
    expect(find.textContaining('/tmp/some'), findsNothing);
    // Nor the fork source's title. 分叉源的标题也不在。
    final t = Translations.of(tester.element(find.byType(ChatHead)));
    expect(find.text(t.chat.forkedFrom(title: 'Original')), findsNothing);
    // The thread's OWN title stays — that is the breadcrumb's subject, not a reference to elsewhere.
    // 线程**自己**的标题留着——那是面包屑的主语,不是指向别处的引用。
    expect(find.text('Original (fork)'), findsOneWidget);
  });
}
