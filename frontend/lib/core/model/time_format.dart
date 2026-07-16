/// Shared time formatters (core, cross-feature). 共享时间格式化(core,跨 feature)。
library;

/// A COARSE elapsed-duration label for "how long has this waited" — parked approvals, run waits (R6:
/// 时长/等待 = 相对 duration). Locale-neutral compact units (`<1m` / `5m` / `2h` / `3d` / `2w`), distinct
/// from the entity feature's precise execution timing (`fmtDuration`, `1.2s`/`2m 3s`). A negative /
/// zero duration (clock skew) collapses to `<1m`.
///
/// 粗粒度等待时长(停泊审批、run 等待,R6:时长/等待=相对 duration)。locale 中性紧凑单位,区别于实体侧
/// 精确执行计时;负/零(时钟偏移)归 `<1m`。
String fmtWaited(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return '<1m';
  if (s < 3600) return '${d.inMinutes}m';
  if (s < 86400) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${d.inDays ~/ 7}w';
}

/// [fmtWaited] of the elapsed time from [since] to [now] (defaults to wall-clock). null since → ''.
/// 从 since 到 now 的等待时长;now 默认墙钟。
String fmtWaitedSince(DateTime? since, {DateTime? now}) {
  if (since == null) return '';
  return fmtWaited((now ?? DateTime.now()).difference(since));
}

/// An ABSOLUTE compact timepoint `YYYY-MM-DD HH:MM` from an ISO-8601 string (R6: timepoints —
/// createdAt / updatedAt / mtime — render absolute, not relative; a settled card shows it statically,
/// never live-refreshing). Parsed in LOCAL time. Unparseable / empty → the raw string (never throws).
/// 绝对紧凑时点(R6:时点=绝对);本地时区解析;解析不了→原样返回(不抛)。
String fmtStamp(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return fmtDateTime(dt);
}

/// A local `YYYY-MM-DD HH:MM` wall-clock stamp from a [DateTime]. Shared so features stop growing their
/// own copies. 本地日期时间戳,供各 feature 共用(勿再各写一份)。
String fmtDateTime(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// A local `HH:MM:SS` wall clock — the SECOND-precision timepoint (WRK-069 S4). A run's gantt axis
/// and its bar hovers span seconds, where [fmtDateTime]'s minute grain would print the same string at
/// both ends of the ruler; the date is redundant there (the head already states the run's day).
/// 本地时分秒钟点(S4):run 的甘特轴与条 hover 是秒级跨度,分钟粒度会让刻度眉两端印出同一个字符串;
/// 日期在那里是冗余的(卷宗头已经说了是哪天)。
String fmtClock(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

/// A local `YYYY-MM-DD` date (no time). 本地日期(无时刻)。
String fmtDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

/// PRECISE execution elapsed — <1s → Nms; <60s → N.Ns; else NmSSs; hour-plus → «2h 5m». Upstreamed
/// from entities' entity_format (WRK-069 S3): the scheduler's run table and entities' cockpit speak
/// the SAME duration voice (features 互不依赖, so the one map lives in core).
/// 精确执行耗时(上收自 entities:scheduler 大表与驾驶舱同一口径,features 互不依赖故归 core)。
String fmtDuration(Duration d) {
  final ms = d.inMilliseconds;
  if (ms < 1000) return '${ms}ms';
  // 59.95–59.999s would round-format to "60.0s" — roll into the minutes tier instead.
  // 59.95s 会被格式化成「60.0s」——滚进分钟档。
  if (ms < 59950) return '${(ms / 1000).toStringAsFixed(1)}s';
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  // Hour-plus runs read as hours, not raw minutes ("2h 5m", never "125m 3s") — durable workflows
  // legitimately run that long. 小时级显示小时档(durable 工作流真会跑这么久)。
  if (m >= 60) return '${d.inHours}h ${m % 60}m';
  return '${m}m ${s}s';
}
