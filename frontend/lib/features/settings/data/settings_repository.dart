import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/api_key.dart';
import '../../../core/contract/workspace.dart';
import '../../../core/net/api_client.dart';
import '../../../core/runtime.dart';

/// The settings feature's data seam — the ACTIVE workspace's preference surface (S1: language /
/// webFetchMode; S2 adds default models / keys around it). Live hits the real backend; Fixture is
/// the in-memory scriptable double (demo + tests). One override point: [settingsRepositoryProvider].
/// settings 数据缝——当前 workspace 的偏好面(S1:语言/抓取模式;S2 续接默认模型/密钥)。Live 打真后端;
/// Fixture 内存可脚本(demo/测试)。唯一 override 点 settingsRepositoryProvider。
abstract class SettingsRepository {
  /// The active workspace row (the workspace-scope preferences live ON it). 当前 workspace 行。
  Future<Workspace> getActiveWorkspace();

  /// PATCH one or more workspace preference fields; returns the fresh row. 分部 PATCH,返新行。
  Future<Workspace> patchWorkspace({String? language, String? webFetchMode});

  // ── S2 模型与密钥 models & keys ──

  /// The static provider catalog (mock hidden outside dev — backend S-5). provider 目录。
  Future<List<ProviderMeta>> listProviders();

  /// Every key row (bounded; the panel shows all). 全部 key 行。
  Future<List<ApiKey>> listKeys();

  Future<ApiKey> createKey({
    required String provider,
    required String displayName,
    required String key,
    String? baseUrl,
    String? apiFormat,
  });

  /// PATCH — a non-empty [key] ROTATES (destructive; probe resets + auto re-probes). 非空 key=旋转。
  Future<ApiKey> patchKey(String id, {String? displayName, String? baseUrl, String? key});

  /// Throws [ApiError] `API_KEY_IN_USE` with `details.references` when referenced. 被引用抛 IN_USE。
  Future<void> deleteKey(String id);

  /// Probe now — returns the refreshed row (the backend persists the outcome). 立即探测,返新行。
  Future<ApiKey> testKey(String id);

  /// null = 404 FREETIER_NOT_PROVISIONED (no managed row yet). 未开通映射 null。
  Future<FreetierQuota?> getFreetierQuota();

  /// POST :provision — true when a managed row exists afterwards. 手动开通;事后有行=true。
  Future<bool> provisionFreetier();

  /// Scenario ∈ dialogue|utility|agent; returns the fresh workspace row. 场景默认;返新 workspace 行。
  Future<Workspace> putDefaultModel(String scenario, {required String apiKeyId, required String modelId});
  Future<Workspace> deleteDefaultModel(String scenario);
  Future<Workspace> putDefaultSearch(String apiKeyId);
  Future<Workspace> deleteDefaultSearch();
}

class LiveSettingsRepository implements SettingsRepository {
  LiveSettingsRepository({required this.api, required this.workspaceId});

  final ApiClient api;

  /// Read per call (the hot-switch discipline: never snapshot the id at construction). 逐调用读。
  final String? Function() workspaceId;

  String get _id {
    final id = workspaceId();
    if (id == null) throw StateError('no active workspace 无活跃工作区');
    return id;
  }

  @override
  Future<Workspace> getActiveWorkspace() =>
      api.getEntity('/api/v1/workspaces/$_id', Workspace.fromJson);

  @override
  Future<Workspace> patchWorkspace({String? language, String? webFetchMode}) =>
      api.patchEntity('/api/v1/workspaces/$_id', Workspace.fromJson, body: {
        'language': ?language,
        'webFetchMode': ?webFetchMode,
      });

  @override
  Future<List<ProviderMeta>> listProviders() async =>
      (await api.getPage('/api/v1/providers', ProviderMeta.fromJson)).items;

  @override
  Future<List<ApiKey>> listKeys() async =>
      (await api.getPage('/api/v1/api-keys', ApiKey.fromJson, query: {'limit': '200'})).items;

