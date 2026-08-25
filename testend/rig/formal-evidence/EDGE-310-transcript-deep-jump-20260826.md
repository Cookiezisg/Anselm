# EDGE-310 · 深跳 `?around=` 整窗替换

## L1 focused evidence

- `frontend/test/features/chat/state/transcript_jump_test.dart` 通过：deep jump 的 identity anchoring、resync hydration 和发送回到 present 的边界行为稳定。
- `frontend/test/features/chat/ui/sidestage_ondemand_shell_test.dart` 通过：聊天岛切换不会在无 activity 时产生幽灵入口。

## 判定

L1=`F5`：跳转与重水合以消息身份和服务端窗口为真相，不凭旧视图拼接。L2-L5 本批未启动真实 App，记 `na`。
