import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_key.dart';
import '../../../core/model/model_capabilities.dart';
import '../data/settings_repository.dart';

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
    state = AsyncData(
      await ref.read(settingsRepositoryProvider).getFreetierQuota(),
    );
  }

  /// The enable CTA — provisions then re-reads. Returns whether a managed row exists now. 启用即重读。
  Future<bool> provision() async {
    final ok = await ref.read(settingsRepositoryProvider).provisionFreetier();
    await refresh();
    if (ok) {
      ref.invalidate(
        modelCapabilitiesProvider,
      ); // the managed models just appeared 受管模型现身
    }
    return ok;
  }
}

final freetierQuotaProvider =
    AsyncNotifierProvider<FreetierQuotaController, FreetierQuota?>(
      FreetierQuotaController.new,
    );

/// The cloned-voice inventory (WRK-082 H9). Deletion goes through here so the cap arithmetic and
/// the row list can never disagree — they arrive from one authoritative re-read rather than a
/// client-side decrement.
///
/// 克隆音色库存(H9)。删除走这里,使上限算术与行列表**不可能互相矛盾**——它们来自**一次权威重读**,
/// 而不是客户端自己减一。
class VoicesController extends AsyncNotifier<VoiceInventory> {
  @override
  Future<VoiceInventory> build() =>
      ref.watch(settingsRepositoryProvider).voices();

  /// Delete one, then re-read. The re-read is the point: the upstream registration is removed
  /// first and the row only follows if that succeeded, so the server is the only thing that knows
  /// what actually survived.
  /// 删一个,然后重读。**重读才是要点**:上游登记先删、行只在那一步成功后才跟着删,故只有服务端知道
  /// 真正活下来的是什么。
  Future<void> remove(String id) async {
    await ref.read(settingsRepositoryProvider).deleteVoice(id);
    state = AsyncData(await ref.read(settingsRepositoryProvider).voices());
  }
}

final voicesProvider = AsyncNotifierProvider<VoicesController, VoiceInventory>(
  VoicesController.new,
);
