import 'package:anselm/core/run/flowrun_progress.dart';
import 'package:flutter_test/flutter_test.dart';

// C-019 — FlowrunProgress.withTick did `[...ticks, t]` (O(n) copy) with an UNBOUNDED list, so a heavy
// iterative workflow (a node re-entered thousands of times) made tick accumulation O(n²) (measured:
// 905ms at 20k ticks) on a non-autoDispose provider (memory leak). The stage renders only the last 12,
// so the list is now capped to maxTicks. 有界末 12+余量,拷贝 O(n²)→O(n)、内存有界。
void main() {
  test('ticks are capped at maxTicks regardless of how many land', () {
    var p = const FlowrunProgress(flowrunId: 'fr');
    for (var i = 0; i < 5000; i++) {
      p = p.withTick(
        NodeTick(nodeId: 'n$i', iteration: 0, status: 'completed'),
      );
    }
    expect(p.ticks.length, FlowrunProgress.maxTicks, reason: '硬有界');
  });

  test('the cap keeps the NEWEST ticks (what the stage renders — last 12)', () {
    var p = const FlowrunProgress(flowrunId: 'fr');
    for (var i = 0; i < 200; i++) {
      p = p.withTick(
        NodeTick(nodeId: 'n$i', iteration: 0, status: 'completed'),
      );
    }
    expect(p.ticks.last.nodeId, 'n199', reason: '最新在末');
    // The last 12 (the render window) are the newest 12. 渲染窗末 12 = 最新 12。
    final window = p.ticks.sublist(p.ticks.length - 12);
    expect(window.first.nodeId, 'n188');
    expect(window.last.nodeId, 'n199');
  });

  test('below the cap, every tick is retained in order', () {
    var p = const FlowrunProgress(flowrunId: 'fr');
    for (var i = 0; i < 10; i++) {
      p = p.withTick(
        NodeTick(nodeId: 'n$i', iteration: 0, status: 'completed'),
      );
    }
    expect(p.ticks.length, 10);
    expect(p.ticks.map((t) => t.nodeId), [for (var i = 0; i < 10; i++) 'n$i']);
  });

  test('C-019 budget: 20k ticks accumulate in O(n) (was ~905ms O(n²))', () {
    var p = const FlowrunProgress(flowrunId: 'fr');
    final sw = Stopwatch()..start();
    for (var i = 0; i < 20000; i++) {
      p = p.withTick(
        NodeTick(nodeId: 'n$i', iteration: 0, status: 'completed'),
      );
    }
    sw.stop();
    expect(
      sw.elapsedMilliseconds,
      lessThan(150),
      reason: 'O(n) 有界拷贝:${sw.elapsedMilliseconds}ms(原 O(n²) 此规模 ~905ms)',
    );
  });
}
