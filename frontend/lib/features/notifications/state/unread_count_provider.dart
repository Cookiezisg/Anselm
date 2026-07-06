import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_providers.dart';

/// The unread-badge count on the left-island bell. THE source of truth is the backend `unread-count`
/// COUNT — mark-read has NO SSE echo and a stream frame can never be trusted to mean "+1" (post-N0 the
/// notifications stream carries frame-only echoes indistinguishable from inbox rows), so this notifier
/// never increments off a frame: it debounce-REFETCHES the authoritative count on an inbox-worthy tick,
/// refetches immediately on a 410 resync, and drops the badge optimistically after a local mark-read
/// (reconciled by the next refetch). This is the deliberate, correct alternative to fragile +1/−1.
///
/// 左岛铃的未读徽标数。真相是后端 unread-count 的 COUNT——mark-read 无 SSE 回声、且一帧绝不能当「+1」
/// (N0 后流上有与收件箱行不可分的仅帧回声),故本 notifier 从不据帧自增:inbox-worthy tick 去抖**重读**权威
/// 计数、410 立即重读、本地 mark-read 后乐观扣减(下次 refetch 对账)。这是脆弱 +1/−1 的刻意正确替代。
class UnreadCountNotifier extends AsyncNotifier<int> {
  Timer? _debounce;

  @override
  Future<int> build() async {
    final repo = ref.watch(notificationRepositoryProvider);
    final debounce = ref.watch(notificationDebounceProvider);

    // A per-frame nudge → debounced refetch (only inbox-worthy durable ticks; a burst coalesces to one
    // COUNT). 逐帧 nudge → 去抖 refetch(仅 inbox-worthy durable tick;一簇合并成一次 COUNT)。
    final sigSub = repo.signals().listen((s) {
      if (s.durable && s.inboxCandidate) {
        _debounce?.cancel();
        _debounce = Timer(debounce, _refresh);
      }
    });
    // 410: the replay ring evicted past our cursor → refetch now (no debounce). 410 立即重读。
    final resyncSub = repo.resync().listen((_) => _refresh());

    ref.onDispose(() {
      _debounce?.cancel();
      sigSub.cancel();
      resyncSub.cancel();
    });

    return repo.unreadCount();
  }

  Future<void> _refresh() async {
    try {
      final n = await ref.read(notificationRepositoryProvider).unreadCount();
      if (ref.mounted) state = AsyncData(n);
    } catch (_) {
      // Keep the last known count on a transient read error; the next tick reconciles. 读错保留旧值。
    }
  }

  /// Optimistically drop the badge by one after a successful single mark-read (no SSE echo to wait for).
  /// 单条 mark-read 成功后乐观扣一(无 SSE 回声可等)。
  void markedOneRead() {
    final cur = state.value;
    if (cur != null && cur > 0) state = AsyncData(cur - 1);
  }

  /// Optimistically zero the badge after a successful mark-all-read. mark-all 后乐观归零。
  void markedAllRead() {
    if (state.value != null) state = const AsyncData(0);
  }

  /// Force an authoritative re-read (e.g. after the tray opens). 强制权威重读(如托盘打开后)。
  Future<void> refresh() => _refresh();
}

/// The unread-badge count. keepAlive by default (app-lifetime — the bell is always mounted). 未读徽标数。
final unreadCountProvider =
    AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
