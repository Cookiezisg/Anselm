import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/model/status_state.dart' show AnStatus;
import '../../../../core/ui/an_panel_head.dart';
import '../../../../core/ui/an_callout.dart';
import '../../../../core/ui/an_code_block.dart';
import '../../../../core/ui/an_term_viewport.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_scroll_behavior.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../data/entity_kind.dart';
import '../../state/detail/entity_detail.dart';
import '../../state/detail/entity_detail_provider.dart';
import '../../../../core/shell/right_panel.dart';
import '../../state/run/run_terminal_controller.dart';
import '../../state/run/run_terminal_state.dart';
import '../../state/selected_entity.dart';
import '../../../../core/run/approval_gate.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_status_dot.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_hover_region.dart';
import '../../../../core/ui/an_expand_reveal.dart';
import '../../../../core/ui/an_ledger_row.dart';
import '../../../../core/ui/an_stat_bar.dart';
import '../../state/run/recent_runs_provider.dart';
import '../../../../core/ui/an_cast_row.dart';
import 'block_tree_view.dart';
import 'run_editor_card.dart';

/// The right-island run terminal (the headless [AnInspector] child) — bound to the SELECTED entity via the
/// [runTerminalProvider] family. Head = entity + verb + a live status state machine + the run meta. Body =
/// the typed input form over a single scroll, then the streamed output (fn/hd live stderr + result, agent
/// the ReAct block tree, workflow the flowrun nodes). The streamed body reads the coalesced
/// [RunTerminalController.stream] via a [ValueListenableBuilder] (≤1 repaint/frame); it sticks to the
/// bottom unless the user scrolls up. The close button collapses the right island (sticky).
///
/// 右岛 run 终端(headless AnInspector child),经 family 绑定选中实体。头=实体+动词+状态机+运行 meta;
/// body=类型化表单(单滚)+ 流式输出。流式 body 读合并的 controller.stream(每帧≤1 重画),除非上滑、否则贴底。
class RunTerminal extends ConsumerStatefulWidget {
  const RunTerminal({super.key});

  @override
  ConsumerState<RunTerminal> createState() => _RunTerminalState();
}

