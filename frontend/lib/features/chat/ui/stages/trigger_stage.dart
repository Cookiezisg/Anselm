import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/entities/trigger.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/stage_truth.dart';
import '../tool_card_skins.dart';
import '../tool_card_trigger.dart';
import 'stage_frame.dart';
import 'stage_scene.dart';

/// The TRIGGER stage (WRK-061 §7-5, W3) — the sentry post: the first closed key (`kind`) swaps in
/// the right FACE (cron / webhook / fsnotify / sensor — the B2 [triggerConfigFaces] reused verbatim
/// and rendering the sensor CELs itself; the old extra AnCelGrow encore double-printed them, G10/
/// A3-24), and while the receipt is pending an [AnRadarSweep] spins — honest waiting, never
/// fabricated progress. Settle reconciles from GET (R-16: listening / nextFireAt / refCount come
/// from the truth, never from frames): the listening dot, the next-fire countdown word (FUTURE-
/// oriented — the past formatter read every future instant as «刚刚», A3-22), the reference count.
///
/// trigger 舞台(W3)——哨位:首个闭合键 kind 换上对应脸(四脸逐字复用 B2,sensor 的 CEL 由脸自渲——
/// 旧 AnCelGrow 加演把同一表达式印两份,G10/A3-24),等回执期 AnRadarSweep 转(诚实等待)。落定按
/// GET 对账(R-16):监听点+下次点火**未来向**人话(旧过去向格式器对未来恒「刚刚」)+引用数。
class TriggerStageBody extends ConsumerWidget {
  const TriggerStageBody({required this.scene, super.key});

  final StageScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Translations.of(context);
    final session = scene.session;

    var kind = session.closedStringAt(['kind']) ?? '';
    final config = _closedObject(session, 'config');
    final resultId = _resultId();

    // R-16: the settle facts come from the reconciled GET only. A LIVE edit also fetches the truth
    // — for its FACE: edit_trigger's schema has NO `kind` (immutable, backend trigger/build.go), so
    // the old args-only read left the whole edit faceless behind a radar (G8/A3-23); R-5 says an
    // edit stages with the OLD truth anyway. 落定事实只从 GET;live 编辑同样取真相**换脸**——edit 的
    // schema 无 kind(不可变),旧读法让整场编辑只剩雷达无脸;R-5 本就要求编辑登台带旧真相。
    final truthId = resultId ?? scene.editTargetId;
    final truth = (truthId != null && (!scene.live || kind.isEmpty))
        ? ref.watch(triggerTruthProvider(truthId))
        : null;
    final trig = truth?.asData?.value;
    if (kind.isEmpty && trig != null && trig.kind != TriggerSource.unknown) {
      kind = trig.kind.name;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 假想框律:一切裸内容(spec 面/带点行/CEL/等待行)归假想框(X=8);runStatBar 是当家条真框、贴 X=0。
        // The imaginary-frame law: every bare block (the spec face, dotted rows, CELs, waiting rows) joins the
        // frame (X=8); only the result bar (a real frame) stays flush at X=0.
        if (kind.isEmpty && scene.live)
          stageFramed(
            Row(
              children: [
                AnRadarSweep(size: AnSize.iconSm.toDouble()),
                const SizedBox(width: AnSpace.s6),
                Text(
                  t.chat.stage.awaitingReceipt,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          )
        else if (kind.isNotEmpty) ...[
          stageFramed(triggerConfigFaces(context, kind, config, truthId ?? '')),
        ],
        if (scene.live && kind.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s6),
          stageFramed(
            Row(
              children: [
                AnRadarSweep(size: AnSize.iconSm.toDouble()),
                const SizedBox(width: AnSpace.s6),
                Text(
                  t.chat.stage.awaitingReceipt,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          ),
        ],
        if (!scene.live && !scene.failed) ...[
          const SizedBox(height: AnSpace.s6),
          if (trig != null)
            stageFramed(
              Wrap(
                spacing: AnSpace.s8,
                runSpacing: AnSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnStatusDot.raw(trig.listening ? c.ok : c.inkFaint),
                      const SizedBox(width: AnSpace.s4),
                      Text(
                        trig.listening
                            ? t.chat.stage.listening
                            : t.chat.stage.notListening,
                        style: AnText.meta.copyWith(
                          color: trig.listening ? c.ok : c.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  if (trig.nextFireAt != null) _LiveClock(at: trig.nextFireAt!),
                  if (trig.refCount > 0)
                    Text(
                      t.chat.stage.refCountWord(n: trig.refCount),
                      style: AnText.meta.copyWith(color: c.inkFaint),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AnSpace.s4),
          runStatBarOf(context, scene.state),
        ],
      ],
    );
  }

  // The config object's CLOSED keys so far (progressive while streaming). 已闭合的 config 键(流中渐进)。
  Map<String, Object?> _closedObject(dynamic session, String key) {
    final out = <String, Object?>{};
    for (final e in session.events) {
      final path = e.path as List<Object>;
      if (path.length == 2 && path.first == key && path.last is String) {
        out[path.last as String] = e.value;
      } else if (path.length == 1 && path.first == key && e.value is Map) {
        for (final me in (e.value as Map).entries) {
          out['${me.key}'] = me.value;
        }
      }
    }
    return out;
  }

  String? _resultId() {
    final r = scene.state.resultText;
    final m = RegExp(r'"id"\s*:\s*"(trg_\w+)"').firstMatch(r);
    return m?.group(1);
  }
}

/// The next-fire clock, honest by the minute: the settle face is static, but «in 3 minutes» must
/// not still read «in 3 minutes» five minutes later — a quiet per-minute re-render, no animation.
/// 下次点火钟,按分钟诚实:落定面是静态的,但「3 分钟后」不能五分钟后还写着 3 分钟——每分钟安静重渲,无动画。
class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.at});

  final DateTime at;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// FUTURE-oriented clock word (G10/A3-22): [AnCastRow.timeLabel] is past-oriented — a future
  /// instant computed negative minutes and read «刚刚» forever, making the per-minute re-render
  /// meaningless. 未来向时钟词:过去向格式器对未来算出负分钟、恒「刚刚」,分钟重渲全白做。
  String _word(BuildContext context) {
    final t = Translations.of(context);
    final now = DateTime.now();
    final local = widget.at.toLocal();
    final mins = local.difference(now).inMinutes;
    if (mins < 1) return t.chat.time.soon;
    if (mins < 60) return t.chat.time.inMinutes(n: mins);
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(local.hour)}:${two(local.minute)}';
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return sameDay ? hm : '${local.month}/${local.day} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    return Text(
      t.chat.stage.nextFire(t: _word(context)),
      style: AnText.meta.copyWith(color: c.inkMuted),
    );
  }
}
