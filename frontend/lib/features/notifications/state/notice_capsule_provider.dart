import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One queued chrome-band notice. [key] doubles as the widget key (a fresh capsule per notice) and
/// the dedup identity upstream. 一条排队的顶带通知;key 兼 widget key 与上游去重身份。
@immutable
class CapsuleNotice {
  const CapsuleNotice({
    required this.key,
    required this.text,
    this.icon,
    this.danger = true,
    this.location,
  });

  final String key;
  final String text;
  final IconData? icon;
  final bool danger;

  /// Deep-link location (router path), null = not navigable. 深链路径,null=不可导航。
  final String? location;
}

/// The band-capsule queue — notices display ONE AT A TIME in arrival order (the dispatcher pushes,
/// the host shows `first` and pops on dismiss/tap). Bounded so an event storm can't build an unbounded
/// backlog: beyond [_cap] the OLDEST undisplayed entries drop — the tray/bell keep every row, the
/// capsule is just the messenger. 顶带胶囊队列:一次显示一条、到达序;有界防风暴(超上限丢最旧未显示条——
/// 托盘/铃保有全量,胶囊只是信使)。
class NoticeCapsuleQueue extends Notifier<List<CapsuleNotice>> {
  static const int _cap = 5;

  @override
  List<CapsuleNotice> build() => const [];

  void push(CapsuleNotice n) {
    final next = [...state, n];
    // Keep the currently-showing head; trim overflow from just behind it. 保住在显头条,从其后裁溢出。
    if (next.length > _cap) {
      next.removeRange(1, next.length - _cap + 1);
    }
    state = next;
  }

  /// Remove the currently-showing notice (dismiss/tap teardown). 移除在显条(收场)。
  void pop() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }
}

final noticeCapsuleProvider =
    NotifierProvider<NoticeCapsuleQueue, List<CapsuleNotice>>(NoticeCapsuleQueue.new);
