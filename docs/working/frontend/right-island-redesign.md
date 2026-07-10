---
id: WRK-064
type: working
status: active
owner: @weilin
created: 2026-07-10
reviewed: 2026-07-10
review-due: 2026-10-08
audience: [human, ai]
landed-into:
---

# 右岛重构 —— 统一头 + 左岛行语言 + chat 侧幕手风琴

> **出身**：用户看现右岛（尤其 chat「侧幕」）与左岛视觉语言不一致，且侧幕「一次一个 stage」的单镜头模型不合意。经可点 HTML mockup 多轮对齐拍板（`scratchpad/right_island_mockup.html`，artifact `claude.ai/code/artifact/86379884-…`），进实现。目标 = **完整、超高质量、完整全部修改**。
>
> **执行纪律**：working 规范（本文）→ 单一作者建（地基先行）→ 对抗复审 → 真机逐帧截图验 → landed docs，`make fe-verify` 全绿每 block 收口。

---

## §1 三改点

1. **统一右岛头**（改点1）：三/四个右岛头收敛成一个形——`[可选 16 icon][小字 label(meta·emphasis·inkFaint)][动作槽][md ✕ 收岛]`，**无分隔线**，内容直接跟随（Claude「Files」式）。不再是「醒目标题 + 一条 hairline」。
2. **右岛行对齐左岛**（改点2）：右岛的行统一复用左岛 `AnRow` 语言——icon **16** · 正文 **13/w300** · 行高 **32** · 每层缩进 **20** · 未点=灰(inkMuted)、点开/命中=黑(ink) + **surfaceActive 8 圆角框（无描边）**。所有 icon（含头部按钮）一律 16px、抄左岛 Lucide 细描。
3. **chat 侧幕手风琴**（改点3，大头）：从「单镜头导演器」重构成「**粘性手风琴列表**」——对话碰过的每样东西（touchpoint）并列成一行，点任意行就地展开精心做的 stage（function→代码窗 / workflow→图 …），live 时自动展开 + 徐徐滚过去、流式播；用左岛同款展开动效。

## §2 拍板的设计细节（mockup 已过）

- **自动展示 icon = `activity`**（脉冲线）——原 `eye` 在 16px 细描下发糊，已否。
- **展开体不左缩进**——归属靠位置一眼可见，退格反而怪；展开体与行左对齐、满宽。
- **todo = 置顶一行**：永远置顶，和别的行同形同交互；只有 lead icon 换成**进度环**（16px 同 icon 包，按 done/total 算弧），**蓝=已完成**；点开=清单。
- **头右动作**（chat）：`[自动展示(activity 三档) · 展开全部 · 收起全部 · ✕]`；其它岛的头动作按需（可有可无）。

## §3 目标架构（chat 侧幕）

- **行数据** = `touchpointLedgerProvider(conv).entities`（`CastEntity`，freshest-first，R-2 聚合，现成）。rowId = `'$kind:$key'`。
- **展开态**（新建）`stageExpansionProvider(conv)` → `Set<rowId>`，**外置粘性**（真相在 provider，ListView 虚拟化 dispose 行不丢展开态；不用 KeepAlive）。用户手点展开的行**永不自动收**（= per-row pin，对应「点开一直开着除非再点」）。
- **live↔行 join**（新建）`liveActivityByRowProvider(conv)`：收集导演器 `subject + channels` 全部 live view → `Map<rowId, StageActivityView>`（match key = `(kind,itemId)`）。
- **展开体喂养**：live 行 → `liveBlock(blockId)→ToolCardState.of→StageScene(live)→stageBodies[kind]`（零改复用）；settled 行 → 新建缝 `sceneFromTruth(kind,id)`（从 `state/stage_truth.dart` 的 `*TruthProvider` 快照合成 `StageScene(live:false)`，喂同一 body）。无 TruthProvider 的 kind（conversation 等）落触点聚合面。
- **live 规则引擎**：复用导演器 `stageRouteOf` / `FollowMode` 三档 / `entranceDebounce=500ms`（`_entranceDue` Map 天生支持 N 行并发）/ `lifecycle+onRunTerminal` R-10 落定 / `nextDeadline+advance` 单 Timer / `_onFrame` 帧投影三表。**删** `_subject/_arbitrate/channels/StagePhase/settleBreath curtain`。**新增 per-row** `autoExpandedOnce`/`autoScrolledOnce`/全局 `takeover` 旗。
- **todo 行**：`rundownProvider`（现成），lead=`AnTaskRing(done,total)`，展开=per-board `AnRundownList`。
- **行原语**：`AnDisclosure`（常驻 chevron，别手搓）承载 kind glyph + 名 + verb·count + activityBit + lastAt；展开体走 `AnExpandReveal`。

