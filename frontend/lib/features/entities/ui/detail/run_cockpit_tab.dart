import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/graph/flowrun_timeline.dart';
import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/graph/graph_run_state.dart';
import '../../../../core/ui/an_action_group.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_callout.dart';
import '../../../../core/ui/an_code_block.dart';
import '../../../../core/ui/an_last_good.dart';
import '../../../../core/ui/an_graph_canvas.dart';
import '../../../../core/ui/an_info_card.dart';
import '../../../../core/ui/an_run_board.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_skeleton.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_expand_reveal.dart';
import '../../../../core/ui/an_type_to_confirm.dart';
import '../../../../core/ui/icons.dart';
import '../../../../core/run/approval_gate.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../state/detail/entity_detail_provider.dart';
import '../../state/detail/run_cockpit_provider.dart';
import '../../state/detail/run_cockpit_state.dart';
import '../../state/selected_entity.dart';
import 'detail_sections.dart';

/// The workflow 运行 tab — the observability cockpit (replaces the generic 日志 tab for workflow: a
/// workflow's log IS its flowruns). [AnRunBoard] (run history + node gantt) → the selected run's
/// [AnGraphCanvas] in run mode (derived overlay) → an inline node-debug card when a node is picked.
/// The board, graph and debug are strong-linked: pick a run → its gantt + graph; pick a node (gantt
/// row OR graph node) → the debug. Actions: `:replay` a failed run, `:kill` the workflow, `:decide`
/// a parked approval. Everything derives from the pure [flowrunTimeline] / [deriveRunState] over the
/// active-version graph + the run's paged-through node rows.
///
/// workflow 运行 tab——观测驾驶舱(取代 workflow 的通用日志 tab:workflow 的日志就是 flowrun)。
/// [AnRunBoard](run 历史 + 节点甘特)→ 选中 run 的 run 态 [AnGraphCanvas](派生覆层)→ 点节点时的
/// 内联节点调试卡。看板/图/调试强链。动作:重跑失败 run / 终止 workflow / 决断 parked 审批。全部由
/// 纯 [flowrunTimeline]/[deriveRunState] 派生(活跃版本图 + run 翻页拉全的节点行)。
class RunCockpitTab extends ConsumerWidget {
  const RunCockpitTab(this.entityRef, {super.key});

  final EntityRef entityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final async = ref.watch(runCockpitProvider(entityRef));
    final notifier = ref.read(runCockpitProvider(entityRef).notifier);
    final detail = ref.watch(entityDetailProvider(entityRef)).value;
    final v = detail?.workflow?.activeVersion;
    final graph = v == null ? null : graphOf(v);

