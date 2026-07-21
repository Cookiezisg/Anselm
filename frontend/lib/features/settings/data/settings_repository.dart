import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/api_key.dart';
import '../../../core/contract/limits.dart';
import '../../../core/contract/mcp.dart';
import '../../../core/contract/network.dart';
import '../../../core/contract/retention.dart';
import '../../../core/contract/sandbox.dart';
import '../../../core/contract/memory.dart';
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
  Future<ApiKey> patchKey(
    String id, {
    String? displayName,
    String? baseUrl,
    String? key,
  });

  /// Throws [ApiError] `API_KEY_IN_USE` with `details.references` when referenced. 被引用抛 IN_USE。
  Future<void> deleteKey(String id);

  /// Probe now — returns the refreshed row (the backend persists the outcome). 立即探测,返新行。
  Future<ApiKey> testKey(String id);

  /// null = 404 FREETIER_NOT_PROVISIONED (no managed row yet). 未开通映射 null。
  Future<FreetierQuota?> getFreetierQuota();

  /// POST :provision — true when a managed row exists afterwards. 手动开通;事后有行=true。
  Future<bool> provisionFreetier();

  /// Scenario ∈ dialogue|utility|agent; returns the fresh workspace row. 场景默认;返新 workspace 行。
  Future<Workspace> putDefaultModel(
    String scenario, {
    required String apiKeyId,
    required String modelId,
    Map<String, String>? options,
  });
  Future<Workspace> deleteDefaultModel(String scenario);
  Future<Workspace> putDefaultSearch(String apiKeyId);
  Future<Workspace> deleteDefaultSearch();

  // ── S3 工作区与关于 workspaces & about ──

  /// Every workspace (bounded set — the switcher's world). 全部 workspace。
  Future<List<Workspace>> listWorkspaces();

  Future<Workspace> createWorkspace({
    required String name,
    String? avatarColor,
  });

  /// PATCH any workspace by id (name / avatarColor / language). 按 id 分部 PATCH。
  Future<Workspace> patchWorkspaceById(
    String id, {
    String? name,
    String? avatarColor,
  });

  /// Cascade destroy. Throws `CANNOT_DELETE_LAST_WORKSPACE` on the last one. 级联销毁。
  Future<void> deleteWorkspace(String id);

  /// The delete confirmation's REAL numbers (S-11). 删除确认的真数字。
  Future<WorkspaceStats> workspaceStats(String id);

  /// The backend build version (`GET /version`, bearer-only). 后端版本。
  Future<String> backendVersion();

  // ── S4 记忆 memories ──

  /// All memories, optionally pinned-only (bounded set). 全部记忆(可只取已固定)。
  Future<List<Memory>> listMemories({bool? pinned});

  /// PUT create-or-update. [pinned] + source are HONORED only at CREATE; an UPDATE ignores both
  /// server-side (F147 — the roster's pin toggle owns updates), so [pinned] is a create-only choice.
  /// 建或改;pinned/source 仅创建时生效,更新时后端忽略(F147:更新交给名册 pin 钮),故 pinned 只在建时有意义。
  Future<Memory> putMemory(
    String name, {
    required String description,
    required String content,
    bool pinned = false,
  });

  Future<Memory> pinMemory(String name, {required bool pinned});

  Future<void> deleteMemory(String name);

  // ── S4b MCP ──

  Future<List<McpServerStatus>> listMcpServers();
  Future<McpServerStatus> getMcpServer(String name);

  /// Manual PUT (same name replaces). A connect failure still lands the row (failed, honest).
  /// 手动 PUT(同名替换);连接失败仍落盘(failed 诚实态)。
  Future<McpServerStatus> putMcpServer(
    String name,
    Map<String, dynamic> config,
  );
  Future<void> deleteMcpServer(String name);
  Future<McpServerStatus> reconnectMcpServer(String name);

  /// The 256KB stderr tail. stderr 尾。
  Future<String> mcpStderr(String name);

  /// One page of the call log + ok/failed aggregates. 调用日志一页+聚合。
  Future<
    ({List<McpCall> calls, int okCount, int failedCount, String? nextCursor})
  >
  listMcpCalls(String name, {String? cursor});

  Future<List<McpRegistryEntry>> listMcpRegistry();
  Future<McpRegistryPlan> planMcpInstall(String fullName);
  Future<McpServerStatus> installMcp(String fullName, Map<String, String> env);

  /// Claude Desktop mcp.json import. 导入。
  Future<({List<String> imported, List<String> skipped})> importMcpJson(
    String json, {
    bool overwrite,
  });

  // ── S5 存储与限额 storage & limits ──

  /// The backend-resolved data root (never guessed client-side). 后端解析的数据根(前端绝不猜)。
  Future<String> dataDir();

  /// Machine-wide sandbox disk usage. 全机沙箱磁盘占用。
  Future<int> sandboxDiskUsage();

  /// The DB file's size + dead (reclaimable) bytes (`GET /storage-stat`, WRK-070 T4). Machine-level:
  /// one .db file for the whole install. 数据库文件大小 + 死（可回收）字节。机器级:整个安装一个 .db 文件。
  Future<({int dbBytes, int deadBytes})> storageStat();

  /// Compact the DB (`POST /storage:compact`, a synchronous VACUUM). Returns bytes handed back to the
  /// OS + whether it upgraded a mode=0 DB to auto_vacuum=INCREMENTAL. NOT destructive (VACUUM keeps
  /// every row) — no type-to-confirm, but a knowing wait (it locks the DB a few seconds).
  /// 压缩数据库(同步 VACUUM)。返回还给 OS 的字节 + 是否把 mode=0 库升级到 INCREMENTAL。**非**破坏性
  /// (VACUUM 保留每一行)——不设输名双闸,但是一次知情等待(锁库几秒)。
  Future<({int reclaimedBytes, bool migrated})> compactStorage();

  /// The nested limits JSON (dotted schema keys index into it). 嵌套限额 JSON。
  Future<Map<String, dynamic>> getLimits();

  Future<List<LimitField>> limitsSchema();

  /// Partial nested merge; 400 SETTINGS_LIMITS_INVALID on violations. 部分合并;越界 400。
  Future<Map<String, dynamic>> patchLimits(Map<String, dynamic> partial);

  Future<Map<String, dynamic>> resetLimits();

  Future<NetworkConfig> getNetwork();

  /// PATCH replaces the whole config (three optional strings). 整体替换。
  Future<NetworkConfig> patchNetwork(NetworkConfig config);

  /// The machine-level run-history retention line (scheduler 工单⑬/判决④). GET always answers a
  /// CONCRETE value — a fresh install reads back the server-held default — so the panel hydrates from
  /// the wire and NEVER hardcodes a default.
  /// 机器级 run 保留线(⑬):GET 恒返具体值(全新安装读回服务端自持的默认),故面板一律水化自线缆、**永不硬编默认**。
  Future<RetentionConfig> getRetention();

  /// PATCH is a PARTIAL MERGE over the current value (unlike [patchNetwork]'s whole-config replace) and
  /// returns the merged whole — write back what it returns. `0` = keep forever. Only a NEGATIVE count
  /// is rejected (400): the 30/90/180 value set is a front-end product affordance, not a backend rule.
  /// PATCH 是对当前值**部分合并**(与 patchNetwork 的整体替换不同)、返合并后的全量——拿返回值回写。
  /// 0=永久。只有**负数**被拒(400):30/90/180 值集是前端产品可供性,不是后端规则。
  Future<RetentionConfig> patchRetention(int days);

  // ── S5 沙箱 sandbox ──

  Future<SandboxBootstrap> sandboxBootstrap();
  Future<void> retrySandboxBootstrap();
  Future<List<SandboxRuntime>> sandboxRuntimes();
  Future<List<RuntimeAvailability>> sandboxAvailable();

  /// 201 Runtime; installs (async → status via refetch). 装运行时。
  Future<SandboxRuntime> installRuntime({
    required String kind,
    required String version,
  });

  /// 204; 409 SANDBOX_ENV_IN_USE when envs still reference it. 删运行时。
  Future<void> deleteRuntime(String id);

  /// ownerKind ∈ function|handler|mcp|skill|conversation (required). 按 owner 列环境。
  Future<List<SandboxEnv>> sandboxEnvs(String ownerKind);
  Future<void> deleteEnv(String id);

  /// olderThanDays: 0 = reap ALL idle now; returns removed count. GC。
  Future<int> sandboxGc(int olderThanDays);
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
      api.patchEntity(
        '/api/v1/workspaces/$_id',
        Workspace.fromJson,
        body: {'language': ?language, 'webFetchMode': ?webFetchMode},
      );

  @override
  Future<List<ProviderMeta>> listProviders() async =>
      (await api.getPage('/api/v1/providers', ProviderMeta.fromJson)).items;

  @override
  Future<List<ApiKey>> listKeys() async => (await api.getPage(
    '/api/v1/api-keys',
    ApiKey.fromJson,
    query: {'limit': '200'},
  )).items;

  @override
  Future<ApiKey> createKey({
    required String provider,
    required String displayName,
    required String key,
    String? baseUrl,
    String? apiFormat,
  }) => api.postEntity(
    '/api/v1/api-keys',
    ApiKey.fromJson,
    body: {
      'provider': provider,
      'displayName': displayName,
      'key': key,
      'baseUrl': ?baseUrl,
      'apiFormat': ?apiFormat,
    },
  );

  @override
  Future<ApiKey> patchKey(
    String id, {
    String? displayName,
    String? baseUrl,
    String? key,
  }) => api.patchEntity(
    '/api/v1/api-keys/$id',
    ApiKey.fromJson,
    body: {'displayName': ?displayName, 'baseUrl': ?baseUrl, 'key': ?key},
  );

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
  Future<Workspace> putDefaultModel(
    String scenario, {
    required String apiKeyId,
    required String modelId,
    Map<String, String>? options,
  }) => api.putEntity(
    '/api/v1/workspaces/$_id/default-models/$scenario',
    Workspace.fromJson,
    body: {
      'apiKeyId': apiKeyId,
      'modelId': modelId,
      if (options != null && options.isNotEmpty) 'options': options,
    },
  );

  @override
  Future<Workspace> deleteDefaultModel(String scenario) => api.deleteEntity(
    '/api/v1/workspaces/$_id/default-models/$scenario',
    Workspace.fromJson,
  );

  @override
  Future<Workspace> putDefaultSearch(String apiKeyId) => api.putEntity(
    '/api/v1/workspaces/$_id/default-search',
    Workspace.fromJson,
    body: {'apiKeyId': apiKeyId},
  );

  @override
  Future<Workspace> deleteDefaultSearch() => api.deleteEntity(
    '/api/v1/workspaces/$_id/default-search',
    Workspace.fromJson,
  );

  @override
  Future<List<Workspace>> listWorkspaces() async =>
      (await api.getPage('/api/v1/workspaces', Workspace.fromJson)).items;

  @override
  Future<Workspace> createWorkspace({
    required String name,
    String? avatarColor,
  }) => api.postEntity(
    '/api/v1/workspaces',
    Workspace.fromJson,
    body: {'name': name, 'avatarColor': ?avatarColor},
  );

  @override
  Future<Workspace> patchWorkspaceById(
    String id, {
    String? name,
    String? avatarColor,
  }) => api.patchEntity(
    '/api/v1/workspaces/$id',
    Workspace.fromJson,
    body: {'name': ?name, 'avatarColor': ?avatarColor},
  );

  @override
  Future<void> deleteWorkspace(String id) =>
      api.delete('/api/v1/workspaces/$id');

  @override
  Future<WorkspaceStats> workspaceStats(String id) =>
      api.getEntity('/api/v1/workspaces/$id/stats', WorkspaceStats.fromJson);

  @override
  Future<String> backendVersion() async =>
      (await api.getData('/api/v1/version'))['version'] as String? ?? '';

  @override
  Future<List<Memory>> listMemories({bool? pinned}) async => (await api.getPage(
    '/api/v1/memories',
    Memory.fromJson,
    query: {if (pinned != null) 'pinned': '$pinned'},
  )).items;

  @override
  Future<Memory> putMemory(
    String name, {
    required String description,
    required String content,
    bool pinned = false,
  }) =>
      // source + pinned are REQUIRED/HONORED at create and IGNORED on update (F147) — sending them is
      // safe on both paths (an AI-authored memory keeps source=ai and its curated pin when edited;
      // pin changes on existing rows go through the roster's :pin/:unpin toggle). 创建必带 source、
      // pinned 建时生效,更新被忽略——恒送两径皆安全(编辑 AI 记忆保 source=ai 与既有 pin;改 pin 走名册 toggle)。
      api.putEntity(
        '/api/v1/memories/$name',
        Memory.fromJson,
        body: {
          'description': description,
          'content': content,
          'source': 'user',
          'pinned': pinned,
        },
      );

  @override
  Future<Memory> pinMemory(String name, {required bool pinned}) => api
      .postData('/api/v1/memories/$name/${pinned ? 'pin' : 'unpin'}')
      .then(Memory.fromJson);

  @override
  Future<void> deleteMemory(String name) =>
      api.delete('/api/v1/memories/$name');

  @override
  Future<List<McpServerStatus>> listMcpServers() async => (await api.getPage(
    '/api/v1/mcp-servers',
    McpServerStatus.fromJson,
  )).items;

  @override
  Future<McpServerStatus> getMcpServer(String name) =>
      api.getEntity('/api/v1/mcp-servers/$name', McpServerStatus.fromJson);

  @override
  Future<McpServerStatus> putMcpServer(
    String name,
    Map<String, dynamic> config,
  ) => api.putEntity(
    '/api/v1/mcp-servers/$name',
    McpServerStatus.fromJson,
    body: config,
  );

  @override
  Future<void> deleteMcpServer(String name) =>
      api.delete('/api/v1/mcp-servers/$name');

  @override
  Future<McpServerStatus> reconnectMcpServer(String name) => api
      .postData('/api/v1/mcp-servers/$name:reconnect')
      .then(McpServerStatus.fromJson);

  @override
  Future<String> mcpStderr(String name) async =>
      (await api.getData('/api/v1/mcp-servers/$name/stderr'))['stderr']
          as String? ??
      '';

  @override
  Future<
    ({List<McpCall> calls, int okCount, int failedCount, String? nextCursor})
  >
  listMcpCalls(String name, {String? cursor}) async {
    final page = await api.getPageWithAggregate(
      '/api/v1/mcp-servers/$name/calls',
      'calls',
      McpCall.fromJson,
      (agg) => (
        ok: (agg['okCount'] as num?)?.toInt() ?? 0,
        failed: (agg['failedCount'] as num?)?.toInt() ?? 0,
      ),
      query: {'cursor': ?cursor},
    );
    return (
      calls: page.items,
      okCount: page.aggregate.ok,
      failedCount: page.aggregate.failed,
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<List<McpRegistryEntry>> listMcpRegistry() async => (await api.getPage(
    '/api/v1/mcp-registry',
    McpRegistryEntry.fromJson,
  )).items;

  @override
  Future<McpRegistryPlan> planMcpInstall(String fullName) => api
      .postData('/api/v1/mcp-registry:plan', body: {'name': fullName})
      .then(McpRegistryPlan.fromJson);

  @override
  Future<McpServerStatus> installMcp(
    String fullName,
    Map<String, String> env,
  ) => api
      .postData(
        '/api/v1/mcp-registry:install',
        body: {'name': fullName, 'env': env},
      )
      .then(McpServerStatus.fromJson);

  @override
  Future<({List<String> imported, List<String> skipped})> importMcpJson(
    String json, {
    bool overwrite = false,
  }) async {
    final data = await api.postData(
      '/api/v1/mcp-servers:import?overwrite=$overwrite',
      body: jsonDecode(json),
    );
    return (
      imported: ((data['imported'] as List?) ?? const []).cast<String>(),
      skipped: ((data['skipped'] as List?) ?? const []).cast<String>(),
    );
  }

  @override
  Future<String> dataDir() async =>
      (await api.getData('/api/v1/system/data-dir'))['dataDir'] as String? ??
      '';

  @override
  Future<int> sandboxDiskUsage() async =>
      ((await api.getData('/api/v1/sandbox/disk-usage'))['totalBytes'] as num?)
          ?.toInt() ??
      0;

  @override
  Future<({int dbBytes, int deadBytes})> storageStat() async {
    final d = await api.getData('/api/v1/storage-stat');
    return (
      dbBytes: (d['dbBytes'] as num?)?.toInt() ?? 0,
      deadBytes: (d['deadBytes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<({int reclaimedBytes, bool migrated})> compactStorage() async {
    final d = await api.postData('/api/v1/storage:compact');
    return (
      reclaimedBytes: (d['reclaimedBytes'] as num?)?.toInt() ?? 0,
      migrated: d['migrated'] == true,
    );
  }

  @override
  Future<Map<String, dynamic>> getLimits() => api.getData('/api/v1/limits');

  @override
  Future<List<LimitField>> limitsSchema() async =>
      (await api.getPage('/api/v1/limits/schema', LimitField.fromJson)).items;

  @override
  Future<Map<String, dynamic>> patchLimits(Map<String, dynamic> partial) async {
    await api.patchEntity('/api/v1/limits', (j) => j, body: partial);
    return getLimits();
  }

  @override
  Future<Map<String, dynamic>> resetLimits() async {
    await api.postData('/api/v1/limits:reset');
    return getLimits();
  }

  @override
  Future<NetworkConfig> getNetwork() =>
      api.getEntity('/api/v1/network', NetworkConfig.fromJson);

  @override
  Future<NetworkConfig> patchNetwork(NetworkConfig config) => api.patchEntity(
    '/api/v1/network',
    NetworkConfig.fromJson,
    body: {
      'httpProxy': config.httpProxy,
      'httpsProxy': config.httpsProxy,
      'noProxy': config.noProxy,
    },
  );

  @override
  Future<RetentionConfig> getRetention() =>
      api.getEntity('/api/v1/retention', RetentionConfig.fromJson);

  @override
  Future<RetentionConfig> patchRetention(int days) => api.patchEntity(
    '/api/v1/retention',
    RetentionConfig.fromJson,
    body: {'runRetentionDays': days},
  );

  @override
  Future<SandboxBootstrap> sandboxBootstrap() => api.getEntity(
    '/api/v1/sandbox/bootstrap-status',
    SandboxBootstrap.fromJson,
  );

  @override
  Future<void> retrySandboxBootstrap() =>
      api.postData('/api/v1/sandbox:retry-bootstrap');

  @override
  Future<List<SandboxRuntime>> sandboxRuntimes() async => (await api.getPage(
    '/api/v1/sandbox/runtimes',
    SandboxRuntime.fromJson,
  )).items;

  @override
  Future<List<RuntimeAvailability>> sandboxAvailable() async =>
      (await api.getPage(
        '/api/v1/sandbox/runtimes/available',
        RuntimeAvailability.fromJson,
      )).items;

  @override
  Future<SandboxRuntime> installRuntime({
    required String kind,
    required String version,
  }) => api
      .postData(
        '/api/v1/sandbox/runtimes',
        body: {'kind': kind, 'version': version},
      )
      .then(SandboxRuntime.fromJson);

  @override
  Future<void> deleteRuntime(String id) =>
      api.delete('/api/v1/sandbox/runtimes/$id');

  @override
  Future<List<SandboxEnv>> sandboxEnvs(String ownerKind) async =>
      (await api.getPage(
        '/api/v1/sandbox/envs',
        SandboxEnv.fromJson,
        query: {'ownerKind': ownerKind},
      )).items;

  @override
  Future<void> deleteEnv(String id) => api.delete('/api/v1/sandbox/envs/$id');

  @override
  Future<int> sandboxGc(int olderThanDays) async =>
      ((await api.postData(
                '/api/v1/sandbox:gc?olderThanDays=$olderThanDays',
              ))['removed']
              as num?)
          ?.toInt() ??
      0;
}

/// In-memory double — demo + tests. 内存替身。
class FixtureSettingsRepository implements SettingsRepository {
  FixtureSettingsRepository({Workspace? workspace})
    : workspace =
          workspace ??
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
  Future<Workspace> patchWorkspace({
    String? language,
    String? webFetchMode,
  }) async {
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
    ProviderMeta(
      name: 'openai',
      displayName: 'OpenAI',
      defaultBaseUrl: 'https://api.openai.com/v1',
    ),
    ProviderMeta(name: 'deepseek', displayName: 'DeepSeek'),
    ProviderMeta(name: 'ollama', displayName: 'Ollama', baseUrlRequired: true),
    ProviderMeta(
      name: 'brave',
      displayName: 'Brave Search',
      category: 'search',
    ),
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
  Future<ApiKey> patchKey(
    String id, {
    String? displayName,
    String? baseUrl,
    String? key,
  }) async {
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
    keys[i] = keys[i].copyWith(
      testStatus: 'ok',
      lastTestedAt: DateTime.now().toUtc(),
    );
    return keys[i];
  }

  @override
  Future<FreetierQuota?> getFreetierQuota() async => quota;

  @override
  Future<bool> provisionFreetier() async {
    _maybeFail();
    if (provisionResult) {
      quota ??= const FreetierQuota(
        limit: 5000,
        used: 0,
        remaining: 5000,
        resetAt: '2026-08-01',
      );
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
  Future<Workspace> putDefaultModel(
    String scenario, {
    required String apiKeyId,
    required String modelId,
    Map<String, String>? options,
  }) async => _withDefault(
    scenario,
    ModelRef(
      apiKeyId: apiKeyId,
      modelId: modelId,
      options: options ?? const {},
    ),
  );

  @override
  Future<Workspace> deleteDefaultModel(String scenario) async =>
      _withDefault(scenario, null);

  @override
  Future<Workspace> putDefaultSearch(String apiKeyId) async =>
      workspace = workspace.copyWith(defaultSearchKeyId: apiKeyId);

  @override
  Future<Workspace> deleteDefaultSearch() async =>
      workspace = workspace.copyWith(defaultSearchKeyId: null);

  // ── S3 workspaces & about (scriptable) ──

  final List<Workspace> extraWorkspaces = [];
  WorkspaceStats stats = const WorkspaceStats();
  String version = '0.0.0-fixture';

  /// Script hook: fail the next workspace delete with this code. 脚本钩:下次删 ws 抛此码。
  String? failNextWorkspaceDelete;

  @override
  Future<List<Workspace>> listWorkspaces() async => [
    workspace,
    ...extraWorkspaces,
  ];

  @override
  Future<Workspace> createWorkspace({
    required String name,
    String? avatarColor,
  }) async {
    final row = Workspace(
      id: 'ws_fix${extraWorkspaces.length + 1}',
      name: name,
      avatarColor: avatarColor,
      language: 'zh-CN',
      createdAt: DateTime.utc(2026, 7, 9),
      updatedAt: DateTime.utc(2026, 7, 9),
    );
    extraWorkspaces.add(row);
    return row;
  }

  @override
  Future<Workspace> patchWorkspaceById(
    String id, {
    String? name,
    String? avatarColor,
  }) async {
    Workspace patch(Workspace w) => w.copyWith(
      name: name ?? w.name,
      avatarColor: avatarColor ?? w.avatarColor,
      updatedAt: DateTime.utc(2026, 7, 9, 1),
    );
    if (workspace.id == id) return workspace = patch(workspace);
    final i = extraWorkspaces.indexWhere((w) => w.id == id);
    if (i < 0) throw StateError('unknown workspace $id');
    return extraWorkspaces[i] = patch(extraWorkspaces[i]);
  }

  @override
  Future<void> deleteWorkspace(String id) async {
    if (failNextWorkspaceDelete != null) {
      final code = failNextWorkspaceDelete!;
      failNextWorkspaceDelete = null;
      throw ApiException(
        code: code,
        message: 'scripted failure',
        httpStatus: 422,
      );
    }
    extraWorkspaces.removeWhere((w) => w.id == id);
  }

  @override
  Future<WorkspaceStats> workspaceStats(String id) async => stats;

  @override
  Future<String> backendVersion() async => version;

  final List<Memory> memories = [];

  @override
  Future<List<Memory>> listMemories({bool? pinned}) async => pinned == null
      ? List.of(memories)
      : memories.where((m) => m.pinned == pinned).toList();

  @override
  Future<Memory> putMemory(
    String name, {
    required String description,
    required String content,
    bool pinned = false,
  }) async {
    final i = memories.indexWhere((m) => m.name == name);
    if (i >= 0) {
      // UPDATE keeps pinned/source (F147) — the incoming pinned is dropped, mirroring the backend.
      // 更新保留 pinned/source(F147),传入 pinned 丢弃,与后端一致。
      return memories[i] = memories[i].copyWith(
        description: description,
        content: content,
      );
    }
    // CREATE honors pinned; source is user-authored (mirrors the Live PUT body). 建时应用 pinned;source=user。
    final m = Memory(
      name: name,
      description: description,
      content: content,
      pinned: pinned,
      source: 'user',
    );
    memories.add(m);
    return m;
  }

  @override
  Future<Memory> pinMemory(String name, {required bool pinned}) async {
    final i = memories.indexWhere((m) => m.name == name);
    return memories[i] = memories[i].copyWith(pinned: pinned);
  }

  @override
  Future<void> deleteMemory(String name) async =>
      memories.removeWhere((m) => m.name == name);

  // ── S4b MCP (scriptable) ──

  final List<McpServerStatus> mcpServers = [];
  final List<McpRegistryEntry> mcpRegistry = [];
  McpRegistryPlan mcpPlan = const McpRegistryPlan(transport: 'stdio');

  /// Script hook: what PUT/install lands as (honest failed faces). 脚本钩:落盘态。
  String nextMcpStatus = 'ready';

  /// Script hook: throw on the next registry install (the in-card honest failure path — market card
  /// shows the red line). 脚本钩:下次市场安装抛错(卡上红句诚实态测试)。
  Object? failNextMcpInstall;

  @override
  Future<List<McpServerStatus>> listMcpServers() async => List.of(mcpServers);

  @override
  Future<McpServerStatus> getMcpServer(String name) async =>
      mcpServers.firstWhere((s) => s.name == name);

  @override
  Future<McpServerStatus> putMcpServer(
    String name,
    Map<String, dynamic> config,
  ) async {
    final row = McpServerStatus(
      id: 'mcp_fix${mcpServers.length}',
      name: name,
      status: nextMcpStatus,
      lastError: nextMcpStatus == 'failed' ? 'connect refused' : null,
    );
    mcpServers.removeWhere((s) => s.name == name);
    mcpServers.add(row);
    return row;
  }

  @override
  Future<void> deleteMcpServer(String name) async =>
      mcpServers.removeWhere((s) => s.name == name);

  @override
  Future<McpServerStatus> reconnectMcpServer(String name) async {
    final i = mcpServers.indexWhere((s) => s.name == name);
    return mcpServers[i] = mcpServers[i].copyWith(status: nextMcpStatus);
  }

  @override
  Future<String> mcpStderr(String name) async => '';

  @override
  Future<
    ({List<McpCall> calls, int okCount, int failedCount, String? nextCursor})
  >
  listMcpCalls(String name, {String? cursor}) async =>
      (calls: <McpCall>[], okCount: 0, failedCount: 0, nextCursor: null);

  @override
  Future<List<McpRegistryEntry>> listMcpRegistry() async =>
      List.of(mcpRegistry);

  @override
  Future<McpRegistryPlan> planMcpInstall(String fullName) async => mcpPlan;

  @override
  Future<McpServerStatus> installMcp(
    String fullName,
    Map<String, String> env,
  ) async {
    final f = failNextMcpInstall;
    if (f != null) {
      failNextMcpInstall = null;
      throw f is Exception ? f : StateError('$f');
    }
    final short = fullName.split('/').last;
    final row = McpServerStatus(
      id: 'mcp_fix${mcpServers.length}',
      name: short,
      status: nextMcpStatus,
    );
    mcpServers.add(row);
    return row;
  }

  @override
  Future<({List<String> imported, List<String> skipped})> importMcpJson(
    String json, {
    bool overwrite = false,
  }) async {
    final map =
        (jsonDecode(json) as Map<String, dynamic>)['mcpServers']
            as Map<String, dynamic>? ??
        {};
    final imported = <String>[], skipped = <String>[];
    for (final name in map.keys) {
      if (!overwrite && mcpServers.any((s) => s.name == name)) {
        skipped.add(name);
        continue;
      }
      await putMcpServer(name, const {});
      imported.add(name);
    }
    return (imported: imported, skipped: skipped);
  }

  // ── S5 (scriptable) ──

  String fixtureDataDir = '/tmp/anselm-fixture';
  int fixtureDisk = 42 * 1024 * 1024;
  List<LimitField> fixtureSchema = const [
    LimitField(
      key: 'agent.maxSteps',
      group: 'agent',
      defaultValue: 30,
      min: 1,
      unit: 'steps',
      desc: 'Max steps.',
    ),
    LimitField(
      key: 'context.triggerRatio',
      group: 'context',
      defaultValue: 0.8,
      min: 0,
      max: 1,
      exclusive: true,
      unit: 'ratio',
      desc: 'Compaction trigger.',
    ),
  ];
  Map<String, dynamic> fixtureLimits = {
    'agent': {'maxSteps': 30},
    'context': {'triggerRatio': 0.8},
  };

  @override
  Future<String> dataDir() async => fixtureDataDir;

  @override
  Future<int> sandboxDiskUsage() async => fixtureDisk;

  /// Scriptable DB size + dead space (demo + tests). Compact hands the dead bytes back and clears
  /// them, so a re-read shows the shrunk file — the panel's before/after story.
  /// 可脚本的库大小 + 死空间(demo/测试)。压缩把死字节还回并清零,重读即见缩小的文件——面板的前后故事。
  int fixtureDbBytes = 120 * 1024 * 1024;
  int fixtureDeadBytes = 48 * 1024 * 1024;

  /// Script hook: throw on the next compact (disk-full error-path tests). 脚本钩:下次压缩抛错。
  bool failNextCompact = false;

  /// Script hook: when set, compact awaits it before resolving — lets a test observe the busy state
  /// (VACUUM locks the DB a few seconds in reality). 脚本钩:设置后压缩先等它再落定,供测试观察忙态。
  Completer<void>? compactGate;

  @override
  Future<({int dbBytes, int deadBytes})> storageStat() async =>
      (dbBytes: fixtureDbBytes, deadBytes: fixtureDeadBytes);

  @override
  Future<({int reclaimedBytes, bool migrated})> compactStorage() async {
    if (compactGate != null) await compactGate!.future;
    if (failNextCompact) {
      failNextCompact = false;
      throw const ApiException(
        code: 'STORAGE_COMPACT_FAILED',
        message:
            'database compaction failed (VACUUM needs free scratch space roughly the size of the database)',
        httpStatus: 500,
      );
    }
    final reclaimed = fixtureDeadBytes;
    fixtureDbBytes -= reclaimed;
    fixtureDeadBytes = 0;
    return (reclaimedBytes: reclaimed, migrated: false);
  }

  @override
  Future<Map<String, dynamic>> getLimits() async => fixtureLimits;

  @override
  Future<List<LimitField>> limitsSchema() async => fixtureSchema;

  @override
  Future<Map<String, dynamic>> patchLimits(Map<String, dynamic> partial) async {
    void merge(Map<String, dynamic> into, Map<String, dynamic> from) {
      from.forEach((k, v) {
        if (v is Map<String, dynamic> && into[k] is Map<String, dynamic>) {
          merge(into[k] as Map<String, dynamic>, v);
        } else {
          into[k] = v;
        }
      });
    }

    merge(fixtureLimits, partial);
    return fixtureLimits;
  }

  @override
  Future<Map<String, dynamic>> resetLimits() async {
    fixtureLimits = {
      'agent': {'maxSteps': 30},
      'context': {'triggerRatio': 0.8},
    };
    return fixtureLimits;
  }

  NetworkConfig fixtureNetwork = const NetworkConfig();

  @override
  Future<NetworkConfig> getNetwork() async => fixtureNetwork;

  @override
  Future<NetworkConfig> patchNetwork(NetworkConfig config) async =>
      fixtureNetwork = config;

  /// Seeded at the BACKEND's own default (90), not at a number invented here — the panel's whole
  /// contract is «never hardcode a default», and a fixture that seeded 30 would let a panel bug that
  /// hardcodes 90 pass anyway. 种在**后端自持**的默认(90)上,而非此处发明的数——面板的全部契约就是
  /// 「永不硬编默认」,而种 30 的 fixture 会让「硬编 90」的面板 bug 照样通过。
  RetentionConfig fixtureRetention = const RetentionConfig(
    runRetentionDays: 90,
  );

  @override
  Future<RetentionConfig> getRetention() async => fixtureRetention;

  @override
  Future<RetentionConfig> patchRetention(int days) async {
    // Mirror the backend's ONE physical rule: a negative line is rejected; 60 is accepted (the value
    // set is a product affordance, not a backend rule — 反校验剧场 #6).
    // 镜像后端唯一的物理规则:负数拒;60 照收(值集是产品可供性、非后端规则——反校验剧场 #6)。
    if (days < 0) {
      throw const ApiException(
        code: 'SETTINGS_RETENTION_INVALID',
        message:
            'runRetentionDays must be 0 (keep forever) or a positive number of days',
        httpStatus: 400,
      );
    }
    return fixtureRetention = RetentionConfig(runRetentionDays: days);
  }

  // ── S5 sandbox (scriptable) ──

  SandboxBootstrap fixtureBootstrap = const SandboxBootstrap(ok: true);
  final List<SandboxRuntime> runtimes = [];
  List<RuntimeAvailability> available = const [
    RuntimeAvailability(
      kind: 'node',
      defaultVersion: '22',
      versions: ['22', '20'],
      pinned: true,
    ),
    RuntimeAvailability(
      kind: 'python',
      defaultVersion: '3.12',
      versions: ['3.12', '3.11'],
      pinned: true,
    ),
  ];
  final Map<String, List<SandboxEnv>> envsByOwner = {};
  int gcRemoved = 3;
  String? failNextRuntimeDelete;

  @override
  Future<SandboxBootstrap> sandboxBootstrap() async => fixtureBootstrap;

  @override
  Future<void> retrySandboxBootstrap() async =>
      fixtureBootstrap = const SandboxBootstrap(ok: true);

  @override
  Future<List<SandboxRuntime>> sandboxRuntimes() async => List.of(runtimes);

  @override
  Future<List<RuntimeAvailability>> sandboxAvailable() async => available;

  @override
  Future<SandboxRuntime> installRuntime({
    required String kind,
    required String version,
  }) async {
    final r = SandboxRuntime(
      id: 'srt_fix${runtimes.length}',
      kind: kind,
      version: version,
    );
    runtimes.add(r);
    return r;
  }

  @override
  Future<void> deleteRuntime(String id) async {
    if (failNextRuntimeDelete != null) {
      final code = failNextRuntimeDelete!;
      failNextRuntimeDelete = null;
      throw ApiException(code: code, message: 'scripted', httpStatus: 409);
    }
    runtimes.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<SandboxEnv>> sandboxEnvs(String ownerKind) async =>
      envsByOwner[ownerKind] ?? const [];

  @override
  Future<void> deleteEnv(String id) async =>
      envsByOwner.forEach((_, list) => list.removeWhere((e) => e.id == id));

  @override
  Future<int> sandboxGc(int olderThanDays) async => gcRemoved;
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return LiveSettingsRepository(
    api: api,
    workspaceId: () => ref.read(activeWorkspaceProvider),
  );
});
