# EDGE-278 文档 Move 防环：真实 App 验收

- 日期：2026-09-01
- 现场：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-104042`
- 结论：通过；非法环路被拒绝，文档树保持原状
- 法条：`F2`、`B2`、`C5`、`G1`

## 目标

验证将三层文档树的根 `doc_5e440feae59850c4` 移到自己的后代
`doc_006cd368f6cfb3cf` 下时，后端拒绝循环，前端向用户给出可理解的结果，且没有
部分移动或错误地改变树。

## 真实现场

- 使用真实 Flutter Debug App、真实 Go sidecar、三路 SSE witness、LLM wire recorder、
  frontend console 和录屏同场运行；session 已由 `rig-down.sh` 封存。
- 直接 HTTP Move 请求返回 `422 DOCUMENT_INVALID_PARENT`，消息为
  `invalid parent (cycle or self)`；请求后 REST 树仍为
  `root -> child -> grandchild`，三条 path 均未变化。
- 在真实 App 中打开同一对话，用户消息明确要求把 Root 移到 Grandchild 下；助手实际调用
  `move_document`，工具卡显示红色 `Move rejected` 和
  `The destination cannot be the document itself or one of its descendants`，随后明确说明
  调用按预期被拒绝、对应 `DOCUMENT_INVALID_PARENT`，文档树没有变化。
- Computer Use 逐帧观察到最终页面仍可交互，输入消息、工具拒绝卡和解释文本均完整可读；
  稳定帧：`sessions/20260901-104042/evidence/edge278-cycle-rejected.jpeg`。
- 为避免 Computer Use 的 `type_text` 在本机 AX 输入桥中丢失下划线和中文，干净的精确
  验收消息通过 REST 写入后，再由真实 App 打开并观察执行结果。此前两次输入桥造成的
  错误 Move 已即时用 REST 恢复，未作为产品证据。

## 五级判定

| 层级 | 法条 | 证据与结论 |
|---|---|---|
| L2 真 | F2 | REST 422、LLM wire 中的真实 `move_document` 调用、工具卡、助手解释和请求后 REST 树五面一致；没有部分持久化。 |
| L3 顺 | B2 | 拒绝结果在当前对话中连续呈现，无空白、错误 loading、历史内容位移或树状态跳变；录屏稳定帧可复核。 |
| L4 美 | C5 | 工具卡的拒绝图标、红色状态文字、原因和后续解释保持清晰对齐，无裁切、遮挡或溢出。 |
| L5 找得到 | G1 | 普通用户只需提出“把文档移到其后代下”，即可在工具卡看到拒绝原因并知道树未改变，不需要理解数据库或 HTTP 语义。 |

## 五通道台架

- `rig-check.sh`：D1、backend、SSE、LLM recorder、frontend console 和录屏归属全部通过。
- `backend.log`：无 panic、fatal、error 或 warn。
- `frontend.log`：无 Dart/Flutter exception、RenderFlex/overflow 或应用级错误；存在的
  Flutter AXTree bridge churn 已在 `evidence/frontend-ax-review.md` 标记为 Computer Use
  观察器同步噪声，真实 App 无产品影响。
- `sse.jsonl`：三路流均连接并持续记录 durable/ephemeral 帧；会话共 1152 行，关闭时正常
  收口。
- `llm.jsonl`：会话共 60 行，真实 managed gateway wire 已记录；包含本次对话的调用链。
- `screen.mov`：已正常 finalize，稳定抽帧为 `edge278-cycle-rejected.jpeg`。

## 本地验证

- `backend/internal/app/document/document_test.go:TestMove_CycleGuard` 通过。
- `testend/scenarios/contract_docs_att_test.go:TestContractDocsAtt_DocumentChildrenDuplicateMove` 通过。
- 实现位于 `backend/internal/app/document/document.go:348`，自指和后代目标均返回
  `ErrInvalidParent`，事务不写入部分结果。

