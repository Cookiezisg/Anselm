# EDGE-353 workflow 停用排空双类：当前版本真实 App 五通道复验

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-014157`；数据目录为
  `/private/tmp/anselm-data-edge353-20260827-r2`，当前二进制由 conductor 从本工作树重新构建。
- 真实 Flutter App、Computer Use、Anselm 窗口录屏、conductor-owned backend、独立三路 SSE witness、
  llmtap 和 frontend/backend journal 均属于同一 manifest。`rig-check` 首次因 AXTree 观察噪声拒绝，
  写入 session 专属 `evidence/frontend-ax-review.md` 后重新通过；`rig-down` 成功封口录屏
  `350.406667s`，所有进程均已停止。

## 操作与产品结果

1. 真实 App 打开 `edge353_r2_workflow` 详情，初始显示 `inactive`、`serial`、图中 trigger→approval。
2. 通过真实 HTTP workspace API 上线 workflow，再从真实 webhook 发送第一条事件；App 显示审批卡“等待审批”，
   详情显示 `active`，第一条 run 停在 approval。
3. 第一条仍在途时发送第二条不同 payload 的真实 webhook，得到 accepted pending firing；随后在真实 App 的
   workflow 更多操作菜单点击“下线”。App 立即显示 `draining`，并显示“在途：已停”；未伪装成 inactive，
   也没有把已接受的第二条事件丢掉。
4. 在真实 App 先后点击两次审批卡的“通过”。第一条 run 完成后，第二条 pending firing 被调度并再次显示审批卡；
   第二次通过后 App 稳定显示 `inactive`，侧栏状态点回到停止态，无红色失败卡、无 retry、无重复操作。
5. 停用后再次调用同一 webhook 得到 HTTP `404 page not found`；未新增 firing 或 flowrun。

## REST / SQLite 真相

- workflow 最终为 `active=false,lifecycleState=inactive,concurrency=serial`。
- 本轮两个 firing：`trf_fa184a4a8bd50d8f`、`trf_60fc52a34c1cff98`，最终均为 `started`；对应
  `fr_ecbd9c939f36c4a3`、`fr_df4c377bda0f5e5d` 最终均为 `completed`。旧 fixture 中的两个历史 completed
  行仍保留，未被误算为本轮新执行。
- 中间真实快照为一条 `running` run + 一条 `pending` firing；停用后仍为 `draining`。这证明生命周期同时等待
  在途 run 与已接受 pending firing，而非只检查 run 数。

## 五通道交叉证据

- **帧 / App**：录屏覆盖激活、审批等待、`draining`、第二次审批和最终 `inactive`；终态详情、侧栏和审批反馈
  相互一致。
- **backend**：无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**：`notifications` durable seq `1..5` 单调，包含 active、approval_pending、draining、inactive；
  `entities` durable seq 单调，包含两次 run_started、两次 run_terminal，无 gap；messages 在此 workflow-only
  场景没有伪造聊天历史帧。三条流均由 ssetap 连接并在收台时正常断开。
- **frontend**：无 `Unhandled exception`、`EXCEPTION CAUGHT`、`FlutterError`、Dart exception、`RenderFlex`
  或 `RenderBox`；固定 AXTree bridge 观察器噪声已由 session review 分类，静置 3 秒不增长；另有一条已审阅的
  macOS IMK host warning，不是应用错误。
- **LLM wire**：llmtap `event=ready`，本场景不需要模型调用；无模型调用仍证明受管线缆启动并被 rig-check 校验，
  不能把 `ready` 误写成模型请求证据。

## 代码与回归

- 当前 workflow/store 的条件 `draining→inactive` 更新返回是否真正获胜；只有获胜者发布一次 durable
  `workflow.lifecycle_changed`，并发/重复 reconcile 不重复发帧。
- focused 回归：`mise exec -- go test -count=1 ./internal/app/workflow ./internal/infra/store/workflow`，全绿。
- 本场景为既有 EDGE-353 L1/L2 语义在当前版本上的新五通道复验；没有把一次 L2 复验提升为顺滑、视觉 craft 或
  从零可发现性结论。L3-L5 由账本明确保持 `na`。

法条：F1（用户可观察状态与持久执行事实一致）、F2（持久状态与实时流一致）、E1（仅三条 workspace SSE 流）。
