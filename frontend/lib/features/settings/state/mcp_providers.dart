import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/mcp.dart';
import '../../../core/runtime.dart';
import '../../../core/sse/sse_gateway.dart';
import '../data/settings_repository.dart';

/// The MCP server roster (WRK-062 S4-⑤). Status is MEMORY truth server-side, so this list NEVER
/// trusts frame payloads: any `mcp` frame on the entities stream (status flips are ephemeral
/// signals) just schedules ONE refetch behind a 300ms coalescer — a burst of transitions costs one
/// round trip. A stream resync (410) also forces a refetch (a backend restart reset every server
/// to disconnected). Mutations refetch inline.
///
/// MCP 名册(S4-⑤)。状态是服务端内存真相——本列表**绝不信帧内容**:entities 流上任何 mcp 帧只在 300ms
/// 去抖后约一次重取(一阵状态翻转=一次往返);流 resync(410)也强制重取(后端重启全回 disconnected)。
class McpServersController extends AsyncNotifier<List<McpServerStatus>> {
  Timer? _coalesce;

  @override
  Future<List<McpServerStatus>> build() {
    final repo = ref.watch(settingsRepositoryProvider);
    final gw = ref.watch(sseGatewayProvider);
    if (gw != null) {
      final frames = gw
          .kindStream(StreamName.entities, 'mcp')
          .listen((_) => _schedule());
      final resync = gw.resync(StreamName.entities).listen((_) => _schedule());
      ref.onDispose(() {
        frames.cancel();
        resync.cancel();
        _coalesce?.cancel();
      });
    }
    return repo.listMcpServers();
  }

  void _schedule() {
    _coalesce?.cancel();
    // 批7 立法1 豁免锚:state 层合帧节流。exempt: state-layer coalescing.
    _coalesce = Timer(const Duration(milliseconds: 300), refresh);
  }

  Future<void> refresh() async {
    final rows = await ref.read(settingsRepositoryProvider).listMcpServers();
    if (ref.mounted) state = AsyncData(rows);
  }

  Future<McpServerStatus> put(String name, Map<String, dynamic> config) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .putMcpServer(name, config);
    await refresh();
    return row;
  }

  Future<void> remove(String name) async {
    await ref.read(settingsRepositoryProvider).deleteMcpServer(name);
    await refresh();
  }

  Future<McpServerStatus> reconnect(String name) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .reconnectMcpServer(name);
    await refresh();
    return row;
  }

  Future<McpServerStatus> install(
    String fullName,
    Map<String, String> env,
  ) async {
    final row = await ref
        .read(settingsRepositoryProvider)
        .installMcp(fullName, env);
    await refresh();
    return row;
  }

  Future<({List<String> imported, List<String> skipped})> importJson(
    String json, {
    bool overwrite = false,
  }) async {
    final r = await ref
        .read(settingsRepositoryProvider)
        .importMcpJson(json, overwrite: overwrite);
    await refresh();
    return r;
  }
}

final mcpServersProvider =
    AsyncNotifierProvider<McpServersController, List<McpServerStatus>>(
      McpServersController.new,
    );

/// The curated marketplace (bounded; search is client-side — the endpoint takes no query).
/// 市场目录(有界;搜索纯前端——端点无参数)。
final mcpRegistryProvider = FutureProvider<List<McpRegistryEntry>>(
  (ref) => ref.watch(settingsRepositoryProvider).listMcpRegistry(),
);

/// One entry's install plan (工单⑨) — fetched when its form opens. 安装计划;表单打开时取。
final mcpPlanProvider = FutureProvider.autoDispose
    .family<McpRegistryPlan, String>(
      (ref, fullName) =>
          ref.watch(settingsRepositoryProvider).planMcpInstall(fullName),
    );

/// The 256KB stderr tail — detail tab, refetched on open. stderr 尾;详情页打开时取。
final mcpStderrProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, name) => ref.watch(settingsRepositoryProvider).mcpStderr(name),
);

/// The first call-log page + aggregates. 调用日志首页+聚合。
final mcpCallsProvider = FutureProvider.autoDispose
    .family<
      ({List<McpCall> calls, int okCount, int failedCount, String? nextCursor}),
      String
    >((ref, name) => ref.watch(settingsRepositoryProvider).listMcpCalls(name));
