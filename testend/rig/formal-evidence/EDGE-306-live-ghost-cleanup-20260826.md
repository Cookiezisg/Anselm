# EDGE-306 · 导演器清 Live 幽灵

## L1 focused evidence

- `frontend/test/features/chat/state/stage_director_provider_test.dart` 通过：冷启动 hydration、terminal 收口、失败行清除和 nested owner 归属均按 transcript truth 重建。
- `frontend/test/features/chat/ui/sidestage_invariants_test.dart` 通过：demo playback 每个帧步均满足 sidestage 不变量。

## 判定

L1=`F1`：流缺口后的 live 投影从 durable transcript 重新接地，不保留孤儿行。L2-L5 本批未启动真实 App，记 `na`。
