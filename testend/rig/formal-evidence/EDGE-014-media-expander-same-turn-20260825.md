# EDGE-014 · MediaExpander 当轮回喂

## Verification

loop 在 tool result 中按 `origin_tool_call_id` 分组收集 MediaRef，交给可选的 `MediaExpander`，并把返回的
原生 content part 只追加到**下一次 provider request**。生成图和 function/MCP 产物都走同一消费咽喉；无
expander 或模型不支持该模态时保留文本 receipt，诚实降级。临时 user 消息不进入 `allBlocks`，因此不会被
`WriteFinalize` 持久化。

Focused verification passed:

```text
go test ./internal/app/loop -run 'TestRun_(SelfAuthoredMediaIsFedBack|EvidenceMediaStillExpands|ToolResultWithoutMediaExpandsNothing)' -count=1  PASS
go test -race ./internal/app/loop -run 'TestRun_(SelfAuthoredMediaIsFedBack|EvidenceMediaStillExpands|ToolResultWithoutMediaExpandsNothing)' -count=1  PASS
```

回归明确断言：首次请求不含媒体，后续请求含真实 image part；生成与 function artifact 均按生产它的
tool call 展开；无媒体结果不触发展开；最终 blocks 不含临时 `Media artifacts referenced...` user 消息。

## Five-level applicability

- L1 `pass`: 同轮原生媒体回喂、产地归属和持久历史隔离均成立；测量法
  `measure:edge014-media-expander-same-turn`。
- L2 `na`: 本轮未为该内部 loop seam 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused test 没有真实 App 录屏、帧时延或媒体加载视觉数据。
- L4 `na`: 本条验证 provider content-part 与持久边界，不含独立视觉几何/动效 surface。
- L5 `na`: MediaExpander 是内部消费咽喉，不是用户可导航入口。
