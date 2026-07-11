import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/workflow.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/status_state.dart' show AnStatus, AnTone;
import '../../../../core/ui/an_badge.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_action_group.dart';
import '../../../../core/ui/an_callout.dart';
import '../../../../core/ui/an_code_block.dart';
import '../../../../core/ui/an_info_card.dart';
import '../../../../core/ui/an_term_viewport.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_scroll_behavior.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_labels.dart';
import '../../state/detail/entity_detail.dart';
import '../../state/detail/entity_detail_provider.dart';
import '../../../../core/shell/right_panel.dart';
import '../../state/run/run_terminal_controller.dart';
import '../../state/run/run_terminal_state.dart';
import '../../state/selected_entity.dart';
import 'block_tree_view.dart';
import 'run_input_form.dart';

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
    final atBottom = (p.maxScrollExtent - p.pixels) < 32;
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
              padding: const EdgeInsets.all(AnSpace.s16),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RunInputForm(
                      key: ValueKey(sel),
                      entityRef: sel,
                      verbLabel: sel.kind.verbLabel(context.t),
                    ),
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
    final c = context.colors;
    final r = context.t.entities.run;
    final name = detail?.name ?? sel.id;
    final badge = _phaseBadge(context, state.phase);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AnSpace.s16, AnSpace.s12, AnSpace.s8, AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AnIcons.byKey(sel.kind.scopeKind), size: AnSize.icon, color: c.inkFaint),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
              ),
              AnButton.iconOnly(
                AnIcons.close,
                semanticLabel: r.close,
                onPressed: () => ref.read(rightPanelCollapsedProvider.notifier).set(true),
              ),
            ],
          ),
          const SizedBox(height: AnSpace.s6),
          Row(
            children: [
              Text(sel.kind.verbLabel(context.t), style: AnText.meta.copyWith(color: c.inkMuted)),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Text(
                  _metaLine(context, sel, state),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ),
              const SizedBox(width: AnSpace.s8),
              AnBadge(badge.$1, tone: badge.$2),
            ],
          ),
        ],
      ),
    );
  }

  (String, AnTone) _phaseBadge(BuildContext context, RunPhase phase) {
    final t = context.t;
    return switch (phase) {
      RunPhase.idle => (t.status.idle, AnTone.none),
      RunPhase.running => (t.status.run, AnTone.accent),
      RunPhase.ok => (t.status.done, AnTone.ok),
      RunPhase.failed => (t.status.err, AnTone.danger),
      RunPhase.cancelled => (t.entities.run.cancelled, AnTone.none),
    };
  }

  String _metaLine(BuildContext context, EntityRef sel, RunTerminalState state) {
    if (!state.isTerminal) return '';
    final r = context.t.entities.run;
    final parts = <String>[];
    switch (sel.kind) {
      case EntityKind.control:
      case EntityKind.approval:
      case EntityKind.trigger:
        break; // support kinds — no run meta 支撑 kind 无 run meta
      case EntityKind.agent:
        if (state.steps > 0) parts.add(r.steps(n: state.steps));
        if (state.tokensIn > 0 || state.tokensOut > 0) {
          parts.add(r.tokens(inT: state.tokensIn, outT: state.tokensOut));
        }
        if (state.elapsedMs > 0) parts.add(r.ms(ms: state.elapsedMs));
      case EntityKind.workflow:
        if (state.flowrunId != null) parts.add(state.flowrunId!);
      case EntityKind.function:
      case EntityKind.handler:
        if (state.elapsedMs > 0) parts.add(r.ms(ms: state.elapsedMs));
    }
    return parts.join(' · ');
  }

  // ── body ────────────────────────────────────────────────────────────────────
  Widget _output(BuildContext context, EntityRef sel, RunTerminalState state, RunStream s) {
    final r = context.t.entities.run;
    if (state.phase == RunPhase.idle) {
      return AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: r.idleTitle, hint: r.idleHint);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.phase == RunPhase.failed && (state.errorMsg ?? '').isNotEmpty) ...[
          AnCallout(state.errorMsg!, title: state.errorCode, severity: AnCalloutSeverity.danger),
          const SizedBox(height: AnSpace.s12),
        ],
        ..._kindBody(context, sel, state, s),
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
            _section(context, r.outputHeading, AnTermViewport(text: text, fadeColor: context.colors.surface)),
          if (state.isTerminal && state.output != null)
            _section(context, r.resultHeading, _mono(context, prettyJson(state.output))),
          if ((state.logs ?? '').isNotEmpty) _section(context, r.logsHeading, _mono(context, state.logs!)),
        ];
      case EntityKind.agent:
        return [
          if (s.tree.isEmpty && state.isRunning)
            _hint(context, r.noTrace)
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
          _approvalGate(context, parked),
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
    return _hint(context, r.noTrace);
  }

  /// The durable approval gate — the parked node's rendered prompt + Approve/Reject firing the
  /// backend `:decide` (first-wins; a lost race reconciles the gate away). Composed from existing
  /// primitives (card + action group), no new hand-rolled surface. 停车审批门:rendered 提示 +
  /// 通过/驳回直发 `:decide`(first-wins,输了对账自纠);既有原语组合、零手搓新面。
  Widget _approvalGate(BuildContext context, FlowrunNode parked) {
    final r = context.t.entities.run;
    final c = context.colors;
    final prompt = parked.result['rendered'] as String? ?? '';
    final notifier = ref.read(runTerminalProvider(ref.read(selectedEntityProvider)!).notifier);
    return AnInfoCard(
      title: r.approvalTitle,
      icon: AnIcons.approval,
      meta: parked.nodeId,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (prompt.isNotEmpty) ...[
          Text(prompt, style: AnText.body.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s8),
        ],
        Text(r.approvalHint, style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnSpace.s8),
        AnActionGroup([
          AnButton(
            label: r.approve,
            variant: AnButtonVariant.primary,
            size: AnButtonSize.sm,
            onPressed: () => notifier.decide(parked.nodeId, 'yes'),
          ),
          AnButton(
            label: r.reject,
            variant: AnButtonVariant.danger,
            size: AnButtonSize.sm,
            onPressed: () => notifier.decide(parked.nodeId, 'no'),
          ),
        ]),
      ]),
    );
  }

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

  Widget _hint(BuildContext context, String text) =>
      Text(text, style: AnText.meta.copyWith(color: context.colors.inkFaint));

}
