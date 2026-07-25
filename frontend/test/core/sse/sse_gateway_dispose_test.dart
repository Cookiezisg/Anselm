import 'dart:async';

import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/sse/sse_connection.dart';
import 'package:anselm/core/sse/sse_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

// The shutdown-path regression (0725 关停日志实锤): every lazy demux controller is registered with
// `onCancel: () => registry.remove(key)`, and dispose() closed them while iterating the SAME map —
// close() ends the subscriptions, onCancel fires, the entry vanishes under the iterator, and dispose
// dies with ConcurrentModificationError. It hit on every app exit and on the workspace-switch dispose
// path, and stayed invisible because the zone handler ate it on the way out.
//
// 关停路径回归(0725 关停日志实锤):每个懒建 demux controller 注册时带着
// `onCancel: () => registry.remove(key)`,而 dispose() 边遍历同一个 map 边 close()——close 终止订阅、
// onCancel 开火、表项在迭代器脚下消失,dispose 以 ConcurrentModificationError 收场。每次 app 退出与
// workspace 切换的 dispose 路径都会撞上,只因 zone handler 在退出路上把它吃掉才一直没被看见。
class _FakeConn extends SseConnection {
  _FakeConn()
    : super(
        streamPath: '/x',
        baseUrl: 'http://localhost:1',
        workspaceId: () => null,
        authToken: () => null,
      );

  final ctrl = StreamController<StreamEnvelope>.broadcast();

  @override
  Stream<StreamEnvelope> get envelopes => ctrl.stream;

  @override
  void start() {} // never dials. 绝不拨号。

  @override
  Future<void> stop() async {}
}

void main() {
  test(
    'dispose survives live demux subscriptions (no concurrent modification)',
    () async {
      final gateway = SseGateway(
        baseUrl: 'http://localhost:1',
        workspaceId: () => null,
        authToken: () => null,
        connectionFactory: (_) => _FakeConn(),
      );

      // Populate BOTH lazy registries with several live subscriptions — one entry would pass even with
      // the bug on some map layouts; several make the mutation-under-iteration deterministic.
      // 给两个懒注册表都挂上**多条**活订阅——只挂一条时某些 map 布局下带病也能过;多条让「迭代中被改」必然发生。
      final subs = <StreamSubscription<StreamEnvelope>>[
        for (var i = 0; i < 4; i++)
          gateway
              .scopeStream(StreamScope(kind: 'conversation', id: 'cv_$i'))
              .listen((_) {}),
        for (final kind in ['function', 'handler', 'agent'])
          gateway.kindStream(StreamName.entities, kind).listen((_) {}),
      ];

      await gateway.dispose();

      for (final s in subs) {
        await s.cancel();
      }
    },
  );
}
