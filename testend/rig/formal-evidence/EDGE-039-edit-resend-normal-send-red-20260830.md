# EDGE-039 `:retry` 编辑重发：真实 App 红证据（2026-08-30）

## 结论

**RED。** 真实 App 中把最后一条用户消息编辑后重新提交，实际走了普通
`POST /api/v1/conversations/{id}/messages`，没有走契约要求的
`POST /api/v1/conversations/{id}:retry`。因此旧 user/assistant 行没有被
`supersededBy`，编辑后的消息被追加成了新的普通回合。

## 五通道定位

- Rig session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-162617`
- Workspace：`ws_bf9aed46483af41a`
- Conversation：`cv_5cac7014d51473d6`
- 真实 App 操作：新建对话，发送 `EDGE039 original prompt`；点击原用户消息，编辑为
  `EDGE039 edited prompt`，点击发送，等待回合完成。
- Frame：录屏中的 UI 显示编辑后的文本和新回答，但未显示版本替换关系。
- Backend journal：原始回合 `16:27:47.163` 与编辑回合 `16:28:32.941` 均为
  `POST .../messages`、状态 `202`；没有 `POST ...:retry`。
- REST truth：消息列表顺序为新的 assistant、编辑后的 user、旧 assistant、旧 user；
  四行的 `supersededBy` / `retryOf` 均为空。
- SSE：编辑回合从 seq `15` 开始以普通 user `open/close`（随后普通 assistant）
  到达，而不是 retry 版本链。
- LLM wire：编辑文本确实进入了第二次模型请求；这证明问题不是输入丢失，而是
  产品动作选择错误。

## 预期

编辑最后一条用户消息并提交，应调用 `:retry {content}`，保留旧行、建立新 user
与新 assistant 版本，并通过 `supersededBy` / `retryOf` 形成可读版本链。

## 当前处理

保持本格未判绿。先封存该 session，再定位真实 App 使用的入口与 `_EditResendField`
回调是否可达；修复后以新 session 复测。
