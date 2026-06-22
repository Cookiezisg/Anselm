import 'package:flutter/widgets.dart';

import '../../../core/ui/ui.dart';

/// The 9 entity kinds (the Quadrinity + graph/carrier kinds), mirroring the backend +
/// demo `ENTITY_KINDS` single source. 九种实体(四项全能 + 图/载体),镜像后端 + demo 单源。
enum EntityKind { function, handler, agent, workflow, trigger, control, approval, mcp, skill }

/// Per-kind metadata: label, Lucide icon, and execution verb (null = not directly
/// executable). 每种实体的:标签、Lucide 图标、执行动词(null=不可直接执行)。
class EntityKindMeta {
  const EntityKindMeta(this.label, this.icon, this.verb);
  final String label;
  final IconData icon;
  final String? verb;
}

const Map<EntityKind, EntityKindMeta> kindMeta = {
  EntityKind.function: EntityKindMeta('Function', AnIcons.function, 'Run'),
  EntityKind.handler: EntityKindMeta('Handler', AnIcons.handler, 'Call'),
  EntityKind.agent: EntityKindMeta('Agent', AnIcons.agent, 'Invoke'),
  EntityKind.workflow: EntityKindMeta('Workflow', AnIcons.workflow, 'Trigger'),
  EntityKind.trigger: EntityKindMeta('Trigger', AnIcons.trigger, 'Fire'),
  EntityKind.control: EntityKindMeta('Control', AnIcons.control, null),
  EntityKind.approval: EntityKindMeta('Approval', AnIcons.approval, null),
  EntityKind.mcp: EntityKindMeta('MCP', AnIcons.mcp, null),
  EntityKind.skill: EntityKindMeta('Skill', AnIcons.skill, null),
};

/// A list-row item for the `rows` schema field (a sub-item with a label + optional meta +
/// optional status dot). `rows` 字段的行项(标签 + 可选 meta + 可选状态点)。
class RowItem {
  const RowItem(this.label, {this.meta, this.status});
  final String label;
  final String? meta;
  final AnStatus? status;
}

/// The summary shown in the rail. 侧栏列表用的摘要。
class EntitySummary {
  const EntitySummary({
    required this.id,
    required this.kind,
    required this.name,
    this.meta,
    this.status = AnStatus.idle,
  });
  final String id;
  final EntityKind kind;
  final String name;
  final String? meta;
  final AnStatus status;
}

/// The full detail: summary + a key→value bag rendered by the kind's schema. Values are
/// typed loosely (`String` / `Map<String,String>` / `List<RowItem>` / `Object?` for json)
/// per the field type in [kindSchema].
/// 完整详情:摘要 + 按该 kind schema 渲染的键值袋。值按 schema 字段型松散键入。
class EntityDetail {
  const EntityDetail({required this.summary, required this.data});
  final EntitySummary summary;
  final Map<String, Object?> data;
}
