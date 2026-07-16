import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/graph/flowrun_timeline.dart';
import '../../../core/graph/graph_run_state.dart';
import '../../../core/model/time_format.dart';
import '../../../core/run/approval_gate.dart';
import '../../../core/run/flowrun_node_list.dart';
import '../../../core/run/provenance_line.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/scheduler_repository.dart';
import '../state/scheduler_rail_provider.dart';
import '../state/scheduler_run_provider.dart';
import 'scheduler_home_model.dart';
import 'scheduler_run_model.dart';

/// The single-run FLAGSHIP (`/scheduler/w/:id/runs/:frId`, WRK-069 §5 — the ocean's main event).
///
/// The whole page is ONE selection × THREE altitudes × the right-island magnifier: the dossier head
/// answers «what happened», the pinned graph answers «where», the gantt answers «when/how long», the
/// ledger answers «which node» — and picking a node anywhere (graph node / gantt row / ledger row)
/// moves the SAME selection, which lives in the URL (`?node=&iter=`) so it survives a reload and can
/// be shared. Nothing here navigates away; the deep detail (I/O trees, logs, the human gate) is one
/// click into the right island (§6). Esc clears back to the dossier face.
///
/// Two honesty rules run through every zone. (1) ONE error sentence: [errorSentence] is computed
/// once and projected into the head, the failing ledger row and the gantt's red bar — «用户在哪层
/// 错误就在哪层», structurally, not by three copies of a substring. (2) Data availability drives
/// shape, never the other way round: the queue segment appears iff ⑫ stamped the row, the exec
/// segment sharpens iff ⑤ has the audit row, the whole gantt degrades to equal slots iff the span
/// collapses, and a mid-flight run's un-rowed front is labelled 推测执行中 rather than drawn as fact.
///
/// 单 run 旗舰:一个选区 × 三海拔 × 右岛放大镜。头答「怎么了」、钉版图答「在哪」、甘特答「多久」、台账答
/// 「哪个节点」;在任一处点节点=同一个选区(在 URL 里,可刷新可分享);页内不跳走,深证据一键进右岛,Esc
/// 回卷宗脸。两条诚实律贯穿全页:①错误只有一句(算一次、投影三处);②形状跟着数据可得性走,绝不反过来。
class SchedulerRunView extends ConsumerStatefulWidget {
  const SchedulerRunView({
    required this.workflowId,
    required this.flowrunId,
    this.nodeId,
    this.iteration,
    super.key,
  });

  final String workflowId;
  final String flowrunId;
  final String? nodeId;
  final int? iteration;

  @override
  ConsumerState<SchedulerRunView> createState() => _SchedulerRunViewState();
}

