import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Like [ValueListenableBuilder], but rebuilds ONLY when a SELECTED slice of the value changes — not on
/// every notification. [selector] maps the listenable's value to the slice that matters ([S] must have a
/// meaningful `==`); the widget rebuilds iff `selector(value) != last`. Use it to hang a subtree off a
/// coarse, high-frequency notifier (a whole-conversation transcript, an app-wide store) while paying a
/// rebuild only when the one thing this subtree cares about actually moved.
///
/// The [builder] still receives the FULL current value (so it can read whatever it renders); the selector
/// only gates WHEN it runs. If [listenable] or the selected value derived from a NEW [selector] changes
/// across a widget update (e.g. a reused element — same [key] — is handed a selector that now closes over
/// a different id), the baseline is re-derived in [didUpdateWidget] so the next notification compares
/// against the right value (no stale-skip).
///
/// 选择性 [ValueListenableBuilder]:仅当 [selector] 选出的切片变化才重建(非每次通知)。把子树挂到粗粒度高频
/// 通知器(整会话 transcript / 全局 store)上,只在本子树真正在意的东西变化时才付重建成本。[builder] 仍收完整
/// 当前值;[selector] 只决定「何时」跑。listenable 或(新 selector 派生的)选中值在 widget 更新间变化时,
/// didUpdateWidget 重算基线,避免陈旧漏建(如同 key 复用元素换了闭包捕获的 id)。
class ValueListenableSelector<T, S> extends StatefulWidget {
  const ValueListenableSelector({
    required this.listenable,
    required this.selector,
    required this.builder,
    super.key,
  });

  final ValueListenable<T> listenable;
  final S Function(T value) selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<ValueListenableSelector<T, S>> createState() =>
      _ValueListenableSelectorState<T, S>();
}

class _ValueListenableSelectorState<T, S>
    extends State<ValueListenableSelector<T, S>> {
  late S _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selector(widget.listenable.value);
    widget.listenable.addListener(_onNotify);
  }

  void _onNotify() {
    final next = widget.selector(widget.listenable.value);
    if (next != _selected) setState(() => _selected = next);
  }

  @override
  void didUpdateWidget(ValueListenableSelector<T, S> old) {
    super.didUpdateWidget(old);
    if (!identical(old.listenable, widget.listenable)) {
      old.listenable.removeListener(_onNotify);
      widget.listenable.addListener(_onNotify);
    }
    // Re-derive the baseline against the CURRENT selector — it may close over new inputs (a reused State
    // handed a new id), and a stale baseline could skip a needed rebuild. Cheap; no setState here (this
    // widget update already rebuilds). 用当前 selector 重算基线(闭包可能捕获新 id),避免漏建;不 setState。
    _selected = widget.selector(widget.listenable.value);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onNotify);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.listenable.value);
}
