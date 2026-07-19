import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/sandbox.dart';
import '../data/settings_repository.dart';

/// Sandbox state (WRK-062 S5-⑦). Runtimes + per-owner envs refetch on mutation; bootstrap health
/// and disk usage are read on open. 沙箱状态:变更即重取;引导健康/磁盘打开时取。
final sandboxBootstrapProvider = FutureProvider.autoDispose<SandboxBootstrap>(
    (ref) => ref.watch(settingsRepositoryProvider).sandboxBootstrap());

final sandboxAvailableProvider = FutureProvider<List<RuntimeAvailability>>(
    (ref) => ref.watch(settingsRepositoryProvider).sandboxAvailable());

class SandboxRuntimesController extends AsyncNotifier<List<SandboxRuntime>> {
  @override
  Future<List<SandboxRuntime>> build() => ref.watch(settingsRepositoryProvider).sandboxRuntimes();

  Future<void> install({required String kind, required String version}) async {
    await ref.read(settingsRepositoryProvider).installRuntime(kind: kind, version: version);
    await _refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(settingsRepositoryProvider).deleteRuntime(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = AsyncData(await ref.read(settingsRepositoryProvider).sandboxRuntimes());
  }
}

final sandboxRuntimesProvider =
    AsyncNotifierProvider<SandboxRuntimesController, List<SandboxRuntime>>(
        SandboxRuntimesController.new);

/// Envs for one owner kind — the tab's data. 某 owner 的环境(tab 数据)。
final sandboxEnvsProvider = FutureProvider.autoDispose.family<List<SandboxEnv>, String>(
    (ref, ownerKind) => ref.watch(settingsRepositoryProvider).sandboxEnvs(ownerKind));