  @override
  Future<ApiKey> createKey({
    required String provider,
    required String displayName,
    required String key,
    String? baseUrl,
    String? apiFormat,
  }) =>
      api.postEntity('/api/v1/api-keys', ApiKey.fromJson, body: {
        'provider': provider,
        'displayName': displayName,
        'key': key,
        'baseUrl': ?baseUrl,
        'apiFormat': ?apiFormat,
      });

  @override
  Future<ApiKey> patchKey(String id, {String? displayName, String? baseUrl, String? key}) =>
      api.patchEntity('/api/v1/api-keys/$id', ApiKey.fromJson, body: {
        'displayName': ?displayName,
        'baseUrl': ?baseUrl,
        'key': ?key,
      });

  @override
  Future<void> deleteKey(String id) => api.delete('/api/v1/api-keys/$id');

  @override
  Future<ApiKey> testKey(String id) async {
    await api.postData('/api/v1/api-keys/$id:test');
    // The probe outcome is persisted server-side — re-read the row for the fresh testStatus.
    // 探测结果落库,重读行取新状态。
    return api.getEntity('/api/v1/api-keys/$id', ApiKey.fromJson);
  }

  @override
  Future<FreetierQuota?> getFreetierQuota() async {
    try {
      final data = await api.getData('/api/v1/freetier/quota');
      return FreetierQuota.fromJson(data);
    } on ApiException catch (e) {
      if (e.code == 'FREETIER_NOT_PROVISIONED') return null;
      rethrow;
    }
  }

  @override
  Future<bool> provisionFreetier() async {
    final data = await api.postData('/api/v1/freetier:provision');
    return data['provisioned'] == true;
  }

  @override
  Future<Workspace> putDefaultModel(String scenario,
          {required String apiKeyId, required String modelId}) =>
      api.putEntity('/api/v1/workspaces/$_id/default-models/$scenario', Workspace.fromJson,
          body: {'apiKeyId': apiKeyId, 'modelId': modelId});

  @override
  Future<Workspace> deleteDefaultModel(String scenario) =>
      api.deleteEntity('/api/v1/workspaces/$_id/default-models/$scenario', Workspace.fromJson);

  @override
  Future<Workspace> putDefaultSearch(String apiKeyId) =>
      api.putEntity('/api/v1/workspaces/$_id/default-search', Workspace.fromJson,
          body: {'apiKeyId': apiKeyId});

  @override
  Future<Workspace> deleteDefaultSearch() =>
      api.deleteEntity('/api/v1/workspaces/$_id/default-search', Workspace.fromJson);
}

/// In-memory double — demo + tests. 内存替身。
class FixtureSettingsRepository implements SettingsRepository {
  FixtureSettingsRepository({Workspace? workspace})
      : workspace = workspace ??
            Workspace(
              id: 'ws_demo0000000000',
              name: 'Demo',
              language: 'zh-CN',
              createdAt: DateTime.utc(2026, 7, 1),
              updatedAt: DateTime.utc(2026, 7, 1),
            );

  Workspace workspace;

  /// Script hook: throw on the next patch (error-path tests). 脚本钩:下次 patch 抛错。
  bool failNextPatch = false;

  @override
  Future<Workspace> getActiveWorkspace() async => workspace;

  @override
  Future<Workspace> patchWorkspace({String? language, String? webFetchMode}) async {
    if (failNextPatch) {
      failNextPatch = false;
      throw StateError('scripted patch failure');
    }
    workspace = workspace.copyWith(
      language: language ?? workspace.language,
      webFetchMode: webFetchMode ?? workspace.webFetchMode,
      updatedAt: DateTime.now().toUtc(),
    );
    return workspace;
  }

  // ── S2 keys surface (scriptable in-memory) 密钥面(内存可脚本) ──

