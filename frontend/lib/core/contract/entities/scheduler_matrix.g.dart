// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduler_matrix.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MatrixCol _$MatrixColFromJson(Map<String, dynamic> json) => _MatrixCol(
  flowrunId: json['flowrunId'] as String? ?? '',
  startedAt: DateTime.parse(json['startedAt'] as String),
  status: json['status'] as String? ?? '',
  elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$MatrixColToJson(_MatrixCol instance) =>
    <String, dynamic>{
      'flowrunId': instance.flowrunId,
      'startedAt': instance.startedAt.toIso8601String(),
      'status': instance.status,
      'elapsedMs': instance.elapsedMs,
    };

_MatrixRow _$MatrixRowFromJson(Map<String, dynamic> json) => _MatrixRow(
  nodeId: json['nodeId'] as String? ?? '',
  kind: json['kind'] as String? ?? '',
);

Map<String, dynamic> _$MatrixRowToJson(_MatrixRow instance) =>
    <String, dynamic>{'nodeId': instance.nodeId, 'kind': instance.kind};

_MatrixCell _$MatrixCellFromJson(Map<String, dynamic> json) => _MatrixCell(
  flowrunId: json['flowrunId'] as String? ?? '',
  nodeId: json['nodeId'] as String? ?? '',
  status: json['status'] as String? ?? '',
  iteration: (json['iteration'] as num?)?.toInt() ?? 0,
  iterations: (json['iterations'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$MatrixCellToJson(_MatrixCell instance) =>
    <String, dynamic>{
      'flowrunId': instance.flowrunId,
      'nodeId': instance.nodeId,
      'status': instance.status,
      'iteration': instance.iteration,
      'iterations': instance.iterations,
    };

_FlowrunMatrix _$FlowrunMatrixFromJson(Map<String, dynamic> json) =>
    _FlowrunMatrix(
      cols:
          (json['cols'] as List<dynamic>?)
              ?.map((e) => MatrixCol.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MatrixCol>[],
      rows:
          (json['rows'] as List<dynamic>?)
              ?.map((e) => MatrixRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MatrixRow>[],
      cells:
          (json['cells'] as List<dynamic>?)
              ?.map((e) => MatrixCell.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MatrixCell>[],
    );

Map<String, dynamic> _$FlowrunMatrixToJson(_FlowrunMatrix instance) =>
    <String, dynamic>{
      'cols': instance.cols.map((e) => e.toJson()).toList(),
      'rows': instance.rows.map((e) => e.toJson()).toList(),
      'cells': instance.cells.map((e) => e.toJson()).toList(),
    };
