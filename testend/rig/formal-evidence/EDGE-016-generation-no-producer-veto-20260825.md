# EDGE-016 · 生成族产地过滤

## Verification

MediaRef collector 不读取 `source` 做 producer veto。`generate_image` 的 receipt 与 function/MCP artifact
一样按 producing tool call 分组交给 `MediaExpander`；生成工具结果只携带 receipt，字节仍由附件消费咽喉按
模型能力/信封决定。该结论遵循 ADR 0020：旧的生成族否决曾让模型看不到刚生成的图并重复出图，已被成对
实验否证。

Focused verification passed:

```text
go test ./internal/app/loop ./internal/pkg/mediaref \
  -run 'TestToolResultMediaIDs_CarriesTheToolCallID|TestRun_SelfAuthoredMediaIsFedBack|TestCollect_HasNoProducerVeto' -count=1  PASS
go test -race ./internal/app/loop ./internal/pkg/mediaref \
  -run 'TestToolResultMediaIDs_CarriesTheToolCallID|TestRun_SelfAuthoredMediaIsFedBack|TestCollect_HasNoProducerVeto' -count=1  PASS
```

现有回归同时证明：`source=generate_image` 会被收集；生成 receipt 会在下一次 request 变成原生 media
part；不会把生成族当成“模型已经知道”的理由而丢弃；跨 producing call 的归属仍由 `ParentBlockID` 保证。

## Five-level applicability

- L1 `pass`: 生成族不被产地过滤，receipt 能进入同轮媒体消费链；测量法
  `measure:edge016-generation-no-producer-veto`。
- L2 `na`: 本轮未为该内部 producer policy 单独启动真实生成/gateway 五通道 session。
- L3 `na`: focused test 无真实 App 录屏、生成等待帧或媒体加载时延数据。
- L4 `na`: 本条验证媒体消费策略，不含独立视觉几何/动效 surface。
- L5 `na`: producer policy 是内部协议边界，不是用户可导航入口。
