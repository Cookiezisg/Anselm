import 'package:anselm/app/app_shell.dart';
import 'package:anselm/app/router.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/features/library/data/library_repository.dart';
import 'package:anselm/features/library/data/library_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/notifications/data/notification_demo_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/scheduler/data/scheduler_demo_fixture.dart';
import 'package:anselm/features/scheduler/data/scheduler_repository.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Chat right island ON-DEMAND EXISTENCE — the end-to-end shell behaviour (用户 0718-19): a conversation WITH
// activity earns the panel-right toggle but the island does NOT auto-pop (default collapsed, WRK-065); the
// user opens it explicitly. A conversation WITHOUT activity has neither island nor toggle. 有 activity 才有
// 右岛+toggle,但不自动开岛(用户点开);无 activity 对话强制无岛无钮。

class _Shell extends ConsumerWidget {
  const _Shell();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    routerConfig: ref.watch(goRouterProvider),
  );
}

ProviderScope _host() => ProviderScope(
  overrides: [
    entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
    chatRepositoryProvider.overrideWithValue(demoChatRepository()),
    notificationRepositoryProvider.overrideWithValue(
      demoNotificationRepository(),
    ),
    libraryRepositoryProvider.overrideWithValue(demoLibraryRepository()),
    schedulerRepositoryProvider.overrideWithValue(demoSchedulerRepository()),
    goRouterProvider.overrideWith(buildAppRouter),
  ],
  child: TranslationProvider(child: const _Shell()),
);

Future<void> _pump(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'activity conversation: toggle appears, island stays CLOSED, then a tap OPENS it',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());
      // The unread badge starts its live repository after the shell's first frame. This must never feed
      // a provider invalidation back into the shell while it is building.
      // 未读徽标在壳首帧后才起 live repository；绝不允许 provider 失效在壳 build 中回冲。
      expect(tester.takeException(), isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
        listen: false,
      );
      container
          .read(goRouterProvider)
          .go(conversationLocation('cv_sync')); // seeded touchpoints
      await _pump(tester);

      // The toggle is lit (activity present) but the island did NOT auto-open (chat default collapsed). 钮亮、岛未自动开。
      expect(
        find.byIcon(AnIcons.panelRight),
        findsOneWidget,
        reason: 'activity earns the toggle',
      );
      expect(
        find.byType(StagePanel),
        findsNothing,
        reason: 'island stays closed — no auto-pop (WRK-065)',
      );

      // The user opens it explicitly. 用户点开。
      await tester.tap(find.byIcon(AnIcons.panelRight));
      await _pump(tester);
      expect(
        find.byType(StagePanel),
        findsOneWidget,
        reason: 'a tap opens the sidestage',
      );
    },
  );

  testWidgets(
    'a plain Q&A conversation (no activity) has NO toggle and NO island',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
        listen: false,
      );
      container
          .read(goRouterProvider)
          .go(conversationLocation('cv_p01')); // Q&A only, no tools/touchpoints
      await _pump(tester);

      expect(
        find.byIcon(AnIcons.panelRight),
        findsNothing,
        reason: 'no content → no door',
      );
      expect(find.byType(StagePanel), findsNothing);
    },
  );
}
