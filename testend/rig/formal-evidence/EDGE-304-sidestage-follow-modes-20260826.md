# EDGE-304 · 侧幕跟随三档

## L1 focused evidence

- `frontend/test/features/chat/state/sidestage_auto_reveal_test.dart` 通过：`always` 与首次跟随会自动展开首个活动，`never` 不自动展开。
- `frontend/test/features/chat/state/stage_director_provider_test.dart` 通过：follow mode 与 stage-worthy activity 的状态转换稳定。

## 判定

L1=`G1`：三种设置语义互斥且可预测。L2-L5 本批未启动真实 App，记 `na`。
