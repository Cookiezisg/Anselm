import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_row.dart';
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

NotificationItem _n(
  String id, {
  bool read = false,
  String name = 'fetch',
  DateTime? createdAt,
}) => NotificationItem(
  id: id,
  type: 'function.created',
  payload: {'name': name},
  // Default rows intentionally sit in the local «今天» bucket. `now - 5min` flakes just after midnight
  // by slipping into «昨天» while the test still asserts the Today head.
  // 默认行固定落在本地「今天」组。`now - 5min` 在午夜后几分钟会滑到「昨天」导致门禁抖动。
  createdAt: createdAt ?? _todayNoon(),
  readAt: read ? DateTime.now() : null,
);

DateTime _todayNoon() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}

// A row that lands in the «昨天» bucket — yesterday at LOCAL noon (robust near midnight, unlike a raw
// `now - 26h` which can slip into «更早»). 落在「昨天」组的行(昨日本地正午,近午夜也稳)。
NotificationItem _yesterday(String id, {bool read = false}) {
  final now = DateTime.now();
  return _n(
    id,
    read: read,
    createdAt: DateTime(now.year, now.month, now.day - 1, 12),
  );
}

Widget _host(
  FixtureNotificationRepository repo, {
  Widget? band,
  bool reduced = false,
}) => ProviderScope(
  overrides: [
    notificationRepositoryProvider.overrideWithValue(repo),
    notificationDebounceProvider.overrideWithValue(Duration.zero),
  ],
  child: TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            Widget body = SizedBox(
              width: 320,
              height: 600,
              child: NotificationTray(approvalsBand: band),
            );
            // Reduced-motion host: AnMotionPref.reduced reads MediaQuery.disableAnimationsOf — the tray's
            // collapse tween then resolves to Duration.zero (instant). reduced 宿主:折叠补间变即时。
            if (reduced) {
              body = MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: body,
              );
            }
            return body;
          },
        ),
      ),
    ),
  ),
);