## §4 live 三规则落地（据最佳实践）

1. **粘性展开**：展开态外置 provider；用户 toggle 打「手动」标记后规则引擎永不自动收。
2. **不跳**：`_StageScrollCoordinator` 持 `Set autoScrolledOnce`——某行**首个 live 帧**（过 500ms 登台防抖）才 `Scrollable.ensureVisible(alignment:0.5)`，且**仅目标在视口外**才滚、未构建（远在外）=不追；行内流式 delta **永不触发滚动**；同帧多行首登场仲裁只滚一项。
3. **不抢**：`NotificationListener` 收 `UserScrollNotification`（方向非 idle）→ `takeover=true` 立即停自动滚；`ScrollEndNotification` 且 near-bottom（`pixels >= max-80`，不用 `atEdge`）→ 恢复。`ScrollUpdateNotification` 一律不改 takeover（防 `ensureVisible` 期间自锁）。center 锚方向语义**写探针核对别猜**。切会话清空 `autoScrolledOnce` + `takeover=false`。

## §5 建造顺序（每步可独立编译 + 验证）

- **Block A｜改点1 统一头** — `AnInspectorHead` 新 API（`label` 小字 · `actions:List` · `onClose+closeSemantics` · 无 divider）+ 3 调用点（documents/workflow-editor/stage_panel）+ run_terminal 手搓头跟样式 + gallery specimen。**✅ 已落**（见 §6）。
- **步1** `stageExpansionProvider`（地基缝，外置粘性 Set）。
- **步2** 行原语 `stage_accordion_row.dart`（`AnDisclosure` 头 + `AnExpandReveal` 体，纯 prop）。
- **步3** `sceneFromTruth`（settled 展开体缝，**最高风险，先做透**）。
- **步4** 各 kind body 接线（live/settled 分派；抽 `LiveStageBody`）。
- **步5** todo 置顶进度环行。
- **步6** live 规则引擎 + 自动滚（改 `StageDirector` 删单主角、`liveActivityByRowProvider`、`_StageScrollCoordinator`）。
- **步7** 统一头动作（chat 头终态：activity 三档 + 展开/收起全部 + ✕=收岛）+ i18n 增删（新 `expandAll/collapseAll/tasks`，废 `moreChannels/livePill/ensembleTitle`，`follow.*/a11y.*` 改值）+ 退役 `eye`。

## §6 建造进展

- **Block A ✅（2026-07-10）**：`AnInspectorHead` 改新 API（`title→label` 小字 meta·inkFaint / `trailing→actions:List` / 新 `onClose+closeSemantics` 一等 ✕ / 可选 icon / 从不画 divider）；`documents_inspector`·`workflow_editor_inspector` 去 head 下 `AnDivider`、改 `onClose`；`run_terminal` 手搓头名行改小字 meta·inkFaint + 去 divider；`AnIcons` 增 `activity/unfold/fold`；gallery 增「label + actions + close」specimen。**决策**：头 label 保留各岛主体身份（文档名/实体名/节点 id）的**小字形**（比 mockup 的通用词「页面/运行」低风险、不丢信息、零新 i18n 键；chat 用「活动」）——**待用户确认是否改回通用词**。真机双验（documents+entities run 两岛头小字 faint + 无线）。

