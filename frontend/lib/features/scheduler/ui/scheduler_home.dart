import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/retention.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/graph/flowrun_timeline.dart';
import '../../../core/graph/graph_run_state.dart';
import '../../../core/model/time_format.dart';
import '../../../core/run/provenance_line.dart';
import '../../../core/run/run_ledger.dart';
import '../../../core/run/run_nav.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/scheduler_repository.dart';
import '../state/scheduler_home_provider.dart';
import '../state/scheduler_rail_provider.dart';
import '../state/selected_scheduler.dart';
import 'batch_engine.dart';
import 'scheduler_home_model.dart';
import 'scheduler_run_model.dart';

/// The workflow operations home (`/scheduler/w/:id`, WRK-069 §4 S3) — one document flow, four
/// segments: health head (name + lifecycle + bead strip + 7d stats + Run now + ⋯) → the run big
/// table (source-phrase rows, count-strip filter, follow pill, batch replay/cancel) → the linked
/// run pane (`?run=`, gantt ⇄ graph ⇄ matrix three faces, an ORDINARY 720 section — 判决③'s
/// full-bleed exemption was rejected by the user on 2026-07-17 and deleted; each face answers width
/// on its own, see [AnPage]) → the triggers exhibit (observation + the pause/resume bleeding switch;
/// editing belongs to Entities). 活性军规 holds: the half-minute pulse refreshes time text only; new
/// runs ride the pill, never a row.
///
/// workflow 运营主页:四段文档流——健康头 → run 大表(来源短语行+计数条过滤+pill+批量)→ 联动格
/// (?run=,甘特⇄图⇄矩阵三脸,**720 阅读列里普通的一段**——判决③ 的全宽破例已被用户 0717 当面否决并删除,
/// 宽度归三脸各自解决,见 AnPage)→ triggers 陈列(观测+暂停/恢复止血开关,编辑归 Entities)。脉搏只刷
/// 时间字;新 run 走 pill 绝不插行。
class SchedulerHomeView extends ConsumerStatefulWidget {
  const SchedulerHomeView({required this.workflowId, this.linkedRunId, super.key});

  final String workflowId;
  final String? linkedRunId;

  @override
  ConsumerState<SchedulerHomeView> createState() => _SchedulerHomeViewState();
}

class _SchedulerHomeViewState extends ConsumerState<SchedulerHomeView> {
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

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler;
    final rail = ref.watch(schedulerRailProvider);

    // Selection changed to ANOTHER workflow → back to top + un-collapse the crumb (entities 先例;
    // a ?run= change keeps the scroll — the linked pane appears in place). 换 workflow 回顶;
    // ?run= 变化不回顶(联动格原地出现)。
    ref.listen(selectedSchedulerProvider, (prev, next) {
      final prevId = prev is SchedulerWorkflow ? prev.workflowId : null;
      final nextId = next is SchedulerWorkflow ? next.workflowId : null;
      if (prevId == nextId || nextId == null) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      ref.read(shellHeadProvider.notifier).setCollapsed(false);
    });

