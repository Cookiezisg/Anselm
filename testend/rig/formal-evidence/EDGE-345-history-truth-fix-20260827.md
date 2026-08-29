# EDGE-345 历史结果真相规则复验

第二个真实 App session 对上一轮发现的“历史成功冒充本次完成”问题做了 stop-and-fix 回归：

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-204342`
- 在包含既有成功登记与合成记录的旧对话中，用户再次要求用同一上传音频登记同名音色。
- 修复后的模型没有直接回答“已完成”，而是重新发起 `enroll_voice`，显示危险确认；拒绝后 UI 明确显示操作已取消。
- Computer Use、真实 macOS App、真实受管网关、backend journal、frontend journal、三路 SSE witness 和 LLM tap
  均由 conductor 持有；录屏 `77.760000s / 2784x1808 / 60fps`。
- 新请求没有发生 `inspect_media` 或任何上游写入；backend/frontend 无未解释应用红线，messages durable seq `1..14`。

该证据证明历史一致性修复，不代表音色登记/合成完整链路已经获得新的 L2-L5 绿判。
