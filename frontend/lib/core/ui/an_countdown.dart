import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../model/status_state.dart';
import 'tone.dart';
import '../model/time_format.dart';
import '../../i18n/strings.g.dart';

// AnCountdown (WRK-069 S0) — a deadline's relative countdown text («剩 2h» / overdue), minute-granular.
// ALL instances share ONE app-level Timer (the C-track law: never a per-row ticker — an inbox of 20
// gates must not run 20 timers), started when the first countdown mounts and cancelled when the last
// unmounts. Granularity is 30s (a minute-precise label needs at most half-minute refresh), so text
// never jitters second-by-second (判官3「毛躁」裁定 — same rule as the rail's running-elapsed meta).
// AnCountdown 截止倒计时:全实例共享单顶层 Timer(C 轨铁律:绝不逐行 ticker),首挂载启动/末卸载取消;
// 30s 粒度(分钟精度文案至多半分钟刷新),永不逐秒跳字。

/// The shared half-minute pulse behind every [AnCountdown]. 全体倒计时共享的半分钟脉搏。
class _CountdownPulse extends ChangeNotifier {
  _CountdownPulse._();

  static final _CountdownPulse instance = _CountdownPulse._();

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// A deadline countdown — «⏳ 2h left» while the deadline is ahead, the overdue word (danger ink) once
/// it passes. [tone] colours the pending face (defaults to the waiting amber — the inbox use). Minute
/// granularity via [fmtWaited]. 截止倒计时:未到=「剩 x」(默认琥珀),已过=「已超时」(红)。
class AnCountdown extends StatefulWidget {
  const AnCountdown({required this.deadline, this.tone = AnTone.warn, super.key});

  final DateTime deadline;

  /// The pending-face tone; overdue always speaks danger. 未到期的语气;超时恒 danger。
  final AnTone tone;

  @override
  State<AnCountdown> createState() => _AnCountdownState();
}

class _AnCountdownState extends State<AnCountdown> {
  @override
  void initState() {
    super.initState();
    _CountdownPulse.instance.addListener(_onPulse);
  }

  @override
  void dispose() {
    _CountdownPulse.instance.removeListener(_onPulse);
    super.dispose();
  }

  void _onPulse() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final remaining = widget.deadline.difference(DateTime.now());
    final overdue = remaining.isNegative;
    final text = overdue ? t.run.countdownOverdue : t.run.countdownLeft(d: fmtWaited(remaining));
    final color = overdue ? c.danger : widget.tone.fg(c);
    return Text(text, style: AnText.meta.copyWith(color: color));
  }
}
