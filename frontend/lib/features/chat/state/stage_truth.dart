import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/approval.dart';
import '../../../core/contract/entities/control.dart';
import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/mcp.dart';
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
final functionTruthProvider = FutureProvider.autoDispose
    .family<FunctionEntity, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getFunctionSnapshot(id),
    );

final documentTruthProvider = FutureProvider.autoDispose
    .family<DocumentNode, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getDocumentSnapshot(id),
    );

final workflowTruthProvider = FutureProvider.autoDispose
    .family<WorkflowEntity, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getWorkflowSnapshot(id),
    );

final controlTruthProvider = FutureProvider.autoDispose
    .family<ControlLogic, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getControlSnapshot(id),
    );

final approvalTruthProvider = FutureProvider.autoDispose
    .family<ApprovalForm, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getApprovalSnapshot(id),
    );

final triggerTruthProvider = FutureProvider.autoDispose
    .family<TriggerEntity, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getTriggerSnapshot(id),
    );

final agentTruthProvider = FutureProvider.autoDispose
    .family<AgentEntity, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getAgentSnapshot(id),
    );

final handlerTruthProvider = FutureProvider.autoDispose
    .family<HandlerEntity, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).getHandlerSnapshot(id),
    );

/// The sidestage's edge-kind truth reads (WRK-064): a settled skill / mcp row's full stage. id = the
/// name (skills & mcp servers are name-addressed). 边缘 kind 真身:落定 skill/mcp 行的完整舞台(id=name)。
final skillTruthProvider = FutureProvider.autoDispose.family<Skill, String>(
  (ref, name) => ref.watch(chatRepositoryProvider).getSkillSnapshot(name),
);

final mcpTruthProvider = FutureProvider.autoDispose
    .family<McpServerStatus, String>(
      (ref, name) => ref.watch(chatRepositoryProvider).getMcpSnapshot(name),
    );

/// G9 — a BUILD tool settled against this entity: its cached truth is stale BY DEFINITION.
/// Invalidate so every «看真身» consumer (StageBodyFromTruth, trigger's R-16 settle facts) refetches
/// fresh — without this, a warm cache served the PRE-edit snapshot indefinitely and «落定只信 GET»
/// was quietly «落定只信过期 GET» (A3-27). Unknown kinds are a no-op by design.
/// G9:build 工具对该实体落定=真相缓存必已过期,失效之——旧暖缓存可无限期端出编辑前快照,
/// R-16 被架空。未知 kind 静默跳过。
void invalidateTruth(Ref ref, String kind, String id) {
  switch (kind) {
    case 'function':
      ref.invalidate(functionTruthProvider(id));
    case 'document':
      ref.invalidate(documentTruthProvider(id));
    case 'workflow':
      ref.invalidate(workflowTruthProvider(id));
    case 'control':
      ref.invalidate(controlTruthProvider(id));
    case 'approval':
      ref.invalidate(approvalTruthProvider(id));
    case 'trigger':
      ref.invalidate(triggerTruthProvider(id));
    case 'agent':
      ref.invalidate(agentTruthProvider(id));
    case 'handler':
      ref.invalidate(handlerTruthProvider(id));
    case 'skill':
      ref.invalidate(skillTruthProvider(id));
    case 'mcp':
      ref.invalidate(mcpTruthProvider(id));
  }
}

/// The R-5 EDIT BASELINE (G9/A3-10) — the target's truth FROZEN per edit block. The live truth
/// providers above now invalidate the moment an edit settles (R-16 wants freshness), while the
/// settle diff badge, the resting old graph and the prefix fast-forward baseline need the PRE-edit
/// snapshot. One entity, two freshness contracts, two provider families: baselines key by the
/// edit's BLOCK id and keep alive once fetched (bounded by edits per session), so a truth refetch
/// can never wash a real diff into «+0 −0». Failures stay autoDispose (honest retry).
/// R-5 编辑基线——按编辑块冻结:真相 provider 落定即失效(R-16 要新),而 diff 徽/静置旧图/前缀快进
/// 要编辑前快照;取到即 keepAlive(量级=会话内编辑数),真相重取绝不把真 diff 洗成 +0−0;失败不冻结。
typedef EditBaselineKey = ({String id, String block});

final functionBaselineProvider = FutureProvider.autoDispose
    .family<FunctionEntity, EditBaselineKey>((ref, key) async {
      final v = await ref
          .watch(chatRepositoryProvider)
          .getFunctionSnapshot(key.id);
      ref.keepAlive();
      return v;
    });

final documentBaselineProvider = FutureProvider.autoDispose
    .family<DocumentNode, EditBaselineKey>((ref, key) async {
      final v = await ref
          .watch(chatRepositoryProvider)
          .getDocumentSnapshot(key.id);
      ref.keepAlive();
      return v;
    });

final workflowBaselineProvider = FutureProvider.autoDispose
    .family<WorkflowEntity, EditBaselineKey>((ref, key) async {
      final v = await ref
          .watch(chatRepositoryProvider)
          .getWorkflowSnapshot(key.id);
      ref.keepAlive();
      return v;
    });

final controlBaselineProvider = FutureProvider.autoDispose
    .family<ControlLogic, EditBaselineKey>((ref, key) async {
      final v = await ref
          .watch(chatRepositoryProvider)
          .getControlSnapshot(key.id);
      ref.keepAlive();
      return v;
    });

final agentBaselineProvider = FutureProvider.autoDispose
    .family<AgentEntity, EditBaselineKey>((ref, key) async {
      final v = await ref
          .watch(chatRepositoryProvider)
          .getAgentSnapshot(key.id);
      ref.keepAlive();
      return v;
    });

final handlerBaselineProvider = FutureProvider.autoDispose
    .family<HandlerEntity, EditBaselineKey>((ref, key) async {
      final v = await ref
          .watch(chatRepositoryProvider)
          .getHandlerSnapshot(key.id);
      ref.keepAlive();
      return v;
    });
