# EDGE-033 · 流式可操作性尝试 · 不计入验收

Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-152152`

本场曾在真实 App streaming 期间验证 Composer 草稿保留和转录区滚动，现场行为本身可观测；
但输入要求输出至少 20 节，真实网关响应持续到收台边界。`rig-down` 在最终 assistant
`message close` 尚未到达前主动停止台架，SSE 只有持续 delta，没有完整终态；backend 因
关停取消 compaction 留下一条 `context canceled` warning。故本场不写任何 COVERAGE pass，
不作为 L2/L3/L4/L5 证据，后续以短输入重跑并等待自然 close。
