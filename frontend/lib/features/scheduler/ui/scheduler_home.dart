import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/scheduler_stats.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/model/time_range.dart';
import '../../../core/run/provenance_line.dart';
import '../../../core/run/run_nav.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../data/scheduler_repository.dart';
import '../state/scheduler_home_provider.dart';
import '../state/scheduler_rail_provider.dart';
import '../state/selected_scheduler.dart';
import 'batch_engine.dart';
import 'run_peek_card.dart';
import 'scheduler_home_model.dart';
import 'run_phrase.dart';

/// The workflow operations home (`/scheduler/w/:id`, WRK-069 §4, 主页重建拍板 0717) — one document
/// flow, four segments: health head (name + lifecycle + 7d stat numbers + Run now + ⋯; the bead
/// strip is GONE — the matrix's column heads carry the same news) → the MATRIX zone (the page-level
/// time-range capsule + the chronological node×run grid anchored at the newest end; a column/cell
/// click NAVIGATES to the run flagship — `?node=` preselected from a cell) → the run big table
/// (source-phrase rows, count-strip filter, follow pill, batch replay/cancel; a row tap expands the
/// INLINE peek card under it — gantt ⇄ graph + the flagship door; `?run=` in the URL is the one
/// expanded row, tap again collapses, a fast double-tap goes straight to the flagship) → the
/// triggers exhibit. ONE time range governs matrix + table (the capsule); the old bottom linked
/// pane is deleted. 活性军规 holds: the half-minute pulse refreshes time text only; new runs ride
/// the pill, never a row.
///
/// workflow 运营主页(0717 拍板):四段文档流——健康头(珠串删,矩阵列头即同一条新闻)→ **矩阵区**(页级
/// 时间范围胶囊 + 时序格阵锚最新端;点列/点格**导航**进 run 旗舰,格带 ?node= 预选)→ run 大表(点行=
/// 行底**行内速览卡**[甘特⇄图+旗舰门],?run= 即展开的那一行、再点收起、快速双击直进旗舰)→ triggers
/// 陈列。一颗胶囊治矩阵+大表;底部联动格已删。脉搏只刷时间字;新 run 走 pill 绝不插行。
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

    // Every section lives in AnPage's 720 reading column (用户 0717 判决,见 AnPage 类文档): the
    // matrix carries its own anchored horizontal scroller, the peek card's gantt is a normalized
    // [0,1] track and its graph pans/zooms in an InteractiveViewer — wide things answer width on
    // their OWN, never by asking the page.
    // 每一段都住 AnPage 的 720 阅读列:矩阵自带锚定横滚、速览卡的甘特是 [0,1] 分数轨、图在
    // InteractiveViewer 里平移缩放——宽的东西各自解决宽度,不向页面讨。
    return AnPage(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HealthHead(row: row, stats: stats, now: now),
          Padding(
            padding: const EdgeInsets.only(top: AnGap.section),
            child: _MatrixZone(workflowId: row.id, linkedRunId: widget.linkedRunId),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AnGap.section),
            child: _RunTableZone(
              workflowId: row.id,
              workflowName: row.name,
              triggersById: triggersById,
              linkedRunId: widget.linkedRunId,
              now: now,
            ),
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
    // The kill blast radius reads the rail's CURRENT running count (a "now" number, deliberately
    // not the range's). 击杀影响面读 rail 的**此刻**在跑数(刻意不随范围)。
    final running = widget.stats?.running ?? 0;
    // The stats sentence FOLLOWS the page-level range (需求②) — its own 1-id fetch, window word =
    // the capsule's word. Numbers render ONLY when the resolved answer's range stamp matches the
    // capsule (复审 0717-晚): during a capsule-switch reload Riverpod keeps the previous value, and
    // pairing the new window word with the old range's numbers would be a factually false sentence
    // — so the switch renders «—» until the new window's numbers land.
    // 统计句跟随页级范围——独立 1-id 取数,窗口词=胶囊之词;数字只在答案的范围章与胶囊相符时渲染:换
    // 胶囊的 reload 期间 Riverpod 保留旧值,新窗口词配旧范围数字=句子撒谎,故切换期渲「—」等新数落地。
    final range = ref.watch(schedulerTimeRangeProvider);
    final stamped = ref.watch(schedulerRangeStatsProvider(widget.row.id)).value;
    final rangeStats = stamped != null && stamped.range == range ? stamped.stats : null;
    final successRate = rangeStats?.successRate;
    final avgMs = rangeStats?.avgElapsedMs;

    final lifecycleWord = switch (widget.row.lifecycleState) {
      'active' => t.status.active,
      'draining' => t.status.draining,
      'inactive' => t.status.inactive,
      _ => widget.row.lifecycleState,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // The documentary page head (需求③, entities 同款文法): in-page crumb → big H2 title → meta
      // row (lifecycle badge · range-scoped stats sentence · THE page-level time capsule) → actions.
      // 文档化页头(entities 同文法):页内面包屑 → 大标题 → meta 行(生命周期徽 · 范围统计句 · 页级时间
      // 胶囊)→ 右侧动作。
      AnOceanHeader(
        crumbs: [t.home.crumbRoot],
        title: widget.row.name,
        meta: [
          AnChip(lifecycleWord,
              tone: widget.row.lifecycleState == 'inactive' ? AnTone.none : AnTone.accent,
              look: AnChipLook.outlined),
          // The capsule FIRST, the numbers after — the window is stated exactly ONCE, by the
          // capsule, and the sentence carries only what the capsule can't (用户 0717-深夜拍板:
          // 「胶囊放前面,成功率放后面,去掉句子的近七天」——同词双显删).
          // 胶囊在前、数字在后——窗口只由胶囊陈述一次,句子只说胶囊说不了的数;同词双显删。
          AnTimeRangePicker(
            value: range,
            onChanged: (r) => ref.read(schedulerTimeRangeProvider.notifier).set(r),
            strings: _rangeStrings(context),
          ),
          Text(
            t.home.statsLine(
              rate: successRate != null ? '${(successRate * 100).round()}%' : '—',
              avg: avgMs != null ? fmtDuration(Duration(milliseconds: avgMs)) : '—',
            ),
            style: AnText.meta.copyWith(color: c.inkMuted),
          ),
        ],
        actions: [
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
    required this.triggersById,
    required this.linkedRunId,
    required this.now,
  });

  final String workflowId;
  final String workflowName;
  final Map<String, TriggerEntity> triggersById;

  /// `?run=` — the ONE expanded row (URL is the truth; absent id expands nothing). ?run==展开行。
  final String? linkedRunId;
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
    // First tap TOGGLES the inline peek card under the row (URL is the truth: `?run=` is the one
    // expanded row; tapping the expanded row again collapses). A quick second tap on the same row
    // goes straight to the flagship (双击进旗舰 — manual double-tap so the first tap stays instant,
    // a GestureDetector double-tap arena would delay every expansion by its window).
    // 首击开合行内速览卡(URL 真相:?run= 即展开行,再点收起);同行快速二击直进旗舰(手工判双击,首击零延迟)。
    final now = DateTime.now();
    final isDouble = _lastTapId == run.id &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) < const Duration(milliseconds: 300);
    _lastTapAt = now;
    _lastTapId = run.id;
    if (isDouble) {
      context.go(_flagshipPath(run.id));
    } else if (run.id == widget.linkedRunId) {
      context.go('/scheduler/w/${widget.workflowId}');
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
    // All three numbers are RANGE-SCOPED probes through the rows' own grammar (复审 [5] 口径同源
    // ——stats.running 是全史「此刻」数,与按 started_at 开窗的行会在窗口边缘打架). 三数皆同文法探针。
    final failedLabel =
        s.failedCountCapped ? '${SchedulerRunTableController.probeCap}+' : '${s.failedCount}';
    final runningLabel =
        s.runningCountCapped ? '${SchedulerRunTableController.probeCap}+' : '${s.runningCount}';
    final barVisible = selectable && (selected.length >= 2 || batchBusy);

    return AnSection(
      label: t.runsHead,
      variant: AnSectionVariant.plain,
      children: [
        // ONE controls block (WRK-070 B3 用户点名「选择器和下面为什么又空了这么多」): the filter +
        // follow pill + batch bar are a single AnSection child so their collapsed AnExpandReveals no
        // longer get double-gapped by the section's 12px inter-child rhythm (a bare collapsed reveal
        // + the old self-margin SizedBox summed to a 44px void). Now: title → 12 → controls → 12 →
        // row1. 控制块合一子件:过滤条+pill+批量条塌缩不再被 AnSection 双夹成 44px 空洞。
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
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
                      label: t.filterRunning(n: runningLabel)),
                  AnSegmentedOption(
                      value: RunStatusFilter.failed, label: t.filterFailed(n: failedLabel)),
                  AnSegmentedOption(
                      value: RunStatusFilter.waiting,
                      label: t.filterWaiting(n: '${s.waitingCount}')),
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
            // The 24h/7d/30d window dropdown is GONE (0717 拍板): the page-level time-range
            // capsule above the matrix governs this table too — one lens, two zones, zero drift.
            // 时间窗下拉已删:矩阵上方的页级时间范围胶囊同治本表——一颗镜头两个区,零漂移。
          ],
        ),
        // «N 条新运行» — the follow pill; new runs NEVER insert rows (§0 军规), the user pulls them
        // in. Padding TOP so it hugs the filter above (collapses cleanly when absent). pill 归位。
        if (s.newRuns > 0)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s8),
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
            padding: const EdgeInsets.only(top: AnSpace.s8),
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
        ]),
        if (s.rows.isEmpty)
          Text(t.runsEmpty, style: AnText.body.copyWith(color: c.inkFaint))
        else ...[
          for (final run in s.rows)
            AnExpandReveal(open: !leaving.contains(run.id), child: _row(context, s, run)),
          // The standard page-number pager (B4): 10/page + ‹/›/numbers/jump; a single page renders
          // nothing (AnPager self-hides). The «等人» filter is UNPAGED (running∩inbox shown whole,
          // 复审 [1]/[5]): its total can exceed pageSize yet all rows are already on screen, so the
          // pager would be inert — gate it out. 标准翻页器;等人过滤不分页(全展),故不渲翻页器免死钮。
          if (s.filter != RunStatusFilter.waiting &&
              s.total > SchedulerRunTableController.pageSize)
            Padding(
              padding: const EdgeInsets.only(top: AnGap.block),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnPager(
                  page: s.page,
                  pageCount:
                      (s.total + SchedulerRunTableController.pageSize - 1) ~/
                          SchedulerRunTableController.pageSize,
                  onPage: (p) => _table.setPage(p),
                  strings: AnPagerStrings(
                    prevLabel: t.pagerPrev,
                    nextLabel: t.pagerNext,
                    jumpHint: t.pagerJump,
                    pageLabel: (n) => t.pagerPage(n: '$n'),
                  ),
                ),
              ),
            ),
          // The retention tombstone is GONE (WRK-070 B3 用户裁「没用+占位怪异」)。墓碑句删。
        ],
      ],
    );
  }

  /// One run row (需求⑦ 0717-晚重排): identity = SOURCE PHRASE + start instant on the LEFT; the
  /// actionable verb (⏹/↻) rides RIGHT AFTER it, persistent — never a hover-revealed far-edge cell
  /// that reserves space on every row. The right edge carries the EXECUTION DURATION alone (the
  /// left already says «when», the old relative "ago" was the same fact twice). Bare ids are gone
  /// from rows (需求⑤) — the full id lives in the peek card and tooltips.
  /// 一行(0717-晚重排):左=来源短语+开始时刻,可操作动词(⏹/↻)**紧随其后常驻**——不再是给所有行占位的
  /// hover 行尾格;右缘只留**执行时长**(左边已说「何时」,旧相对时间是同一事实说两遍)。行内无裸 id
  /// (完整 id 收进速览卡与 tooltip)。
  Widget _row(BuildContext context, RunTableState s, Flowrun run) {
    final t = context.t.scheduler.home;
    final key = run.id;
    final isPending = pending.contains(key) || batchBusy && selected.contains(key);
    final selectable = s.filter == RunStatusFilter.failed || s.filter == RunStatusFilter.running;
    final hovered = hoveredKey == key;
    final showCheck = selectable && (selected.isNotEmpty || hovered) && !isPending;
    final running = run.status == 'running';
    final failed = run.status == 'failed';

    // EVERY origin carries its start instant (the ONE phrase grammar, run_phrase.dart). 统一短语文法。
    final started = run.startedAt;
    final primary = runPhrase(context, run, widget.triggersById, widget.now);

    // Elapsed: finished → precise; running → the pulse-driven coarse live measure (脉搏只刷字).
    // 耗时:落定精确;在跑走脉搏粗粒活计时。
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
      child: AnLedgerRow(
        expanded: run.id == widget.linkedRunId,
        // Lazy (C-006): a collapsed row NEVER builds its peek card — an eager card per row
        // would fetch full run composites for rows nobody opened.
        // 惰性:收起的行绝不建速览卡——每行急建会替没人点开的行拉全量 run 复合。
        expandBuilder: (_) => RunPeekCard(workflowId: widget.workflowId, flowrunId: run.id),
        lead: isPending
            ? const AnSpinner(size: AnSize.iconSm)
            : showCheck
                ? AnBatchCheck(
                    checked: selected.contains(key),
                    semanticLabel: context.t.scheduler.overview.selectRow(name: run.id),
                    onChanged: (v) =>
                        setState(() => v ? selected.add(key) : selected.remove(key)),
                  )
                // The disclosure hand (B4): expanded wears ▾; a hovered collapsed row morphs its
                // dot into ▸ — «this opens». 披露示能:展开 ▾;hover 点变 ▸——「这里能点开」。
                : run.id == widget.linkedRunId
                    ? Icon(AnIcons.chevronDown,
                        size: AnSize.iconSm, color: context.colors.inkMuted)
                    : hovered
                        ? Icon(AnIcons.chevronRight,
                            size: AnSize.iconSm, color: context.colors.inkMuted)
                        : AnStatusDot(AnStatus.fromRaw(run.status)),
        primary: primary,
        mono: false,
        chips: [
          // The persistent verb, right where the eye already is (需求⑦). 常驻动词,紧随视线。
          if (running)
            AnButton(
              label: t.rowCancel,
              icon: AnIcons.stop,
              size: AnButtonSize.sm,
              variant: AnButtonVariant.danger,
              onPressed: isPending || batchBusy ? null : () => _cancelOne(run),
            )
          else if (failed)
            AnButton(
              label: t.rowRetry,
              icon: AnIcons.history,
              size: AnButtonSize.sm,
              onPressed: isPending || batchBusy ? null : () => _replayOne(run),
            ),
          if (run.replayCount > 0)
            AnChip(context.t.run.replayTimes(n: '${run.replayCount}'),
                look: AnChipLook.outlined),
        ],
        sub: failed ? _errorFirstLine(run.error) : null,
        subTone: AnTone.danger,
        measure: elapsed,
        onTap: () => _onRowTap(run),
      ),
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


// ─────────────────────────────────── 矩阵区 + 行内速览卡 ───────────────────────────────────

/// Build the picker's string bundle from slang — the primitive is copy-free by design.
/// 从 slang 拼选择器字符串包——原语按设计零文案。
AnTimeRangePickerStrings _rangeStrings(BuildContext context) {
  final t = context.t.scheduler.range;
  return AnTimeRangePickerStrings(
    presetLabels: {
      AnTimePreset.today: t.today,
      AnTimePreset.h24: t.h24,
      AnTimePreset.d7: t.d7,
      AnTimePreset.d30: t.d30,
      AnTimePreset.all: t.all,
    },
    customTitle: t.customTitle,
    fromLabel: t.from,
    toLabel: t.to,
    applyLabel: t.apply,
    endBeforeStartError: t.endBeforeStart,
    weekdayLabels: t.weekdays.split(' '),
    monthTitle: (m) => t.monthTitle(y: '${m.year}', m: m.month.toString().padLeft(2, '0')),
    prevMonthLabel: t.prevMonth,
    nextMonthLabel: t.nextMonth,
    capsuleA11y: t.capsuleA11y,
    gridSemanticLabel: t.gridA11y,
  );
}

/// The top-of-page matrix zone (0717 拍板): the page-level time-range capsule + the chronological
/// node×run grid anchored at the newest end. A COLUMN head click navigates to that run's flagship;
/// a CELL click lands there with `?node=` preselected (the flagship's own selection grammar) —
/// nothing selects downward anymore, the grid is a LAUNCHER. Row heads are inert names. Sliding
/// toward the oldest edge pulls older pages ([SchedulerMatrixWindowController.loadOlder]); the
/// `?run=` expanded row's column is highlighted (one selection, two projections).
/// 页顶矩阵区:页级时间范围胶囊 + 时序格阵锚最新端。点列头→直进该 run 旗舰;点格→旗舰 + ?node= 预选
/// (旗舰自己的选区文法)——不再向下选中,格阵是**发射台**。行头惰性只作名。滑近最旧缘拉旧页;?run= 展开
/// 行的列被点亮(一个选区、两处投影)。
class _MatrixZone extends ConsumerWidget {
  const _MatrixZone({required this.workflowId, required this.linkedRunId});

  final String workflowId;
  final String? linkedRunId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.scheduler.home;
    final c = context.colors;
    final async = ref.watch(schedulerMatrixWindowProvider(workflowId));
    final s = async.value;

    Widget body;
    if (s == null) {
      body = async.hasError
          ? Row(children: [
              Expanded(child: Text(t.paneError, style: AnText.body.copyWith(color: c.inkMuted))),
              AnButton(
                  label: context.t.scheduler.retry,
                  size: AnButtonSize.sm,
                  onPressed: () => ref.invalidate(schedulerMatrixWindowProvider(workflowId))),
            ])
          : const AnDeferredLoading(child: AnSkeleton.lines(3));
    } else if (s.matrix.cols.isEmpty) {
      // An empty window is an ANSWER («no runs in this range»), never a bare frame that reads as
      // broken. 空窗是答案(这段时间没有运行),绝不渲一个读作坏掉的空框。
      body = Text(t.matrixEmpty, style: AnText.body.copyWith(color: c.inkFaint));
    } else {
      body = _grid(context, ref, s);
    }

    // The «Matrix View» section title (WRK-070 B3 方案 A 用户拍板) — a titleless grid read as「给标题
    // 留位」的空档; naming it makes the page speak the entities section rhythm (title → 12 → content).
    // The capsule still lives in the page head meta row (需求②). 段题=矩阵视图;胶囊仍在页头 meta 行。
    return AnSection(label: t.matrixView, variant: AnSectionVariant.plain, children: [body]);
  }

  Widget _grid(BuildContext context, WidgetRef ref, MatrixWindowState s) {
    final t = context.t.scheduler.home;
    final m = s.matrix;
    // The sparse cell list → an O(1) lookup. NEVER assume cells == rows×cols (稀疏是契约).
    // 稀疏格列表 → O(1) 查询;绝不假设 cells == rows×cols(稀疏是契约)。
    final byKey = {for (final cell in m.cells) '${cell.flowrunId}/${cell.nodeId}': cell};
    // Humane column words (需求⑤): tooltip/a11y speak the run's SOURCE PHRASE + start time, never a
    // bare id (the id rides the tooltip's last line for support/copy).
    // 人话列词:tooltip/读屏说来源短语+时刻,绝不裸 id(id 收 tooltip 末行留支持/复制)。
    final triggersById = {
      for (final tr in ref.watch(schedulerRailProvider).value?.triggers ?? const <TriggerEntity>[])
        tr.id: tr,
    };
    final now = DateTime.now();
    String srcOf(String frId) {
      final run = s.runsById[frId];
      if (run == null) return truncate(frId, AnTrunc.id);
      return runPhrase(context, run, triggersById, now);
    }
    // Wire order is canonical newest→oldest; the timeline renders OLDEST LEFT and anchors at the
    // newest end — a pure display reversal of the same truth. 线缆正典新→旧;时间轴旧在左、锚最新端
    // ——同一真相的纯呈现反转。
    final cols = m.cols.reversed.toList();
    String flagship(String frId) => '/scheduler/w/$workflowId/runs/$frId';
    return AnRunMatrix(
      // Keyed on the RANGE: a lens change REPLACES the dataset, and the grid must remount — fresh
      // newest-end anchor + re-armed edge hysteresis. Updating in place would keep a stale offset
      // (clamping to the oldest edge and firing a spurious loadOlder, 复审 [2]); an older-page
      // prepend keeps the same range → same key → in-place zero-shift as designed.
      // 按**范围**取键:换镜头=换数据集,格阵必须重挂——新锚+重上膛。原地更新会留旧 offset(钳到最旧缘
      // 还误发一次 loadOlder);前插旧页同范围同键=原地零位移,如设计。
      key: ValueKey(ref.read(schedulerTimeRangeProvider)),
      rows: [for (final r in m.rows) MatrixRowHead(nodeId: r.nodeId, kind: r.kind)],
      cols: [
        for (final col in cols)
          RunColumn(
            id: col.flowrunId,
            status: col.status,
            elapsedMs: col.elapsedMs,
            label: '${t.matrixColA11y(
              src: srcOf(col.flowrunId),
              status: flowrunStatusWord(context.t, col.status),
              // A run still going has no elapsed — say «running», never a fabricated duration.
              // 在跑的 run 无耗时——说「在跑」,绝不编一个时长。
              d: col.elapsedMs == null
                  ? t.matrixRunning
                  : fmtDuration(Duration(milliseconds: col.elapsedMs!)),
            )}\n${col.flowrunId}',
          ),
      ],
      cellStatus: (frId, nodeId) {
        final cell = byKey['$frId/$nodeId'];
        if (cell == null) return null; // 未及 — sparse, and that IS the answer 稀疏即答案
        return MatrixCellState(
          status: cell.status,
          iterations: cell.iterations,
          label: t.matrixCellA11y(
              node: nodeId, status: flowrunStatusWord(context.t, cell.status), n: '${cell.iterations}'),
        );
      },
      // The `?run=` expanded row's column — one selection projected in both zones. ?run= 列点亮。
      selection: MatrixSelection(flowrunId: linkedRunId),
      // The grid is a LAUNCHER (0717 拍板): a column head opens the run's flagship, a cell lands
      // there with the node preselected. 格阵是发射台:列头进旗舰,格带节点预选。
      onCol: (frId) => context.go(flagship(frId)),
      onCell: (frId, nodeId) => context
          .go(Uri(path: flagship(frId), queryParameters: {'node': nodeId}).toString()),
      onNearOldestEdge: s.hasMore
          ? () => ref.read(schedulerMatrixWindowProvider(workflowId).notifier).loadOlder()
          : null,
      loadingOlder: s.loadingOlder,
      notReachedLabel: t.matrixNotReached,
      runningLabel: t.matrixRunning,
      cellSemanticLabel: (col, row, cell) => t.matrixCellA11y(
          node: row.nodeId,
          status: cell == null
              ? t.matrixNotReached
              : flowrunStatusWord(context.t, cell.status),
          n: '${cell?.iterations ?? 0}'),
      colSemanticLabel: (col) => t.matrixColA11y(
          src: srcOf(col.id),
          status: flowrunStatusWord(context.t, col.status),
          d: col.elapsedMs == null
              ? t.matrixRunning
              : fmtDuration(Duration(milliseconds: col.elapsedMs!))),
      rowSemanticLabel: (row) => t.matrixRowA11y(node: row.nodeId),
      rowSummaryLabel: (sum) {
        final reached = sum.cells.whereType<MatrixCellState>().toList();
        final bad = reached.where((cl) => cl.status == 'failed').length;
        return t.matrixRowSummaryA11y(
            node: sum.row.nodeId,
            r: '${sum.index + 1}',
            total: '${sum.total}',
            n: '${reached.length}',
            failed: '$bad');
      },
      coordinateLabel: (r, rc, c2, cc) =>
          t.matrixCoordA11y(r: '${r + 1}', rows: '$rc', c: '${c2 + 1}', cols: '$cc'),
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
    // The «Editing belongs to Entities ↗» hint is GONE (WRK-070 B3 用户裁「没用+占位怪异」) and the
    // cards flow as a responsive TWO-column grid (B9). 编辑归属提示删;卡片双列网格。
    return AnSection(
      label: t.triggersHead,
      variant: AnSectionVariant.plain,
      children: [
        if (triggers.isEmpty)
          Text(t.triggersEmpty, style: AnText.body.copyWith(color: c.inkFaint))
        else
          AnAutoGrid(children: [
            for (final trigger in triggers) _TriggerCard(trigger: trigger, now: now),
          ]),
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
