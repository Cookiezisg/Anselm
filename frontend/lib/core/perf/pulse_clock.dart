import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../design/tokens.dart';

/// The SHARED phase source for every decorative pulse/breath loop (WRK-061 W0 §5-6): one Ticker drives
/// all of them, each consumer just wraps itself in its own RepaintBoundary and reads [value] (a 0→1
/// sawtooth over [period]). Without this, a busy transcript + right island grows one AnimationController
/// per breathing dot — dozens of independent tickers all waking the engine.
///
/// 静息降级 (idle degrade): the clock only runs while it has listeners AND something recently [poke]d it
/// (a new stream frame, user activity). Past [idleAfter] with no poke the ticker STOPS, the phase freezes
/// at 0 (consumers' defined static pose — a solid dot, no ring), and one final notification is sent. The
/// next poke restarts the loop from rest. Consumers must therefore design their t=0 frame as the static
/// fallback — the same pose reduced-motion renders permanently.
///
/// 全部脉冲/呼吸共享的单相位源:一个 Ticker 喂所有消费者(各自 RepaintBoundary,读 0→1 锯齿相位)。
/// 静息降级:有听众且 [idleAfter] 内被 [poke] 过才转;超时停 Ticker、相位冻回 0(=消费者的静态实心姿态,
/// 与 reduced-motion 的永久姿态同形)并广播最后一次;再次 poke 从头起搏。
class PulseClock extends ChangeNotifier implements ValueListenable<double> {
  PulseClock({this.period = AnMotion.breath, this.idleAfter = const Duration(seconds: 6)});

  /// The app-wide instance decorative loops share. Injectable in tests via constructors that take a
  /// [PulseClock]. 全应用共享实例;测试经构造注入。
  static final PulseClock shared = PulseClock();

  final Duration period;
  final Duration idleAfter;

  Ticker? _ticker;
  double _phase = 0;
  Duration _elapsed = Duration.zero; // since the current ticker start 本次起搏以来
  Duration _lastPoke = Duration.zero; // in the same clock 同一时基
  bool _pokedWhileStopped = false;

  @override
  double get value => _phase;

  /// True when the loop is degraded to the static pose (no ticker running). 已降级为静态姿态。
  bool get idle => !(_ticker?.isActive ?? false);

  /// Activity heartbeat — a new stream frame / user gesture. Restarts a stopped loop and pushes the
  /// idle deadline back. Cheap enough to call per frame-batch. 活动心跳:重启已停的环并顺延静息期限。
  void poke() {
    _lastPoke = _elapsed;
    if (idle) {
      _pokedWhileStopped = true;
      _maybeStart();
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _maybeStart();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop(toRest: false); // nobody watching — just stop 无人看即停
  }

  void _maybeStart() {
    if (!hasListeners || !(idle && _pokedWhileStopped)) return;
    _pokedWhileStopped = false;
    _elapsed = Duration.zero;
    _lastPoke = Duration.zero;
    _ticker ??= Ticker(_onTick, debugLabel: 'PulseClock');
    if (!_ticker!.isActive) _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    if (elapsed - _lastPoke > idleAfter) {
      _stop(toRest: true); // degrade: freeze at the static pose + one last notify 降级:冻回静态并广播一次
      return;
    }
    _phase = (elapsed.inMicroseconds % period.inMicroseconds) / period.inMicroseconds;
    notifyListeners();
  }

  void _stop({required bool toRest}) {
    _ticker?.stop();
    if (toRest && _phase != 0) {
      _phase = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}