  List<ProviderMeta> providers = const [
    ProviderMeta(name: 'anselm', displayName: 'Anselm Free', managed: true),
    ProviderMeta(name: 'openai', displayName: 'OpenAI', defaultBaseUrl: 'https://api.openai.com/v1'),
    ProviderMeta(name: 'deepseek', displayName: 'DeepSeek'),
    ProviderMeta(name: 'ollama', displayName: 'Ollama', baseUrlRequired: true),
    ProviderMeta(name: 'brave', displayName: 'Brave Search', category: 'search'),
  ];
  final List<ApiKey> keys = [];
  FreetierQuota? quota;
  bool provisionResult = true;

  /// Script hooks. 脚本钩。
  Object? failNextKeyOp;
  int _seq = 0;

  void _maybeFail() {
    final f = failNextKeyOp;
    if (f != null) {
      failNextKeyOp = null;
      throw f is Exception ? f : StateError('$f');
    }
  }

  @override
  Future<List<ProviderMeta>> listProviders() async => providers;

  @override
  Future<List<ApiKey>> listKeys() async => List.of(keys);

  @override
  Future<ApiKey> createKey({
    required String provider,
    required String displayName,
    required String key,
    String? baseUrl,
    String? apiFormat,
  }) async {
    _maybeFail();
    final now = DateTime.now().toUtc();
    final row = ApiKey(
      id: 'aki_fixture${_seq++}',
      provider: provider,
      displayName: displayName,
      keyMasked: key.length > 4 ? '${key.substring(0, 4)}…' : '…',
      baseUrl: baseUrl ?? '',
      apiFormat: apiFormat ?? '',
      createdAt: now,
      updatedAt: now,
    );
    keys.add(row);
    return row;
  }

  @override
  Future<ApiKey> patchKey(String id, {String? displayName, String? baseUrl, String? key}) async {
    _maybeFail();
    final i = keys.indexWhere((k) => k.id == id);
    var row = keys[i];
    row = row.copyWith(
      displayName: displayName ?? row.displayName,
      baseUrl: baseUrl ?? row.baseUrl,
      testStatus: key != null ? 'pending' : row.testStatus,
      updatedAt: DateTime.now().toUtc(),
    );
    keys[i] = row;
    return row;
  }

  @override
  Future<void> deleteKey(String id) async {
    _maybeFail();
    keys.removeWhere((k) => k.id == id);
  }

  @override
  Future<ApiKey> testKey(String id) async {
    _maybeFail();
    final i = keys.indexWhere((k) => k.id == id);
    keys[i] = keys[i].copyWith(testStatus: 'ok', lastTestedAt: DateTime.now().toUtc());
    return keys[i];
  }

  @override
  Future<FreetierQuota?> getFreetierQuota() async => quota;

  @override
  Future<bool> provisionFreetier() async {
    _maybeFail();
    if (provisionResult) {
      quota ??= const FreetierQuota(limit: 5000, used: 0, remaining: 5000, resetAt: '2026-08-01');
    }
    return provisionResult;
  }

  Workspace _withDefault(String scenario, ModelRef? ref) {
    workspace = switch (scenario) {
      'dialogue' => workspace.copyWith(defaultDialogue: ref),
      'utility' => workspace.copyWith(defaultUtility: ref),
      'agent' => workspace.copyWith(defaultAgent: ref),
      _ => workspace,
    };
    return workspace;
  }

  @override
  Future<Workspace> putDefaultModel(String scenario,
          {required String apiKeyId, required String modelId}) async =>
      _withDefault(scenario, ModelRef(apiKeyId: apiKeyId, modelId: modelId));

  @override
  Future<Workspace> deleteDefaultModel(String scenario) async => _withDefault(scenario, null);

  @override
  Future<Workspace> putDefaultSearch(String apiKeyId) async =>
      workspace = workspace.copyWith(defaultSearchKeyId: apiKeyId);

  @override
  Future<Workspace> deleteDefaultSearch() async =>
      workspace = workspace.copyWith(defaultSearchKeyId: null);
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return LiveSettingsRepository(api: api, workspaceId: () => ref.read(activeWorkspaceProvider));
});
