import 'package:anselm/features/notifications/ui/notification_tray.dart';
import 'package:flutter_test/flutter_test.dart';

// NotificationDayBuckets — the SINGLE source both the tray's time-bucketing and each group's bulk-mark
// window derive from. `now` is injected, so these run deterministically. The load-bearing property is the
// INVARIANT that bucketOf and windowOf agree at every day edge: a row's group and the window its ⋯ sweeps
// can never disagree (the whole point of one分界源). That invariant is time-zone independent — bucketOf and
// windowOf both key off the same LOCAL midnights, so the tests assert relationships, not wall-clock offsets.

void main() {
  // Local 3pm on 2026-07-20 → todayStart = local 2026-07-20 00:00, yesterdayStart = local 2026-07-19 00:00.
  final days = NotificationDayBuckets(DateTime(2026, 7, 20, 15));

  test(
    'bucketOf classifies a LOCAL createdAt into today / yesterday / earlier',
    () {
      expect(days.bucketOf(DateTime(2026, 7, 20, 9)), 0); // today
      expect(
        days.bucketOf(DateTime(2026, 7, 20, 0, 0)),
        0,
      ); // today midnight (inclusive floor)
      expect(days.bucketOf(DateTime(2026, 7, 19, 10)), 1); // yesterday
      expect(
        days.bucketOf(DateTime(2026, 7, 19, 0, 0)),
        1,
      ); // yesterday midnight (inclusive floor)
      expect(
        days.bucketOf(DateTime(2026, 7, 19, 23, 59)),
        1,
      ); // last moment of yesterday
      expect(days.bucketOf(DateTime(2026, 7, 18, 23, 59)), 2); // earlier
    },
  );

  test(
    'windowOf maps each bucket to its half-open [after, before) UTC window',
    () {
      final todayStartUtc = DateTime(2026, 7, 20).toUtc();
      final yesterdayStartUtc = DateTime(2026, 7, 19).toUtc();

      // today = [今日零点, ∞)
      expect(days.windowOf(0).after, todayStartUtc);
      expect(days.windowOf(0).before, isNull);
      // yesterday = [昨日零点, 今日零点)
      expect(days.windowOf(1).after, yesterdayStartUtc);
      expect(days.windowOf(1).before, todayStartUtc);
      // earlier = (-∞, 昨日零点)
      expect(days.windowOf(2).after, isNull);
      expect(days.windowOf(2).before, yesterdayStartUtc);
    },
  );

  test(
    'INVARIANT: bucketOf(d) agrees with windowOf — d lands in exactly its own bucket window',
    () {
      // A spread of local instants across the boundaries (including the two exclusive/inclusive edges).
      final cases = <DateTime>[
        DateTime(2026, 7, 20, 15), // today
        DateTime(2026, 7, 20, 0, 0), // today floor (inclusive)
        DateTime(
          2026,
          7,
          19,
          23,
          59,
          59,
        ), // yesterday, just under today's floor
        DateTime(2026, 7, 19, 12), // yesterday
        DateTime(2026, 7, 19, 0, 0), // yesterday floor (inclusive)
        DateTime(
          2026,
          7,
          18,
          23,
          59,
          59,
        ), // earlier, just under yesterday's floor
        DateTime(2025, 1, 1), // ancient earlier
      ];
      for (final d in cases) {
        final b = days.bucketOf(d);
        // The row's OWN bucket window contains it; the other two do NOT — the partition is exact, so a group's
        // ⋯ action sweeps precisely the rows shown under that group.
        for (final other in const [0, 1, 2]) {
          expect(
            days.windowOf(other).contains(d),
            other == b,
            reason:
                'instant $d is bucket $b; windowOf($other).contains must be ${other == b}',
          );
        }
      }
    },
  );

  test(
    'the today floor is INCLUSIVE while the yesterday ceiling is EXCLUSIVE (half-open, no gap/overlap)',
    () {
      final todayMidnight = DateTime(
        2026,
        7,
        20,
      ); // exactly today's floor / yesterday's ceiling
      expect(days.bucketOf(todayMidnight), 0); // classified as today
      expect(
        days.windowOf(0).contains(todayMidnight),
        isTrue,
      ); // today window includes its floor
      expect(
        days.windowOf(1).contains(todayMidnight),
        isFalse,
      ); // yesterday window excludes its ceiling
    },
  );
}
