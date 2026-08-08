import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/ui/an_dialog.dart';
import 'package:anselm/core/ui/an_inline_edit.dart';
import 'package:anselm/core/ui/an_sidebar_list.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/data/chat_repository.dart';
import 'package:anselm/features/chat/data/conversation_signal.dart';
import 'package:anselm/features/chat/state/chat_drafts.dart';
import 'package:anselm/features/chat/state/conversation_list_provider.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/ui/conversation_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// STEP 6 gate (widget) — the conversation rail end-to-end: grouped Pinned + Recents render off the repo
// seam, selection is route-derived (tap → context.go('/chat/:id') → selectedConversationProvider), and the
// ⚙ menu's toggles actually drive the list (turning "show time" off removes the row timestamps). The
// pixel look is verified separately by the PNG capture harness.

Conversation _c(
  String id,
  String title, {
  bool pinned = false,
  DateTime? at,
  String workDir = '',
}) {
  final ts = at ?? DateTime.utc(2026, 6, 26, 12);
  return Conversation(
    id: id,
    title: title,
    pinned: pinned,
    workDir: workDir,
    createdAt: ts,
    updatedAt: ts,
    lastMessageAt: ts,
  );
}

/// One transcript row for the fork fixture (the rail's fork copies the thread, so it needs rows).
/// 分叉夹具的一条回合行(rail 的分叉会复制线程,故需要行)。
ChatMessage _m(String id, String role, String text) => ChatMessage(
  id: id,
  conversationId: 'cv_a',
  role: role,
  status: 'completed',
  createdAt: DateTime.utc(2026, 6, 26, 12),
  blocks: [
    ChatBlock(id: 'blk_$id', messageId: id, type: 'text', content: text),
  ],
);