    // Last-known-good, hard reset on entity switch (snapshot bridges same-entity refreshes only —
    // cross-entity hold would be data corruption). last-known-good,实体切换硬换代,快照只桥同实体刷新。
    return AnLastGood(
      value: async,
      resetKey: entityRef,
      placeholder: const AnSkeleton.lines(6),
      errorBuilder: (_, _, _) => AnState(
        kind: AnStateKind.error,
        size: AnStateSize.inset,
        title: d.state.errorTitle,
        action: AnButton(
          label: d.state.retry,
          onPressed: () => ref.invalidate(runCockpitProvider(entityRef)),
        ),
      ),
      builder: (context, st) {
        final comp = st.selected;
        final gantt = (graph != null && comp != null)
            ? flowrunTimeline(graph, comp)
            : const <GanttRow>[];
        final overlay = (graph != null && comp != null)
            ? deriveRunState(
                graph,
                rows: comp.nodes,
                runStatus: st.selectedRun?.status ?? '',
              )
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnRunBoard(
              runs: [
                for (final r in st.runs)
                  AnRunItem(
                    id: r.id,
                    status: r.status,
                    hint: fmtTime(r.startedAt ?? r.updatedAt),
                    replayCount: r.replayCount,
                  ),
              ],
              gantt: gantt,
              selectedRunId: st.selectedRunId,
              onRunPick: notifier.selectRun,
              selectedNodeId: st.selectedNodeId,
              onNodePick: notifier.selectNode,
              runsHeader: d.cockpit.runsCount(n: st.runs.length),
              ganttHeader: d.cockpit.nodeGantt,
              emptyTitle: d.cockpit.noRuns,
              emptyHint: d.cockpit.noRunsHint,
              notRunLabel: d.cockpit.notRun,
              waitingLabel: d.cockpit.waitingApproval,
            ),
            if (st.hasMore) ...[
              const SizedBox(height: AnSpace.s8),
              Align(
                alignment: Alignment.centerLeft,
                child: st.loadingMore
                    ? const AnSkeleton.row()
                    : AnButton(
                        label: d.state.loadMore,
                        onPressed: notifier.loadMore,
                      ),
              ),
            ],
            // The selected run's header info + observability actions (:replay a failed run, :kill the
            // workflow). 选中 run 的头信息 + 观测动作(重跑失败 run / 终止 workflow)。
            if (st.selectedRun case final run?)
              AnSection(
                variant: AnSectionVariant.plain,
                children: [
                  _runInfo(
                    context,
                    ref,
                    st,
                    run,
                    workflowName: detail?.workflow?.name ?? run.workflowId,
                  ),
                ],
              ),
            // The run graph, lit by the selected run's derived overlay. 选中 run 派生覆层点亮的运行图。
            if (graph != null && st.selectedRunId != null)
              AnSection(
                label: d.cockpit.runGraph,
                variant: AnSectionVariant.plain,
                children: [
                  AnGraphCanvas(
                    graph: graph,
                    framed: true,
                    run: overlay,
                    selectedNodeId: st.selectedNodeId,
                    onNodeTap: notifier.selectNode,
                  ),
                ],
              ),
            if (st.selectedNode case final node?)
              AnSection(
                variant: AnSectionVariant.plain,
                children: [_nodeDebug(context, ref, st, node)],
              ),
          ],
        );
      },
    );
  }

  Widget _runInfo(
    BuildContext context,
    WidgetRef ref,
    RunCockpitState st,
    Flowrun run, {
    required String workflowName,
  }) {
    final d = context.t.entities.detail;
    final kv = d.kv;
    final notifier = ref.read(runCockpitProvider(entityRef).notifier);
    final failed = run.status == 'failed';
    final live = run.status == 'running' || run.status == 'parked';
    final runningCount = st.runs
        .where((r) => r.status == 'running' || r.status == 'parked')
        .length;
    final lifetime = (run.completedAt != null && run.startedAt != null)
        ? fmtDuration(run.completedAt!.difference(run.startedAt!))
        : '—';
    final execution = st.executionDuration;
    return AnInfoCard(
      title: d.cockpit.runInfo,
      icon: AnIcons.byKey('scheduler'),
      meta: run.status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kvList([
            (kv.flowrunId, run.id),
            (kv.version, run.versionId),
            (kv.replay, '${run.replayCount}'),
            (kv.lifetime, lifetime),
            if (execution != null) (kv.execution, fmtDuration(execution)),
            if (run.error?.isNotEmpty ?? false) (kv.error, run.error),
          ], dense: true),
          if (failed || live) ...[
            const SizedBox(height: AnSpace.s8),
            if (failed)
              AnActionGroup([
                AnButton(
                  label: d.cockpit.replay,
                  icon: AnIcons.byKey('history'),
                  size: AnButtonSize.sm,
                  onPressed: st.busy ? null : notifier.replaySelected,
                ),
              ]),
            if (live)
              _KillWorkflowAction(
                workflowName: workflowName,
                label: d.cockpit.kill,
                title: d.cockpit.killTitle,
                warning: d.cockpit.killWarning(
                  n: st.hasMore ? '$runningCount+' : '$runningCount',
                ),
                body: d.cockpit.killBody,
                inputHint: d.cockpit.killHint(name: workflowName),
                confirmLabel: d.cockpit.killConfirm,
                busy: st.busy,
                onConfirm: notifier.kill,
              ),
          ],
        ],
      ),
    );
  }

  Widget _nodeDebug(
    BuildContext context,
    WidgetRef ref,
    RunCockpitState st,
    FlowrunNode node,
  ) {
    final d = context.t.entities.detail;
    final kv = d.kv;
    final notifier = ref.read(runCockpitProvider(entityRef).notifier);
    final execution = st.executionDurationFor(node);
    final parked = node.status == 'parked';
    // Result minus the reserved routing/approval keys is the node's actual payload. 剔保留键的真实结果。
    final payload = <String, Object?>{
      for (final e in node.result.entries)
        if (e.key != '__port' && e.key != 'rendered') e.key: e.value,
    };
    return AnInfoCard(
      title: d.cockpit.nodeDetail(id: node.nodeId),
      icon: AnIcons.byKey('sliders'),
      meta: node.status,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kvList([
            (kv.status, node.status),
            if (node.iteration > 0)
              (d.cockpit.iteration(n: node.iteration), '${node.iteration}'),
            (kv.ref, node.ref),
            (kv.execution, execution == null ? '—' : fmtDuration(execution)),
          ], dense: true),
          if (node.error?.isNotEmpty ?? false) ...[
            const SizedBox(height: AnSpace.s8),
            AnCallout(node.error!, severity: AnCalloutSeverity.danger),
          ],
          if (payload.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s8),
            AnSection(
              label: kv.output,
              variant: AnSectionVariant.quiet,
              children: [AnCodeBlock(prettyJsonCapped(payload))],
            ),
          ],
          // A parked approval node grows the gate — the shared ApprovalGate, bare (already inside this
          // debug card), decide right here (first-wins → reconcile). parked 出门:共享门·裸接(已在卡内)。
          if (parked) ...[
            const SizedBox(height: AnSpace.s12),
            ApprovalGate(
              parked: node,
              framed: false,
              busy: st.busy,
              onDecide: (v, _) => notifier.decide(node.nodeId, v),
            ),
          ],
        ],
      ),
    );
  }
}

