import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp.freezed.dart';
part 'mcp.g.dart';

/// MCP wire contracts (references/backend/domains/mcp.md). [McpServerStatus] is pure RUNTIME state —
/// config (url/env/transport…) is write-only (encrypted at rest, never echoed); status is memory
/// truth (a backend restart resets every server to disconnected, so lists refetch on SSE reconnect).
///
/// MCP 线上契约。ServerStatus 是纯运行态——配置只写不回(落盘加密);状态是内存真相(后端重启全回
/// disconnected,列表在 SSE 重连后强制重取)。
@freezed
abstract class McpServerStatus with _$McpServerStatus {
  const factory McpServerStatus({
    required String id,
    required String name,
    @Default('disconnected') String status, // disconnected|connecting|ready|degraded|failed
    DateTime? connectedAt,
    String? lastError,
    DateTime? lastErrorAt,
    @Default(0) int consecutiveFailures,
    @Default(0) int totalCalls,
    @Default(0) int totalFailures,
    @Default([]) List<McpToolDef> tools,
  }) = _McpServerStatus;

  factory McpServerStatus.fromJson(Map<String, dynamic> json) =>
      _$McpServerStatusFromJson(json);
}

@freezed
abstract class McpToolDef with _$McpToolDef {
  const factory McpToolDef({
    @Default('') String serverName,
    required String name,
    @Default('') String description,
    Map<String, dynamic>? inputSchema,
  }) = _McpToolDef;

  factory McpToolDef.fromJson(Map<String, dynamic> json) => _$McpToolDefFromJson(json);
}

/// One curated marketplace entry — the LIST projection (env/plan detail comes from :plan, 工单⑨;
/// the wire has no installed flag — the panel matches short names against /mcp-servers itself).
/// 市场条目列表投影(env/计划细节走 :plan;线上无 installed 标——面板自己按短名比对)。
@freezed
abstract class McpRegistryEntry with _$McpRegistryEntry {
  const factory McpRegistryEntry({
    required String name, // full slug e.g. io.github.upstash/context7 完整 slug
    @Default('') String description,
    @Default('') String prerequisite,
  }) = _McpRegistryEntry;

  factory McpRegistryEntry.fromJson(Map<String, dynamic> json) =>
      _$McpRegistryEntryFromJson(json);
}

/// The install plan (`POST /mcp-registry:plan`) — how the backend WOULD install this entry and
/// exactly which env vars to collect. 安装计划:后端会怎么装+要收集哪些 env。
@freezed
abstract class McpRegistryPlan with _$McpRegistryPlan {
  const factory McpRegistryPlan({
    required String transport,
    @Default('') String runtime,
    @Default(false) bool oauth,
    @Default([]) List<McpEnvVar> envVars,
    @Default('') String prerequisite,
  }) = _McpRegistryPlan;

  factory McpRegistryPlan.fromJson(Map<String, dynamic> json) =>
      _$McpRegistryPlanFromJson(json);
}

@freezed
abstract class McpEnvVar with _$McpEnvVar {
  const factory McpEnvVar({
    required String name,
    @Default('') String description,
    @Default(false) bool isSecret,
    @Default(false) bool required,
  }) = _McpEnvVar;

  factory McpEnvVar.fromJson(Map<String, dynamic> json) => _$McpEnvVarFromJson(json);
}

/// One call-log row (`GET /mcp-servers/{name}/calls`; only `GET /mcp-calls/{id}` carries logs).
/// 调用日志行(仅单读带 logs)。
@freezed
abstract class McpCall with _$McpCall {
  const factory McpCall({
    required String id,
    @Default('') String serverId,
    @Default('') String tool,
    @Default('') String status, // ok|failed|cancelled|timeout
    @Default('') String triggeredBy, // chat|agent|workflow|manual
    String? errorMessage,
    @Default(0) int elapsedMs,
    DateTime? startedAt,
    DateTime? createdAt,
  }) = _McpCall;

  factory McpCall.fromJson(Map<String, dynamic> json) => _$McpCallFromJson(json);
}
