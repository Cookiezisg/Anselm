import 'dart:async';

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';

/// Shows [child] (a loading skeleton / spinner) ONLY after [delay] has elapsed — the anti-flash pattern.
/// A sub-threshold async (the common case against a local sidecar: a few ms) resolves before the delay,
/// so its parent leaves the loading branch and this widget is disposed → the timer is cancelled →
/// nothing was ever shown (no appear-then-instantly-vanish flicker). Only a genuinely slow load (> delay)
/// surfaces the indicator, by which point it's wanted. Until then it occupies zero space.
///
/// 仅在 [delay] 后才显 [child](加载骨架/转圈)——防闪烁。亚阈值异步(本地 sidecar 常态,数毫秒)在延迟前
/// 返回 → 父离开 loading 分支、本 widget 被弃 → timer 取消 → 从未显示(无"闪现即消失");仅真慢加载(> delay)
/// 才浮出指示器,此时也确实需要。延迟内占零空间。
class AnDeferredLoading extends StatefulWidget {
  const AnDeferredLoading({
    required this.child,
    this.delay = AnMotion.loaderDelay,
    this.onShown,
    super.key,
  });

  final Widget child;
  final Duration delay;

  /// Fired the moment the indicator actually SURFACES (the delay elapsed while still loading) —
  /// lets an owner (e.g. AnLastGood) start its minimum-display clock from the true first visible
  /// frame. 指示器真正亮出的瞬间回调——让宿主(如 AnLastGood)从真实首帧起算最短停留钟。
  final VoidCallback? onShown;

  @override
  State<AnDeferredLoading> createState() => _AnDeferredLoadingState();
}

class _AnDeferredLoadingState extends State<AnDeferredLoading> {
  bool _show = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _show = true);
      widget.onShown?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _show ? widget.child : const SizedBox.shrink();
}
