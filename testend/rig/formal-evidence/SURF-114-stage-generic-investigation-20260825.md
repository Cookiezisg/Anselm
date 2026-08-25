# SURF-114 stage/generic investigation

## Scope

验证 `_GenericStage` 作为第 13 类通用舞台 host 的全生命周期：未编排工具不误登台、workflow poll 运行态不提前谢幕、节点/边图体量可读、durable terminal 后诚实收卷，并检查失败边界不被伪装成成功。

## Static contract

- `stageRouteOf` 对 `trigger_workflow` 路由为 workflow bespoke body + `LifecycleSource.poll`；其它未列入 stage route 的 catalog/search/read/list/delete 工具不凭空制造舞台。
- `_GenericStage` 负责 honesty ribbon、live/settling/failed 状态、poll progress 和 bespoke body 的 fallback host；settled 状态回到 touchpoint identity summary。
- `run_terminal` 必须按 `flowrunId` 匹配；receipt open 后先到 terminal、receipt close 后才给 flowrun id 的竞态也必须收口。

## Real run

- session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-105440`。
- 正向路径经真实 App 的实体提及选择器选择 `surf114_poll`，避免 Computer Use `type_text` 剥除下划线；单次真实 `trigger_workflow` 产出 `fr_b71eebde4adf9919`。
- REST flowrun completed；节点 2、边 1；workflow function action 返回 `fixture=surf114, ok=true`。
- 直接输入错误 id 的两次失败保留为负边界，不计绿格；它们证明仪器输入限制不能悄悄改变验收事实。

## Product verdict by level

- L1 achieved: `E2`。用户能通过提及实体选择目标并完成一次 workflow 触发，模型得到真实 run id。
- L2 true: `F2`。REST、messages/entities SSE、backend journal、frontend log、LLM wire 五通道相互一致；`run_terminal` 按 flowrun id 对账。
- L3 smooth: `B2`。poll 202 不提前退场，运行态维持；终态由 durable signal 驱动，不因结果回执时序跳成永久“执行”。新增真实时序 focused test 通过。
- L4 craft: `C4`。通用 workflow 图的节点/边、状态词、结果摘要在 2784×1808 连续帧内稳定，无 clipping/overlap/reflow；settled 动作词不冒充 running。
- L5 discoverability: `G1`。Activity 侧幕提供实体名、节点/边概览和结果落点；工具目录路径不误导为舞台，实体提及是可发现的精确目标入口。

## Boundary

`type_text` 剥掉下划线是 Computer Use 观察器边界；通过产品自身的实体提及入口可完成同一目标。该负边界保留在录屏和 SSE/LLM journal 中，未被擦除或降级为正向证据。
