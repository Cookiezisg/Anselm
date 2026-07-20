import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/dev/demo_notice_showcase.dart';
import 'package:anselm/features/notifications/data/notification_demo_fixture.dart';
import 'package:anselm/features/notifications/data/notification_signal.dart';
import 'package:anselm/features/notifications/ui/notification_copy.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

// The demo's top-band tour is data-only here: prove its timing and semantic mix without letting real timers
// leak into widget tests. The fixture's durable row still proves the repository signal seam separately.
// demo 顶带巡演在此只验数据:时间/语义混合不让真计时器泄入 widget 测;fixture durable 行另验仓储信号缝。
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  test('the durable fixture failure classifies as danger', () {
    final line = notificationLine(demoFailureNotice(), t);
    expect(line.tone, AnTone.danger, reason: 'run_failed → 红,穿透应用内提醒开关');
  });

  test('top-band demo tour is slow, varied, and reaches approval +N', () {
    final beats = demoTopBandShowcase(t);
    expect(beats.map((beat) => beat.at), const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 6),
      Duration(seconds: 10),
      Duration(seconds: 14),
      Duration(seconds: 17),
      Duration(seconds: 20),
      Duration(seconds: 23),
    ]);
    expect(
      beats.where((beat) => beat.message.origin == NoticeOrigin.operation),
      hasLength(3),
    );
    expect(
      beats.where((beat) => beat.message.origin == NoticeOrigin.event),
      hasLength(4),
    );
    final approval = beats.singleWhere(
      (beat) => beat.message.kind == NoticeKind.approval,
    );
    expect(approval.message.flowrunId, 'flr_park');
    expect(approval.message.nodeId, 'approve_deploy');
    expect(approval.priority, NoticePriority.priority);
    expect(beats.last.at, greaterThan(approval.at));
  });

  test('emit pushes a durable signal on the stream', () async {
    final repo = demoNotificationRepository();
    final got = <NotificationSignal>[];
    final sub = repo.signals().listen(got.add);
    repo.emit(demoFailureNotice());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(got, isNotEmpty);
    expect(got.first.durable, isTrue);
    expect(got.first.type, 'workflow.run_failed');
  });
}
