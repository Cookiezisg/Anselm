import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/run/approval_gate.dart';
import '../../../core/run/provenance_line.dart';
import '../../../core/shell/right_panel.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/scheduler_repository.dart';
import '../state/scheduler_rail_provider.dart';
import '../state/scheduler_run_provider.dart';
import '../state/selected_scheduler.dart';
import 'scheduler_home_model.dart';
import 'scheduler_run_model.dart';

/// The run flagship's RIGHT ISLAND — the magnifier, and the ONLY place in the Scheduler that reveals
/// one (WRK-069 §6: the Overview board and the operations home are self-sufficient; an island is not
/// revealed just because we have one). Two faces over the page's single URL-borne selection:
///
///   • NO node selected → the RUN DOSSIER (§6 «永不空白»): pinned closure, replay history, entry
///     payload, the error in full, the `:triage` entry. The island is never empty — «nothing
///     selected» is itself a subject worth showing.
///   • A node selected → the INSPECTOR: head + the `#0 ▾` iteration switcher (a loop is only
///     debuggable per-turn) + the error callout + input/output trees + the execution-log deep link
///     + a parked node's in-place gate + a failed node's in-place replay.
///
/// The 650KB result payload is physically isolated HERE (§6) and nowhere else: the flagship page
/// renders zero JSON, so a monstrous node result costs the page nothing until you ask for it — and
/// then it costs only this pane. Esc (owned by the page) clears back to the dossier face.
///
/// run 旗舰的右岛=放大镜,也是本海洋唯一揭示右岛之处(§6:看板与主页自足,不为放而放)。两张脸随页面
/// URL 单选区切换:无选中=运行卷宗(永不空白);选中节点=检查器(头+迭代切换+错误+I/O+执行日志深链+
/// 就地人闸/重放)。650KB 大 I/O **物理隔离在此**——旗舰页零 JSON,巨大结果在你开口前不花页面一分钱,
/// 开口后也只花这一格。Esc(归页面)清回卷宗脸。
class SchedulerRunInspector extends ConsumerWidget {
  const SchedulerRunInspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedSchedulerProvider);
    if (sel is! SchedulerRun) return const SizedBox.shrink();
    final async = ref.watch(schedulerRunProvider(sel.flowrunId));
    final d = async.value;
    if (d == null) {
      return const Padding(
        padding: EdgeInsets.all(AnSpace.s12),
        child: AnDeferredLoading(child: AnSkeleton.lines(6)),
      );
    }
    if (sel.nodeId == null) return _RunDossierFace(data: d);
    return _NodeInspectorFace(data: d, nodeId: sel.nodeId!, iteration: sel.iteration);
  }
}

