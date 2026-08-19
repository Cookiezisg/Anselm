---
id: DOC-069
type: reference
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Feature：Scheduler（调度海洋）—— 当前形态

> 本篇描述 `frontend/lib/features/scheduler/` 的当前投影。执行与调度真相来自 [`scheduler-flowrun.md`](../../backend/foundation/scheduler-flowrun.md)、[`workflow.md`](../../backend/domains/workflow.md) 与 [`trigger.md`](../../backend/domains/trigger.md)。

## 1. 三层阅读面

| 层 | 路由 | 用途 |
|---|---|---|
| Overview | `/scheduler` | 跨 workflow 的运行态势、未来排程、等待人工处理、正在运行与近期失败 |
| Workflow 运营页 | `/scheduler/w/:workflowId` | 单 workflow 的排程轨、健康信号、运行历史与操作入口 |
| Run 卷宗 | `/scheduler/w/:workflowId/runs/:flowrunId` | 钉住运行版本的图、甘特、节点账本、错误、审批与恢复动作 |
| Run 中继 | `/scheduler/runs/:flowrunId` | 只拿到 run id 时解析父 workflow，再进入规范卷宗 URL |

三个层级共用一个 URL 选区；中心页与右岛 inspector 不维护第二份“当前 run”。Overview 和运营页不为填满右岛而造内容；只有 run 有真实深证据时右岛才出现。

## 2. 当前能力

- rail 按 workflow 展示活性、下一次点火、最近运行与异常信号；排序和显示偏好由独立 provider 持有。
- inactive workflow 只在沉底段保留历史行与时间，不携带当前运行/等待/失败状态点；停用前的失败历史仍可在详情与运行记录中追溯。
- Overview 的 KPI、排程轨、等待处理、正在运行和失败区都从 `schedulerRailProvider` 的同一批真相派生，避免徽标与正文各拉一份后漂移。
- 运行矩阵与排程轨按真实 run / firing 计算；空格是“没有运行”的答案，不用预测或占位冒充事实。
- run 卷宗展示触发来源、入口 payload、队列/执行耗时、钉住版本、执行图、节点甘特和逐节点 ledger；入口 payload 来自耐久 trigger node result，钉版无版本可解析时明确降级，不拿当前 workflow 图伪装历史图。
- parked approval 在节点账本中提升为可操作门；first-wins 冲突后重取服务器状态。
- 失败 run 可 replay，执行中 run 可 kill；triage 从卷宗开启对话，后续诊断仍由 chat 承载。

## 3. 数据与实时

- `SchedulerRepository` 是唯一数据缝；Live/Fixture 实现同形。
- REST 行是 durable 真相。`entities` / `notifications` 流只负责促使当前投影更新；tick 只更新瞬时进度，不灌入耐久缓存。
- rail、Overview 与 inspector 复用已取得的 workflow、stats、schedule、inbox 与 run 数据；同一个事实不由多个 provider 独立解释。
- trigger 的 `status`（pause/resume）帧会触发 rail 重取，以刷新 next-fire join；activation/firing telemetry 不触发整 rail 重取，避免高频观测流造成刷新风暴。
- run 详情以 `flowrunId` 寻址；workflow id 只提供父级导航和运营上下文，不能替代 run 身份。
- 运行版本来自 flowrun 自己的 `versionId`；版本缺失或宿主已删除时保留卷宗，其地图诚实不可知。

## 4. 关键不变量

1. 调度器是 durable engine 的观察与操作面，不在前端重新实现调度规则。
2. 下一次点火来自服务端 trigger schedule 投影；前端不自行算 cron。
3. run 终态与节点终态以数据库行裁决；SSE close/tick 只缩短可见延迟。
4. replay 只清理失败节点后幂等重走；kill 是硬停止，不伪装为普通失败。
5. approval 的决定只能提交一次；迟到客户端必须对账，不能本地覆盖服务器赢家。

## 5. 验证入口

- feature 测试：`frontend/test/features/scheduler/`
- 图与运行纯模型：`frontend/test/core/graph/`、`frontend/test/core/run/`
- 后端黑盒：`testend/scenarios/` 的 workflow/trigger/flowrun/approval/replay/kill 场景
- 人眼验收：`make -C frontend demo` 或 `make -C frontend app`
