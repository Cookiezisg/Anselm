import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/shell/oceans.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/scheduler_overview_provider.dart';
import 'overview_zones.dart';

/// The Scheduler Overview board (WRK-069 §3, S2a+S2b) — `/scheduler` with nothing selected. Zones
/// top-down by how much they need a human: KPI strip → «等你处理» (inbox rows + in-place ApprovalGate
/// + batch approve/reject, [SchedulerWaitingZone]) → running now (hover ⏹ cancel + batch cancel,
/// [SchedulerRunningZone]) → next-24h schedule → 7d failure aggregation; zero workflows collapses the
/// whole page into one first-use education card. 活性军规: the half-minute [AnTimePulse] refreshes
/// TIME TEXT only (running elapsed / waited-for / next-fire relatives); rows appear/disappear only on
/// user action or durable refetch. Saturated colour goes to red/amber only — success stays background
/// hum. Scheduler 总览看板:KPI 牌 → 等你处理(就地审批+批量)→ 正在跑(hover 取消+批量)→ 未来 24h →
/// 失败聚合;零数据整页一张教育卡。脉搏只刷时间字,行增删只随用户动作/durable refetch;饱和色只给红/琥珀。
class SchedulerOverviewView extends ConsumerStatefulWidget {
  const SchedulerOverviewView({super.key});

  @override
  ConsumerState<SchedulerOverviewView> createState() => _SchedulerOverviewViewState();
}

/// One zone's anchor + wash trigger — the board's drill-down mechanism, ONE engine for every KPI tile
/// that has somewhere true to go. [seq] only ever changes on a USER TAP, so a wash cannot fire on a
/// refetch — 活性军规 (geometry and attention move on user action or durable landing, never on their own).
/// 一个区的锚 + 洗亮触发器——看板的钻取机制,凡「有真去处」的 KPI 牌共用**这一个**引擎。seq **只在用户点击时**变,
/// 故洗亮不可能因重取而发生(活性军规:几何与注意力只随用户动作或 durable 落账而动)。
class _ZoneAnchor {
  _ZoneAnchor(this.name);

  /// Stable across the wash wrap/unwrap — the zones are stateful (batch selection), and a GlobalKey is
  /// what carries their element through the re-parent. 洗亮包裹/解包时保持:区是有状态的(批量选区),
  /// GlobalKey 正是带着它们的 element 穿过换父的那个东西。
  final GlobalKey key = GlobalKey();
  final String name;
  int seq = 0;
}

