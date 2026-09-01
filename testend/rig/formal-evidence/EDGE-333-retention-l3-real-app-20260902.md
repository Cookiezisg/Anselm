# EDGE-333 · 保留面板无客户端默认 · L3

## 判定

`A1` 通过：用户打开保留策略菜单、选择 180 天、再恢复 90 天时，均在 100ms 反馈门内看到局部控件变化或结果反馈；没有把 Computer Use 调用墙钟冒充 UI 延迟。

## 真实运行

- session: `/private/tmp/anselm-rig-formal-20260902-02/sessions/20260902-001814`
- workspace: `ws_8397891fc75d3e99`
- recording: `screen.mov`, `3104x1848`, `102.666667s`, 60fps
- product path: Settings → Storage & logs → Run history retention
- initial wire value: `GET /api/v1/retention` returned `{"runRetentionDays":90}`
- action: opened the dropdown, selected `180 days`, observed success feedback and `180 days`; selected `90 days`, observed success feedback and `90 days`

## Measurement

The 60fps windows were extracted from the sealed recording:

- 180-day selection: `measure latency`, action frame `245`, feedback frame `247`, `33.3ms`, changed region `(2072,842)-(2551,950)`
- 90-day restoration: `measure latency`, action frame `245`, feedback frame `246`, `16.7ms`, changed region `(2098,844)-(2524,944)`
- 2fps transition scan: all reported changes were limited to the settings panel/dropdown region; no persistent whole-panel reflow was observed

## Five channels

- frame: the sealed recording shows the four options, successful selection feedback and final `90 days` state
- backend: `backend.log` records the initial GET, both PATCHes and both follow-up GETs as HTTP 200; PATCH elapsed time is 0-1ms
- SSE: `ssetap` connected to messages, entities and notifications for the workspace; no business durable frame was expected for a machine-level settings change
- frontend console: 4 lines, no Flutter exception, `RenderFlex`, `RenderBox`, overflow or unhandled error; the known macOS IMK diagnostic is host-level and reviewed
- LLM wire: managed challenge/install/models requests were all HTTP 200; no chat model call was needed by this journey

