import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/memory.dart';
import '../data/settings_repository.dart';

/// The memory roster + mutations (WRK-062 S4-⑥). One unfiltered list — the pinned filter is a UI
/// projection (the set is bounded, N4-exempt). Pin/unpin PATCHes the single row in place from the
/// authoritative response (no full refetch for a one-bit flip).
///
/// 记忆名册与变更(S4-⑥)。一份全量列表,pinned 过滤是 UI 投影(有界集)。pin/unpin 用权威响应就地补
/// 单行(一比特翻转不整表重拉)。
class MemoriesController extends AsyncNotifier<List<Memory>> {
  @override
  Future<List<Memory>> build() => ref.watch(settingsRepositoryProvider).listMemories();

  Future<Memory> put(String name,
      {required String description, required String content}) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .putMemory(name, description: description, content: content);
    await _refresh();
    return row;
  }

  Future<void> setPinned(String name, bool pinned) async {
    final row =
        await ref.read(settingsRepositoryProvider).pinMemory(name, pinned: pinned);
    final cur = state.value;
    if (cur != null) {
      state = AsyncData([for (final m in cur) m.name == name ? row : m]);
    }
  }

  Future<void> remove(String name) async {
    await ref.read(settingsRepositoryProvider).deleteMemory(name);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = AsyncData(await ref.read(settingsRepositoryProvider).listMemories());
  }
}

final memoriesProvider =
    AsyncNotifierProvider<MemoriesController, List<Memory>>(MemoriesController.new);
