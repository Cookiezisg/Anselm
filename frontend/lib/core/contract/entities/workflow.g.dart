// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WorkflowEntity _$WorkflowEntityFromJson(Map<String, dynamic> json) =>
    _WorkflowEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
      active: json['active'] as bool? ?? false,
      lifecycleState: json['lifecycleState'] as String? ?? '',
      concurrency: json['concurrency'] as String? ?? 'serial',
      needsAttention: json['needsAttention'] as bool? ?? false,
      attentionReason: json['attentionReason'] as String?,
      lastActionBy: json['lastActionBy'] as String? ?? '',
      activeVersionId: json['activeVersionId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      activeVersion: json['activeVersion'] == null
          ? null
          : WorkflowVersion.fromJson(
              json['activeVersion'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$WorkflowEntityToJson(_WorkflowEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'tags': instance.tags,
      'active': instance.active,
      'lifecycleState': instance.lifecycleState,
      'concurrency': instance.concurrency,
      'needsAttention': instance.needsAttention,
      'attentionReason': instance.attentionReason,
      'lastActionBy': instance.lastActionBy,
      'activeVersionId': instance.activeVersionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'activeVersion': instance.activeVersion?.toJson(),
    };

_WorkflowVersion _$WorkflowVersionFromJson(Map<String, dynamic> json) =>
    _WorkflowVersion(
      id: json['id'] as String,
      workflowId: json['workflowId'] as String,
      version: (json['version'] as num).toInt(),
      graph: json['graph'] as String? ?? '',
      changeReason: json['changeReason'] as String?,
      builtInConversationId: json['builtInConversationId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      graphParsed: json['graphParsed'] == null
          ? null
          : Graph.fromJson(json['graphParsed'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WorkflowVersionToJson(_WorkflowVersion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workflowId': instance.workflowId,
      'version': instance.version,
      'graph': instance.graph,
      'changeReason': instance.changeReason,
      'builtInConversationId': instance.builtInConversationId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'graphParsed': instance.graphParsed?.toJson(),
    };

_Flowrun _$FlowrunFromJson(Map<String, dynamic> json) => _Flowrun(
  id: json['id'] as String,
  workflowId: json['workflowId'] as String,
  versionId: json['versionId'] as String? ?? '',
  pinnedRefs:
      (json['pinnedRefs'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  triggerId: json['triggerId'] as String?,
  firingId: json['firingId'] as String?,
  status: json['status'] as String? ?? '',
  replayCount: (json['replayCount'] as num?)?.toInt() ?? 0,
  error: json['error'] as String?,
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$FlowrunToJson(_Flowrun instance) => <String, dynamic>{
  'id': instance.id,
  'workflowId': instance.workflowId,
  'versionId': instance.versionId,
  'pinnedRefs': instance.pinnedRefs,
  'triggerId': instance.triggerId,
  'firingId': instance.firingId,
  'status': instance.status,
  'replayCount': instance.replayCount,
  'error': instance.error,
  'startedAt': instance.startedAt?.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

_FlowrunNode _$FlowrunNodeFromJson(Map<String, dynamic> json) => _FlowrunNode(
  id: json['id'] as String,
  flowrunId: json['flowrunId'] as String,
  nodeId: json['nodeId'] as String,
  iteration: (json['iteration'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? '',
  ref: json['ref'] as String? ?? '',
  status: json['status'] as String? ?? '',
  result: json['result'] as Map<String, dynamic>? ?? const <String, Object?>{},
  error: json['error'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$FlowrunNodeToJson(_FlowrunNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'flowrunId': instance.flowrunId,
      'nodeId': instance.nodeId,
      'iteration': instance.iteration,
      'kind': instance.kind,
      'ref': instance.ref,
      'status': instance.status,
      'result': instance.result,
      'error': instance.error,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_FlowrunNodeSummary _$FlowrunNodeSummaryFromJson(Map<String, dynamic> json) =>
    _FlowrunNodeSummary(
      totalNodes: (json['totalNodes'] as num?)?.toInt() ?? 0,
      shownNodes: (json['shownNodes'] as num?)?.toInt() ?? 0,
      byStatus:
          (json['byStatus'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      note: json['note'] as String? ?? '',
    );

Map<String, dynamic> _$FlowrunNodeSummaryToJson(_FlowrunNodeSummary instance) =>
    <String, dynamic>{
      'totalNodes': instance.totalNodes,
      'shownNodes': instance.shownNodes,
      'byStatus': instance.byStatus,
      'note': instance.note,
    };

_FlowrunComposite _$FlowrunCompositeFromJson(Map<String, dynamic> json) =>
    _FlowrunComposite(
      flowrun: Flowrun.fromJson(json['flowrun'] as Map<String, dynamic>),
      nodes:
          (json['nodes'] as List<dynamic>?)
              ?.map((e) => FlowrunNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <FlowrunNode>[],
      nextCursor: json['nextCursor'] as String?,
      nodeSummary: json['nodeSummary'] == null
          ? null
          : FlowrunNodeSummary.fromJson(
              json['nodeSummary'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$FlowrunCompositeToJson(_FlowrunComposite instance) =>
    <String, dynamic>{
      'flowrun': instance.flowrun.toJson(),
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
      'nextCursor': instance.nextCursor,
      'nodeSummary': instance.nodeSummary?.toJson(),
    };
