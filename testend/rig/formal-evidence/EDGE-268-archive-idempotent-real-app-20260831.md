# EDGE-268 · 驻地分组批量归档重跑 · L2 真实 App 证据

正式 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-233736`，workspace=`ws_8fe797430dcf8f75`。为本场景创建两个专用线程并放入 `/private/tmp/anselm-edge268-group`，真实 App 保持运行并观察活动 rail；归档动作使用产品对应的真实 HTTP 端点执行，避免点击不可稳定暴露的隐藏组菜单 affordance。

## 结果

```text
POST /api/v1/conversations:archive-workdir #1 -> {archived: 2, workDir: /private/tmp/anselm-edge268-group}
POST /api/v1/conversations:archive-workdir #2 -> {archived: 0, workDir: /private/tmp/anselm-edge268-group}
GET /api/v1/conversations?archived=all -> both EDGE-268 threads archived=true
GET /api/v1/conversations/workdir-groups -> group activeCount=0, archivedCount=2
```

## 五通道交叉证据

- **屏幕 / Computer Use**：归档后真实 App 活动 rail 移除 `anselm-edge268-group`，保留其他活动驻地组；最终画面保存为 `sessions/20260831-233736/evidence/EDGE-268-archive-idempotent-real-app.png`。
- **后端 journal**：两次真实归档请求均为 200，响应体分别为 `archived=2` 与 `archived=0`。
- **SSE witness**：同场收到两个 `conversation.archived` durable notifications，分别对应两条专用线程；没有 messages 流帧。
- **前端 console**：仅有 macOS IMK 系统诊断，没有 Flutter/Dart/RenderFlex/overflow/Unhandled 错误。
- **LLM wire**：本场景不需要 completion；llmtap 只记录真实 managed bootstrap 接线，不伪造模型证据。

## L2 判定

`F2`：服务端返回的实际变更数、归档后的 durable 状态、SSE 事件和 App 活动列表相互一致；第二次重跑是明确的 `0`，没有重复归档或虚假成功。

`rig-check.sh` 与 `rig-down.sh` 均通过，录屏封存=`72.845000s`。本证据只覆盖本批新增的 L2；L3-L5 继续保持开放，不用 L2 结果冒充全格完成。
