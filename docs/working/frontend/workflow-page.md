---
id: WRK-055
type: working
status: active
owner: @weilin
created: 2026-07-03
reviewed: 2026-07-03
review-due: 2026-10-01
audience: [human, ai]
---

# Workflow 实体页 — 编排图画布 + 驾驶舱 + 编辑器(WRK-054 第二站)

> 实体页雕琢总纲在 [`entity-pages.md`](entity-pages.md)(WRK-054);本篇是 workflow 站的专属规范——图画布原语量级够大、独立成篇。参照物 = demo `an-graph-canvas`(`demo/core/primitives/graph-canvas.js`,用户钦点)+ demo 三海洋体验(实体页预览 / graph-editor / scheduler 驾驶舱)。

## 已拍板(2026-07-03)

1. **全量手工编辑器**:workflow 图开手工编辑(独立编辑器页:加删节点/连线/拖拽/检查器,逐动作发 `:edit` ops)。**拍板 #4(版本内容 AI-only)不延伸到 workflow 图**——图是空间编排,人改图是该 kind 的核心体验;function 的裁决理由(签名与代码强关联)在此不成立。
2. **图置顶当 hero**:概览第一屏就是编排图(与 function 变换盒 hero 同构),meta/治理卡在下。demo 的「图在中下」顺序不照搬。
3. **驾驶舱并入本轮**(W4):run 列表 + 节点甘特 + 活图 + 右岛节点调试,落在 workflow 的「运行」tab(取代其日志 tab 语义——workflow 的日志就是 flowrun)。
4. **滚轮 = 缩放到光标**(同 demo / n8n 惯例):裸滚/双指滚=以光标为中心缩放,空白拖拽=平移,pinch=缩放。

## 集成契约(后端事实,调研核实 2026-07-03)

- **Graph 线缆**:`Node{id, kind, ref, input(map 字段→CEL), retry?, pos?{x,y}, notes?}` + `Edge{id, from, fromPort?, to}`(workflow.go:96-183)。**pos 后端持久化**(authoring 元数据、执行忽略)——渲染 pos 优先、缺省才自动布局(demo 的 layout 覆写 pos 是它自认的 TODO,不照抄)。
- **5 kind 封闭集**:trigger(trg_)/action(fn_·hd_&lt;id&gt;.method·mcp:server/tool)/agent(ag_)/control(ctl_)/approval(apf_);回边只能出自 control/approval;禁自环;≥1 trigger;全可达(graph.go:27-100)。
- **control 端口是动态契约**:fromPort ∈ 被引 `ctl_` 实体 active 版本 `Branch.Port` 集合(作者自定义名);approval 恒 yes/no。demo 的 branch1..N/retry 自动命名是编造——**编辑器生成出边前必须拉 control 实体解析真实端口**。图渲染不受影响(边上有啥渲啥)。
- **`:edit` ops 7 种**:set_meta / add_node{node} / update_node{id,patch}(**顶层 merge patch,input 整体替换**——改单字段须回发完整 input map)/ delete_node{id}(**后端级联删触及边**,ops.go:206-215——前端无须像 demo 那样自发级联 delete_edge)/ add_edge{edge} / update_edge{id,patch} / delete_edge{id}。
- **执行面**:`POST :trigger` → 202 `{data:{id:flowrunId}}`(绕过并发策略);`GET /flowruns?workflowId&status`(最新在前);`GET /flowruns/{id}` → `{flowrun, nodes, nextCursor}`(**节点行最新在前分页**——长 loop run 一页非全量);run 状态机 running/completed/failed/cancelled;**节点行只有终态** completed/failed/parked(**无 running 行**);`POST /flowruns/{id}:replay`(仅 failed);审批 `GET /flowrun-inbox` + `POST /flowruns/{id}/approvals/{node}:decide`(first-wins,输家 422);止损 workflow `:kill`。
- **SSE 活图**:entities 流 workflow scope、`node.type="run"`、**ephemeral seq=0**,content `{flowrunId, nodeId, iteration, status}`(status 只有三终态)。**「正在跑」是前端合成态**(上游 completed → 后继标 running 属推测渲染);tick 可丢、run 头终态无 entities 信号(failed 走 notifications `workflow.run_failed`)——**活图 = tick 点亮 + `GET /flowruns/{id}` REST 对账收口**;tick 按 `content.flowrunId` 自滤(workflow scope 并发多 run 会混流)。
- 错误码:WORKFLOW_* 17 个 + FLOWRUN_* 7 个(error-codes.md);`WORKFLOW_NOT_RUNNABLE` details.problems、`WORKFLOW_INVALID_GRAPH` details.reason。
- 前端契约层已 100%(Graph/Node/Edge/NodeKind sealed+unknown/NodePosition/Flowrun/FlowrunNode/FlowrunComposite + triggerWorkflow/listFlowruns/getFlowrun + workflow scope SSE 缝)。

