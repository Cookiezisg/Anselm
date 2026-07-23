import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'an_deferred_loading.dart';

/// Renders an [AsyncValue] by the LAST-KNOWN-GOOD strategy — the house answer to loading flicker.
/// A bare `.when(loading: skeleton)` throws away data it is already holding: every invalidate /
/// SSE resync / selection switch collapses good content into a skeleton for the few ms a local
/// sidecar needs, which reads as "flashing". This widget never shows a loading state while it has
/// ANYTHING better to show:
///
/// 1. value has data (incl. loading-with-previous — a refresh/reload of the SAME provider) → content;
/// 2. value is purely loading but a previous build had data (a NEW family instance after a selection
///    switch — riverpod's previous can't cross instances) → the snapshot, held up to
///    [AnMotion.staleHold], then the placeholder (a genuinely slow load must read as loading);
/// 3. nothing to hold → the placeholder behind [AnDeferredLoading] (sub-threshold loads never flash);
/// 4. errors always win (even with old data in hand) — silent staleness would hide real failures.
///
/// Content SURFACES with a one-shot [AnMotion.contentIn] fade on (re)mount; data updates within
/// mounted content swap in place, no animation (fast beats fancy). [resetKey] declares a HARD
/// generation boundary (workspace switch, a different entity feeding sub-resource tabs): when it
/// changes the snapshot is dropped AND carried-over previous values are distrusted until the value
/// settles once — held-over content from another generation is data corruption, not smoothness.
///
/// 以 last-known-good 策略渲 AsyncValue——闪烁问题的房规答案。裸 `.when(loading: 骨架)` 会丢掉手里
/// 攥着的数据:每次 invalidate/SSE resync/切选区,好内容都塌成骨架闪几十毫秒。本件手里有更好的东西
/// 就绝不渲加载态:①值有数据(含同 provider refresh/reload 的 loading-with-previous)→内容;②纯
/// loading 但上一轮有过数据(切选区后的新 family 实例,riverpod previous 跨不过实例)→快照顶替,顶
/// 至 [AnMotion.staleHold] 后转占位(真慢必须像在加载);③无可顶→占位经 [AnDeferredLoading](亚阈
/// 值加载永不闪);④错误恒优先(有旧值也显)——静默陈旧会藏真故障。内容(重)挂载时一次性
/// [AnMotion.contentIn] 淡入浮现;已挂载内容的数据更新原地换、零动画(快就是丝滑)。[resetKey] 声明
/// 硬换代边界(workspace 切换 / 子资源 tab 换实体):变化即弃快照,且不再信任跨代 previous,直到值
/// 落定一次——渲上一代的内容是串数据,不是丝滑。
class AnLastGood<T> extends StatefulWidget {
  const AnLastGood({
    required this.value,
    required this.builder,
    required this.placeholder,
    required this.errorBuilder,
    this.resetKey,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;

  /// The bare skeleton — deferral timing is owned here, do NOT pre-wrap in [AnDeferredLoading].
  /// 裸骨架——延迟时机归本件管,勿再套 AnDeferredLoading。
  final Widget placeholder;

  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  )
  errorBuilder;

  /// Hard generation boundary — see class doc. 硬换代边界,见类注释。
  final Object? resetKey;

  @override
  State<AnLastGood<T>> createState() => _AnLastGoodState<T>();
}

class _AnLastGoodState<T> extends State<AnLastGood<T>> {
  // Record box, not `T?` — a nullable T could legitimately snapshot `null`. 记录盒而非 T?:T 可空时
  // null 也是合法快照。
  (T,)? _snap;
  bool _awaitFresh = false;
  bool _staleExpired = false;
  Timer? _staleTimer;

  @override
  void didUpdateWidget(AnLastGood<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey) {
      _snap = null;
      _awaitFresh = true;
      _staleExpired = false;
      _cancelStale();
    }
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    super.dispose();
  }

  void _cancelStale() {
    _staleTimer?.cancel();
    _staleTimer = null;
  }

  void _armStale() {
    _staleTimer ??= Timer(AnMotion.staleHold, () {
      if (mounted) setState(() => _staleExpired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    // A settled emission (data OR error, not loading) ends the reset generation — from here on the
    // value IS the new generation's truth. 一次落定(数据或错误)即结束换代等待——此后值即新代真相。
    if (!v.isLoading) _awaitFresh = false;

    if (!_awaitFresh && v.hasError) {
      _cancelStale();
      return widget.errorBuilder(
        context,
        v.error!,
        v.stackTrace ?? StackTrace.empty,
      );
    }
    if (!_awaitFresh && v.hasValue) {
      _snap = (v.requireValue,);
      _cancelStale();
      _staleExpired = false;
      return _FadeIn(child: widget.builder(context, v.requireValue));
    }

    final snap = _snap;
    if (snap != null && !_staleExpired) {
      _armStale();
      return _FadeIn(child: widget.builder(context, snap.$1));
    }
    // After an expired hold the user already waited staleHold — show the skeleton NOW, not after
    // another deferral. 顶替超时后已等足 staleHold——骨架直显,不再二次延迟。
    return _staleExpired
        ? widget.placeholder
        : AnDeferredLoading(child: widget.placeholder);
  }
}

/// One-shot mount fade — content surfaces instead of popping in. Replays only on (re)mount
/// (placeholder→content), never on in-place data updates (same element, live State). Honors
/// reduce-motion. 一次性挂载淡入:仅(重)挂载时播,原地数据更新不重播;尊重减少动效。
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AnMotionPref.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AnMotion.contentIn,
      curve: AnMotion.easeOut,
      child: child,
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child!),
    );
  }
}
