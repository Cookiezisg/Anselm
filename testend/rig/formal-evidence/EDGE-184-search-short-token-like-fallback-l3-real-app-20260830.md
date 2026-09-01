# EDGE-184 短词 LIKE 回退 · L3

- 结论：`pass`
- 法条：`A4`（超过 1 秒的操作必须有可见进行态/状态反馈）
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-225024`

真实 App 的短 token 回合在消息 durable open 后约 `2.55s` 出现 reasoning，约 `5.17s`
出现最终文本；混合 token 回合在消息 durable open 后约 `1.36s` 出现 reasoning，约
`5.56s` 出现首个搜索工具调用，约 `20.95s` 完成最终回答。录屏中两回合均显示 thinking、
搜索/读取状态和最终结果；没有无反馈等待、假成功或停留在旧内容的情况。

`sse.jsonl` 的 durable timestamps 与 `screen.mov` 属于同一 session，作为时序来源；
没有把 Computer Use 的输入桥接延迟计入产品反馈。
