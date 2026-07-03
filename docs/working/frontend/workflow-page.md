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

- **混合架构**:**节点=真 widget**(An* token/文本/图标/MouseRegion/i18n/主题全免费)定位在变换 Stack;**边=CustomPaint 底层**(W3 加动画层时 `repaint: AnimationController` 直驱、绝不 AnimatedBuilder rebuild)。几十节点规模性能富余。
- **零图形包依赖**:graphview(边渲染只有直线箭头、小图定位)/fl_nodes(pre-1.0、自带皮肤体系与 An* 冲突)都不引;最难的正交圆角边路由 + 回边弧 + 运行态动画没有包替写,布局已有 60 行 Sugiyama-lite 参照可移植。
- **GraphModel 纯模型层**(`core/graph/`,CLAUDE.md 预留位):解析 → 回边判定(DFS 灰节点,与后端 graph.go BackEdges 同算法)→ 分层(拓扑 rank + 中位数排序 8 趟)→ 坐标(LR/TB;**全节点带 pos 则用 pos、否则整图自动布局**)→ 正交圆角边路由(浮动锚 facing + STUB + 拐角点列)+ 回边通道 → bounds。纯 Dart 函数、脱 widget 单测。
- **视口自管**(Matrix4 + 手势,**不用 InteractiveViewer**——IV 用内置 Listener 抢 `PointerSignalResolver`(内层先注册者赢)、滚轮行为关不掉且跨版本反复变):`Listener` 辨 `PointerScrollEvent` → `M' = T(cursor)·S(f)·T(-cursor)·M` 缩放到光标(k∈[0.2,2.5]);scale 手势族管空白拖拽平移 + 触控板双指平移 + pinch 缩放(每帧从手势起点矩阵重组、不累积漂移);fit 公式自管(k ≤ 1.3、居中)。坑:读缩放用 `entry(0,0)`——`getMaxScaleOnAxis` 含未动 z 轴,k<1 错读为 1。
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
| W1 图地基 | `GraphColors` token(violet/teal + edge/gridDot)+ `GraphModel` 纯模型层(`core/graph/`,回边 DFS/Sugiyama-lite/pos 优先/正交路由/回边通道)+ `AnGraphCanvas` 只读版(节点 widget + 边 painter[圆角折线+箭头+回边虚线] + 视口自管[滚轮缩放到光标/拖拽平移/pinch/fit] + framed/toolbar/进入编辑器缝 + 受控选中)+ gallery 9 specimens。**对抗复审 6 缺陷已修**(1 HIGH:换图不重 fit;5 MEDIUM:Dart 不稳定 sort 宽层漂移[index tiebreak]/等值重建吞用户视口[freezed == 判变]/辅助字号撑破节点卡[场景锁 textScaler]/加粗被 wght 轴覆盖实渲 w300[.weight(),连 AnTransformBox 同款]/a11y 直插英文枚举名[t.graph.kind.* 词表])+ 测试缺口 6 连补 | ✅(fe-verify 1398 绿;gallery 截图过) |
| W2 页面组装 | 概览重排(编排图 hero 置顶 framed + meta AnKv 就地编辑 + id·版本·计数 KV + 治理合卡 + 告警,坏 blob 诚实 inset)+ `patchWorkflowMeta` 写面(Live+Fixture,页头改名接线 + vN 徽对齐)+ 版本 tab `workflowVersionSummary` 图结构小签(节点按 id/边按端点+口)+ graph blob `prettyJsonSource` 美化 diff + demo fixture 升级(v2 质检门+retry 回边 + 版本历史) | ✅(fe-verify 1406 绿;概览/版本两截图过) |
| W3 活运行 | `GraphRunState`/`deriveRunState` 纯派生(迭代精确回边/口匹配/合成 running,9 单测)+ 画布运行面(边四 tier + 彗星层 + 呼吸环 + ×N 叠卡 + future 虚线,AnMotionPref 门控)+ run 终端 workflow 分支重做(tick `flowrunId` 自滤[修混流]+ 去抖对账 + 4s 轮询兜底 + 终态收口[修「拉一次定终态」]+ keepAlive 钉到终态)+ 审批门卡 `:decide`(first-wins 回落对账)+ hero 活态(watch 同一 provider)+ fixture 202 同形图驱动脚本 + gallery 3 运行态 specimens | ✅(fe-verify 1433 绿;demo run hero + gallery 三态截图过)。**对抗复审 6 根因已修(2 HIGH)**:①单页 50 行未翻页→首次对账翻页拉全+并集合并(record-once 不可变)②×N=行数非最高迭代+1(循环出口后继曾误渲 ×N+1)③AND-join 部分前驱曾误亮汇聚点→两趟候选过滤 ④parked 全图关停合成与后端相悖(并行分支照常派发)→只挡自身下游 ⑤cancel 被迟到 tick 复活→按 phase 闸 ⑥派生 O(edges×rows²)→(node,迭代) 索引近线性 + 彗星/边层 RepaintBoundary 隔离。教训:**后端 walk 语义(AND-join/前向边保持迭代/parked 非全局)必须逐条对 walk.go 核实,不能凭直觉推演** |
| W4 驾驶舱 | `flowrunTimeline` 纯派生(节点→甘特段,时间定位+零跨度顺序回退,7 单测)+ `AnNodeGantt`/`AnRunBoard` 原语(gallery 4 specimen)+ **运行 tab**(取代 workflow 日志 tab:run 历史列表 + 甘特 + run 态活图 + **内联**节点调试[status/iteration/result/error + parked 审批门]强链,`runCockpitProvider` 翻页拉全 + `:replay`/`:kill` 重取真相)+ 写面 `replayFlowrun`/`killWorkflow`/`fetchFlowrunFull`。**W3 同病灶解**:log_list flowrun 懒取单页现为 workflow 死路(cockpit 翻页拉全)。**节点调试放内联而非右岛**:右岛专属 run 操作台(触发/活 run 终端),观测历史入文档流(单滚壳一致) | ✅(fe-verify 1457 绿;完成/失败/循环×2 甘特 + run 图 + 节点调试截图过) |
| W5 编辑器 | 编辑器路由页(工具条/检查器/连接柄拖线/edit ops/动态 control 端口解析/capability-check 问题条) | ⏳ |

每批:gallery → 接线 → 截图过目 → `make fe-verify` 绿 → 文档同步。W1 先行(一切之基),W2–W4 吃只读+run 两态,W5 编辑态最后(最大)。
