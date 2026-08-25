# EDGE-308 · 侧幕失败行清除

## L1 focused evidence

- `frontend/test/features/chat/state/stage_director_provider_test.dart` 通过：failed close 进入 failed-hold，row-level clear 才回到 idle。
- `frontend/test/features/chat/ui/stage_panel_test.dart` 通过：失败 live action 与成功 verb 不混淆，清除出口保持明确。

## 判定

L1=`A5`：失败反馈不会静默消失，同时提供唯一可理解的行级清除动作。L2-L5 本批未启动真实 App，记 `na`。
