# EDGE-265 · 切驻地落 marker 块

## L1 focused evidence

- `backend/internal/app/conversation/workdir_test.go:TestUpdate_WorkDirMountSwitchUnmount` 与 `TestUpdate_WorkDirMarkerFailureNeverBlocksTheSwitch` 通过。
- `testend/scenarios/chat_workdir_test.go:TestChatWorkDir_MidThreadSwitchLeavesADurableMarker` 通过，消息历史中落 `{kind:workdir,from,to}` marker，正文保持空。

## 判定

L1=`F5`：驻地切换的历史语义可从 durable message/block 重建，不依赖瞬时 SSE 回声。L2-L5 本批未启动真实 App，记 `na`。
