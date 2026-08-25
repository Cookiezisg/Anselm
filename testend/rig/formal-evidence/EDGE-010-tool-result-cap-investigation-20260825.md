# EDGE-010 · tool_result 256 KiB 硬封顶

## Stop-and-fix finding

静态审阅发现旧实现把截断提示追加在 256 KiB 原文之后，因此最终结果超过硬上限；工具同时返回
部分输出和错误时，错误文本也可能再次把结果撑出上限。这不满足“落库、SSE、当前 prompt 三处都
不被打爆”的验收目标。

## Fix

`capToolResult` 现在把提示本身计入最终字节预算，成功结果保留头部并在合法 UTF-8 的字符边界截断。
失败结果使用同一预算保留输出头部、错误尾部和收窄提示。最终字符串（不是仅原始 payload）严格不超过
`limits.Tools.ToolResultCapKB`，默认值为 256 KiB；畸形 UTF-8 不由截断器擅自改写。

## Verification

后端回归 `TestExecuteTool_ToolResultHardCap` 以 1 KiB live limit 构造多字节超长成功结果与“部分输出+
错误”结果，验证：

- 成功和失败 `tool_result` 的最终长度均不超过 cap；
- 成功结果保留可读的 `tool result truncated` 与 `narrow the query` 提示；
- 失败结果仍保留 `upstream failed`，不丢失权威错误原因；
- 成功结果不泄漏尾部 sentinel，且不会切断 UTF-8；
- `go test ./internal/app/loop -count=1` 通过。

前端已有真实工具卡边界回归：9000 字 prose 结果在展开后显示 bounded excerpt、截断提示和原始长度，
不把整段结果塞进视图；对应 `chat_tool_card_test.dart` 全文件通过，`make analyze` 通过。

## Five-level applicability

- L1 `pass`: `executeTool` 的成功/失败路径均受最终字节 cap 约束，并由 `TestExecuteTool_ToolResultHardCap`
  锁死；测量法 `measure:edge010-tool-result-cap`。
- L2 `na`: 本条是 loop 的确定性容量边界，本轮没有为制造数百 KiB Grep/MCP 输出而启动真实五通道
  managed session；不伪称已有 session 证据。
- L3 `na`: 前端工具卡已有 bounded excerpt，但本条的关键判据是字节容量，不是用户动作到帧的时延或动效。
- L4 `pass`: 用户可见的超长结果有可读截断提示，前端 `chat_tool_card_test.dart` 锁定该呈现；法条 `E1`
  （人话状态与下一步）适用。
- L5 `na`: 截断是工具结果的自动保护边界，不是用户需要自行发现的产品入口；收窄建议已在结果内直接给出。
