# EDGE-279 · 对话挂载的文档被删 · 真实 App L2

## 目标

证明一个已经挂载文档的对话，在文档随后被删除后仍能继续对话：模型必须看到明确的
`missing="true"` grounding 警告，不能读到不存在的正文，也不能因为历史悬挂引用让整轮失败。

## 真实路径

- clean session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-144028`
- workspace=`ws_6161a430bf326410`
- conversation=`cv_b110ec9c283373f4`
- fixture document=`doc_223e10c4a400bc06`
- App/window=`34126/6116`
- 真实操作顺序：创建文档 → 创建对话 → 在真实后端 PATCH `attachedDocuments` → 删除文档 → Computer Use 打开该对话 → 真实键入并发送消息。

## 五通道证据

- **画面 / Computer Use**：真实 App 的对话成功完成；最终画面显示助手明确回答“无法读取您之前附上的文档”，解释文档已被删除或不再存在，并建议重新上传。画面没有错误页、卡死或无限生成；最终帧=`evidence/EDGE-279-missing-document-response.jpeg`。
- **backend journal**：对话消息两轮均返回 `202`，对应两个 LLM 回合均正常收束；无应用级 `WARN`、`ERROR`、panic 或 fatal。第二轮为 `POST /v1/chat/completions`，响应 `200`。
- **SSE tap**：三条 stream 均由 ssetap 真实接管；notifications durable seq `16..19` 严格递增，包含 document create、conversation create/update、document delete；messages durable 帧覆盖 user/assistant 回合及最终 text，未见 gap。
- **frontend journal**：无 Flutter/Dart/RenderFlex/RenderBox/Unhandled 应用红线；仅保留已分类的 macOS IMK 宿主诊断。
- **LLM wire**：managed gateway 的 challenge/install/models 全为 `200`；真实 chat request 的 system prompt 含精确的
  `<document id="doc_223e10c4a400bc06" missing="true">(this attached document no longer exists — it was deleted; its content is unavailable)</document>`，第二轮返回 `200`，没有伪造文档正文。

## 交叉核对与边界

- REST 在删除后仍保留对话的 `attachedDocuments` 引用，这是预期的历史引用；渲染层将它转换为缺失警告，而不是静默移除 grounding。
- SQLite `integrity_check` 与 foreign-key check 在收台前通过；录屏窗口归属于 conductor 启动的 App，`rig-check` 与 `rig-down` 均通过。
- 本格只证明“缺失引用下仍可诚实继续对话”的 L2 数据真相与完成性；L3 顺滑、L4 视觉 craft、L5 可发现性保持 `na`，不以一次错误状态对话冒充五级结论。

## 判定

L2=`F1`：真实 App、五通道 journal、LLM wire 和持久化事实一致，文档缺失被模型和用户双方诚实看见，回合正常完成。
