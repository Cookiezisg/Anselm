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

## 四个面

| 面 | 在哪 | 是什么 |
|---|---|---|
| **rail(左岛)** | `features/entities/ui/entity_rail.dart` | `EntityRail` over [`AnSidebarList`]:4 kind 折叠段 + 实体行(状态点)+ 域内过滤 + ⚙ 菜单(排序 最近活跃/创建/名称 + 显示分组计数)+ 四态(骨架/错/空/列表)。选择 = `context.go` 改 URL。 |
| **ocean(中心)** | `features/entities/ui/detail/` | `EntityOcean` = **单一 `AnPage` 文档**(头 + tab + 720 阅读列**一起滚**):`AnOceanHeader`(面包屑 + 名称[function/workflow 就地改名→meta PATCH] + 状态徽[workflow 含 vN·生命周期·并发·attention] + 动词 CTA)+ `AnTabs(flow)`(概览/版本/日志)+ 4 kind 各自概览。 |
| **detail(tab 内容)** | `features/entities/{state,ui}/detail/` | 概览(function = **`AnTransformBox` 变换盒 hero**[签名即接口:inputs→盒→outputs 一张图,env 灯+py·deps meta] + 代码 **50 行渐隐收合**[`AnFadeCollapse`] + 环境合卡[venv KV + deps,envError `AnCallout` 红字直出];**workflow = `AnGraphCanvas` 编排图 hero 置顶**[framed 定高自动 fit + 缩放工具条,`graphOf` 解析、坏 blob 诚实 inset `graph.unparseable`;**hero 活态(W3)**:watch 右岛同一 `runTerminalProvider`,触发过即 `deriveRunState` 点亮(taken 加粗/彗星/呼吸/×N)——页 hero=仪表盘、右岛=操作台] + meta 就地编辑[说明/标签,同 function 的 AnKv 件,`patchWorkflowMeta` 不升版] + id·版本·节点边计数 KV + 运行治理合卡 + 告警,WRK-055 W2;余 kind 暂 AnKv/AnField/AnCodeEditor 罗列,逐个雕琢中 WRK-054)· 版本(`AnVersionDiff` 相邻版本 + **结构化 diff 小签**[function=签名字段/依赖/py `functionVersionSummary`;workflow=图结构 节点按 id/边按端点+口 `workflowVersionSummary`,graph blob 经 `prettyJsonSource` 美化后才有行可 diff;页边界行无签] + **「设为活跃版本」**[`:revert` 后详情+列表从真相重取])· 日志(ok/failed 聚合 + `AnRowDetail` 行展开 + loadMore;workflow flowrun 懒取节点)。**版本内容只读、AI-only**(WRK-054 拍板 #4:手工不编签名/代码/依赖;手工可编=meta——页头就地改名 + 概览说明/标签走成熟 `AnKv` 编辑模式[与 venv 段同件:说明=文本行最右铅笔、标签=`AnKvRow.tags`(hover→✕/➕,**按 ➕ 才出自聚焦输入框**,Enter 连加/Esc 收),值全部贴右垂直居中、触点共 controlSm 最右轨],PATCH 不升版)。**版本 tab**:diff 置顶(顶点恒定),结构化签名 diff 小签 + 「设为活跃版本」在 diff **下方 footer**(选版本不移 diff);`setActive` 就地重算 active 标记(选区不回弹)+ pending 防重入 + 失败 toast。 |
| **run 终端(右岛)** | `features/entities/{state,ui}/run/` | 强链选区揭示:类型化逐字段入参表单 → 执行 → `BlockTreeReducer` 渲 agent 块树(完整 block-tree,非 flat 转录)。**workflow 分支对账驱动(W3)**:`:trigger` 202 → tick(按 `flowrunId` 自滤,workflow scope 并发多 run 混流)upsert 活行 + 去抖 300ms `GET /flowruns/{id}` 落真相 + 4s 慢轮询兜底丢帧;run 头终态才收口(旧「拉一次定终态」已废);**parked 出审批门卡**(rendered 提示 + 通过/驳回 → `:decide`,first-wins 输了对账自纠);keepAlive 钉到终态。`autoDispose` + 后台续流。 |

## 数据缝 + state

- **唯一缝** `EntityRepository`(`features/entities/data/`):`LiveEntityRepository`(接 `ApiClient` + `SseGateway` demux)/ `FixtureEntityRepository`(内存可脚本,demo + 测试;写面同样实现并发 durable 信号走正常重取路)/ `entityRepositoryProvider` 单点 override。**写面(meta-only)**:`patchFunctionMeta`(F2)· `patchWorkflowMeta`(W2,name/description/tags/concurrency)· `revertVersion`(`:revert`,kind 通用签名)· `decideApproval`(W3,`POST /flowruns/{id}/approvals/{node}:decide` → 202 快照)。fixture 的 `triggerWorkflow` **202 同形**(先返 id、异步按实体真图走:control 落 `__port`、approval 停车,tick 无 result 同线缆)。版本内容无前端写通路(AI-only,拍板 #4)。辅型 `EntityKind`(4 kind 的 REST/scope/verb 常量)· `EntityRow`(统一 rail 行投影 + 徽标 + `createdAt`/`updatedAt`)· `EntitySignal`(生命周期投影)。
- **state**(`features/entities/state/`):`entityListProvider`(AsyncNotifier.family over kind,首页 + `loadMore` keyset + SSE 就地 patch)· `railModelProvider`(扇 4 kind 成 RailGroup)· `railSortProvider` / `railShowCountProvider`(⚙ 视图偏好)· `selectedEntityProvider`(**只读、单向派生自路由 delegate**)· detail/(`entityDetail` 双流订阅 + `versionList` + `logList`,全 `autoDispose`)。
- **SSE 路由**:生命周期走 `notifications` 流(按 node.type 投影)、面板实时走 `entities` scope 流;`seq>0` durable 重取、`seq=0` ephemeral no-op。

## 状态

✅ **全落**:STEP 0(契约 DTO)→ 1(数据缝 + fixtures)→ 2(列表 state + rail VM)→ 3(rail UI)→ 4(详情海洋)→ 5(执行 + run 终端)→ 6(go_router 路由化)+ 5.5(壳 chrome:左岛收起 + 浮层头面包屑 + 红绿灯对齐)。`make fe-verify` 全绿。

**最近迭代**:实体页逐实体雕琢([WRK-054](../../../working/frontend/entity-pages.md)/[WRK-055](../../../working/frontend/workflow-page.md))——function F1–F2(变换盒 hero + meta 就地编辑 + 版本 tab 定式)已落;**workflow W1–W2 已落**(`GraphModel`+`AnGraphCanvas` 图地基 → 概览编排图 hero + meta 编辑 + 图结构版本小签),W3 活运行/W4 驾驶舱/W5 编辑器在建。

## 复用的原语(看全 props → design-system)

`AnSidebarList`(rail)· `AnPage`(海洋滚动脚手架)· `AnOceanHeader` · `AnTabs(flow)` · `AnInspector`(右岛壳)· `AnRow`/`AnRowDetail` · `AnKv`/`AnField`/`AnEditableValue`(就地编辑)· `AnCodeEditor` · `AnTransformBox`(function hero)· `AnGraphCanvas`(workflow hero)· `AnFadeCollapse`(代码收合)· `AnCallout`(envError)· `AnVersionDiff` · `AnStatusDot`/`AnBadge`。**全部来自 gallery,零手搓**。

## 关键决策(详见归档 WRK-046)

详情海洋 = **单文档同滚**(头+tab+内容一个滚动区,非各自滚)· run 轨迹 = **完整 block-tree**(非 flat)· 入参 = **类型化逐字段** · 选区 = **单向派生自 URL**(常量 key 壳永不重挂)· workflow 编排图可视化**推迟到图编辑器阶段**(概览只给节点/边计数)。
