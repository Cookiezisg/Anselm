import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/approval.dart';
import '../../../core/contract/entities/control.dart';
import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../data/chat_providers.dart';

/// R-5 (WRK-061): an EDIT's stage fetches the OLD TRUTH once, the moment the args stream resolves the
/// target id — one GET feeding four uses (the name while args are nameless, the AnLayerDiff stratum,
/// the settle diff's `before`, the document prefix fast-forward baseline). autoDispose family keyed by
/// id; a failure/timeout degrades honestly (no baseline → slow-pace growth, 宁慢勿假 — the stages
/// treat error as absence, they never block on this).
///
/// R-5 旧真相单读:edit 舞台在 args 解出目标 id 的瞬间 GET 一次——一石四鸟(候名/地层/diff before/
/// 前缀快进基线)。按 id family;失败/超时诚实降级(无基线=慢拍生长,宁慢勿假——舞台把 error 当缺席,
/// 绝不阻塞)。
final functionTruthProvider = FutureProvider.autoDispose.family<FunctionEntity, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getFunctionSnapshot(id),
);

final documentTruthProvider = FutureProvider.autoDispose.family<DocumentNode, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getDocumentSnapshot(id),
);

final workflowTruthProvider = FutureProvider.autoDispose.family<WorkflowEntity, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getWorkflowSnapshot(id),
);

final controlTruthProvider = FutureProvider.autoDispose.family<ControlLogic, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getControlSnapshot(id),
);

final approvalTruthProvider = FutureProvider.autoDispose.family<ApprovalForm, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getApprovalSnapshot(id),
);

final triggerTruthProvider = FutureProvider.autoDispose.family<TriggerEntity, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getTriggerSnapshot(id),
);

final agentTruthProvider = FutureProvider.autoDispose.family<AgentEntity, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getAgentSnapshot(id),
);

final handlerTruthProvider = FutureProvider.autoDispose.family<HandlerEntity, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).getHandlerSnapshot(id),
);
