import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/time_format.dart';
import '../../../core/shell/oceans.dart';
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
  /// The three zones a KPI tile can open. Each tile reveals the zone that holds ITS OWN evidence:
  /// 「在跑 N」 → the rows it counts; 「等你 N」 → the rows it counts; 「错过 N」 and 「下次调度」 → the track,
  /// whose past ✕ and future rings are respectively what those two numbers are ABOUT.
  /// 三个 KPI 牌可打开的区。每张牌揭示**自己那份证据**所在的区:「在跑 N」「等你 N」→ 它数的那些行;
  /// 「错过 N」与「下次调度」→ 轨道,其过去的 ✕ 与未来的空心环分别正是这两个数**所谈论的东西**。
  final _ZoneAnchor _waiting = _ZoneAnchor('waiting');
  final _ZoneAnchor _running = _ZoneAnchor('running');
  final _ZoneAnchor _schedule = _ZoneAnchor('schedule');

  @override
  void initState() {
    super.initState();
    AnTimePulse.instance.addListener(_onPulse);
  }

  @override
  void dispose() {
    AnTimePulse.instance.removeListener(_onPulse);
    super.dispose();
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
    final c = context.colors;
    if (d.firstUse) return _firstUse(context);

    final now = DateTime.now();
    return AnPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AnGap.section),
            child: Text(t.overviewTitle, style: AnText.h2.copyWith(color: c.ink)),
          ),
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
              _running, SchedulerRunningZone(key: _running.key, rows: d.runningRuns, now: now)),
          _washable(_schedule, SchedulerScheduleZone(key: _schedule.key, track: d.track, now: now)),
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
/// **Four of the five open the evidence they are about; 「24h 失败」 is inert, and that is a finding, not
/// an omission.** Each click reveals the zone that holds THIS tile's own facts — running/waiting reveal
/// the rows they are the length of, missed and next-fire reveal the track whose ✕ and rings they name.
/// The failed tile has no such zone and provably cannot be given one from this ocean's endpoints; the
/// reason is on the tile itself below. 宪法 says a KPI must open the list it counts, and a link to a
/// nearby-but-different list is worse than none — so it keeps none.
///
/// KPI 牌:四张等宽 + 第五张「错过 N」**有话说时才出现**(判决⑥)。**为何「错过 0」不成牌**:禁虚荣数字 军规——
/// 每个 KPI 须过决策测试(这个数会改变我做什么吗?);醒着的机器什么都不会错过,故「错过 0」是常态,一张天天读 0
/// 的牌是装饰,还要占掉另外四张五分之一的宽。成功是背景音:**牌不在,本身就是好消息**。它只随 durable 重取增删、
/// 绝不随 tick——活性军规恰好允许这一条。**五张里四张打开自己所谈论的那份证据;「24h 失败」惰性,而那是一个结论、
/// 不是一处遗漏**:每次点击揭示的都是**这张牌自己**的事实所在的区——在跑/等你揭示它们所是其长度的那些行,错过与
/// 下次调度揭示它们所念的 ✕ 与空心环。失败牌没有这样一个区,且**可证**地无法用本海洋的端点造出一个来——理由就写在
/// 下面那张牌上。宪法说 KPI 必须点开它数的那个列表,而链到一个相近但不同的列表比没有链更糟,故它一个也不要。
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.kpi,
    required this.now,
    required this.onRunning,
    required this.onWaiting,
    required this.onNextFire,
    required this.onMissed,
  });

  final SchedulerKpi kpi;
  final DateTime now;

  /// Reveal the rows each tile is the LENGTH of — null when there are none, so a tile never opens an
  /// empty zone. 揭示每张牌所是其**长度**的那些行;无行时为 null,故牌绝不打开一个空区。
  final VoidCallback? onRunning;
  final VoidCallback? onWaiting;

  /// Reveal the track — null unless the named tick is really drawn on it ([nextFireOnTrack]).
  /// 揭示轨道;除非所念刻度真画在其上,否则 null。
  final VoidCallback? onNextFire;

  /// Reveal the ticks this strip's 「错过 N」 counted. 显出「错过 N」数的那些刻度。
  final VoidCallback onMissed;

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
      // **The one tile with no click, and it is not waiting on a surface to be built — no surface can
      // express its predicate.** It counts runs that REACHED failed inside the window: the backend
      // windows `failedSince` on `completed_at`. Every run list this ocean can ask for windows on
      // `started_at` (`GET /flowruns?startedAfter=`, api.md 工单⑥ — there is no `completedAfter`), so a
      // list built from them would drop the 30h-old run that failed an hour ago and include the run that
      // started inside the window and is still going. Not «close enough»: those are exactly the runs a
      // 24h failure tile exists to surface.
      //
      // «Failures · 7d» below is the nearby-but-different list the 宪法 names: it aggregates WORKFLOWS by
      // consecutive-failure streak, not runs by window — a workflow that failed 4× overnight and then
      // succeeded contributes 4 here and is absent there (self-healed, streak 0). Two units, two windows,
      // two questions. Wiring them together would make the tile say 4 and open an empty zone.
      //
      // **唯一没有点击的那张,且它不是在等一个面被建出来——没有任何面表达得了它的谓词**:它数的是窗口内**落定**
      // 为 failed 的 run(后端 failedSince 按 `completed_at` 开窗),而本海洋问得到的每一份 run 列表都按
      // `started_at` 开窗(`GET /flowruns?startedAfter=`,api.md 工单⑥——根本没有 completedAfter);故照它们建出的
      // 列表会**漏掉**30 小时前起跑、一小时前失败的那个,又会**混进**窗口内起跑却还在跑的那个。这不是「差不多」:
      // 那恰恰就是一张 24h 失败牌存在的意义所在的那些 run。下面的「失败聚合 7d」正是宪法点名的那个**相近但不同**的
      // 列表:它按**连败**聚合 **workflow**、不按窗口聚合 run——一个整夜失败 4 次然后跑通了的 workflow,在这里贡献 4、
      // 在那里缺席(已自愈,连败 0)。两种单位、两个窗口、两个问题。把它们接起来,就会让牌写着 4、点开一个空区。
      _tile(
        context,
        label: t.kpiFailed24h,
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
        a11y: nextFire != null && nextFire.isAfter(now)
            ? t.kpiNextFireA11y(d: fmtWaited(nextFire.difference(now)))
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
