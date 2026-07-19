// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NetworkConfig _$NetworkConfigFromJson(Map<String, dynamic> json) =>
    _NetworkConfig(
      httpProxy: json['httpProxy'] as String? ?? '',
      httpsProxy: json['httpsProxy'] as String? ?? '',
      noProxy: json['noProxy'] as String? ?? '',
    );

Map<String, dynamic> _$NetworkConfigToJson(_NetworkConfig instance) =>
    <String, dynamic>{
      'httpProxy': instance.httpProxy,
      'httpsProxy': instance.httpsProxy,
      'noProxy': instance.noProxy,
    };
