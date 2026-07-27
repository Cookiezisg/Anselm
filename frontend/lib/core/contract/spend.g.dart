// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spend.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SpendRow _$SpendRowFromJson(Map<String, dynamic> json) => _SpendRow(
  date: json['date'] as String? ?? '',
  category: json['category'] as String? ?? '',
  provider: json['provider'] as String? ?? '',
  model: json['model'] as String? ?? '',
  units: (json['units'] as num?)?.toInt() ?? 0,
  estPUSD: (json['estPUSD'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SpendRowToJson(_SpendRow instance) => <String, dynamic>{
  'date': instance.date,
  'category': instance.category,
  'provider': instance.provider,
  'model': instance.model,
  'units': instance.units,
  'estPUSD': instance.estPUSD,
};
