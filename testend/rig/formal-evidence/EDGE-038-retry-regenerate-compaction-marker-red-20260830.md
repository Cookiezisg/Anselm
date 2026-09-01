# EDGE-038 · :retry 重生成分支 · 首轮红证据

真实 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-155920` 发现产品缺陷，故本文件不是通过证据：

- 在有 Context compacted marker 的真实线程中点击 `Retry`，HTTP 返回 `202`，但新 assistant 的 `attrs.retryOf` 指向 compaction assistant 行 `msg_f18dfc7b6702beaf`，而可见旧回答 `msg_7b9605ea026a95dd` 的 `supersededBy` 仍为空。
- UI 因此出现新 assistant 版本和版本导航，但 durable 事实没有替换真正可见回答；这违反 EDGE-038 的“supersede 末 assistant、不写新 user 回合、重生成同一轮”语义。
- 五通道仍完整：录屏=`screen.mov` 约 `204.591667s`，SSE messages durable `seq=1..18` 单调，backend/frontend 无应用级红线，managed LLM wire 请求均为 `200`。问题是 retry target 选择错误，不是台架故障。

根因是压缩/workdir 使用 assistant-shaped synthetic marker，而 `retryTargets` 未过滤这些 marker。修复与回归测试见 `backend/internal/app/chat/retry.go` 与 `retry_test.go`；修复后的真实 session 必须重新证明旧可见 assistant 被 supersede、新 assistant 的 `retryOf` 指向旧回答，才允许 L2 裁决。
