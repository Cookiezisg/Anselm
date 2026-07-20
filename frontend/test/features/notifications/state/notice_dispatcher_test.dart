import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/data/os_notifier.dart';
import 'package:anselm/features/notifications/state/app_focus_provider.dart';
import 'package:anselm/features/notifications/state/notice_dispatcher.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOsNotifier implements OsNotifier {
  final shows = <({String title, String body, String? location})>[];

  @override
  Future<void> init(void Function(String) onTapLocation) async {}

  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
    String? location,
  }) async {
    shows.add((title: title, body: body, location: location));
  }
}

NotificationItem _n(String type, Map<String, dynamic> payload) =>
    NotificationItem(
      id: 'x',
      type: type,
      payload: payload,
      createdAt: DateTime.utc(2026, 7, 6),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  (ProviderContainer, FixtureNotificationRepository) setup({
    String? level,
    void Function(SettingsPrefs)? prefsTweak,
  }) {
    final repo = FixtureNotificationRepository(seed: const []);
    final prefs = SettingsPrefs.inMemory();
    if (level != null) prefs.setString(SettingsKeys.notifyLevel, level);
    prefsTweak?.call(prefs);
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        settingsPrefsProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    container.read(noticeDispatcherProvider);
    return (container, repo);
  }

  NoticeCenterState stage(ProviderContainer container) =>
      container.read(noticeCenterProvider);

  test(
    'danger event enters the single top band with full tone and deep link',
    () async {
      final (container, repo) = setup();
      repo.emit(
        _n('workflow.run_failed', {
          'name': 'w',
          'workflowId': 'wf_1',
          'error': 'boom',
        }),
      );
      await pumpEventQueue();
      final message = stage(container).current?.message;
      expect(message?.tone, AnTone.danger);
      expect(message?.text, contains('w'));
      expect(message?.location, '/entities/workflow/wf_1');
      expect(message?.origin, NoticeOrigin.event);
    },
  );

  test('attention warn on default registry stays tray-only', () async {
    final (container, repo) = setup();
    repo.emit(
      _n('workflow.attention_changed', {
        'name': 'etl',
        'workflowId': 'wf_2',
        'needsAttention': true,
      }),
    );
    await pumpEventQueue();
    expect(stage(container).current, isNull);
  });

  test(
    'approval uses block grammar and exact parked-node coordinates',
    () async {
      final (container, repo) = setup();
      repo.emit(
        _n('workflow.approval_pending', {
          'name': 'deploy',
          'workflowId': 'wf_2',
          'flowrunId': 'fr_1',
          'nodeId': 'gate',
        }),
      );
      await pumpEventQueue();
      final message = stage(container).current?.message;
      expect(message?.kind, NoticeKind.approval);
      expect(message?.tone, AnTone.warn);
      expect(message?.title, 'deploy');
      expect((message?.flowrunId, message?.nodeId), ('fr_1', 'gate'));
    },
  );

  test('registry switches silence their event class', () async {
    final (container, repo) = setup(
      prefsTweak: (prefs) {
        prefs.setBool(SettingsKeys.capsuleApprovals, false);
        prefs.setBool(SettingsKeys.capsuleFailures, false);
      },
    );
    repo.emit(
      _n('workflow.approval_pending', {
        'name': 'deploy',
        'workflowId': 'wf_2',
        'flowrunId': 'fr_1',
        'nodeId': 'gate',
      }),
    );
    repo.emit(
      _n('workflow.run_failed', {
        'name': 'w',
        'workflowId': 'wf_1',
        'error': 'x',
      }),
    );
    await pumpEventQueue();
    expect(stage(container).current, isNull);
  });

  test("level 'all' allows a warn event into the band", () async {
    final (container, repo) = setup(level: 'all');
    repo.emit(
      _n('workflow.approval_pending', {'name': 'deploy', 'workflowId': 'wf_2'}),
    );
    await pumpEventQueue();
    expect(stage(container).current?.message.tone, AnTone.warn);
  });

  test('neutral lifecycle events remain silent on important level', () async {
    final (container, repo) = setup();
    repo.emit(_n('function.created', {'name': 'fetch', 'functionId': 'fn_1'}));
    repo.emit(_n('agent.edited', {'name': 'triager', 'agentId': 'ag_1'}));
    await pumpEventQueue();
    expect(stage(container).current, isNull);
  });

  test(
    'same-key storm is deduped; different entities remain real candidates',
    () async {
      final (container, repo) = setup();
      for (var i = 0; i < 5; i++) {
        repo.emit(
          _n('workflow.run_failed', {
            'name': 'w',
            'workflowId': 'wf_1',
            'error': 'boom $i',
          }),
        );
      }
      repo.emit(_n('handler.crashed', {'name': 'b', 'handlerId': 'hd_1'}));
      await pumpEventQueue();
      expect(stage(container).current, isNotNull);
      expect(stage(container).queue.pendingCount, 1);
    },
  );

  test('unfocused routes to OS instead of the in-app stage', () async {
    final repo = FixtureNotificationRepository(seed: const []);
    final os = _FakeOsNotifier();
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        osNotifierProvider.overrideWithValue(os),
      ],
    );
    addTearDown(container.dispose);
    container.read(noticeDispatcherProvider);
    container.read(appFocusedProvider);
    container
        .read(appFocusedProvider.notifier)
        .debugSetLifecycle(AppLifecycleState.paused);

    repo.emit(
      _n('workflow.run_failed', {
        'name': 'w',
        'workflowId': 'wf_1',
        'error': 'boom',
      }),
    );
    await pumpEventQueue();
    expect(stage(container).current, isNull);
    expect(os.shows, hasLength(1));
    expect(os.shows.single.body, contains('w'));
    expect(os.shows.single.location, '/entities/workflow/wf_1');
  });
}