    if (!rail.hasValue) {
      if (rail.hasError) {
        return Center(
          child: AnState(
            kind: AnStateKind.error,
            title: t.railErrorTitle,
            hint: t.railErrorHint,
            action: AnButton(
              label: t.retry,
              onPressed: () => ref.read(schedulerRailProvider.notifier).refresh(),
            ),
          ),
        );
      }
      return const AnPage(
        child: AnDeferredLoading(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [AnSkeleton.card(), SizedBox(height: AnSpace.s16), AnSkeleton.lines(6)],
          ),
        ),
      );
    }

    final data = rail.value!;
    final row = data.workflows.where((w) => w.id == widget.workflowId).firstOrNull;
    if (row == null) {
      // Stale deep link / deleted workflow — honest not-found, crumb cleared. 诚实找不到,清面包屑。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(shellHeadProvider.notifier).clear();
      });
      return Center(
        child: AnState(kind: AnStateKind.empty, title: t.home.notFoundTitle, hint: t.home.notFoundHint),
      );
    }

    // Bind the floating-head crumb «Scheduler / 名» post-frame (entities 先例:每次数据重建重绑,
    // onTap 恒新鲜). 后帧绑面包屑。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(shellHeadProvider.notifier).bind(t.home.crumb(name: row.name), _scrollToTop);
      }
    });

    final now = DateTime.now();
    final stats = data.stats[row.id];
    final triggersById = {for (final tr in data.triggers) tr.id: tr};
    final myTriggers = [
      for (final e in data.edges)
        if (e.fromId == row.id && triggersById[e.toId] != null) triggersById[e.toId]!,
    ];
    final waiting = waitingRunIds(data.inbox, row.id);

    // Every section — the linked pane included — lives in AnPage's 720 reading column. The pane's
    // three faces each answer width on their OWN: the gantt's track is a normalized [0,1] fraction
    // that rescales losslessly, the graph pans/zooms in its InteractiveViewer, and the matrix carries
    // its own horizontal scroller (用户 0717 判决 — 全宽破例作废,见 AnPage 类文档).
    // 每一段(含联动格)都住 AnPage 的 720 阅读列:甘特是可无损缩放的 [0,1] 分数轨、图在 InteractiveViewer
    // 里平移缩放、矩阵自带横滚——三脸各自解决宽度,不向页面讨(用户 0717 判决,全宽破例作废)。
    return AnPage(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HealthHead(row: row, stats: stats, now: now),
          Padding(
            padding: const EdgeInsets.only(top: AnGap.section),
            child: _RunTableZone(
              workflowId: row.id,
              workflowName: row.name,
              runningCount: stats?.running ?? 0,
              waitingIds: waiting,
              triggersById: triggersById,
              now: now,
            ),
          ),
          if (widget.linkedRunId != null)
            Padding(
              padding: const EdgeInsets.only(top: AnGap.section),
              child: _LinkedRunPane(workflowId: row.id, flowrunId: widget.linkedRunId!),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AnGap.section),
            child: _TriggersZone(workflowId: row.id, triggers: myTriggers, now: now),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── 健康头 ───────────────────────────────────

class _HealthHead extends ConsumerStatefulWidget {
  const _HealthHead({required this.row, required this.stats, required this.now});

  final SchedulerWorkflowRow row;
  final WorkflowRunStats? stats;
  final DateTime now;

  @override
  ConsumerState<_HealthHead> createState() => _HealthHeadState();
}

class _HealthHeadState extends ConsumerState<_HealthHead> {
  bool _runBusy = false;
  bool _killOpen = false;
  bool _killBusy = false;

  Future<void> _runNow() async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _runBusy = true);
    try {
      final id = await ref.read(schedulerRepositoryProvider).runNow(widget.row.id);
      if (!mounted) return;
      overlay.showToast(t.runNowStarted(id: truncate(id, AnTrunc.id)), tone: AnTone.ok);
      // USER action — refetching the table top is 军规-legal geometry. 用户动作,回顶重取合法。
      await ref.read(schedulerRailProvider.notifier).refresh();
      await ref.read(schedulerRunTableProvider(widget.row.id).notifier).refetchTop();
    } on ApiException catch (e) {
      if (mounted) overlay.showToast(e.message, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _runBusy = false);
    }
  }

  Future<void> _kill() async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _killBusy = true);
    try {
      await ref.read(schedulerRepositoryProvider).killWorkflow(widget.row.id);
      if (!mounted) return;
      overlay.showToast(t.killed, tone: AnTone.warn);
      setState(() => _killOpen = false);
      await ref.read(schedulerRailProvider.notifier).refresh();
      await ref.read(schedulerRunTableProvider(widget.row.id).notifier).refetchTop();
    } on ApiException catch (e) {
      if (mounted) overlay.showToast(e.message, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _killBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler;
    final c = context.colors;
    final stats = widget.stats;
    final recent = stats?.recent ?? const <String>[];
    final successRate = stats?.successRate;
    final avgMs = stats?.avgElapsedMs;
    final running = stats?.running ?? 0;

    final lifecycleWord = switch (widget.row.lifecycleState) {
      'active' => t.status.active,
      'draining' => t.status.draining,
      'inactive' => t.status.inactive,
      _ => widget.row.lifecycleState,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Wrap(
            spacing: AnGap.inlineLoose,
            runSpacing: AnGap.stackTight,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(widget.row.name, style: AnText.h2.copyWith(color: c.ink)),
              AnChip(lifecycleWord,
                  tone: widget.row.lifecycleState == 'inactive' ? AnTone.none : AnTone.accent,
                  look: AnChipLook.outlined),
            ],
          ),
        ),
        const SizedBox(width: AnGap.inlineLoose),
        AnActionGroup([
          AnButton(
            label: t.home.runNow,
            icon: AnIcons.run,
            variant: AnButtonVariant.primary,
            size: AnButtonSize.sm,
            onPressed: _runBusy ? null : _runNow,
          ),
          AnMenu(
            entries: [
              AnMenuItem(
                label: t.home.menuEdit,
                icon: AnIcons.open,
                onTap: () => goToPanel(context, 'workflow', widget.row.id),
              ),
              AnMenuItem(
                label: t.home.menuKill,
                icon: AnIcons.ban,
                danger: true,
                onTap: () => setState(() => _killOpen = true),
              ),
            ],
            anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
              AnIcons.more,
              size: AnButtonSize.sm,
              semanticLabel: t.home.moreA11y,
              onPressed: toggle,
            ),
          ),
        ]),
      ]),
      const SizedBox(height: AnGap.block),
      // Health at a glance: the near-10 bead strip + the 7d stats sentence (nulls = «—», never 0%).
      // 一眼健康:近 10 珠 + 7d 统计句(缺席渲 —,绝不装 0%)。
      Wrap(
        spacing: AnGap.inlineLoose,
        runSpacing: AnGap.stackTight,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (recent.isNotEmpty)
            RunBeadStrip(beads: [
              for (final s in recent)
                RunBead(status: AnStatus.fromRaw(s), tooltip: s),
            ]),
          Text(
            t.home.statsLine(
              window: t.home.windowWord,
              rate: successRate != null ? '${(successRate * 100).round()}%' : '—',
              avg: avgMs != null ? fmtDuration(Duration(milliseconds: avgMs)) : '—',
            ),
            style: AnText.meta.copyWith(color: c.inkMuted),
          ),
        ],
      ),
      // The :kill danger zone — AnTypeToConfirm inline (settings 先例:确认卡内联揭示,AnDialog 无
      // 自定义体), with the REAL blast radius sentence. :kill 危险区内联,影响面句真数字。
      AnExpandReveal(
        open: _killOpen,
        child: Padding(
          padding: const EdgeInsets.only(top: AnGap.block),
          child: AnTypeToConfirm(
            title: t.home.killTitle,
            warning: running > 0 ? t.home.killWarning(n: '$running') : null,
            body: Text(t.home.killBody, style: AnText.label.copyWith(color: c.inkMuted)),
            expected: widget.row.name,
            inputHint: t.home.killHint(name: widget.row.name),
            confirmLabel: t.home.killConfirm,
            busy: _killBusy,
            onConfirm: _kill,
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────── run 大表 ───────────────────────────────────

class _RunTableZone extends ConsumerStatefulWidget {
  const _RunTableZone({
    required this.workflowId,
    required this.workflowName,
    required this.runningCount,
    required this.waitingIds,
    required this.triggersById,
    required this.now,
  });

  final String workflowId;
  final String workflowName;
  final int runningCount;
  final List<String> waitingIds;
  final Map<String, TriggerEntity> triggersById;
  final DateTime now;

  @override
  ConsumerState<_RunTableZone> createState() => _RunTableZoneState();
}

class _RunTableZoneState extends ConsumerState<_RunTableZone> with BatchZone<_RunTableZone> {
  DateTime? _lastTapAt;
  String? _lastTapId;

  SchedulerRunTableController get _table =>
      ref.read(schedulerRunTableProvider(widget.workflowId).notifier);

  String _flagshipPath(String frId) => '/scheduler/w/${widget.workflowId}/runs/$frId';

  void _onRowTap(Flowrun run) {
    // First tap selects into the linked pane (URL is the truth); a quick second tap on the same row
    // goes straight to the flagship (双击进旗舰 — manual double-tap so the first tap stays instant,
    // a GestureDetector double-tap arena would delay every selection by its window).
    // 首击选入联动格(URL 真相);同行快速二击直进旗舰(手工判双击,首击零延迟)。
    final now = DateTime.now();
    final isDouble = _lastTapId == run.id &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) < const Duration(milliseconds: 300);
    _lastTapAt = now;
    _lastTapId = run.id;
    if (isDouble) {
      context.go(_flagshipPath(run.id));
    } else {
      context.go('/scheduler/w/${widget.workflowId}?run=${run.id}');
    }
  }

  // ── single-row ops ──────────────────────────────────────────────────────────

  Future<void> _cancelOne(Flowrun run) async {
    final ov = context.t.scheduler.overview;
    final overlay = ref.read(overlayProvider.notifier);
    final ok = await overlay.confirm(
      title: ov.cancelConfirmTitle,
      message: ov.cancelConfirmBody(name: widget.workflowName, id: run.id),
      confirmLabel: ov.cancelConfirmAction,
      cancelLabel: ov.cancelKeep,
      barrierLabel: ov.cancelKeep,
    );
    if (!ok || !mounted) return;
    setState(() => pending.add(run.id));
    try {
      await ref.read(schedulerRepositoryProvider).cancelRun(run.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      overlay.showToast(e.httpStatus == 422 ? ov.alreadyFinished : e.message,
          tone: e.httpStatus == 422 ? AnTone.warn : AnTone.danger);
    } finally {
      if (mounted) setState(() => pending.remove(run.id));
    }
    if (!mounted) return;
    await _table.refetchTop();
    await ref.read(schedulerRailProvider.notifier).refresh();
  }

  Future<void> _replayOne(Flowrun run) async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    final repo = ref.read(schedulerRepositoryProvider);
    setState(() => pending.add(run.id));
    (int, int)? counts;
    try {
      // Pre-flight the REAL numbers off the run's node rows (记忆化承诺文案 §10). 先取真数字。
      final comp = await repo.getRunFull(run.id);
      final c = replayCounts(comp.nodes);
      counts = (c.failed, c.completed);
    } catch (_) {
      // Numbers unavailable → still allow the replay, with the numberless sentence (honest, not
      // blocked). 取不到数字仍可重放,句子不带假数。
    } finally {
      if (mounted) setState(() => pending.remove(run.id));
    }
    if (!mounted) return;
    final ok = await overlay.confirm(
      title: t.replayTitle,
      message: counts != null
          ? t.replayBody(failed: '${counts.$1}', completed: '${counts.$2}')
          : t.replayBodyUnknown,
      confirmLabel: t.replayAction,
      cancelLabel: context.t.action.cancel,
      barrierLabel: context.t.action.cancel,
      confirmTone: AnDialogTone.primary,
    );
    if (!ok || !mounted) return;
    setState(() => pending.add(run.id));
    try {
      await repo.replayRun(run.id);
      if (mounted) overlay.showToast(t.replayed, tone: AnTone.ok);
    } on ApiException catch (e) {
      if (!mounted) return;
      overlay.showToast(e.httpStatus == 422 ? t.notReplayable : e.message,
          tone: e.httpStatus == 422 ? AnTone.warn : AnTone.danger);
    } finally {
      if (mounted) setState(() => pending.remove(run.id));
    }
    if (!mounted) return;
    await _table.refetchTop();
    await ref.read(schedulerRailProvider.notifier).refresh();
  }

  // ── batch ops (判决②:前端逐发+显式挂账) ─────────────────────────────────────

  List<Flowrun> _selectedRuns(List<Flowrun> rows) =>
      [for (final r in rows) if (selected.contains(r.id)) r];

  Future<void> _batchReplay(List<Flowrun> rows) async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    final repo = ref.read(schedulerRepositoryProvider);
    final targets = _selectedRuns(rows);
    if (targets.isEmpty) return;
    // Merge the REAL numbers across every target (合并真数字弹窗). 逐 run 取数合并。
    var failed = 0, completed = 0;
    var counted = true;
    setState(() => batchBusy = true);
    try {
      for (final r in targets) {
        final comp = await repo.getRunFull(r.id);
        final c = replayCounts(comp.nodes);
        failed += c.failed;
        completed += c.completed;
      }
    } catch (_) {
      counted = false;
    } finally {
      if (mounted) setState(() => batchBusy = false);
    }
    if (!mounted) return;
    final ok = await overlay.confirm(
      title: t.batchReplayTitle(n: '${targets.length}'),
      message: counted
          ? t.batchReplayBody(failed: '$failed', completed: '$completed')
          : t.replayBodyUnknown,
      confirmLabel: t.replayAction,
      cancelLabel: context.t.action.cancel,
      barrierLabel: context.t.action.cancel,
      confirmTone: AnDialogTone.primary,
    );
    if (!ok || !mounted) return;
    final (done, lost, err) =
        await runBatch<Flowrun>(targets, (r) => r.id, (r) => repo.replayRun(r.id));
    if (!mounted) return;
    summaryToast(
      okPart: done > 0 ? t.sumReplayed(n: '$done') : null,
      lostPart: lost > 0 ? t.sumNotReplayable(n: '$lost') : null,
      failedPart: err > 0 ? context.t.scheduler.overview.sumFailed(n: '$err') : null,
    );
    await _table.refetchTop();
    await settleRefetch();
  }

  Future<void> _batchCancel(List<Flowrun> rows) async {
    final ov = context.t.scheduler.overview;
    final overlay = ref.read(overlayProvider.notifier);
    final repo = ref.read(schedulerRepositoryProvider);
    final targets = _selectedRuns(rows);
    if (targets.isEmpty) return;
    // The danger dialog lists every victim (确认的是名单,不是数字). 弹窗带行清单。
    final list = [for (final r in targets) r.id].join('\n');
    final ok = await overlay.confirm(
      title: ov.batchCancelTitle(n: '${targets.length}'),
      message: ov.batchCancelBody(list: list),
      confirmLabel: ov.cancelConfirmAction,
      cancelLabel: ov.cancelKeep,
      barrierLabel: ov.cancelKeep,
    );
    if (!ok || !mounted) return;
    final (done, ended, err) =
        await runBatch<Flowrun>(targets, (r) => r.id, (r) => repo.cancelRun(r.id));
    if (!mounted) return;
    summaryToast(
      okPart: done > 0 ? ov.sumCancelled(n: '$done') : null,
      lostPart: ended > 0 ? ov.sumEnded(n: '$ended') : null,
      failedPart: err > 0 ? ov.sumFailed(n: '$err') : null,
    );
    await _table.refetchTop();
    await settleRefetch();
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.home;
    final c = context.colors;
    final async = ref.watch(schedulerRunTableProvider(widget.workflowId));
    final s = async.value;

    if (s == null) {
      if (async.hasError) {
        return AnSection(label: t.runsHead, children: [
          Text(t.runsError, style: AnText.body.copyWith(color: c.inkMuted)),
          const SizedBox(height: AnSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: AnButton(
                label: context.t.scheduler.retry,
                size: AnButtonSize.sm,
                onPressed: () => ref.invalidate(schedulerRunTableProvider(widget.workflowId))),
          ),
        ]);
      }
      return const AnDeferredLoading(child: AnSkeleton.lines(4));
    }

    pruneTo({for (final r in s.rows) r.id});

    // Selection mode is filter-scoped: replay lives in the failed face, cancel in the running face
    // (记裁量:all 态不混两种动作语义). 选择模式限失败/在跑两过滤态。
    final selectable = s.filter == RunStatusFilter.failed || s.filter == RunStatusFilter.running;
    final failedLabel =
        s.failedCountCapped ? '${SchedulerRunTableController.probeCap}+' : '${s.failedCount}';
    final barVisible = selectable && (selected.length >= 2 || batchBusy);

    return AnSection(
      label: t.runsHead,
      children: [
        // The count strip + origin/window dropdowns — counts are TRUE numbers (stats / probe /
        // inbox), each click IS the filter. 计数条+两下拉;真数可点即过滤。
        Wrap(
          spacing: AnGap.inlineLoose,
          runSpacing: AnGap.stackTight,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // The segmented control measures its equal segments off a BOUNDED width — it always
            // sits in a fixed control slot (settings 先例); four count labels take the XL slot.
            // 分段器按有界宽等分,恒坐定宽槽(settings 先例);四段计数走特宽槽。
            SizedBox(
              width: AnSize.ctlSlotXl,
              child: AnSegmented<RunStatusFilter>(
                value: s.filter,
                semanticLabel: t.filterA11y,
                options: [
                  AnSegmentedOption(value: RunStatusFilter.all, label: t.filterAll),
                  AnSegmentedOption(
                      value: RunStatusFilter.running,
                      label: t.filterRunning(n: '${widget.runningCount}')),
                  AnSegmentedOption(
                      value: RunStatusFilter.failed, label: t.filterFailed(n: failedLabel)),
                  AnSegmentedOption(
                      value: RunStatusFilter.waiting,
                      label: t.filterWaiting(n: '${widget.waitingIds.length}')),
                ],
                onChanged: (f) {
                  selected.clear();
                  _table.refetchTop(filter: f);
                },
              ),
            ),
            AnDropdown<String>(
              value: s.origin ?? 'all',
              variant: AnDropdownVariant.ghost,
              options: [
                AnDropdownOption(value: 'all', label: t.originAll),
                AnDropdownOption(value: 'manual', label: t.originManual),
                AnDropdownOption(value: 'chat', label: t.originChat),
                AnDropdownOption(value: 'cron', label: t.originCron),
                AnDropdownOption(value: 'webhook', label: t.originWebhook),
                AnDropdownOption(value: 'fsnotify', label: t.originFsnotify),
                AnDropdownOption(value: 'sensor', label: t.originSensor),
              ],
              onChanged: (v) => _table.refetchTop(
                  origin: v == 'all' ? null : v, clearOrigin: v == 'all'),
            ),
            AnDropdown<RunWindow>(
              value: s.window,
              variant: AnDropdownVariant.ghost,
              options: [
                AnDropdownOption(value: RunWindow.h24, label: t.window24h),
                AnDropdownOption(value: RunWindow.d7, label: t.window7d),
                AnDropdownOption(value: RunWindow.d30, label: t.window30d),
                AnDropdownOption(value: RunWindow.all, label: t.windowAll),
              ],
              onChanged: (w) => _table.refetchTop(window: w),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s8),
        // «N 条新运行» — the follow pill; new runs NEVER insert rows (§0 军规), the user pulls them
        // in. pill 归位,新 run 绝不插行。
        if (s.newRuns > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnFollowPill.jump(
                label: t.newRuns(n: '${s.newRuns}'),
                onTap: () => _table.refetchTop(),
              ),
            ),
          ),
        AnExpandReveal(
          open: barVisible,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s8),
            child: AnBatchBar(
              count: selected.length,
              busy: batchBusy,
              actions: [
                if (s.filter == RunStatusFilter.failed)
                  BatchAction(
                      label: t.batchReplay,
                      icon: AnIcons.history,
                      tone: AnTone.accent,
                      onRun: () => _batchReplay(s.rows)),
                if (s.filter == RunStatusFilter.running)
                  BatchAction(
                      label: context.t.scheduler.overview.batchCancel,
                      icon: AnIcons.stop,
                      tone: AnTone.danger,
                      onRun: () => _batchCancel(s.rows)),
              ],
              onClear: () => setState(selected.clear),
            ),
          ),
        ),
        if (s.rows.isEmpty)
          Text(t.runsEmpty, style: AnText.body.copyWith(color: c.inkFaint))
        else ...[
          for (final run in s.rows)
            AnExpandReveal(open: !leaving.contains(run.id), child: _row(context, s, run)),
          if (s.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: s.loadingMore
                    ? const AnSkeleton.row()
                    : AnButton(label: t.loadMore, size: AnButtonSize.sm, onPressed: _table.loadMore),
              ),
            )
          else
            // THE RETENTION TOMBSTONE (判决④/工单⑬). At the true bottom of the history, say why the
            // history ends — an unexplained last row silently implies «this workflow never ran before
            // then», which is false. The backend ships NO field for this (the tombstone is a
            // presentation decision, 工单⑬ 裁量): the front end reads the same `GET /retention` the
            // storage panel edits, so the two can never disagree. Forever (0) → no sweeper → no
            // tombstone: there is nothing to explain.
            // **保留墓碑**(判决④/⑬)。翻到历史真正的底部时,说明历史为什么在此结束——一个没有解释的末行会
            // 静默暗示「这个 workflow 在那之前从没跑过」,而那是假的。后端为此**不发任何字段**(墓碑是**呈现**
            // 决策,⑬ 裁量):前端读的是存储面板所编辑的**同一个** `GET /retention`,故两处永不矛盾。
            // 永久(0)→ 不清理 → **不渲**墓碑:没有什么需要解释。
            _Tombstone(),
        ],
      ],
    );
  }

  /// One run row — identity is the SOURCE PHRASE (GHA「cron run 全长一样」之鉴); the mono fr_ id
  /// demotes to a chip. 一行:身份=来源短语,fr_ id 降 chip。
  Widget _row(BuildContext context, RunTableState s, Flowrun run) {
    final t = context.t.scheduler.home;
    final source = runSourceOf(run, widget.triggersById);
    final key = run.id;
    final isPending = pending.contains(key) || batchBusy && selected.contains(key);
    final selectable = s.filter == RunStatusFilter.failed || s.filter == RunStatusFilter.running;
    final hovered = hoveredKey == key;
    final showCheck = selectable && (selected.isNotEmpty || hovered) && !isPending;
    final running = run.status == 'running';
    final failed = run.status == 'failed';

    final primary = switch (source.origin) {
      'manual' => t.srcManual,
      'chat' => t.srcChat,
      'cron' => source.detail != null ? t.srcCron(at: source.detail!) : t.srcCronBare,
      'webhook' =>
        source.detail != null ? t.srcWithName(kind: t.srcWebhookBare, name: source.detail!) : t.srcWebhookBare,
      'fsnotify' =>
        source.detail != null ? t.srcWithName(kind: t.originFsnotify, name: source.detail!) : t.originFsnotify,
      'sensor' =>
        source.detail != null ? t.srcWithName(kind: t.originSensor, name: source.detail!) : t.originSensor,
      _ => t.srcUnknown,
    };

    // Elapsed: finished → precise; running → the pulse-driven coarse live measure (脉搏只刷字).
    // 耗时:落定精确;在跑走脉搏粗粒活计时。
    final started = run.startedAt;
    final String? elapsed;
    if (run.completedAt != null && started != null) {
      elapsed = fmtDuration(run.completedAt!.difference(started));
    } else if (running && started != null) {
      elapsed = fmtWaited(widget.now.difference(started));
    } else {
      elapsed = null;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => hoveredKey = key),
      onExit: (_) => setState(() {
        if (hoveredKey == key) hoveredKey = null;
      }),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: AnLedgerRow(
            lead: isPending
                ? const AnSpinner(size: AnSize.iconSm)
                : showCheck
                    ? AnBatchCheck(
                        checked: selected.contains(key),
                        semanticLabel: context.t.scheduler.overview.selectRow(name: run.id),
                        onChanged: (v) =>
                            setState(() => v ? selected.add(key) : selected.remove(key)),
                      )
                    : AnStatusDot(AnStatus.fromRaw(run.status)),
            primary: primary,
            mono: false,
            chips: [
              // origin=chat carries its conversation coordinate — navigable via the panel registry
              // (真名缝不存在,mono id 记偏差). chat 行带对话坐标(mono id;真名缝待建)。
              if (source.conversationId != null && source.conversationId!.isNotEmpty)
                toolNavPill(context,
                    kind: 'conversation',
                    label: truncate(source.conversationId!, AnTrunc.id),
                    id: source.conversationId),
              AnChip(truncate(run.id, AnTrunc.id),
                  mono: true, look: AnChipLook.outlined, tooltip: run.id),
              if (run.replayCount > 0)
                AnChip(context.t.run.replayTimes(n: '${run.replayCount}'),
                    look: AnChipLook.outlined),
            ],
            sub: failed ? _errorFirstLine(run.error) : null,
            subTone: AnTone.danger,
            measure: elapsed,
            meta: context.t.scheduler
                .agoMeta(d: fmtWaited(widget.now.difference(started ?? run.updatedAt))),
            onTap: () => _onRowTap(run),
          ),
        ),
        const SizedBox(width: AnSpace.s6),
        // The hover tail op — a RESERVED cell (hover 零位移): ⏹ on running rows, ↻ on failed rows.
        // hover 行尾定宽格:在跑 ⏹ / 失败 ↻。
        Visibility(
          visible: hovered && !isPending && !batchBusy && (running || failed),
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: running
              ? AnButton.iconOnly(
                  AnIcons.stop,
                  size: AnButtonSize.sm,
                  variant: AnButtonVariant.danger,
                  semanticLabel: context.t.scheduler.overview.cancelRunA11y(id: run.id),
                  onPressed: () => _cancelOne(run),
                )
              : AnButton.iconOnly(
                  AnIcons.history,
                  size: AnButtonSize.sm,
                  semanticLabel: t.replayA11y(id: run.id),
                  onPressed: () => _replayOne(run),
                ),
        ),
      ]),
    );
  }

  String? _errorFirstLine(String? error) {
    if (error == null) return null;
    for (final line in error.split('\n')) {
      final s = line.trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }
}

