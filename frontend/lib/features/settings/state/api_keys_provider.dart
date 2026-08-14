import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_key.dart';
import '../../../core/media/media_source.dart';
import '../../../core/model/model_capabilities.dart';
import '../../../core/runtime.dart';
import '../data/settings_repository.dart';

/// The destructive request succeeded, but the authoritative inventory re-read did not. Keeping
/// the old row here would invite a second delete and would falsely claim the upstream registration
/// still exists; the UI must show an honest reconciliation state and offer only a fresh read.
/// 破坏性请求已成功,但权威库存重读失败。此时保留旧行会诱导第二次删除,还会谎称上游登记仍在;
/// UI 必须进入诚实的对账状态,只给一次新的读取。
class VoiceDeleteCommittedRefreshException implements Exception {
  const VoiceDeleteCommittedRefreshException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'voice delete committed; inventory refresh failed: $cause';
}

/// The provider catalog (static; mock hidden outside dev). provider 目录。
final providersProvider = FutureProvider<List<ProviderMeta>>(
  (ref) => ref.watch(settingsRepositoryProvider).listProviders(),
);

/// The key rows + every mutation (create / rotate / test / delete). Each mutation refreshes the list
/// from the backend AND invalidates the capabilities catalog (S-15: the pickers must never show a
/// dead key's models). Errors rethrow — the panel renders them inline (S-3/S-4 voices).
/// key 行与全部变更。每次变更后重拉列表并 invalidate capabilities(S-15);错误 rethrow 供面板行内渲染。
class ApiKeysController extends AsyncNotifier<List<ApiKey>> {
  @override
  Future<List<ApiKey>> build() =>
      ref.watch(settingsRepositoryProvider).listKeys();

  Future<ApiKey> create({
    required String provider,
    required String displayName,
    required String key,
    String? baseUrl,
    String? apiFormat,
  }) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .createKey(
          provider: provider,
          displayName: displayName,
          key: key,
          baseUrl: baseUrl,
          apiFormat: apiFormat,
        );
    await _refresh();
    return row;
  }

  Future<ApiKey> patch(
    String id, {
    String? displayName,
    String? baseUrl,
    String? key,
  }) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .patchKey(id, displayName: displayName, baseUrl: baseUrl, key: key);
    await _refresh();
    return row;
  }

  Future<void> remove(String id) async {
    await ref.read(settingsRepositoryProvider).deleteKey(id);
    await _refresh();
  }

  Future<void> test(String id) async {
    try {
      await ref.read(settingsRepositoryProvider).testKey(id);
    } finally {
      // A FAILED probe also stamped test_status on the row — refresh either way, or the list keeps
      // showing the pre-probe state. 失败探测同样落了行态——无论成败都重拉,否则列表停在探测前。
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    state = AsyncData(await ref.read(settingsRepositoryProvider).listKeys());
    // Key set changed → the (key, model) catalog is stale (S-15). key 集变→能力目录过期。
    ref.invalidate(modelCapabilitiesProvider);
    // Read-aloud has its own capability projection; keeping the transcript affordance cached after a
    // key mutation would make a newly speech-capable workspace look permanently silent.
    // 朗读有自己的能力投影;key 变更后仍沿用旧缓存,会让刚具备语音能力的 workspace 永远像「不能朗读」。
    ref.invalidate(readAloudAvailableProvider);
  }
}

final apiKeysProvider = AsyncNotifierProvider<ApiKeysController, List<ApiKey>>(
  ApiKeysController.new,
);

/// The free-tier quota card state: null = not provisioned (the enable-CTA face). Manual refresh only
/// — never polled (S-7). 免费档配额卡:null=未开通(启用 CTA 面);只手动刷新,绝不轮询。
class FreetierQuotaController extends AsyncNotifier<FreetierQuota?> {
  @override
  Future<FreetierQuota?> build() =>
      ref.watch(settingsRepositoryProvider).getFreetierQuota();