// The head's ⋯ bulk menu rides AnRow's hover-revealed actions slot (count at rest, ⋯ on hover; the idle
// layer is IgnorePointer'd) — hover the head with a real mouse, then click the ⋯. A synthesized touch tap
// carries no hover. 组头 ⋯ 骑 AnRow hover 揭示的动作槽;用真鼠标悬停组头再点 ⋯。
Future<void> _openHeadMenu(WidgetTester tester, String headText) async {
  WidgetsBinding.instance.focusManager.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(() => mouse.removePointer());
  await mouse.moveTo(tester.getCenter(find.text(headText)));
  await tester.pump(); // hover the head → ⋯ becomes hit-testable
  // Scope the ⋯ to THIS head's row — with multiple group heads on screen each renders its own ⋯ (the idle
  // ones IgnorePointer'd), so a bare find.byIcon would be ambiguous. 按组头行圈定 ⋯(多组头时避歧义)。
  final headRow = find.ancestor(
    of: find.text(headText),
    matching: find.byType(AnRow),
  );
  final p = tester.getCenter(
    find.descendant(of: headRow, matching: find.byIcon(AnIcons.more)),
  );
  await mouse.moveTo(p);
  await tester.pump();
  await mouse.down(p);
  await mouse.up();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets(
    'retired chrome: no feed title, the search field is the top chrome',
    (tester) async {
      await tester.pumpWidget(
        _host(FixtureNotificationRepository(seed: [_n('a')])),
      );
      await tester.pumpAndSettle();
      // Title / divider / top "mark all read" button all retired (0719) — the search field replaces them.
      // 标题/分割线/顶「全部已读」钮退役,搜索框取而代之。
      expect(find.text(t.notifications.feed), findsNothing);
      expect(find.text(t.notifications.searchPlaceholder), findsOneWidget);
    },
  );

  testWidgets('populated feed → rows under a collapsible time-bucket head', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureNotificationRepository(seed: [_n('a'), _n('b'), _n('c')])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(3));
    expect(find.text(t.notifications.today), findsOneWidget); // the group head
  });

  testWidgets(
    'head ⋯ carries mark-all-read + mark-all-unread; read-all keeps the rows (audit) + the ⋯',
    (tester) async {
      final repo = FixtureNotificationRepository(seed: [_n('a'), _n('b')]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      // The ⋯ rides the head's hover-revealed actions slot (AnRow meta↔actions, 1:1 with the chat rail head).
      // ⋯ 骑组头 hover 揭示的动作槽(AnRow 数字↔动作,与 chat rail 头 1:1)。
      await _openHeadMenu(tester, t.notifications.today);
      expect(find.text(t.notifications.markAllRead), findsOneWidget);
      expect(
        find.text(t.notifications.markAllUnread),
        findsOneWidget,
      ); // both bulk actions present
      await tester.tap(find.text(t.notifications.markAllRead));
      await tester.pumpAndSettle();
      expect(await repo.unreadCount(), 0); // mark-all-read fired
      // The read rows stay in the list (audit trail); the ⋯ persists (it now also offers mark-all-unread).
      // 已读行留列表(审计);⋯ 常驻(现也给「全部未读」)。
      expect(find.byType(NotificationRow), findsNWidgets(2));
    },
  );

  testWidgets(
    'a time-group ⋯ «mark all read» clears ONLY that group (0720: today ≠ earlier backlog)',
    (tester) async {
      // One «今天» row + one «昨天» row → two group heads. Clearing the Today group must leave the Yesterday
      // row unread — the head action carries just that group's [after, before) window. 组标记只清该组。
      final repo = FixtureNotificationRepository(
        seed: [_n('t'), _yesterday('y')],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(await repo.unreadCount(), 2);
      expect(find.text(t.notifications.today), findsOneWidget);
      expect(find.text(t.notifications.yesterday), findsOneWidget);

      await _openHeadMenu(tester, t.notifications.today);
      await tester.tap(find.text(t.notifications.markAllRead));
      await tester.pumpAndSettle();

      // Only the Today row flipped; the Yesterday backlog is untouched. 只清今天,昨天积压不动。
      expect(await repo.unreadCount(), 1);
      final rows = (await repo.listNotifications()).items;
      expect(rows.firstWhere((r) => r.id == 't').isUnread, isFalse);
      expect(rows.firstWhere((r) => r.id == 'y').isUnread, isTrue);
    },
  );

  testWidgets('head ⋯ «mark all unread» re-marks the read ledger unread', (
    tester,
  ) async {
    final repo = FixtureNotificationRepository(
      seed: [_n('a', read: true), _n('b', read: true)],
    );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    expect(await repo.unreadCount(), 0);
    await _openHeadMenu(tester, t.notifications.today);
    await tester.tap(find.text(t.notifications.markAllUnread));
    await tester.pumpAndSettle();
    expect(await repo.unreadCount(), 2); // all rows re-marked unread
  });

  testWidgets('tapping a group head collapses its rows (head stays)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FixtureNotificationRepository(seed: [_n('a'), _n('b')])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));
    await tester.tap(find.text(t.notifications.today));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNothing); // collapsed
    expect(find.text(t.notifications.today), findsOneWidget); // head persists
  });

  // Collapse/expand rides the SAME rail slide as AnSidebarList (a SliverAnimatedList SizeTransition), never
  // an instant jump. 折叠/展开与左岛 rail 同一套滑动(SliverAnimatedList SizeTransition),非瞬跳。
  testWidgets(
    'collapsing a bucket SLIDES its rows out (SizeTransition mid-frame), not an instant jump',
    (tester) async {
      await tester.pumpWidget(
        _host(FixtureNotificationRepository(seed: [_n('a'), _n('b')])),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(2));
      await tester.tap(find.text(t.notifications.today)); // collapse
      await tester.pump(); // kick off the removal tween
      await tester.pump(const Duration(milliseconds: 60)); // mid-flight
      final sliding = tester
          .widgetList<SizeTransition>(find.byType(SizeTransition))
          .where((s) => s.sizeFactor.value > 0.0 && s.sizeFactor.value < 1.0);
      expect(
        sliding,
        isNotEmpty,
        reason:
            'the rows must slide out under a SizeTransition — a unified rail slide, not a jump',
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNothing); // settles collapsed
    },
  );

  testWidgets('reduced motion collapses instantly (no mid-flight slide)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FixtureNotificationRepository(seed: [_n('a'), _n('b')]),
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));
    await tester.tap(find.text(t.notifications.today)); // collapse
    await tester.pump(); // a single frame — reduced → Duration.zero → immediate
    expect(find.byType(NotificationRow), findsNothing); // instant, no tween
  });

  testWidgets(
    'geometry: bare AnRow heads share the rail column with the rows (block fills, content +s8; no +s4)',
    (tester) async {
      await tester.pumpWidget(
        _host(FixtureNotificationRepository(seed: [_n('a')])),
      );
      await tester.pumpAndSettle();
      final trayLeft = tester.getTopLeft(find.byType(NotificationTray)).dx;
      // The head is a BARE AnRow — its hover block fills from the tray/island edge (no +s4 outer padding
      // shifting it right). 组头裸 AnRow:块从托盘/岛边起(无 +s4 右推)。
      final headRow = find.ancestor(
        of: find.text(t.notifications.today),
        matching: find.byType(AnRow),
      );
      expect(headRow, findsOneWidget);
      expect(tester.getTopLeft(headRow).dx, trayLeft);
      // The head chevron and the notification row's lead icon sit on ONE vertical line. The chevron is measured
      // by CENTRE (an open head's chevron is rotated 90°, so its top-left corner is rotation-displaced); the
      // row icon (unrotated) pins the column at the rail's s8 content inset. 组头 chevron 与行图标同竖线(chevron 取中心避旋转、
      // 行图标取左缘锁 s8 内容列)。
      final chevronCX = tester
          .getCenter(
            find.descendant(
              of: headRow,
              matching: find.byIcon(AnIcons.chevronRight),
            ),
          )
          .dx;
      final rowIcon = find
          .descendant(
            of: find.byType(NotificationRow),
            matching: find.byType(Icon),
          )
          .first;
      expect(tester.getCenter(rowIcon).dx, chevronCX);
      expect(tester.getTopLeft(rowIcon).dx - trayLeft, AnSpace.s8);
    },
  );

  testWidgets(
    'a filter change re-keys instantly — filtered-out rows vanish with NO removal tween',
    (tester) async {
      // A DATA/filter change re-flattens fresh under a new key (no insert/remove animation — the tween is only
      // for user toggles). 数据/过滤变=换 key 整重建、不走插删动画(补间只给用户 toggle)。
      await tester.pumpWidget(
        _host(
          FixtureNotificationRepository(
            seed: [
              _n('a', name: 'alpha'),
              _n('b', name: 'beta'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotificationRow), findsNWidgets(2));
      await tester.enterText(
        find.byType(EditableText),
        'alpha',
      ); // filter → re-key rebuild
      await tester.pump(); // a single frame
      expect(
        find.byType(NotificationRow),
        findsOneWidget,
      ); // gone in ONE frame (not shrinking under a tween)
      final sliding = tester
          .widgetList<SizeTransition>(find.byType(SizeTransition))
          .where((s) => s.sizeFactor.value > 0.0 && s.sizeFactor.value < 1.0);
      expect(
        sliding,
        isEmpty,
        reason:
            'a filter change must re-key (instant), never run a removal tween',
      );
    },
  );

  testWidgets('search filters the feed by rendered content', (tester) async {
    await tester.pumpWidget(
      _host(
        FixtureNotificationRepository(
          seed: [
            _n('a', name: 'alpha'),
            _n('b', name: 'beta'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));
    await tester.enterText(find.byType(EditableText), 'alpha');
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsOneWidget);
  });

  testWidgets('⚙ "unread only" hides read rows', (tester) async {
    await tester.pumpWidget(
      _host(
        FixtureNotificationRepository(seed: [_n('a'), _n('b', read: true)]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(2));
    await tester.tap(find.byIcon(AnIcons.sliders)); // the ⚙ display menu
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.notifications.unreadOnly));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsOneWidget); // only the unread one
  });

  testWidgets(
    'injected approvals band is the top group; it hides while searching',
    (tester) async {
      await tester.pumpWidget(
        _host(
          FixtureNotificationRepository(seed: [_n('a', name: 'alpha')]),
          band: const Text('BAND'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('BAND'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'zzz');
      await tester.pumpAndSettle();
      expect(
        find.text('BAND'),
        findsNothing,
      ); // approvals aren't notification content — hidden under a query
    },
  );

  testWidgets('massive list renders without overflow', (tester) async {
    await tester.pumpWidget(
      _host(
        FixtureNotificationRepository(
          seed: [for (var i = 0; i < 200; i++) _n('n$i')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationRow), findsWidgets);
  });
}
