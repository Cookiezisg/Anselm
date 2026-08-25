# EDGE-305 · 侧幕尊重手动关

## L1 focused evidence

- `frontend/test/features/chat/state/sidestage_auto_reveal_test.dart` 通过：预先记录手动关闭后，即使再次 stage 也保持收起。
- 同文件通过：用户折叠可见 sidestage 会记录本会话手动关闭状态。

## 判定

L1=`A5`：用户手动意图优先于后续自动提醒，不发生反复打扰。L2-L5 本批未启动真实 App，记 `na`。
