# EDGE-309 · 侧幕分档时钟

## L1 focused evidence

- `frontend/test/features/chat/state/stage_director_provider_test.dart` 通过：stage 状态与 terminal/失败收口不依赖重建。
- `frontend/test/features/chat/ui/sidestage_invariants_test.dart` 通过：整段 demo playback 的时序与布局不变量逐帧保持。

## 判定

L1=`A5`：活动行的时序投影由状态时钟驱动，不以静态构建冻结。L2-L5 本批未启动真实 App，记 `na`。