/// The retention tombstone — rendered only at the true end of a run history, and only when a
/// retention line actually exists. Reads its own truth (the machine-level `GET /retention`), so it
/// stays silent until it knows: an unresolved read renders NOTHING rather than guess a number, and
/// «forever» renders nothing because nothing was cleared.
/// 保留墓碑:只在 run 历史真正的末尾渲,且只在**确实存在**保留线时渲。它读自己的真相(机器级
/// `GET /retention`),故在知道之前**闭嘴**:读不到就什么都不渲、绝不猜一个数;永久也不渲,因为什么都没被清理。
class _Tombstone extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(schedulerRetentionProvider).value;
    if (cfg == null || cfg.forever) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s8),
      child: Text(
        context.t.scheduler.home.tombstone(d: '${cfg.runRetentionDays}'),
        style: AnText.meta.copyWith(color: context.colors.inkFaint),
      ),
    );
  }
}

// ─────────────────────────────────── 联动格 ───────────────────────────────────

class _LinkedRunPane extends ConsumerStatefulWidget {
  const _LinkedRunPane({required this.workflowId, required this.flowrunId});

  final String workflowId;
  final String flowrunId;

  @override
  ConsumerState<_LinkedRunPane> createState() => _LinkedRunPaneState();
}

/// The linked pane's three lenses on ONE selection (判决③). Gantt and graph are single-run lenses —
/// «how long» and «which path». The MATRIX is the only one that spans runs, and it is here for the
/// question the other two are structurally blind to: **is this node always the one that breaks, or was
/// it just this once.** Default stays gantt (§4.3:「甘特是单 run 的透镜非一等页面」).
/// 联动格对**同一选区**的三个透镜(判决③):甘特与图是单 run 透镜(多久 / 走了哪条路);**矩阵**是唯一跨 run
/// 的那个,它在此是为了另两者**结构上看不见**的那个问题:**这个节点是老是坏,还是就坏了这一次**。默认仍甘特。
enum _PaneFace { gantt, graph, matrix }

