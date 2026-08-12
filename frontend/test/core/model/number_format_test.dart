import 'package:anselm/core/model/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'compact counts use locale-aware readable units and preserve small values',
    () {
      expect(fmtCompactCount(0, locale: 'en'), '0');
      expect(fmtCompactCount(999, locale: 'en'), '999');
      expect(fmtCompactCount(1000, locale: 'en'), '1K');
      expect(fmtCompactCount(12345678, locale: 'en'), '12.3M');
      expect(fmtCompactCount(1000000000, locale: 'en'), '1B');
      expect(fmtCompactCount(1000000000, locale: 'zh-CN'), '10亿');
    },
  );
}