## 架构决策(业界调研 2026-07-03,对抗验证过)

- **混合架构**:`InteractiveViewer(constrained:false, boundaryMargin:∞)` 管平移缩放;**节点=真 widget**(An* token/文本/图标/MouseRegion/i18n/主题全免费,RepaintBoundary 包裹);**边=CustomPaint 双层**(静态层 path 缓存 + 动画层 `repaint: AnimationController` 直驱、绝不 AnimatedBuilder rebuild)。几十节点规模性能富余。
- **零图形包依赖**:graphview(边渲染只有直线箭头、小图定位)/fl_nodes(pre-1.0、自带皮肤体系与 An* 冲突)都不引;最难的正交圆角边路由 + 回边弧 + 运行态动画没有包替写,布局已有 60 行 Sugiyama-lite 参照可移植。
- **GraphModel 纯模型层**(`core/graph/`,CLAUDE.md 预留位):解析 → 回边判定(DFS 灰节点,与后端 graph.go BackEdges 同算法)→ 分层(拓扑 rank + 中位数排序 8 趟)→ 坐标(LR/TB;**全节点带 pos 则用 pos、否则整图自动布局**)→ 正交圆角边路由(浮动锚 facing + STUB + 拐角点列)+ 回边通道 → bounds。纯 Dart 函数、脱 widget 单测。
- **自研滚轮缩放到光标**(InteractiveViewer 内置滚轮行为跨版本反复变):外包 `Listener` 辨 `PointerScrollEvent`,矩阵更新 `M' = T(cursor)·S(f)·T(-cursor)·M` 直写 transformationController;fit-to-content 公式自管(k ≤ 1.3、居中、clamp)。拖拽 delta ÷ 当前 scale;视口↔场景用 `toScene()`。
- **视觉规格照 demo 逐项复刻**(digits 见 graph-canvas.js:8):节点 188×60 rx14、类型色 chip 26×26 rx8 + 18 图标、id+ref 双行(截断)、GAPX 84/GAPY 44/PAD 48/STUB 22/CORNER 12/LOOP_GAP 26、回边底部/右侧虚线 accent 通道、端口药丸、运行 tier(taken 加粗 ink/live accent 彗星/future 虚线/parked 琥珀/running 呼吸环——呼吸过 AnMotionPref 门控)、×N 叠卡、网格点底、悬浮工具条、framed 380 定高自动 fit。**字重按两档纪律适配**(demo 的 w600/w700 → emphasisWeight w400)。5 kind 色族缺 violet/teal → 新增 design token(照 SyntaxColors ThemeExtension 先例,禁内联)。
- **demo 已知缺陷不照抄**:layout 覆写 pos(做成 pos 优先)、branchN/retry 编造端口(编辑器拉 ctl_ 实体解析)、approval 门未接线(真接 `:decide`)、run 终端「拉一次定终态」(重做成 tick+对账)。

## 页面 ideal 形态

