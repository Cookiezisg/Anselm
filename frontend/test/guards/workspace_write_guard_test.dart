import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// WRK-083 L2 law: production code writes the active workspace through ONE door.
//
// The id change dirties `dioProvider` (that watch IS the hot-switch pulse), and Riverpod flushes
// lazily — so the dirt sits there until a WIDGET's build walks down the chain, and the flush then
// cascades into `setState` on the provider scope mid-build. The app threw that assertion on every
// single cold start and every hot restart. `setActiveWorkspace` settles the chain in the same breath as
// the write, which is why the two must not be separable.
//
// A behavioural test cannot hold this line: `test/guards/provider_settle_guard_test.dart` proves the
// door works, but it says nothing about a NEW call site that walks around it. And walking around it is
// the easy mistake — `ref.read(activeWorkspaceProvider.notifier).set(id)` is the obvious thing to write,
// it compiles, it sets the id correctly, and the damage lands somewhere else entirely, in a terminal
// nobody reads. So the door is guarded at the SOURCE.
//
// Tests are exempt: they legitimately drive the raw notifier to construct states (the hot-switch suite
// does exactly that), and they do not ship.
//
// WRK-083 L2 军规:生产代码写活动 workspace **只走一扇门**。
//
// id 一变就把 `dioProvider` 弄脏(那个 watch **就是**热切换脉搏),而 riverpod **懒刷新**——于是这份脏一直搁着,
// 直到某个 **widget** 的 build 走下那条链,刷新随即在 build 中途级联成对 provider scope 的 `setState`。app 在
// **每一次**冷启动、每一次热重启都抛这条断言。`setActiveWorkspace` 把「摊平」与「写」放在同一口气里完成,
// 正因如此两者不可分离。
//
// 行为测试守不住这条线:`provider_settle_guard_test.dart` 证明这扇门是好的,却对**新增的绕行调用点**一无所知。
// 而绕行恰恰是最容易犯的错——`ref.read(activeWorkspaceProvider.notifier).set(id)` 是显然会写出来的那一行,
// 它编译得过、id 也确实设对了,而损害落在完全不相干的地方、落在一段没人读的终端文字里。故这扇门在**源码层**守。
//
// 测试豁免:它们正当地直接驱动裸 notifier 去构造状态(热切换那套就是这么做的),且它们不进发布物。

void main() {
  test('only setActiveWorkspace writes the active workspace id', () {
    const door = 'lib/core/workspace/set_active_workspace.dart';
    final offenders = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith(door.split('/').last) &&
          f.path.contains('workspace')) {
        continue; // the door itself 门本身
      }
      final src = f.readAsStringSync();
      // The notifier's own `set` — `clear()` is a different verb with no id to settle around, and the
      // NAME provider carries no dependency at all. 只挡 id notifier 的 `set`;`clear()` 是另一个动词、
      // 没有 id 可摊平,而**名字** provider 根本没有依赖者。
      if (RegExp(
        r'activeWorkspaceProvider\s*\.\s*notifier\s*\)\s*\.\s*set\s*\(',
      ).hasMatch(src)) {
        offenders.add(f.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these files write the workspace id directly instead of through '
          '`setActiveWorkspace` — the write and the runtime settle must stay one action (WRK-083 L2): '
          '${offenders.join(', ')}',
    );
  });
}
