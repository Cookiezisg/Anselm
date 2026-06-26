// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'values.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Field _$FieldFromJson(Map<String, dynamic> json) => _Field(
  name: json['name'] as String,
  type: json['type'] as String,
  description: json['description'] as String?,
);

Map<String, dynamic> _$FieldToJson(_Field instance) => <String, dynamic>{
  'name': instance.name,
  'type': instance.type,
  'description': instance.description,
};

_ToolRef _$ToolRefFromJson(Map<String, dynamic> json) =>
    _ToolRef(ref: json['ref'] as String, name: json['name'] as String);

Map<String, dynamic> _$ToolRefToJson(_ToolRef instance) => <String, dynamic>{
  'ref': instance.ref,
  'name': instance.name,
};

_MethodSpec _$MethodSpecFromJson(Map<String, dynamic> json) => _MethodSpec(
  name: json['name'] as String,
  description: json['description'] as String?,
  inputs:
      (json['inputs'] as List<dynamic>?)
          ?.map((e) => Field.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Field>[],
  outputs:
      (json['outputs'] as List<dynamic>?)
          ?.map((e) => Field.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Field>[],
  body: json['body'] as String? ?? '',
  streaming: json['streaming'] as bool? ?? false,
  timeout: (json['timeout'] as num?)?.toInt(),
);

Map<String, dynamic> _$MethodSpecToJson(_MethodSpec instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'inputs': instance.inputs.map((e) => e.toJson()).toList(),
      'outputs': instance.outputs.map((e) => e.toJson()).toList(),
      'body': instance.body,
      'streaming': instance.streaming,
      'timeout': instance.timeout,
    };

_InitArgSpec _$InitArgSpecFromJson(Map<String, dynamic> json) => _InitArgSpec(
  name: json['name'] as String,
  type: json['type'] as String,
  description: json['description'] as String?,
  required: json['required'] as bool? ?? false,
  sensitive: json['sensitive'] as bool? ?? false,
  defaultValue: json['default'],
);

Map<String, dynamic> _$InitArgSpecToJson(_InitArgSpec instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'description': instance.description,
      'required': instance.required,
      'sensitive': instance.sensitive,
      'default': instance.defaultValue,
    };

_NodePosition _$NodePositionFromJson(Map<String, dynamic> json) =>
    _NodePosition(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$NodePositionToJson(_NodePosition instance) =>
    <String, dynamic>{'x': instance.x, 'y': instance.y};

_RetryConfig _$RetryConfigFromJson(Map<String, dynamic> json) => _RetryConfig(
  maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 0,
  backoff: json['backoff'] as String?,
  delayMs: (json['delayMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$RetryConfigToJson(_RetryConfig instance) =>
    <String, dynamic>{
      'maxAttempts': instance.maxAttempts,
      'backoff': instance.backoff,
      'delayMs': instance.delayMs,
    };

_Edge _$EdgeFromJson(Map<String, dynamic> json) => _Edge(
  id: json['id'] as String,
  from: json['from'] as String,
  fromPort: json['fromPort'] as String?,
  to: json['to'] as String,
);

Map<String, dynamic> _$EdgeToJson(_Edge instance) => <String, dynamic>{
  'id': instance.id,
  'from': instance.from,
  'fromPort': instance.fromPort,
  'to': instance.to,
};

_Node _$NodeFromJson(Map<String, dynamic> json) => _Node(
  id: json['id'] as String,
  kind: $enumDecode(
    _$NodeKindEnumMap,
    json['kind'],
    unknownValue: NodeKind.unknown,
  ),
  ref: json['ref'] as String? ?? '',
  input:
      (json['input'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  retry: json['retry'] == null
      ? null
      : RetryConfig.fromJson(json['retry'] as Map<String, dynamic>),
  pos: json['pos'] == null
      ? null
      : NodePosition.fromJson(json['pos'] as Map<String, dynamic>),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$NodeToJson(_Node instance) => <String, dynamic>{
  'id': instance.id,
  'kind': _$NodeKindEnumMap[instance.kind]!,
  'ref': instance.ref,
  'input': instance.input,
  'retry': instance.retry?.toJson(),
  'pos': instance.pos?.toJson(),
  'notes': instance.notes,
};

const _$NodeKindEnumMap = {
  NodeKind.trigger: 'trigger',
  NodeKind.action: 'action',
  NodeKind.agent: 'agent',
  NodeKind.control: 'control',
  NodeKind.approval: 'approval',
  NodeKind.unknown: 'unknown',
};

_Graph _$GraphFromJson(Map<String, dynamic> json) => _Graph(
  nodes:
      (json['nodes'] as List<dynamic>?)
          ?.map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Node>[],
  edges:
      (json['edges'] as List<dynamic>?)
          ?.map((e) => Edge.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Edge>[],
);

Map<String, dynamic> _$GraphToJson(_Graph instance) => <String, dynamic>{
  'nodes': instance.nodes.map((e) => e.toJson()).toList(),
  'edges': instance.edges.map((e) => e.toJson()).toList(),
};
