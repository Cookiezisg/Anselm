# EDGE-307 · poll 型 202 不谢幕

## L1 focused evidence

- `frontend/test/features/chat/state/stage_director_provider_test.dart` 通过：receipt open/close 与 terminal 的 flowrun 关联收口，terminal 到达前不会错误谢幕。
- `frontend/test/features/chat/ui/stage_panel_test.dart` 通过：live row 在 settle 后才收起，失败和嵌套运行保持可见语义。

## 判定

L1=`F1`：202 回执不被当成最终完成，durable terminal 才是收尾事实。L2-L5 本批未启动真实 App，记 `na`。
