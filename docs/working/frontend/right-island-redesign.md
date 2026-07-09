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

- **Block A ✅（2026-07-10）**：`AnInspectorHead` 改新 API（`title→label` 小字 meta·inkFaint / `trailing→actions:List` / 新 `onClose+closeSemantics` 一等 ✕ / 可选 icon / 从不画 divider）；`documents_inspector`·`workflow_editor_inspector` 去 head 下 `AnDivider`、改 `onClose`；`run_terminal` 手搓头名行改小字 meta·inkFaint + 去 divider；`stage_panel` 头最小适配到新 API（保留 dismiss 行为，✕ 经 onClose 自动升 md/16px；完整重构留步7）；`AnIcons` 增 `activity/unfold/fold`；gallery 增「label + actions + close」specimen。**决策**：头 label 保留各岛主体身份（文档名/实体名/节点 id）的**小字形**（比 mockup 的通用词「页面/运行」低风险、不丢信息、零新 i18n 键；chat 用「活动」），mockup 通用词偏成主体名小字——**待用户确认是否改回通用词**。`make fe-verify` 3315 测全绿。

## §7 待用户拍板 / 签字

- **Block A 头 label**：主体名小字（现行）vs mockup 通用词「页面/运行」——待确认（改回通用词=换 label 串 + 加 2 i18n 键 + run_terminal 名挪 body，低成本）。
- §8 五决策已自裁（documents 头统一 / settled 渲 TruthProvider 快照 / 落定不自动收 + 洗亮 / exhibit 去实体页降为行内动作 / 用户展开永不自动收），可否决。
- 真机逐帧截图每 block 验收；chat 侧幕手风琴落地后需用户真机签字（live 三规则的手感）。