class _LinkedRunPaneState extends ConsumerState<_LinkedRunPane> {
  _PaneFace _face = _PaneFace.gantt;

  /// The matrix's ROW grain (§12 三粒度) — which node's history is lit. The RUN grain already lives in
  /// the URL (`?run=`), so the two grains stay in their honest homes: the run is shareable state, the
  /// node highlight is a local lens. There is no right island on this page (§6), so a cell tap lands
  /// its run in the URL and its node here — it never jumps pages.
  /// 矩阵的**行**粒度(§12):哪个节点的历史被点亮。**run** 粒度已经住在 URL(`?run=`)里,故两个粒度各归其位:
  /// run 是可分享的状态、节点高亮是本地透镜。本页无右岛(§6),故点格=run 落 URL、节点落这里,绝不跳页。
  String? _pickedNode;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.home;
    final c = context.colors;
    final runAsync = ref.watch(schedulerLinkedRunProvider(widget.flowrunId));
    final wfAsync = ref.watch(schedulerWorkflowProvider(widget.workflowId));

    Widget body;
    final comp = runAsync.value;
    if (_face == _PaneFace.matrix) {
      body = _matrixFace(context);
    } else if (comp != null) {
      final graph = graphOfVersion(wfAsync.value?.activeVersion);
      if (_face == _PaneFace.gantt) {
        final rows = flowrunTimeline(graph ?? const Graph(), comp);
        body = rows.isEmpty
            ? Text(t.paneNoNodes, style: AnText.body.copyWith(color: c.inkFaint))
            : AnNodeGantt(
                rows: rows,
                notRunLabel: t.notRun,
                waitingLabel: context.t.run.nodeWait,
              );
      } else if (graph != null) {
        body = AnGraphCanvas(
          graph: graph,
          framed: true,
          run: deriveRunState(graph, rows: comp.nodes, runStatus: comp.flowrun.status),
        );
      } else if (!wfAsync.hasValue && !wfAsync.hasError) {
        body = const AnDeferredLoading(child: AnSkeleton.lines(3));
      } else {
        body = Text(t.noGraph, style: AnText.body.copyWith(color: c.inkFaint));
      }
    } else if (runAsync.hasError) {
      body = Row(children: [
        Expanded(child: Text(t.paneError, style: AnText.body.copyWith(color: c.inkMuted))),
        AnButton(
            label: context.t.scheduler.retry,
            size: AnButtonSize.sm,
            onPressed: () => ref.invalidate(schedulerLinkedRunProvider(widget.flowrunId))),
      ]);
    } else {
      body = const AnDeferredLoading(child: AnSkeleton.lines(3));
    }

