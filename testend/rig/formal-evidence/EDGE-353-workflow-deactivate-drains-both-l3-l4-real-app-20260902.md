# EDGE-353 workflow 停用排空双类：L3/L4 当前版本真实 App 复验

## 范围与判定

本证据只提升 `EDGE-353` 的 L3（顺滑）和 L4（视觉 craft）。L5 仍保持未结算：本轮从
已知 workflow 进入实体菜单，没有做从空白状态开始的新用户可发现性走查。L2 的用户目的与
五通道真相沿用本格既有 L2 证据，本文件不把功能成功重复冒充为 L5。

正式 session=`/private/tmp/anselm-rig-formal-20260902-34/sessions/20260902-063536`；workspace=
`ws_59aa11b757be8ed6`；workflow=`wf_09d37b27a7cdd5ca`；trigger=`trg_2abde7e191547e05`；
录屏=`screen.mov`，`639.861667s / 3104x1848 / 60fps`。session 由同一 conductor 启动并收台，
`rig-check` 在 AXTree session review 后通过，`rig-down` 成功封口。

## 真实 App 路径

1. 在真实 App 的 Entities workflow 行菜单中看到 `Deactivate`，点击后页面状态从 `active`
   变为 `draining`；右侧审批卡和 run terminal 保持可见，未把排空中的流程伪装成已停止。
2. 停用前已由两个真实 manual fire 建立两类在途工作：第一条 run 停在 approval，第二条因
   `serial` 保持 pending firing。停用后先在 App 批准第一条，第一条完成后第二条自动接续并
   再次显示审批卡；再批准第二条，页面收口为 `inactive`。
3. 收口后再次 fire 同一 trigger 只生成 activation，`firingCount=0`，没有新增 workflow
   firing 或 flowrun，证明 listener 已停止且历史没有幽灵执行。

## L3 顺滑证据（A4）

停用是可能持续等待在途 run 的操作，UI 在动作后明确呈现 `draining`，并持续保留审批入口，
用户知道系统正在做什么、下一步是什么，而不是面对无反馈的等待。录屏按 10fps、局部窗口
ROI 抽帧，使用仓内测量器：

```text
measure latency -dir /private/tmp/edge353-latency-20260902-r1 -fps 10 -action 55 -roi 0,0,776,462 -threshold 0.01
=> {"feedbackFrame":64,"latencyMs":900.0,"changedFrac":0.01450,"box":"(76,184)-(519,304)"}
```

`action=55` 由 recorder 起始时刻与 notifications 的 `workflow.lifecycle_changed` draining
帧对齐得到；变化框落在 workflow 状态/内容区，而不是无关时钟或光标区。停用后的状态反馈
没有夺走右岛、没有冻结页面，也没有把两类在途工作中的任一类静默丢弃。法条：`A4`。

## L4 视觉 craft 证据（C4）

对 `screen.mov` 的 active、draining、第二条审批等待和 inactive 关键帧逐帧目视复核，并用
`measure diff` 检查状态变更范围。四张抽帧保留在：

- `/private/tmp/edge353-screen-frames-20260902/498-active.png`
- `/private/tmp/edge353-screen-frames-20260902/501-draining.png`
- `/private/tmp/edge353-screen-frames-20260902/520-after-first.png`
- `/private/tmp/edge353-screen-frames-20260902/547-inactive.png`

复核结果：状态 chip 的高度、圆角和色层在 `active → draining → inactive` 间保持同一视觉
阶梯；审批卡与右岛边界稳定，workflow 图的节点/连线不重排，实体 rail 的状态点同步变化；
没有白闪、遮挡、裁切、异常空白或不解释的布局跳变。最终 inactive 帧仍保留可继续查看
版本、图和 run terminal 的信息层级。法条：`C4`。

## 五通道交叉核验

- **Frames / Computer Use**：真实 App 观察到实体菜单 `Deactivate`、`draining` 中间态、两次
  审批和最终 `inactive`；录屏与上述抽帧来自同一 session。
- **Backend**：最终 workflow 为 `active=false,lifecycleState=inactive,concurrency=serial`；
  两条 firing 均 `started`，对应两条 flowrun 均 `completed`；approval inbox 为空；backend
  journal 无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**：notifications durable seq 22 为 active、24 为 draining、26 为 inactive；entities
  durable seq 19/20 与 21/22 分别对应两条 run 的 start/terminal；三条流均连接且无缺口，
  post-deactivate fire 的 entities 帧明确 `firingCount=0`。
- **Frontend console**：无 Dart/Flutter exception、RenderFlex、lost-device 或未解释 runtime
  红线；141 条 Flutter macOS AXTree bridge churn 已在 session 专属
  `evidence/frontend-ax-review.md` 中逐条按已知 tooling pattern 审阅，非应用错误。
- **LLM wire**：受管网关 challenge/install/models 均为 `200`；本确定性 workflow 不需要模型
  completion，未把 `ready` 冒充 completion 证据。

## 结论

`EDGE-353` L3/L4 均可判通过：优雅停用的长期等待有明确可见状态，且状态切换期间的布局、
层级和视觉尺度稳定。L5 继续保持未结算，等待独立的从零可发现性走查。
