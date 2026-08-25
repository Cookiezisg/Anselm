# EDGE-311 · 归队重钉贴底

## L1 focused evidence

- `frontend/test/features/chat/state/transcript_jump_test.dart` 通过：deep jump 后 back-to-live 重新加入 head，发送操作也显式回到 present。
- `frontend/test/features/chat/ui/chat_transcript_test.dart` 通过：pinned reader 跟随 max，scrolled-up reader 不被 streaming 推动。

## 判定

L1=`F5`：归队动作显式重建贴底状态，不把读者留在历史窗口。L2-L5 本批未启动真实 App，记 `na`。
