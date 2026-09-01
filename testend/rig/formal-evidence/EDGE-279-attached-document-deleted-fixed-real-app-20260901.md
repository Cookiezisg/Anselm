# EDGE-279 · 对话挂载的文档被删：修复后真实 App 验收

- 日期：2026-09-01
- 现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-113227`
- 目标：历史引用保留，但模型和用户都明确知道正文已不可用；助手不得泄漏内部 grounding XML。

## 现场事实

- 真实 App、conductor-owned backend、三路 SSE witness、LLM tap、frontend console 和 60fps
  窗口录屏属于同一 session；`rig-check.sh` 和 `rig-down.sh` 均通过，owned processes 已收尸。
- 通过 REST 先创建文档和对话，将文档挂载到对话，再删除文档；删除返回 `204`，删除后读取文档返回
  `404 DOCUMENT_NOT_FOUND`，对话的历史 `attachedDocuments` 引用保留。
- Computer Use 打开该对话并发送 “Please explain what happened to the attached document”。真实
  managed gateway 回合完成；App 稳定帧见
  `sessions/20260901-113227/evidence/edge279-missing-document-response-fixed.jpeg`。
- 修复后用户可见回答为：“该文档已被删除，无法再访问其内容。如果您需要查看该文档，请重新上传一份。”
  无 `missing="true"`、XML 标签、内部 ID、残缺括号或错误页；输入、回答和 composer 均保持稳定。

## 五通道核对

- 帧：封口录屏可读，稳定帧显示单一清晰回答，无跳页、空白、布局溢出或持续生成。
- 后端：同场创建、挂载、删除、消息和 chat completion 均有 journal；删除后引用未被静默抹除，回合正常
  收束，无 panic/fatal/应用级异常。
- SSE：同场 `entities`、`messages`、`notifications` 三流真实连接；messages durable close 为
  `completed`，最终 text 与 App 一致。
- 前端：frontend journal 无 Dart/Flutter/RenderFlex/RenderBox/Unhandled 异常。
- LLM：managed challenge/install/models 与 chat completion 真实经过 llmtap；上下文包含缺失附件事实，
  但最终用户文本按新增规则隐藏内部标记。

## 修复与回归

- `backend/internal/app/chat/prompt.go` 新增缺失附件用户语言规则：说明删除/不可用并建议重新上传，禁止
  泄漏 XML、内部属性、raw grounding marker 或残缺警告片段。
- `backend/internal/app/chat/chat_test.go` 锁定该系统提示契约；`mise exec -- go test ./internal/app/chat`
  通过。
- `docs/references/backend/domains/chat.md` 已同步用户反馈契约。
- 首轮红帧与正式证据保留：
  `testend/rig/formal-evidence/EDGE-279-attached-document-deleted-real-app-20260829.md` 只证明
  L2，首轮回答泄漏内部标记的事实在本轮修复前已记录；本文件只作为修复后判定依据。

## 判定映射

- L3 `B2`：删除后的对话回合在真实 UI 中正常完成，状态单向收敛，无卡死、重复、跳页或视口夺取。
- L4 `C4`：两句短反馈有明确层级与留白，内部标记不泄漏，红线/错误态不冒充成功；稳定帧可复核。
- L5 `G1`：用户只需询问当前附件即可得到删除原因和可执行的重新上传下一步，无需知道 XML 或错误码。
