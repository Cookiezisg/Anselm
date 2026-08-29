# EDGE-353 workflow 停用排空双类：真实 App 绿证据

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-002414`
- 真实 App + Computer Use + 窗口录屏 + backend journal + 三路 SSE witness + LLM tap 全部由同一台架托管。
- serial workflow 收到两次真实 webhook：第一条 run 停在 approval，第二条 accepted firing pending。
- App 执行 `:deactivate` 后中间态为 `active=false,lifecycleState=draining`；先后在 App 批准两条审批后，详情最终显示 `inactive`。
- REST 最终确认两条 firing `started`、两条 flowrun `completed`；notifications 出现唯一最终 `workflow.lifecycle_changed` inactive durable 帧；messages/entities durable seq 单调，无 gap。
- 停用后第三次同 webhook 返回 HTTP `404`，没有新增 firing/run；backend/frontend/LLM journal 无未解释错误。

首轮真实复验发现只写库不发 inactive SSE，修复为条件更新返回 changed，且仅由赢得转换的调用发布一次生命周期事件；store/app/scheduler 定向测试通过。

裁决：`L2=pass`（`F1`）；L3-L5 按该边界的覆盖政策不重复冒充视觉 craft / discoverability 证据。
