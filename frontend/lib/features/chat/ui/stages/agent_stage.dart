import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../model/tool_receipts.dart';
import '../../state/stage_truth.dart';
import '../tool_card_skins.dart';
import 'stage_frame.dart';
import 'stage_scene.dart';

/// The AGENT stage (WRK-061 §7-3, W5) — the persona assembly bay: the prompt prose grows in the
/// central window (word-tail, R-13 bounded), each closed ToolRef clicks a BELT CHIP on (fn_/hd_/mcp
/// faces, neutral while live per R-4), knowledge ids chip in shimmer-named, and the model override
/// flips its plate. An EDIT discloses PROGRESSIVELY (R-9): slots the args never mention keep the OLD
/// truth at 40% ink — «AI 只动了这些» readable at a glance. Settle: the reconciled GET's belt +
/// knowledge as full-ink chips + the result bar (mount-health lamps ride the entity page tier).
///
/// agent 舞台(W5)——人格装配台:prompt 散文中央窗(词尾生长),ToolRef 闭合即扣腰带芯片(live 中性 R-4),
/// knowledge 芯片候名,modelOverride 翻牌。edit 按 R-9 渐进开区:args 未提及的槽以 40% 墨保留旧真相——
/// 「AI 只动了这些」一眼可读。落定:GET 对账腰带+知识全墨芯片+结果条(mount 体检灯归实体页档)。
class AgentStageBody extends ConsumerWidget {
  const AgentStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final session = scene.session;
    final editId = scene.editTargetId;
    final truth = editId == null ? null : ref.watch(agentTruthProvider(editId));
    final old = truth?.asData?.value.activeVersion;

    final prompt = session.liveStringNamed('prompt');
    final tools = session.arrayItemsAt(['tools']);
    final knowledge = session.arrayItemsAt(['knowledge']);
    // REAL wire shape (G8/A3-33): modelOverride is an OBJECT `{apiKeyId, modelId}` — the old
    // string reads returned null on a Map, so the model badge never lit on a live create/edit.
    // 真线缆形:modelOverride 是对象——旧字符串读法对 Map 恒 null,live 期模型牌从不点亮。
    final rawOverride = session.closedValueAt(['modelOverride']);
    final overrideId = rawOverride is Map ? rawOverride['modelId'] : null;
    final model = overrideId is String && overrideId.isNotEmpty
        ? overrideId
        : null;

    final promptTouched = prompt != null;
    final toolsTouched = tools.isNotEmpty;
    final knowledgeTouched = knowledge.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The prompt window: fresh ink when the args opened it, the 40% stratum otherwise (R-9). 散文窗。
        if (promptTouched) ...[
          AnWindow(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                // Live streaming bounds to the word-tail (R-13); a settled truth render shows the FULL prompt
                // (「看真身」应见全貌,WRK-064). 活流限尾 14 行;落定真身显全文。
                scene.live ? tailLines(prompt, 14) : prompt,
                style: AnText.reading.copyWith(color: c.inkMuted),
              ),
            ),
          ),
        ] else if (scene.live && old != null && old.prompt.isNotEmpty) ...[
          AnLayerDiff(
            oldText: old.prompt,
            versionLabel: 'v${old.version}',
            maxLines: 5,
          ),
        ],
        const SizedBox(height: AnSpace.s6),
        // 假想框律:腰带/知识/模型芯片(裸 chips)归假想框(X=8);prompt AnWindow(真框)贴 X=0。The
        // imaginary-frame law: the belt / knowledge / model chips (bare chips) join the frame (X=8); the prompt
        // window (a real frame) stays at X=0.
        // The tool belt: closed refs click on; untouched slots keep the old belt at 40% (R-9). 腰带。
        if (toolsTouched)
          stageFramed(
            Wrap(
              spacing: AnSpace.s4,
              runSpacing: AnSpace.s4,
              children: [for (final ref_ in tools) _beltChip(ref_)],
            ),
          )
        else if (scene.live && old != null && old.tools.isNotEmpty)
          stageFramed(
            Opacity(
              opacity: AnOpacity.stratum,
              child: Wrap(
                spacing: AnSpace.s4,
                runSpacing: AnSpace.s4,
                children: [
                  for (final ref_ in old.tools)
                    _beltChip({'ref': ref_.ref, 'name': ref_.name}),
                ],
              ),
            ),
          ),
        if (knowledgeTouched) ...[
          const SizedBox(height: AnSpace.s4),
          stageFramed(
            Wrap(
              spacing: AnSpace.s4,
              runSpacing: AnSpace.s4,
              children: [
                for (final k in knowledge) AnChip('$k', tone: AnTone.none),
              ],
            ),
          ),
        ],
        if (model != null && model.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s4),
          stageFramed(AnChip(model, tone: AnTone.accent)),
        ],
        if (!scene.live && !scene.failed) ...[
          const SizedBox(height: AnSpace.s6),
          runStatBarOf(context, scene.state),
        ],
      ],
    );
  }

  // Shell deleted, brain kept (批5 A-040): the wire ToolRef is {ref, name} (values.dart) — show
  // the resolved name, ref as fallback; the chip itself is the family head (ONE voice both faces —
  // the settled full-ink face yields to the family ink, 刻意裁决帧核). 删壳留脑:标签解析自有,壳走
  // 当家件;live/settled 同声零跳变。
  String _beltLabel(Object? ref_) {
    if (ref_ is Map) {
      final name = '${ref_['name'] ?? ''}';
      return name.isNotEmpty ? name : '${ref_['ref'] ?? ''}';
    }
    return '$ref_';
  }

  Widget _beltChip(Object? ref_) =>
      AnChip(_beltLabel(ref_), look: AnChipLook.outlined);
}
