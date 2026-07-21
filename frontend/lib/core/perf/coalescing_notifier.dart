import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// L2 of the streaming-render playbook (WRK-045 §5 / perf research wlup4cbx4): a [ValueListenable] whose
/// value updates SYNCHRONOUSLY + losslessly, but whose listeners are notified AT MOST ONCE PER FRAME.
///
/// The streaming firehose (chat token deltas, flowrun node ticks — hundreds/sec) is the perf trap the
/// user flagged: notifying once per delta repaints the leaf hundreds of times/sec. Here every [mutate]
/// applies immediately to the accumulator (nothing is dropped — safe because these are ephemeral seq=0
/// frames and the DB row is the truth), but the rebuild it drives is coalesced to the next frame. A leaf
/// that watches this via `ValueListenableBuilder` therefore repaints ≤1×/frame (60fps ceiling) no matter
/// the delta rate. Combined with L0 (gateway demux: a leaf only receives ITS frames) + L3–L6 (family
/// providers / select / RepaintBoundary, feature-time), an SSE frame repaints only the changing leaf.
///
/// PAIR WITH THE EPHEMERAL PATH ONLY. Durable (seq>0) frames patch the typed Riverpod cache directly +
/// advance the resume cursor and must NEVER be coalesced or dropped (see [StreamEnvelope.durable]).
///
/// L2 流式渲染合并原语:值同步无损更新、监听者每帧最多通知一次。firehose(token/tick 数百每秒)下每次
/// mutate 立刻应用进累加器(不丢——ephemeral seq=0、DB 行才是真相),但触发的重建合并到下一帧;叶子经
/// ValueListenableBuilder 每帧最多重画一次。只配 ephemeral 路径;durable(seq>0)直接 patch 缓存+进游标,
/// 绝不合并/丢弃。
class CoalescingNotifier<T> extends ChangeNotifier
    implements ValueListenable<T> {
  CoalescingNotifier(this._value, {SchedulerBinding? scheduler})
    : _scheduler = scheduler ?? SchedulerBinding.instance;

  T _value;
  final SchedulerBinding _scheduler;
  bool _flushScheduled = false;
  bool _disposed = false;

  @override
  T get value => _value;

  /// Apply [reducer] to the accumulator NOW (synchronous + lossless), then schedule a SINGLE coalesced
  /// notify for the next frame. Many calls in one batch ⇒ one rebuild. 立刻无损应用;合并到下一帧通知一次。
  void mutate(T Function(T current) reducer) {
    if (_disposed) return;
    _value = reducer(_value);
    if (_flushScheduled) return;
    _flushScheduled = true;
    _scheduler.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (!_disposed) notifyListeners();
    });
    // Ensure a frame actually comes when the app is idle (between frames) — otherwise an addPostFrame
    // callback registered while idle wouldn't fire until something else schedules a frame.
    // 空闲(帧间)时也确保来一帧,否则空闲时注册的 postFrame 回调要等别处调度才触发。
    _scheduler.scheduleFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