    return AnCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Wrap(
              spacing: AnGap.inlineLoose,
              runSpacing: AnGap.stackTight,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_face == _PaneFace.matrix ? t.matrixTitle : t.linkedTitle,
                    style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
                AnChip(truncate(widget.flowrunId, AnTrunc.id),
                    mono: true, look: AnChipLook.outlined, tooltip: widget.flowrunId),
                if (comp != null) AnStatusDot(AnStatus.fromRaw(comp.flowrun.status)),
              ],
            ),
          ),
          const SizedBox(width: AnGap.inlineLoose),
          // Three faces → the WIDE control slot (the token's own rule: 3+-segment segmented).
          // 三脸走**宽**控件槽(token 自身之律:3+ 段分段器)。
          SizedBox(
            width: AnSize.ctlSlotLg,
            child: AnSegmented<_PaneFace>(
              value: _face,
              semanticLabel: t.faceA11y,
              options: [
                AnSegmentedOption(value: _PaneFace.gantt, label: t.faceGantt),
                AnSegmentedOption(value: _PaneFace.graph, label: t.faceGraph),
                AnSegmentedOption(value: _PaneFace.matrix, label: t.faceMatrix),
              ],
              onChanged: (f) => setState(() => _face = f),
            ),
          ),
          const SizedBox(width: AnGap.inlineLoose),
          AnButton(
            label: t.openRun,
            size: AnButtonSize.sm,
            onPressed: () =>
                context.go('/scheduler/w/${widget.workflowId}/runs/${widget.flowrunId}'),
          ),
        ]),
        const SizedBox(height: AnGap.block),
        body,
      ]),
    );
  }

  /// The matrix face (判决③ + 工单⑩). Three grains, each landing where it honestly belongs: a COLUMN
  /// picks the run (into the URL — shareable, and the gantt/graph faces follow it); a ROW lights that
  /// node's history (a local lens); a CELL does both. Nothing jumps pages — 「打开 →」 is still the one
  /// door to the flagship.
  /// 矩阵脸(判决③+⑩)。三粒度各落其位:**列**选中 run(落 URL——可分享,且甘特/图两脸跟着它走)、**行**点亮
  /// 该节点的历史(本地透镜)、**格**两者都做。全程不跳页——「打开 →」仍是通往旗舰的唯一那扇门。
  Widget _matrixFace(BuildContext context) {
    final t = context.t.scheduler.home;
    final c = context.colors;
    final async = ref.watch(schedulerMatrixProvider(widget.workflowId));
    final m = async.value;
    if (m == null) {
      if (async.hasError) {
        return Row(children: [
          Expanded(child: Text(t.paneError, style: AnText.body.copyWith(color: c.inkMuted))),
          AnButton(
              label: context.t.scheduler.retry,
              size: AnButtonSize.sm,
              onPressed: () => ref.invalidate(schedulerMatrixProvider(widget.workflowId))),
        ]);
      }
      return const AnDeferredLoading(child: AnSkeleton.lines(3));
    }
    if (m.rows.isEmpty || m.cols.isEmpty) {
      return Text(t.matrixEmpty, style: AnText.body.copyWith(color: c.inkFaint));
    }
    // The sparse cell list → an O(1) lookup. NEVER assume cells == rows×cols (稀疏是契约).
    // 稀疏格列表 → O(1) 查询;绝不假设 cells == rows×cols(稀疏是契约)。
    final byKey = {for (final cell in m.cells) '${cell.flowrunId}/${cell.nodeId}': cell};
    return AnRunMatrix(
      rows: [for (final r in m.rows) MatrixRowHead(nodeId: r.nodeId, kind: r.kind)],
      cols: [
        for (final col in m.cols)
          RunColumn(
            id: col.flowrunId,
            status: col.status,
            elapsedMs: col.elapsedMs,
            label: t.matrixColA11y(
              id: truncate(col.flowrunId, AnTrunc.id),
              status: runStatusWord(context.t, col.status),
              // A run still going has no elapsed — say «running», never a fabricated duration.
              // 在跑的 run 无耗时——说「在跑」,绝不编一个时长。
              d: col.elapsedMs == null
                  ? t.matrixRunning
                  : fmtDuration(Duration(milliseconds: col.elapsedMs!)),
            ),
          ),
      ],
      cellStatus: (frId, nodeId) {
        final cell = byKey['$frId/$nodeId'];
        if (cell == null) return null; // 未及 — sparse, and that IS the answer 稀疏即答案
        return MatrixCellState(
          status: cell.status,
          iterations: cell.iterations,
          label: t.matrixCellA11y(
              node: nodeId, status: runStatusWord(context.t, cell.status), n: '${cell.iterations}'),
        );
      },
      selection: MatrixSelection(flowrunId: widget.flowrunId, nodeId: _pickedNode),
      onCell: (frId, nodeId) {
        setState(() => _pickedNode = nodeId);
        if (frId != widget.flowrunId) context.go('/scheduler/w/${widget.workflowId}?run=$frId');
      },
      onCol: (frId) {
        if (frId != widget.flowrunId) context.go('/scheduler/w/${widget.workflowId}?run=$frId');
      },
      onRow: (nodeId) => setState(() => _pickedNode = _pickedNode == nodeId ? null : nodeId),
      notReachedLabel: t.matrixNotReached,
      runningLabel: t.matrixRunning,
      cellSemanticLabel: (col, row, cell) => t.matrixCellA11y(
          node: row.nodeId,
          status: cell == null
              ? t.matrixNotReached
              : runStatusWord(context.t, cell.status),
          n: '${cell?.iterations ?? 0}'),
      colSemanticLabel: (col) => t.matrixColA11y(
          id: truncate(col.id, AnTrunc.id),
          status: runStatusWord(context.t, col.status),
          d: col.elapsedMs == null
              ? t.matrixRunning
              : fmtDuration(Duration(milliseconds: col.elapsedMs!))),
      rowSemanticLabel: (row) => t.matrixRowA11y(node: row.nodeId),
    );
  }
}

