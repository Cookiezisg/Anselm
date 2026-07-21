import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/workspace.dart';
import '../data/settings_repository.dart';

/// The active workspace's preference row — fetched when a settings panel needs it, PATCHed
/// optimistically (value flips now; a failed write ROLLS BACK and rethrows so the row can toast).
/// Instant-apply model: no save buttons, the control writes.
/// 当前 workspace 偏好行——面板需要时取,乐观 PATCH(先翻值;写失败回滚并 rethrow 供行内报错)。
/// 即时生效模型:无保存按钮,控件即写。
class WorkspacePrefsController extends AsyncNotifier<Workspace> {
  @override
  Future<Workspace> build() =>
      ref.watch(settingsRepositoryProvider).getActiveWorkspace();

  Future<void> setLanguage(String language) => _patch(language: language);

  Future<void> setWebFetchMode(String mode) => _patch(webFetchMode: mode);

  // ── S2 scenario defaults (dedicated endpoints return the fresh workspace row) 场景默认 ──

  Future<void> setDefaultModel(
    String scenario, {
    required String apiKeyId,
    required String modelId,
    Map<String, String>? options,
  }) async {
    state = AsyncData(
      await ref
          .read(settingsRepositoryProvider)
          .putDefaultModel(
            scenario,
            apiKeyId: apiKeyId,
            modelId: modelId,
            options: options,
          ),
    );
  }

  Future<void> clearDefaultModel(String scenario) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).deleteDefaultModel(scenario),
    );
  }

  Future<void> setDefaultSearch(String apiKeyId) async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).putDefaultSearch(apiKeyId),
    );
  }

  Future<void> clearDefaultSearch() async {
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).deleteDefaultSearch(),
    );
  }

  Future<void> _patch({String? language, String? webFetchMode}) async {
    // A write may arrive before the first fetch resolves (a panel that only READS on demand) —
    // await the row instead of silently dropping the write. 写可能先于首取完成——等行,绝不静默弃写。
    final before = state.value ?? await future;
    // Optimistic flip. 乐观先翻。
    state = AsyncData(
      before.copyWith(
        language: language ?? before.language,
        webFetchMode: webFetchMode ?? before.webFetchMode,
      ),
    );
    try {
      final fresh = await ref
          .read(settingsRepositoryProvider)
          .patchWorkspace(language: language, webFetchMode: webFetchMode);
      state = AsyncData(fresh);
    } catch (e) {
      state = AsyncData(before); // roll back 回滚
      rethrow;
    }
  }
}

final workspacePrefsProvider =
    AsyncNotifierProvider<WorkspacePrefsController, Workspace>(
      WorkspacePrefsController.new,
    );
