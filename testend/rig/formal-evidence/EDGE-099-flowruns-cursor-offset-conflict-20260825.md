# EDGE-099 flowruns 两种分页互斥

- **结论**：pass（cursor/keyset 与 offset/page 两种分页模式互斥）
- **验证目标**：`GET /api/v1/flowruns` 同时收到 `cursor` 与 `offset` 时，必须优先返回 `422 FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT`；单独的畸形 `offset` 仍返回参数错误，不能被冲突检查吞掉。
- **Focused commands**：`cd backend && mise exec -- go test ./internal/transport/httpapi/handlers ./internal/app/scheduler -run 'Test(List_CursorOffsetConflict|ParseOffset)' -count=1 -race -v`；`cd testend && mise exec -- go test ./scenarios -run '^TestFlowruns_OffsetPagination$' -count=1 -v`
- **结果**：handler `-race` 单测通过，覆盖正常双模式、`cursor` 存在但 `offset` 畸形仍先报冲突、以及单独畸形 `offset`；真实 HTTP scenario 通过，确认 offset 分页、cursor 分页、混用 422、负 offset 与坏 offset 的响应契约。testend free-tier port-1 warning 是隔离 harness 的预期关闭端口，不是场景失败。

Levels 2-5 are intentionally `na`: this cell is an API pagination contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
