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

/// The HANDLER stage (WRK-061 §7-2, W5) — the method rack on a vertical lifecycle rail
/// (init ▸ methods ▸ shutdown). `add_method` slots a SPINE onto the rack (name w400 + a streaming
/// wave mark + the timeout clock word) whose body grows in a small live window — the W0 engine's
/// path-aware channel keeps同名 `body` values apart, so each spine follows ITS OWN code. set_init /
/// set_shutdown light their rail段 with a live window; set_init_args_schema previews the config form
/// (sensitive keys ALWAYS masked ••••). Settle: configState badge + runtimeState heartbeat +
/// the result bar. NO match discriminant — the contract has none (勿设想).
///
/// handler 舞台(W5)——竖向生命周期轨上的方法架。add_method 上架书脊(名 w400+streaming 波浪+timeout 钟),
/// body 在小窗续长(W0 带路径通道让同名 body 各归其位);set_init/shutdown 点亮轨段;initArgsSchema 预览
/// 配置面(sensitive 恒 ••••)。落定:configState 徽+runtimeState 心跳+结果条(runStatBarOf)。无 match 判别式(契约如此)。
class HandlerStageBody extends ConsumerWidget {
  const HandlerStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final editId = scene.editTargetId;
    final truth = editId == null
        ? null
        : ref.watch(handlerTruthProvider(editId));
    final ops = session.arrayItemsAt(['ops']);

    // The newest still-growing body follows the in-flight channel (path-aware). 在途 body 跟当前书脊。
    final liveBody = scene.live ? session.liveStringNamed('body') : null;