class _SchedulerOverviewViewState extends ConsumerState<SchedulerOverviewView> {
  /// The zones a KPI tile can open. Each tile reveals the zone that holds ITS OWN evidence:
  /// 「在跑 N」 → the rows it counts; 「等你 N」 → the rows it counts; 「24h 失败 N」 → the per-run failed
  /// list it counts (工单⑮); 「错过 N」 and 「下次调度」 → the track, whose past ✕ and future rings are
  /// respectively what those two numbers are ABOUT.
  /// 各 KPI 牌可打开的区。每张牌揭示**自己那份证据**所在的区:「在跑 N」「等你 N」→ 它数的那些行;
  /// 「24h 失败 N」→ 它数的那份按 run 的失败列表(工单⑮);「错过 N」与「下次调度」→ 轨道,其过去的 ✕ 与未来
  /// 的空心环分别正是这两个数**所谈论的东西**。
  final _ZoneAnchor _waiting = _ZoneAnchor('waiting');
  final _ZoneAnchor _running = _ZoneAnchor('running');
  final _ZoneAnchor _failed = _ZoneAnchor('failed');
  final _ZoneAnchor _schedule = _ZoneAnchor('schedule');

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    AnTimePulse.instance.addListener(_onPulse);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    AnTimePulse.instance.removeListener(_onPulse);
    _scroll.dispose();
    super.dispose();
  }

  // The floating-head crumb (WRK-070 B11, 与运营主页同款文法): scrolled past the big title →
  // «Scheduler / Overview» appears top-left; back at top it yields. 下滑出浮层头面包屑,回顶让位。
  void _onScroll() {
    final collapsed = _scroll.hasClients && _scroll.offset > AnSpace.s64;
    ref.read(shellHeadProvider.notifier).setCollapsed(collapsed);
  }

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
  }

  void _onPulse() {
    if (mounted) setState(() {});
  }

  void _reveal(_ZoneAnchor anchor) {
    final ctx = anchor.key.currentContext;
    if (ctx == null) return;
    setState(() => anchor.seq++);
    Scrollable.ensureVisible(ctx,
        duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.slow,
        curve: AnMotion.easeOut,
        alignment: 0.1);
  }

  /// The zone, washed if it has ever been revealed. Wrapping only after the first tap keeps the
  /// untouched board free of the extra layer. 揭示过才裹洗亮层:没碰过的盘面不多一层。
  Widget _washable(_ZoneAnchor anchor, Widget zone) => anchor.seq == 0
      ? zone
      : AnWashHighlight(key: ValueKey('${anchor.name}-wash-${anchor.seq}'), child: zone);

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler;
    final data = ref.watch(schedulerOverviewProvider);

    // Keep the last good board on refetch (no flash); loading/error only rule the FIRST load.
    // 重取期间保留旧盘面;骨架/错误只管首载。
    if (data.hasValue) return _board(context, data.value!);
    if (data.hasError) {
      return Center(
        child: AnState(
          kind: AnStateKind.error,
          title: t.overview.errorTitle,
          hint: t.overview.errorHint,
          action: AnButton(
            label: t.retry,
            onPressed: () => ref.read(schedulerOverviewProvider.notifier).retry(),
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

  Widget _board(BuildContext context, SchedulerOverviewData d) {
    final t = context.t.scheduler;
    if (d.firstUse) return _firstUse(context);

    final now = DateTime.now();
    // Bind the floating head post-frame (entities 先例:每次重建重绑,onTap 恒新鲜). 后帧绑浮层头。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(shellHeadProvider.notifier)
            .bind(t.home.crumb(name: t.overviewTitle), _scrollToTop);
      }
    });
    return AnPage(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The documentary page head (WRK-070 B11): grey crumb over the big title — the standard
          // grammar every ocean page speaks. 文档化页头:灰 crumb + 大标题,全海洋标准文法。
          AnOceanHeader(crumbs: [t.home.crumbRoot], title: t.overviewTitle),
          Padding(
            padding: const EdgeInsets.only(bottom: AnGap.section),
            child: _KpiStrip(
              kpi: d.kpi,
              now: now,
              // A tile is clickable exactly when the list it counts EXISTS. Zero rows = no list to
              // open, so the tile stays inert rather than scroll to an empty zone — the same rule the
              // failure zone's [最新 run] through-train already obeys (a dead affordance is a lie).
              // 一张牌可点,恰当它数的那份列表**在场**。零行=没有列表可开,故牌保持惰性、不去滚一个空区
              // ——与失败区[最新 run]直通车同一条规矩(没有目标就不做成可点)。
              onRunning: d.runningRuns.isEmpty ? null : () => _reveal(_running),
              onWaiting: d.waiting.isEmpty ? null : () => _reveal(_waiting),
              // The 24h-failed tile opens the per-run failed zone (工单⑮), present exactly when there
              // are failures — inert at zero, same rule as running/waiting. 24h 失败牌开按 run 失败区,
              // 恰在有失败时在场;零时惰性,同 running/waiting。
              onFailed24h: d.failedRuns.isEmpty ? null : () => _reveal(_failed),
              // Only when the tick it names is really on the axis (see nextFireOnTrack). 所念刻度真在轴上才可点。
              onNextFire: nextFireOnTrack(d.track, d.kpi.nextFire) ? () => _reveal(_schedule) : null,
              onMissed: () => _reveal(_schedule),
            ),
          ),
          // «等你处理» — the costliest land (S2b): inbox rows + in-place ApprovalGate + AnBatchBar
          // batch approve/reject; then «正在跑» with hover ⏹ + batch cancel. 等你处理(就地审批+批量)
          // 与 正在跑(hover 取消+批量取消)两操作区。
          _washable(_waiting, SchedulerWaitingZone(key: _waiting.key, rows: d.waiting, now: now)),
          _washable(
              _running,
              SchedulerRunningZone(
                  key: _running.key,
                  rows: d.runningRuns,
                  triggersById: d.triggersById,
                  now: now)),
          _washable(
              _schedule,
              SchedulerScheduleZone(
                  key: _schedule.key,
                  track: d.track,
                  triggersById: d.triggersById,
                  now: now)),
          // «24h 失败» — the per-run list the KPI tile opens (工单⑮), present only when non-empty (the
          // tile is inert at zero, so the board never scrolls to an absent zone; 成功是背景音). Placed
          // just above the 7d «失败聚合» so the two failure views (24h runs, then 7d workflow streaks)
          // read together without being confused for one another.
          // 24h 失败:牌点开的按 run 列表(工单⑮),仅非空时在场(零时牌惰性、看板不滚向不在的区;成功是背景音);
          // 紧挨 7d 失败聚合之上,使两种失败视图(24h run、7d workflow 连败)相邻同读而不相混。
          if (d.failedRuns.isNotEmpty)
            _washable(
                _failed,
                SchedulerFailedZone(
                    key: _failed.key,
                    rows: d.failedRuns,
                    triggersById: d.triggersById,
                    now: now)),
          AnSection(
            label: t.overview.failuresHead,
            children: d.failures.isEmpty
                ? [_emptyLine(context, t.overview.failuresEmpty)]
                : [for (final f in d.failures) _failureRow(context, f)],
          ),
        ],
      ),
    );
  }

  /// An honest quiet empty sentence under a zone head (no ghost frames). 区头下的诚实灰句。
  Widget _emptyLine(BuildContext context, String text) =>
      Text(text, style: AnText.body.copyWith(color: context.colors.inkFaint));

  /// «Failures · 7d» row: red dot · workflow name · ×N streak chip · error first line · the
  /// latest-run through-train. Replay waits for the run composite (S4). 失败聚合一行;replay 随 S4。
  Widget _failureRow(BuildContext context, FailingWorkflowRow f) {
    final t = context.t.scheduler.overview;
    void openLatest() {
      final id = f.latestRunId;
      if (id != null) context.go('/scheduler/w/${f.workflowId}/runs/$id');
    }

    return AnLedgerRow(
      lead: const AnStatusDot(AnStatus.err),
      primary: f.workflowName,
      mono: false,
      chips: [
        AnChip(t.streak(n: '${f.streak}'), tone: AnTone.danger),
        // The through-train renders only when the probe found a run — a dead affordance is a lie.
        // 直通车只在探到 run 时渲——没有目标就不做成可点。
        if (f.latestRunId != null)
          AnChip(t.latestRun, look: AnChipLook.outlined, onTap: openLatest),
      ],
      sub: f.error,
      subTone: AnTone.danger,
      onTap: f.latestRunId != null ? openLatest : null,
    );
  }

  /// The zero-data first-use card — the whole page collapses into one education card with the two
  /// deep links (Entities to build; chat to just say it). Ocean switching is provider-driven (not
  /// routed yet), same as the left-island switcher. 零数据教育卡:双深链走海洋 provider(未路由化)。
  Widget _firstUse(BuildContext context) {
    final t = context.t.scheduler.overview;
    return Center(
      child: AnState(
        kind: AnStateKind.empty,
        icon: AnIcons.scheduler,
        title: t.firstUseTitle,
        hint: t.firstUseBody,
        // Wrap, not Row: two buttons in AnState's 360 column overflow in en — they stack honestly.
        // Wrap 非 Row:360 列装不下两钮时诚实换行。
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: AnGap.inlineLoose,
          runSpacing: AnGap.stackTight,
          children: [
            AnButton(
              label: t.firstUseEntities,
              variant: AnButtonVariant.primary,
              onPressed: () =>
                  ref.read(selectedOceanProvider.notifier).select(OceanKind.entities),
            ),
            AnButton(
              label: t.firstUseChat,
              onPressed: () => ref.read(selectedOceanProvider.notifier).select(OceanKind.chat),
            ),
          ],
        ),
      ),
    );
  }
}

