import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/memory.dart';
import '../../notifications/data/notification_providers.dart';
import '../data/settings_repository.dart';

/// The memory roster + mutations (WRK-062 S4-⑥). One unfiltered list — the pinned filter is a UI
/// projection (the set is bounded, N4-exempt). Pin/unpin PATCHes the single row in place from the
/// authoritative response (no full refetch for a one-bit flip).
///
/// 记忆名册与变更(S4-⑥)。一份全量列表,pinned 过滤是 UI 投影(有界集)。pin/unpin 用权威响应就地补
/// 单行(一比特翻转不整表重拉)。
class MemoriesController extends AsyncNotifier<List<Memory>> {
  int _reconcileGeneration = 0;

  @override
  Future<List<Memory>> build() {
    final settings = ref.watch(settingsRepositoryProvider);
    final notifications = ref.watch(notificationRepositoryProvider);
    final signalSub = notifications.signals().listen((signal) {
      if (signal.durable && _isMemorySignal(signal.type)) {
        _reconcileFromSignal();
      }
    });
    ref.onDispose(signalSub.cancel);
    // A 410 means memory lifecycle signals were dropped. Re-read the same durable roster rather than
    // leaving the settings panel silently stale for the rest of the session. 410 表示生命周期帧已丢失，
    // 必须重读耐久名册，不能让设置页在本会话余下时间静默陈旧。
    final resyncSub = notifications.resync().listen((_) {
      _reconcileFromSignal();
    });
    ref.onDispose(resyncSub.cancel);
    return settings.listMemories();
  }

  static bool _isMemorySignal(String type) =>
      type == 'memory.created' ||
      type == 'memory.updated' ||
      type == 'memory.deleted';

  /// Reconcile in place so an already-settled roster does not pass through a second provider build.
  /// The generation guard keeps an older REST response from overwriting a newer signal's result.
  /// 就地对账，避免已稳定名册再走一轮 provider 构建；代数闸防旧请求覆盖新信号的结果。
  void _reconcileFromSignal() {
    final generation = ++_reconcileGeneration;
    unawaited(_loadRoster(generation));
  }

  Future<void> _loadRoster(int generation) async {
    try {
      final rows = await ref.read(settingsRepositoryProvider).listMemories();
      if (!ref.mounted || generation != _reconcileGeneration) return;
      state = AsyncData(rows);
    } catch (error, stackTrace) {
      if (!ref.mounted || generation != _reconcileGeneration) return;
      state = AsyncError(error, stackTrace);
    }
  }

  Future<Memory> put(
    String name, {
    required String description,
    required String content,
    bool pinned = false,
  }) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .putMemory(
          name,
          description: description,
          content: content,
          pinned: pinned,
        );
    await _refresh();
    return row;
  }

  Future<void> setPinned(String name, bool pinned) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .pinMemory(name, pinned: pinned);
    final cur = state.value;
    if (cur != null) {
      state = AsyncData([for (final m in cur) m.name == name ? row : m]);
    }
  }

  Future<void> remove(String name) async {
    await ref.read(settingsRepositoryProvider).deleteMemory(name);
    await _refresh();
  }

  /// Re-read the roster in place (no loading flash) — mirrors [McpServersController.refresh]; used
  /// after an out-of-band roster change (e.g. the capture harness clearing the seed). 就地重取名册。
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).listMemories(),
    );
  }
}

final memoriesProvider =
    AsyncNotifierProvider<MemoriesController, List<Memory>>(
      MemoriesController.new,
    );