- **概览**:① **编排图 hero**(AnGraphCanvas framed:定高、自动 fit、网格点、悬浮缩放条 + 「进入编辑器」;有在途 run 时活态点亮——右岛同 scope 数据源,同 function hero 心智)② meta(说明/标签 = 成熟 AnKv 编辑模式,`patchWorkflowMeta` 不升版)③ 运行治理合卡(lifecycleState + concurrency 策略 + needsAttention 告警红字直出)。页头改名照 function。
- **版本 tab**:照 function 定式(diff 置顶 + footer 设为活跃 `:revert`);小签 = **图结构 diff**(±节点/±边/改 ref,纯函数 `workflowVersionSummary`)。
- **运行 tab**(驾驶舱,取代 workflow 的日志 tab):**AnRunBoard**(左 run 列表[状态点 + mono id + trigger·时间 + ↻replay 徽] + 右 **AnNodeGantt** 节点甘特[kind 图标 + id + ×N 迭代徽 + 状态条,parked 内嵌「等待审批」])+ 下方 **run 态活图**(AnGraphCanvas run mode,随选中 run 切)+ 强链右岛(run 详情卡[pin 冻结/记忆化 n:m/耗时/replay·kill 动作] + 点节点/甘特行出节点调试[status/iteration/耗时/result json/error + parked 审批门→`:decide`])。failed 行出 `:replay`。
- **编辑器**(独立 go_router 路由,常量 key 壳不重挂;从 hero「进入编辑器」进):顶工具条(返回/添加节点 5 类菜单/自动布局/方向 LR·TB)+ 画布 edit 态(拖拽存 pos[minor]、四向连接柄拖线、边校验 toast)+ 右岛检查器(kind/ref[@ 提及同款 picker]/input 接线表[完整 map 回发]/retry/出口列表/删除)。逐动作发 `:edit` ops(每动作一版,后端语义即此);`WORKFLOW_INVALID_GRAPH/INVALID_OPS` 失败 toast + 回滚本地。capability-check 问题条(`POST :capability-check` → problems/warnings)。
- **右岛 run 终端**(entities 通用面)重做 workflow 分支:tick 驱动(flowrunId 自滤)+ 终态 re-GET 收口 + parked 审批门,不再「拉一次定终态」。

## 建造批次

| 批 | 内容 | 状态 |
|---|---|---|
| W1 图地基 | 节点色族 token(violet/teal)+ `GraphModel` 纯模型层(布局/回边/路由,单测矩阵)+ `AnGraphCanvas` 只读版(节点 widget + 边双层 painter + 平移缩放 fit + 滚轮缩放到光标 + framed/toolbar + 选中回调)+ gallery specimens(线性/分支端口/回边/TB/空/海量 stress/unknown kind/framed) | ⏳ |
| W2 页面组装 | 概览重排(hero 图 + meta AnKv + 治理合卡 + 告警)+ `patchWorkflowMeta` 写面 + 版本 tab `workflowVersionSummary` 图结构 diff 小签 | ⏳ |
| W3 活运行 | run 态渲染(tick 合成 running + REST 对账 + taken 推导 + 彗星/呼吸/×N)+ 右岛 run 终端 workflow 分支重做 + 审批门 `:decide` + hero 活态 | ⏳ |
| W4 驾驶舱 | `AnRunBoard` + `AnNodeGantt` 原语 + 运行 tab 组装(run 选择 ↔ 甘特 ↔ 活图 ↔ 右岛节点调试强链)+ `:replay`/`:kill` | ⏳ |
| W5 编辑器 | 编辑器路由页(工具条/检查器/连接柄拖线/edit ops/动态 control 端口解析/capability-check 问题条) | ⏳ |

每批:gallery → 接线 → 截图过目 → `make fe-verify` 绿 → 文档同步。W1 先行(一切之基),W2–W4 吃只读+run 两态,W5 编辑态最后(最大)。
