import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/ui/notification_row.dart';
import 'package:anselm/features/notifications/ui/notification_tray.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The bell tray, rebuilt on the rail architecture (0719). Pins: retired chrome (no "Notifications" title /
// divider / top mark-all button); collapsible time-bucket group heads; mark-all lives in the group ⋯ menu;
// search + "unread only" filters; the injected approvals band as the top group (hidden while searching);
// massive list doesn't throw.
// 铃托盘照 rail 架构重造:退役 chrome + 可折叠组头 + mark-all 进 ⋯ 菜单 + 搜索/仅未读过滤 + 注入 band。

NotificationItem _n(String id, {bool read = false, String name = 'fetch'}) => NotificationItem(
      id: id,
      type: 'function.created',
      payload: {'name': name},
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      readAt: read ? DateTime.now() : null,
    );

Widget _host(FixtureNotificationRepository repo, {Widget? band}) => ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        notificationDebounceProvider.overrideWithValue(Duration.zero),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(body: SizedBox(width: 320, height: 600, child: NotificationTray(approvalsBand: band))),
        ),
      ),
    );

// The head's ⋯ bulk menu rides AnRow's hover-revealed actions slot (count at rest, ⋯ on hover; the idle
// layer is IgnorePointer'd) — hover the head with a real mouse, then click the ⋯. A synthesized touch tap
// carries no hover. 组头 ⋯ 骑 AnRow hover 揭示的动作槽;用真鼠标悬停组头再点 ⋯。
Future<void> _openHeadMenu(WidgetTester tester, String headText) async {
  WidgetsBinding.instance.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(() => mouse.removePointer());
  await mouse.moveTo(tester.getCenter(find.text(headText)));
  await tester.pump(); // hover the head → ⋯ becomes hit-testable
  final p = tester.getCenter(find.byIcon(AnIcons.more));
  await mouse.moveTo(p);
  await tester.pump();
  await mouse.down(p);
  await mouse.up();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('retired chrome: no feed title, the search field is the top chrome', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [_n('a')])));
    await tester.pumpAndSettle();
    // Title / divider / top "mark all read" button all retired (0719) — the search field replaces them.
    // 标题/分割线/顶「全部已读」钮退役,搜索框取而代之。
    expect(find.text(t.notifications.feed), findsNothing);
    expect(find.text(t.notifications.searchPlaceholder), findsOneWidget);
  });

  testWidgets('populated feed → rows under a collapsible time-bucket head', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [_n('a'), _n('b'), _n('c')])));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(3));
    expect(find.text(t.notifications.today), findsOneWidget); // the group head
  });

  testWidgets('head ⋯ carries mark-all-read + mark-all-unread; read-all keeps the rows (audit) + the ⋯', (tester) async {
    final repo = FixtureNotificationRepository(seed: [_n('a'), _n('b')]);
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    // The ⋯ rides the head's hover-revealed actions slot (AnRow meta↔actions, 1:1 with the chat rail head).
    // ⋯ 骑组头 hover 揭示的动作槽(AnRow 数字↔动作,与 chat rail 头 1:1)。
    await _openHeadMenu(tester, t.notifications.today);
    expect(find.text(t.notifications.markAllRead), findsOneWidget);
    expect(find.text(t.notifications.markAllUnread), findsOneWidget); // both bulk actions present
    await tester.tap(find.text(t.notifications.markAllRead));
    await tester.pumpAndSettle();
    expect(await repo.unreadCount(), 0); // mark-all-read fired
    // The read rows stay in the list (audit trail); the ⋯ persists (it now also offers mark-all-unread).
    // 已读行留列表(审计);⋯ 常驻(现也给「全部未读」)。
    expect(find.byType(NotificationRow), findsNWidgets(2));
  });

  testWidgets('head ⋯ «mark all unread» re-marks the read ledger unread', (tester) async {
    final repo = FixtureNotificationRepository(seed: [_n('a', read: true), _n('b', read: true)]);
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    expect(await repo.unreadCount(), 0);
    await _openHeadMenu(tester, t.notifications.today);
    await tester.tap(find.text(t.notifications.markAllUnread));
    await tester.pumpAndSettle();
    expect(await repo.unreadCount(), 2); // all rows re-marked unread
  });

  testWidgets('tapping a group head collapses its rows (head stays)', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [_n('a'), _n('b')])));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));
    await tester.tap(find.text(t.notifications.today));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNothing); // collapsed
    expect(find.text(t.notifications.today), findsOneWidget); // head persists
  });

  testWidgets('search filters the feed by rendered content', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [_n('a', name: 'alpha'), _n('b', name: 'beta')])));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));
    await tester.enterText(find.byType(EditableText), 'alpha');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsOneWidget);
  });

  testWidgets('⚙ "unread only" hides read rows', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [_n('a'), _n('b', read: true)])));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));
    await tester.tap(find.byIcon(AnIcons.sliders)); // the ⚙ display menu
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.notifications.unreadOnly));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsOneWidget); // only the unread one
  });

  testWidgets('injected approvals band is the top group; it hides while searching', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [_n('a', name: 'alpha')]), band: const Text('BAND')));
    await tester.pumpAndSettle();
    expect(find.text('BAND'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('BAND'), findsNothing); // approvals aren't notification content — hidden under a query
  });

  testWidgets('massive list renders without overflow', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [for (var i = 0; i < 200; i++) _n('n$i')])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationRow), findsWidgets);
  });
}
