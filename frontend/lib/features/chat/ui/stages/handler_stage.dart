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
/// RunStatBar. NO match discriminant — the contract has none (勿设想).
///
/// handler 舞台(W5)——竖向生命周期轨上的方法架。add_method 上架书脊(名 w400+streaming 波浪+timeout 钟),
/// body 在小窗续长(W0 带路径通道让同名 body 各归其位);set_init/shutdown 点亮轨段;initArgsSchema 预览
/// 配置面(sensitive 恒 ••••)。落定:configState 徽+runtimeState 心跳+RunStatBar。无 match 判别式(契约如此)。
class HandlerStageBody extends ConsumerWidget {
  const HandlerStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;
    final editId = scene.editTargetId;
    final truth = editId == null ? null : ref.watch(handlerTruthProvider(editId));
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
          initCode = raw['code'] as String? ?? raw['body'] as String?;
        case 'set_shutdown':
          shutdownCode = raw['code'] as String? ?? raw['body'] as String?;
        case 'set_init_args_schema':
          final f = raw['schema'] ?? raw['fields'];
          if (f is List) schema = f;
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      _railSegment(context, c, 'init', lit: initCode != null),
      if (initCode != null)
        Padding(
          padding: const EdgeInsets.only(left: AnSpace.s12, bottom: AnSpace.s4),
          child: AnLiveCodeWindow(text: initCode, tailLines: 12),
        ),
      for (final m in methods) _spine(context, c, t, m),
      if (scene.live && liveBody != null && liveBody.isNotEmpty && methods.isEmpty)
        // A body streaming before its method op closes — honest small window. 方法未闭前的在途 body。
        Padding(
          padding: const EdgeInsets.only(left: AnSpace.s12, bottom: AnSpace.s4),
          child: AnLiveCodeWindow(text: liveBody, tailLines: 8),
        ),
      _railSegment(context, c, 'shutdown', lit: shutdownCode != null),
      if (shutdownCode != null)
        Padding(
          padding: const EdgeInsets.only(left: AnSpace.s12, bottom: AnSpace.s4),
          child: AnLiveCodeWindow(text: shutdownCode, tailLines: 12),
        ),
      if (schema.isNotEmpty) ...[
        const SizedBox(height: AnSpace.s4),
        Wrap(spacing: AnSpace.s4, runSpacing: AnSpace.s4, children: [
          for (final f in schema.whereType<Map>())
            AnBadge(
              f['sensitive'] == true ? '${f['name']} ••••' : '${f['name']}',
              tone: f['sensitive'] == true ? AnTone.warn : AnTone.none,
            ),
        ]),
      ],
      if (!scene.live && !scene.failed) ...[
        const SizedBox(height: AnSpace.s6),
        _settleStates(context, c, truth?.asData?.value),
        const SizedBox(height: AnSpace.s4),
        RunStatBar(state: scene.state),
      ],
    ]);
  }

  Widget _railSegment(BuildContext context, AnColors c, String label, {required bool lit}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AnSpace.s2),
        child: Row(children: [
          Container(
            width: AnSize.dot,
            height: AnSize.dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit ? c.accent : null,
              border: lit ? null : Border.all(color: c.line, width: AnSize.hairline),
            ),
          ),
          const SizedBox(width: AnSpace.s6),
          Text(label, style: AnText.meta.copyWith(color: lit ? c.inkMuted : c.inkFaint)),
        ]),
      );

  // One method spine: name w400 + the streaming wave + the timeout clock, its body in a live window
  // while the args stream (the in-flight channel keys by path). 方法书脊。
  Widget _spine(BuildContext context, AnColors c, Translations t, Map<Object?, Object?> m) {
    final name = '${m['name'] ?? ''}';
    final streaming = m['streaming'] == true;
    final timeout = m['timeout'];
    final body = m['body'] as String?;
    return Padding(
      padding: const EdgeInsets.only(left: AnSpace.s12, top: AnSpace.s2, bottom: AnSpace.s2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(name, style: AnText.label.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
          if (streaming) ...[
            const SizedBox(width: AnSpace.s4),
            Text('~', style: AnText.code.copyWith(color: c.accent)),
          ],
          if (timeout != null) ...[
            const SizedBox(width: AnSpace.s6),
            Text('⏱ $timeout', style: AnText.meta.copyWith(color: c.inkFaint)),
          ],
        ]),
        if (body != null && body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s2),
            child: scene.live
                ? AnLiveCodeWindow(text: '$body\n', tailLines: 8)
                : AnCodeEditor(code: body, lang: 'python', reading: true),
          ),
      ]),
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
    return Wrap(spacing: AnSpace.s6, children: [
      if (config != null)
        AnBadge(config == 'ready' ? t.chat.stage.cfgReady : t.chat.stage.cfgPending,
            tone: config == 'ready' ? AnTone.ok : AnTone.warn),
      if (runtime != null)
        AnBadge(rtLabel(runtime),
            tone: runtime == 'running'
                ? AnTone.ok
                : runtime == 'crashed'
                    ? AnTone.danger
                    : AnTone.none),
    ]);
  }
}
