---
id: DOC-048
type: reference
status: active
owner: @weilin
created: 2026-06-30
reviewed: 2026-06-30
review-due: 2026-09-28
audience: [human, ai]
---

# Feature:Entities(实体海洋)—— 当前形态

> 第一个完整 feature,端到端落成(Phase 4.1)。本篇 = **它现在是什么样**(供快速理解 + 对接);**怎么一步步建的**(STEP/决策/调研)看归档建造日志 [`WRK-046`](../../../archive/entities/README.md);**文件住哪**看 [`architecture.md`](../architecture.md) §2;**DTO**看 [`contract.md`](../contract.md) §4。

## 一句话

**Quadrinity 实体**(Function / Handler / Agent / Workflow——四类可执行实体)的导航 + 详情 + 执行海洋。左岛 rail 选实体,中心海洋读详情,右岛跑执行。

## 五个面

| 面 | 在哪 | 是什么 |
|---|---|---|
| **rail(左岛)** | `features/entities/ui/entity_rail.dart` | `EntityRail` over [`AnSidebarList`]:7 kind 折叠段(4 可执行 Quadrinity + **control/approval/trigger 支撑段**,P1)+ 实体行(状态点:handler 运行态 / workflow 生命周期·attention / **trigger listener 热→蓝点**)+ 域内过滤 + ⚙ 菜单(排序 最近活跃/创建/名称 + 显示分组计数)+ 四态(骨架/错/空/列表)。选择 = `context.go` 改 URL。 |
| **ocean(中心)** | `features/entities/ui/detail/` | `EntityOcean` = **单一 `AnPage` 文档**(头 + tab + 720 阅读列**一起滚**):**workflow 图编辑器**(独立全屏路由 `/entities/workflow/:id/editor`,从概览 hero「进入编辑器」进,**无边框**:满铺画布 + 浮动药丸 chrome,不成实心条、`AnWindowControls` 预留红绿灯位;左簇 返回/加节点 5 类/自动布局/方向,右簇 未保存·放弃·`_saveButton`[与白药丸同高的 accent CTA]·收起时的重开钮):编辑态 `AnGraphCanvas`(骑在官方 `InteractiveViewer` 底座上——平移/pinch/滚轮到光标白拿;节点拖移 pos[localDelta 场景坐标]/连接柄拖连[裸 Listener + `_suppressPan`]/边与节点点选[裸 tap 探测,节点走 widget 命中避帧同步]/缩放条落左下)+ **检查器 = run 终端视觉孪生**(`AnInspectorHead` 头带[kind 图标 + node.id + 裸收起钮]+ 发丝线 + 满高滚动 body;节点 kind/**ref 分层选择器**[`NodeRefPicker`:族→目标→成员依赖下拉——action 选 function 直选 / handler→方法 / mcp→工具,agent/trigger/control/approval 单目标]/input 映射/retry/**control 节点加只读「路由分支」peek(每出口 `AnBadge`(port) + when CEL(`AnText.codeInline`)+ emit 徽;末条兜底淡显,`controlProvider`)**/删除;边 from→to·**port(control 源=被引用 control 的分支端口下拉 `controlPortsProvider`,approval 源=yes/no,消灭盲打自由文本)**·删除;未选=`AnState` 居中空态)+ **可收右岛**(`AnIsland` + `AnInspector(headless)` + 共享 `rightPanelCollapsedProvider`,同壳右岛揭示);本地 working 图 diff→一个 `:edit`→一版(`workflowEditorProvider`),INVALID_GRAPH/OPS 呈现理由留 working。—— `AnOceanHeader`(面包屑 + 名称[function/workflow 就地改名→meta PATCH] + 状态徽[workflow 含 vN·生命周期·并发·attention] + 动词 CTA)+ `AnTabs(flow)`(概览/版本/日志;**control/approval 仅概览 tab**;**trigger 无版本 → 概览 + 活动[activations 触发面,`firedOnly` 过滤] + 派发[firings 运行面,`status` 过滤 pending/started/skipped/superseded/shed]——两条独立 keyset 游标不可合并,故各自首级 tab、复用日志 tab 的 `AnRowDetail`+分页壳**;executable 门控)+ 各 kind 概览(`ControlOverview`:meta + inputs + 路由分支表 · **`TriggerOverview`:4 源一套一致模板**——identity + 配置[每源一个可复制 headline spec `AnCodeEditor`:cron 表达式 / webhook 挂载 URL `/api/v1/webhooks/{id}/{path}` / fsnotify 路径 / sensor CEL 条件 + 统一 KV 明细] + 运行时[listening/监听者/最近·下次触发] + Fire 载荷[`outputs`])。header 的 trigger `Fire` CTA(`:fire` 合成 `{manual:true}` 无表单 → toast 新 activation id + 刷新)。 |
| **运行驾驶舱(workflow 运行 tab)** | `features/entities/{state,ui}/detail/run_cockpit_*` | workflow 的日志就是 flowrun → 「日志」tab 换成 **「运行」驾驶舱**(WRK-055 W4):`AnRunBoard`(run 历史列表 + `AnNodeGantt` 节点甘特[状态条/×N 循环/parked 等待/未运行])→ 选中 run 的 run 态 `AnGraphCanvas`(派生覆层)→ 内联节点调试(status/iteration/耗时/result JSON/error + parked 审批门 `:decide`);run 详情卡 `:replay`(失败 run)/`:kill`(在途 run)。选中 run 的节点 composite **翻页拉全**(修 W3 同病灶:log_list 的 flowrun 懒取单页现为 workflow 死路,cockpit 走 `fetchFlowrunFull`)。全部由纯 `flowrunTimeline`/`deriveRunState`(活跃版本图 + 翻页节点行)派生。|
| **detail(tab 内容)** | `features/entities/{state,ui}/detail/` | 概览(function = 说明/标签 meta[`AnKv` 就地编辑] + 代码 **50 行渐隐收合**[`AnFadeCollapse`] + 输入/输出卡[`AnInfoCard`×2 · `fieldList`] + 环境合卡[venv KV + deps,envError `AnCallout` 红字直出];**workflow = `AnGraphCanvas` 编排图 hero 置顶**[framed 定高自动 fit + 缩放工具条,`graphOf` 解析、坏 blob 诚实 inset `graph.unparseable`;**hero 活态(W3)**:watch 右岛同一 `runTerminalProvider`,触发过即 `deriveRunState` 点亮(taken 加粗/彗星/呼吸/×N)——页 hero=仪表盘、右岛=操作台] + meta 就地编辑[说明/标签,同 function 的 AnKv 件,`patchWorkflowMeta` 不升版] + id·版本·节点边计数 KV + 运行治理合卡 + 告警,WRK-055 W2;余 kind 暂 AnKv/AnField/AnCodeEditor 罗列,逐个雕琢中 WRK-054)· 版本(`AnVersionDiff` 相邻版本 + **结构化 diff 小签**[function=签名字段/依赖/py `functionVersionSummary`;workflow=图结构 节点按 id/边按端点+口 `workflowVersionSummary`,graph blob 经 `prettyJsonSource` 美化后才有行可 diff;页边界行无签] + **「设为活跃版本」**[`:revert` 后详情+列表从真相重取])· 日志(ok/failed 聚合 + `AnRowDetail` 行展开 + loadMore;workflow flowrun 懒取节点)。**版本内容只读、AI-only**(WRK-054 拍板 #4:手工不编签名/代码/依赖;手工可编=meta——页头就地改名 + 概览说明/标签走成熟 `AnKv` 编辑模式[与 venv 段同件:说明=文本行最右铅笔、标签=`AnKvRow.tags`(hover→✕/➕,**按 ➕ 才出自聚焦输入框**,Enter 连加/Esc 收),值全部贴右垂直居中、触点共 controlSm 最右轨],PATCH 不升版)。**版本 tab**:diff 置顶(顶点恒定),结构化签名 diff 小签 + 「设为活跃版本」在 diff **下方 footer**(选版本不移 diff);`setActive` 就地重算 active 标记(选区不回弹)+ pending 防重入 + 失败 toast。 |
| **run 终端(右岛)** | `features/entities/{state,ui}/run/` | 强链选区揭示:类型化逐字段入参表单 → 执行 → `BlockTreeReducer` 渲 agent 块树(完整 block-tree,非 flat 转录)。**workflow 分支对账驱动(W3)**:`:trigger` 202 → tick(按 `flowrunId` 自滤,workflow scope 并发多 run 混流;**cancel/终态后迟到 tick 一律丢**,状态机不可被复活)upsert 活行 + 去抖 300ms `GET /flowruns/{id}` 落真相(**节点页最新在前非全量:首次对账翻页拉全,此后单页并集合并**——行 record-once 不可变,长循环 run 早期节点不退化 future、parked 行不被挤出页外)+ 4s 慢轮询兜底丢帧;run 头终态才收口(旧「拉一次定终态」已废);**parked 出审批门卡**(rendered 提示 + 通过/驳回 → `:decide`,first-wins 输了对账自纠);keepAlive 钉到终态。`autoDispose` + 后台续流。 |
| **审批收件箱(左岛铃托盘)** | `features/entities/ui/flowrun_inbox.dart` | approval 的运行时「第二张脸」(config 表单在 rail、待审在此):`FlowrunInbox` 挂 `AppShell` 铃托盘,watch `flowrunInboxProvider`(`GET /flowrun-inbox` 的 `parked` 集,`autoDispose`——开托盘取、关即弃)→ 逐卡 `_ApprovalCard`(`AnInfoCard`:标题「Awaiting approval」+ 盾图标 + `nodeId` meta + result.`rendered` 提示 + **result.`allowReason`==true 才出 `AnInput` 理由**+ 蓝 Approve/红 Reject `AnActionGroup`)→ `decideApproval(flowrunId,nodeId,decision,reason?)`(`:decide`,first-wins)→ `invalidate` 收缩列表;`_deciding` 防重入,输了 422/传输错恢复可点。跨 run 全域(非绑单实体),与右岛 run 终端的审批门是同一 `:decide` 的两个入口。四态:骨架/错(重取)/空(`inboxEmpty`)/列表。 |

## 数据缝 + state

- **唯一缝** `EntityRepository`(`features/entities/data/`):`LiveEntityRepository`(接 `ApiClient` + `SseGateway` demux)/ `FixtureEntityRepository`(内存可脚本,demo + 测试;写面同样实现并发 durable 信号走正常重取路)/ `entityRepositoryProvider` 单点 override。**写面(meta-only)**:`patchFunctionMeta`(F2)· `patchWorkflowMeta`(W2)· `revertVersion`(`:revert`)· `decideApproval`(W3,`:decide` → 202)· `replayFlowrun`(W4,`:replay` 失败 run)· `killWorkflow`(W4,`:kill` 硬停在途)· `fetchFlowrunFull`(翻页拉全节点助手)· `editWorkflow`(W5,`:edit` ops → 新版本)。fixture 的 `triggerWorkflow` **202 同形**(先返 id、异步按实体真图走:control 落 `__port`、approval 停车,tick 无 result 同线缆)。版本内容无前端写通路(AI-only,拍板 #4)。**ref 选择器候选读面**(供图编辑器 `NodeRefPicker` 分层下钻,非四大 rail 实体故走各自端点):`listMcpServers`(`GET /mcp-servers`)· `listMcpTools(server)`(`GET /mcp-servers/{name}` 的 tools 缓存)· `listTriggers`/`listControls`/`listApprovals`(`GET /triggers`·`/controls`·`/approvals`)——皆投影成精简 `RefCandidate`{id,name,meta};**`getControl`(→ `ControlLogic`,供 control 边端口下拉 `controlPortsProvider`/节点分支 peek)· `getApproval`(`GET /approvals/{id}` → `ApprovalForm`,rail 详情)· `getTrigger`(`GET /triggers/{id}` → `TriggerEntity`,rail 详情)· `listFlowrunInbox`(`GET /flowrun-inbox` → `parked` 的 `List<FlowrunNode>`,喂 `flowrunInboxProvider` 铃托盘;fixture 从 `_flowrunDetail` 派生 parked approval 节点)**;function/handler/agent 目标复用 `listEntities`,handler 方法复用 `getHandler().activeVersion.methods`(零新端点)。**trigger 观测面 + 催发**:`fireTrigger`(`POST :fire` → 202 新 activation id)· `listActivations`(`GET /triggers/{id}/activations`,`?firedOnly`,N4 分页 → `Page<Activation>`)· `listFirings`(`GET /triggers/{id}/firings`,`?status`,N4 分页 → `Page<Firing>`)——喂 `activationListProvider`/`firingListProvider`(按 `(id+过滤)` family,复用 `LogListState`+`LogRow`+`KeysetScopedPaging`,不造新类型)。辅型 `EntityKind`(现 **7 kind**:4 可执行 + **control/approval/trigger 支撑**;`verb` 支撑 kind 为 null + `executable` 能力位;支撑 kind 走同 rail/详情壳但无 run 终端/动词 CTA——**trigger 例外持 `Fire` CTA(非 run 终端)**)· `EntityRow`(统一 rail 行投影 + 徽标[+ trigger 的 `listening`] + `createdAt`/`updatedAt`)· `RefCandidate`(ref 候选精简投影 id/name/meta)· `EntitySignal`(生命周期投影)。纯模型 `NodeRef`(按 `NodeKind` parse/format ref:`fn_`/`hd_.method`/`mcp:server/tool`/`ag_`/`trg_`/`ctl_`/`apf_`,脱 widget 单测)。
- **state**(`features/entities/state/`):`entityListProvider`(AsyncNotifier.family over kind,首页 + `loadMore` keyset + SSE 就地 patch)· `railModelProvider`(扇 7 kind 成 RailGroup)· `railSortProvider` / `railShowCountProvider`(⚙ 视图偏好)· `selectedEntityProvider`(**只读、单向派生自路由 delegate**)· detail/(`entityDetail` 双流订阅 + `versionList` + `logList`,全 `autoDispose`)。
- **SSE 路由**:生命周期走 `notifications` 流(按 node.type 投影)、面板实时走 `entities` scope 流;`seq>0` durable 重取、`seq=0` ephemeral no-op。

## 状态

✅ **全落**:STEP 0(契约 DTO)→ 1(数据缝 + fixtures)→ 2(列表 state + rail VM)→ 3(rail UI)→ 4(详情海洋)→ 5(执行 + run 终端)→ 6(go_router 路由化)+ 5.5(壳 chrome:左岛收起 + 浮层头面包屑 + 红绿灯对齐)。`make fe-verify` 全绿。

**最近迭代**:实体页逐实体雕琢([WRK-054](../../../working/frontend/entity-pages.md)/[WRK-055](../../../working/frontend/workflow-page.md))——function F1–F2(meta 就地编辑 + 版本 tab 定式)已落(**变换盒 hero 试后回退**:function/handler 概览回朴素 KV 文档 + 输入/输出卡,`AnTransformBox`/`AnReadinessPipeline` 已删);**workflow W1–W2 已落**(`GraphModel`+`AnGraphCanvas` 图地基 → 概览编排图 hero + meta 编辑 + 图结构版本小签),W3 活运行/W4 驾驶舱/W5 编辑器在建。

## 复用的原语(看全 props → design-system)

`AnSidebarList`(rail)· `AnPage`(海洋滚动脚手架)· `AnOceanHeader` · `AnTabs(flow)` · `AnInspector`(右岛壳)· `AnRow`/`AnRowDetail` · `AnKv`/`AnField`/`AnEditableValue`(就地编辑)· `AnCodeEditor` · `AnGraphCanvas`(workflow hero)· `AnFadeCollapse`(代码收合)· `AnCallout`(envError)· `AnVersionDiff` · `AnStatusDot`/`AnBadge`。**全部来自 gallery,零手搓**。

## 关键决策(详见归档 WRK-046)

详情海洋 = **单文档同滚**(头+tab+内容一个滚动区,非各自滚)· run 轨迹 = **完整 block-tree**(非 flat)· 入参 = **类型化逐字段** · 选区 = **单向派生自 URL**(常量 key 壳永不重挂)· workflow 编排图可视化**推迟到图编辑器阶段**(概览只给节点/边计数)。
