/// Shared numeric display formatters. 共享数字显示格式器。
library;

import 'package:intl/intl.dart';

/// Formats a count for a human-facing compact label using the active locale's conventions.
/// 用当前 locale 的约定把计数格式化为适合人读的紧凑标签。
String fmtCompactCount(int value, {required String locale}) {
  return NumberFormat.compact(locale: locale).format(value);
}
