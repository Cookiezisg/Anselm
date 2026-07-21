import 'dart:async';

import 'package:flutter/foundation.dart';

/// The app's ONE relative-time heartbeat — a half-minute ChangeNotifier every «2h ago» / «in 3m» /
/// «running · 1m» text listens to (C-track law: never a per-row ticker; 判官3: minute-granular labels
/// never jitter second-by-second). The timer runs only while listeners exist. 全 app 唯一相对时间
/// 心跳:半分钟脉搏,有听众才走针。
class AnTimePulse extends ChangeNotifier {
  AnTimePulse._();

  static final AnTimePulse instance = AnTimePulse._();

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => notifyListeners(),
    );
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