/// The island's shell — the SAME head + scrolling body every inspector wears (documents 先例;零壳改,
/// §6「inspector 三元链加一支」). 岛壳:与其它检查器同一顶+同一滚动体。
class _Face extends ConsumerWidget {
  const _Face({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnInspectorHead(
            icon: AnIcons.scheduler,
            label: title,
            onClose: () => ref.read(rightPanelCollapsedProvider.notifier).set(true),
            closeSemantics: context.t.shell.togglePanel,
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: const AnScrollBehavior(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AnSpace.s16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────── 卷宗脸(无选中) ───────────────────────────────────

class _RunDossierFace extends ConsumerStatefulWidget {
  const _RunDossierFace({required this.data});

  final SchedulerRunData data;

  @override
  ConsumerState<_RunDossierFace> createState() => _RunDossierFaceState();
}

class _RunDossierFaceState extends ConsumerState<_RunDossierFace> {
  bool _busy = false;

  Future<void> _triage() async {
    final t = context.t.scheduler.run;
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _busy = true);
    try {
      final cvId = await ref.read(schedulerRepositoryProvider).triageRun(widget.data.run.id);
      if (!mounted) return;
      context.go('/chat/$cvId');
    } on ApiException catch (e) {
      if (mounted) overlay.showToast(e.message, tone: AnTone.danger);
    } catch (_) {
      if (mounted) overlay.showToast(t.triageFailed, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.run;
    final c = context.colors;
    final d = widget.data;
    final run = d.run;
    final error = errorSentence(run.error);

    return _Face(
      title: t.dossierTitle,
      children: [
        AnKv(rows: [
          // Label = the «Status» COLUMN word, value = the localized flowrun status (复审后追查
          // 0717-深夜: this row once read «运行中 → failed» — the AnStatus face word `status.run`
          // mis-used as the label, with the raw wire word as the value).
          // 标签=「状态」栏目词,值=本地化 flowrun 状态词——此行曾渲「运行中 → failed」(把状态词
          // status.run 错当标签,值还漏裸线缆词)。
          AnKvRow(t.kvStatus, flowrunStatusWord(context.t, run.status)),
          // The pinned version speaks its HUMAN number (需求⑤); the raw wfv_ id only when the
          // version row never resolved (pre-versionId 旧行). 钉版念人话版本号;解不出才落裸 id。
          if (run.versionId.isNotEmpty)
            AnKvRow(
                t.pinnedVersion,
                d.pinnedVersionNumber != null
                    ? 'v${d.pinnedVersionNumber}'
                    : truncate(run.versionId, AnTrunc.id)),
          AnKvRow(t.replayHistory(n: '${run.replayCount}'),
              run.replayCount > 0 ? fmtDateTime(run.updatedAt) : t.replayNever),
        ]),
        const SizedBox(height: AnGap.block),
        ProvenanceLine(
          conversationId: run.conversationId,
          triggerId: run.triggerId,
          firingId: run.firingId,
          flowrunId: run.id,
        ),
        // The error IN FULL — the head carries only its first sentence, and this is where the rest
        // of it lives (nothing else in the page dumps text). 错误全文:头只带首句,全文住这。
        if (run.error != null && run.error!.trim().isNotEmpty) ...[
          const SizedBox(height: AnGap.section),
          AnSection(label: t.errorHead, variant: AnSectionVariant.plain, children: [
            AnWindow(
              child: Text(run.error!.trim(), style: AnText.code.copyWith(color: c.danger)),
            ),
          ]),
        ],
        // The PINNED closure — which exact entity versions this run is bound to. This is the answer
        // to «why did it behave differently than today's definition», so it belongs in the dossier.
        // 钉住的闭包:本 run 绑死在哪些实体版本上——「为什么它和今天的定义表现不同」的答案。
        if (run.pinnedRefs.isNotEmpty) ...[
          const SizedBox(height: AnGap.section),
          AnSection(label: t.pinnedRefsHead, variant: AnSectionVariant.plain, children: [
            AnKv(
              dense: true,
              rows: [
                for (final e in run.pinnedRefs.entries) AnKvRow(e.key, e.value, mono: true),
              ],
            ),
          ]),
        ],
        if (error != null && !d.orphan) ...[
          const SizedBox(height: AnGap.section),
          AnButton(
            label: t.triage,
            icon: AnIcons.chat,
            size: AnButtonSize.sm,
            block: true,
            onPressed: _busy ? null : _triage,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────── 检查器脸(选中节点) ───────────────────────────────────

class _NodeInspectorFace extends ConsumerStatefulWidget {
  const _NodeInspectorFace({required this.data, required this.nodeId, this.iteration});

  final SchedulerRunData data;
  final String nodeId;
  final int? iteration;

  @override
  ConsumerState<_NodeInspectorFace> createState() => _NodeInspectorFaceState();
}

class _NodeInspectorFaceState extends ConsumerState<_NodeInspectorFace> {
  bool _busy = false;

  Future<void> _decide(String verdict, String? reason, FlowrunNode node) async {
    await _act((repo) => repo.decideApproval(widget.data.run.id, node.nodeId,
        decision: verdict, reason: reason),
        lost: context.t.scheduler.overview.alreadyHandled);
  }

  Future<void> _replay() async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    final c = replayCounts(widget.data.comp.nodes);
    final ok = await overlay.confirm(
      title: t.replayTitle,
      message: t.replayBody(failed: '${c.failed}', completed: '${c.completed}'),
      confirmLabel: t.replayAction,
      cancelLabel: context.t.action.cancel,
      barrierLabel: context.t.action.cancel,
      confirmTone: AnDialogTone.primary,
    );
    if (!ok || !mounted) return;
    await _act((repo) => repo.replayRun(widget.data.run.id), lost: t.notReplayable);
  }

  Future<void> _act(Future<void> Function(SchedulerRepository) op, {required String lost}) async {
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _busy = true);
    try {
      await op(ref.read(schedulerRepositoryProvider));
    } on ApiException catch (e) {
      if (!mounted) return;
      overlay.showToast(e.httpStatus == 422 ? lost : e.message,
          tone: e.httpStatus == 422 ? AnTone.warn : AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await ref.read(schedulerRunProvider(widget.data.run.id).notifier).refresh();
    await ref.read(schedulerRailProvider.notifier).refresh();
  }

  /// Move the ITERATION within the same node — the loop debugger's one control (§6 迭代切换器).
  /// Routes through the URL like every other selection write. 迭代切换:与其它选区写入同走 URL。
  void _pickIteration(int iter) {
    final sel = ref.read(selectedSchedulerProvider);
    if (sel is! SchedulerRun) return;
    context.go(Uri(
      path: '/scheduler/w/${sel.workflowId}/runs/${sel.flowrunId}',
      queryParameters: {'node': widget.nodeId, 'iter': '$iter'},
    ).toString());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.run;
    final c = context.colors;
    final d = widget.data;

    final rows = [for (final n in d.nodes) if (n.nodeId == widget.nodeId) n]
      ..sort((a, b) => a.iteration.compareTo(b.iteration));

    if (rows.isEmpty) {
      // Selected a node with no row: the speculative front, or a stale ?node= from a shared URL.
      // Honest, not blank. 选中了无行的节点:推测前沿,或分享 URL 带来的过期 ?node=。诚实,不空白。
      return _Face(
        title: t.inspectorTitle,
        children: [
          AnStatBar(leading: [AnChip(widget.nodeId, mono: true, look: AnChipLook.outlined)]),
          const SizedBox(height: AnGap.block),
          Text(
            inferredRunningNodes(d.graph ?? const Graph(), d.merged).contains(widget.nodeId)
                ? context.t.run.inferredRunning
                : t.nodeNoIo,
            style: AnText.body.copyWith(color: c.inkMuted),
          ),
        ],
      );
    }

    final node = rows.firstWhere((n) => n.iteration == widget.iteration, orElse: () => rows.last);
    final activity = [
      for (final a in d.activity)
        if (a.nodeId == node.nodeId && a.iteration == node.iteration) a,
    ].firstOrNull;
    final timing = nodeTiming(node, activity: activity);
    final parked = node.status == 'parked';
    final failed = node.status == 'failed';

    return _Face(
      title: t.inspectorTitle,
      children: [
        AnStatBar(
          status: AnStatus.fromRaw(node.status),
          leading: [AnChip(node.nodeId, mono: true, look: AnChipLook.outlined)],
          stats: [
            if (node.kind.isNotEmpty) AnStat(node.kind),
            if (timing.queue != null) AnStat(t.queuedFor(d: fmtDuration(timing.queue!)), tabular: true),
            if (timing.exec != null) AnStat(t.execFor(d: fmtDuration(timing.exec!)), tabular: true),
          ],
          chips: [
            if (node.ref.isNotEmpty) AnChip(truncate(node.ref, AnTrunc.id), mono: true, look: AnChipLook.outlined),
          ],
        ),
        // The iteration switcher — a loop node is only debuggable one turn at a time (§6 «#0 ▾»).
        // One row ⇒ no switcher (a control with one option is noise). 迭代切换器:循环只能逐轮取证;
        // 只有一轮就不长出来(单选项的控件是噪声)。
        if (rows.length > 1) ...[
          const SizedBox(height: AnGap.block),
          Row(children: [
            Text(t.iterationPick, style: AnText.label.copyWith(color: c.inkMuted)),
            const SizedBox(width: AnGap.inline),
            Expanded(
              child: AnDropdown<int>(
                value: node.iteration,
                variant: AnDropdownVariant.ghost,
                options: [
                  for (final r in rows)
                    AnDropdownOption(value: r.iteration, label: '#${r.iteration}'),
                ],
                onChanged: _pickIteration,
              ),
            ),
          ]),
        ],
        if (node.error != null && node.error!.trim().isNotEmpty) ...[
          const SizedBox(height: AnGap.block),
          AnCallout(node.error!.trim(), severity: AnCalloutSeverity.danger),
        ],
        // The I/O — the ONE place in the whole flagship that renders JSON (§6 650KB 物理隔离于此).
        // AnJsonTree is lazy + collapsible, so even a monstrous result costs only what you open.
        // I/O:整个旗舰唯一渲 JSON 之处;AnJsonTree 惰性可折,巨大结果只花你打开的那部分。
        const SizedBox(height: AnGap.section),
        if (node.result.isEmpty)
          Text(t.nodeNoIo, style: AnText.body.copyWith(color: c.inkFaint))
        else
          AnSection(label: t.nodeOut, variant: AnSectionVariant.plain, children: [
            // The tree is a VIRTUALIZED viewport (TreeSliver) and so REQUIRES a bounded height from
            // its host (the primitive's own contract — it cannot shrinkWrap). That bound is exactly
            // what makes 650KB cost only the visible rows, and it is why the island — never the page
            // — is where a monstrous result may live at all. 树是虚拟化 viewport,必须由宿主给定高
            // (原语自身契约,不能 shrinkWrap);正是这个界让 650KB 只花可见行的钱,也正因如此巨物只能
            // 住在岛里而非页上。
            SizedBox(
              height: AnSize.jsonViewport,
              child: AnJsonTree(data: node.result, showRoot: false, openDepth: 1),
            ),
          ]),
        // The execution log deep link — the audit row this node's work left behind (工单⑤ execId).
        // 执行日志深链:本节点留下的审计行。
        if (activity != null && activity.execId.isNotEmpty) ...[
          const SizedBox(height: AnGap.section),
          AnSection(label: t.execLogHead, variant: AnSectionVariant.plain, children: [
            AnKv(dense: true, rows: [
              AnKvRow(activity.kind, activity.execId, mono: true),
              // Label = «Status», value = the EXEC-domain word (activity.status is ok/timeout land —
              // runStatusWord IS the right map here; only the label was wrong: `status.done` 曾错当
              // 标签渲成「完成 → 失败」). 标签「状态」;值走执行域词表(此处 runStatusWord 本就对)。
              AnKvRow(context.t.scheduler.run.kvStatus, runStatusWord(context.t, activity.status)),
            ]),
          ]),
        ],
        // The human gate, decidable right here (§10 人闸三处就地:Overview / 台账 / 右岛).
        if (parked) ...[
          const SizedBox(height: AnGap.section),
          ApprovalGate(
            parked: node,
            busy: _busy,
            collectReason: true,
            onDecide: (v, r) => _decide(v, r, node),
          ),
        ],
        // A failed node replays the RUN (:replay clears every failed row and rewalks — there is no
        // per-node replay endpoint, so the button says what actually happens).
        // 失败节点重放的是整个 run(:replay 清全部失败行重走——没有逐节点重放端点,故钮说的是真实发生的事)。
        if (failed && !d.orphan) ...[
          const SizedBox(height: AnGap.section),
          AnButton(
            label: t.replayNode,
            icon: AnIcons.history,
            size: AnButtonSize.sm,
            block: true,
            onPressed: _busy ? null : _replay,
          ),
        ],
      ],
    );
  }
}
