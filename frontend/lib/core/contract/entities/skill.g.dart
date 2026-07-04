// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Skill _$SkillFromJson(Map<String, dynamic> json) => _Skill(
  name: json['name'] as String,
  description: json['description'] as String? ?? '',
  source: json['source'] as String? ?? '',
  context: json['context'] as String? ?? '',
  body: json['body'] as String? ?? '',
  frontmatter: json['frontmatter'] == null
      ? const Frontmatter()
      : Frontmatter.fromJson(json['frontmatter'] as Map<String, dynamic>),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SkillToJson(_Skill instance) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'source': instance.source,
  'context': instance.context,
  'body': instance.body,
  'frontmatter': instance.frontmatter.toJson(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

_Frontmatter _$FrontmatterFromJson(Map<String, dynamic> json) => _Frontmatter(
  name: json['name'] as String? ?? '',
  description: json['description'] as String? ?? '',
  allowedTools:
      (json['allowedTools'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  context: json['context'] as String? ?? '',
  agent: json['agent'] as String? ?? '',
  arguments:
      (json['arguments'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  disableModelInvocation: json['disableModelInvocation'] as bool? ?? false,
  userInvocable: json['userInvocable'] as bool? ?? false,
  whenToUse: json['whenToUse'] as String? ?? '',
  model: json['model'] as String? ?? '',
  effort: json['effort'] as String? ?? '',
  source: json['source'] as String? ?? '',
);

Map<String, dynamic> _$FrontmatterToJson(_Frontmatter instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'allowedTools': instance.allowedTools,
      'context': instance.context,
      'agent': instance.agent,
      'arguments': instance.arguments,
      'disableModelInvocation': instance.disableModelInvocation,
      'userInvocable': instance.userInvocable,
      'whenToUse': instance.whenToUse,
      'model': instance.model,
      'effort': instance.effort,
      'source': instance.source,
    };
