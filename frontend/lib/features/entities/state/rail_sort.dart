import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entity_row.dart';

/// How the rail orders rows within each kind section — aligned with the chat rail's three sorts:
/// [recent] = most-recently-active (updatedAt desc, the working-set order, default), [created] =
/// most-recently-created (createdAt desc), [name] = A→Z. A transient view preference (not server state),
/// so a plain Notifier; ordering is client-side over the loaded rows.
///
/// 行在各 kind 段内的排序——与 chat rail 三档对齐:recent=最近活跃(updatedAt 降序,默认)、created=最近创建(createdAt 降序)、
/// name=A→Z。瞬时视图偏好;客户端对已载行排序。
enum RailSort { recent, created, name }

class RailSortNotifier extends Notifier<RailSort> {
  @override
  RailSort build() => RailSort.recent;

  void set(RailSort sort) => state = sort;
}

final railSortProvider = NotifierProvider<RailSortNotifier, RailSort>(RailSortNotifier.new);

/// Whether the rail shows the per-kind-section count (函数 ··· 4) — the ⚙ "show counts" toggle, default
/// ON. A transient view pref (mirrors the chat rail's showGroupCountProvider).
/// rail 是否显每 kind 段计数(函数···4)——⚙「显示分组计数」开关,默认开(镜像 chat 的 showGroupCountProvider)。
class RailShowCountNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final railShowCountProvider = NotifierProvider<RailShowCountNotifier, bool>(RailShowCountNotifier.new);

/// Order a kind's rows by [sort], stably (name tiebreak keeps it deterministic frame to frame, so the
/// list never jitters on equal keys). Returns a new list; never mutates the input. 稳定排序(name 兜底)。
List<EntityRow> sortRows(List<EntityRow> rows, RailSort sort) {
  final out = [...rows];
  switch (sort) {
    case RailSort.recent:
      out.sort((a, b) {
        final byTime = b.updatedAt.compareTo(a.updatedAt); // newest first
        return byTime != 0 ? byTime : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case RailSort.created:
      out.sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt); // newest first
        return byTime != 0 ? byTime : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case RailSort.name:
      out.sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
  }
  return out;
}