class _RunTerminalState extends ConsumerState<RunTerminal> {
  final ScrollController _scroll = ScrollController();
  bool _stick = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final atBottom = (p.maxScrollExtent - p.pixels) < AnSize.followSlop;
    if (atBottom != _stick) setState(() => _stick = atBottom);
  }

  void _autoscroll() {
    if (!_stick) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(selectedEntityProvider);
    if (sel == null) return const SizedBox.shrink();
    final state = ref.watch(runTerminalProvider(sel));
    final controller = ref.read(runTerminalProvider(sel).notifier);
    final detail = ref.watch(entityDetailProvider(sel)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, sel, state, detail),
        Expanded(
          child: ScrollConfiguration(
            behavior: const AnScrollBehavior(),
            child: SingleChildScrollView(
              controller: _scroll,
              // Vertical only — the AnIsland 12px is the sole horizontal island inset (内距单源律).
              // 仅纵向:岛壳 12 即唯一水平岛级内距。
              padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RunEditorCard(key: ValueKey(sel), entityRef: sel),
                    const SizedBox(height: AnSpace.s16),
                    ValueListenableBuilder<RunStream>(
                      valueListenable: controller.stream,
                      builder: (context, s, _) {
                        _autoscroll();
                        return _output(context, sel, state, s);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── head ────────────────────────────────────────────────────────────────────
  Widget _head(BuildContext context, EntityRef sel, RunTerminalState state, EntityDetail? detail) {
    final r = context.t.entities.run;
    final name = detail?.name ?? sel.id;
    // 三段式文法 §1+§2 (0719): the entity IDENTITY head — kind glyph + name, EVERY panel action collapsed
    // into a single ⋯ (the debugger has none yet → no ⋯, 「无则暂缺」), the first-class ✕, and a quiet
    // glance strip below (版本 · 今日执行 · 上次结果). The running/failed phase badge RETIRES: 「running」
    // already reads from the streaming body + the stop CTA, 「failed」 from the callout + settled bar, and
    // the last outcome from the glance's 「上次…」 — the head is pure identity (chat 侧幕同律).
    // 实体身份头:kind 图标+名、面板动作全收 ⋯(调试台暂无→无 ⋯)、一等 ✕ + 速览带;活/失败徽退役(运行由
    // 流式体+停止钮陈述、失败由 callout+落定条、上次结果由速览带),头纯身份。
    return AnPanelHead(
      icon: AnIcons.byKey(sel.kind.scopeKind),
      title: name,
      sub: _glance(context, sel, detail),
      onClose: () => ref.read(rightPanelCollapsedProvider.notifier).set(true),
      closeSemantics: r.close,
    );
  }

  /// §2 GLANCE STRIP — one quiet `v{N} · 今天 {n} 次执行 · 上次{结果} {耗时}` line: the active version
  /// number, today's execution count and the last run's outcome + elapsed, all AGGREGATED from the
  /// already-watched [recentRunsProvider] bench ledger (≤5 rows) + the detail. Each segment renders ONLY
  /// on real data (缺段不渲: a fresh entity with no runs shows just 「v{N}」, or nothing); all empty →
  /// null → [AnPanelHead] draws no band (全空不渲). 「今天」counts the bench rows whose start is the local
  /// today (bounded by the ledger's 5, so a very busy day under-reports — the bench is a glance, the full
  /// history lives in Logs). 速览带:版本·今日执行·上次结果,全从已监听的 recentRuns(≤5)+detail 聚合;有数据
  /// 才在、全空→null;「今天」数的是账内当天行(≤5 有界)。
  Widget? _glance(BuildContext context, EntityRef sel, EntityDetail? detail) {
    final c = context.colors;
    final t = context.t.entities.run;
    final segs = <String>[];
    final ver = detail?.activeVersionNumber;
    if (ver != null) segs.add('v$ver');
    final runs = ref.watch(recentRunsProvider(sel)).value ?? const <RecentRun>[];
    final now = DateTime.now();
    final today = runs.where((run) {
      final s = run.startedAt?.toLocal();
      return s != null && s.year == now.year && s.month == now.month && s.day == now.day;
    }).length;
    if (today > 0) segs.add(t.glanceToday(n: today));
    final last = runs.isNotEmpty ? runs.first : null;
    if (last != null) {
      // Only a SETTLED outcome speaks a 「上次…」 (ok/done · failed · cancelled) — a still-running last
      // run is 「now」, not a past result, so it stays silent. 只落定结局开口;仍在跑不算上次结果。
      final st = AnStatus.fromRaw(last.status);
      String? word;
      if (st == AnStatus.done) {
        word = t.glanceLastOk;
      } else if (st == AnStatus.err) {
        word = t.glanceLastFailed;
      } else if (last.status.toLowerCase() == 'cancelled') {
        word = t.glanceLastCancelled;
      }
      if (word != null) {
        segs.add(last.elapsedMs > 0
            ? '$word ${fmtDuration(Duration(milliseconds: last.elapsedMs))}'
            : word);
      }
    }
    if (segs.isEmpty) return null;
    return Text(
      segs.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AnText.meta.copyWith(color: c.inkFaint),
    );
  }

  /// The settled bar (落定条, AnStatBar 族): status word + elapsed; a workflow adds its flowrun id
  /// and the flagship door. 落定条:状态词+耗时;wf 加 flowrun id 与旗舰门。
  Widget _settledBar(BuildContext context, EntityRef sel, RunTerminalState state) {
    final r = context.t.entities.run;
    return AnStatBar(
      status: switch (state.phase) {
        RunPhase.ok => AnStatus.done,
        RunPhase.failed => AnStatus.err,
        _ => AnStatus.idle,
      },
      statusLabel: state.phase == RunPhase.cancelled ? r.cancelled : null,
      stats: [
        if (state.elapsedMs > 0) AnStat(fmtDuration(Duration(milliseconds: state.elapsedMs)), tabular: true),
        // Agent run meta rides the settled bar now the head's meta sub-row retired. agent 运行 meta 归落定条。
        if (sel.kind == EntityKind.agent && state.steps > 0) AnStat(r.steps(n: state.steps)),
        if (sel.kind == EntityKind.agent && (state.tokensIn > 0 || state.tokensOut > 0))
          AnStat(r.tokens(inT: state.tokensIn, outT: state.tokensOut)),
        if (sel.kind == EntityKind.workflow && state.flowrunId != null) AnStat(state.flowrunId!, tabular: true),
      ],
      chips: [
        if (sel.kind == EntityKind.workflow && state.flowrunId != null)
          AnButton(
            label: r.openFlowrun,
            size: AnButtonSize.sm,
            onPressed: () => context.go('/scheduler/runs/${state.flowrunId}'),
          ),
      ],
    );
  }

  // ── body ────────────────────────────────────────────────────────────────────
  Widget _output(BuildContext context, EntityRef sel, RunTerminalState state, RunStream s) {
    if (state.phase == RunPhase.idle) {
      // Never ran → NOTHING here (零墓碑, 0718 拍板): the form above IS the guidance; below it, air.
      // The bench strip renders separately. 没跑过=结果区不渲——表单即引导,下面是空气。
      return _RecentStrip(entityRef: sel);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isTerminal) ...[
          _settledBar(context, sel, state),
          const SizedBox(height: AnSpace.s12),
        ],
        if (state.phase == RunPhase.failed && (state.errorMsg ?? '').isNotEmpty) ...[
          AnCallout(state.errorMsg!, title: state.errorCode, severity: AnCalloutSeverity.danger),
          const SizedBox(height: AnSpace.s12),
        ],
        ..._kindBody(context, sel, state, s),
        _RecentStrip(entityRef: sel),
      ],
    );
  }

  List<Widget> _kindBody(BuildContext context, EntityRef sel, RunTerminalState state, RunStream s) {
    final r = context.t.entities.run;
    switch (sel.kind) {
      case EntityKind.control:
      case EntityKind.approval:
      case EntityKind.trigger:
        return const []; // support kinds — no run body 支撑 kind 无 run body
      case EntityKind.function:
      case EntityKind.handler:
        // ONE component for BOTH faces (A-095, 批1 复审: no live↔settled material flip, and mid-run
        // scroll-back survives): the bounded scrollback terminal — termFold+ANSI, stick-to-bottom
        // while streaming, «回到最新» pill, only the tail materialized for huge logs. The old path
        // re-laid the WHOLE buffer every frame and dumped raw ANSI escapes once settled.
        // 两脸同件(A-095,批1 复审:活/落定不换材质,运行中可回看):有界回滚终端窗——折叠+ANSI+钉底跟随+
        // 「回到最新」+大日志只物化尾部。旧径每帧全文重排、落定还裸渲转义字节。
        final text = s.text;
        return [
          if (text.trim().isNotEmpty)
            _section(context, r.outputHeading, AnTermViewport(text: text)),
          if (state.isTerminal && state.output != null)
            _section(context, r.resultHeading, _mono(context, prettyJson(state.output))),
          if ((state.logs ?? '').isNotEmpty) _section(context, r.logsHeading, _mono(context, state.logs!)),
        ];
      case EntityKind.agent:
        return [
          if (s.tree.isEmpty && state.isRunning)
            // Running with no first block yet = a WAITING state — an honest spinner, not a hint.
            // 运行中等首块=等待态,spinner 诚实。
            AnState(kind: AnStateKind.loading, size: AnStateSize.inset, title: r.noTrace)
          else if (!s.tree.isEmpty)
            _section(context, r.traceHeading, BlockTreeView(roots: s.tree.roots)),
          if (state.isTerminal && state.output != null)
            _section(context, r.resultHeading, _mono(context, prettyJson(state.output))),
        ];
      case EntityKind.workflow:
        return [_nodes(context, state, s)];
    }
  }

  Widget _nodes(BuildContext context, RunTerminalState state, RunStream s) {
    final r = context.t.entities.run;
    final parked = state.isRunning ? state.parkedNode : null;
    // Each flowrun node = a passive mono AnRow: status dot (lead) + 'nodeId · kind' + status word (meta).
    // A parked run grows the approval gate ABOVE the rows (the human decision is the next action).
    // 每个 flowrun 节点 = passive mono AnRow;停车时审批门长在行列之上(人决断是下一步)。
    if (state.flowNodes.isNotEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (parked != null) ...[
          ApprovalGate(
            parked: parked,
            onDecide: (v, _) => ref
                .read(runTerminalProvider(ref.read(selectedEntityProvider)!).notifier)
                .decide(parked.nodeId, v),
          ),
          const SizedBox(height: AnSpace.s12),
        ],
        _section(context, r.nodesHeading, _nodeList([
          for (final n in state.flowNodes) (label: '${n.nodeId} · ${n.kind}', status: n.status),
        ])),
      ]);
    }
    if (s.liveNodes.isNotEmpty) {
      return _section(context, r.nodesHeading, _nodeList([
        for (final e in s.liveNodes.entries) (label: e.key, status: e.value),
      ]));
    }
    // Mirror the agent branch (批7 复审): a RUNNING flowrun with no node rows yet is a waiting
    // state, not an empty archive. 运行中无节点=等待态,非空档案。
    return AnState(
        kind: state.isRunning ? AnStateKind.loading : AnStateKind.empty,
        size: AnStateSize.inset,
        title: r.noTrace);
  }

  /// The durable approval gate — the parked node's rendered prompt + Approve/Reject firing the
  /// backend `:decide` (first-wins; a lost race reconciles the gate away). Composed from existing
  /// primitives (card + action group), no new hand-rolled surface. 停车审批门:rendered 提示 +
  /// 通过/驳回直发 `:decide`(first-wins,输了对账自纠);既有原语组合、零手搓新面。
  Widget _nodeList(List<({String label, String status})> nodes) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final n in nodes)
            AnRow(
              label: n.label,
              mono: true,
              passive: true,
              dot: AnStatus.fromRaw(n.status),
              meta: n.status,
            ),
        ],
      );

  // ── shared bits ───────────────────────────────────────────────────────────--
  // A quiet headed section (lowercase faint meta label + tight body) — output / result / logs / trace /
  // nodes all ride it. 安静头组(小写灰 meta 标 + 紧凑体):各输出段共用。
  Widget _section(BuildContext context, String title, Widget child) =>
      AnSection(label: title, variant: AnSectionVariant.quiet, children: [child]);

  // Plain Text — the whole scroll body is one SelectionArea (best-practice over per-row SelectableText).
  Widget _mono(BuildContext context, String text) => AnCodeBlock(text);
}

