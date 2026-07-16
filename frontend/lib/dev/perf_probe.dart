import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// The real-frame probe — `make demo-profile` arms it via `--dart-define=PERF_HUD=true`.
///
/// Reports REAL frame times so a "feels sticky" report can be split into the halves that have completely
/// different cures: **build** (Dart: widget build + layout + the merged-thread platform-message work) vs
/// **raster** (GPU: paint, layers, repaint boundaries) — plus the **frame cadence** (the actual refresh
/// rate the app drives; a 60fps app on a 144Hz display judders no matter how cheap each frame is).
/// Flutter's `showPerformanceOverlay` does not render on macOS desktop, so this reads [FrameTiming]
/// directly — the same numbers, as text on stdout. Only meaningful on a `--profile` build (debug is JIT +
/// assertions and always janky — the 0716 lesson: a "sticky scrolling" report was entirely the debug
/// build; profile measured a full 120fps with 3× headroom). This closes the raster-side real-frame gap P5
/// explicitly left open ("automation context can't foreground a window"), without flutter_driver.
///
/// Output: `[perf] JANK build=…ms raster=…ms` per >3.5ms frame, and every 60 frames a summary line
/// `[perf] n=60 build p50/p95/max | raster p50/p95/max | gap p50=8.3ms ≈120fps`.
///
/// 真实帧探针——`make demo-profile` 经 `--dart-define=PERF_HUD=true` 装上。把「用起来粘滞」劈成救法完全
/// 不同的两半:build(Dart:构建+布局+合并线程后的平台消息工作)vs raster(GPU:绘制/图层/重绘边界),外加
/// **帧节奏**(app 实际驱动的刷新率——144Hz 屏上只出 60fps,每帧再便宜也发涩)。macOS 桌面不渲染
/// showPerformanceOverlay,故直接读 FrameTiming(同样的数,以文本落 stdout)。只在 --profile 下有意义
/// (debug 是 JIT+断言、必卡——0716 教训:「滚动粘滞」整个是 debug 假象,profile 实测满 120fps、余量 3 倍)。
/// 补上 P5 明确挂起的「raster 侧真机帧」缺口,且不需要 flutter_driver。
///
/// NOTE the arming define accepts ONLY the literals `true`/`false` — `=1` silently reads as false
/// (`bool.fromEnvironment`). 开关只认字面 true/false,传 =1 会静默当 false。
const bool kPerfProbeEnabled = bool.fromEnvironment('PERF_HUD');

/// Frames slower than this (per phase) log a `[perf] JANK` line — half the 144Hz budget (6.9ms), so a
/// spike is flagged well before it becomes a dropped frame. 单相超此值即记 JANK——144Hz 预算的一半,
/// 尖峰在真掉帧前就被点名。
const int _jankThresholdUs = 3500;

/// Frames per summary line. 每多少帧出一行汇总。
const int _summaryEvery = 60;

int _lastVsyncUs = 0;

void installPerfProbe() {
  final build = <int>[], raster = <int>[], interval = <int>[];
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      final b = t.buildDuration.inMicroseconds, r = t.rasterDuration.inMicroseconds;
      build.add(b);
      raster.add(r);
      if (b > _jankThresholdUs || r > _jankThresholdUs) {
        debugPrint('[perf] JANK build=${(b / 1000).toStringAsFixed(1)}ms raster=${(r / 1000).toStringAsFixed(1)}ms');
      }
      // Frame cadence: consecutive vsync gaps = the refresh rate actually driven (8.3ms=120Hz, 6.9=144,
      // 16.7=60). Gaps over 200ms are idle pauses, not cadence — skipped. 帧节奏:相邻 vsync 间隔;
      // >200ms 是空闲停顿非节奏,跳过。
      final v = t.timestampInMicroseconds(FramePhase.vsyncStart);
      if (_lastVsyncUs > 0) {
        final gap = v - _lastVsyncUs;
        if (gap > 0 && gap < 200000) interval.add(gap);
      }
      _lastVsyncUs = v;
    }
    if (build.length >= _summaryEvery) {
      String pct(List<int> xs, double p) {
        final sorted = [...xs]..sort();
        return (sorted[(sorted.length * p).clamp(0, sorted.length - 1).toInt()] / 1000).toStringAsFixed(1);
      }
      final fps = interval.isEmpty ? 0.0 : 1000 / double.parse(pct(interval, .5));
      debugPrint('[perf] n=${build.length} build p50=${pct(build, .5)} p95=${pct(build, .95)} max=${pct(build, 1)}'
          ' | raster p50=${pct(raster, .5)} p95=${pct(raster, .95)} max=${pct(raster, 1)}'
          ' | gap p50=${interval.isEmpty ? "-" : pct(interval, .5)}ms ≈${fps.toStringAsFixed(0)}fps');
      build.clear();
      raster.clear();
      interval.clear();
    }
  });
}