  Future<void> refresh() async {
    try {
      final quota = await ref
          .read(settingsRepositoryProvider)
          .getFreetierQuota();
      if (ref.mounted) state = AsyncData(quota);
    } catch (error, stackTrace) {
      // Do not leave a stale green meter on screen when the live gateway read fails. The error face
      // is the repair route; it is more honest and more useful than silently retaining old quota.
      // live 网关读失败时不留旧的绿色额度条。错误面就是修复入口，比静默保留旧配额诚实且可用。
      if (ref.mounted) state = AsyncError(error, stackTrace);
    }
  }

  /// The enable CTA — provisions then re-reads. Returns whether a managed row exists now. 启用即重读。
  Future<bool> provision() async {
    try {
      final ok = await ref.read(settingsRepositoryProvider).provisionFreetier();
      await refresh();
      if (!ok || state.hasError) return false;
      ref.invalidate(
        modelCapabilitiesProvider,
      ); // the managed models just appeared 受管模型现身
      ref.invalidate(
        readAloudAvailableProvider,
      ); // managed speech may have appeared 受管语音能力可能已现身
      return true;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final freetierQuotaProvider =
    AsyncNotifierProvider<FreetierQuotaController, FreetierQuota?>(
      FreetierQuotaController.new,
      // Recovery is the explicit repair/refresh action on the card. Riverpod's default retry
      // would turn a dead managed install back into a loading spinner and hide that action.
      retry: (_, _) => null,
    );

/// The cloned-voice inventory (WRK-082 H9). Deletion goes through here so the cap arithmetic and
/// the row list can never disagree — they arrive from one authoritative re-read rather than a
/// client-side decrement.
///
/// 克隆音色库存(H9)。删除走这里,使上限算术与行列表**不可能互相矛盾**——它们来自**一次权威重读**,
/// 而不是客户端自己减一。
class VoicesController extends AsyncNotifier<VoiceInventory> {
  @override
  Future<VoiceInventory> build() {
    // The settings ocean is kept alive across workspace switches. Make the inventory provider's
    // generation explicit so the old workspace's rows cannot render while the new list is loading.
    // 设置海洋跨 workspace 常驻;显式绑定代际,避免新列表加载时旧 workspace 的行继续显示。
    ref.watch(activeWorkspaceProvider);
    return ref.watch(settingsRepositoryProvider).voices();
  }

  /// Delete one, then re-read. The re-read is the point: the upstream registration is removed
  /// first and the row only follows if that succeeded, so the server is the only thing that knows
  /// what actually survived.
  /// 删一个,然后重读。**重读才是要点**:上游登记先删、行只在那一步成功后才跟着删,故只有服务端知道
  /// 真正活下来的是什么。
  Future<void> remove(String id) async {
    final workspaceId = ref.read(activeWorkspaceProvider);
    if (workspaceId == null || workspaceId.isEmpty) {
      throw StateError('cannot delete a voice without an active workspace');
    }
    final repository = ref.read(settingsRepositoryProvider);
    // Pin both calls to the workspace that authorized the destructive action. The live repository
    // otherwise reads the hot-switch callback lazily, which can turn an in-flight delete into a
    // cross-workspace request when the user switches during the await.
    // 两次请求都固定在发起破坏性动作时的 workspace。否则 Live repository 懒读热切换回调,用户在 await
    // 期间切换时,在途删除可能串到另一个 workspace。
    await repository.deleteVoice(id, workspaceId: workspaceId);
    if (!ref.mounted || ref.read(activeWorkspaceProvider) != workspaceId) {
      return;
    }
    try {
      final inventory = await repository.voices(workspaceId: workspaceId);
      if (!ref.mounted || ref.read(activeWorkspaceProvider) != workspaceId) {
        return;
      }
      state = AsyncData(inventory);
    } catch (error, stackTrace) {
      final committed = VoiceDeleteCommittedRefreshException(error);
      if (!ref.mounted || ref.read(activeWorkspaceProvider) != workspaceId) {
        return;
      }
      state = AsyncError(committed, stackTrace);
      Error.throwWithStackTrace(committed, stackTrace);
    }
  }
}

final voicesProvider = AsyncNotifierProvider<VoicesController, VoiceInventory>(
  VoicesController.new,
);
