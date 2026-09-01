# EDGE-247 · 账本警报独立复审

本次 `EDGE-247 L2` 写账后，`alarms.py check` 按原有阈值打开
`discovery-collapse`：近 50 条正式裁决的 fail 占比为 `2.0%`，低于 `5%`。没有打开
`gap-too-fast`；没有修改警报阈值、曲线算法、法典、锚点或顺序 gate。

复审重新核对了本格的独立正式 session
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-191204`：

- 录屏和 Computer Use 观察确实包含真实 App 的错误态、可理解原因、Retry 以及恢复后的
  Chat/Recents/Composer，而不是只看代码测试或最终绿态。
- backend journal 确实记录了受控未知路径 `404`、受控错误方法 `405` 和之后透明请求
  `200`；appproxy journal 证明两次注入各自只消耗一个有限预算。
- `sse.jsonl`、`frontend.log`、`llm.jsonl` 与同一 manifest 绑定，三路 SSE 均连接，前端无
  Flutter/Dart/Unhandled/渲染红线；LLM 只记录真实 managed bootstrap，不虚构模型 completion。
- `anchors.py check` 保持 `10/10`；formal evidence、session journals、录屏和 focused
  router tests 均可重读。

因此该告警被解释为统计保护信号，而不是“产品无缺陷”或“可以橡皮章通过”。本次证据
真实、完整且没有降低标准，允许按既有机制 ack 当前 journal 水位；后续新裁决仍继续受三条
曲线约束。

## L3 追加复审

`EDGE-247 L3` 写账后同一 `discovery-collapse` 按原规则再次出现。复读同一封存 session
的稳定错误帧、Retry 后恢复帧和五通道日志，确认 A4 的判断基于真实可见等待/恢复反馈，
不是把后台请求速度或空白画面当作顺滑；因此按原阈值再次销账，标准不变。

## L4 追加复审

`EDGE-247 L4` 写账后再次出现同一统计告警。复读 `frame-001`、`frame-030`、
`frame-060`、`frame-103` 及录屏尾段，确认错误卡到正常 Chat 的切换没有裁切、重叠、
自主跳变或破坏 Composer/rail 的几何关系；C4 的适用判断没有把这项路由错误体验扩大
冒充文档选择等无关视觉 surface。按原机制销账，标准不变。

## L5 追加复审

`EDGE-247 L5` 写账后再次出现同一统计告警。复读 Computer Use 的错误态与恢复后的
可访问树，确认用户只需理解“对话列表加载失败”和点击 `Try again`，不需要知道 HTTP
路由、请求方法或 N1 envelope；恢复后的 Chat 入口仍可见可用。G1 的可发现性结论有真实
入口和动作证据支撑，按原机制销账，标准不变。
