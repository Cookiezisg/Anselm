import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/data/os_notifier.dart';
import 'package:anselm/features/notifications/state/app_focus_provider.dart';
import 'package:anselm/features/notifications/state/notice_capsule_provider.dart';
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

// The event→capsule bridge (用户 0720: the top-right toast is retired; the band capsule is the only
// floating surface). Pins: danger → one capsule; warn on the default level → NO float (bell dot is its
// presentation); 'all' level → warn pops too; neutral stays silent; storms dedup; unfocused → OS.

NotificationItem _n(String type, Map<String, dynamic> payload) =>
    NotificationItem(id: 'x', type: type, payload: payload, createdAt: DateTime.utc(2026, 7, 6));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  (ProviderContainer, FixtureNotificationRepository) setup(
      {String? level, void Function(SettingsPrefs)? prefsTweak}) {
    final repo = FixtureNotificationRepository(seed: const []);
    final prefs = SettingsPrefs.inMemory();
    if (level != null) prefs.setString(SettingsKeys.notifyLevel, level);
    prefsTweak?.call(prefs);
    final c = ProviderContainer(overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
      settingsPrefsProvider.overrideWithValue(prefs),
    ]);
    addTearDown(c.dispose);
    c.read(toastDispatcherProvider); // subscribe
    return (c, repo);
  }

  List<CapsuleNotice> capsules(ProviderContainer c) => c.read(noticeCapsuleProvider);

  test('a danger event pushes ONE band capsule (deep-link attached)', () async {
    final (c, repo) = setup();
    repo.emit(_n('workflow.run_failed', {'name': 'w', 'workflowId': 'wf_1', 'error': 'boom'}));
    await pumpEventQueue();
    expect(capsules(c).length, 1);
    expect(capsules(c).single.danger, isTrue);
    expect(capsules(c).single.text, contains('w'));
    expect(capsules(c).single.location, '/entities/workflow/wf_1');
    // The legacy top-right toast never fires for events anymore. 旧右上事件 toast 退役。
    expect(c.read(overlayProvider).toasts, isEmpty);
  });

  test('an ATTENTION warn on the default registry floats nothing (bell dot is its presentation)',
      () async {
    final (c, repo) = setup();
    repo.emit(_n('workflow.attention_changed',
        {'name': 'etl', 'workflowId': 'wf_2', 'needsAttention': true}));
    await pumpEventQueue();
    expect(capsules(c), isEmpty);
    expect(c.read(overlayProvider).toasts, isEmpty);
  });

  test('an APPROVAL pops the BLOCK capsule by default (registry on) with exact coordinates', () async {
    final (c, repo) = setup();
    repo.emit(_n('workflow.approval_pending',
        {'name': 'deploy', 'workflowId': 'wf_2', 'flowrunId': 'fr_1', 'nodeId': 'gate'}));
    await pumpEventQueue();
    expect(capsules(c).length, 1);
    final cap = capsules(c).single;
    expect(cap.kind, CapsuleKind.approval);
    expect(cap.danger, isFalse, reason: '审批=warn 琥珀,绝非 danger 红(分级点色铁律)');
    expect(cap.title, 'deploy');
    expect((cap.flowrunId, cap.nodeId), ('fr_1', 'gate'));
  });

  test('registry OFF switches silence their class (approvals / failures)', () async {
    final (c, repo) = setup(prefsTweak: (p) {
      p.setBool(SettingsKeys.capsuleApprovals, false);
      p.setBool(SettingsKeys.capsuleFailures, false);
    });
    repo.emit(_n('workflow.approval_pending',
        {'name': 'deploy', 'workflowId': 'wf_2', 'flowrunId': 'fr_1', 'nodeId': 'gate'}));
    repo.emit(_n('workflow.run_failed', {'name': 'w', 'workflowId': 'wf_1', 'error': 'x'}));
    await pumpEventQueue();
    expect(capsules(c), isEmpty, reason: '登记关掉的类不上带(铃/托盘仍有)');
  });

  test('an approval CUTS THE LINE ahead of queued pills, never displacing a showing approval', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final q = c.read(noticeCapsuleProvider.notifier);
    q.push(const CapsuleNotice(key: 'p1', text: 'pill1'));
    q.push(const CapsuleNotice(key: 'p2', text: 'pill2'));
    q.push(const CapsuleNotice(key: 'a1', text: 'appr', kind: CapsuleKind.approval));
    expect(c.read(noticeCapsuleProvider).map((n) => n.key), ['a1', 'p1', 'p2']);
    q.push(const CapsuleNotice(key: 'a2', text: 'appr2', kind: CapsuleKind.approval));
    expect(c.read(noticeCapsuleProvider).map((n) => n.key).take(2), ['a1', 'a2'],
        reason: '在显审批不被顶,新审批排其后');
  });

  test("level 'all': a warn event DOES pop a (non-danger) capsule", () async {
    final (c, repo) = setup(level: 'all');
    repo.emit(_n('workflow.approval_pending', {'name': 'deploy', 'workflowId': 'wf_2'}));
    await pumpEventQueue();
    expect(capsules(c).length, 1);
    expect(capsules(c).single.danger, isFalse);
  });

  test('neutral lifecycle events stay SILENT (tray-only)', () async {
    final (c, repo) = setup();
    repo.emit(_n('function.created', {'name': 'fetch', 'functionId': 'fn_1'}));
    repo.emit(_n('agent.edited', {'name': 'triager', 'agentId': 'ag_1'}));
    await pumpEventQueue();
    expect(capsules(c), isEmpty);
  });

  test('a same-key storm is deduped to one capsule', () async {
    final (c, repo) = setup();
    for (var i = 0; i < 5; i++) {
      repo.emit(_n('workflow.run_failed', {'name': 'w', 'workflowId': 'wf_1', 'error': 'boom $i'}));
    }
    await pumpEventQueue();
    expect(capsules(c).length, 1); // deduped within the window
  });

  test('different entities each get their own capsule', () async {
    final (c, repo) = setup();
    repo.emit(_n('workflow.run_failed', {'name': 'a', 'workflowId': 'wf_1', 'error': 'x'}));
    repo.emit(_n('handler.crashed', {'name': 'b', 'handlerId': 'hd_1'}));
    await pumpEventQueue();
    expect(capsules(c).length, 2);
  });

  test('UNFOCUSED → an OS notification instead of a capsule', () async {
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
    expect(capsules(c), isEmpty);
    expect(os.shows.length, 1);
    expect(os.shows.single.body, contains('w'));
    expect(os.shows.single.location, '/entities/workflow/wf_1');
  });

  test('queue is bounded: a burst keeps the showing head and the newest tail', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final q = c.read(noticeCapsuleProvider.notifier);
    for (var i = 0; i < 9; i++) {
      q.push(CapsuleNotice(key: 'k$i', text: 't$i'));
    }
    final keys = c.read(noticeCapsuleProvider).map((n) => n.key).toList();
    expect(keys.length, 5);
    expect(keys.first, 'k0', reason: '在显头条保住');
    expect(keys.last, 'k8', reason: '最新一条保住,裁的是中段最旧');
    q.pop();
    expect(c.read(noticeCapsuleProvider).first.key, isNot('k0'));
  });
}
