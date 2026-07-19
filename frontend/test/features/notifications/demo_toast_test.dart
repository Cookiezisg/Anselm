import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/features/notifications/data/notification_demo_fixture.dart';
import 'package:anselm/features/notifications/data/notification_signal.dart';
import 'package:anselm/features/notifications/ui/notification_copy.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

// D-031 — the demo emits a LIVE toast a few seconds after launch (demo_main schedules
// repo.emit(demoLiveToast())). Verify the seeded event is toast-worthy (danger tone) AND that emit pushes
// the durable signal the ToastDispatcher listens on. demo 延时活 toast:danger 且 emit 推 durable 信号。
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  test('the live toast event classifies as danger (so the dispatcher pops it)', () {
    final line = notificationLine(demoLiveToast(), t);
    expect(line.tone, AnTone.danger, reason: 'run_failed → 红,穿透 toast 开关');
  });

  test('emit pushes a durable signal on the stream', () async {
    final repo = demoNotificationRepository();
    final got = <NotificationSignal>[];
    final sub = repo.signals().listen(got.add);
    repo.emit(demoLiveToast());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(got, isNotEmpty);
    expect(got.first.durable, isTrue);
    expect(got.first.type, 'workflow.run_failed');
  });
}
