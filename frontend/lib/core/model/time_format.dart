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
