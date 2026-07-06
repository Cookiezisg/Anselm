import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/ui/notification_feed.dart';
import 'package:anselm/features/notifications/ui/notification_row.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The feed widget. Pins: empty → caught-up state; populated → rows + a "mark all read" header that clears
// the badge + grays the rows; massive list doesn't throw.

NotificationItem _n(String id, {bool read = false}) => NotificationItem(
      id: id,
      type: 'function.created',
      payload: const {'name': 'fetch'},
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      readAt: read ? DateTime.now() : null,
    );

Widget _host(FixtureNotificationRepository repo) => ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        notificationDebounceProvider.overrideWithValue(Duration.zero),
      ],
      child: TranslationProvider(
        child: MaterialApp(theme: AnTheme.light(), home: const Scaffold(body: SizedBox(width: 320, height: 600, child: NotificationFeed()))),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('empty feed → caught-up state, no mark-all', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: const [])));
    await tester.pumpAndSettle();
    expect(find.text(t.notifications.emptyTitle), findsOneWidget);
    expect(find.text(t.notifications.markAllRead), findsNothing);
  });

  testWidgets('populated feed → rows + mark-all clears them', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [_n('a'), _n('b'), _n('c')])));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationRow), findsNWidgets(3));
    expect(find.text(t.notifications.markAllRead), findsOneWidget);

    await tester.tap(find.text(t.notifications.markAllRead));
    await tester.pumpAndSettle();
    // Mark-all zeroed the badge → the header's mark-all affordance disappears. 全部已读后 mark-all 消失。
    expect(find.text(t.notifications.markAllRead), findsNothing);
  });

  testWidgets('massive list renders without overflow', (tester) async {
    await tester.pumpWidget(_host(FixtureNotificationRepository(seed: [for (var i = 0; i < 200; i++) _n('n$i')])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NotificationRow), findsWidgets);
  });
}
