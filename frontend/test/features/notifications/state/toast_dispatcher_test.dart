import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/data/os_notifier.dart';
import 'package:anselm/features/notifications/state/app_focus_provider.dart';
import 'package:anselm/features/notifications/state/toast_dispatcher.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records OS-notification shows so a test can assert the unfocused route. 记录 OS 通知以断言未聚焦路由。
class _FakeOsNotifier implements OsNotifier {
  final shows = <({String title, String body, String? location})>[];
  @override
  Future<void> init(void Function(String) onTapLocation) async {}
  @override
  Future<void> show({required String key, required String title, required String body, String? location}) async {
    shows.add((title: title, body: body, location: location));
  }
}

// The event→toast bridge. Pins: important (warn/danger) events pop a toast; neutral lifecycle stays
// silent; danger = sticky, warn = 8s; a same-key storm is deduped to one toast.

NotificationItem _n(String type, Map<String, dynamic> payload) =>
    NotificationItem(id: 'x', type: type, payload: payload, createdAt: DateTime.utc(2026, 7, 6));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  (ProviderContainer, FixtureNotificationRepository) setup() {
    final repo = FixtureNotificationRepository(seed: const []);
    final c = ProviderContainer(overrides: [notificationRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.read(toastDispatcherProvider); // subscribe
    return (c, repo);
  }

  List<AnToastData> toasts(ProviderContainer c) => c.read(overlayProvider).toasts;

  test('an important (danger) event pops a sticky toast', () async {
    final (c, repo) = setup();
    repo.emit(_n('workflow.run_failed', {'name': 'w', 'workflowId': 'wf_1', 'error': 'boom'}));
    await pumpEventQueue();
    expect(toasts(c).length, 1);
    expect(toasts(c).single.tone, AnTone.danger);
    expect(toasts(c).single.duration, Duration.zero); // sticky
    expect(toasts(c).single.text, contains('w'));
  });

  test('a warn event pops an 8s toast', () async {
    final (c, repo) = setup();
    repo.emit(_n('workflow.approval_pending', {'name': 'deploy', 'workflowId': 'wf_2'}));
    await pumpEventQueue();
    expect(toasts(c).single.tone, AnTone.warn);
    expect(toasts(c).single.duration, const Duration(seconds: 8));
  });

  test('neutral lifecycle events stay SILENT (tray-only)', () async {
    final (c, repo) = setup();
    repo.emit(_n('function.created', {'name': 'fetch', 'functionId': 'fn_1'}));
    repo.emit(_n('agent.edited', {'name': 'triager', 'agentId': 'ag_1'}));
    await pumpEventQueue();
    expect(toasts(c), isEmpty);
  });

  test('a same-key storm is deduped to one toast', () async {
    final (c, repo) = setup();
    for (var i = 0; i < 5; i++) {
      repo.emit(_n('workflow.run_failed', {'name': 'w', 'workflowId': 'wf_1', 'error': 'boom $i'}));
    }
    await pumpEventQueue();
    expect(toasts(c).length, 1); // deduped within the window
  });

  test('different entities each get their own toast', () async {
    final (c, repo) = setup();
    repo.emit(_n('workflow.run_failed', {'name': 'a', 'workflowId': 'wf_1', 'error': 'x'}));
    repo.emit(_n('handler.crashed', {'name': 'b', 'handlerId': 'hd_1'}));
    await pumpEventQueue();
    expect(toasts(c).length, 2);
  });

  test('UNFOCUSED → an OS notification instead of an in-app toast', () async {
    final repo = FixtureNotificationRepository(seed: const []);
    final os = _FakeOsNotifier();
    final c = ProviderContainer(overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
      osNotifierProvider.overrideWithValue(os),
    ]);
    addTearDown(c.dispose);
    c.read(toastDispatcherProvider);
    c.read(appFocusedProvider); // build the focus notifier (state = true)
    c.read(appFocusedProvider.notifier).debugSetLifecycle(AppLifecycleState.paused); // window blurred
    expect(c.read(appFocusedProvider), isFalse);

    repo.emit(_n('workflow.run_failed', {'name': 'w', 'workflowId': 'wf_1', 'error': 'boom'}));
    await pumpEventQueue();
    // The toast did NOT fire; the OS notifier did (with the composed body + a deep-link location).
    expect(c.read(overlayProvider).toasts, isEmpty);
    expect(os.shows.length, 1);
    expect(os.shows.single.body, contains('w'));
    expect(os.shows.single.location, '/entities/workflow/wf_1');
  });
}
