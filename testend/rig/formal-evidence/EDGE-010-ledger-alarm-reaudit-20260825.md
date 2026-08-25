# EDGE-010 ledger/alarm re-audit · 2026-08-25

## Trigger

写入 EDGE-010 五个层级后，原有统计窗口按设计打开 `gap-too-fast` 与
`discovery-collapse`；没有打开 `pass-burst`。本复审不改变任何阈值、检测算法、法典、锚点或
序列规则。

## Evidence review

- 重新阅读 `EDGE-010-tool-result-cap-investigation-20260825.md`：旧代码确实让截断提示和失败错误
  文本把最终结果推过 256 KiB，属于真实容量与可诊断性缺陷，不是形式性补测。
- 后端 `go test ./internal/app/loop -count=1` 通过；回归同时验证成功结果、部分输出加错误、最终
  字节上限、UTF-8 边界和收窄提示。
- 前端 `chat_tool_card_test.dart` 全文件通过，超长 prose 展开显示 bounded excerpt、截断提示和
  原始长度；`make analyze` 通过。
- L2/L3/L5 仍按证据边界记录 `na`，没有把本地 fixture 或 widget test 冒充真实 managed gateway
  五通道 session、帧时延证据或可发现性旅程。

## Resolution

这是一次真实 stop-and-fix：修复后才写入 L1/L4，且保留三层不适用声明。两条警报仅针对这次正式
写账窗口独立复审后销账，后续检测继续启用。