Widget _host(
  ChatRepository repo, {
  AnOverlayController? overlay,
  String initialLocation = '/',
}) {
  const rail = Scaffold(
    body: SizedBox(width: 320, height: 600, child: ConversationRail()),
  );
  final router = GoRouter(
    initialLocation: initialLocation,
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
      // A fake overlay lets the row-menu's confirm() resolve deterministically without mounting the host
      // navigator (toasts still record into state). 假浮层让 confirm 确定解析、无需挂 host。
      if (overlay != null) overlayProvider.overrideWith(() => overlay),
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

/// A scripted overlay: [confirm] returns [result] (no real dialog / navigator needed). 脚本化浮层。
class _FakeOverlay extends AnOverlayController {
  _FakeOverlay(this.result);
  final bool result;
  bool confirmCalled = false;

  /// Every word the last confirm() put in front of the user. The residency-group tests assert on this —
  /// the wording is the feature, so it has to be inspectable.
  /// 上一次 confirm() 摆在用户面前的每一个字。驻地组测试断言它——措辞就是功能,故它必须可被检查。
  String lastTitle = '';
  String lastMessage = '';
  String lastConfirmLabel = '';

  @override
  Future<bool> confirm({
    required String title,
    String? message,
    required String confirmLabel,
    required String cancelLabel,
    required String barrierLabel,
    AnDialogTone confirmTone = AnDialogTone.danger,
  }) async {
    confirmCalled = true;
    lastTitle = title;
    lastMessage = message ?? '';
    lastConfirmLabel = confirmLabel;
    return result;
  }
}

// Open a row's ⋯ menu with a REAL mouse: hover the row (reveals the trail actions — the idle layer is
// IgnorePointer'd), move onto the ⋯ (still within the row → stays hovered), then click via down/up. A
// fresh tester.tap() synthesizes a touch pointer that carries no hover, so the ⋯ would stay inert and the
// tap would fall through to the timestamp meta. 用真鼠标:hover 行→显动作→移到 ⋯(仍在行内→仍 hover)→down/up 点击。
Future<void> _openRowMenu(WidgetTester tester, String rowText) async {
  // Force traditional (mouse) highlighting so FocusableActionDetector fires hover highlights on enter —
  // otherwise the test's default touch mode never reveals the IgnorePointer'd trail actions. 强制鼠标高亮态。
  WidgetsBinding.instance.focusManager.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(() => mouse.removePointer());
  await mouse.moveTo(tester.getCenter(find.text(rowText)));
  await tester.pump(); // hover the row → ⋯ becomes hit-testable
  final p = tester.getCenter(find.byIcon(AnIcons.more));
  await mouse.moveTo(p);
  await tester.pump();
  await mouse.down(p);
  await mouse.up();
  await tester.pumpAndSettle(); // popover open animation settles
}

void main() {
  testWidgets(
    'New chat clears the landing draft and requests a fresh composer',
    (tester) async {
      await tester.pumpWidget(
        _host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')])),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConversationRail)),
      );
      container
          .read(chatDraftsProvider)
          .set(ChatDrafts.landingKey, 'stale draft');
      final before = container.read(chatLandingResetProvider);

      final t = Translations.of(tester.element(find.byType(ConversationRail)));
      await tester.tap(find.text(t.chat.kNew));
      await tester.pump();

      expect(
        container.read(chatDraftsProvider).of(ChatDrafts.landingKey),
        isEmpty,
      );
      expect(container.read(chatLandingResetProvider), before + 1);
    },
  );

  testWidgets('loaded → AnSidebarList with Pinned + Recents sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureChatRepository(
          conversations: [
            _c('cv_pin', 'pinned one', pinned: true),
            _c('cv_a', 'recent one'),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AnSidebarList), findsOneWidget);
    expect(find.text(t.chat.bucket.pinned), findsOneWidget);
    expect(find.text(t.chat.bucket.recents), findsOneWidget);
    expect(find.text('pinned one'), findsOneWidget);
    expect(find.text('recent one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row navigates → selection derives from the route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')])),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ConversationRail)),
    );
    expect(container.read(selectedConversationProvider), isNull);

    await tester.tap(find.text('thread A'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(goRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/chat/cv_a',
    );
    expect(
      container.read(selectedConversationProvider),
      const ConversationRef('cv_a'),
    );
  });

  testWidgets(
    '⚙ menu opens (Sort + Display); "show time" toggle removes the row timestamps',
    (tester) async {
      // A far-past date → the row meta is a stable numeric year ("2020/...") regardless of the real clock.
      await tester.pumpWidget(
        _host(
          FixtureChatRepository(
            conversations: [
              _c('cv_a', 'thread A', at: DateTime.utc(2020, 1, 1, 12)),
            ],
          ),
        ),
      );
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
    },
  );

  // ── STEP 7: the per-row ⋯ menu (rename / fork / pin / archive / delete) ──

  testWidgets(
    'hovering a row reveals the ⋯ menu listing rename / fork / pin / archive / delete',
    (tester) async {
      await tester.pumpWidget(
        _host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')])),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'thread A');

      expect(find.text(t.chat.rename), findsOneWidget);
      expect(
        find.text(t.chat.fork),
        findsOneWidget,
      ); // CH-b: fork lives here too
      expect(find.text(t.chat.pin), findsOneWidget); // not pinned → "Pin"
      expect(find.text(t.chat.archive), findsOneWidget);
      expect(find.text(t.action.delete), findsOneWidget);
    },
  );

  testWidgets(
    'Rename → the row becomes an in-place field; committing renames via the repo',
    (tester) async {
      final repo = FixtureChatRepository(
        conversations: [_c('cv_a', 'thread A')],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'thread A');

      await tester.tap(find.text(t.chat.rename));
      await tester.pumpAndSettle();
      expect(find.byType(AnInlineEdit), findsOneWidget); // in-place edit opened

      // Scope to the rename field — the rail also has the filter TextField. 限定到改名框(rail 还有过滤框)。
      final field = find.descendant(
        of: find.byType(AnInlineEdit),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, 'renamed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AnInlineEdit), findsNothing); // back to a normal row
      expect(find.text('renamed'), findsOneWidget);
      final p = await repo.listConversations();
      expect(p.items.single.title, 'renamed'); // the repo really mutated
    },
  );

  testWidgets('Pin moves the row into the Pinned section', (tester) async {
    await tester.pumpWidget(
      _host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')])),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text(t.chat.bucket.pinned),
      findsNothing,
    ); // no Pinned section yet

    await _openRowMenu(tester, 'thread A');
    await tester.tap(find.text(t.chat.pin));
    await tester.pumpAndSettle();

    expect(
      find.text(t.chat.bucket.pinned),
      findsOneWidget,
    ); // re-bucketed into Pinned
  });

  testWidgets(
    'Delete → confirm accepted → the row is removed; empty rail = the collapsed shape (chrome + both heads, no tombstone)',
    (tester) async {
      final fake = _FakeOverlay(true);
      await tester.pumpWidget(
        _host(
          FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]),
          overlay: fake,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _openRowMenu(tester, 'thread A');

      await tester.tap(find.text(t.action.delete));
      await tester.pumpAndSettle();

      expect(fake.confirmCalled, true);
      expect(find.text('thread A'), findsNothing);
      // 用户 0718 拍板: empty rail = the FULL rail collapsed — the list's own chrome (New chat + both group
      // heads) stays, no «No conversations yet» tombstone. 空态=满态收起:chrome 与两组头恒在、无墓碑。
      expect(
        find.byType(AnState),
        findsNothing,
      ); // the old full-area empty tombstone is retired 墓碑退役
      expect(find.byType(AnSidebarList), findsOneWidget);
      expect(find.text(t.chat.kNew), findsOneWidget); // + New chat
      expect(
        find.text(t.chat.bucket.pinned),
        findsOneWidget,
      ); // Pinned head renders even at zero data 零数据也渲
      expect(
        find.text(t.chat.bucket.recents),
        findsOneWidget,
      ); // Recents head too
    },
  );

  testWidgets('Delete → confirm declined → the row stays', (tester) async {
    final fake = _FakeOverlay(false);
    await tester.pumpWidget(
      _host(
        FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]),
        overlay: fake,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'thread A');

    await tester.tap(find.text(t.action.delete));
    await tester.pumpAndSettle();

    expect(fake.confirmCalled, true);
    expect(find.text('thread A'), findsOneWidget); // untouched
  });

  testWidgets(
    'deleting the SELECTED thread clears the selection (navigates home)',
    (tester) async {
      final fake = _FakeOverlay(true);
      await tester.pumpWidget(
        _host(
          FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]),
          overlay: fake,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConversationRail)),
      );
      container.read(goRouterProvider).go('/chat/cv_a');
      await tester.pumpAndSettle();
      expect(
        container.read(selectedConversationProvider),
        const ConversationRef('cv_a'),
      );

      await _openRowMenu(tester, 'thread A');
      await tester.tap(find.text(t.action.delete));
      await tester.pumpAndSettle();

      expect(
        container
            .read(goRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        '/',
      );
      expect(container.read(selectedConversationProvider), isNull);
    },
  );

  testWidgets('an external durable deletion clears the open deep link', (
    tester,
  ) async {
    final repo = FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]);
    await tester.pumpWidget(_host(repo, initialLocation: '/chat/cv_a'));
    await tester.pump(const Duration(milliseconds: 50));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ConversationRail)),
    );
    expect(
      container.read(selectedConversationProvider),
      const ConversationRef('cv_a'),
    );

    // Simulate another window deleting the thread. The list and the open route consume the same
    // durable notification, so the rail must remove the row AND leave the dead deep link.
    // 模拟另一个窗口删除线程。列表与当前路由消费同一 durable 通知,必须同时去行并离开死深链。
    repo.emitSignal(
      const ConversationSignal(
        id: 'cv_a',
        action: ConversationAction.deleted,
        durable: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container
          .read(goRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/',
    );
    expect(container.read(selectedConversationProvider), isNull);
    expect(find.text('thread A'), findsNothing);
  });

  // ── the left-island fork entry (CH-b) ──

  testWidgets(
    'the ⋯ menu forks from the LATEST message, grows a new rail row and navigates to it',
    (tester) async {
      final repo = FixtureChatRepository(
        conversations: [_c('cv_a', 'thread A')],
        messages: {
          'cv_a': [
            _m('msg_u1', 'user', 'ASK'),
            _m('msg_a1', 'assistant', 'ANSWER'),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump(const Duration(milliseconds: 50));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConversationRail)),
      );

      await _openRowMenu(tester, 'thread A');
      expect(find.text(t.chat.fork), findsOneWidget);
      await tester.tap(find.text(t.chat.fork));
      await tester.pumpAndSettle();

      // The fork is a NEW row, titled from the source, and the source survives untouched.
      // 分叉是一条**新**行、标题源自源线程,而源分毫不动地活着。
      expect(find.text('thread A (fork)'), findsOneWidget);
      expect(find.text('thread A'), findsOneWidget);
      // We navigated INTO the fork (a fork you cannot see is a fork you have to go find).
      final path = container
          .read(goRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path;
      expect(path, isNot('/'));
      expect(path, startsWith('/chat/'));
      final forkId = path.substring('/chat/'.length);
      expect(forkId, isNot('cv_a'));
      // From the latest message = the whole thread came along, with lineage stamped.
      final head = await repo.getConversation(forkId);
      expect(head.forkedFromConversationId, 'cv_a');
      expect(head.forkedFromMessageId, 'msg_a1');
      final copied = await repo.listMessages(forkId);
      expect(copied.items.length, 2);
    },
  );

  // ── WD1.5 · the rail grouped by RESIDENCY 按驻地分组 ──

  // Open a SECTION HEAD's ⋯ menu — same real-mouse dance as a row's (the trail actions are IgnorePointer'd
  // until hovered), keyed off the head's own label. 开**段头**的 ⋯ 菜单——与行的同一套真鼠标舞步。
  Future<void> openHeadMenu(WidgetTester tester, String headLabel) async {
    WidgetsBinding.instance.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(() => mouse.removePointer());
    final head = find.text(headLabel);
    await mouse.moveTo(tester.getCenter(head));
    await tester.pump();
    final more = find.descendant(
      of: find.ancestor(of: head, matching: find.byType(Row)).last,
      matching: find.byIcon(AnIcons.more),
    );
    final p = tester.getCenter(more.first);
    await mouse.moveTo(p);
    await tester.pump();
    await mouse.down(p);
    await mouse.up();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'four sections: Pinned · 📁 residency groups · Recents — and a pinned residency thread is NOT duplicated',
    (tester) async {
      final repo = FixtureChatRepository(
        conversations: [
          _c('cv_pin', 'pinned in alpha', pinned: true, workDir: '/w/alpha'),
          _c(
            'cv_a1',
            'alpha one',
            workDir: '/w/alpha',
            at: DateTime.utc(2026, 6, 26, 11),
          ),
          _c(
            'cv_b1',
            'beta one',
            workDir: '/w/beta',
            at: DateTime.utc(2026, 6, 25, 11),
          ),
          _c('cv_home', 'no folder at all'),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump(const Duration(milliseconds: 50));
      await tester
          .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
      await tester
          .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页

      // The heads: Pinned, the two folders (named by their own last segment), Recents.
      expect(find.text(t.chat.bucket.pinned), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text(t.chat.bucket.recents), findsOneWidget);

      // Pinned wins: the pinned thread renders under 置顶 and NOT inside alpha, exactly once.
      // 置顶赢:置顶线程渲在「置顶」下、**不**在 alpha 里,恰好一次。
      expect(find.text('pinned in alpha'), findsOneWidget);
      // Recents holds ONLY the thread that lives in no directory.
      expect(find.text('no folder at all'), findsOneWidget);
      // alpha is the most recently active group → it starts OPEN, so its row is on screen; beta starts
      // folded, so beta's row is not built at all (and beta fetched nothing).
      // alpha 是最近活跃的组 → 它默认**打开**,故它的行在屏上;beta 默认收起,故 beta 的行根本没被建(也什么都没取)。
      expect(find.text('alpha one'), findsOneWidget);
      expect(find.text('beta one'), findsNothing);
      expect(tester.takeException(), isNull);

      // Expanding beta fetches its first page through the same tail sentinel every axis uses.
      // 展开 beta 会经每个轴共用的同一个尾哨兵取它的第一页。
      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();
      expect(find.text('beta one'), findsOneWidget);
    },
  );

  testWidgets('a residency head carries exactly three actions', (tester) async {
    await tester.pumpWidget(
      _host(
        FixtureChatRepository(
          conversations: [_c('cv_a1', 'alpha one', workDir: '/w/alpha')],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
    await openHeadMenu(tester, 'alpha');

    final w = t.chat.workDir;
    expect(find.text(w.groupArchiveAll), findsOneWidget);
    expect(find.text(w.groupDeleteAll), findsOneWidget);
    // «Reveal in Finder» belongs here on purpose: it is the item that shows the folder is something we
    // point at, never something we own. 「在访达中显示」刻意在此:它表明文件夹是我们**指着**的东西、绝非我们拥有的。
    expect(find.text(w.revealFinder), findsOneWidget);
  });

  // ⚠️ THE HONESTY LAW, as an assertion. «Delete the directory» — or any phrasing containing the word
  // *directory* — would be read as deleting the real folder on disk with the user's work inside it. Both
  // group actions delete/archive CONVERSATIONS and nothing else, so neither the menu labels nor the confirm
  // dialogs may contain that word, in either language. This test is the thing that keeps a future edit
  // honest: a well-meaning «删除该目录下的全部对话» would turn it red.
  //
  // ⚠️ **诚实律**,做成断言。「删除目录」——或任何含「目录」字样的说法——会被读成删掉磁盘上那个真文件夹、连里面用户
  // 的活一起。两个组动作删/归档的都是**对话**、别无其他,故菜单标签与确认框**两种语言下**都不得含那两个字。本测试
  // 正是让未来某次编辑保持诚实的东西:一句好心的「删除该目录下的全部对话」会让它转红。
  test('honesty law · the residency-group wording never says «directory»', () {
    // Chinese: 「目录」 is the forbidden sequence — note that 「工作目录」 CONTAINS it, so the group wording may
    // not fall back on the residency button's own vocabulary either.
    // 中文:「目录」是被禁的序列——注意「工作目录」**包含**它,故组的措辞也不能退回驻地按钮自己的词汇表。
    const zhForbidden = '目录';
    // English: any spelling of directory / directories, and «folder» too — the same misreading in English is
    // "it will delete my folder". 英文:directory/directories 的任何拼法,连 folder 一并禁——英文里同一种误读是
    // 「它会删掉我的文件夹」。
    final enForbidden = RegExp(r'director|folder', caseSensitive: false);

    for (final loc in AppLocale.values) {
      final w = loc.buildSync().chat.workDir;
      final wording = <String>[
        w.groupArchiveAll,
        w.groupDeleteAll,
        w.groupArchiveTitle,
        w.groupArchiveBody(count: 12, name: 'anselm'),
        w.groupArchiveConfirm,
        w.groupDeleteTitle,
        w.groupDeleteBody(count: 12, name: 'anselm'),
        w.groupDeleteConfirm,
      ];
      for (final s in wording) {
        expect(
          s.contains(zhForbidden),
          isFalse,
          reason: '[$loc] 「$zhForbidden」 must never appear: $s',
        );
        expect(
          enForbidden.hasMatch(s),
          isFalse,
          reason: '[$loc] directory/folder must never appear: $s',
        );
      }
      // And the DELETE dialog must say, positively, that nothing on disk goes — the absence of a scary word
      // is not the same as a reassurance. 而**删除**对话框必须**正面**说出磁盘上什么都不会没——可怕词的缺席不等于一句安抚。
      final body = w.groupDeleteBody(count: 12, name: 'anselm');
      expect(
        body.contains('磁盘') || body.toLowerCase().contains('disk'),
        isTrue,
        reason:
            '[$loc] the delete dialog must state that nothing on disk is deleted: $body',
      );
      // The inventory is a COUNT, not a vague "these" — the user is told exactly how many threads move.
      // 盘点是一个**数**、不是含糊的「这些」——用户被告知究竟有几条线程会动。
      expect(
        body.contains('12'),
        isTrue,
        reason: '[$loc] the delete dialog must inventory the count: $body',
      );
      expect(
        w.groupArchiveBody(count: 12, name: 'anselm').contains('12'),
        isTrue,
      );
    }
  });

  testWidgets(
    'archive-all inventories the WHOLE group and files exactly it — one request, pinned spared',
    (tester) async {
      final overlay = _FakeOverlay(true);
      final repo = FixtureChatRepository(
        conversations: [
          _c('cv_a1', 'alpha one', workDir: '/w/alpha'),
          _c('cv_a2', 'alpha two', workDir: '/w/alpha'),
          _c('cv_pin', 'alpha pinned', pinned: true, workDir: '/w/alpha'),
          _c('cv_home', 'no folder at all'),
        ],
      );
      await tester.pumpWidget(_host(repo, overlay: overlay));
      await tester.pump(const Duration(milliseconds: 50));
      await tester
          .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
      await tester
          .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
      await openHeadMenu(tester, 'alpha');
      await tester.tap(find.text(t.chat.workDir.groupArchiveAll));
      await tester.pumpAndSettle();

      expect(overlay.confirmCalled, isTrue);
      // The dialog inventories the group's own count (2), not the workspace's, and names the folder the user
      // clicked. 确认框盘点的是**这个组自己**的数(2)、不是整个 workspace 的,并点出用户点的那个文件夹。
      expect(overlay.lastMessage, contains('2'));
      expect(overlay.lastMessage, contains('alpha'));

      // The group's unpinned threads left the active list; the pinned one and the folderless one stayed.
      // 组内未置顶的线程离开了活跃列表;置顶那条与没有文件夹那条留下。
      expect(find.text('alpha one'), findsNothing);
      expect(find.text('alpha two'), findsNothing);
      expect(find.text('alpha pinned'), findsOneWidget);
      expect(find.text('no folder at all'), findsOneWidget);
      // The group itself is gone from the rail: a projection with nothing unpinned left in it does not exist.
      // 组本身从 rail 上消失了:一个已无未置顶成员的投影并不存在。
      expect(find.text('alpha'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delete-all removes the group but leaves the machine alone', (
    tester,
  ) async {
    final overlay = _FakeOverlay(true);
    final repo = FixtureChatRepository(
      conversations: [
        _c('cv_a1', 'alpha one', workDir: '/w/alpha'),
        _c('cv_a2', 'alpha two', workDir: '/w/alpha'),
        _c('cv_home', 'no folder at all'),
      ],
    );
    await tester.pumpWidget(_host(repo, overlay: overlay));
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
    await openHeadMenu(tester, 'alpha');
    await tester.tap(find.text(t.chat.workDir.groupDeleteAll));
    await tester.pumpAndSettle();

    expect(overlay.lastConfirmLabel, t.chat.workDir.groupDeleteConfirm);
    expect(find.text('alpha one'), findsNothing);
    expect(find.text('alpha two'), findsNothing);
    expect(find.text('alpha'), findsNothing);
    expect(find.text('no folder at all'), findsOneWidget);
    // What the repository saw is ONE group request, never a loop of per-row deletes.
    // repository 看到的是**一次**组请求、绝不是逐行删除的循环。
    expect(repo.deletedIds, isEmpty);
    expect(repo.deletedWorkDirs, ['/w/alpha']);
  });

  testWidgets('cancelling the confirm changes nothing at all', (tester) async {
    final overlay = _FakeOverlay(false);
    final repo = FixtureChatRepository(
      conversations: [_c('cv_a1', 'alpha one', workDir: '/w/alpha')],
    );
    await tester.pumpWidget(_host(repo, overlay: overlay));
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
    await openHeadMenu(tester, 'alpha');
    await tester.tap(find.text(t.chat.workDir.groupDeleteAll));
    await tester.pumpAndSettle();

    expect(overlay.confirmCalled, isTrue);
    expect(repo.deletedWorkDirs, isEmpty);
    expect(find.text('alpha one'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
  });

  testWidgets(
    'leaving a residency moves the thread back to Recents and takes the empty group with it',
    (tester) async {
      final repo = FixtureChatRepository(
        conversations: [
          _c('cv_a1', 'alpha one', workDir: '/w/alpha'),
          _c('cv_home', 'no folder at all'),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump(const Duration(milliseconds: 50));
      await tester
          .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
      await tester
          .pumpAndSettle(); // the open group's tail sentinel fetches its first page 打开的组的尾哨兵取首页
      expect(find.text('alpha'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConversationRail)),
      );
      // The residency button's own action, seen from the rail: PATCH workDir='' → the row belongs to Recents
      // now, and its group has no unpinned member left. 驻地按钮自己的动作:PATCH workDir='' → 该行现在属于「最近」,
      // 而它那个组已无未置顶成员。
      final left = await repo.setWorkDir('cv_a1', '');
      container.read(conversationListProvider.notifier).applyUpdate(left);
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // the coalesced projection re-read
      await tester.pumpAndSettle();

      expect(find.text('alpha'), findsNothing);
      final state = container.read(conversationListProvider).value!;
      expect(state.recents.rows.map((r) => r.id), contains('cv_a1'));
      expect(state.groups, isEmpty);
    },
  );
}
