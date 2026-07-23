import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/stage_truth.dart';
import '../tool_card_control_approval.dart';
import '../tool_card_skins.dart';
import 'stage_frame.dart';
import 'stage_scene.dart';

/// The CONTROL stage (WRK-061 §7-6, W3) — the discriminant ladder, live: an evaluation-order thread
/// runs down the left edge, rungs slide in as branches CLOSE (only completed branches surface), each
/// rung = ① priority ordinal · port name (w400) · the `when` CEL growing through [AnCelGrow] · the
/// emit grid (`field ← CEL`; an empty emit reads «透传» in ghost ink). The catch-all (`when:"true"`)
/// pins as a grey «否则» rung, never rendered as code. An EDIT lays the OLD LADDER at 40% first
/// (whole-replace semantics made visible, R-5). Settle: the result bar (vN rides the receipt).
///
/// control 舞台(W3)——判别式生长正殿:左缘求值顺序丝线,梯级随 branch 闭合滑入(只闭合者上台),每级=
/// 序号·port 名牌(w400)·when CEL(AnCelGrow)·emit 出射格(空 emit=幽灵「透传」);末级 when:"true" 渲灰徽
/// 「否则」,不渲成代码。edit 先铺旧梯 40%(全量替换语义可见,R-5)。落定:结果条(runStatBarOf)。
class ControlStageBody extends ConsumerWidget {
  const ControlStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final editId = scene.editTargetId;
    final truth = editId == null
        ? null
        : ref.watch(
            controlBaselineProvider((id: editId, block: scene.node.id)),
          );
    final oldBranches =
        truth?.asData?.value.activeVersion?.branches ?? const [];

    final branches = controlBranches(scene.session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The old ladder at 40% — the whole-replace honesty stratum (edit, live only). 旧梯垫底。
        // 假想框律:瞬时地层的裸文字(旧梯标签+旧分支行)归假想框(X=8),与下方生长梯左缘同起。
        if (scene.live && oldBranches.isNotEmpty) ...[
          stageFramed(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.chat.stage.oldLadder,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
                const SizedBox(height: AnSpace.s2),
                Opacity(
                  opacity: AnOpacity.stratum,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < oldBranches.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AnSpace.s2),
                          child: Text(
                            '${i + 1} ${oldBranches[i].port} · ${oldBranches[i].when}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AnText.code.copyWith(color: c.inkMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AnSpace.s6),
        ],
        // The family ladder skeleton (批6 A-075 — the hand-rolled numbered circle + evaluation
        // thread retire; rung content stays here). 族梯骨架(手搓序号圆+求值丝线退役;级内容自持)。
        // 假想框律:整梯归假想框(外层 s8)——序号沟从 X=8 起(AnLadder 自持的序号→丝线沟不动,只整体右移),
        // 与裸文字/沟行同一条框线。The imaginary-frame law: the whole ladder joins the frame — its numbered
        // gutter now starts at X=8 (AnLadder's own ordinal→thread gutter is untouched, just shifted as one).
        stageFramed(
          AnLadder(
            children: [
              for (final b in branches) _rungContent(context, c, t, b),
            ],
          ),
        ),
        if (!scene.live && !scene.failed) ...[
          const SizedBox(height: AnSpace.s6),
          runStatBarOf(context, scene.state),
        ],
      ],
    );
  }

  // The rung's CONTENT only — the skeleton (numbered circle + thread) is AnLadder's. 级内容(骨架归梯)。
  Widget _rungContent(
    BuildContext context,
    AnColors c,
    Translations t,
    ControlBranch b,
  ) {
    final isCatchAll = b.when.trim() == 'true';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                b.port,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.body
                    .weight(AnText.emphasisWeight)
                    .copyWith(color: c.ink),
              ),
            ),
            if (isCatchAll) ...[
              const SizedBox(width: AnSpace.s6),
              AnChip(t.chat.stage.elseFallback, tone: AnTone.none),
            ],
          ],
        ),
        if (!isCatchAll)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: AnCelGrow(expression: b.when, live: scene.live),
          ),
        if (b.emit.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: Text(
              t.chat.stage.passThrough,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
          )
        else
          for (final e in b.emit.entries)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.key} ← ',
                    style: AnText.code.copyWith(color: c.inkFaint),
                  ),
                  Expanded(
                    child: AnCelGrow(expression: e.value, live: scene.live),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
