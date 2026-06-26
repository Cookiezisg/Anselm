import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/status_state.dart' show AnStatus, AnTone;
import '../../../../core/ui/an_badge.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_callout.dart';
import '../../../../core/ui/an_code_surface.dart';
import '../../../../core/ui/an_scroll_behavior.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_format.dart';
import '../../data/entity_kind.dart';
import '../../state/detail/entity_detail.dart';
import '../../state/detail/entity_detail_provider.dart';
import '../../state/run/run_terminal_controller.dart';
import '../../state/run/run_terminal_state.dart';
import 'block_tree_view.dart';
import 'run_input_form.dart';

/// The right-island run terminal (the headless [AnInspector] child). Head = entity + verb + a live status
/// state machine (idle/running/ok/failed/cancelled) + the run meta (elapsed / steps / tokens). Body = the
/// typed input form over a single scroll, then the streamed output: fn/hd live stderr + the bare result,
/// agent the ReAct block tree + result, workflow the flowrun node list. The streamed body reads the
/// coalesced [RunTerminalController.stream] via a [ValueListenableBuilder] (≤1 repaint/frame under a delta
/// firehose); it sticks to the bottom unless the user scrolls up.
///
/// 右岛 run 终端(headless AnInspector 的 child)。头=实体+动词+状态机+运行 meta。body=类型化表单(单滚)
/// + 流式输出(fn/hd 实时 stderr+裸结果 / agent 块树+结果 / workflow flowrun 节点)。body 读合并的
/// controller.stream(每帧≤1 重画),除非用户上滑、否则贴底。
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

  // Best-practice stick-to-bottom: jump AFTER layout (post-frame) so maxScrollExtent reflects the just-
  // appended content, and only while the user hasn't scrolled up. 贴底:布局后(post-frame)跳,且未上滑时。
  void _autoscroll() {
    if (!_stick) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(runTerminalProvider);
    final target = state.ref;
    if (target == null) return const SizedBox.shrink();
    final controller = ref.read(runTerminalProvider.notifier);
    final detail = ref.watch(entityDetailProvider(target)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, state, detail, controller),
        Container(height: AnSize.hairline, color: context.colors.line),
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
                      key: ValueKey(target),
                      kind: target.kind,
                      inputs: _inputs(target.kind, detail),
                      methods: _methods(detail),
                      busy: state.isRunning,
                      terminal: state.isTerminal,
                      verbLabel: _verbLabel(context, target.kind),
                      onRun: (req, method) =>
                          controller.run(request: req, method: method),
                      onCancel: controller.cancel,
                    ),
                    const SizedBox(height: AnSpace.s16),
                    ValueListenableBuilder<RunStream>(
                      valueListenable: controller.stream,
                      builder: (context, s, _) {
                        _autoscroll();
                        return _output(context, state, s);
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
  Widget _head(
    BuildContext context,
    RunTerminalState state,
    EntityDetail? detail,
    RunTerminalController controller,
  ) {
    final c = context.colors;
    final r = context.t.entities.run;
    final name = detail?.name ?? state.ref!.id;
    final badge = _phaseBadge(context, state.phase);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AnSpace.s16,
        AnSpace.s12,
        AnSpace.s8,
        AnSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                AnIcons.byKey(state.ref!.kind.scopeKind),
                size: AnSize.icon,
                color: c.inkMuted,
              ),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.body
                      .weight(FontWeight.w600)
                      .copyWith(color: c.ink),
                ),
              ),
              AnButton.iconOnly(
                AnIcons.close,
                semanticLabel: r.close,
                onPressed: controller.close,
              ),
            ],
          ),
          const SizedBox(height: AnSpace.s6),
          Row(
            children: [
              Text(
                _verbLabel(context, state.ref!.kind),
                style: AnText.meta.copyWith(color: c.inkMuted),
              ),
              const SizedBox(width: AnSpace.s8),
              // The run meta (steps · tokens · ms) takes the slack + ellipsizes so it never overflows the
              // fixed 320 island. 运行 meta 占剩余空间 + 省略,绝不撑破固定岛宽。
              Expanded(
                child: Text(
                  _metaLine(context, state),
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

  String _metaLine(BuildContext context, RunTerminalState state) {
    if (!state.isTerminal) return '';
    final r = context.t.entities.run;
    final parts = <String>[];
    switch (state.ref!.kind) {
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
  Widget _output(BuildContext context, RunTerminalState state, RunStream s) {
    final r = context.t.entities.run;
    if (state.phase == RunPhase.idle) {
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        title: r.idleTitle,
        hint: r.idleHint,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.phase == RunPhase.failed &&
            (state.errorMsg ?? '').isNotEmpty) ...[
          AnCallout(
            state.errorMsg!,
            title: state.errorCode,
            severity: AnCalloutSeverity.danger,
          ),
          const SizedBox(height: AnSpace.s12),
        ],
        ..._kindBody(context, state, s),
      ],
    );
  }

  List<Widget> _kindBody(
    BuildContext context,
    RunTerminalState state,
    RunStream s,
  ) {
    final r = context.t.entities.run;
    switch (state.ref!.kind) {
      case EntityKind.function:
      case EntityKind.handler:
        return [
          if (s.text.isNotEmpty)
            _section(context, r.outputHeading, _mono(context, s.text)),
          if (state.isTerminal && state.output != null)
            _section(
              context,
              r.resultHeading,
              _mono(context, prettyJson(state.output)),
            ),
          if ((state.logs ?? '').isNotEmpty)
            _section(context, r.logsHeading, _mono(context, state.logs!)),
        ];
      case EntityKind.agent:
        return [
          if (s.tree.isEmpty && state.isRunning)
            _hint(context, r.noTrace)
          else if (!s.tree.isEmpty)
            _section(
              context,
              r.traceHeading,
              BlockTreeView(roots: s.tree.roots),
            ),
          if (state.isTerminal && state.output != null)
            _section(
              context,
              r.resultHeading,
              _mono(context, prettyJson(state.output)),
            ),
        ];
      case EntityKind.workflow:
        return [_nodes(context, state, s)];
    }
  }

  Widget _nodes(BuildContext context, RunTerminalState state, RunStream s) {
    final c = context.colors;
    final r = context.t.entities.run;
    // Durable node list (post-fetch) is the truth; while running we show the live ticks. 跑完用真相、跑中用实时。
    if (state.flowNodes.isNotEmpty) {
      return _section(
        context,
        r.nodesHeading,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final n in state.flowNodes)
              Padding(
                padding: const EdgeInsets.only(bottom: AnSpace.s6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${n.nodeId} · ${n.kind}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AnText.value(mono: true).copyWith(color: c.ink),
                      ),
                    ),
                    const SizedBox(width: AnSpace.s8),
                    AnBadge(n.status, tone: AnStatus.fromRaw(n.status).tone),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (s.liveNodes.isNotEmpty) {
      return _section(
        context,
        r.nodesHeading,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in s.liveNodes.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AnSpace.s6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AnText.value(mono: true).copyWith(color: c.ink),
                      ),
                    ),
                    const SizedBox(width: AnSpace.s8),
                    AnBadge(e.value, tone: AnStatus.fromRaw(e.value).tone),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return _hint(context, r.noTrace);
  }

  // ── shared bits ───────────────────────────────────────────────────────────--
  Widget _section(BuildContext context, String title, Widget child) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s6),
          child,
        ],
      ),
    );
  }

  // Plain Text — the whole scroll body is wrapped in one SelectionArea (best-practice: SelectionArea over
  // per-row SelectableText, which defeats list recycling + can't select across rows). 整 body 一个 SelectionArea。
  Widget _mono(BuildContext context, String text) => AnCodeSurface(
    child: Padding(
      padding: const EdgeInsets.all(AnSpace.s8),
      child: Text(
        text,
        style: AnText.value(mono: true).copyWith(color: context.colors.ink),
      ),
    ),
  );

  Widget _hint(BuildContext context, String text) =>
      Text(text, style: AnText.meta.copyWith(color: context.colors.inkFaint));

  List<Field> _inputs(EntityKind kind, EntityDetail? d) {
    if (d == null) return const [];
    return switch (kind) {
      EntityKind.function => d.function?.activeVersion?.inputs ?? const [],
      EntityKind.agent => d.agent?.activeVersion?.inputs ?? const [],
      EntityKind.handler || EntityKind.workflow => const [],
    };
  }

  List<MethodSpec> _methods(EntityDetail? d) =>
      d?.handler?.activeVersion?.methods ?? const [];

  String _verbLabel(BuildContext context, EntityKind k) => switch (k) {
    EntityKind.function => context.t.entities.detail.verb.run,
    EntityKind.handler => context.t.entities.detail.verb.call,
    EntityKind.agent => context.t.entities.detail.verb.invoke,
    EntityKind.workflow => context.t.entities.detail.verb.trigger,
  };
}
