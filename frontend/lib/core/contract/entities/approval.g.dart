// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'approval.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApprovalForm _$ApprovalFormFromJson(Map<String, dynamic> json) =>
    _ApprovalForm(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      activeVersionId: json['activeVersionId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      activeVersion: json['activeVersion'] == null
          ? null
          : ApprovalVersion.fromJson(
              json['activeVersion'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$ApprovalFormToJson(_ApprovalForm instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'activeVersionId': instance.activeVersionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'activeVersion': instance.activeVersion?.toJson(),
    };

_ApprovalVersion _$ApprovalVersionFromJson(Map<String, dynamic> json) =>
    _ApprovalVersion(
      id: json['id'] as String,
      approvalId: json['approvalId'] as String,
      version: (json['version'] as num).toInt(),
      inputs:
          (json['inputs'] as List<dynamic>?)
              ?.map((e) => Field.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Field>[],
      template: json['template'] as String? ?? '',
      allowReason: json['allowReason'] as bool? ?? false,
      timeout: json['timeout'] as String? ?? '',
      timeoutBehavior: json['timeoutBehavior'] as String? ?? '',
      changeReason: json['changeReason'] as String?,
      builtInConversationId: json['builtInConversationId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ApprovalVersionToJson(_ApprovalVersion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'approvalId': instance.approvalId,
      'version': instance.version,
      'inputs': instance.inputs.map((e) => e.toJson()).toList(),
      'template': instance.template,
      'allowReason': instance.allowReason,
      'timeout': instance.timeout,
      'timeoutBehavior': instance.timeoutBehavior,
      'changeReason': instance.changeReason,
      'builtInConversationId': instance.builtInConversationId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
