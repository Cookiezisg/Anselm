import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/contract/entities/agent.dart';
import '../../../../core/contract/entities/function.dart';
import '../../../../core/contract/entities/handler.dart';
import '../../../../core/contract/entities/workflow.dart';
import '../../data/entity_kind.dart';
import '../selected_entity.dart';

part 'entity_detail.freezed.dart';

/// The resolved detail for the selected entity — exactly one of the four typed entities is non-null
/// (matching `ref.kind`), plus the agent's mount-health when applicable. A single freezed value (not a
/// sealed hierarchy) keeps the AsyncNotifier state one type; the overview switches on `ref.kind` and
/// reads the matching field. 选中实体的已解析详情:四个 typed 实体恰一个非空(对应 kind)+ agent 挂载健康。
@freezed
abstract class EntityDetail with _$EntityDetail {
  const factory EntityDetail({
    required EntityRef ref,
    FunctionEntity? function,
    HandlerEntity? handler,
    AgentEntity? agent,
    WorkflowEntity? workflow,
    MountHealthReport? mountHealth,
  }) = _EntityDetail;
}

/// The active version id for whichever kind this detail holds (used to flag the "current" version in the
/// versions tab). 当前 detail 对应 kind 的活动版本 id。
extension EntityDetailX on EntityDetail {
  String get name => switch (ref.kind) {
        EntityKind.function => function?.name ?? '',
        EntityKind.handler => handler?.name ?? '',
        EntityKind.agent => agent?.name ?? '',
        EntityKind.workflow => workflow?.name ?? '',
      };

  String get activeVersionId => switch (ref.kind) {
        EntityKind.function => function?.activeVersionId ?? '',
        EntityKind.handler => handler?.activeVersionId ?? '',
        EntityKind.agent => agent?.activeVersionId ?? '',
        EntityKind.workflow => workflow?.activeVersionId ?? '',
      };
}
