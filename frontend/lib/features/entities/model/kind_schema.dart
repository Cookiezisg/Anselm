import 'package:flutter/widgets.dart';

import '../../../core/ui/ui.dart';
import 'entity.dart';

/// Declarative per-kind detail schema (faithful port of the demo's KIND_SCHEMA): adding a
/// kind = adding a schema, not touching the renderer. Field types: text / kv / code / json
/// / rows / card (grid) / graph. Section labels are English for now (TODO: i18n via slang).
/// 声明式分 kind 详情 schema(忠实移植 demo KIND_SCHEMA)。加一种实体=加一段 schema、不动渲染器。
enum FieldType { text, kv, code, json, rows, card, graph }

class SchemaField {
  const SchemaField({
    this.key,
    this.label,
    required this.type,
    this.lang,
    this.title,
    this.icon,
    this.fields = const [],
  });
  final String? key;
  final String? label;
  final FieldType type;
  final String? lang;
  final String? title; // for card
  final IconData? icon; // for card
  final List<SchemaField> fields; // for card
}

class SectionSchema {
  const SectionSchema(this.label, this.fields, {this.grid = false});
  final String label;
  final List<SchemaField> fields;
  final bool grid;
}


const Map<EntityKind, List<SectionSchema>> kindSchema = {
  EntityKind.function: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Code', [SchemaField(key: 'code', type: FieldType.code, lang: 'python')]),
    SectionSchema('Inputs / Outputs', [
      SchemaField(type: FieldType.card, title: 'Inputs', icon: AnIcons.enter, fields: [SchemaField(key: 'inputs', type: FieldType.kv)]),
      SchemaField(type: FieldType.card, title: 'Outputs', icon: AnIcons.run, fields: [SchemaField(key: 'outputs', type: FieldType.kv)]),
    ], grid: true),
    SectionSchema('Environment', [
      SchemaField(type: FieldType.card, title: 'Dependencies', icon: AnIcons.handler, fields: [SchemaField(key: 'dependencies', type: FieldType.rows)]),
      SchemaField(type: FieldType.card, title: 'venv', icon: AnIcons.approval, fields: [SchemaField(key: 'env', type: FieldType.kv)]),
    ], grid: true),
    SectionSchema('Run history', [SchemaField(key: 'runs', type: FieldType.rows)]),
  ],
  EntityKind.handler: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Resident state', [
      SchemaField(type: FieldType.card, title: 'Runtime', icon: AnIcons.agent, fields: [SchemaField(key: 'runtime', type: FieldType.kv)]),
      SchemaField(type: FieldType.card, title: 'init config', icon: AnIcons.approval, fields: [SchemaField(key: 'configState', type: FieldType.kv)]),
    ], grid: true),
    SectionSchema('Methods', [SchemaField(key: 'methods', type: FieldType.rows), SchemaField(key: 'code', type: FieldType.code, lang: 'python')]),
    SectionSchema('Call log', [SchemaField(key: 'calls', type: FieldType.rows)]),
  ],
  EntityKind.agent: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Prompt', [SchemaField(key: 'prompt', type: FieldType.code, lang: 'markdown')]),
    SectionSchema('Mounted capabilities', [
      SchemaField(type: FieldType.card, title: 'Tools', icon: AnIcons.mcp, fields: [SchemaField(key: 'tools', type: FieldType.rows)]),
      SchemaField(type: FieldType.card, title: 'Knowledge', icon: AnIcons.document, fields: [SchemaField(key: 'knowledge', type: FieldType.rows)]),
    ], grid: true),
    SectionSchema('Mount health', [SchemaField(key: 'mountHealth', type: FieldType.rows)]),
    SectionSchema('Run history', [SchemaField(key: 'executions', type: FieldType.rows)]),
  ],
  EntityKind.workflow: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Run governance', [
      SchemaField(type: FieldType.card, title: 'Lifecycle', icon: AnIcons.scheduler, fields: [SchemaField(key: 'lifecycle', type: FieldType.kv)]),
      SchemaField(type: FieldType.card, title: 'Concurrency', icon: AnIcons.control, fields: [SchemaField(key: 'concurrency', type: FieldType.kv)]),
    ], grid: true),
    SectionSchema('Graph', [SchemaField(key: 'graph', type: FieldType.graph)]),
    SectionSchema('Run history', [SchemaField(key: 'flowruns', type: FieldType.rows)]),
  ],
  EntityKind.trigger: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Source config', [SchemaField(key: 'sourceMeta', type: FieldType.kv), SchemaField(key: 'config', type: FieldType.json)]),
    SectionSchema('Activations', [SchemaField(key: 'activations', type: FieldType.rows)]),
    SectionSchema('Firings inbox', [SchemaField(key: 'firings', type: FieldType.rows)]),
  ],
  EntityKind.control: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Inputs', [SchemaField(key: 'inputs', type: FieldType.kv)]),
    SectionSchema('Branches', [SchemaField(key: 'branches', type: FieldType.rows)]),
    SectionSchema('Branch detail', [
      SchemaField(type: FieldType.card, title: 'When (CEL)', icon: AnIcons.control, fields: [SchemaField(key: 'when', type: FieldType.code, lang: 'cel')]),
      SchemaField(type: FieldType.card, title: 'Emit', icon: AnIcons.run, fields: [SchemaField(key: 'emit', type: FieldType.json)]),
    ], grid: true),
  ],
  EntityKind.approval: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Prompt template', [SchemaField(key: 'template', type: FieldType.code, lang: 'markdown')]),
    SectionSchema('Inputs / Decision', [
      SchemaField(type: FieldType.card, title: 'Inputs', icon: AnIcons.enter, fields: [SchemaField(key: 'inputs', type: FieldType.kv)]),
      SchemaField(type: FieldType.card, title: 'Decision rule', icon: AnIcons.approval, fields: [SchemaField(key: 'decision', type: FieldType.kv)]),
    ], grid: true),
    SectionSchema('Ports', [SchemaField(key: 'ports', type: FieldType.rows)]),
  ],
  EntityKind.mcp: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Connection', [
      SchemaField(type: FieldType.card, title: 'Status', icon: AnIcons.mcp, fields: [SchemaField(key: 'connection', type: FieldType.kv)]),
      SchemaField(type: FieldType.card, title: 'Transport', icon: AnIcons.control, fields: [SchemaField(key: 'transport', type: FieldType.kv)]),
    ], grid: true),
    SectionSchema('Tools', [SchemaField(key: 'tools', type: FieldType.rows)]),
    SectionSchema('Call log', [SchemaField(key: 'calls', type: FieldType.rows)]),
  ],
  EntityKind.skill: [
    SectionSchema('Overview', [
      SchemaField(key: 'description', label: 'Description', type: FieldType.text),
      SchemaField(key: 'meta', type: FieldType.kv),
    ]),
    SectionSchema('Frontmatter', [SchemaField(key: 'frontmatter', type: FieldType.json)]),
    SectionSchema('Body (instructions)', [SchemaField(key: 'body', type: FieldType.code, lang: 'markdown')]),
    SectionSchema('allowed-tools', [SchemaField(key: 'allowedTools', type: FieldType.rows)]),
  ],
};
