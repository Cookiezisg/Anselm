import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/entities/values.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/graph/flowrun_timeline.dart';
import '../../../core/graph/graph_run_state.dart';
import '../../../core/run/run_nav.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../state/scheduler_home_provider.dart';
import 'scheduler_run_model.dart';

/// The inline peek card under a run row (0717 拍板 — the bottom linked pane's successor): the SAME
/// selection, rendered where the user tapped instead of somewhere below the fold. Two single-run
/// lenses (gantt ⇄ graph; the cross-run matrix moved to the top of the page where it belongs) + the
/// one flagship door. Lazy by construction — built only while its row is expanded
/// ([AnLedgerRow.expandBuilder]).
///
/// **Cross-workflow reusable** (WRK-070 B10): it takes [workflowId] + [flowrunId] explicitly, so BOTH
/// the operations home's run big table AND the Overview's running / failed zones open the identical
/// card under a tapped row — one implementation, never a parallel one.
/// run 行下的行内速览卡(0717 拍板——底部联动格的后继):同一个选区,渲在用户点的那一行底下而非折叠线以下
/// 的某处。两个单 run 透镜(甘特⇄图;跨 run 的矩阵已升页顶归位)+ 唯一旗舰门。天生惰性——仅所在行展开时才建
/// (AnLedgerRow.expandBuilder)。**跨 workflow 可复用**(B10):显式吃 workflowId+flowrunId,故运营主页大表
/// 与 Overview 在跑/失败区点开的是同一张卡——一份实现,绝无平行。
enum _PeekFace { gantt, graph }

class RunPeekCard extends ConsumerStatefulWidget {
  const RunPeekCard({
    required this.workflowId,
    required this.flowrunId,
    super.key,
  });

  final String workflowId;
  final String flowrunId;

  @override
  ConsumerState<RunPeekCard> createState() => _RunPeekCardState();
}

class _RunPeekCardState extends ConsumerState<RunPeekCard> {
  _PeekFace _face = _PeekFace.gantt;

  @override
  Widget build(BuildContext context) {
    final t = context.t.scheduler.home;
    final c = context.colors;
    final runAsync = ref.watch(schedulerLinkedRunProvider(widget.flowrunId));
    final wfAsync = ref.watch(schedulerWorkflowProvider(widget.workflowId));

    Widget body;
    final comp = runAsync.value;
    if (comp != null) {
      final graph = graphOfVersion(wfAsync.value?.activeVersion);
      if (_face == _PeekFace.gantt) {
        final rows = flowrunTimeline(graph ?? const Graph(), comp);
        body = rows.isEmpty
            ? Text(
                t.paneNoNodes,
                style: AnText.body.copyWith(color: c.inkFaint),
              )
            : AnNodeGantt(
                rows: rows,
                notRunLabel: t.notRun,
                waitingLabel: context.t.run.nodeWait,
              );
      } else if (graph != null) {
        body = AnGraphCanvas(
          graph: graph,
          framed: true,
          run: deriveRunState(
            graph,
            rows: comp.nodes,
            runStatus: comp.flowrun.status,
          ),
        );
      } else if (!wfAsync.hasValue && !wfAsync.hasError) {
        body = const AnDeferredLoading(child: AnSkeleton.lines(3));
      } else {
        body = Text(t.noGraph, style: AnText.body.copyWith(color: c.inkFaint));
      }
    } else if (runAsync.hasError) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              t.paneError,
              style: AnText.body.copyWith(color: c.inkMuted),
            ),
          ),
          AnButton(
            label: context.t.scheduler.retry,
            size: AnButtonSize.sm,
            onPressed: () =>
                ref.invalidate(schedulerLinkedRunProvider(widget.flowrunId)),
          ),
        ],
      );
    } else {
      body = const AnDeferredLoading(child: AnSkeleton.lines(3));
    }

    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s6),
      child: AnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // The leading cluster is the ONE flex region (wraps/shrinks); the faces + door keep
                // their fixed slots. 前导簇=唯一弹性区;两脸与门守定宽槽。
                Expanded(
                  child: Wrap(
                    spacing: AnGap.inline,
                    runSpacing: AnGap.stackTight,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (comp != null) ...[
                        AnStatusDot(AnStatus.fromRaw(comp.flowrun.status)),
                        // The full id lives HERE (需求⑤:行内无裸 id,速览卡与 tooltip 收编完整 id)。
                        AnChip(
                          truncate(comp.flowrun.id, AnTrunc.id),
                          mono: true,
                          look: AnChipLook.outlined,
                          tooltip: comp.flowrun.id,
                        ),
                        if (comp.flowrun.conversationId != null &&
                            comp.flowrun.conversationId!.isNotEmpty)
                          toolNavPill(
                            context,
                            kind: 'conversation',
                            label: context.t.scheduler.home.srcChat,
                            id: comp.flowrun.conversationId,
                          ),
                      ],
                    ],
                  ),
                ),
                // Two faces → the standard control slot (token 自身之律:2 段走标准槽). 两脸走标准槽。
                SizedBox(
                  width: AnSize.ctlSlot,
                  child: AnSegmented<_PeekFace>(
                    value: _face,
                    semanticLabel: t.faceA11y,
                    options: [
                      AnSegmentedOption(
                        value: _PeekFace.gantt,
                        label: t.faceGantt,
                      ),
                      AnSegmentedOption(
                        value: _PeekFace.graph,
                        label: t.faceGraph,
                      ),
                    ],
                    onChanged: (f) => setState(() => _face = f),
                  ),
                ),
                const SizedBox(width: AnGap.inlineLoose),
                AnButton(
                  label: t.openRun,
                  size: AnButtonSize.sm,
                  onPressed: () => context.go(
                    '/scheduler/w/${widget.workflowId}/runs/${widget.flowrunId}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AnGap.block),
            body,
            // The run's error, in full (0718 宁静化 — 错误句撤出行 → 速览卡): the failed run rows are now
            // single-line (red dot = the only alarm), and the ONE red detail lands HERE, in the card's
            // context — AnCallout danger, the same error voice the run flagship's summary speaks (one
            // text, consistent surfaces). Present only for a run that carries a wire error.
            // run 错误全文:失败行已单行化(红点=唯一警报),那条红细节落在卡里(与旗舰错误摘要同声);仅有错误时在场。
            if (comp != null &&
                (comp.flowrun.error?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: AnGap.block),
              AnCallout(
                comp.flowrun.error!.trim(),
                severity: AnCalloutSeverity.danger,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
