# EDGE-183 换 embedder 重嵌 · L3

- 结论：`pass`
- 法条：`A4`（超过 1 秒的操作必须给出进度/状态；超过 10 秒必须可取消或后台化）
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-223728`

切换后第一条自然语言查询没有把内部 embedder 名称暴露给用户；App 先显示思考和
`Searched document`，随后显示 `Searching document…`，而不是停在无反馈的旧画面。
第二条从用户目标出发的语义查询在用户消息 durable close 后约 `2.85s` 出现首个
reasoning open，约 `5.37s` 出现首个搜索工具调用，约 `40.51s` 完成最终回答。整个
长回合有连续流式 reasoning、search/read 工具状态和可见内容，最终回到稳定输入态；
没有静默等待，也没有伪造百分比进度。

时序来源是同一 session 的 `sse.jsonl` durable timestamps 与 `screen.mov`，不是人工
估算。超过 10 秒的工作在 UI 中保持进行态并允许停止生成。