/// The KPI strip — equal [AnCard] tiles (running / waiting-on-you / failed-24h with its delta arrow /
/// next fire), plus a FIFTH「错过 N」tile that appears only when there is something to say (判决⑥).
///
/// **Why 「错过 0」 is not a tile.** 禁虚荣数字 军规: every KPI must pass the decision test — would this
/// number change what I do? A machine that was awake misses nothing, so 「错过 0」 is the normal state,
/// and a tile reading 0 every day for months is decoration that costs the other four a fifth of their
/// width. 「成功是背景音」: the absence of the tile IS the good news. It appears and disappears only on a
/// durable refetch, never on a tick — 活性军规 permits exactly that.
///
/// **Every tile opens the evidence it is about.** Each click reveals the zone that holds THIS tile's
/// own facts — running/waiting/failed reveal the rows they are the length of, missed and next-fire
/// reveal the track whose ✕ and rings they name. The 「24h 失败」 tile was the last inert one; 工单⑮
/// gave `GET /flowruns` a `completedAfter` window, so it now opens the per-run failed list on the
/// byte-identical predicate `failedSince` counts with — 宪法 says a KPI must open the list it counts,
/// and now it can. (It is inert only at zero, like running/waiting: no rows, no zone to reveal.)
///
/// KPI 牌:四张等宽 + 第五张「错过 N」**有话说时才出现**(判决⑥)。**为何「错过 0」不成牌**:禁虚荣数字 军规——
/// 每个 KPI 须过决策测试(这个数会改变我做什么吗?);醒着的机器什么都不会错过,故「错过 0」是常态,一张天天读 0
/// 的牌是装饰,还要占掉另外四张五分之一的宽。成功是背景音:**牌不在,本身就是好消息**。它只随 durable 重取增删、
/// 绝不随 tick——活性军规恰好允许这一条。**每张牌都打开自己所谈论的那份证据**:在跑/等你/失败揭示它们所是其长度的
/// 那些行,错过与下次调度揭示它们所念的 ✕ 与空心环。「24h 失败」曾是最后一张惰性牌;工单⑮ 给 `GET /flowruns`
/// 加了 `completedAfter` 窗,故它现在点开走 failedSince **逐字节相同**谓词的按 run 失败列表——宪法说 KPI 必须
/// 点开它数的那个列表,现在它做得到。(仅零时惰性,同 running/waiting:无行则无区可揭。)
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.kpi,
    required this.now,
    required this.onRunning,
    required this.onWaiting,
    required this.onFailed24h,
    required this.onNextFire,
    required this.onMissed,
  });

  final SchedulerKpi kpi;
  final DateTime now;

  /// Reveal the rows each tile is the LENGTH of — null when there are none, so a tile never opens an
  /// empty zone. 揭示每张牌所是其**长度**的那些行;无行时为 null,故牌绝不打开一个空区。
  final VoidCallback? onRunning;
  final VoidCallback? onWaiting;

  /// Reveal the per-run failed list the 「24h 失败」 tile counts (工单⑮) — null at zero. 揭示失败牌数的按 run 列表。
  final VoidCallback? onFailed24h;

  /// Reveal the track — null unless the named tick is really drawn on it ([nextFireOnTrack]).
  /// 揭示轨道;除非所念刻度真画在其上,否则 null。
  final VoidCallback? onNextFire;

  /// Reveal the ticks this strip's 「错过 N」 counted. 显出「错过 N」数的那些刻度。
  final VoidCallback onMissed;

  /// Clamp to zero — an on-track fire that just slipped past now must not fmtWaited a negative
  /// duration. 对刚滑过此刻的在轴下次钳零,避免负时长。
  static Duration _nonNeg(Duration d) => d.isNegative ? Duration.zero : d;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.overview;
    final c = context.colors;
    final nextFire = kpi.nextFire;
    final tiles = <Widget>[
      _tile(
        context,
        label: t.kpiRunning,
        value: AnCountUp(kpi.running, style: _valueStyle(c)),
        onTap: onRunning,
        a11y: t.kpiRunningA11y(n: '${kpi.running}'),
      ),
      _tile(
        context,
        label: t.kpiWaiting,
        value: AnCountUp(kpi.waiting, style: _valueStyle(c)),
        onTap: onWaiting,
        a11y: t.kpiWaitingA11y(n: '${kpi.waiting}'),
      ),
      // 24h 失败 — the per-run failed list it opens exists as of 工单⑮ (see the class doc + the
      // SchedulerKpi.failed24h field for why `completedAfter` is the predicate that makes the tile and
      // its list one fact). Clickable exactly when there are rows (onFailed24h null at zero).
      //
      // The a11y must carry the delta itself when clickable: `_tile` wraps a tappable body in
      // ExcludeSemantics (so `button`+`enabled` own the one node), which would swallow the delta's own
      // Semantics below — and the delta can be non-zero at count 0 (0 today, 3 yesterday → ▼3
      // improving, an inert tile that still has something to announce). So the sentence appends the
      // delta phrase; when inert the nested Semantics below carries it instead.
      // 24h 失败——它点开的按 run 失败列表自工单⑮ 起存在(为何 completedAfter 让牌与列表成一个事实,见类注释与
      // SchedulerKpi.failed24h 字段)。恰在有行时可点(零时 onFailed24h 为 null)。可点时 a11y 须自带 delta:
      // _tile 把可点 body 裹进 ExcludeSemantics(使 button+enabled 独占一个节点),会吞掉下面 delta 自己的
      // Semantics——而 delta 在计数为 0 时仍可非零(今天 0、昨天 3 → ▼3 改善,惰性牌仍有话说)。故句子附上 delta 短语;
      // 惰性时改由下面那个嵌套 Semantics 承载。
      _tile(
        context,
        label: t.kpiFailed24h,
        onTap: onFailed24h,
        a11y: onFailed24h == null
            ? null
            : [
                t.kpiFailed24hA11y(n: '${kpi.failed24h}'),
                if (kpi.failedDelta > 0) t.deltaUpA11y(n: '${kpi.failedDelta}'),
                if (kpi.failedDelta < 0) t.deltaDownA11y(n: '${-kpi.failedDelta}'),
              ].join(' '),
        value: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnCountUp(kpi.failed24h, style: _valueStyle(c)),
            if (kpi.failedDelta != 0) ...[
              const SizedBox(width: AnGap.inline),
              Padding(
                padding: const EdgeInsets.only(bottom: AnSpace.s4),
                child: Semantics(
                  label: kpi.failedDelta > 0
                      ? t.deltaUpA11y(n: '${kpi.failedDelta}')
                      : t.deltaDownA11y(n: '${-kpi.failedDelta}'),
                  child: ExcludeSemantics(
                    child: Text(
                      kpi.failedDelta > 0
                          ? t.deltaUp(n: '${kpi.failedDelta}')
                          : t.deltaDown(n: '${-kpi.failedDelta}'),
                      style: AnText.metaTabular().copyWith(
                          color: kpi.failedDelta > 0 ? c.danger : c.ok),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      // VALUE = honest news: show the next fire whenever it is in the future, EVEN off the drawn
      // track (a weekly cron says «1d» though the 24h axis can't draw it). But a TAPPABLE tile must
      // ALWAYS carry an a11y label — keying a11y on the value's `isAfter(now)` alone left a tappable
      // (on-track) tile UNLABELLED when the on-track fire just slipped past wall-clock now (复审 [4]).
      // So a11y is present when the tile is tappable OR shows a future fire; its word is clamped
      // non-negative for the slipped-past edge. 值=诚实消息(未来即显,含轴外);但可点牌必带读屏标签——
      // a11y 在「可点 或 显未来」时都在场,相对词对滑过此刻的边界钳非负。
      _tile(
        context,
        label: t.kpiNextFire,
        value: Text(
          nextFire != null && nextFire.isAfter(now)
              ? t.fireIn(d: fmtWaited(nextFire.difference(now)))
              : t.kpiNone,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _valueStyle(c),
        ),
        onTap: onNextFire,
        a11y: (onNextFire != null || (nextFire != null && nextFire.isAfter(now)))
            ? t.kpiNextFireA11y(
                d: fmtWaited(_nonNeg(nextFire?.difference(now) ?? Duration.zero)))
            : null,
      ),
      // The fifth tile — present only when it has news. 第五张牌:有话说才在场。
      if (kpi.missed > 0)
        _tile(
          context,
          label: t.kpiMissed,
          value: AnCountUp(kpi.missed, style: _valueStyle(c)),
          onTap: onMissed,
          a11y: t.kpiMissedA11y(n: '${kpi.missed}'),
        ),
    ];
    // IntrinsicHeight equalizes the four tiles (the host Column hands the Row unbounded height, so
    // cross-axis stretch alone would blow up); four one-line tiles keep the pass cheap.
    // IntrinsicHeight 等高四牌(宿主 Column 给无界高,裸 stretch 会炸);单行牌代价可忽略。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AnGap.block),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }

  TextStyle _valueStyle(AnColors c) => AnText.h2.copyWith(color: c.ink);

  /// One tile. [onTap] non-null makes it a CONTROL, and then [a11y] is required — a tile that became a
  /// button must announce as one, with the sentence saying what the click does (a bare 「Running / 3」
  /// read by a screen reader is a fact, not an affordance).
  ///
  /// **The label is annotated INSIDE the card, and only the label** — [AnCard]'s own [AnInteractive]
  /// keeps ownership of `button`/`enabled`, so the two configurations share no flag, stay compatible,
  /// and merge into ONE node (design-system §2: two [Semantics] setting the same flag is an
  /// incompatible configuration that splits into parent + child and strands the label on the child).
  /// [ExcludeSemantics] then covers only the raw 「label / value」 text, whose two bare nodes are facts,
  /// not the affordance.
  ///
  /// DUMP-verified, not reasoned (§2: a11y claims must be read off the real tree):
  /// `actions: focus, tap` + `flags: isButton, hasEnabledState, isEnabled, isFocusable` + the sentence
  /// — i.e. exactly what a stock button emits. Annotating from OUTSIDE an excluded card instead (the
  /// shape the fifth tile first shipped with) measurably loses `isFocusable`/`hasEnabledState` and, more
  /// seriously, the tap ACTION — one of the few things that actually reach a desktop screen reader — so
  /// it announced a button that could not be pressed.
  ///
  /// 一张牌。onTap 非空即**控件**,那时 a11y 必填——变成按钮的牌必须念成按钮,且句子要说清这一点会做什么(读屏念出
  /// 光秃秃的「Running / 3」是一个**事实**、不是一个**可供性**)。**label 标在卡的内部,且只标 label**:`button`/`enabled`
  /// 的所有权留给 AnCard 自己的 AnInteractive,于是两份配置**不共享任何旗标**、彼此兼容、**合并成一个节点**
  /// (design-system §2:两个 Semantics 设同一旗标是不兼容配置,会裂成父+子并把 label 搁浅在孩子身上);
  /// ExcludeSemantics 于是只盖住「标签/数值」那两个裸文本节点——它们是事实,不是可供性。**以 dump 验证、不靠推理**
  /// (§2:a11y 主张必须从真实的树上读):`actions: focus, tap` + `flags: isButton, hasEnabledState, isEnabled,
  /// isFocusable` + 句子——正是原装按钮所发的那一套。改从**外面**包一张被 exclude 的卡(第五张牌最初落地时的形状),
  /// 实测会丢掉 isFocusable/hasEnabledState,更要命的是丢掉 **tap 动作**——而动作正是少数真到得了桌面读屏的东西之一
  /// ——于是它念出一个**按不动**的按钮。
  Widget _tile(BuildContext context,
      {required String label, required Widget value, VoidCallback? onTap, String? a11y}) {
    assert(onTap == null || a11y != null, 'a tappable KPI tile must carry its a11y sentence');
    final c = context.colors;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnGap.stackTight),
        value,
      ],
    );
    if (onTap == null) return AnCard(child: body);
    // `selectable` is AnCard's «the whole card is one button» mode — the hover border IS the
    // affordance. It is not a selection: AnCard hands its `false` to AnInteractive, which routes it
    // through AnA11y.selected and therefore emits NOTHING (never `selected: false` — the pinned
    // engine reads an explicit false as «selected»).
    // selectable=AnCard 的「整卡即一个按钮」模式,hover 边即可供性。它**不是**选中:AnCard 把 false 交给
    // AnInteractive,后者经 AnA11y.selected 过滤 → **什么都不发**(绝不发 selected:false——钉住的引擎会把
    // 显式 false 念成「已选中」)。
    return AnCard(
      selectable: true,
      onSelect: onTap,
      child: Semantics(label: a11y, child: ExcludeSemantics(child: body)),
    );
  }
}
