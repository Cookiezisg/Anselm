# EDGE-298 · 未读徽标绝不据帧 +1

## L1 focused evidence

- `frontend/test/features/notifications/state/unread_count_provider_test.dart` 通过：candidate 事件触发权威 `unread-count` refetch，不直接 `+1`；非 candidate 不触发；410 resync 会重取。
- `frontend/test/features/notifications/data/notification_fixture_test.dart` 通过：Emit 与 EmitEcho 的持久化语义分流稳定。

## 判定

L1=`F1`：徽标来自服务端权威计数，而非从帧形状猜测增量。L2-L5 本批未启动真实 App，记 `na`。
