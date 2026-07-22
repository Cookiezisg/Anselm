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
  provenance: json['provenance'] == null
      ? null
      : Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SkillToJson(_Skill instance) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'source': instance.source,
  'context': instance.context,
  'body': instance.body,
  'frontmatter': instance.frontmatter.toJson(),
  'provenance': instance.provenance?.toJson(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

_Provenance _$ProvenanceFromJson(Map<String, dynamic> json) => _Provenance(
  source: json['source'] as String? ?? '',
  repo: json['repo'] as String? ?? '',
  ref: json['ref'] as String? ?? '',
  subdir: json['subdir'] as String? ?? '',
  installedAt: json['installedAt'] == null
      ? null
      : DateTime.parse(json['installedAt'] as String),
  toolsApproved: json['toolsApproved'] as bool? ?? false,
);

Map<String, dynamic> _$ProvenanceToJson(_Provenance instance) =>
    <String, dynamic>{
      'source': instance.source,
      'repo': instance.repo,
      'ref': instance.ref,
      'subdir': instance.subdir,
      'installedAt': instance.installedAt?.toIso8601String(),
      'toolsApproved': instance.toolsApproved,
    };

_SkillFile _$SkillFileFromJson(Map<String, dynamic> json) => _SkillFile(
  path: json['path'] as String,
  size: (json['size'] as num?)?.toInt() ?? 0,
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SkillFileToJson(_SkillFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'size': instance.size,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

_SkillInstallPreview _$SkillInstallPreviewFromJson(Map<String, dynamic> json) =>
    _SkillInstallPreview(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      allowedTools:
          (json['allowedTools'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      installable: json['installable'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      alreadyExists: json['alreadyExists'] as bool? ?? false,
    );

Map<String, dynamic> _$SkillInstallPreviewToJson(
  _SkillInstallPreview instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'allowedTools': instance.allowedTools,
  'fileCount': instance.fileCount,
  'totalBytes': instance.totalBytes,
  'installable': instance.installable,
  'reason': instance.reason,
  'alreadyExists': instance.alreadyExists,
};

_SkillInstallResult _$SkillInstallResultFromJson(Map<String, dynamic> json) =>
    _SkillInstallResult(
      installed:
          (json['installed'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      skipped:
          (json['skipped'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const <String, String>{},
    );

Map<String, dynamic> _$SkillInstallResultToJson(_SkillInstallResult instance) =>
    <String, dynamic>{
      'installed': instance.installed,
      'skipped': instance.skipped,
    };

_Frontmatter _$FrontmatterFromJson(Map<String, dynamic> json) => _Frontmatter(
  name: json['name'] as String? ?? '',
  description: json['description'] as String? ?? '',
  license: json['license'] as String? ?? '',
  compatibility: json['compatibility'] as String? ?? '',
  metadata:
      (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
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
      'license': instance.license,
      'compatibility': instance.compatibility,
      'metadata': instance.metadata,
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
