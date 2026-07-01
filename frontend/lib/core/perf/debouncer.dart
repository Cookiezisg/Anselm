import 'dart:async';

/// A trailing-edge debouncer: [run] schedules a callback, and each new [run] before the delay elapses
/// cancels the pending one — only the last call within a quiet window fires. Used at input edges (rail
/// search boxes) so a keystroke storm collapses into ONE server hit. Owners must [dispose] it (cancels any
/// pending timer) in their own dispose. Guard side-effects with a `mounted` check inside the callback.
///
/// 尾沿防抖:run 排一个回调,延迟内再 run 取消前一个——安静窗口内只有最后一次触发。用于输入边(rail 搜索框),
/// 逐键风暴收敛成一次服务端请求。持有者须在自身 dispose 里 dispose 它(取消在途 timer);回调内自查 mounted。
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
