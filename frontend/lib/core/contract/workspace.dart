import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

/// A model selection (which API key + which model id + provider options). The backend's
/// `model.ModelRef`; carried by a workspace's three scenario defaults.
///
/// 一个模型选择(哪个 API key + 哪个 model id + provider 选项)。后端 `model.ModelRef`;
/// 由 workspace 三场景默认携带。
@freezed
abstract class ModelRef with _$ModelRef {
  const factory ModelRef({
    required String apiKeyId,
    required String modelId,
    @Default(<String, String>{}) Map<String, String> options,
  }) = _ModelRef;

  factory ModelRef.fromJson(Map<String, dynamic> json) =>
      _$ModelRefFromJson(json);
}

/// The local isolation unit — and the only auth axis (no accounts; the active workspace
/// id rides every request as `X-Anselm-Workspace-ID`). Every entity DTO is a backend
/// projection living here in core/contract (the client has no domain/use-case layer per
/// ADR 0004): camelCase wire ↔ json_serializable, no rename maps. Mirrors backend
/// `workspace.Workspace`.
///
/// 本地隔离单元——也是唯一鉴权轴(无账号;活动 workspace id 经 `X-Anselm-Workspace-ID` 随每请求)。
/// 每个实体 DTO 都是后端投影,统一住在 core/contract(客户端无 domain/use-case 层,见 ADR 0004):
/// camelCase 线缆 ↔ json_serializable、无重命名表。镜像后端 `workspace.Workspace`。
@freezed
abstract class Workspace with _$Workspace {
  const factory Workspace({
    required String id,
    required String name,
    String? avatarColor,
    required String language,
    ModelRef? defaultDialogue,
    ModelRef? defaultUtility,
    ModelRef? defaultAgent,
    String? defaultSearchKeyId,
    String? webFetchMode, // local | jina
    DateTime? lastUsedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}

/// One workspace's content inventory — `GET /workspaces/{id}/stats` (the delete confirmation's real
/// numbers, WRK-062 S-11). blobBytes == -1 means the walk blew its budget (honest unknown).
/// 一个 workspace 的内容盘点(删除确认的真数字);blobBytes==-1=超预算的诚实未知。
@freezed
abstract class WorkspaceStats with _$WorkspaceStats {
  const factory WorkspaceStats({
    @Default(0) int conversations,
    @Default(0) int functions,
    @Default(0) int handlers,
    @Default(0) int agents,
    @Default(0) int workflows,
    @Default(0) int documents,
    @Default(0) int runningFlowruns,
    @Default(0) int generatingConversations,
    @Default(0) int blobBytes,
  }) = _WorkspaceStats;

  factory WorkspaceStats.fromJson(Map<String, dynamic> json) => _$WorkspaceStatsFromJson(json);
}
