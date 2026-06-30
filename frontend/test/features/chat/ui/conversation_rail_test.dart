import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/ui/an_dialog.dart';
import 'package:anselm/core/ui/an_inline_edit.dart';
import 'package:anselm/core/ui/an_sidebar_list.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/data/chat_repository.dart';
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

Conversation _c(String id, String title, {bool pinned = false, DateTime? at}) {
  final ts = at ?? DateTime.utc(2026, 6, 26, 12);
  return Conversation(id: id, title: title, pinned: pinned, createdAt: ts, updatedAt: ts, lastMessageAt: ts);
}

Widget _host(ChatRepository repo, {AnOverlayController? overlay}) {
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
  WidgetsBinding.instance.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
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

  // ── STEP 7: the per-row ⋯ menu (rename / pin / archive / delete) ──

  testWidgets('hovering a row reveals the ⋯ menu listing rename / pin / archive / delete', (tester) async {
    await tester.pumpWidget(_host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')])));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'thread A');

    expect(find.text(t.chat.rename), findsOneWidget);
    expect(find.text(t.chat.pin), findsOneWidget); // not pinned → "Pin"
    expect(find.text(t.chat.archive), findsOneWidget);
    expect(find.text(t.action.delete), findsOneWidget);
  });

  testWidgets('Rename → the row becomes an in-place field; committing renames via the repo', (tester) async {
    final repo = FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]);
    await tester.pumpWidget(_host(repo));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'thread A');

    await tester.tap(find.text(t.chat.rename));
    await tester.pumpAndSettle();
    expect(find.byType(AnInlineEdit), findsOneWidget); // in-place edit opened

    // Scope to the rename field — the rail also has the filter TextField. 限定到改名框(rail 还有过滤框)。
    final field = find.descendant(of: find.byType(AnInlineEdit), matching: find.byType(EditableText));
    await tester.enterText(field, 'renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AnInlineEdit), findsNothing); // back to a normal row
    expect(find.text('renamed'), findsOneWidget);
    final p = await repo.listConversations();
    expect(p.items.single.title, 'renamed'); // the repo really mutated
  });

  testWidgets('Pin moves the row into the Pinned section', (tester) async {
    await tester.pumpWidget(_host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')])));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(t.chat.bucket.pinned), findsNothing); // no Pinned section yet

    await _openRowMenu(tester, 'thread A');
    await tester.tap(find.text(t.chat.pin));
    await tester.pumpAndSettle();

    expect(find.text(t.chat.bucket.pinned), findsOneWidget); // re-bucketed into Pinned
  });

  testWidgets('Delete → confirm accepted → the row is removed (empty state)', (tester) async {
    final fake = _FakeOverlay(true);
    await tester.pumpWidget(_host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]), overlay: fake));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'thread A');

    await tester.tap(find.text(t.action.delete));
    await tester.pumpAndSettle();

    expect(fake.confirmCalled, true);
    expect(find.text('thread A'), findsNothing);
    expect(find.text(t.chat.emptyTitle), findsOneWidget); // last row gone → empty
  });

  testWidgets('Delete → confirm declined → the row stays', (tester) async {
    final fake = _FakeOverlay(false);
    await tester.pumpWidget(_host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]), overlay: fake));
    await tester.pump(const Duration(milliseconds: 50));
    await _openRowMenu(tester, 'thread A');

    await tester.tap(find.text(t.action.delete));
    await tester.pumpAndSettle();

    expect(fake.confirmCalled, true);
    expect(find.text('thread A'), findsOneWidget); // untouched
  });

  testWidgets('deleting the SELECTED thread clears the selection (navigates home)', (tester) async {
    final fake = _FakeOverlay(true);
    await tester.pumpWidget(_host(FixtureChatRepository(conversations: [_c('cv_a', 'thread A')]), overlay: fake));
    await tester.pump(const Duration(milliseconds: 50));
    final container = ProviderScope.containerOf(tester.element(find.byType(ConversationRail)));
    container.read(goRouterProvider).go('/chat/cv_a');
    await tester.pumpAndSettle();
    expect(container.read(selectedConversationProvider), const ConversationRef('cv_a'));

    await _openRowMenu(tester, 'thread A');
    await tester.tap(find.text(t.action.delete));
    await tester.pumpAndSettle();

    expect(container.read(goRouterProvider).routerDelegate.currentConfiguration.uri.path, '/');
    expect(container.read(selectedConversationProvider), isNull);
  });
}
