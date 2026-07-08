import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/workspace.dart';
import '../../../core/runtime.dart';
import '../data/settings_repository.dart';

/// The workspace roster + its mutations (WRK-062 S3). Every mutation refreshes from the backend;
/// renaming the ACTIVE workspace also refreshes the sidebar-footer name. Deleting never touches the
/// selection — the panel only offers delete on non-active rows (the backend guards the last one).
///
/// workspace 名册与变更(S3)。每次变更后重拉;改名当前 workspace 时同步底栏名。删除不碰选区——
/// 面板只对非当前行给删除(后端守最后一个)。
class WorkspacesController extends AsyncNotifier<List<Workspace>> {
  @override
  Future<List<Workspace>> build() => ref.watch(settingsRepositoryProvider).listWorkspaces();

  Future<Workspace> create({required String name, String? avatarColor}) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .createWorkspace(name: name, avatarColor: avatarColor);
    await _refresh();
    return row;
  }

  Future<Workspace> rename(String id, String name) async {
    final row =
        await ref.read(settingsRepositoryProvider).patchWorkspaceById(id, name: name);
    if (ref.read(activeWorkspaceProvider) == id) {
      ref.read(activeWorkspaceNameProvider.notifier).set(row.name); // 底栏名同步
    }
    await _refresh();
    return row;
  }

  Future<Workspace> recolor(String id, String color) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .patchWorkspaceById(id, avatarColor: color);
    await _refresh();
    return row;
  }

  Future<void> remove(String id) async {
    await ref.read(settingsRepositoryProvider).deleteWorkspace(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = AsyncData(await ref.read(settingsRepositoryProvider).listWorkspaces());
  }
}

final workspacesProvider =
    AsyncNotifierProvider<WorkspacesController, List<Workspace>>(WorkspacesController.new);

/// The delete confirmation's real numbers — fetched when the danger zone opens, autoDispose (stats
/// go stale the moment work continues). 删除确认真数字;危险区展开时取,autoDispose(数字随工作即刻过期)。
final workspaceStatsProvider = FutureProvider.autoDispose.family<WorkspaceStats, String>(
    (ref, id) => ref.watch(settingsRepositoryProvider).workspaceStats(id));

/// The backend build version (About). 后端构建版本(关于页)。
final backendVersionProvider =
    FutureProvider<String>((ref) => ref.watch(settingsRepositoryProvider).backendVersion());