- **Block C（改点3+2 手风琴）✅（2026-07-10）**：`stage_panel` 从单镜头导演器重写成粘性手风琴列表。**关键低险裁决**：**director 不重写**——其单 subject 仲裁天然=「自动展开谁」的信号,并行 live 只有被仲裁那个自动展开、其余静默 live 行(可手点),正好是「不跳」；A 组 director 测因此全过。新建 `stageExpansionProvider`(外置粘性 Set,带单测)。行=左岛 `AnRow`(collapsible hover-swap chevron + selected→surfaceActive 框 + 新 `trailingDot` live 蓝点)+ 去缩进 `AnExpandReveal` 体。展开体:有 live block→复用 `_GenericStage`(**去 brow**,行头即身份,body 只留 stage 内容);无→`_SettledBody`(id+动词史+跳转/去实体页)。todo=置顶行(`AnTaskRing` lead + 展开 `AnRundownList`)。头终态=活动 label + `_FollowMenu`(activity icon)+展开/收起全部+✕收岛。live 三规则:`_AccordionList` 的 `_StageScrollCoordinator`(autoHandled 每 live 一生一开一滚 + `Scrollable.ensureVisible(0.5)` 仅视口外 + `UserScrollNotification`→takeover 挂起自动滚、near-bottom 恢复);itemId 未解出用 blockId 键、解出后迁移。i18n 增 `island/tasks/expandAll/collapseAll`。**v1 已知取舍**:未建 `sceneFromTruth`(settled 老行展开=摘要非全 stage,近期/live 行才全 stage);attachment 展品座暂降为通用摘要;并行未 resolve 的 channel 可能瞬时重复行。5 个旧布局测已改写到手风琴行为(AnCastRow→AnRow / todo 展开才见清单 / 行内展开非 exhibit / 落定不谢幕留行)。**真机验收**:并列 touchpoint 行(左岛 AnRow 语言)+ 点开=黑字+surfaceActive 框 + 去缩进展开体(id/动词史/去实体页)+ 统一头(活动/activity/展开全部/收起全部/✕、无线),cv_sync 会话逐帧核对。

- **sceneFromTruth ✅（2026-07-10，用户拍板「非常核心」）**：消除「旧 settled 行只显摘要」取舍——点**任何** touchpoint 行都渲完整精心 stage(function→代码/workflow→图/control→判别梯/agent→人格台/handler→方法架/approval→信笺/document→prose/trigger→哨位),不分新旧。**核心裁决**:不新造 scene 语义,**复刻生产 recipe**——真身序列化成 args-JSON→塞进合成 `BlockNode(toolCall,completed)`→`ToolCardState.of` 自派生 session→`StageScene(live:false)` 交给同一 bespoke 体,零行为分叉。拆(A)纯核心 `sceneFromTruth`(无 Ref/async,8 kind 单测)+(B)`StageBodyFromTruth` wrapper(watch *TruthProvider,data→bespoke/loading·error→SettledBody 摘要兜底)。toolName 默认 `create_KIND`(editTargetId null,纯渲真身无 diff/地层);trigger/document 用 `edit_KIND` 点亮活事实条/字节徽。逐 kind args-JSON 由 7-agent 并行读码写映射(字段逐字核):workflow 合成 add_node/add_edge ops(内联 graphOf 免跨 feature)、control branches、agent tools+modelOverride→modelId 投影、handler set_init/add_method/set_shutdown/schema ops。**body 改 2 处**:agent prompt 窗 settled 去 tailLines 显全文;handler init/shutdown 窗 settled 走 AnCodeEditor(reading)。展开才 GET(收起零请求)、tombstone 绝不 GET、无活版本降摘要。**留摘要的边缘 kind**:attachment(展品座)/subagent(嵌套重水合)/skill/memory/mcp/conversation(暂无 snapshot provider,可后补)。demo fixture 补种 wf_night 图 + doc_runbook prose 供真机展示。`SettledBody` 从 stage_panel 移入 scene_from_truth 公开化。规范来源:理解工作流 tasks/wpvfwernj.output + 映射工作流 tasks/wz5a5wbp3.output。**真机三旗舰验**:function→代码/workflow→图/document→prose。**对抗复审 4 修**(6 候选全确认,合去重):①handler 空 initBody/shutdownBody 不发 set_init/set_shutdown op(否则捏造亮轨段+空编辑器),ops 全空返 null;②workflow add_node 带 `input` CEL map(判别式抽屉读 node['input'],原丢块);③document_stage 字节徽加 `settled != baseline` 守(内容没变=纯真身渲染,不显幻影「X B→Y B」;CJK bytes-vs-chars 幻影根除,path chip+prose 留);④content-less 版本(空图/零 branch/空码/空文/handler 无 op)一律 return null→降 SettledBody 摘要,不渲空白舞台。加 4 回归测。fe-verify 3331 全绿。

