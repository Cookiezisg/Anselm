import '../../../../core/contract/entities/values.dart';
import '../../data/entity_kind.dart';
import '../detail/entity_detail.dart';

// The declared run-input fields for an entity, by kind + (handlers only) the selected method — the SINGLE
// source the form (render) and the controller (coerce) both read. Reading one function off one detail
// guarantees a rendered field IS the coerced field; two hand-kept copies could drift and silently drop a
// param. workflow has no per-field inputs (one optional JSON payload). d==null → not loaded → none.
//
// 一次 run 的声明入参:按 kind +(仅 handler)所选方法——表单渲染与 controller 强转的**唯一**取字段处。
// 同函数同 detail 保证「渲染的字段=强转的字段」;两份手抄会漂移、静默丢参。workflow 无逐字段入参(单 JSON payload)。
List<Field> runInputFields(EntityKind kind, EntityDetail? d, {String? method}) {
  if (d == null) return const [];
  return switch (kind) {
    EntityKind.function => d.function?.activeVersion?.inputs ?? const [],
    EntityKind.agent => d.agent?.activeVersion?.inputs ?? const [],
    EntityKind.handler =>
      d.handler?.activeVersion?.methods.where((m) => m.name == method).firstOrNull?.inputs ?? const [],
    EntityKind.workflow => const [],
    EntityKind.control || EntityKind.approval || EntityKind.trigger => const [], // support kinds — not executable 支撑 kind 无执行入参
  };
}

// The handler methods offered in the method picker (empty for non-handlers). 方法选择器的方法集(非 handler 空)。
List<MethodSpec> runMethods(EntityDetail? d) => d?.handler?.activeVersion?.methods ?? const [];