class _SchedulerRunViewState extends ConsumerState<SchedulerRunView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    AnTimePulse.instance.addListener(_onPulse);
  }

  @override
  void dispose() {
    AnTimePulse.instance.removeListener(_onPulse);
    _scroll.dispose();
    super.dispose();
  }

  // A live run's elapsed / «running for» text refreshes on the ONE top-level pulse — never a
  // per-row ticker (C 轨). 活 run 的耗时字随唯一顶层脉搏刷新,绝不逐行 ticker。
  void _onPulse() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final collapsed = _scroll.hasClients && _scroll.offset > AnSpace.s64;
    ref.read(shellHeadProvider.notifier).setCollapsed(collapsed);
  }

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
  }

  String get _base => '/scheduler/w/${widget.workflowId}/runs/${widget.flowrunId}';

  /// THE selection write (§5 三海拔单选区): every altitude routes through this one call, so the URL
  /// stays the single truth and picking the same node twice toggles it off (Esc's mouse twin).
  /// 唯一的选区写入:三海拔都走这一条,URL 恒为单一真相;再点一次即取消(Esc 的鼠标孪生)。
  void _pick(String? nodeId, {int? iteration}) {
    if (nodeId == null || (nodeId == widget.nodeId && iteration == widget.iteration)) {
      context.go(_base);
      return;
    }
    final q = {'node': nodeId, if (iteration != null) 'iter': '$iteration'};
    context.go(Uri(path: _base, queryParameters: q).toString());
  }

  void _clear() => context.go(_base);

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler;
    final async = ref.watch(schedulerRunProvider(widget.flowrunId));
    final d = async.value;

    if (d == null) {
      if (async.hasError) {
        final e = async.error;
        final missing = e is ApiException && e.httpStatus == 404;
        return Center(
          child: AnState(
            kind: missing ? AnStateKind.empty : AnStateKind.error,
            title: missing ? t.run.notFoundTitle : t.run.errorTitle,
            hint: missing ? t.run.notFoundHint : t.run.errorHint,
            action: missing
                ? null
                : AnButton(
                    label: t.retry,
                    onPressed: () => ref.invalidate(schedulerRunProvider(widget.flowrunId)),
                  ),
          ),
        );
      }
      return const AnPage(
        child: AnDeferredLoading(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [AnSkeleton.card(), SizedBox(height: AnSpace.s16), AnSkeleton.lines(8)],
          ),
        ),
      );
    }

    // Bind «Scheduler / 名 / fr_x» post-frame (entities 先例:每次数据重建重绑,onTap 恒新鲜). 后帧绑。
    final hostName = d.workflow?.name ?? widget.workflowId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(shellHeadProvider.notifier).bind(
              t.run.crumb(name: hostName, id: truncate(widget.flowrunId, AnTrunc.id)),
              _scrollToTop,
            );
      }
    });

    final graph = d.graph ?? const Graph();
    final inferred = inferredRunningNodes(graph, d.merged);
    final now = DateTime.now();
    final chart = flowrunChart(graph, d.merged,
        activity: d.activity, now: now, inferredRunning: inferred);

    // Esc clears the node selection back to the dossier face (§6). The shortcut lives on the PAGE,
    // not the island — the selection is the page's, and the island is only its mirror. Bound only
    // while there IS a selection, so Esc stays free for whatever else owns it otherwise (settings
    // 先例). Esc 清选区回卷宗脸;快捷键挂在页上而非岛上——选区是页的,岛只是它的镜子;仅有选区时绑,
    // 否则 Esc 留给别人。
    return CallbackShortcuts(
      bindings: {
        if (widget.nodeId != null) const SingleActivator(LogicalKeyboardKey.escape): _clear,
      },
      child: Focus(
        autofocus: false,
        child: AnZonedPage(
          controller: _scroll,
          zones: [
            AnPageZone(_DossierHead(data: d, now: now)),
            if (d.graph != null)
              AnPageZone(
                Padding(
                  padding: const EdgeInsets.only(top: AnGap.section),
                  child: _GraphZone(
                    data: d,
                    graph: graph,
                    selectedNodeId: widget.nodeId,
                    onPick: (id) => _pick(id),
                  ),
                ),
                fullBleed: true,
              ),
            // The gantt breaks the 720 reading column (判决③ 全宽破例 — a time axis's density is
            // horizontal; the prose zones keep 720). 甘特全宽破例(时间轴的密度天然横向)。
            AnPageZone(
              Padding(
                padding: const EdgeInsets.only(top: AnGap.section),
                child: _GanttZone(
                  chart: chart,
                  selectedNodeId: widget.nodeId,
                  onPick: (id) => _pick(id),
                ),
              ),
              fullBleed: true,
            ),
            AnPageZone(Padding(
              padding: const EdgeInsets.only(top: AnGap.section),
              child: _LedgerZone(
                data: d,
                graph: graph,
                inferred: inferred,
                selectedNodeId: widget.nodeId,
                selectedIteration: widget.iteration,
                onPick: (id, iter) => _pick(id, iteration: iter),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── 卷宗头 ───────────────────────────────────

class _DossierHead extends ConsumerStatefulWidget {
  const _DossierHead({required this.data, required this.now});

  final SchedulerRunData data;
  final DateTime now;

  @override
  ConsumerState<_DossierHead> createState() => _DossierHeadState();
}

class _DossierHeadState extends ConsumerState<_DossierHead> {
  bool _busy = false;

  SchedulerRunData get _d => widget.data;
  Flowrun get _run => _d.run;

  Future<void> _cancel() async {
    final ov = context.t.scheduler.overview;
    final overlay = ref.read(overlayProvider.notifier);
    final ok = await overlay.confirm(
      title: ov.cancelConfirmTitle,
      message: ov.cancelConfirmBody(
          name: _d.workflow?.name ?? _run.workflowId, id: _run.id),
      confirmLabel: ov.cancelConfirmAction,
      cancelLabel: ov.cancelKeep,
      barrierLabel: ov.cancelKeep,
    );
    if (!ok || !mounted) return;
    await _act((repo) => repo.cancelRun(_run.id), lost: ov.alreadyFinished);
  }

  Future<void> _replay() async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    // The REAL numbers are already in hand — the page holds every node row (§10 记忆化承诺文案).
    // 真数字已在手:本页持全量节点行,无需再探。
    final c = replayCounts(_d.comp.nodes);
    final ok = await overlay.confirm(
      title: t.replayTitle,
      message: t.replayBody(failed: '${c.failed}', completed: '${c.completed}'),
      confirmLabel: t.replayAction,
      cancelLabel: context.t.action.cancel,
      barrierLabel: context.t.action.cancel,
      confirmTone: AnDialogTone.primary,
    );
    if (!ok || !mounted) return;
    await _act((repo) => repo.replayRun(_run.id), lost: t.notReplayable);
  }

  Future<void> _triage() async {
    final t = context.t.scheduler.run;
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _busy = true);
    try {
      final cvId = await ref.read(schedulerRepositoryProvider).triageRun(_run.id);
      if (!mounted) return;
      // 202 → the new conversation: hand the user straight to it (§10). 202 → 直接把人交给对话。
      context.go('/chat/$cvId');
    } on ApiException catch (e) {
      if (mounted) overlay.showToast(e.message, tone: AnTone.danger);
    } catch (_) {
      if (mounted) overlay.showToast(t.triageFailed, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(Future<void> Function(SchedulerRepository) op, {required String lost}) async {
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _busy = true);
    try {
      await op(ref.read(schedulerRepositoryProvider));
    } on ApiException catch (e) {
      if (!mounted) return;
      // 422 = we lost a first-wins race (the run settled itself in the meantime) — that is NEWS,
      // not an error. 422=first-wins 输了(run 自己先落定了)——那是消息,不是错误。
      overlay.showToast(e.httpStatus == 422 ? lost : e.message,
          tone: e.httpStatus == 422 ? AnTone.warn : AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await ref.read(schedulerRunProvider(_run.id).notifier).refresh();
    await ref.read(schedulerRailProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.run;
    final run = _run;
    final running = run.status == 'running';
    final failed = run.status == 'failed';
    // THE sentence — computed once, rendered here, in the ledger's failed row and behind the gantt's
    // red bar (§5.1 同句同源). 唯一那句话:算一次,头/台账/甘特同源。
    final error = errorSentence(run.error);
    final timing = runTiming(_d.nodes, _d.activity);
    final started = run.startedAt;
    final elapsed = started == null
        ? null
        : (run.completedAt != null
            ? fmtDuration(run.completedAt!.difference(started))
            : (running ? fmtWaited(widget.now.difference(started)) : null));

    final head = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnStatBar(
        status: AnStatus.fromRaw(run.status),
        leading: [
          // The tombstone (§5.7): the host workflow was soft-deleted. The page stays — a run's
          // archive is not the workflow's to delete — but every action except replay is off.
          // 墓碑:宿主已软删。页仍在(run 的档案不归 workflow 删),但除 replay 外的动作全禁。
          if (_d.orphan) AnChip(t.orphanBadge, tone: AnTone.warn, icon: AnIcons.ban),
        ],
        stats: [
          if (started != null)
            AnStat('${fmtClock(started)}${run.completedAt != null ? ' → ${fmtClock(run.completedAt)}' : ''}',
                tabular: true),
          if (elapsed != null) AnStat(elapsed, tabular: true),
          // «排队 x · 执行 y» — only with the data behind it (工单⑫/⑤). Queue absent → the exec leg
          // alone; neither → the total above already told the whole truth.
          // 拆分只在数据在库时出现:无排队戳只显执行段;两者皆无则上面的总时长已是全部真相。
          if (timing.queue != null)
            AnStat(t.queuedFor(d: fmtDuration(timing.queue!)), tabular: true),
          if (timing.exec != null) AnStat(t.execFor(d: fmtDuration(timing.exec!)), tabular: true),
          if (run.versionId.isNotEmpty) AnStat(t.pinnedVersion),
        ],
        chips: [
          if (run.replayCount > 0)
            AnChip(context.t.run.replayTimes(n: '${run.replayCount}'), look: AnChipLook.outlined),
          AnChip(_originWord(context, run.origin), look: AnChipLook.outlined, icon: AnIcons.trigger),
        ],
        notes: [
          if (error != null) AnStatNote(error),
          // The map disclaimer: we could not resolve the run's pinned version, so this page is
          // reading TODAY's graph over a historical run. Say it out loud rather than mis-draw in
          // silence (§5.2). 地图免责声明:钉版解不出,本页是拿今天的图看历史 run——明说,绝不闷声画错。
          if (_d.graph != null && !_d.graphPinned) AnStatNote(t.graphNotPinned, tone: AnTone.warn),
        ],
      ),
      const SizedBox(height: AnGap.block),
      // The provenance chain — cron → firing → conversation, each link navigable (§5.1). Upstreamed
      // (S0), so chat's dossier and this head speak the SAME line. 出处链:逐环深链;上收件,与 chat
      // 卷宗同一条线。
      ProvenanceLine(
        conversationId: run.conversationId,
        triggerId: run.triggerId,
        firingId: run.firingId,
        flowrunId: run.id,
      ),
      const SizedBox(height: AnGap.block),
      Wrap(spacing: AnGap.inline, runSpacing: AnGap.stackTight, children: [
        if (failed)
          AnButton(
            label: t.replay,
            icon: AnIcons.history,
            variant: AnButtonVariant.primary,
            size: AnButtonSize.sm,
            onPressed: _busy ? null : _replay,
          ),
        // Cancel needs a LIVE run and a live host — an orphan's engine is gone (§5.7). 取消需活 run
        // 与活宿主:孤儿的引擎已不在。
        if (running && !_d.orphan)
          AnButton(
            label: t.cancel,
            icon: AnIcons.stop,
            variant: AnButtonVariant.danger,
            size: AnButtonSize.sm,
            onPressed: _busy ? null : _cancel,
          ),
        if (failed && !_d.orphan)
          AnButton(
            label: t.triage,
            icon: AnIcons.chat,
            size: AnButtonSize.sm,
            outline: true,
            onPressed: _busy ? null : _triage,
          ),
      ]),
    ]);

    // The settle flash — one wash when a durable run_terminal landed (谢幕落账洗亮先例). 落定洗亮一次。
    return _d.settledFlash ? AnWashHighlight(child: head) : head;
  }

  String _originWord(BuildContext context, String? origin) {
    final h = context.t.scheduler.home;
    return switch (origin) {
      'manual' => h.originManual,
      'chat' => h.originChat,
      'cron' => h.originCron,
      'webhook' => h.originWebhook,
      'fsnotify' => h.originFsnotify,
      'sensor' => h.originSensor,
      _ => h.srcUnknown,
    };
  }
}

// ─────────────────────────────────── 流转图(钉版) ───────────────────────────────────

class _GraphZone extends StatelessWidget {
  const _GraphZone({
    required this.data,
    required this.graph,
    required this.selectedNodeId,
    required this.onPick,
  });

  final SchedulerRunData data;
  final Graph graph;
  final String? selectedNodeId;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.run;
    return AnSection(
      label: data.graphPinned ? t.graphHeadPinned : t.graphHead,
      children: [
        AnGraphCanvas(
          graph: graph,
          framed: true,
          // Read-only run colouring; the graph is a NAVIGATOR — picking a node moves the page's one
          // selection (§5.2 图=导航器). 只读染色;图=导航器,点节点即移动全页唯一选区。
          run: deriveRunState(graph, rows: data.nodes, runStatus: data.run.status),
          selectedNodeId: selectedNodeId,
          onNodeTap: onPick,
        ),
      ],
    );
  }
}

// ─────────────────────────────────── 完整甘特(全宽) ───────────────────────────────────

class _GanttZone extends StatelessWidget {
  const _GanttZone({required this.chart, required this.selectedNodeId, required this.onPick});

  final GanttChart chart;
  final String? selectedNodeId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.run;
    final c = context.colors;
    if (chart.rows.isEmpty) {
      return AnSection(label: t.ganttHead, children: [
        Text(t.ganttEmpty, style: AnText.body.copyWith(color: c.inkFaint)),
      ]);
    }
    return AnSection(
      label: t.ganttHead,
      children: [
        AnNodeGantt(
          rows: chart.rows,
          chart: chart,
          ruler: true,
          nowLine: true,
          selectedNodeId: selectedNodeId,
          onNodePick: onPick,
          notRunLabel: t.notRun,
          waitingLabel: context.t.run.nodeWait,
          inferredLabel: context.t.run.inferredRunning,
          queueLabel: t.queueWord,
          execLabel: t.execWord,
        ),
        // The axis collapsed (every stamp coincident — a sub-millisecond run, the local-sidecar
        // norm): the bars are EQUAL SLOTS showing sequence only, so the page says so instead of
        // letting equal widths read as equal durations. 轴塌缩(全部时刻重合,本地 sidecar 常态):条=
        // 等宽顺序槽、只表顺序——明说,免得等宽被读成等时长。
        if (!chart.timeMode) ...[
          const SizedBox(height: AnSpace.s6),
          Text(t.ganttNoSpan, style: AnText.meta.copyWith(color: c.inkFaint)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────── 节点台账 ───────────────────────────────────

class _LedgerZone extends ConsumerWidget {
  const _LedgerZone({
    required this.data,
    required this.graph,
    required this.inferred,
    required this.selectedNodeId,
    required this.selectedIteration,
    required this.onPick,
  });

  final SchedulerRunData data;
  final Graph graph;
  final Set<String> inferred;
  final String? selectedNodeId;
  final int? selectedIteration;
  final void Function(String nodeId, int iteration) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.scheduler.run;
    final c = context.colors;
    final entries = foldNodeLedger(graph, data.nodes, inferredRunning: inferred);
    final byKey = {for (final a in data.activity) '${a.nodeId}#${a.iteration}': a};

    if (entries.isEmpty) {
      return AnSection(label: t.ledgerHead, children: [
        Text(t.ledgerEmpty, style: AnText.body.copyWith(color: c.inkFaint)),
      ]);
    }

    // The honest count line — the REAL byStatus tally of what is in hand (§5.4 诚实账头). 诚实账头。
    final counts = <String, int>{};
    for (final n in data.nodes) {
      counts[n.status] = (counts[n.status] ?? 0) + 1;
    }

    final parked = [for (final e in entries) if (e.parked) e.latest!];

    return AnSection(
      label: t.ledgerHead,
      children: [
        AnStatBar(stats: [
          AnStat(context.t.run.nodeCount(n: '${data.nodes.length}'), tabular: true),
          if ((counts['completed'] ?? 0) > 0)
            AnStat('${context.t.run.runCompleted} ${counts['completed']}', tabular: true),
          if ((counts['failed'] ?? 0) > 0)
            AnStat('${context.t.run.failed} ${counts['failed']}', tabular: true),
          if ((counts['parked'] ?? 0) > 0)
            AnStat('${context.t.run.nodeWait} ${counts['parked']}', tabular: true),
        ]),
        const SizedBox(height: AnSpace.s8),
        // The human gate is the ONE thing allowed to jump the queue to the very top (§5.6 例外上浮;
        // §0 军规's two sanctioned exceptions are failure and the human gate). It sits ABOVE the
        // ledger because it is a request for action, not a record.
        // 人闸是唯一获准插到最顶的东西(军规两例外=失败与人闸);它在台账之上,因为它是行动请求、不是记录。
        for (final node in parked)
          Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s8),
            child: _ParkedGate(flowrunId: data.run.id, node: node),
          ),
        FlowrunNodeList(
          lines: [
            for (final e in entries) _lineOf(context, e, byKey),
          ],
          selectedNodeId: selectedNodeId,
          selectedIteration: selectedIteration,
          onPick: onPick,
        ),
      ],
    );
  }

  /// Fold one entry into its ledger line — the ×N members ride [FlowrunNodeLine.iterationLines], the
  /// duration is the SAME split the head totals and the gantt draws (§5.3 三段条与台账双数同源).
  /// 折一条台账行:×N 成员随行带、耗时与头/甘特同源。
  FlowrunNodeLine _lineOf(
      BuildContext context, NodeLedgerEntry e, Map<String, FlowrunActivityRow> byKey) {
    if (e.inferred) {
      return FlowrunNodeLine(
        nodeId: e.nodeId,
        status: 'running',
        kind: _graphKindOf(e.nodeId),
        inferred: true,
      );
    }
    final latest = e.latest!;
    FlowrunNodeLine one(FlowrunNode n) => FlowrunNodeLine(
          nodeId: n.nodeId,
          status: n.status,
          kind: n.kind,
          iteration: n.iteration,
          error: errorSentence(n.error),
          errorFull: n.error,
          measure: _measure(context, n, byKey['${n.nodeId}#${n.iteration}']),
        );
    return FlowrunNodeLine(
      nodeId: e.nodeId,
      status: latest.status,
      kind: latest.kind,
      iterations: e.iterations,
      iteration: latest.iteration,
      error: errorSentence(latest.error),
      errorFull: latest.error,
      measure: _measure(context, latest, byKey['${latest.nodeId}#${latest.iteration}']),
      iterationLines: e.iterations > 1 ? [for (final n in e.rows) one(n)] : const [],
    );
  }

  /// «排队 x · 执行 y» when the data is there, the exec leg alone when only ⑤ is, nothing when
  /// neither — a node that left no measurable trace shows no number rather than «0ms».
  /// 有数据才拆;只有 ⑤ 就只显执行段;都没有就不显——没留下可测痕迹的节点不该被写成「0ms」。
  String? _measure(BuildContext context, FlowrunNode n, FlowrunActivityRow? a) {
    final t = context.t.scheduler.run;
    final timing = nodeTiming(n, activity: a);
    final parts = <String>[
      if (timing.queue != null) t.queuedFor(d: fmtDuration(timing.queue!)),
      if (timing.exec != null) t.execFor(d: fmtDuration(timing.exec!)),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String _graphKindOf(String nodeId) {
    for (final n in graph.nodes) {
      if (n.id == nodeId) return n.kind.name;
    }
    return NodeKind.unknown.name;
  }
}

/// The parked approval, decidable right where you found it (§10 人闸三处就地). 就地人闸。
class _ParkedGate extends ConsumerStatefulWidget {
  const _ParkedGate({required this.flowrunId, required this.node});

  final String flowrunId;
  final FlowrunNode node;

  @override
  ConsumerState<_ParkedGate> createState() => _ParkedGateState();
}

class _ParkedGateState extends ConsumerState<_ParkedGate> {
  bool _busy = false;

  Future<void> _decide(String verdict, String? reason) async {
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _busy = true);
    try {
      await ref.read(schedulerRepositoryProvider).decideApproval(
            widget.flowrunId,
            widget.node.nodeId,
            decision: verdict,
            reason: reason,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      // first-wins: someone (or the timeout) got there first. The gate reconciles away below.
      // first-wins:别人(或超时)先到了;下面的对账会把门收走。
      overlay.showToast(
          e.httpStatus == 422 ? context.t.scheduler.overview.alreadyHandled : e.message,
          tone: e.httpStatus == 422 ? AnTone.warn : AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await ref.read(schedulerRunProvider(widget.flowrunId).notifier).refresh();
    await ref.read(schedulerRailProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) => ApprovalGate(
        parked: widget.node,
        busy: _busy,
        collectReason: true,
        onDecide: _decide,
      );
}
