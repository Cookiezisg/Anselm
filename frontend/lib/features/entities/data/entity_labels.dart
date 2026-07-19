import '../../../i18n/strings.g.dart';
import 'entity_kind.dart';

/// The i18n labels for an entity kind — the type noun (Function / Handler / Agent / Workflow) and the
/// execution verb (Run / Call / Invoke / Trigger). One source so the rail, ocean header, and run terminal
/// share the exact same mapping instead of each hand-copying the same switch.
///
/// 实体 kind 的 i18n 标签——类型名词(Function/Handler/Agent/Workflow)与执行动词(Run/Call/Invoke/Trigger)。
/// 唯一处:rail、海洋头、run 终端共用同一映射,不再各抄一份 switch。
extension EntityKindLabels on EntityKind {
  String typeLabel(Translations t) => switch (this) {
        EntityKind.function => t.ref.function,
        EntityKind.handler => t.ref.handler,
        EntityKind.agent => t.ref.agent,
        EntityKind.workflow => t.ref.workflow,
        EntityKind.control => t.ref.control,
        EntityKind.approval => t.ref.approval,
        EntityKind.trigger => t.ref.trigger,
      };

  // Support kinds have no execution verb — never reached (the verb CTA is gated on `executable`), but the
  // switch must be exhaustive. 支撑 kind 无执行动词(动词 CTA 由 executable 门控,不会到此)。
  String verbLabel(Translations t) => switch (this) {
        EntityKind.function => t.entities.detail.verb.run,
        EntityKind.handler => t.entities.detail.verb.call,
        EntityKind.agent => t.entities.detail.verb.invoke,
        EntityKind.workflow => t.entities.detail.verb.trigger,
        EntityKind.control => '',
        EntityKind.approval => '',
        EntityKind.trigger => '',
      };
}
