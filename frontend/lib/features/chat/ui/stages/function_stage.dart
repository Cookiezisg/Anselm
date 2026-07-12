import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/stage_truth.dart';
import '../tool_card_skins.dart';
import 'stage_scene.dart';

/// The FUNCTION stage (WRK-061 §7-1, W2 flagship) — code being authored, live. Streaming: the op
/// ticker drops a NEUTRAL chip per completed op (R-4: dictated, not succeeded), `set_code`'s code
/// grows through the live editor face (AnCodeEditor.live — bounded stick-to-bottom viewport, same
/// shell/highlight/gutter as settled), signature pills light as set_inputs/outputs close, dependency
/// chips likewise. An EDIT opens over the old truth (R-5): [AnLayerDiff] keeps "改之前的它" on stage
/// at low ink. Settle: the SAME editor un-pins + an HONEST diff badge (+n −m computed from the
/// fetched before vs the landed after) + the result-bar adapter [runStatBarOf]. Failure keeps the streamed draft readable.
///
/// function 舞台(W2 旗舰)——代码正在被写成。流式:op ticker 逐 op 落中性芯片(R-4)、set_code 走编辑器
/// live 脸(有界贴底视口,同壳同高亮同行号)、签名药丸/依赖芯片随闭合点亮;edit 先铺旧真相地层(R-5)。
/// 落定:同一编辑器解除钉底+真 diff 徽(+n −m)+结果条(runStatBarOf)。失败保留可读草稿。
class FunctionStageBody extends ConsumerWidget {
  const FunctionStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final editId = scene.editTargetId;
    final truth = editId == null ? null : ref.watch(functionTruthProvider(editId));
    final oldCode = truth?.asData?.value.activeVersion?.code ?? '';
    final oldVersion = truth?.asData?.value.activeVersion?.version;

    final code = session.liveStringNamed('code') ?? '';
    final ops = session.arrayItemsAt(['ops']);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // The old-truth stratum — only while LIVE editing (the settle's diff badge takes over). 旧地层。
      if (scene.live && oldCode.isNotEmpty) ...[
        AnLayerDiff(
          oldText: oldCode,
          versionLabel: oldVersion == null ? t.chat.stage.beforeEdit : 'v$oldVersion · ${t.chat.stage.beforeEdit}',
        ),
        const SizedBox(height: AnSpace.s6),
      ],
      if (ops.isNotEmpty) ...[
        _OpTicker(ops: ops, live: scene.live),
        const SizedBox(height: AnSpace.s6),
      ],
      if (code.isNotEmpty) ...[
        // ONE shell, two faces (A-020): live pins the SAME bounded viewport to the newest line; the
        // settle only un-pins — zero jump. Failed keeps the draft readable in the same shell.
        // 两脸一壳(A-020):live 同视口钉底,落定仅解除钉底、零跳变;失败残稿同壳可读。
        AnCodeEditor(code: code, lang: 'python', reading: true, live: scene.live, maxHeight: AnSize.codeViewport),
        if (!scene.live && !scene.failed) ...[
          const SizedBox(height: AnSpace.s6),
          Row(children: [
            if (oldCode.isNotEmpty) ...[
              _DiffBadge(before: oldCode, after: code),
              const SizedBox(width: AnSpace.s8),
            ],
            Expanded(child: runStatBarOf(context, scene.state)),
          ]),
        ],
      ],
      ..._signaturePills(context, c, session),
      if (!scene.live && !scene.failed && code.isEmpty) runStatBarOf(context, scene.state),
    ]);
  }

  // set_inputs / set_outputs / set_dependencies — closed values light up as pills (R-4 neutral live).
  // 签名药丸/依赖芯片:闭合即亮(live 中性)。
  List<Widget> _signaturePills(BuildContext context, AnColors c, dynamic session) {
    final chips = <Widget>[];
    for (final raw in session.arrayItemsAt(['ops'])) {
      if (raw is! Map) continue;
      switch (raw['op']) {
        case 'set_inputs' || 'set_outputs':
          final fields = raw[raw['op'] == 'set_inputs' ? 'inputs' : 'outputs'];
          if (fields is List) {
            for (final f in fields.whereType<Map>()) {
              final name = f['name'];
              if (name is String && name.isNotEmpty) {
                chips.add(AnChip('${raw['op'] == 'set_inputs' ? '→' : '←'} $name', tone: AnTone.none));
              }
            }
          }
        case 'set_dependencies':
          final deps = raw['dependencies'];
          if (deps is List) {
            for (final d in deps) {
              chips.add(AnChip('$d', tone: AnTone.none));
            }
          }
      }
    }
    if (chips.isEmpty) return const [];
    return [
      const SizedBox(height: AnSpace.s6),
      Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, children: chips),
    ];
  }
}

/// One neutral chip per completed op, in arrival order (R-4: live shows «已听写», never success).
/// op ticker:每闭合 op 一枚中性芯片(R-4:live 只示「已听写」,绝不演成功)。
class _OpTicker extends StatelessWidget {
  const _OpTicker({required this.ops, required this.live});

  final List<Object?> ops;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, children: [
      for (final raw in ops)
        if (raw is Map && raw['op'] is String)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6, vertical: AnSpace.s2),
            decoration: BoxDecoration(
              border: Border.all(color: c.line, width: AnSize.hairline),
              borderRadius: BorderRadius.circular(AnRadius.tag),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Neutral while live (outline dot); solid ok only after the settle. live 轮廓点;落定实心。
              Container(
                width: AnSize.dot - 2,
                height: AnSize.dot - 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: live ? null : c.ok,
                  border: live ? Border.all(color: c.inkFaint, width: AnSize.hairline) : null,
                ),
              ),
              const SizedBox(width: AnSpace.s4),
              Text('${raw['op']}', style: AnText.meta.copyWith(color: c.inkMuted)),
            ]),
          ),
    ]);
  }
}

/// The settle's honest «+n −m» — a REAL line diff of the fetched before vs the landed after (R-5's
/// fourth use). 落定 diff 徽:真 lineDiff(+n −m)。
class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.before, required this.after});

  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var add = 0, del = 0;
    for (final l in lineDiff(before, after)) {
      if (l.op == DiffOp.add) add++;
      if (l.op == DiffOp.del) del++;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('+$add', style: AnText.meta.copyWith(color: c.ok)),
      const SizedBox(width: AnSpace.s4),
      Text('−$del', style: AnText.meta.copyWith(color: c.danger)),
    ]);
  }
}
