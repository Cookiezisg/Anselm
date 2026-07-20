import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  NoticeCenter controller() => container.read(noticeCenterProvider.notifier);
  NoticeCenterState state() => container.read(noticeCenterProvider);

  String normal(String text, {String? coalesceKey}) =>
      controller().push(NoticeMessage(text: text, coalesceKey: coalesceKey));

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test(
    'first is current; priority waits ahead of normal without preempting current',
    () {
      final a = normal('A');
      final b = normal('B');
      final approval = controller().push(
        const NoticeMessage(
          text: 'C',
          tone: AnTone.warn,
          kind: NoticeKind.approval,
        ),
        priority: NoticePriority.priority,
      );

      expect(
        state().current?.id,
        a,
        reason: 'arrival never replaces the visible card',
      );
      expect(state().queue.cues.map((cue) => cue.id), [approval, b]);
      controller().finishExit(a);
      expect(state().current?.id, approval);
      expect(state().current?.briskPlayback, isTrue, reason: '积压播放使用较短但可读的驻留');
      expect(state().queue.cues.single.id, b);
      controller().finishExit(approval);
      expect(state().current?.briskPlayback, isFalse, reason: '最后一条恢复标准驻留');
    },
  );

  test('unbounded FIFO playback does not drop after the old cap of five', () {
    final ids = [for (var i = 0; i < 100; i++) normal('$i')];
    final played = <String>[];
    while (true) {
      final current = state().current;
      if (current == null) break;
      played.add(current.id);
      controller().finishExit(current.id);
    }
    expect(played, ids);
    expect(state().current, isNull);
    expect(state().queue.pendingCount, 0);
  });

  test(
    'continuous priority yields to one waiting normal after every three',
    () {
      final current = normal('current');
      final normals = [normal('normal 1'), normal('normal 2')];
      final priorities = [
        for (var i = 1; i <= 7; i++)
          controller().push(
            NoticeMessage(text: 'priority $i'),
            priority: NoticePriority.priority,
          ),
      ];

      final played = <String>[];
      controller().finishExit(current);
      while (state().current != null) {
        final staged = state().current!;
        played.add(staged.id);
        controller().finishExit(staged.id);
      }

      expect(played, [
        priorities[0],
        priorities[1],
        priorities[2],
        normals[0],
        priorities[3],
        priorities[4],
        priorities[5],
        normals[1],
        priorities[6],
      ]);
    },
  );

  test(
    'ten thousand pending messages still expose only two lightweight cues',
    () {
      normal('current');
      for (var i = 0; i < 10000; i++) {
        normal('pending $i');
      }
      expect(state().queue.pendingCount, 10000);
      expect(state().queue.cues, hasLength(2));
      expect(state().queue.overflowCount, 9998);
    },
  );

  test('stale finish/dismiss callbacks cannot remove a newer current', () {
    final a = normal('A');
    final b = normal('B');
    controller().finishExit(a);
    expect(state().current?.id, b);
    controller().finishExit(a);
    controller().dismissCurrent(a);
    expect(state().current?.id, b);
    expect(state().current?.dismissRequested, isFalse);
  });

  test(
    'bulk clear keeps current mounted, clears snapshot, and preserves later arrivals',
    () {
      final a = normal('A');
      normal('old B');
      normal('old C');
      normal('old D');
      controller().clearVisibleSnapshot();

      expect(state().current?.id, a);
      expect(state().current?.dismissRequested, isTrue);
      expect(state().queue.pendingCount, 0);

      final fresh = normal('fresh');
      expect(
        state().queue.pendingCount,
        1,
        reason: 'arrival during clear animation survives',
      );
      controller().finishExit(a);
      expect(state().current?.id, fresh);
      controller().finishExit(a); // repeated old callback is inert
      expect(state().current?.id, fresh);
    },
  );

  test('clear is idempotent and safe on an empty stage', () {
    controller().clearVisibleSnapshot();
    final a = normal('A');
    normal('B');
    normal('C');
    controller().clearVisibleSnapshot();
    controller().clearVisibleSnapshot();
    expect(state().current?.id, a);
    expect(state().current?.dismissRequested, isTrue);
    expect(state().queue.pendingCount, 0);
  });

  test(
    'optional operation coalesce key is O(1)-style active dedup, then re-arms after exit',
    () {
      final first = normal('save failed', coalesceKey: 'save:doc');
      final duplicate = normal('save failed again', coalesceKey: 'save:doc');
      expect(duplicate, first);
      expect(state().queue.pendingCount, 0);
      controller().finishExit(first);
      final later = normal('save failed later', coalesceKey: 'save:doc');
      expect(later, isNot(first));
    },
  );
}
