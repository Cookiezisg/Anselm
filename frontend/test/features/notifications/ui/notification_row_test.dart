import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_status_dot.dart';
import 'package:anselm/features/notifications/ui/notification_row.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The notification row widget. Pins: unread renders the message; read still renders (audit trail, stays
// in the list); tap deep-links; overlong name + injection never overflow and the script is inert text;
// 已读律 (0719) — NO leading unread dot (kind icon is the sole lead).

final _now = DateTime.utc(2026, 7, 6, 12);

NotificationItem _n(String type, {Map<String, dynamic> payload = const {}, bool read = false}) => NotificationItem(
      id: 'noti_x',
      type: type,
      payload: payload,
      createdAt: _now.subtract(const Duration(minutes: 5)),
      readAt: read ? _now : null,
    );

Widget _host(Widget child) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SizedBox(width: 320, child: child))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('unread row renders the composed message + relative time', (tester) async {
    await tester.pumpWidget(_host(NotificationRow(item: _n('function.created', payload: {'name': 'fetch_orders'}), now: _now)));
    expect(find.textContaining('fetch_orders', findRichText: true), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
  });

  testWidgets('read row still renders (stays in the list as an audit trail)', (tester) async {
    await tester.pumpWidget(_host(NotificationRow(item: _n('function.created', payload: {'name': 'fetch_orders'}, read: true), now: _now)));
    expect(find.textContaining('fetch_orders', findRichText: true), findsOneWidget);
  });

  testWidgets('tap deep-links (onTap fires)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(NotificationRow(
      item: _n('workflow.run_failed', payload: {'name': 'w', 'error': 'boom'}),
      now: _now,
      onTap: () => tapped = true,
    )));
    await tester.tap(find.byType(NotificationRow));
    expect(tapped, isTrue);
  });

  testWidgets('danger event shows its error detail line', (tester) async {
    await tester.pumpWidget(_host(NotificationRow(
      item: _n('workflow.run_failed', payload: {'name': 'nightly', 'error': 'connection refused'}), now: _now)));
    expect(find.textContaining('connection refused'), findsOneWidget);
  });

  testWidgets('overlong name + <script> injection: no overflow, script is inert text', (tester) async {
    await tester.pumpWidget(_host(NotificationRow(
      item: _n('function.created', payload: {'name': '${'x_' * 60}<script>alert(1)</script>'}), now: _now)));
    await tester.pump();
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    // The script text is rendered as literal characters (never interpreted) — the label carries it.
    expect(find.textContaining('<script>', findRichText: true), findsOneWidget);
  });

  testWidgets('已读律: no leading unread dot — the kind icon is the sole lead (未读点退役)', (tester) async {
    // An UNREAD row must NOT carry a leading status dot; unread vs read is carried by the icon colour +
    // the whole-row fade alone (0719 «行首未读点退役 ● ⚠→⚠»). 未读行无行首点,靠图标色+整行褪色区分。
    await tester.pumpWidget(_host(NotificationRow(item: _n('function.created', payload: {'name': 'fetch'}), now: _now)));
    expect(find.byType(AnStatusDot), findsNothing);
    expect(find.byType(Icon), findsWidgets); // the kind/tone icon is present as the lead
  });

  testWidgets('nameless row renders without a dangling object', (tester) async {
    await tester.pumpWidget(_host(NotificationRow(item: _n('agent.created'), now: _now)));
    expect(tester.takeException(), isNull);
    // 智能体 已创建 — kind + verb, no 「」 empty brackets.
    expect(find.textContaining('「」', findRichText: true), findsNothing);
  });
}
