import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return LiveSettingsRepository(api: api, workspaceId: () => ref.read(activeWorkspaceProvider));
});
