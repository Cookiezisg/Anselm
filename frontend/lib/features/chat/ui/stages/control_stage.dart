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
    final truth = editId == null ? null : ref.watch(controlTruthProvider(editId));
    final oldBranches = truth?.asData?.value.activeVersion?.branches ?? const [];

    final branches = controlBranches(scene.session);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // The old ladder at 40% — the whole-replace honesty stratum (edit, live only). 旧梯垫底。
      if (scene.live && oldBranches.isNotEmpty) ...[
        Text(t.chat.stage.oldLadder, style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnSpace.s2),
        Opacity(
          opacity: AnOpacity.stratum,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < oldBranches.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AnSpace.s2),
                child: Text('${i + 1} ${oldBranches[i].port} · ${oldBranches[i].when}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.code.copyWith(color: c.inkMuted)),
              ),
          ]),
        ),
        const SizedBox(height: AnSpace.s6),
      ],
      for (var i = 0; i < branches.length; i++) _rung(context, c, t, i, branches[i]),
      if (!scene.live && !scene.failed) ...[
        const SizedBox(height: AnSpace.s6),
        runStatBarOf(context, scene.state),
      ],
    ]);
  }

  Widget _rung(BuildContext context, AnColors c, Translations t, int index, ControlBranch b) {
    final isCatchAll = b.when.trim() == 'true';
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // The evaluation-order thread: first-true-wins runs TOP-DOWN. 求值顺序丝线(自上而下先真先赢)。
        Column(children: [
          Container(
            width: AnSize.icon,
            height: AnSize.icon,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.line, width: AnSize.hairline),
            ),
            child: Text('${index + 1}', style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
          Expanded(child: Container(width: AnSize.hairline, color: c.line)),
        ]),
        const SizedBox(width: AnSpace.s8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(b.port,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
                ),
                if (isCatchAll) ...[
                  const SizedBox(width: AnSpace.s6),
                  AnChip(t.chat.stage.elseFallback, tone: AnTone.none),
                ],
              ]),
              if (!isCatchAll)
                Padding(
                  padding: const EdgeInsets.only(top: AnSpace.s2),
                  child: AnCelGrow(expression: b.when, live: scene.live),
                ),
              if (b.emit.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AnSpace.s2),
                  child: Text(t.chat.stage.passThrough,
                      style: AnText.meta.copyWith(color: c.inkFaint.withValues(alpha: c.inkFaint.a * 0.7))),
                )
              else
                for (final e in b.emit.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: AnSpace.s2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e.key} ← ', style: AnText.code.copyWith(color: c.inkFaint)),
                      Expanded(child: AnCelGrow(expression: e.value, live: scene.live)),
                    ]),
                  ),
            ]),
          ),
        ),
      ]),
    );
  }
}
