import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/features/chat/ui/conversation_rail_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Local (not UTC) timestamps so toLocal() is identity → bucket/time tests are TZ-deterministic.
Conversation _cAt(String id, DateTime at, {bool pinned = false}) =>
    Conversation(id: id, title: id, pinned: pinned, createdAt: at, updatedAt: at, lastMessageAt: at);

final _now = DateTime(2026, 6, 26, 12);

final _timeStrings = ConvTimeStrings(
  justNow: 'now',
  yesterday: 'yest',
  minutesAgo: (n) => '${n}m',
  hoursAgo: (n) => '${n}h',
  daysAgo: (n) => '${n}d',
);

const _labels = ConvRailLabels(
  newLabel: 'New',
  filter: 'Filter',
  pinned: 'PINNED',
  recents: 'RECENTS',
  time: ConvTimeStrings(justNow: 'now', yesterday: 'yest', minutesAgo: _m, hoursAgo: _h, daysAgo: _d),
);
String _m(int n) => '${n}m';
String _h(int n) => '${n}h';
String _d(int n) => '${n}d';

// STEP 3 gate — the conversation-row lead-dot mapping. The row itself is a plain AnRow (verified
// visually in the gallery's Chat category); this pins the precedence that picks WHICH dot:
// generating > awaiting > unread > archived > none.

Conversation _c({bool generating = false, bool awaiting = false, bool unread = false, bool archived = false}) {
  final t = DateTime.utc(2026, 6, 26);
  return Conversation(
    id: 'cv_1',
    title: 't',
    createdAt: t,
    updatedAt: t,
    lastMessageAt: t,
    isGenerating: generating,
    awaitingInput: awaiting,
    hasUnread: unread,
    archived: archived,
  );
}

void main() {
  test('a plain active thread has no dot', () {
    expect(conversationDot(_c()), isNull);
  });

  test('generating → run (blue), the highest precedence', () {
    expect(conversationDot(_c(generating: true)), AnStatus.run);
    // wins even when every flag is set at once
    expect(conversationDot(_c(generating: true, awaiting: true, unread: true, archived: true)), AnStatus.run);
  });

  test('awaiting input → wait (amber), over unread + archived', () {
    expect(conversationDot(_c(awaiting: true)), AnStatus.wait);
    expect(conversationDot(_c(awaiting: true, unread: true, archived: true)), AnStatus.wait);
  });

  test('unread → done (green), over archived', () {
    expect(conversationDot(_c(unread: true)), AnStatus.done);
    expect(conversationDot(_c(unread: true, archived: true)), AnStatus.done);
  });

  test('archived → idle (gray marker), the lowest', () {
    expect(conversationDot(_c(archived: true)), AnStatus.idle);
  });

  group('conversationTimeLabel', () {
    String label(DateTime at) => conversationTimeLabel(at, _now, _timeStrings);
    test('< 1 min → just now', () => expect(label(_now), 'now'));
    test('< 60 min → N min', () => expect(label(_now.subtract(const Duration(minutes: 5))), '5m'));
    test('same day, hours → N hr', () => expect(label(DateTime(2026, 6, 26, 9)), '3h'));
    test('previous day → yesterday', () => expect(label(DateTime(2026, 6, 25, 9)), 'yest'));
    test('2–7 days → N days', () => expect(label(DateTime(2026, 6, 23, 9)), '3d'));
    test('> 7 days → numeric y/m/d', () => expect(label(DateTime(2026, 5, 27, 9)), '2026/5/27'));
  });

  group('buildConversationRailModel', () {
    test('two icon section heads (Pinned + Recents), counts, server order within each', () {
      final rows = [
        _cAt('cv_pin', DateTime(2026, 6, 20, 9), pinned: true),
        _cAt('cv_a', DateTime(2026, 6, 26, 9)),
        _cAt('cv_b', DateTime(2026, 6, 1, 9)), // old, but no time bucketing → still Recents
      ];
      final types = buildConversationRailModel(rows, now: _now, labels: _labels).groups.single.types;
      expect(types.map((t) => t.label), ['PINNED', 'RECENTS']);
      expect(types.map((t) => t.count), [1, 2]);
      expect(types.every((t) => t.icon != null), isTrue); // both sections are icon'd (entities head style)
      expect(types.first.rows.single.id, 'cv_pin');
      expect(types[1].rows.map((r) => r.id), ['cv_a', 'cv_b']); // recents keep server order
      // each row still carries its own relative-time meta (>7 days → a numeric date).
      expect(types[1].rows.last.meta, '2026/6/1');
    });

    test('no pinned → only the Recents section', () {
      final types =
          buildConversationRailModel([_cAt('cv_a', _now)], now: _now, labels: _labels).groups.single.types;
      expect(types.map((t) => t.label), ['RECENTS']);
    });

    test('showCount/showTime off → section counts and row time meta are null (⚙ toggles)', () {
      final rows = [_cAt('cv_pin', _now, pinned: true), _cAt('cv_a', _now)];
      final types = buildConversationRailModel(rows,
              now: _now, labels: _labels, showCount: false, showTime: false)
          .groups
          .single
          .types;
      expect(types.every((t) => t.count == null), isTrue); // no count badge on the heads
      expect(types.expand((t) => t.rows).every((r) => r.meta == null), isTrue); // no relative time on rows
    });
  });
}
