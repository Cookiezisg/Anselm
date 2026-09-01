# EDGE-232 账本警报复审

本次警报由正式写入 `模型目录运行时刷新失败` L2 后触发，未修改任何警报阈值、算法、
法典或锚点。

- `gap-too-fast`：警报针对近期裁决间隔，不是本格证据质量判断。复审重新核对了本格
  session 的 `screen.mov`、`backend.log`、`frontend.log`、`sse.jsonl`、`llm.jsonl`，
  以及 `rig-check`/`rig-down` 封口结果；录屏可读，时长 `147.233333s`，三路 SSE
  各连接一次并 clean EOF，真实 managed bootstrap 与两次 chat completion 均为 `200`。
- `discovery-collapse`：近期没有 fail 不是自动判绿。本格的真实故障由关闭 loopback
  catalog 端点确定注入，backend 明确留下 `previous catalog kept`，Settings 仍展示
  模型目录，真实 Chat 返回 `EDGE232CHATOK`；L2 使用存在于 `CODEX.md` 的 `E7`，不是
  仅凭 UI 印象签章。

复审结论：两条警报均已被本次完整五通道证据和本格适用法条覆盖，可以 ack；后续新裁决
仍会重新计算曲线，任何新警报仍然阻止继续写 pass。

L3 追加裁决后警报再次打开，原因仍是统计窗口的裁决速度与 fail-share，而非新缺陷。
追加复核确认真实 App 在后台失败后仍可进入 Settings、返回 Chat、完成真实 completion，
录屏与五通道材料没有变化或缺失；因此本轮按原阈值再次 ack，保留警报触发事实。
