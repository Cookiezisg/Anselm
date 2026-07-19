import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app window is FOCUSED — the toast dispatcher reads this at dispatch time to route an
/// important event to an in-app toast (focused) vs an OS-native notification (not focused; the user is
/// looking elsewhere). Driven by [AppLifecycleState] (resumed = focused). Defaults to focused (true) so a
/// null/unknown lifecycle at startup shows the in-app toast rather than firing an off-screen OS one.
///
/// app 窗口是否**聚焦**——toast 派发器在派发时读它,把重要事件路由到 in-app toast(聚焦)或 OS 原生通知
/// (未聚焦、用户在看别处)。由 AppLifecycleState 驱动(resumed=聚焦)。默认聚焦(true),启动时 null/未知不误发 OS。
class AppFocus extends Notifier<bool> {
  _LifecycleObserver? _observer;

  @override
  bool build() {
    final obs = _LifecycleObserver((focused) {
      if (state != focused) state = focused;
    });
    WidgetsBinding.instance.addObserver(obs);
    _observer = obs;
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(obs));
    final st = WidgetsBinding.instance.lifecycleState;
    return st == null || st == AppLifecycleState.resumed;
  }

  /// Test seam: drive the focus state as if the OS reported a lifecycle change. 测试缝:模拟 OS 生命周期。
  @visibleForTesting
  void debugSetLifecycle(AppLifecycleState value) => _observer?.didChangeAppLifecycleState(value);
}

/// A plain [WidgetsBindingObserver] that reports focus (resumed = focused) — kept OFF the Notifier so its
/// `state` parameter never shadows [Notifier.state]. 独立 observer(避免 state 参数遮蔽 Notifier.state)。
class _LifecycleObserver with WidgetsBindingObserver {
  _LifecycleObserver(this.onFocus);
  final void Function(bool focused) onFocus;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      onFocus(state == AppLifecycleState.resumed);
}

/// True while the window is focused/resumed. 窗口聚焦时为真。
final appFocusedProvider = NotifierProvider<AppFocus, bool>(AppFocus.new);
