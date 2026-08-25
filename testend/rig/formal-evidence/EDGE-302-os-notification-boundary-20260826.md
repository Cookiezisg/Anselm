# EDGE-302 · OS 通知被静默拒

## L1 focused evidence

- `frontend/test/features/notifications/state/notice_dispatcher_test.dart:unfocused routes to OS instead of the in-app stage` 通过：失焦事件走 OS notifier 路由。
- `frontend/lib/features/notifications/data/os_notifier.dart` 明确记录：macOS unsigned dev bundle 的 UserNotifications 可能以 `UNErrorDomain Code=1` 静默拒绝，真实投递须以签名 build 验证。

## 判定

L1=`F1`：路由真相和已知平台边界均被明确记录；本批没有签名 build，因此不宣称 OS 真投递通过。L2-L5 记 `na`。
