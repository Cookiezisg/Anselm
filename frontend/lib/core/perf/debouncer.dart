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
  void Function()?
  _pending; // the last-scheduled action, kept so [flush] can still run it 最后排的动作

  void run(void Function() action) {
    _pending = action;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _pending = null;
      action();
    });
  }

  /// Fire the pending action NOW (if the quiet window hasn't elapsed) and cancel the timer. Owners whose
  /// debounced action has a SIDE EFFECT THAT MUST NOT BE LOST — an autosave above all — call this in their
  /// dispose so switching away within the debounce window still persists the last edit (else the pending
  /// timer is simply cancelled and the edit is dropped). `mounted` is still true during dispose(), so a
  /// callback guarded by it runs. 立即触发在途动作 + 停表:持有者(尤其自动保存)在 dispose 调用它,避免
  /// 防抖窗口内切走丢掉最后一次编辑(否则 timer 被取消、编辑丢失)。dispose() 期 mounted 仍 true,回调会跑。
  void flush() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    pending?.call();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
