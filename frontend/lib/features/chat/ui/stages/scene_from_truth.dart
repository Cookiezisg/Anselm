import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/agent.dart';
import '../../../../core/contract/entities/approval.dart';
import '../../../../core/contract/entities/control.dart';
import '../../../../core/contract/entities/document.dart';
import '../../../../core/contract/entities/function.dart';
import '../../../../core/contract/entities/handler.dart';
import '../../../../core/contract/entities/skill.dart';
import '../../../../core/contract/entities/trigger.dart';
import '../../../../core/contract/entities/values.dart';
import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/contract/mcp.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/messages/block_tree_reducer.dart';
import '../../../../core/contract/messages/block_content.dart';
import '../../../../core/router/panel_registry.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/stage_director.dart';
import '../../model/tool_card_state.dart';
import '../../state/stage_truth.dart';
import '../../state/touchpoint_ledger.dart';
import '../../state/transcript_jump_provider.dart';
import '../tool_card_nav.dart';
import 'stage_registry.dart';
import 'stage_scene.dart';

/// «Any row shows its full stage» (WRK-064) — the sceneFromTruth seam. A SETTLED touchpoint row (no live
/// tool block) still opens to its carefully-built kind stage (function → the code editor, workflow → the
/// graph, control → the discriminant ladder…), NOT a bare verb-history summary. It does this by REPLICATING
/// the production recipe the live path uses (stage_panel `_GenericStage`): serialize the entity's current
/// truth into an args-JSON, pack it into a synthetic completed tool_call [BlockNode], let [ToolCardState.of]
/// derive the args session, and hand a `live:false` [StageScene] to the SAME bespoke body — zero behaviour
/// fork. The tool name is `create_KIND` so `editTargetId` stays null (no GET / no diff / no old-stratum —
/// just «render the current truth»); trigger/document use `edit_KIND` so the body's read-only live-facts
/// bar / byte badge light up.
///
/// 「点任何行都渲完整 stage」的 sceneFromTruth 缝。落定行(无 live tool 块)照样展开出精心 kind 舞台而非
/// 光秃摘要:复刻活路的生产 recipe——真身序列化成 args-JSON,塞进合成的 completed tool_call BlockNode,
/// ToolCardState.of 自派生 session,把 live:false 的 StageScene 交给同一 bespoke 体,零行为分叉。toolName
/// 用 create_KIND 让 editTargetId 恒 null(不 GET/无 diff/无地层,纯渲当前真身);trigger/document 用
/// edit_KIND 点亮活事实条 / 字节徽。

/// The kinds that have a truth snapshot provider AND a bespoke stage worth rendering from that truth.
/// Excluded: attachment (its own pedestal, no stage) · subagent (truth = the LIVE-only nested transcript,
/// needs B6 reload-rehydration) · memory (backend `noTouch` → never produces a settled ledger row, so
/// unreachable) · conversation (no bespoke stage). 有真身 provider + bespoke 舞台的 kind;其余各有原因留摘要。
bool hasTruthStage(String kind) => const {
      'function', 'handler', 'agent', 'workflow', 'control', 'approval', 'trigger', 'document',
      'skill', 'mcp',
    }.contains(kind);

/// Watch the kind's truth snapshot (autoDispose family — a collapsed row frees the GET). 观该 kind 真身。
AsyncValue<Object> _watchTruth(WidgetRef ref, String kind, String id) => switch (kind) {
      'function' => ref.watch(functionTruthProvider(id)),
      'handler' => ref.watch(handlerTruthProvider(id)),
      'agent' => ref.watch(agentTruthProvider(id)),
      'workflow' => ref.watch(workflowTruthProvider(id)),
      'control' => ref.watch(controlTruthProvider(id)),
      'approval' => ref.watch(approvalTruthProvider(id)),
      'trigger' => ref.watch(triggerTruthProvider(id)),
      'document' => ref.watch(documentTruthProvider(id)),
      'skill' => ref.watch(skillTruthProvider(id)),
      'mcp' => ref.watch(mcpTruthProvider(id)),
      _ => const AsyncValue<Object>.data(<String, Object?>{}),
    };

/// trigger/document want the body's edit-only read-adds (facts bar / byte badge); everyone else renders as a
/// pure create so no diff / old-stratum leaks in. trigger/document 用 edit 点亮只读附加件,余用 create。
String _toolNameFor(String kind) =>
    (kind == 'trigger' || kind == 'document') ? 'edit_$kind' : 'create_$kind';

