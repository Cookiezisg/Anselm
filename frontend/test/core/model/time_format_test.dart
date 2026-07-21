import 'package:anselm/core/model/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

// fmtWaited — the coarse elapsed-duration label (R6: 时长/等待 = 相对 duration), locale-neutral units.
// 粗粒度等待时长,locale 中性单位。

void main() {
  test('coarse buckets: <1m / m / h / d / w', () {
    expect(fmtWaited(const Duration(seconds: 30)), '<1m');
    expect(fmtWaited(const Duration(minutes: 5)), '5m');
    expect(fmtWaited(const Duration(minutes: 59)), '59m');
    expect(fmtWaited(const Duration(hours: 2)), '2h');
    expect(fmtWaited(const Duration(hours: 23)), '23h');
    expect(fmtWaited(const Duration(days: 3)), '3d');
    expect(fmtWaited(const Duration(days: 6)), '6d');
    expect(fmtWaited(const Duration(days: 14)), '2w');
  });

  test('negative / zero (clock skew) collapses to <1m', () {
    expect(fmtWaited(Duration.zero), '<1m');
    expect(fmtWaited(const Duration(seconds: -10)), '<1m');
  });

  test('fmtWaitedSince computes from a fixed now', () {
    final now = DateTime.utc(2026, 7, 6, 12);
    expect(fmtWaitedSince(DateTime.utc(2026, 7, 6, 10), now: now), '2h');
    expect(fmtWaitedSince(DateTime.utc(2026, 7, 3, 12), now: now), '3d');
    expect(fmtWaitedSince(null, now: now), '');
  });

  // fmtRelativeDay — the coarse calendar-day relative label (documents' «last edited» glance). Injected
  // strings keep it pure. 粗粒度日相对(文档速览带),注入串保纯。
  group('fmtRelativeDay', () {
    String rel(DateTime at, DateTime now) => fmtRelativeDay(
      at,
      now,
      today: 'today',
      yesterday: 'yesterday',
      daysAgo: (n) => '$n days ago',
    );

    final now = DateTime(2026, 7, 6, 12); // local wall-clock 本地墙钟

    test('same calendar day → today (sub-day precision is noise)', () {
      expect(rel(DateTime(2026, 7, 6, 8), now), 'today');
      expect(rel(DateTime(2026, 7, 6, 0, 1), now), 'today');
      expect(rel(now, now), 'today');
    });

    test('yesterday / N days ago within the week', () {
      expect(rel(DateTime(2026, 7, 5, 23), now), 'yesterday');
      expect(rel(DateTime(2026, 7, 3, 12), now), '3 days ago');
      expect(rel(DateTime(2026, 6, 29, 12), now), '7 days ago');
    });

    test('older than a week → numeric y/m/d', () {
      expect(rel(DateTime(2026, 6, 28, 12), now), '2026/6/28');
      expect(rel(DateTime(2025, 1, 5, 12), now), '2025/1/5');
    });

    test('a future skew (clock drift) collapses to today', () {
      expect(rel(DateTime(2026, 7, 6, 20), now), 'today');
      expect(rel(DateTime(2026, 7, 8, 12), now), 'today'); // days < 0 → today
    });
  });
}