/// The bench strip (「最近」段, 0719 拍板): this entity's last five executions off the SAME ledgers
/// the Logs tab pages — mixed real runs and bench runs, newest first. A row expands to its I/O
/// digest; hovering slides out the REPRODUCE key (回填该次输入——hd 连方法、wf 连来源), the archive
/// stays in the Logs tab (档案馆/工作台分层: the island never carries history).
///
/// 工作台条:该实体最近五次执行(与 Logs tab 同账,真跑/试跑混排新在前)。点行展开 IO 摘要;悬停滑出
/// 「重现」钥匙;全史归 Logs tab——右岛永不装历史。
class _RecentStrip extends ConsumerStatefulWidget {
  const _RecentStrip({required this.entityRef});

  final EntityRef entityRef;

  @override
  ConsumerState<_RecentStrip> createState() => _RecentStripState();
}

class _RecentStripState extends ConsumerState<_RecentStrip> {
  String? _hovered;
  String? _open;

  @override
  Widget build(BuildContext context) {
    final r = context.t.entities.run;
    if (!widget.entityRef.kind.executable) return const SizedBox.shrink();
    final async = ref.watch(recentRunsProvider(widget.entityRef));
    final rows = async.value ?? const <RecentRun>[];
    // Quiet in every non-data state (加载/失败皆静默——工作台条是辅助面,失败不喊;档案有 Logs tab).
    // 非数据态一律安静。
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s16),
      child: AnSection(label: r.recentCount(n: rows.length), variant: AnSectionVariant.quiet, children: [
        for (final run in rows) _row(context, run),
      ]),
    );
  }

  Widget _row(BuildContext context, RecentRun run) {
    final r = context.t.entities.run;
    final c = ref.read(runTerminalProvider(widget.entityRef).notifier);
    final hovered = _hovered == run.id;
    // A workflow run's detail lives on the run page (the island never hosts a long run — task ⑤); every
    // other kind expands to its I/O digest inline. wf 深链运行页(右岛不装长跑),余者内联展开 IO。
    final isWorkflow = widget.entityRef.kind == EntityKind.workflow;
    return AnHoverRegion(
      onEnter: (_) => setState(() => _hovered = run.id),
      onExit: (_) => setState(() {
        if (_hovered == run.id) _hovered = null;
      }),
      child: AnLedgerRow(
        lead: AnStatusDot(AnStatus.fromRaw(run.status)),
        // Relative time (刚刚 / 3 天前 / date) — the SAME voice the chat cast rows speak (core reuse).
        // 相对时间,与 chat cast 行同口径(core 复用)。
        primary: AnCastRow.timeLabel(context, run.startedAt ?? DateTime.now()),
        mono: false,
        chips: [
          // Single-line micro-labels (窄岛下不许折词成「workflo w」— 真机帧揪出). 微标不折行。
          if (run.method.isNotEmpty)
            Text(run.method,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.metaTabular().copyWith(color: context.colors.inkFaint)),
          // The wire origin word spoken as human text (手动/调度/对话…), never «manual»/«cron». 来源人话。
          if (run.triggeredBy.isNotEmpty)
            Text(runOriginLabel(context.t, run.triggeredBy),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.meta.copyWith(color: context.colors.inkFaint)),
          // «⎘ 用这份输入» slides out on hover — fills this run's input back into the editor (hd 连方法、
          // wf 连来源). 悬停滑出「用这份输入」,回填该次输入进编辑器。
          AnExpandReveal(
            axis: Axis.horizontal,
            open: hovered,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: AnSpace.s6),
              child: AnButton(
                label: r.reproduce,
                size: AnButtonSize.sm,
                surface: true,
                onPressed: () => c.loadInput(run),
              ),
            ),
          ),
        ],
        measure: run.elapsedMs > 0 ? fmtDuration(Duration(milliseconds: run.elapsedMs)) : null,
        disclose: true,
        expanded: _open == run.id,
        onTap: () => setState(() => _open = _open == run.id ? null : run.id),
        expandBuilder: (_) => isWorkflow
            ? Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnButton(
                  label: r.openRunPage,
                  size: AnButtonSize.sm,
                  onPressed: () => context.go('/scheduler/runs/${run.id}'),
                ),
              )
            // Lazy I/O digest (C-006): input, then the error (failed) OR the result. 惰性 IO 摘要:输入 + 错误/结果。
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (run.input.isNotEmpty) ...[
                    Text(r.inputHeading, style: AnText.meta.copyWith(color: context.colors.inkFaint)),
                    const SizedBox(height: AnSpace.s4),
                    AnCodeBlock(prettyJsonCapped(run.input)),
                  ],
                  if ((run.errorMsg ?? '').isNotEmpty) ...[
                    if (run.input.isNotEmpty) const SizedBox(height: AnSpace.s8),
                    Text(r.errorHeading, style: AnText.meta.copyWith(color: context.colors.inkFaint)),
                    const SizedBox(height: AnSpace.s4),
                    AnCallout(run.errorMsg!, severity: AnCalloutSeverity.danger),
                  ] else if (run.output != null) ...[
                    if (run.input.isNotEmpty) const SizedBox(height: AnSpace.s8),
                    Text(r.resultHeading, style: AnText.meta.copyWith(color: context.colors.inkFaint)),
                    const SizedBox(height: AnSpace.s4),
                    AnCodeBlock(prettyJsonCapped(run.output)),
                  ],
                ],
              ),
      ),
    );
  }
}
