# EDGE-303 · 侧幕 activity 门控

## L1 focused evidence

- `frontend/test/features/chat/ui/sidestage_ondemand_shell_test.dart` 通过：无 activity 的普通问答没有 toggle、没有岛；有 activity 时才出现 toggle。
- `frontend/test/features/chat/state/sidestage_auto_reveal_test.dart` 通过：首个 staged activity 才触发可见岛状态。

## 判定

L1=`G1`：入口只在有真实活动时出现，空对话不制造无意义控件。L2-L5 本批未启动真实 App，记 `na`。
