import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/values.dart';
import '../../data/entity_kind.dart';
import '../detail/entity_detail.dart';
import '../detail/entity_detail_provider.dart';
import '../selected_entity.dart';

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
      d.handler?.activeVersion?.methods
              .where((m) => m.name == method)
              .firstOrNull
              ?.inputs ??
          const [],
    EntityKind.workflow => const [],
    EntityKind.control || EntityKind.approval || EntityKind.trigger =>
      const [], // support kinds — not executable 支撑 kind 无执行入参
  };
}

// The handler methods offered in the method picker (empty for non-handlers). 方法选择器的方法集(非 handler 空)。
List<MethodSpec> runMethods(EntityDetail? d) =>
    d?.handler?.activeVersion?.methods ?? const [];

/// The workflow payload-source KIND for the picked source: 'manual', or the mounted trigger's
/// source kind (cron/webhook/fsnotify/sensor) once its detail is loaded — the form renders that
/// kind's payload template and [_coerce] folds it the same way (render/coerce 同源判据).
/// wf 来源 kind:'manual' 或选中 trigger 的 source kind(detail 载后);表单渲模板、强转折叠同源。
String wfSourceKind(Ref ref, EntityRef wf, String source) {
  if (source == 'manual') return 'manual';
  final t = ref
      .read(entityDetailProvider(EntityRef(EntityKind.trigger, source)))
      .value
      ?.trigger;
  return t?.kind.name ?? 'manual';
}