- **边缘 kind 纳入 ✅（2026-07-10,用户「边缘 kind 都需要」）**：探查工作流(tasks/wdyx3pao9)诚实判定 5 个边缘 kind 里 **3 可建、2 结构性不可达**——①**attachment**→展品座(提取 exhibit 的 `_AttachmentPedestal` 成公开 `AttachmentPedestal`,`_StageRow` settled 分支 attachment case 优先;不走 sceneFromTruth[无 stage body/无真身];**删死码** exhibit_stage.dart + exhibit_provider.dart[WRK-064 后无引用])②**skill**→sceneFromTruth(GET /skills/{name} 已有;chat repo 加 getSkillSnapshot + skillTruthProvider,args={name,context,allowedTools,disableModelInvocation,body},SkillStageBody body settled 显全文;id=name,create_skill)③**mcp**→sceneFromTruth(GET /mcp-servers/{name} 已有;getMcpSnapshot + mcpTruthProvider,args={name,tools:[names]}省 env,McpStageBody `_resultTools` 加 args 回退;id=name,create_mcp)。**2 不可达(诚实标注,非偷懒)**:**memory** 在后端 noTouch 名单(catalog.go:162)→ 永不产触点行 → 侧幕 ledger 永无 memory 行 → sceneFromTruth 触不到(端点在但不可达);**subagent** 无 executionId/表/端点,真身=LIVE-only 嵌套子消息(前端 hydration 现丢弃)+ 不产触点 → 需 B6 reload 重水合缝(跨切工作,待立项)。demo cv_sync 补种 skill(commit-helper)+mcp(github) 触点及快照。加 skill/mcp 单测。fe-verify 3333 全绿。至此侧幕**可点行的每一种实体都渲完整真身舞台**(8 Quadrinity/config + skill + mcp),attachment 展品座,memory/subagent 有据可查地留白。

- **Block C 对抗复审修复 ✅（2026-07-10）**：3 维度(状态迁移/滚动布局/泄漏边界)对抗复审 6 候选 → 证伪 3、**确认 3 全修**:①**HIGH** load-more 脚在 itemBuilder(build 期)同步调 `loadMore()` 变异被 watch 的 ledger provider → 触发 Riverpod「build 期改 provider」守卫抛错 + 分页永久卡死 → 改 `addPostFrameCallback` 延迟出 build(+60 触点回归测);②**MED** 切会话时 `_takeover`/`_autoHandled` 残留(壳无 per-conv key,State 复用而 provider 重建)→ 新会话 live 自动展开却不自动滚入 → 加 `didUpdateWidget` 按 conversationId 重置;③**MED** `_isNearBottom` 复位锚对顶锚列表方向反了(live 在顶部,却要滚到底才重武装自动跟随)→ 翻转成 `_isNearTop`(pixels≤minExtent+80)。`make fe-verify` 3319 测全绿。

## §7 待用户拍板 / 签字

- **Block A 头 label**：主体名小字（现行）vs mockup 通用词「页面/运行」——待确认（改回通用词=换 label 串 + 加 2 i18n 键 + run_terminal 名挪 body，低成本）。
- §8 五决策已自裁（documents 头统一 / settled 渲 TruthProvider 快照 / 落定不自动收 + 洗亮 / exhibit 去实体页降为行内动作 / 用户展开永不自动收），可否决。
- 真机逐帧截图每 block 验收；chat 侧幕手风琴落地后需用户真机签字（live 三规则的手感）。