/// The cockpit's destructive action uses the same distributed danger-zone gate as Scheduler: the
/// button only reveals the impact, and the workflow name is required before :kill can execute.
/// 驾驶舱危险动作与 Scheduler 共用分布式危险区:先揭示影响面,再输入 workflow 名才可执行。
class _KillWorkflowAction extends StatefulWidget {
  const _KillWorkflowAction({
    required this.workflowName,
    required this.label,
    required this.title,
    required this.warning,
    required this.body,
    required this.inputHint,
    required this.confirmLabel,
    required this.busy,
    required this.onConfirm,
  });

  final String workflowName;
  final String label;
  final String title;
  final String warning;
  final String body;
  final String inputHint;
  final String confirmLabel;
  final bool busy;
  final VoidCallback onConfirm;

  @override
  State<_KillWorkflowAction> createState() => _KillWorkflowActionState();
}

class _KillWorkflowActionState extends State<_KillWorkflowAction> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnButton(
          label: widget.label,
          icon: AnIcons.byKey('stop'),
          variant: AnButtonVariant.danger,
          size: AnButtonSize.sm,
          onPressed: widget.busy ? null : () => setState(() => _open = !_open),
        ),
        AnExpandReveal(
          open: _open,
          child: Padding(
            padding: const EdgeInsets.only(top: AnGap.block),
            child: AnTypeToConfirm(
              title: widget.title,
              warning: widget.warning,
              body: Text(
                widget.body,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
              expected: widget.workflowName,
              inputHint: widget.inputHint,
              confirmLabel: widget.confirmLabel,
              busy: widget.busy,
              onConfirm: widget.onConfirm,
            ),
          ),
        ),
      ],
    );
  }
}
