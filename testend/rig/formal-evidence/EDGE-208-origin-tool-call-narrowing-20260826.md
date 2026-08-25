# EDGE-208 · `origin_tool_call_id` 收窄展开

## 判定范围

本证据覆盖 L1 tool-result 媒体消费边界。独立真实 App、SSE、LLM wire、逐帧视觉和可发现性 session 尚未为本格封存。

## 复现命令

```text
cd backend
mise exec -- go test ./internal/app/attachment -run '^TestToolResultContentParts_OnlyWhatThisCallMinted$' -count=1 -race -v
```

结果：`PASS`。

## 观察

- 当前 tool call 铸出的附件 ID 会按能力展开为原生媒体 part。
- tool result 回显的其他调用附件 ID 被保留为普通文本，不会越权展开。
- 缺少 `toolCallID` 时不展开任何附件。

## 结论

L1 通过。L2-L5 暂不判定，等待后续正式台架 session。
