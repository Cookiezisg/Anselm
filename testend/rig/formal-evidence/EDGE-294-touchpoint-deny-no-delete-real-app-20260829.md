# EDGE-294 · 触点不记幽灵删除：真实 App L2

## 目的

验证危险删除调用在用户拒绝后确实没有执行：目标实体仍存在、不会产生 `deleted` 通知，也不会在对话触点台账里伪造一次删除足迹。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151503`
- data=`/private/tmp/anselm-data-edge294-real-20260829-r1`
- workspace=`ws_6b1a68d7272543a9`
- conversation=`cv_67b4397afdc3e6d8`
- Agent=`ag_48d56677797d099a`（`EDGE294 delete probe`）
- App/window=`39007/6218`；录屏=`105.826667s`
- 关键帧=`sessions/20260829-151503/evidence/EDGE-294-denied-delete.jpeg`

## 场景与结果

1. 在真实 workspace 创建临时 Agent。
2. 真实 App 中发送“Delete the agent named EDGE294 delete probe. Do not do anything else.”；模型先搜索到唯一 Agent，再展示危险确认卡，明确目标 id、删除语义和审计保留说明。
3. Computer Use 点击 `Deny`。App 回答“删除操作已被拒绝。如需继续，请告知。”，危险卡收尾为 `Denied`，没有继续重试。
4. 收台前 `GET /agents/ag_48d56677797d099a` 仍返回 `200`；该对话 `GET /touchpoints` 返回空列表；notifications 中没有任何 delete 行。

## 五通道证据

- **Channel 1 / Computer Use + 录屏**：真实 App 展示完整危险确认卡与拒绝后的人话回执，无错误卡、残留等待或幽灵删除状态。
- **Channel 2 / backend journal**：只发生 Agent 搜索和交互 resolve；无 `DELETE /agents/{id}` 执行记录、无应用级 WARN/ERROR/panic。
- **Channel 3 / SSE tap**：messages 流记录危险 `interaction`、用户拒绝后的 resolved interaction 和 denied `tool_result`，没有 agent.deleted 或 touchpoint deleted 帧。
- **Channel 4 / frontend 错误面**：`rig-check` 通过真实 App/window 归属、录屏遮挡、三流连接和 recorder lifecycle；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，唯一 IMK 文本为已分类的 macOS 宿主诊断。
- **Channel 5 / LLM tap**：真实 chat-completions continuation 均为 `200`；wire 中 `delete_agent` 保留 `dangerous`，仅进入 interaction gate，拒绝后工具结果明确为 `The user denied running this tool. Do not retry it unless the user explicitly asks.`。
- **耐久对账**：目标 Agent REST 仍存在，touchpoint 列表为空，notifications 无删除事件，SQLite `integrity_check=ok`、`foreign_key_check` 为空。

## 判定

本证据支持 L2 `F1`：用户拒绝后没有执行删除，也没有产生幽灵触点或删除通知；UI、SSE、LLM wire、REST 和 SQLite 事实一致。L3-L5 不在本次证据中猜测，继续保持 `na`。