/// The workflow graph from its version — `graphParsed` if the backend sent it (null in production), else
/// the decoded raw `graph` blob (empty → an empty graph, unparseable → null). Inlined from
/// entity_format's `graphOf` to avoid a cross-feature import (features 互不依赖). 工作流图(内联 graphOf,免跨 feature)。
Graph? _graphOf(WorkflowVersion v) {
  if (v.graphParsed != null) return v.graphParsed;
  if (v.graph.trim().isEmpty) return const Graph();
  try {
    return Graph.fromJson(jsonDecode(v.graph) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// The current-truth → args-JSON projection, per kind (null = no active version / no renderable graph →
/// caller degrades to the summary). Each case is `{}`-scoped so it may reuse `v` (the switch block is
/// flat-scoped in Dart). Keys mirror EXACTLY what each bespoke body reads off its args session.
/// 真身→args-JSON 投影(null=无活版本/无图,降摘要)。每 case 独立作用域;键与各 body 读的逐字吻合。
Map<String, Object?>? _argsFromTruth(String kind, Object truth) {
  switch (kind) {
    case 'function':
      {
        final v = (truth as FunctionEntity).activeVersion;
        if (v == null || v.code.isEmpty) return null; // no code → the summary, not a blank editor 空码降摘要
        return {'code': v.code};
      }
    case 'workflow':
      {
        final v = (truth as WorkflowEntity).activeVersion;
        if (v == null) return null;
        final g = _graphOf(v);
        if (g == null || g.nodes.isEmpty) return null; // empty graph → the summary, not a blank canvas 空图降摘要
        // graphFromWorkflowOps replays add_node / add_edge into the final graph — the settled canvas. Carry
        // each node's `input` CEL map so the 「最新判别式」drawer renders (the body reads node['input']).
        // 合成 add_node/add_edge → 静态整图;带 input CEL 让判别式抽屉可渲。
        return {
          'ops': [
            for (final n in g.nodes)
              {
                'op': 'add_node',
                'node': {'id': n.id, 'kind': n.kind.name, 'ref': n.ref, 'input': n.input},
              },
            for (final e in g.edges)
              {
                'op': 'add_edge',
                'edge': {
                  'id': e.id,
                  'from': e.from,
                  'to': e.to,
                  if (e.fromPort != null) 'fromPort': e.fromPort,
                },
              },
          ],
        };
      }
    case 'control':
      {
        final v = (truth as ControlLogic).activeVersion;
        if (v == null || v.branches.isEmpty) return null; // no branches → the summary 无分支降摘要
        return {
          'branches': [
            for (final b in v.branches) {'port': b.port, 'when': b.when, 'emit': b.emit},
          ],
        };
      }
    case 'approval':
      {
        final v = (truth as ApprovalForm).activeVersion;
        if (v == null || v.template.isEmpty) return null; // no letter → the summary 无信笺降摘要
        return {
          'template': v.template,
          'allowReason': v.allowReason,
          'timeout': v.timeout,
          'timeoutBehavior': v.timeoutBehavior,
        };
      }
    case 'agent':
      {
        final v = (truth as AgentEntity).activeVersion;
        if (v == null || (v.prompt.isEmpty && v.tools.isEmpty && v.knowledge.isEmpty)) return null; // 空降摘要
        return {
          'prompt': v.prompt,
          'tools': [for (final t in v.tools) {'ref': t.ref, 'name': t.name}],
          'knowledge': v.knowledge,
          'modelOverride': v.modelOverride?.modelId, // project ModelRef → its id string, else the badge drops
        };
      }
    case 'handler':
      {
        final v = (truth as HandlerEntity).activeVersion;
        if (v == null) return null;
        // ONLY emit a lifecycle op when its body actually exists — `set_init/set_shutdown` with a default-
        // empty body would light the rail dot + render an empty editor, fabricating structure the handler
        // has none of (the live path only emits when the LLM set code). 只有真有 body 才发轨 op,免捏造空段。
        // REAL wire keys: set_init carries `initBody`, set_shutdown carries `shutdownBody` (backend
        // apply.go — a synthetic `code` key would diverge from what a live edit_handler streams).
        // 真线缆键:set_init=initBody、set_shutdown=shutdownBody(合成 code 键会与活 edit_handler 流不一致)。
        final ops = <Map<String, Object?>>[
          if (v.initBody.isNotEmpty) {'op': 'set_init', 'initBody': v.initBody},
          for (final m in v.methods)
            {'op': 'add_method', 'method': {'name': m.name, 'streaming': m.streaming, 'timeout': m.timeout, 'body': m.body}},
          if (v.shutdownBody.isNotEmpty) {'op': 'set_shutdown', 'shutdownBody': v.shutdownBody},
          if (v.initArgsSchema.isNotEmpty)
            {'op': 'set_init_args_schema', 'schema': [for (final a in v.initArgsSchema) {'name': a.name, 'sensitive': a.sensitive}]},
        ];
        if (ops.isEmpty) return null; // nothing to show → the summary 无内容降摘要
        return {'ops': ops};
      }
    case 'document':
      {
        final doc = truth as DocumentNode;
        if (doc.content.isEmpty) return null; // empty doc → the summary, not a blank prose curtain 空文降摘要
        return {'id': doc.id, 'content': doc.content};
      }
    case 'trigger':
      {
        final trig = truth as TriggerEntity;
        return {'triggerId': trig.id, 'kind': trig.kind.name, 'config': trig.config};
      }
    case 'skill':
      {
        final sk = truth as Skill;
        // SkillStageBody reads name / context / allowedTools / disableModelInvocation / body. Degrade to the
        // summary only when there's no real CONTENT (body + allowedTools). `context` is NOT content — the
        // backend defaults it to 'inline' on every write (app/skill/mutate.go), so `context.isEmpty` is
        // always false for API-created skills and would defeat the guard, leaving a bare「inline」nameplate.
        // context 恒有后端默认值(inline)、非真内容,不能算进空判据——否则空 skill 渲稀薄铭牌而非降摘要。
        if (sk.body.isEmpty && sk.frontmatter.allowedTools.isEmpty) return null;
        return {
          'name': sk.name,
          'context': sk.context,
          'allowedTools': sk.frontmatter.allowedTools,
          'arguments': sk.frontmatter.arguments, // the accepted args (the header's「可传什么」) 可传参数
          'disableModelInvocation': sk.frontmatter.disableModelInvocation,
          'body': sk.body,
        };
      }
    case 'mcp':
      {
        final s = truth as McpServerStatus;
        // The tool shelf. Disconnected / cached-empty (no tools) → the summary, not a bare header. 无工具降摘要。
        if (s.tools.isEmpty) return null;
        return {'name': s.name, 'tools': [for (final t in s.tools) t.name]};
      }
    default:
      return null;
  }
}

/// The subject's display name (the entity name, else the id). 主体显示名(实体名,兜底 id)。
String _nameFromTruth(String kind, Object truth, String id) => switch (kind) {
      'function' => (truth as FunctionEntity).name,
      'workflow' => (truth as WorkflowEntity).name,
      'control' => (truth as ControlLogic).name,
      'approval' => (truth as ApprovalForm).name,
      'agent' => (truth as AgentEntity).name,
      'handler' => (truth as HandlerEntity).name,
      'document' => (truth as DocumentNode).name,
      'trigger' => (truth as TriggerEntity).name,
      'skill' => (truth as Skill).name,
      'mcp' => (truth as McpServerStatus).name,
      _ => id,
    };

/// Build a `live:false` [StageScene] that makes the [kind]'s bespoke body render the entity's current truth.
/// PURE (no Ref / no async) so it unit-tests against a fixture DTO. Returns null when the truth has no
/// renderable content (e.g. no active version) → the caller falls back to the summary.
/// 合成 live:false StageScene 让 bespoke 体渲当前真身。纯函数(可单测)。无可渲内容→null→调用方降摘要。
// Memoized by the [truth] instance (C-026/007): the settled truth stage re-renders on ANY director /
// ledger change while its row is open, but the entity's fetched truth is a STABLE DTO instance until the
// provider re-fetches — so without this a fresh BlockNode + jsonEncode(full truth) + args re-parse ran
// every rebuild (the fresh node defeats the revision memo by design). Keyed on the truth object (a freezed
// DTO = a valid Expando key) with a [rowId] guard (the same truth is only ever one row, but stay honest).
// 按 truth 实例记忆化:真身是稳定 DTO,渲染重建不再重造节点/重编码/重解析 args;truth 变(重取)才新算。
final _truthSceneCache = Expando<({String rowId, StageScene? scene})>('truthScene');

StageScene? sceneFromTruth({
  required String kind,
  required Object truth,
  required String id,
  required String conversationId,
  required String rowId,
}) {
  final cached = _truthSceneCache[truth];
  if (cached != null && cached.rowId == rowId) return cached.scene;

  final args = _argsFromTruth(kind, truth);
  StageScene? scene;
  if (args != null) {
    // Replicate the production recipe (stage_panel `_GenericStage`): a completed tool_call node carrying
    // the args JSON + a completed result child (→ phase succeeded, not «running»), then derive the state
    // ONCE (fresh node, so the revision-memo can't hand back a stale projection). 复刻生产 recipe。
    final node = BlockNode(id: rowId, kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': _nameFromTruth(kind, truth, id), 'arguments': jsonEncode(args)};
    node.children.add(BlockNode(id: '${rowId}_r', kind: BlockKind.toolResult, parentId: rowId)
      ..status = 'completed'
      ..content = {'content': ''});
    final state = ToolCardState.of(node);
    scene = StageScene(
      conversationId: conversationId,
      subject: StageActivityView(
        blockId: rowId,
        toolName: _toolNameFor(kind),
        kind: kind,
        live: false,
        failed: false,
        unread: 0,
        itemId: id,
      ),
      phase: StagePhase.following, // ≠ failedHold ⇒ scene.failed = false
      node: node,
      state: state,
      session: state.argsSession,
    );
  }
  _truthSceneCache[truth] = (rowId: rowId, scene: scene);
  return scene;
}

/// The SUBAGENT settled scene (WRK-064 B6) — unlike the 12 entity kinds, a subagent has no entity GET:
/// its «truth» is the FOLDED nested transcript already in memory ([ConversationTranscript._foldSubagents]
/// rebuilt it under the spawning tool_call). So build a `live:false` [StageScene] STRAIGHT off that
/// [BlockNode] (no args projection, no Ref, no async) and hand it to [SubagentStageBody], which renders its
/// ReAct trajectory tail off `scene.node.children` alone. subagent 落定场景:真身=已折进内存的嵌套 transcript
/// 节点(非实体 GET),直接包成 live:false 场景交 SubagentStageBody。
StageScene sceneFromSubagentNode(BlockNode node, String conversationId) {
  final state = ToolCardState.of(node);
  return StageScene(
    conversationId: conversationId,
    subject: StageActivityView(
      blockId: node.id,
      toolName: 'Subagent',
      kind: 'subagent',
      live: node.isOpen,
      failed: node.isError,
      unread: 0,
    ),
    phase: node.isError ? StagePhase.failedHold : StagePhase.following,
    node: node,
    state: state,
    session: state.argsSession,
  );
}

/// The settled row's body when the kind has a truth stage: watch the snapshot, and on data render the
/// bespoke stage from the synthesized scene; loading / error / no-active-version all degrade honestly to
/// the [SettledBody] summary (the summary IS a natural skeleton — no flash). Only built inside an OPEN
/// row, so a collapsed row never fires the GET. 落定行的真身舞台体:观快照→渲 bespoke;加载/失败/无活版本
/// 诚实降级摘要。只在展开行构建,收起零请求。
class StageBodyFromTruth extends ConsumerWidget {
  const StageBodyFromTruth({
    required this.conversationId,
    required this.kind,
    required this.id,
    required this.rowId,
    required this.fallback,
    super.key,
  });

  final String conversationId;
  final String kind;
  final String id;
  final String rowId;
  final CastEntity fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget summary() =>
        SettledBody(conversationId: conversationId, entity: fallback, tombstoned: fallback.tombstoned);
    return _watchTruth(ref, kind, id).when(
      data: (truth) {
        final scene = sceneFromTruth(
            kind: kind, truth: truth, id: id, conversationId: conversationId, rowId: rowId);
        final body = stageBodies[kind];
        if (scene == null || body == null) return summary();
        return body(context, scene);
      },
      loading: summary,
      error: (_, _) => summary(),
    );
  }
}

/// A settled touchpoint's inline SUMMARY — the entity's verb history (each verb · count · last-touch) over
/// the id, plus the two navigation actions. The fallback when a kind has no truth stage, is tombstoned, or
/// its snapshot is still loading / failed. No GET on a tombstone. 落定触点摘要(动词史+id+双导航;墓碑不 GET)。
class SettledBody extends ConsumerWidget {
  const SettledBody({required this.conversationId, required this.entity, required this.tombstoned, super.key});

  final String conversationId;
  final CastEntity entity;
  final bool tombstoned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final lastMessageId = entity.primary.lastMessageId;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      AnKv(dense: true, rows: [
        AnKvRow('id', entity.key, mono: true),
        for (final r in entity.byVerb.values)
          AnKvRow(
            AnCastRow.verbWord(t, r.verb),
            r.count > 1
                ? '×${r.count} · ${AnCastRow.timeLabel(context, r.lastAt)}'
                : AnCastRow.timeLabel(context, r.lastAt),
          ),
      ]),
      if (tombstoned)
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s4),
          child: Text(t.feedback.cast.tombstone, style: AnText.meta.copyWith(color: c.danger)),
        ),
      if (!tombstoned && (lastMessageId.isNotEmpty || hasPanelFor(entity.kind))) ...[
        const SizedBox(height: AnSpace.s6),
        Row(children: [
          if (lastMessageId.isNotEmpty)
            AnButton(
              label: t.feedback.cast.jumpToScene,
              icon: AnIcons.locate,
              size: AnButtonSize.sm,
              onPressed: () =>
                  ref.read(transcriptJumpProvider(conversationId).notifier).request(lastMessageId),
            ),
          if (hasPanelFor(entity.kind)) ...[
            const SizedBox(width: AnSpace.s6),
            AnButton(
              label: t.feedback.cast.goToEntity,
              icon: AnIcons.open,
              size: AnButtonSize.sm,
              onPressed: () => toolNavTo(context, entity.kind, entity.key),
            ),
          ],
        ]),
      ],
    ]);
  }
}
