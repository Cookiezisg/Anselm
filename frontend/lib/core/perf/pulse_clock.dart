import 'dart:async';

import 'package:flutter/foundation.dart';

import '../design/tokens.dart';

/// The SHARED phase source for every decorative pulse/breath loop (WRK-061 W0 §5-6): one clock drives
/// all of them, each consumer just wraps itself in its own RepaintBoundary and reads [value] (a 0→1
/// sawtooth over [period]). Without this, a busy transcript + right island grows one AnimationController
/// per breathing dot — dozens of independent tickers all waking the engine.
///
/// The driver is a LOW-RATE periodic timer at [cadence] (~30fps), NOT a vsync Ticker — deliberately.
/// A live Ticker forces the engine to produce full frames at display rate even when nothing else
/// changes (T1/WRK-070: ONE breathing dot = 120fps = 24.92% CPU measured), and Flutter has no
/// frame-rate cap (flutter/flutter#159797); a ~2s breath stepped at 30fps is imperceptible. The
/// per-widget law «decorative loops ride vsync controllers so TickerMode stops them offscreen»
/// (AnTypewriter) is answered here by ACTIVITY gating instead: consumers only poke while live and
/// on-stage (they read TickerMode.of), and past [idleAfter] the timer stops dead.
///
/// 静息降级 (idle degrade): the clock only runs while it has listeners AND something recently [poke]d it
/// (a new stream frame, user activity). Past [idleAfter] with no poke the timer STOPS, the phase freezes
/// at 0 (consumers' defined static pose — a solid dot, no ring), and one final notification is sent. The
/// next poke restarts the loop from rest. Consumers must therefore design their t=0 frame as the static
/// fallback — the same pose reduced-motion renders permanently.
///
/// 全部脉冲/呼吸共享的单相位源:一个钟喂所有消费者(各自 RepaintBoundary,读 0→1 锯齿相位)。驱动器是
/// [cadence](~30fps)低频周期 timer、**刻意不用 vsync Ticker**——活 Ticker 会逼引擎按屏幕刷新率产整帧
/// (T1/WRK-070 实测:一个呼吸点=120fps=24.92% CPU),Flutter 无官方帧率上限;~2s 呼吸在 30fps 阶梯不可察。
/// 「装饰循环走 vsync 控制器以吃 TickerMode 离屏自停」(AnTypewriter 法)在此由**活动门控**接管:消费者
/// 只在活着且在台上(读 TickerMode.of)时 poke,超 [idleAfter] timer 死停。
/// 静息降级:有听众且 [idleAfter] 内被 [poke] 过才转;超时停 timer、相位冻回 0(=消费者的静态实心姿态,
/// 与 reduced-motion 的永久姿态同形)并广播最后一次;再次 poke 从头起搏。
class PulseClock extends ChangeNotifier implements ValueListenable<double> {
  PulseClock({
    this.period = AnMotion.breath,
    this.idleAfter = const Duration(seconds: 6),
    this.cadence = AnMotion.pulseCadence,
  });

  /// The app-wide instance decorative loops share. Injectable in tests via constructors that take a
  /// [PulseClock]. 全应用共享实例;测试经构造注入。
  static final PulseClock shared = PulseClock();

  final Duration period;
  final Duration idleAfter;

  /// Repaint cadence while running — the timer interval, i.e. how often listeners are notified.
  /// 运转期重绘节拍——timer 间隔,即听众被通知的频率。
  final Duration cadence;

  Timer? _timer;
  double _phase = 0;
  Duration _elapsed = Duration
      .zero; // accumulated from fired ticks (fake-async deterministic) 由已触发节拍累加(fake-async 确定)
  Duration _lastPoke = Duration.zero; // in the same clock 同一时基
  bool _pokedWhileStopped = false;

  @override
  double get value => _phase;

  /// True when the loop is degraded to the static pose (no timer running). 已降级为静态姿态。
  bool get idle => _timer == null;

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
    if (!hasListeners) {
      _stop(toRest: false); // nobody watching — just stop 无人看即停
    }
  }

  void _maybeStart() {
    if (!hasListeners || !(idle && _pokedWhileStopped)) return;
    _pokedWhileStopped = false;
    _elapsed = Duration.zero;
    _lastPoke = Duration.zero;
    _phase =
        0; // restart from rest — never resume a stale mid-breath phase 从静止起搏,不续陈旧半相
    _timer = Timer.periodic(cadence, _onTick);
  }

  void _onTick(Timer _) {
    _elapsed += cadence;
    if (_elapsed - _lastPoke > idleAfter) {
      _stop(
        toRest: true,
      ); // degrade: freeze at the static pose + one last notify 降级:冻回静态并广播一次
      return;
    }
    _phase =
        (_elapsed.inMicroseconds % period.inMicroseconds) /
        period.inMicroseconds;
    notifyListeners();
  }

  void _stop({required bool toRest}) {
    _timer?.cancel();
    _timer = null;
    if (toRest && _phase != 0) {
      _phase = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
