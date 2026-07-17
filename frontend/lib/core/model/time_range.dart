/// The page-level time-range model behind [AnTimeRangePicker] (WRK-069 主页重建拍板 0717): a range
/// is EITHER a live preset ("last 7 days" — re-resolved against a fresh `now` at every fetch, never
/// stored as instants: freezing a relative range is the EUI #4026 bug) OR a frozen absolute pair.
/// Sealed two-type, no third state — a query either slides with now or it doesn't.
///
/// Absolute ranges store the user's INCLUSIVE minute-grain wall-clock picks verbatim (what the
/// capsule re-displays must round-trip byte-for-byte with what the form parses — Grafana #103524);
/// [resolveTimeRange] converts to the API's half-open `[from, to)` by pushing `to` one minute past
/// the inclusive end, so a run at 23:59:30 lands inside a "…– 23:59" pick.
///
/// 页级时间范围模型（AnTimeRangePicker 之骨，0717 拍板）：范围**要么**是活预设（「近 7 天」——每次取数
/// 用新鲜 now 现解析、绝不存解析结果：冻结相对范围是 EUI #4026 真 bug），**要么**是冻结的绝对两端。
/// sealed 两型、无第三态。绝对范围逐字存用户**闭区间分钟粒度**的墙钟选择（胶囊回显必须与表单解析逐字节
/// 往返——Grafana #103524）；resolveTimeRange 把闭端 `to` 推后一分钟转成 API 的半开 `[from, to)`，
/// 「…– 23:59」因此含住 23:59:30 的 run。
library;

/// The quick presets — a closed set, each a LIVE look-back window except [all].
/// 快速预设——封闭集，除 all 外均为活的回看窗。
enum AnTimePreset { today, h24, d7, d30, all }

sealed class AnTimeRange {
  const AnTimeRange();
}

/// A live relative window; resolves against `now` at query time. 活的相对窗，取数时现解析。
class AnPresetRange extends AnTimeRange {
  const AnPresetRange(this.preset);

  final AnTimePreset preset;

  @override
  bool operator ==(Object other) => other is AnPresetRange && other.preset == preset;
  @override
  int get hashCode => preset.hashCode;
}

/// A frozen absolute pair — the user's inclusive minute-grain wall-clock picks, local time.
/// 冻结的绝对两端——用户闭区间分钟粒度的本地墙钟选择。
class AnAbsoluteRange extends AnTimeRange {
  const AnAbsoluteRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) => other is AnAbsoluteRange && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
}

/// Resolve a range to the API's half-open `[from, to)` bounds (null = unbounded on that side).
/// Presets re-resolve every call — pass a fresh `now`. "Today" anchors at local midnight via
/// constructor normalization (DST-safe); duration presets are true look-back durations.
/// 解析成 API 半开 `[from, to)`（null=该侧无界）。预设逐次现解析——传新鲜 now。「今天」经构造器归一锚到
/// 本地零点（DST 安全）；时长预设是真回看时长。
({DateTime? from, DateTime? to}) resolveTimeRange(AnTimeRange range, DateTime now) {
  switch (range) {
    case AnPresetRange(:final preset):
      switch (preset) {
        case AnTimePreset.today:
          return (from: DateTime(now.year, now.month, now.day), to: null);
        case AnTimePreset.h24:
          return (from: now.subtract(const Duration(hours: 24)), to: null);
        case AnTimePreset.d7:
          return (from: now.subtract(const Duration(days: 7)), to: null);
        case AnTimePreset.d30:
          return (from: now.subtract(const Duration(days: 30)), to: null);
        case AnTimePreset.all:
          return (from: null, to: null);
      }
    case AnAbsoluteRange(:final from, :final to):
      // Inclusive minute-grain end → exclusive bound one minute later. 闭分钟端 → 后推一分钟成开端。
      return (from: from, to: to.add(const Duration(minutes: 1)));
  }
}

// ── calendar month math ───────────────────────────────────────────────────────
// Constructor normalization ONLY — never Duration(days: 30) arithmetic, which drifts the wall
// clock across DST boundaries (dart-lang/sdk#44014). 只用构造器归一化——绝不 Duration 天数算术
// （跨 DST 漂墙钟）。

/// First day of the month [delta] months away from [month]'s month. 相距 delta 个月的月首。
DateTime addMonths(DateTime month, int delta) => DateTime(month.year, month.month + delta, 1);

/// Days in [month]'s month — day 0 of the NEXT month normalizes to this month's last day.
/// 该月天数——下月第 0 天归一化为本月末日。
int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// The 42 dates of a fixed 6-row Monday-first grid containing [month] — constant height across
/// months, so a popover's Apply button never jumps (the DayPicker `fixedWeeks` convention).
/// 含该月的恒 6 行周一起手 42 格——跨月高度恒定，弹层里的应用按钮不跳位。
List<DateTime> monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final leading = (first.weekday - DateTime.monday + 7) % 7;
  return [
    for (var i = 0; i < 42; i++) DateTime(month.year, month.month, 1 - leading + i),
  ];
}

/// Same calendar date (ignoring time). 同一天（忽略时刻）。
bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Date-only value (local midnight). 只取日期（本地零点）。
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ── lenient form parsing ──────────────────────────────────────────────────────
// Multi-format tolerance is the settled convention (EUI absolute tab); reject only what no format
// matches, and only at blur/apply — never mid-keystroke. 宽容解析是定式；只拒所有格式都不认的，
// 且只在失焦/应用时判——绝不在打字途中。

/// Parse a date input: `2026-07-01`, `2026/7/1`, `2026.7.1`. Rejects impossible dates (2026-02-31
/// would silently normalize to March — a lie). null = unparseable. 解析日期输入；不可能的日期拒收
/// （构造器会把 2-31 静默归一成 3 月——那是撒谎）。
DateTime? parseDateInput(String raw) {
  final m = RegExp(r'^\s*(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\s*$').firstMatch(raw);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1) return null;
  if (d > daysInMonth(DateTime(y, mo))) return null;
  return DateTime(y, mo, d);
}
