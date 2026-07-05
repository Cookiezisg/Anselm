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
}
