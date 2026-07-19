/// The ONE human-readable byte formatter — B / KB / MB / GB, one decimal. Foundation-level because
/// two features grew their own copies that already disagreed (documents dropped the GB tier — 2GB
/// rendered "2048.0 MB" — and used conditional decimals vs chat's fixed one): the same size must
/// read identically everywhere (原则 #8 — strengthen the foundation, don't re-copy in modules).
///
/// 唯一的人类可读字节格式化(B/KB/MB/GB,一位小数)。放地基:两个 feature 各长了一份且已经分叉
/// (documents 缺 GB 档——2GB 渲成「2048.0 MB」,小数规则也不同)——同一大小必须处处同读(原则 #8:
/// 强化地基、不在模块内重抄)。
library;

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
