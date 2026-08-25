# EDGE-015 · MCP 非纯 JSON 结果里的 receipt

## Verification

MCP 媒体结果可以是占位文本与 receipt 的混合体，例如
`[image: image/png]\n{"attachmentId":"att_...",...}`，不能要求整个 tool result 先通过 JSON 解析。
`toolResultMediaIDs` 先保留非 JSON 文本，再由 `mediaref.Collect` 解析嵌入对象；只有合法
`att_<16hex>` 且挂在 `attachmentId` 下的引用被收集，并继续按 producing tool call 分组。

Focused verification passed:

```text
go test ./internal/app/loop ./internal/pkg/mediaref -run 'TestToolResultMediaIDs|TestCollect' -count=1  PASS
go test -race ./internal/app/loop ./internal/pkg/mediaref -run 'TestToolResultMediaIDs|TestCollect' -count=1  PASS
```

新增回归直接使用 MCP 占位行加 receipt 的真实混合形状，断言 receipt 到达正确的 `tc_mcp` 分组；已有
mediaref 回归继续覆盖散文/代码块内 receipt、去重、封顶和伪造 attachmentId 不命中。

## Five-level applicability

- L1 `pass`: 混合文本中的合法 receipt 能到达媒体消费咽喉，整段非 JSON 不再丢媒体；测量法
  `measure:edge015-mcp-embedded-receipt`。
- L2 `na`: 本轮未为内部 receipt collector 单独启动真实 MCP/gateway 五通道 session。
- L3 `na`: focused test 无真实 App 录屏、媒体加载帧或时延数据。
- L4 `na`: 本条验证 receipt 解析与归属，不含独立视觉几何/动效 surface。
- L5 `na`: receipt collector 是内部协议边界，不是用户可导航入口。
