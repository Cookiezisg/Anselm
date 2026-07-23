import 'dart:async';

import 'package:flutter/foundation.dart';

/// The app's ONE relative-time heartbeat — a half-minute ChangeNotifier every «2h ago» / «in 3m» /
/// «running · 1m» text listens to (C-track law: never a per-row ticker; 判官3: minute-granular labels
/// never jitter second-by-second). The timer runs only while listeners exist. 全 app 唯一相对时间
/// 心跳:半分钟脉搏,有听众才走针。
class AnTimePulse extends ChangeNotifier {
  AnTimePulse._();

  static final AnTimePulse instance = AnTimePulse._();

  /// "Now" quantized to the pulse's own half-minute beat — what a rebuild should pass into an
  /// equality-memoized model (S8): a raw DateTime.now() differs on EVERY build and busts the memo,
  /// while two rebuilds inside one beat receive the same instant (labels are minute-granular anyway,
  /// 判官3). 量化到心跳半分钟拍的「现在」——相等性记忆化模型该收的值(S8):裸 now 每 build 皆异、
  /// 必破记忆;同拍内的重建收到同一时刻(标签本就分钟粒度)。
  static DateTime get quantizedNow {
    final now = DateTime.now();
    return now.subtract(
      Duration(
        seconds: now.second % 30,
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      ),
    );
  }

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
