# EDGE-017 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-017 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`，未打开
`pass-burst`。本复审不改变 detector、阈值、法典、锚点或 sequence gate。

## Evidence review

- DeepSeek wire regression 直接解析 request body，确认全文本 parts 变成有序 JSON string，两个换行和文本
  内容均保留；没有把 provider 编码测试冒充真实模型成功。
- 普通 llm suite 与 `go test -race` 均通过；没有发现需要 stop-and-fix 的实现红线。
- L2-L5 保持显式 `na`：本条没有独立真实 managed gateway 五通道 session、帧时延、视觉 surface 或用户
  导航入口。

## Resolution

两条警报仅针对 EDGE-017 写账窗口独立复审后销账，后续 drift detector 保持启用。