// ─────────────────────────────────── triggers 陈列 ───────────────────────────────────

class _TriggersZone extends ConsumerWidget {
  const _TriggersZone({required this.workflowId, required this.triggers, required this.now});

  final String workflowId;
  final List<TriggerEntity> triggers;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.scheduler.home;
    final c = context.colors;
    return AnSection(
      label: t.triggersHead,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AnSpace.s8),
          child: Text(t.triggersEditHint, style: AnText.meta.copyWith(color: c.inkFaint)),
        ),
        if (triggers.isEmpty)
          Text(t.triggersEmpty, style: AnText.body.copyWith(color: c.inkFaint))
        else
          for (final trigger in triggers)
            Padding(
              padding: const EdgeInsets.only(bottom: AnGap.block),
              child: _TriggerCard(trigger: trigger, now: now),
            ),
      ],
    );
  }
}

class _TriggerCard extends ConsumerStatefulWidget {
  const _TriggerCard({required this.trigger, required this.now});

  final TriggerEntity trigger;
  final DateTime now;

  @override
  ConsumerState<_TriggerCard> createState() => _TriggerCardState();
}

class _TriggerCardState extends ConsumerState<_TriggerCard> {
  bool _busy = false;

  Future<void> _pause() async {
    final t = context.t.scheduler.home;
    final overlay = ref.read(overlayProvider.notifier);
    // The stop-the-bleeding switch confirms its EXACT semantics (§10). 止血开关点明语义。
    final ok = await overlay.confirm(
      title: t.pauseTitle(name: widget.trigger.name),
      message: t.pauseBody,
      confirmLabel: t.pauseAction,
      cancelLabel: context.t.action.cancel,
      barrierLabel: context.t.action.cancel,
      confirmTone: AnDialogTone.primary,
    );
    if (!ok || !mounted) return;
    await _flip((repo) => repo.pauseTrigger(widget.trigger.id));
  }