    final methods = <Map<Object?, Object?>>[];
    String? initCode;
    String? shutdownCode;
    List<Object?> schema = const [];
    for (final raw in ops) {
      if (raw is! Map) continue;
      switch (raw['op']) {
        case 'add_method' || 'update_method':
          final m = raw['method'];
          if (m is Map) methods.add(m);
        case 'set_init':
          // REAL wire key first (`initBody`, backend apply.go); code/body kept as legacy fallbacks.
          // 真线缆键 initBody 优先;code/body 兜历史。
          initCode =
              raw['initBody'] as String? ??
              raw['code'] as String? ??
              raw['body'] as String?;
        case 'set_shutdown':
          shutdownCode =
              raw['shutdownBody'] as String? ??
              raw['code'] as String? ??
              raw['body'] as String?;
        case 'set_init_args_schema':
          final f = raw['schema'] ?? raw['fields'];
          if (f is List) schema = f;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _railSegment(context, c, 'init', lit: initCode != null),
        if (initCode != null)
          Padding(
            // 假想框律:代码窗(真框)满宽贴 X=0,绝不二次缩进(与 function_stage 同原语同摆法);轨层级由
            // 上方 dot+名 沟行自己表达。The imaginary-frame law: the code editor (a real frame) fills the
            // body width at X=0 — no s12 indent; the rail hierarchy reads from the dot+name gutter row above.
            padding: const EdgeInsets.only(bottom: AnSpace.s4),
            // Settle → the reading editor (whole code), matching the method spines; live → the tail window.
            // 落定=reading 编辑器(整段,与方法书脊一致);活=尾窗。
            child: scene.live
                ? AnCodeEditor(
                    code: initCode,
                    lang: 'python',
                    reading: true,
                    live: true,
                    maxHeight: AnSize.codeViewportSm,
                  )
                : AnCodeEditor(
                    code: initCode,
                    lang: 'python',
                    reading: true,
                    maxHeight: AnSize.codeViewportSm,
                  ),
          ),
        for (final m in methods) _spine(context, c, t, m),
        if (scene.live &&
            liveBody != null &&
            liveBody.isNotEmpty &&
            methods.isEmpty)
          // A body streaming before its method op closes — honest small viewport. 方法未闭前的在途 body。
          Padding(
            // 假想框律:代码窗满宽贴 X=0。The imaginary-frame law: the code editor fills the body width at X=0.
            padding: const EdgeInsets.only(bottom: AnSpace.s4),
            child: AnCodeEditor(
              code: liveBody,
              lang: 'python',
              reading: true,
              live: true,
              maxHeight: AnSize.codeViewportSm,
            ),
          ),
        _railSegment(context, c, 'shutdown', lit: shutdownCode != null),
        if (shutdownCode != null)
          Padding(
            // 假想框律:代码窗满宽贴 X=0。The imaginary-frame law: the code editor fills the body width at X=0.
            padding: const EdgeInsets.only(bottom: AnSpace.s4),
            child: scene.live
                ? AnCodeEditor(
                    code: shutdownCode,
                    lang: 'python',
                    reading: true,
                    live: true,
                    maxHeight: AnSize.codeViewportSm,
                  )
                : AnCodeEditor(
                    code: shutdownCode,
                    lang: 'python',
                    reading: true,
                    maxHeight: AnSize.codeViewportSm,
                  ),
          ),
        if (schema.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s4),
          Wrap(
            spacing: AnSpace.s4,
            runSpacing: AnSpace.s4,
            children: [
              for (final f in schema.whereType<Map>())
                AnChip(
                  f['sensitive'] == true ? '${f['name']} ••••' : '${f['name']}',
                  tone: f['sensitive'] == true ? AnTone.warn : AnTone.none,
                ),
            ],
          ),
        ],
        if (!scene.live && !scene.failed) ...[
          const SizedBox(height: AnSpace.s6),
          _settleStates(context, c, truth?.asData?.value),
          const SizedBox(height: AnSpace.s4),
          runStatBarOf(context, scene.state),
        ],
      ],
    );
  }

  Widget _railSegment(
    BuildContext context,
    AnColors c,
    String label, {
    required bool lit,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
    child: Row(
      children: [
        lit ? AnStatusDot.raw(c.accent) : AnStatusDot.raw(c.line, hollow: true),
        const SizedBox(width: AnSpace.s6),
        Text(
          label,
          style: AnText.meta.copyWith(color: lit ? c.inkMuted : c.inkFaint),
        ),
      ],
    ),
  );

  // One method spine: name w400 + the streaming wave + the timeout clock, its body in a live window
  // while the args stream (the in-flight channel keys by path). 方法书脊。
  Widget _spine(
    BuildContext context,
    AnColors c,
    Translations t,
    Map<Object?, Object?> m,
  ) {
    final name = '${m['name'] ?? ''}';
    final streaming = m['streaming'] == true;
    final timeout = m['timeout'];
    final body = m['body'] as String?;
    return Padding(
      // 假想框律:方法脊不再 s12 缩进——层级由「dot+名」沟行自己表达,与 init/shutdown 轨段同沟(同尺寸
      // dot 于同起点自然对齐,无需定宽格);代码窗满宽贴 X=0。The imaginary-frame law: the spine no longer
      // indents; a dot+name row (same lead as init/shutdown, uniform dots align at the same start) carries
      // the rail hierarchy, and its code editor fills the body width at X=0.
      padding: const EdgeInsets.only(top: AnSpace.s2, bottom: AnSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnStatusDot.raw(c.accent),
              const SizedBox(width: AnSpace.s6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.label
                      .weight(AnText.emphasisWeight)
                      .copyWith(color: c.ink),
                ),
              ),
              if (streaming) ...[
                const SizedBox(width: AnSpace.s4),
                Icon(AnIcons.activity, size: AnSize.iconXs, color: c.accent),
              ],
              if (timeout != null) ...[
                const SizedBox(width: AnSpace.s6),
                Icon(
                  AnIcons.timeout,
                  size: AnSize.iconSm,
                  color: c.inkFaint,
                  semanticLabel: context.t.a11y.timeoutBudget,
                ),
                const SizedBox(width: AnSpace.s4),
                Text(
                  '$timeout',
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ],
            ],
          ),
          if (body != null && body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s2),
              child: scene.live
                  ? AnCodeEditor(
                      code: body,
                      lang: 'python',
                      reading: true,
                      live: true,
                      maxHeight: AnSize.codeViewportSm,
                    )
                  : AnCodeEditor(
                      code: body,
                      lang: 'python',
                      reading: true,
                      maxHeight: AnSize.codeViewportSm,
                    ),
            ),
        ],
      ),
    );
  }

  Widget _settleStates(BuildContext context, AnColors c, dynamic handler) {
    if (handler == null) return const SizedBox.shrink();
    final t = context.t;
    final config = handler.configState as String?;
    final runtime = handler.runtimeState as String?;
    String rtLabel(String s) => switch (s) {
      'running' => t.chat.stage.rtRunning,
      'crashed' => t.chat.stage.rtCrashed,
      'stopped' => t.chat.stage.rtStopped,
      _ => s,
    };
    return Wrap(
      spacing: AnSpace.s6,
      children: [
        if (config != null)
          AnChip(
            config == 'ready' ? t.chat.stage.cfgReady : t.chat.stage.cfgPending,
            tone: config == 'ready' ? AnTone.ok : AnTone.warn,
          ),
        if (runtime != null)
          AnChip(
            rtLabel(runtime),
            tone: runtime == 'running'
                ? AnTone.ok
                : runtime == 'crashed'
                ? AnTone.danger
                : AnTone.none,
          ),
      ],
    );
  }
}
