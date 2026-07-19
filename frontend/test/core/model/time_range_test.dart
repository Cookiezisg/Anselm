import 'package:anselm/core/model/time_range.dart';
import 'package:flutter_test/flutter_test.dart';

// The page-level time-range model: preset resolution (live, half-open), absolute round-trip
// (inclusive minute-grain → exclusive API bound), the fixed 6-row month grid, constructor-only
// month math, and the lenient-but-honest form parsers.
// 页级时间范围模型:预设现解析(活/半开)、绝对往返(闭分钟 → 开 API 端)、恒 6 行月网格、构造器月算术、
// 宽容但诚实的表单解析。
void main() {
  final now = DateTime(2026, 7, 17, 14, 30);

  group('resolveTimeRange', () {
    test('today anchors at LOCAL midnight, unbounded end', () {
      final r = resolveTimeRange(const AnPresetRange(AnTimePreset.today), now);
      expect(r.from, DateTime(2026, 7, 17));
      expect(r.to, isNull);
    });

    test('h24/d7/d30 are true look-back durations', () {
      expect(resolveTimeRange(const AnPresetRange(AnTimePreset.h24), now).from,
          now.subtract(const Duration(hours: 24)));
      expect(resolveTimeRange(const AnPresetRange(AnTimePreset.d7), now).from,
          now.subtract(const Duration(days: 7)));
      expect(resolveTimeRange(const AnPresetRange(AnTimePreset.d30), now).from,
          now.subtract(const Duration(days: 30)));
    });

    test('all is unbounded on both sides', () {
      final r = resolveTimeRange(const AnPresetRange(AnTimePreset.all), now);
      expect(r.from, isNull);
      expect(r.to, isNull);
    });

    test('absolute: inclusive minute-grain end becomes an exclusive bound ONE minute later — '
        'a 23:59:30 run lands inside a "… – 23:59" pick', () {
      final r = resolveTimeRange(
          AnAbsoluteRange(from: DateTime(2026, 6, 1, 9, 0), to: DateTime(2026, 6, 30, 23, 59)), now);
      expect(r.from, DateTime(2026, 6, 1, 9, 0));
      expect(r.to, DateTime(2026, 7, 1, 0, 0));
    });

    test('presets re-resolve against the now they are handed — a live expression, never frozen', () {
      final later = now.add(const Duration(hours: 3));
      final a = resolveTimeRange(const AnPresetRange(AnTimePreset.h24), now).from!;
      final b = resolveTimeRange(const AnPresetRange(AnTimePreset.h24), later).from!;
      expect(b.difference(a), const Duration(hours: 3));
    });
  });

  group('range equality (preset highlight relies on it)', () {
    test('presets compare by preset, absolutes by both endpoints', () {
      expect(const AnPresetRange(AnTimePreset.d7), const AnPresetRange(AnTimePreset.d7));
      expect(const AnPresetRange(AnTimePreset.d7), isNot(const AnPresetRange(AnTimePreset.d30)));
      expect(AnAbsoluteRange(from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 2)),
          AnAbsoluteRange(from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 2)));
      expect(AnAbsoluteRange(from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 2)),
          isNot(AnAbsoluteRange(from: DateTime(2026, 1, 1), to: DateTime(2026, 1, 3))));
    });
  });

  group('month grid', () {
    test('always 42 cells, Monday first, month fully contained', () {
      final days = monthGridDays(DateTime(2026, 7, 1)); // Jul 2026: the 1st is a Wednesday 周三
      expect(days.length, 42);
      expect(days.first.weekday, DateTime.monday);
      expect(days.first, DateTime(2026, 6, 29)); // two leading June days 前导两天
      expect(days.contains(DateTime(2026, 7, 1)), isTrue);
      expect(days.contains(DateTime(2026, 7, 31)), isTrue);
    });

    test('a month starting on Monday still renders 6 rows (fixed weeks — zero height jump)', () {
      final days = monthGridDays(DateTime(2026, 6, 1)); // Jun 2026: the 1st IS a Monday 周一起手
      expect(days.length, 42);
      expect(days.first, DateTime(2026, 6, 1));
      expect(days.last, DateTime(2026, 7, 12)); // trailing July fills row 6 尾行补七月
    });

    test('daysInMonth: leap February and the 30/31 walk', () {
      expect(daysInMonth(DateTime(2026, 2, 1)), 28);
      expect(daysInMonth(DateTime(2028, 2, 1)), 29);
      expect(daysInMonth(DateTime(2026, 4, 1)), 30);
      expect(daysInMonth(DateTime(2026, 12, 1)), 31);
    });

    test('addMonths normalizes across year edges', () {
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 1));
      expect(addMonths(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 1));
    });
  });

  // Form parsing is GONE entirely (0718 三列拍板:日期归日历、时刻归滚轮——无可打字之物,
  // parseDateInput/parseTimeInput 双双退役,草稿构造即合法). 表单解析整体退役。

  group('day helpers', () {
    test('isSameDay ignores time; dateOnly strips to local midnight', () {
      expect(isSameDay(DateTime(2026, 7, 17, 23, 59), DateTime(2026, 7, 17, 0, 1)), isTrue);
      expect(isSameDay(DateTime(2026, 7, 17), DateTime(2026, 7, 18)), isFalse);
      expect(dateOnly(DateTime(2026, 7, 17, 23, 59)), DateTime(2026, 7, 17));
    });
  });
}