  /// Resume is harmless + idempotent — no dialog (记裁量). 恢复无害幂等,不弹确认。
  Future<void> _resume() => _flip((repo) => repo.resumeTrigger(widget.trigger.id));

  Future<void> _flip(Future<TriggerEntity> Function(SchedulerRepository) op) async {
    final overlay = ref.read(overlayProvider.notifier);
    setState(() => _busy = true);
    try {
      await op(ref.read(schedulerRepositoryProvider));
      // The card, the rail meta and the Overview lanes all follow the ONE refetch. 三面随一次 refetch。
      await ref.read(schedulerRailProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (mounted) overlay.showToast(e.message, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler;
    final c = context.colors;
    final trigger = widget.trigger;
    final paused = trigger.paused;
    final cron = trigger.config['cron'];
    final nextFire = trigger.nextFireAt;

    final kindIcon = switch (trigger.kind) {
      TriggerSource.cron => AnIcons.scheduler,
      TriggerSource.webhook => AnIcons.trigger,
      TriggerSource.fsnotify => AnIcons.folder,
      TriggerSource.sensor => AnIcons.activity,
      TriggerSource.unknown => AnIcons.trigger,
    };

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: AnGap.inlineLoose,
        runSpacing: AnGap.stackTight,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(kindIcon, size: AnSize.iconSm, color: c.inkMuted),
          Text(trigger.name, style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
          if (cron is String && cron.isNotEmpty)
            AnChip(cron, mono: true, look: AnChipLook.outlined),
          if (paused) AnChip(t.home.paused, tone: AnTone.warn),
        ],
      ),
      const SizedBox(height: AnGap.stackTight),
      // The schedule sentence: next fire (relative + absolute tooltip-free meta) · last fired.
      // Paused → nextFireAt reads absent on the wire, so the sentence naturally drops it (诚实).
      // 调度句:下次(相对)·上次;暂停时线缆 nextFireAt 缺席,句子自然收起。
      Text(
        [
          if (nextFire != null && nextFire.isAfter(widget.now))
            t.home.nextFire(d: fmtWaited(nextFire.difference(widget.now)), at: fmtDateTime(nextFire)),
          if (trigger.lastFiredAt != null)
            t.home.lastFired(d: fmtWaited(widget.now.difference(trigger.lastFiredAt!)))
          else
            t.home.neverFired,
        ].join(' · '),
        style: AnText.meta.copyWith(color: c.inkMuted),
      ),
    ]);

    return AnCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          // A paused card greys its INFO cluster only — the controls stay fully alive (你得能一眼
          // 恢复). 暂停灰显只罩信息簇,控件保持全活。
          child: paused ? Opacity(opacity: AnOpacity.disabled, child: info) : info,
        ),
        const SizedBox(width: AnGap.inlineLoose),
        AnActionGroup([
          AnButton(
            label: paused ? t.home.resume : t.home.pause,
            icon: paused ? AnIcons.run : AnIcons.pause,
            size: AnButtonSize.sm,
            outline: true,
            onPressed: _busy ? null : (paused ? _resume : _pause),
          ),
          AnButton.iconOnly(
            AnIcons.open,
            size: AnButtonSize.sm,
            semanticLabel: t.home.editTriggerA11y(name: trigger.name),
            onPressed: () => goToPanel(context, 'trigger', trigger.id),
          ),
        ]),
      ]),
    );
  }
}
