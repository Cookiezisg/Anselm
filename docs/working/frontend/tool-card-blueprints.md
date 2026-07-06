---
id: WRK-056
type: working
status: active
owner: @weilin
created: 2026-07-06
reviewed: 2026-07-06
review-due: 2026-10-04
audience: [human, ai]
---

# 工具卡完美态蓝图 —— 113 工具逐个设计(2026-07-06 已拍板)

> **这是什么**:chat 工具卡 pivot 初衷(「每个 tool call 都是量身插件级呈现,核心动作**纯可视化看见变化本身**——图长出来、代码被写出来、旧图 morph 成新图」)的全量设计蓝图:**113 具名工具 + MCP 动态族 + mount 附节,17 族逐工具**给出收起行 / 活期生长秀 / 落定体 / edit morph / 退化态 / 新原语 / 可行性注记。
> **怎么来的**:64-agent 编队——12 路普查(9 路后端契约逐工具提取 + 框架机制 + 前端乐器盘点 + 图画布勘探,见底册 [`tool-card-census.md`](tool-card-census.md))→ 17 族设计师(共同宪法约束)→ 17 路对抗审察(可行性谎言 / 诚实违规 / 性能陷阱 / 文法破坏)→ 修订落回 → 总合成裁决 12 处族间冲突。
> **状态**:**已拍板(2026-07-06)**——B1–B7 建造顺序认可;第四章 10 题:**第 1 题用户改判「保留两套」**(Subagent=SubTranscriptFrame / invoke_agent=NestedRunPane,R1 裁决被推翻),其余 9 题按推荐(取数缝允许统一一条、后端小改包 6 项全做、时间语义/chip 单热区/settled 禁呼吸/HitList 归一/generic 地板 B2 后穿插/P2 挂起)。拍板已重述进 [`tool-cards.md`](tool-cards.md)(WRK-053)§1/§6;本文是逐族实施的设计事实源,随批次落地逐族勾销、终归 archive。
> **引用约定**:族文内「census 01–10 / palette / graph」指底册对应章;「palette 缺口 #N」指底册 palette 章缺口清单。母文档 [`chat.md`](chat.md)。

---

# 工具卡完美态设计宪法(所有设计者共同法律)

## 使命(用户原话意译 —— pivot 初衷)

每一个 tool call 都要做成**量身的插件级呈现**,核心动作要**纯可视化地看见变化本身**:
- create_workflow:看到那张图**一点点长出来**(节点浮现、边接上);
- edit_workflow:看到旧图**怎么一点点变成新图**(morph,不是两张静态截图);
- create_function:看到代码**怎么被写出来**;
- 所有核心能力,都是「特别可视化地看它怎么变化」。

你的任务:给你负责的族里**每一个工具**设计它的「完美态」——想象这个工具是一个被顶级产品团队
精心打磨的专属插件,它的收起行、活期(执行中)、落定体各应该是什么样子。要给出让人眼前一亮的
设计,同时每一笔都锚定线缆现实(census 文件里的真实契约)。

## 已拍板的地基(不可违背)

1. **收起行 = 无边框裸行 32px**:确定性动词(进行时→过去时)+ 等宽目标 chip + 灰回执尾。
   LLM 自报 summary 只进展开体(危险族在窗上方常显)。有展开体才有 chevron。
2. **机器窗口身份**:tool call 是对外部世界的**操作**、非模型内心低语——机器产物一律住
   `ToolWindow` 凹陷等宽窗(或更专门的窗:代码窗 AnCodeEditor / diff 窗 AnVersionDiff / 图画布),
   **绝不**借 thinking 的低语语法(无左竖线 rail、无裸散文)。
3. **状态机七相位**(派生自线缆,不存储):args 流入 → [等待确认] → 执行中 → 成功/失败/拒绝/中断。
   失败(或危险色族回执,如 exit≠0)自动展开一次;完成后收拢——历史读起来像目录不像日志。
4. **诚实铁律**:回执绝不猜(解析不匹配就无回执);截断必有显式注记;截断计数显示 N+;
   空结果诚实说「无匹配」;半成功(如 env 构建失败)必须显性。
5. **字号双轨**:内容 15 / 内容标签 13 / 内容代码 codeReading(mono 13) / 机器窗终端类 code 12;
   收起行动词 13;两档字重 w300/w400,禁更重。
6. **reduced motion 全等价**:一切动效可即时化,信息零丢失。
7. **i18n**:一切文案 slang 双语;动词对给中文,英文自然对应。
8. **性能**:流动期逐 delta 重渲必须便宜(流动中纯等宽不高亮、落定换高亮;图增量呈现不得全图
   重排每帧);transcript 行**绝不**背无界滚动区——重内容有界视口 + 「查看全文」逃生口。
9. **克制也是完美的一部分**:呈现深度要配得上工具的分量。delete/revert 之类就该是薄卡
   (一行 + 凭据 + 危险确认),不是每个工具都要秀。完美 = 恰如其分,不是堆料。

## 每工具输出格式(紧凑,10~25 行/工具;薄卡族可 5~10 行)

### `tool_name` — 动词对(正在X → 已X)
- **收起行**:icon · 动词 · 目标 chip 来源(哪个 arg,怎么截断)· 回执(从输出哪个字段/格式解析)
- **活期(生长秀)**:执行中用户看到什么在生长/变化;⚠️数据源必须标注:`args-partial`(流中可提)
  / `progress 流` / `settle-only`(只能落定后呈现,活期退化为什么样子)
- **落定体**:展开后的完美陈列(用什么窗/原语,布局,哪些字段,上限与逃生口)
- **morph**(edit/revert 类才有):旧→新的变化可视化设计
- **退化态**:空 / 超限 / 解析失败 / 部分成功 各是什么样子
- **交互**:deep link(跳实体面板/右岛)、复制、逃生口
- **新原语**:需要新建什么组件(或「复用 X」);新原语给一句能力描述
- **Wow**:一句话——为什么这个设计让人惊喜
- **可行性**:线缆注记(args 流入顺序不可控、字段是否可 partial 提取、输出大小风险等)

## 设计母语(启发方向,不设上限)

- **「生长」按数据类型有母语**:代码在代码窗里被打字出来;图在画布上节点浮现、边接上、布局呼吸;
  文档像被排版的稿子流出来(渲染态,不是 markdown 源码);清单逐项点亮;JSON 配置成形为 KV/表单。
- **「morph」母语**:代码=diff 窗;图=节点新增浮现(绿晕)/删除淡出(红晕)/修改脉冲;
  属性=delta chips(`name: a → b`);版本=时间轴上 vN → vN+1。
- **落定体是成果的陈列,不是日志**:build 给结果条(id·vN·env 三色);run 给输入/输出对陈;
  search 给可点命中列表;get 给实体卡摘要。
- **活感层次**:流光动词(已有)< 读秒(已有)< 活尾巴窗(已有)< **内容本身在生长**(本次的野心)。
- 想想业界最好的:Claude Code 的 diff 流、Cursor 的 agent 面板、Vercel AI Elements、
  Linear 的 issue 卡、Raycast 的插件卡——然后为「本工具在本产品里」量身,不照抄。

## 你必须做的

1. 先 Read 你族对应的 census 文件(拿到每个工具的**精确** args/输出契约)+ palette.md(前端原语清单);
   涉图的族再读 graph.md。
2. 逐工具按格式输出到你的设计文件(Write 覆盖写);文件开头给族级「统一文法」一段
   (本族共享的视觉语言,避免逐工具重复)。
3. 结尾给「族级新原语汇总」+「建造顺序建议(族内)」。
4. 返回 JSON(不是文件内容):family/file/toolCount/newPrimitives/highlights(3 条内)/risks。


---


# 合成总纲(统一语言 · 原语总表 · 建造顺序 · 拍板清单)

> 输入:上章宪法 + 下方 F01–F17 全部 17 族设计。本章把 17 份族设计收敛成**一套语言、一张原语总表、一条建造顺序、一份拍板清单**;族内细节(逐工具收起行/活期/落定/退化)以各族章节为准,本章只裁族间共性与冲突。

---

## 第一章 统一设计语言

### 1.1 生长母语(按数据类型,全系统只有六种「生长」)

17 族收敛后,活期「内容本身在生长」只有六种物理形态,任何工具的活期必属其一(或诚实地 settle-only):

| 母语 | 载体(唯一实现) | 消费族 |
|---|---|---|
| **代码被打出来** | 活代码窗 = ToolLiveTail(倒扫尾 N 行、纯 mono 不高亮;落定才换 AnCodeEditor 高亮成品) | F01 Write、F04 fn/hd、F11 write_memory、F15 prompt 任务书 |
| **终端在滚** | AnTermTail(ToolLiveTail + termFold/ansiSpans ANSI 层)/ ToolStageTail(+ stage 标签层) | F03 Bash、F08 call_handler yields、F13 install、F14 progress |
| **稿子流出(排版态)** | ProseWindow live 态(定高底对齐 + 顶缘渐隐;双模:纯 Text 尾钳 / AnMarkdown 尾窗切片) | F04 agent/doc/skill/approval、F10 WebFetch 摘要 |
| **表单/配置成形** | LiveKvForm(partial JSON 逐键闭合点亮)/ op ticker + chip 流(partialJsonEvents 驱动) | F14 mcp/generic、F04 workflow ops、F04 trigger config、F16 ask options |
| **清单逐项点亮** | TodoChecklist 活窗 / method chips / 装备架 RefPill 次第亮 | F11 todo_write、F04 create_handler/agent |
| **图长出来** | **不在流中画**——settle-then-replay:AnMiniGraph 几何冻结后按拓扑 rank 揭示(GraphRevealState) | F04 create/edit_workflow(旗舰) |

**族级铁律(全体通过,写死)**:流动期渲染必须便宜——尾提取一律倒扫 O(尾窗)/帧、args 解码一律增量(argStringPartial 增量化)、markdown 只喂有界尾切片、图绝不流中重布局;settle-only 的族**不造假活窗**(F02/F05/F06/F07/F09/F12/F17 全员声明,克制即完美)。

### 1.2 morph 母语(edit 类的变化可视化,五种笔法)

| 补丁风格(线缆语义) | morph 笔法 | 用者 |
|---|---|---|
| 整段替换(ops) | before 懒取 → AnVersionDiff(过 diff 尺寸门:>50KB/2000 行退双段对陈+注记) | edit_function/agent prompt/document |
| merge patch | **触碰 chips**(键出现即列)+ AnDeltaChip `key: old→new`(旧值取缓存,取不到只渲新值) | edit_agent、update_method、update_meta |
| 整体替换快照 | **全新快照渲染,绝不渲「未变」**;before 可得才叠行级 diff | edit_control/approval/skill、trigger config |
| 局部手术 | 两幕 −/+ 素窗(ToolEditLivePane)→ 落定 LCS diff | F01 Edit |
| 指针回拨/图 delta | AnVersionRewindChip `⤺ vN` 单端倒带 / GraphMorphState(绿晕浮现·红名册退场·脉冲) | revert 六联、edit_workflow |

统一原则:**morph 素材必须全部来自线缆或诚实懒取**——旧值不在手就不假装双端(单端陈述 + 「无旧版对比」注记),F04/F05/F11/F17 各自独立得出同一结论,升为宪法级共识。

### 1.3 窗身份谱系(全系统只有四种「窗」+ 一种低语)

1. **ToolWindow 机器窗**(凹陷 mono 12):一切机器产物——终端、命中列表、台账、JSON、错误全文。绝不渲 markdown 排版(格式未知即 mono)。
2. **ProseWindow 散文/阅读窗**(AnSunkenPanel bubble inset,15/1.6):写给人读的内容——WebFetch 摘要、文档正文、审批模板、记忆正文。凹陷容器身份不变、只换排版。**裁决:F04 ToolLiveWindow、F06 ToolReadingWindow、F10 ProseWindow 三者合一件**(live 双模 + settled AnMarkdown)。
3. **ToolInteractionGate 人闸**(白岛感、非凹陷):唯一「等人动手」的形状——ask 问答与 V6 危险确认共用;决议后冻结成章。
4. **SubTranscriptFrame 嵌套对话框**(左缩进 + accent 竖界 + 身份行):子代理的「小对话」第三身份——既非机器窗也非 thinking 低语;全注册表递归复用。
5. thinking 低语(左 rail 散文)——**工具卡永远不借**(宪法既定)。

**裁决 R1(族间最大冲突)**:F08 invoke_agent 的 NestedRunPane(ToolWindow mono 行)与 F15 SubTranscriptFrame 是同一物的两套设计。合成曾裁「SubTranscriptFrame 唯一、删 NestedRunPane」——**用户 2026-07-06 改判:保留两套**:Subagent(对话内的小对话,全注册表递归)= SubTranscriptFrame;invoke_agent(执行一个实体)= NestedRunPane 轻量运行窗(F08 章原设计有效,恢复为 F08 专属原语,不入总表 50 件计数)。落定差异照旧:Subagent 有耐久 sub-message 可重水合,invoke_agent 落定收拢成「轨迹·N 步」深链(不重放)。

### 1.4 回执文法(全族一部宪法,tool_receipts.dart 单源)

- **确定性解析,绝不猜**:回执只从输出精确字段/锚定模板解析;不匹配 = 无回执(Read 系)或**灰「结果未确认」**(写盘/manage 类——过去时动词旁的空回执会被读成成功);**mismatch ≠ 失败**(F05 三值裁决:模板漂移不得渲假失败)。
- **tone 三色**:none / warn(琥珀半态:draining、软删、内存抹除、未激活)/ danger(→ 自动展开一次)。**截断 ≠ 失败**(F14 裁决:「截 X/Y KB」灰、不 danger 不自动展开)。
- **计数语法**:精确 `N` > 截断 `N+`(只知下界)> 分数 `N/M`(服务端截断);空结果诚实说「无匹配/空/无输出」且 bodyless(回执即卡)。
- **「档案 vs 本次」语义**:历史里的 failed 是被查看的信息(恒灰,体内红徽章),本次执行的 failed 才染 danger(F06/F09 一致);cancelled 恒中性灰、不自动展开(F03/F08/F16 一致)。
- **假成功真失败三机制**(按线缆形态分派):①结果内失败(JSON error 键/status)→ classifyResult 缝改 failed 相;②散文模板(document 系/web 族)→ 锚定分类器(F10 的 URL 绑定判别防散文假阳性是全族标杆);③半成功(env failed、runtimeWarning、连接失败仍落盘)→ 必须显性(warn 卡/结果条)。
- **动词缝**:`verb(t,{live,state})` 统一签名(F05/F07/F17 三处同一诉求);动词特化只在 args 完整后生效(argsStreaming 期恒通用对,禁流中翻面)。

### 1.5 其余族间不一致裁决

- **R2 ToolHitList 三重发明**(F02 命中窗 200 行 stagger / F07 实体命中 20-30 行级联 / F17 对话行 28px + F10 WebHitList):**合一件参数化**——行 = glyph/主文(15 值档)/次行(13)/尾 meta builder;封顶数、footer 双态(本地超封顶逃生口 vs 服务端截断注记)、点亮策略、fold 阈值皆参数;「亲历落定 → 首次挂载播一次」的两级判定(F07 版最严谨)为唯一动效契约。
- **R3 复制家族五重发明**(F03 actions 槽 / F05 顶栏整卡复制 / F06 复制全文 / F10 WindowCopyButton / F14 onCopy):**一次收口**——ToolWindow `actions` 头槽 + 独立 `WindowCopyButton`(ToolWindow/ProseWindow 双挂载)+ `copyPayload` 语义(复制未截断全量,渲染截喂复制不截,F01/F06 同一诉求)。
- **R4 收起行 chip 交互**:F01 AnPathChip「点击复制」与 F03「收起行纯展示、32px 整行是展开热区」冲突。**裁 F03 全局化**:收起行 chip 只 hover tooltip;copy 落展开体。
- **R5 settled 呼吸**:F09 running 呼吸环与 F03「settled 底条禁一切呼吸」冲突。**裁禁**——settled 卡是历史快照,running 渲静态 accent 点 + 「快照时点」措辞;呼吸只属于底盘真活期相位与 ToolInteractionGate 等待态。
- **R6 时间格式**:F02 绝对紧凑 vs F09/F17 相对时间。**裁二分**:时点(mtime/createdAt/连接时刻)= 绝对紧凑 `YYYY-MM-DD HH:MM`;时长/等待(elapsed、parked 2h)= 相对 duration;settled 卡一律落定时静态渲、永不活刷。
- **R7 mcp 动态卡双设计**(F01 mount mcpTool 皮 vs F14 mcp__ 动态卡):**F14 为唯一实现**(sniffShape 成形 + sentinel 前缀徽章);F01 mountIdentity resolver 只做身份路由(mount map 优先、名字 fallback、形状嗅探升降格),路由到 F14 的卡。拆名规则统一:剥 `mcp__` 后**最左** `__` 劈 server/tool(两族已一致)。
- **R8 检查单双发明**(F05 ToolProblemsBlock vs F12 ToolChecklist,双双认领 capability_check):**合一件** ToolChecklist(glyph 语义色 + mono 文本),封顶/溢出行/warnings 黄条为参数;F05 的「失败 details 是否上线缆」读码前置对两者同时成立。
- **R9 结果条双轨**(F04 BuildResultBar 公共化 vs F08 RunStatBar 抽升):**一条实现**——`RunStatBar` 四槽(状态词/耗时/计数/凭据 pill)+ per-kind 扩展槽(env 三色/lifecycle/listening/runtime),builds 侧同提交迁移(F08 已裁,采纳)。
- **R10 贴底视口双发明**(F03 AnTermViewport vs F15 AnStickViewport 均认领 palette 缺口 #1):**分层**——AnStickViewport 为通用底座(有界+贴底+回到最新+顶缘渐隐),AnTermViewport = 其终端层(ANSI 行 + 「显示更早 N 行」懒加载),SubTranscriptFrame 组合底座。
- **R11 partial JSON 五处实现**(F04 partialJsonEvents / F11 partialJsonItems+partialJsonString / F01 argStringPartial 增量化 / F14 repair+decode / F16 options 逐项提取):**一台引擎**——partialJsonEvents(path-aware、增量、字符串态机含逃逸悬置)为底,items/string/argString 皆其门面;F14 的 ≤2KB repair+decode 保留为 LiveKvForm 专用快路径(有闸、有单测),但闭合判据与框架键剔除规则共享。
- **R12 深链判定三处规则**(F07 面板能力注册表 / F12 kind 路由归宿 / F08 执行凭据 intent):**一层收口**——运行时**面板能力注册表**为单一事实源(kind 在注册表才可点,onTap:null 惰性绝不假链接);intent 形状扩为 `{kind, id, focus?}`(focus 承载 execution/flowrun/activation/tab 定位);scroll-anchor intent(load-until-found + 诚实降级)为对话内跳锚统一缝(F15 跳 Subagent 卡 / F16 祖先冒泡滚锚 / F17 messageId P2 三处共用)。

---

## 第二章 新原语总表(去重合并,50 件)

> 量级:S=天内、M=2–3 天、L=周级。★ = 「一件乐器养活多族」高杠杆件。

### A. 底盘与 core 缝(9 件)

| # | 原语 | 能力一句话 | 消费族 | 依赖 | 量级 |
|---|---|---|---|---|---|
| 1 | **底盘缝一揽子** ★ | ToolReceipt tone{none,warn,danger} + count/countedText + classifyResult 三值谓词缝 + verb(t,{live,state}) 签名(+可选 receiptWidget 槽、settle 过渡钩子) | 全 17 族 | 无 | S |
| 2 | **AnIcons 精确表全量收口** ★ | 90+ 工具逐条钉死实体/动作字形 + 新字形(terminal/folder/memory/checklist/芯片/关系/收件箱/对话泡)+ 小写键修正(websearch/webfetch);一次 PR 修全系统错形 | 全 17 族 | 无 | S |
| 3 | **partialJson 引擎** ★★ | path-aware 流中增量 JSON 事件解析(值闭合即发事件)+ 增量字符串反转义(逃逸悬置)+ items/argString 门面;五电池单测 | F01/04/11/14/16 | 无 | M |
| 4 | ToolLiveTail 倒扫增强 | 尾提取倒扫 O(尾窗)/帧 + 字符预算(无换行巨行设防);Write/Bash/builds 全体受益 | F01/03/08/13 | 无 | S |
| 5 | termFold + ansiSpans | \r/ESC[K/cursor-up 折叠(64 行可变窗)+ SGR→主题化 TextSpan(bold→w400);纯函数 | F03 | 无 | M |
| 6 | **AnStickViewport → AnTermViewport** ★ | 通用有界贴底视口(回到最新/顶缘渐隐/reduced 跳底)+ 终端层(ANSI + 「显示更早」懒加载);关 palette 缺口 #1 | F03/08/15 | 5 | M |
| 7 | **复制家族收口** ★ | ToolWindow actions 头槽 + WindowCopyButton(双窗挂载)+ copyPayload(渲染截喂、复制全量);关缺口 #12 | 全机器窗族 | 无 | S |
| 8 | **面板能力注册表 + intent 扩展** ★ | go_router 注册表单一事实源(不可点即惰性)+ `{kind,id,focus?}` 执行凭据 intent + scroll-anchor(load-until-found)+ openExternalUrl(url_launcher,scheme 闸与 AnMarkdown 同源) | F07/08/10/12/13/15/16/17 | 无 | M |
| 9 | core 小改集 | entityKindGlyph/attachmentKindGlyph 抽表 · AnThinTable 列级 mono · AnKvRow 行级 mono · maskedValue(短值全遮)· AnCountUp(tabular 滚数) | F02/05/06/07/09/12/16 | 1(count 缝) | S |

### B. 跨族共享陈列件(10 件)

| # | 原语 | 能力一句话 | 消费族 | 依赖 | 量级 |
|---|---|---|---|---|---|
| 10 | **ToolHitList 统一版** ★★ | 机器窗内命中/枚举行列:glyph/主文/次行/尾 meta builder + 封顶/双态 footer/fold/级联点亮(亲历落定首挂载播一次)+ 行点击 intent + 「当前」徽记 | F02/07/10/17(+未来 search_blocks 等) | 8,9 | M |
| 11 | **ProseWindow 统一** ★★ | 散文双态窗(=ToolLiveWindow+ToolReadingWindow+F10 ProseWindow 合一):live 双模(纯 Text 尾钳 / AnMarkdown 尾窗切片)+ settled AnMarkdown 15/1.6 + FadeCollapse 物理截喂纪律 | F04/06/10/11 | 无 | M |
| 12 | **RunStatBar** ★ | 结果条唯一实现(抽 _BuildResultBar 升格):状态/耗时/计数/凭据 pill 四槽 + per-kind 扩展槽;builds 同提交迁移 | F04/08 | 8 | S |
| 13 | ToolIOSection | 输入/输出对陈节:显式渲染规则(标量内联/逐键陈列/真嵌套才 JSON 树/renderAsProse 置位制、禁内容嗅探) | F08(+反哺 generic) | 无 | M |
| 14 | ToolChecklist(并 ProblemsBlock) | 状态 glyph + mono 文本检查单,封顶 20+溢出行 + warnings 黄条;details 上线缆读码前置 | F05/12 | 无 | S |
| 15 | ToolDependentsBlock | 删除审计块:N 处引用 + RefPill Wrap(24 枚封顶)+ 字符串形前缀白名单派生 | F05 | 8,9 | S |
| 16 | AnDeltaChip / AnCopyChip / AnPathChip | 变更药丸 `k: a→b` / mono 值+copy chip / 路径 chip(hover 全路径) | F01/04/05/06 | 无 | S×3 |
| 17 | **sniffShape + ShapedView** ★★ | 零 schema 成形引擎:任意串→五形(媒体/KV/表格/树/文档/纯文本)+ 截断标记剥离 + settle 单次成形 build 零解析;generic 地板抬到 80 分,∞ 工具受益 | F14(mcp 动态 + 一切未编目) | 无 | M |
| 18 | LiveKvForm + MediaMarkerChip | 活期 args 表单点亮(原文闭合判据、框架键按名剔除、2KB 闸)+ 媒体占位 chip | F14 | 3 | M |
| 19 | 回执/模板解析器群 | fsErrorReceipt·footer 组·searchReceipt·web 结局分类器·document 句·memory/todo 模板·固定散文匹配表等,集中 tool_receipts.dart 纯函数全单测 | 全 17 族 | 无 | S×N(合计 M) |

### C. 族专属大件(21 件)

| # | 原语 | 能力一句话 | 消费族 | 依赖 | 量级 |
|---|---|---|---|---|---|
| 20 | **ToolInteractionGate** ★★ | 人闸:prompt 槽 + fail-safe 钮排 + 选项/文本框 + awaiting↔resolved 冻结章 + 焦点仲裁;ask 与 V6 danger 共用 | F16 → 全 dangerous 工具 | 21 | M |
| 21 | **pendingInteractionsProvider** ★ | 三源合一交互真相(ephemeral 信号⊕GET interactions⊕resolved)+ 相位覆盖 + rail 联动 + 祖先链冒泡 | F16/15 | 无 | M |
| 22 | **AnMiniGraph** ★ | 只读迷你图画布(framed,复用 layoutGraph+边 painter) | F04/06/08 | 无 | M |
| 23 | GraphRevealState + 揭示面 | settle-then-replay 图生长:rank staggered 浮现 + 边 draw-in | F04 | 22 | M |
| 24 | GraphMorphState | 图 morph delta 变体:绿晕/脉冲/红名册;三级降级 | F04 | 22,23,50 | M |
| 25 | ToolEditLivePane | Edit 两幕 −/+ 素窗 | F01 | 3 | S |
| 26 | GrepContentView + highlightMatches | Grep content 分组视图 + 行内命中高亮(multiline 诚实跳过) | F02 | 无 | M |
| 27 | EnvFixTimeline | env 自愈 attempt 时间线 | F04 | 无 | S |
| 28 | BranchRuleList | control 决策梯(catch-all 钉底 + 错误行定位 + diff 态) | F04 | 3 | M |
| 29 | ApprovalFormPreview(+moustache 预处理) | 审批人视角预览 + `{{input.*}}` 占位投影(围栏跳过) | F04/06 | 11 | M |
| 30 | TriggerConfigCard ✅(B2.9) | trigger 四 kind 脸(cron 加重 / webhook AnCopyChip URL+🔒密钥 / fsnotify 路径+事件 / sensor 目标药丸+CEL);cronDescribe 挂起 P2(裸表达式已够) | F04 | 3 | M |
| 31 | ToolEntityHeader + EntityGetBody + RawResultDisclosure | get 族四段骨架(身份行/KV/内容折叠/原始底账永不过滤) | F06 | 9 | M |
| 32 | 模板解析器×2(read_document 严格行序 / read_attachment 六形) | 串模板反解,一步不匹配整串降级 | F06 | 无 | S |
| 33 | RunBeadStrip | 状态珠串(色表参数化) | F09 | 无 | S |
| 34 | RunLedger | 有界执行台账(显式槽位 + 行内 disclosure 联动外层展开) | F09 | 无 | M |
| 35 | RunDossier + ProvenanceLine | 执行卷宗(对陈 + 日志双端保留 + stderr 分段)+ 因果链凭据行(可点/不可点分界) | F09 | 8 | M |
| 36 | RunWaterfall | flowrun 节点解剖(虚拟滚动 + 落账事件点 + failed/parked 置顶) | F09 | 无 | M/L |
| 37 | TranscriptPeek + **transcript 水合适配器** ★ | settled transcript→帧序水合喂 BlockTreeReducer + 30 块意图锚定速览;适配器与 F15 reload/invoke_agent 共用 | F09/15/08 | 无 | M |
| 38 | FlowrunNodeList | 节点生死簿行列(nodeSummary 计数原文) | F08/16 | 无 | S |
| 39 | FlowrunSnapshotPane | fetch-on-expand 运行快照图(先 get flowrun 取 versionId 再按版本取图) | F08 | 22,50,版本图端点 | L |
| 40 | TodoChecklist + scopeChecklists 态 | 三态清单 + 迁移脉冲(fired 态外置防虚拟化重放) | F11 | 3 | M |
| 41 | MemoryNoteCard | 记忆索引卡(write/read 同脸) | F11 | 11 | S |
| 42 | RelationStarMap | 关系星图(24 边红线,超限退分组列表) | F12 | 9 | M |
| 43 | schemaParamDigest | JSON Schema→参数摘要(滤框架三字段) | F12 | 无 | S |
| 44 | McpMarketList / McpServerStatusCard / McpToolsList | 市场货架 / ServerStatus 卡(memoize 承载点)/ 工具清单点亮 | F13 | 7 | M |
| 45 | ToolStageTail | stage 标签进度尾(`[stage] msg (pct%)`) | F13(通用) | 4 | S |
| 46 | AnTermTail | 终端活尾(ToolLiveTail+ANSI) | F03 | 4,5 | S |
| 47 | **SubTranscriptFrame + SubagentDigestTail + reload 重水合缝** ★ | 嵌套对话第三身份(全注册表递归)+ 最近 K 行活摘要 + sub-message 折树重水合 + nested state 扩展(R1 改判后仅 Subagent 用;invoke_agent 用 F08 专属 NestedRunPane) | F15 | 6,21,37 | L |
| 48 | WebHitList(ToolHitList 变体)+ webOutcome 分类器 | 搜索命中出卡 + 假成功判别(URL 绑定锚) | F10 | 10,8 | S |
| 49 | AnVersionRewindChip | `⤺ vN` 倒带徽标(P2 打磨件) | F05 | 1 | S |
| 50 | **取数缝(before/after/版本图)** ★ | 工具卡 fetch-on-expand repository 缝:before 懒取 diff / after 图权威源 / 按版本取 graphParsed / mount map / 名→id 反查;内建 diff 尺寸门 + 诚实降级 | F01/04/05/06/08/13 | 架构拍板 Q2 | M/L |

**杠杆之王**(建了它一片族活):#3 partialJson 引擎、#10 ToolHitList、#11 ProseWindow、#17 sniffShape/ShapedView、#20+21 人闸双件、#47 嵌套对话框、#1/#2 底盘一揽子。

---

## 第三章 建造顺序提案(7 批)

> 排序逻辑:产品冲击 × 依赖 × 风险。已知约束:**V6 humanloop 已拍板紧随 V3c(= 第 1 批)**;**F4 builds 图生长是 pivot 旗舰(= 第 2 批)**。每批内部仍按各族「族内建造顺序」执行;B7 各族互不依赖、可并行或穿插提前。

### B1 「人闸」— F16 humanloop 全族 + 底盘缝 + 图标收口
- **内容**:pendingInteractionsProvider → ToolInteractionGate(gallery 五态 specimen)→ V6 danger 门 → ask_user → decide_approval → list_approval_inbox;同批顺手:底盘缝一揽子(#1)、AnIcons 全表(#2)。
- **理由**:用户已拍板;V6 门是全系统 dangerous 工具的公共安全面(族外溢价值最大);底盘缝与图标表是后续一切批次的前置,半天级小改趁第一批锁死,免得 6 个族各自 patch 一遍。

### B2 「builds 旗舰」— F04 全族 + 四件高杠杆地基
- **内容**:partialJsonEvents(#3)+ RunStatBar 抽升(#12)→ fn/hd 完全体(活代码窗+EnvFixTimeline+AnDeltaChip)→ **AnMiniGraph + GraphReveal/Morph + workflow 图生长/图 morph(pivot 旗舰)** → control/approval(BranchRuleList/FormPreview)→ document/skill(ProseWindow #11 首落)→ trigger;**取数缝(#50)架构拍板与首版**随 morph 深化落。
- **理由**:pivot 初衷三大点名场景(图长出来/图 morph/代码被写出来)全在此族;partialJsonEvents/ProseWindow/RunStatBar/AnMiniGraph 四件在此首建、养活 B5–B7 半数族;图回放 ~600–800 行是最大单体,独立 WRK 切片 + gallery 逐帧验收。

### B3 「目录感普查」— F05 + F06 + F07 + F17(50 工具)+ ToolHitList
- **内容**:四族回执解析器群 + 动词对 + chip 文法一次铺完(50 工具收起行全部脱 generic)→ ToolHitList 统一版(#10)+ 面板能力注册表(#8)→ EntityGetBody 四段骨架 → ToolDependentsBlock/ToolChecklist → 各族落定体。
- **理由**:全部 settle-only 薄卡、风险全系统最低,但覆盖工具数最多——每工时「transcript 读起来像目录」的增量最大;ToolHitList 一件养四族(含 B7 的 F10);删除审计/体检报告是低成本高感知件。

### B4 「终端与文件手术」— F03 + F01 + F02
- **内容**:termFold/ansiSpans(#5)→ footer 解析器组 + 后端 cap 余量小改 → AnTermTail → AnStickViewport+AnTermViewport(#6)→ BashOutput/KillShell;F01:fsErrorReceipt + AnPathChip + Write 活窗(ToolLiveTail 倒扫 #4 + argStringPartial 增量化)+ ToolEditLivePane + mount resolver;F02:AnCountUp/回执 count 缝 + LS/Glob/Grep + GrepContentView。
- **理由**:shell+fs 是 agent 最高频工具面,生长秀密度最高(终端滚动/文件被打出来/手术两幕);AnStickViewport 在此落地为 B6 嵌套对话预铺;三族已有 V3b 底盘,增量可控。

### B5 「执行与档案」— F08 + F09
- **内容**:ToolIOSection(#13)→ run_function/call_handler/fire_trigger → FlowrunNodeList → replay_flowrun;F09:回执 13 组 → RunBeadStrip+RunLedger(6 个 search 点亮)→ RunDossier+ProvenanceLine → RunWaterfall(get_flowrun)→ **transcript 水合适配器 + TranscriptPeek**;FlowrunSnapshotPane 待版本图端点核实(Q2)后落。
- **理由**:执行观测一体成型(跑了什么/留在哪张台账/坏在哪一步);水合适配器是 B6 的硬前置工件;RunWaterfall 开工前先真跑验证节点时长分布(F09 已列)。

### B6 「嵌套对话」— F15 + F08 invoke_agent 活期
- **内容**:子树投影纯模型 + reload 重水合缝 → SubTranscriptFrame(组合 AnStickViewport)+ 钉住终答 → SubagentDigestTail 活期 + 琥珀上浮(消费 B1 的祖先冒泡)→ get_subagent_trace + scroll-anchor intent。(R1 改判:invoke_agent 不接此套件——其 NestedRunPane 随 B5 F08 落。)
- **理由**:依赖最深(E3 接线、重水合缝、视口、pendingInteractions 冒泡、水合适配器——B1/B4/B5 各供一件),放最后风险最小;wow 是全系统天花板(对话里长出会用工具的小对话,整套卡片文法免费递归)。

### B7 「生态收尾」— F14 + F11 + F10 + F13 + F12(可并行/穿插)
- **内容**:sniffShape+ShapedView 抬 generic 地板(#17,可在 B2 后任意时点提前——∞ 未编目工具受益)→ LiveKvForm + mcp 动态卡;F11:TodoChecklist 完全体(resident 高频,建议优先穿插)+ MemoryNoteCard;F10:web 结局分类器 + WebHitList + ProseWindow 打字摘要;F13:McpServerStatusCard 三件 + ToolStageTail;F12:ToolChecklist 消费 + RelationStarMap(列表退化先行)。
- **理由**:五族互不依赖、各自 S/M 级,可按人力并行;F14 与 F11 产品冲击最高(地板抬升 + Claude Code 同款 todo 体验),族内已注明可提前。

---

## 第四章 拍板问题清单

> **拍板结果(2026-07-06)**:第 1 题用户**改判「保留两套」**;第 2–10 题全部按推荐执行。

1. **嵌套运行身份(R1)**:invoke_agent 活期用 F15 SubTranscriptFrame(第三身份、全注册表递归)还是 F08 NestedRunPane(ToolWindow mono 行)?推荐曾为统一 SubTranscriptFrame;**拍板:保留两套**——Subagent=SubTranscriptFrame,invoke_agent=NestedRunPane(见 §1.3 R1 改判记录)。
2. **工具卡取数缝(#50)**:是否允许工具卡越出「块状态纯函数」边界开 repository 缝(before 懒取 diff / after 图 / FlowrunSnapshotPane / mount map / mcp 名→id)?**推荐:允许,统一一条 fetch-on-expand 缝 + 诚实降级**;随缝核实「按版本取 workflow 图(graphParsed)」端点——今天零证据,缺则按迭代铁律②补端点或写死降级(绝不用 active 图冒充版本图)。
3. **后端小改包(迭代铁律②,打包一次拍板)**:①document 系散文输出迁 JSON(砍全族模板脆性,F04/05/06 三族受益)+ delete_agent 对齐;②Bash/BashOutput cap 预留 footer 余量(双 cap 冲突根治);③todo content 单行不变量;④rg 补 `--with-filename`/`--no-context-separator` 抹平双后端;⑤MCP OAuth `[oauth]` progress 行;⑥失败 tool_result 是否序列化 details(ToolProblemsBlock 前置)。**推荐:全做**,各随消费批次同提交、守 testend。
4. **时间语义(R6)**:**推荐:时点=绝对紧凑、时长=相对,settled 永不活刷**——一条全族纪律入 WRK-053。
5. **收起行 chip 交互(R4)**:**推荐:收起行纯展示全局化**(单一热区),copy 一律进展开体/hover;AnPathChip 相应调整。
6. **settled 动效边界(R5)**:**推荐:settled 卡禁呼吸**,running 渲静态点+快照措辞;微动效(计数滚升/级联点亮/迁移脉冲)保留但随族落地一次到位(gallery 动静双态 specimen + reduced 全等价),不做「先静态后补」二遍工。
7. **ToolHitList 归一范围(R2)**:F02 的 200 行命中窗(带原始输出逃生口)是否也并入统一件?**推荐:并入**,封顶/逃生口作参数——四族一件,代价是首版参数面稍大。
8. **B3/B4 顺序**:目录感普查(50 薄卡)先于终端/fs 完全体,还是反之?**推荐:B3 先**——覆盖面收益大、风险低,且 shell/fs 已有 V3b 可用底盘不算裸奔;若用户更在意高频工具的生长秀质感,可对调。
9. **generic 地板(#17)提前与否**:sniffShape/ShapedView 放 B7 还是紧跟 B2?**推荐:B2 完成后立即穿插**(一人日级独立件,∞ 工具受益、真线缆随手可验),不必等 B7。
10. **AnVersionRewindChip / cronDescribe / settle 过渡钩子等 P2 打磨件**:本期做否?**推荐:全部挂 P2 backlog,不入 B1–B7 承诺**——克制也是完美的一部分。


---

# F01 — fs-ops 族完美态(Read / Write / Edit)+ mount 附节

> 线缆真相:census 01(fs 三工具)+ census 09 末节(mount 合成工具)。
> 底盘现状:三工具已在 catalog(V3b),本设计 = 从「已编目」升到「完美态」的增量。

## 族级统一文法

- **身份**:文件是外部世界——一切产物住机器窗,行保持裸动词。图标:Read→doc、Write→edit、**Edit→edit(必须补 AnIcons 精确表:真名 `Edit` 现被关键字 `create|edit` 分支劫走成锤形;`Read`/`Write` 靠 `file|read|write` 兜进 doc,也应显式落表)**。
- **目标 chip = AnPathChip(族新原语)**:mono basename 显示、hover 浮全绝对路径、点击复制路径;流中容忍 partial(未闭合路径取尾段)。三卡同一件,替换现 `pathBasename` 纯文本。
- **错误即文案(线缆铁律)**:Execute 期失败几乎全是 err==nil 的人读字符串 → 族共用 **`fsErrorReceipt` 前缀模式表**,必须收齐 census 01 错误文案**全集**(前缀锚定串首;cat -n 行号前缀天然防文件内容误伤):`path is denied by safety guard:`(PathGuard,三工具全会命中)/ **fspath 三文案(三工具全会命中;归属已读码确认:`fspath.Expand` 错误在三工具 Execute 内以 `err.Error(), nil` 作正常 tool_result 返回、非 ValidateInput sentinel)`path must be absolute`→「路径非绝对」/ `path is required`→「路径为空」/ `cannot expand ~:`→「~ 无法展开」** / `File not found:` / `Permission denied:` / `Cannot access` / `Path is a directory` / `Failed to read`(Read)/ `Parent directory does not exist:` / `Parent path exists but is not a directory:` / `Cannot verify Read-first guard:` / `File must be read first`(Write/Edit)/ `File has been modified since last read` / `old_string not found` / `Found \d+ matches`(Edit)/ `Write failed (` / `Edit failed (`。命中 → 红短语回执 + **自动展开一次**,展开体 = ToolWindow 错误全文。**Write/Edit(写盘工具)结果非成功模板且表未命中 → 灰中性回执「结果未确认」**(显式不确认、非猜测——过去时动词旁的纯空回执会被读成成功,那是「已写入」谎言);Read 未命中 → 无回执灰行照旧。**表完备性是诚实的承重墙**:漏一条 = 行面「已写入 .env」而文件实际被 guard 拒写。
- **cautious 双卡**:Write/Edit 的 LLM 自报 summary 常显于窗上方(复用 `_intent`;Read 只读不显)。
- **「活期生长、展开成品」母语(与底盘「完成即溶、成功收拢」对齐)**:流动期一律纯 mono 素色活窗(A 级、逐 delta 便宜);settled 高亮体(AnCodeEditor / AnVersionDiff)默认只在用户点 chevron 展开后挂载。真实时间线 = 素窗溶掉 → 裸行收拢 →(展开)→ 高亮成品——**不承诺原位 morph**(素窗只持尾 8 行 12 号、settled 是全文 13 号带行号 chrome,即便同框也不是「内容不动」)。**可选增强(底盘 settle 过渡钩子,非本族义务)**:落定一瞬若卡可见(在飞未收/已被展开),liveBody 原位 cross-fade 成 settled 体、停留一拍再按底盘语义收拢;reduced motion 直接收拢。此钩子缺席时本族设计照样成立——建造者不背做不出来的不变量。
- **字号**:活窗/错误窗 = 机器档 `AnText.code`(12);落定创作内容(Write 全文、Edit diff)= 内容档 `reading: true`(codeReading 13)——写进用户世界的东西按内容对待。

---

### `Read` — 正在读取 → 已读取

- **收起行**:doc icon · 读取中/已读取 · AnPathChip(`args.file_path`)· 回执解析成功输出(cat -n 模板,`%5d\t` 行号稳定可解):首行号 F 与截断脚注(尾行 `[truncated at line N]`)**独立提取**,规则表 = (F==1?, truncated?) 四象限——F==1 无截断 → `L 行`(L=末行号);F>1 无截断 → `行 F–L`(offset 分页读诚实呈现);F==1 截断 → **`N+ 行`**(宪法 N+ 铁律);**F>1 且截断 → `行 F–N+`**(分页起点照显、+ 号照挂——读大文件的常见路径,不许显成像从头读了 N+ 行);`<system-reminder>File exists but has empty contents` → `空文件`;错误模式 → 红短语(`未找到`/`无权限`/`是目录`/`无法访问`/`读取失败`/`守卫拒绝`/`路径非绝对`)。
- **活期**:`settle-only`(无 progress)。流光动词 + chip 随 file_path 流入长出,>3s 读秒。**不做假生长**——Read 亚秒级,克制即完美(宪法 #9)。
- **落定体**:**bodyless——回执即卡**(已拍板)。唯一例外:错误模式命中 → 生成一次性体(ToolWindow 错误全文,如目录误读时含后端的 Glob 建议原文)+ 自动展开。
- **退化态**:空文件=灰「空文件」无体;2000 行截断=`2000+ 行`;单行 8MiB 超限 scanner 报错 → 走错误模式表(`Failed to read` 前缀)。
- **交互**:AnPathChip 点击复制绝对路径;无 deep link(主机 FS 非实体)。
- **新原语**:AnPathChip(族共用)。
- **Wow**:一叠 Read 行读起来像一本书的目录页——文件名 + 精确行数回执的确定性节奏,agent「在翻文件」的感觉不需要任何展开。
- **可行性**:行号解析对 5 宽右对齐+TAB 模板做,后端模板改动会静默降级为无回执(诚实降级,不误报);offset/limit 在 args 即取,无顺序风险。

### `Write` — 正在写入 → 已写入

- **收起行**:edit icon · 写入中/已写入 · AnPathChip · 回执 = 落定时从 `args.content` 数行(`N 行`;content="" → `空文件`;args 未闭合/坏 JSON → 无回执);错误模式 → 红短语(`守卫拒绝`/`路径非绝对`/`须先读`/`守卫未核验`[Cannot verify Read-first guard]/`父目录缺失`/`父路径非目录`/`是目录`/`写入失败`);非成功模板且表未命中 → 灰「结果未确认」(族级规则)。结果串恒 `Wrote <path>`,无需解析。
- **活期(生长秀,`args-partial`)**:**文件在行下被打出来**——liveBody = **ToolLiveTail(text: argStringPartial('content'), tailLines: 8)**(现成 A 级原语直接吃,它对文本来源本就无感——progress 或 args-partial 都只是 text prop,不另抽尾窗 helper);`argStringPartial` 容忍未闭合 JSON 串。这是使命原话「看到代码怎么被写出来」的 fs 版,管线 builds 已验证。
- **落定体**:`_intent`(cautious 自报)→ **AnCodeEditor(code: content, lang: 扩展名映射, reading: true)** 高亮陈列;>50 行裹 **AnFadeCollapse**(collapsedHeight 400,fadeColor 显式对齐 code surface 底色)+「查看全文」逃生口;>6000 chars **渲染截断、复制不截**:AnCodeEditor 只喂截断体(transcript 不背无界内容),copy 动作喂**完整 `args.content`**(settled 时 args 全量在手——用户复制到的永远是整个文件,绝不让 copy 栏复制截断体冒充全文)——**物理载体 = AnCodeEditor 新增可选 `copyPayload` 参数**(copy 栏优先取它、缺省取 `code`;palette 现状 copy 栏只会复制自己的 `code` prop 即截断体,不加此参数这条承诺不可实现,故列入族级新原语汇总为 core 原语增强项、与倒扫改造同格,不靠建造者自行发现);截断态下展开标签改「**展开(已截 N 字)**」且截断注记**常显**(全文看不到时标签不许叫「查看全文」)。
- **morph**:无——整体替换是本工具的补丁风格;**不伪造 vs 旧内容的 diff**(线缆没有旧内容,诚实铁律;跨卡拼此前 Read 的内容做 diff 属脆弱聪明,否决)。
- **退化态**:content=""(合法)→ 体隐、回执「空文件」;读前守卫拒绝 → 红「须先读」+ 自动展开后端提示原文;写半途失败(`Write failed (rename to target)`)→ 红「写入失败」+ 全文。
- **交互**:AnCodeEditor copy/wrap 栏(copy 经 `copyPayload` 喂全量 `args.content`,见落定体);AnPathChip 复制路径。
- **新原语**:无新建组件——复用 **ToolLiveTail**(builds 活窗若有额外 chrome[命令回显 header / 语言标签],把差异参数化进 ToolLiveTail——header 槽 ToolWindow 上已有;同一「尾 N 行素窗」能力绝不做三份)+ **AnCodeEditor `copyPayload` 增强**(core 原语增量,见落定体与族级汇总)。
- **Wow**:小窗里看着文件逐行长出来;落定收拢后一点展开,同一份字符串换上带行号语法高亮的成品身份——活期看生长、展开看成品,两种生命(装了 settle 过渡钩子时还能看到原位 cross-fade 的显影一拍)。
- **可行性**:args 键序不可控——file_path 可能晚于 content 闭合,chip 与 lang 须容忍 null 后补(lang 晚到 = 落定时才定,无碍);content 是全文件 PAYLOAD——**尾提取必须倒扫**(从串尾 `lastIndexOf('\n')` 迭代 N 次切出尾窗,O(尾窗)/帧),**不许**每帧对全串 `split('\n')`(O(全文) 扫描 + 数千行 substring 分配/帧 = 纯 GC churn,结果只用尾 8 行);倒扫落在 ToolLiveTail 一处实现,Write/builds/Bash 全体受益。**上游同责——`argStringPartial` 必须增量化**(否则倒扫省下的 O(全文)/帧 被解码路径原样吐回:现实现每帧对累积全串跑 regex + 逐字符全量重解码 + 分配全量新串,256KB 级 content 流式帧率下就是纯 GC churn):args delta 是 append-only,契约 = 缓存「已解码前缀 + 未闭合逃逸尾」(如半个 `\u00`),每帧只解码新增字节;半截逃逸序列悬置到下一帧再显示(避免闪烁乱码);倒扫作用于解码缓存串。**倒扫还须带字符预算**(无换行巨行设防):尾窗总量封顶(如 4K chars),单「行」超预算(minified JS / 单行 JSON 无 `\n`,`lastIndexOf` 全串落空)只取行尾片段 + 头部省略号注记——否则「尾 8 行」= 整个已流入串(MB 级)塞进单 wrap Text,ToolWindow 内单 RenderParagraph 每帧全量重排 = 硬冻结;Bash 原始字节流同样可能无换行,同受益。

### `Edit` — 正在编辑 → 已编辑

- **收起行**:edit icon · 编辑中/已编辑 · AnPathChip · 回执解析 `Replaced (\d+) occurrences?` → `1 处替换` / `N 处替换`;错误模式 → 红短语(`未匹配`/`N 处歧义`/`文件已变`/`须先读`/`守卫拒绝`/`路径非绝对`/`未找到`/`编辑失败`);非成功模板且表未命中 → 灰「结果未确认」(族级规则)。
- **活期(生长秀,`args-partial`,两幕)**:**ToolEditLivePane(族新原语)**——第一幕:old_string 流入,活窗显「−」段尾行(danger 软色素 mono,要被切掉的);第二幕:new_string 键一出现,旧段定格、下方「+」段逐行生长(ok 软色)。纯双段 Text 零 LCS——A 级便宜。两幕按「哪个键已出现」驱动,**不假设键序**。
- **落定体**:`_intent` → **AnVersionDiff(before: old, after: new, lang: 扩展名, reading: true, note: replace_all 时「N 处全部替换」)**——LCS 只在落定跑一次(C 级原语用在正确时机);**超限退化**:old+new 合计 >1500 行不进 AnVersionDiff(palette 明言其每 build 全量 LCS、面向短单字段——naive O(n²) 在数千行输入上是点 chevron 瞬间的秒级冻结)→ 退化为「−段 / +段」两个纯 mono ToolWindow 对陈(复用 ToolEditLivePane 双段布局,零新件)+ 显式注记「内容过长,未做逐行对比」(诚实降级);new_string="" = 纯删除,diff 全红,如实。
- **morph**:两幕素色 −/+ 活窗(活期)→ 展开后的 LCS unified diff(settled)**即是**本工具的 morph:先看见要切的、再看见缝上去的,展开读到教科书式绿红手术记录——两态按底盘语义各居其位,不承诺落定原位变身(settle 过渡钩子在场时才有原位显影一拍)。reduced motion:直接终态 diff。
- **退化态**:`old_string not found` → 红「未匹配」+ 自动展开:错误全文 + **old_string 对照窗**(用户一眼看出哪段没对上——空白/大小写);`Found N matches` → 红「N 处歧义」+ 全文(含 replace_all 建议原文);size 漂移 → 红「文件已变」;old+new 合计 >1500 行 → 双段对陈退化态(见落定体);`FS_EDIT_NOOP`(old==new)是 ValidateInput 硬错 → 底盘失败相。
- **交互**:AnPathChip 复制;diff 窗暂无 copy 栏(AnVersionDiff 现状,可后补非本族义务)。
- **新原语**:ToolEditLivePane(feature 级组合件:双段 −/+ 素色流窗)。
- **Wow**:替换像外科手术直播——切口与缝线分两幕看清,展开读到真 diff 的手术记录;失败时把没对上的 old_string 直接摊给你看,不用猜。
- **可行性**:diff 素材全在 args(census 明示结果串只有计数,**前端 diff 必须从 args 取**);超长 old/new(整函数级)活窗只显尾行、落定单次 LCS 仅在 ≤1500 行阈值内可接受(超限走双段退化态,见落定体——LLM 用 Edit 重写大段时 old/new 可达整文件级);行级 diff 会把一词之差渲成整行删+加(palette 缺口 #10,接受为 v1 取舍)。

---

## mount 附节 — agent 挂载合成工具(动态命名,无固定工具名)

**身份识别策略(census 09 #5:不能按工具名注册皮肤)**:**mount map 优先、名字路由仅作 fallback**——`mountIdentity` resolver 能从上下文解析时(subagent 树的 invoke_agent → agentId → agent 实体 ToolRefs mount map;或后端 touchpoint/TouchEntity 元信息)**以 map 为准**定皮肤;解析不到才走名字启发:① `mcp__<server>__<tool>` 前缀 → mcpTool 皮;② 名含 `__`(非 mcp__ 开头,按**最右** `__` 劈 handler/method)→ handlerTool 皮——⚠️ census 未约束 function 命名,裸函数名 `my__helper` 会被此规则误穿 handler 皮(chip 错劈、回执解析落空、动词错),故 handler 皮必须带**落定形状嗅探降级**(见 handlerTool 可行性);③ 其余裸名**无无条件断言**(裸函数名与未来未编目工具名字层面不可分,live 就穿 functionTool 皮会对未知工具显错动词「运行中/已运行」):live 期一律 **generic 皮**(动词中性);settled 时结果 JSON 形状匹配 `ExecutionResult`(`{ok,elapsedMs,…}` 键)才**升格 functionTool 皮**——与 handlerTool 已有的落定形状嗅探共用同一机制、同一时机(零流式代价)。名字路由任一级拿不准 → generic 兜底,**绝不无声**。

### `functionTool`(名 = 函数名)— 正在运行 → 已运行

- **收起行**:action icon · 运行中/已运行 · chip = 工具名本身(= 函数名,mono)· 回执解析 JSON `{ok,output,errorMsg,elapsedMs,logs?}`:ok → 耗时格式化(`1.2 s`,来自 elapsedMs——比读秒更诚实);ok:false → 红「失败」+ 自动展开。
- **活期**:`settle-only`(无 progress)→ 流光 + 读秒,无假生长。
- **落定体**:**输入/输出对陈**(宪法母语「run 给输入/输出对陈」):args → 内联 JSON(≤14 行)否则 AnJsonTree@240,标「输入」;`output` 同规则标「输出」;`logs` 非空 → ToolWindow mono;`errorMsg` → 红 mono。mount map 可解析出 fn id 时,尾挂 **AnRefPill(function, fn_<id>)** deep link 跳实体面板。
- **退化态**:output 巨大 → JsonTree 有界视口;结果非 JSON → 通用体;ok:false 但 errorMsg 空 → 红「失败」+ 原始结果窗。
- **Wow**:agent 的挂载函数调用读起来和一等公民 run_function 一样专业——尽管线缆上它是个「无名」动态工具。
- **可行性**:⚠️ 识别全靠 resolver;拿不到 mount map 时落 generic(卡仍完整可读,只失去族皮)。

### `handlerTool`(名 = `<handler>__<method>`)— 正在调用 → 已调用

- **收起行**:handler icon · 调用中/已调用 · chip = `handler.method`(最右 `__` 劈开、点号连显,人读友好)· 回执:`{"result": <v>}` 的 v 为短标量(≤24 chars)→ `→ 值`;否则无回执(诚实)。
- **活期**:**有 progress(逐 yield 一行)**→ **ToolLiveTail**(与 Bash 同族魂,现成原语直接吃)。
- **落定体**:输入 JSON(同 functionTool 规则)+ yield 全文 ToolWindow(progressText 非空时,封顶 6000 + 注记)+ result JSON 陈列;可解析时挂 AnRefPill(handler)。
- **退化态**:yield 空 → 无窗只对陈;result 深嵌 → JsonTree 有界。
- **Wow**:handler 方法边跑边吐 yield,行下终端活着——挂载工具里最有「呼吸感」的一张卡。
- **可行性**:最右 `__` 劈名对「handler 名自身含 `__`」有理论歧义(后端合成单一分隔),取最右段为 method 最稳;**跨类误路由防御(名字 fallback 专属)**:settled 时若 `{"result": …}` 解析落空**且**结果形状匹配 functionTool 的 `{ok,elapsedMs,…}` → 降级 function 皮(或 generic)——形状嗅探只在落定做一次,零流式代价;yield 粒度=行,ToolLiveTail 尾提取(倒扫,见 Write 可行性)便宜。

### `mcpTool`(名 = `mcp__<server>__<tool>`)— 正在调用 → 已调用

- **收起行**:plug icon · 调用中/已调用 · chip = `server / tool`(剥 `mcp__` 前缀后按**最左** `__` 劈——server 段短、tool 段吃余量,server/tool 名自含 `__` 时[用户自命名 server 完全可能]这是唯一确定性规则;mount map 可解析时以 map 里的 serverName/toolName 为准覆盖名字劈分;劈分只影响 chip 显示、不影响皮肤路由[`mcp__` 前缀已定身份],故降级无害)· 回执:成功**无回执**(结果是 server 原始串、形态体积均不可知——不猜);失败三错可区分:`MCP_SERVER_NOT_FOUND`→「服务器不存在」/ `MCP_SERVER_NOT_CONNECTED`→「服务器离线」/ `MCP_TOOL_NOT_FOUND`→「工具不存在」,红 + 自动展开——识别走底盘失败相,**并加 code 子串匹配文案的兜底路径**(NOT_CONNECTED 的线缆形是文案内嵌 code:`mcp server "x" is not connected: MCP_SERVER_NOT_CONNECTED`);⚠️ 三错能否到达本卡待读码确认,见可行性。
- **活期**:**有 progress(MCP 通知)**→ ToolLiveTail。
- **落定体**:args JSON 对陈 + 结果 **ToolWindow 纯 mono 封顶 6000 + 诚实截断注记**——**绝不当 markdown 渲**(格式未知,机器窗身份铁律);「服务器离线」错误体内给跳 MCP 设置的动作(deep link → settings/mcp 该 server;**前提 = 三错确认能到达本卡**,否则此呈现整体挪走,见可行性)。
- **退化态**:结果空串 → 灰「无输出」一行;超限 → 截断注记 + 「查看全文」(AnFadeCollapse)。
- **Wow**:第三方工具的输出被稳稳关进机器窗——不管 server 吐什么妖形怪状,卡面永远端正,离线时一键带你去重连。
- **可行性**:结果体积不可控 → 封顶铁律必须执行;⚠️ **三错到达前端的载体存疑,开工前必须读码确认**(哪一层的块、是否带失败标记)——census 09 标注它们是**解析期**错误且 mount 解析 fail-fast(挂载坏 → invoke 整体大声失败),很可能在 invoke_agent 层就炸、本卡的 tool_call 根本不开、红回执无处可挂;即便 CallTool 执行期返回,NOT_CONNECTED 未必以结构化 failed 相到达(文案内嵌 code 形)。若读码确认是 invoke 层失败:「服务器离线 + 跳 MCP 设置」的呈现**归属挪到 invoke_agent 卡的失败体**,本节删该承诺。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| **AnPathChip** | core/ui(或 feature 起步) | mono basename chip:hover 浮全路径、点击复制绝对路径、partial 容忍——fs 全族(及一切带路径的族)共用 |
| **ToolEditLivePane** | feature | Edit 活期双段 −/+ 素色流动窗:old 段定格(danger 软色)+ new 段尾行生长(ok 软色),零 LCS、A 级便宜 |
| **ToolLiveTail 倒扫改造 + 字符预算** | 现有原语增强(非新建) | Write/builds 活窗直接复用 ToolLiveTail(**不建 streamTailWindow**——同一「尾 N 行素窗」能力不做三份,builds 的 header/语言标签差异参数化进它);尾提取改倒扫 `lastIndexOf('\n')`,O(尾窗)/帧,大 PAYLOAD 零 GC churn;**尾窗总量封顶(如 4K chars)+ 单行超预算取行尾片段+头部省略号注记**(minified/单行 JSON 无换行时不退化成 MB 级单行重排);Bash 同受益 |
| **argStringPartial 增量化** | tool_receipts.dart 现有 helper 增强 | args delta append-only 契约:缓存「已解码前缀 + 未闭合逃逸尾」,每帧只解码新增字节、半截逃逸悬置下帧(现实现每帧全串 regex + 全量重解码 = O(全文)/帧,会把倒扫省下的成本原样吐回);倒扫作用于解码缓存串 |
| **AnCodeEditor `copyPayload` 增强** | core 原语增强(非新建) | copy 栏可选载荷参数:优先取 `copyPayload`、缺省取 `code`——Write 落定「渲染截断、复制不截」的物理载体(palette 现状 copy 栏只会复制自己的 `code` prop,即截断体) |
| **fsErrorReceipt** | tool_receipts.dart 扩展 | fs 错误文案前缀模式表(**census 全集**,含 PathGuard/fspath 三文案[「路径非绝对」等,已读码确认为 Execute 期 tool_result 字符串]/`Cannot verify Read-first guard`/`Cannot access`/`Failed to read` 等)→ {短语, danger:true};Write/Edit 未命中且非成功模板 → 灰「结果未确认」;Read 未命中诚实无回执 |
| **mountIdentity resolver** | feature 数据层 | **mount map 优先**、`mcp__`(最左劈)/最右 `__` 名字路由仅 fallback → mount 三式皮肤;**裸名 live 期一律 generic、settled 按 `ExecutionResult` 形状嗅探升格 functionTool**;handler 皮带落定形状嗅探降级(防裸函数名含 `__` 误路由);解析不到落 generic |
| (可选)底盘 settle 过渡钩子 | 底盘增量,非本族义务 | 落定瞬间卡可见时 liveBody 原位 cross-fade 成 settled 体、停一拍再收拢;reduced motion 直接收——缺席不影响本族设计成立 |
| AnIcons 精确表补条 | core/design | `Read→doc, Write→edit, Edit→edit`(修 Edit 现落锤形的错位) |

## 族内建造顺序建议

1. **fsErrorReceipt(census 错误文案全集 + fspath 三文案[归属已读码确认,直接入表] + Write/Edit 灰「结果未确认」)+ Read 回执精修(四象限含 `行 F–N+`)+ AnIcons 补表**——纯解析零新 UI,风险最低,三卡失败态立刻端正(自动展开语义此步激活)。
2. **AnPathChip** → 三卡换 chip(交互增量,独立可验)。
3. **Write 活窗 + 落定**:ToolLiveTail 直接接 liveBody(含尾提取倒扫 + 字符预算 + `argStringPartial` 增量化三项改造)+ 落定 AnFadeCollapse 封顶 + **AnCodeEditor `copyPayload` 增强**接 copy 全量 `args.content`(管线 builds 已验证,主要是复用)。
4. **ToolEditLivePane + Edit 落定精修**(reading/note/未匹配对照窗/>1500 行双段退化态)——族内最大新件,放在文法都稳之后。
5. **mount 三式皮肤**:先落 `mcp__`(最左劈)与最右 `__` 两个名字 fallback 路由 + 裸名 live-generic/settled `ExecutionResult` 形状嗅探升格 + handler 皮形状嗅探降级(零依赖);mount map resolver(以 map 为准)依赖 agent 实体数据缝、随 V8/右岛 touchpoint 线一起落;**mcpTool 三错载体的读码确认也在此步开工前做**(结论决定「服务器离线」呈现归属本卡还是 invoke_agent 卡)。


---

# F02 fs-search — Glob / Grep / LS 完美态

> 线缆锚:census 01-fs-shell §4–6。三工具共性:**只读、零 progress、一次性落定**——活期没有任何
> 中间流可秀,族的全部戏剧性押在 **settle 瞬间的「计数揭示」**上。Execute 期错误全是普通
> tool_result 文本(err==nil),UI 按 census 已登记的文案前缀识别。

## 族级统一文法

- **收起行句式 = 一句话侦查报告**:`动词 · 引号 pattern chip · 计数回执`。
  读作 `已检索 "**/*.go" · 342 项` / `已搜索 "TODO(" · 87 处匹配` / `已列出 backend/ · 24 项`。
  pattern chip 恒双引号包(WRK-053 §4);LS 用路径 chip(basename + 尾随 `/` 表明是目录)不加引号。
  chip 封顶 ~48 字符尾省略(pattern 信息量在头部)。
- **活期(全族 settle-only)**:线上无 progress,不造假窗——活期 = `AnShimmerText` 流光动词 +
  pattern chip 随 args 流入渐现(args 很小,通常一闪即全);>3s 底盘读秒接管(Glob 裸 `**` 大树
  walk 时读秒就是真话)。**无 liveBody**——克制也是完美的一部分(宪法 #9)。
- **计数揭示 = 族魂(仅本会话亲历落定才播,两段两载体)**:动效只属于在本会话内观察到
  running→succeeded 相位迁移的卡。**第一段(settle 瞬间,收起行)**:回执数字用 `AnCountUp`
  快速滚上(0→N,~300ms `AnMotion.mid`,tabular figures 不抖行宽)——收起行始终可见,这一段
  真在播。**第二段(亲历落定后的首次展开,命中列表)**:settle 瞬间**只置 `revealEligible`
  标记、不播列表动效**——宪法 #3 成功即收拢且不自动展开,body 经 `AnExpandReveal` 收拢时
  child 已移出树(palette §3),在 settle 瞬间「播」= 播给未挂载的空气;用户首次展开且列表
  真实挂载时消费标记,前 ~16 行逐行点亮(每行 ~20ms stagger,fade + 2px 上移;之后的行即时
  全现),播完转已播、重展开不重播。**历史加载 / 挂载即已落定的卡不置标记**——直接渲终值 +
  静态列表(历史读起来像目录不像日志,宪法 #3);`revealEligible`/已播标记存卡片 state
  (AnExpandReveal 外层——child 收拢移出树也不丢);reduced→一律即时终值 + 全现。
  `ToolHitList` 的 gallery specimen 按此收录动(revealEligible 首展开)/ 静(历史)双态。
- **命中窗 = ToolWindow + `ToolHitList`(族级新原语)**:glyph 列(dir/file/link)+ 主文本 +
  右侧 dim meta 列(等宽对齐);**路径一律相对搜索根显示**(根在窗头,降噪),hover 行浮出
  copy 钮拷**绝对路径**;**相对化的根绝不直接用 args.path 原文**——后端 Execute 先
  `fspath.Expand` 再搜(`~` 是全域一等公民,census 首条共性),输出路径全是展开后绝对路径而
  args JSON 保留 LLM 原样 `~/...`:Glob 用输出 JSON 自带 `root`、LS 用头行绝对路径,Grep 无
  输出根 → 用解析器推导的「有效根」(见 Grep 可行性);窗头 query echo 仍显 args 原文;渲染封顶 200 行 + `AnFadeCollapse`(collapsedHeight 400,
  **fadeColor 必须显式传 surfaceSunken**——palette 明示默认 canvas 会穿帮)+ 底部
  「查看原始输出」逃生口(切回 `_cappedMono` 原文)。窗内 mono 12(`AnText.code`)机器档。
- **窗头 = 检索参数回显**(对应 Bash 的 `$ cmd` 回显,但用检索的声音):左 = query echo
  (`"pattern" in <root> · *.go · -i`),右 = 诚实计数(`显示 100 / 共 342`)。
- **时间用绝对紧凑格式**(`YYYY-MM-DD HH:MM`,同 LS 线缆):transcript 是历史,相对时间
  (「3 分钟前」)会腐烂或需秒表刷新。
- **错误即文案(族级机制,前缀表按工具分域)**:census 已登记的错误前缀 → 分类成 danger 回执
  (`目录不存在` / `无效模式` / `守卫拒绝` / `超时`),`danger:true` 借底盘机制红显 + 自动展开一次,
  体 = 原文案装 mono 窗(danger 色字);**未识别前缀 → 无回执 + 中性通用窗**(诚实铁律:绝不猜)。
  **双门分类,防内容伪装误报**:① 各工具只认自己会产出的前缀——LS:`Directory not found:` /
  `Not a directory` / `Cannot read directory` / `Cannot access`;Glob:`Search root not found:` /
  `Search root must be a directory:` / `Invalid glob pattern` / `Cannot access` /
  `Glob search exceeded the time budget`;Grep:`Invalid regex pattern:`;三工具共认
  `path is denied by safety guard:`。② 仅当**整个输出为单行**且命中前缀才分类(线缆错误文案
  均单行;Grep content 输出是任意文件文本、单文件根还无 path 前缀,首行完全可能长得像
  `Directory not found: /x` 之类文案——把成功结果标成失败比漏标更糟)。双门不满足则按正常
  结果解析。分类器纯函数单测必含「内容伪装错误文案」用例。
- **空结果 = 回执即卡**:`无匹配` / `空目录` 回执,bodyless(学 Read——不放一个空窗给人点)。
- **图标修正(现状 bug)**:palette §6 证实 Glob/Grep/LS 走不到 `search` 关键字分支、全落兜底
  扳手——`AnIcons.toolIcon` 精确表补三条:`Glob→search`、`Grep→search`、`LS→folder`
  (AnIcons 新增 folder 字形;若不愿加字形,LS 退 search)。
- **i18n 新增**:`items(n)/shownOfTotal(x,y)/emptyDir/viewRaw/errDirNotFound/errBadPattern/
  errDenied/errTimeout/matchesInFiles(n,m)/hasMatches`(动词对沿用现有 globbing/grepping/listing 键,精修中文文案)。

---

### `Glob` — 正在检索 → 已检索(Finding files → Found files)

- **收起行**:🔍 search · 动词 · chip = `"“ + args.pattern + ”"`(args-partial,流中片段直接显示)·
  回执 = 解析结果 JSON:`total` → `342 项`(复用 `items(n)` 键,与 LS 一致——matches 的 type 是
  file|dir|link 三值、total 计入目录与符号链接,说「个文件」失实;不按 type 过滤计数,免得与窗头
  分数对不上;total 是**截断前总数**,精确值优于 N+);
  `total:0` → `无匹配`;JSON 解析失败(超时/错误文案)→ 走族级错误前缀分类,无匹配前缀则无回执。
- **活期**:`settle-only`。流光动词 + chip 渐现;>3s 读秒(裸 `**` 大树 walk 的诚实信号)。无 liveBody。
- **落定体**:ToolWindow,窗头 = `"**/*.go" in <root>`(root 中段省略)+ 右侧
  `显示 100 / 共 342`(truncated 时)。体 = `ToolHitList`:每行 glyph(file/dir/link)+
  相对路径 + 右侧 `humanBytes` + `mtime` 紧凑绝对时间,**mtime 降序原样保留**——最新改动在顶,
  结果读起来像「刚发生了什么」的时间线。首 ~16 行 stagger 点亮;封顶 200 行 +
  FadeCollapse + 查看原始输出(原始 JSON 进 `AnJsonTree`@jsonViewport 或 `_cappedMono`)。
- **退化态**:空 → 回执 `无匹配`,bodyless;超时文案 → danger 回执 `超时` + 原文案窗(自动展开,
  文案本身教用户收窄根);truncated → 窗头诚实分数 + 列表尾行 `…仅返回前 100 项(共 342)`;
  JSON 解析失败且非已知前缀 → 原文 mono 窗、无回执。
- **交互**:hover 行 copy 绝对路径(`AnButton.iconOnly` sm);窗头 root 可 copy;查看原始输出逃生口。
  无 in-app 文件浏览器,不做假 deep link。
- **新原语**:`ToolHitList`(族共享)+ `AnCountUp`;JSON 解析器为纯函数(可单测)。
- **Wow**:settle 瞬间收起行计数滚上、亲历落定后的首次展开最新文件从顶端逐行点亮——mtime 降序
  把「文件堆」变成「时间线」,这是后端排序白送的叙事,前端只需不打乱它。
- **可行性**:唯一 JSON 输出、解析最稳;唯一风险是超时/错误分支返**纯文本非 JSON**——解析必须
  以 try/catch 包裹并优雅落 mono 窗(现 `countReceipt` 已容错,保持)。args 只有
  pattern/path/limit 三个小字段,partial 提取无压力。

### `Grep` — 正在搜索 → 已搜索(Grepping → Grepped)

- **收起行**:🔍 search · 动词 · chip = `"pattern"`(args-partial)· 回执按 `output_mode`(settle 时
  args 已完整,读它选解析器):`files_with_matches` → 行数 `N 个文件`;`count` → 逐行
  `path:N` rsplit 求和 → `87 处匹配`,**外加单文件规则:整个输出为单行纯数字 → 按单文件
  count 解析,N 即计数、标签用 args.path 的 basename**(与单文件 basename 显示纪律一致——
  rg 走 `--count-matches` 未传 `--with-filename`[grep_rg.go buildRgArgs],单文件目标输出裸
  `N` 无 path 前缀;stdlib searchCount 恒 `path:N`,双后端在此真实分歧);`content` 有 `-n` →
  按 `:(\d+):` 计匹配行 → `N 行匹配`(**单文件根线缆省略 path 前缀、行形 `12:text`**——
  解析器先做单文件模式检测,**锚定「有效根」而非 args.path 原文**[见可行性对策①:args.path
  可能是 `~/...` 而输出全是展开后绝对路径,原文前缀锚定会把 ~ 根多文件搜索系统性误判成
  单文件],单文件时改按 `^(\d+):` 计);content 无 `-n` 且
  无上下文 → 行数;**无 `-n` 且带 -A/-B/-C(匹配行与上下文行不可靠区分)→ 回执退 `有匹配`
  (无数字,诚实)**。**兜底诚实**:任何模式下解析计数为 0 但输出非空且非 `No matches for`
  前缀 → 回执退 `有匹配`(绝不显示假「0 行匹配」)。命中 `... [truncated at N ...]` 标记 → `N+`;
  `No matches for` 前缀 → `无匹配`。
- **活期**:`settle-only`。同族文法;regex pattern 流入时 chip 逐字符长出来是天然小戏。无 liveBody。
- **落定体(三模式三张脸,窗头统一 query echo:`"TODO(" in <root> · *.go · -i`)**:
  - `files_with_matches`:`ToolHitList` 路径行(仅 glyph + 相对路径——线缆只有路径,不编造 meta)。
  - `count`:`ToolHitList` 的 **热度条变体**:相对路径 + 右侧计数 + 计数底下一条比例条
    (barFraction = n/max,accent 弱色,~64px 满格)——哪个文件是模式的聚居地一眼可见;
    尾行合计 `共 87 处 · 12 个文件`。
  - `content`:`GrepContentView`(族级新原语):按文件**分组**(组头 = 相对路径 + 该文件命中数),
    组内匹配行 = 行号 gutter(右对齐 dim,`-n` 才有;无则无 gutter 平铺)+ 行文本,**行内命中
    span 用 `highlightMatches` 点亮**(Dart RegExp 按 args 重编译,`-i`→caseSensitive:false;
    **`multiline:true` 整体跳过行内高亮**——后端 multiline 编译为 Go `(?s)` dotAll 跨行匹配
    [grep_stdlib.go compileGrepRegex],与 Dart `multiLine`(仅改 `^`/`$` 锚语义)完全两回事,
    映射会点亮错误 span、比无高亮更糟,且跨行匹配本质无法按行重跑复现——走「编译失败→静默
    无高亮」同一条诚实降级路;编译失败 → 静默无高亮);上下文行(`-` 分隔)降为 inkFaint、
    无高亮;行号出现跳跃时插一条 `···` 细分隔;**「整行恰为 `--`」识别为组分隔符,同样翻译成
    `···` 细分隔(与行号跳跃产物统一),绝不当正文渲染**——rg 后端带 -A/-B/-C 时在不连续组间
    输出裸 `--` 行(buildRgArgs 未传 `--no-context-separator`;stdlib 从不输出,双后端在此
    真实分歧,rg 还是装机默认快路径)。逐行解析失败的行**原样渲染**(不丢不猜)。
    **封顶纪律同 ToolHitList(宪法 #8:线缆 256KB 字节帽 ≈ 数千行,展开体绝不无界内联)**:
    渲染封顶 ~200 匹配行(组头计入)+ `AnFadeCollapse`(collapsedHeight 400,fadeColor 显式
    surfaceSunken)+ 底部「查看原始输出」逃生口;`highlightMatches` 只对帽内行执行;
    帽外以尾行诚实注记 `…仅显示前 200 行(共 N)`。
- **退化态**:无匹配 → 回执即卡;256KB 字节帽标记 → 窗底诚实注记 `输出截断于 256KB·收窄
  glob/type 或用 head_limit` + 回执 N+;`Invalid regex pattern:` → danger 回执 `无效模式` 自动展开;
  单文件根(线缆省略 path 前缀)→ content 不分组、files_with_matches 单行;**单文件时路径显示
  一律用 basename、组头/单行不做相对化**(相对文件自身是空串,会显示成空白)。
- **交互**:组头 hover copy 绝对路径;content 匹配行 hover copy `path:line`(可直接粘给 Read/编辑器);
  查看原始输出逃生口。
- **新原语**:`GrepContentView` + `highlightMatches`(纯函数)+ 复用 `ToolHitList`(两 mode)。
- **Wow**:count 模式的热度条 + content 模式命中词逐行点亮——像把编辑器的全局搜索面板搬进对话,
  且每个字都来自线缆、零编造。
- **可行性**:**全族解析风险之最**——rg `--no-heading` 文本先天歧义(路径可含 `:`/`-`、无 -n 无行号、
  单文件根省略前缀),且 **args.path 原文不可信作锚**:后端 Execute 先 `fspath.Expand` 再搜
  (grep.go),输出路径全是展开后绝对路径,args JSON 保留 LLM 原样 `~/...`。对策四条:
  ① **有效根锚定(不用 args.path 原文)**——args.path 为绝对路径时直接用;以 `~` 开头时改用
  去掉 `~` 的**后缀匹配**(如 `~/proj` → 判输出行首绝对路径的目录部分是否以 `/proj` 结尾/延续);
  兜底从已解析行的绝对路径取**最长公共目录前缀**作有效根。单文件模式检测与相对化显示都用
  有效根;窗头 echo 仍显 args 原文;
  ② 解析器逐行容错、失败行原样渲;③ 计数不可靠、或解析计 0 而输出非空时回执退「有匹配」;
  ④ multiline 绝不映射 Dart multiLine(语义不同,见落定体)。**census「rg/stdlib 双后端输出
  语义一致」经真码复核在两处不成立**:单文件 count rg 输出裸数字(无 `--with-filename`)、
  上下文模式 rg 输出裸 `--` 组分隔线(无 `--no-context-separator`)——解析器仍只写一份,但必须
  按上文规则覆盖两形态(即便后端将来抹平,历史 transcript 里的旧输出仍是两形态);可选小改
  后端 buildRgArgs 补 `--with-filename` + `--no-context-separator` 抹平双后端(迭代铁律②允许,
  同提交守 testend 黑盒)。Go RE2 → Dart RegExp 高亮为尽力而为(RE2 无 lookahead,常见 pattern
  均可编译)。歧义行电池必含:单文件根两用例(`-n` 计数按 `^(\d+):`、files_with_matches 单行
  basename 显示)、**`~` 根两用例(~ 根多文件 content 不得误判单文件、~ 根单文件)**、
  **rg 裸数字 count 用例**、**rg 风格含 `--` 的上下文混排用例**;
  `highlightMatches` 单测电池加 multiline 用例锁死跳过行为。

### `LS` — 正在列目录 → 已列出(Listing → Listed)

- **收起行**:📁 folder(新字形)· 动词 · chip = `pathBasename(args.path) + "/"`(不引号;根目录显
  `~` 或 `/` 全文)· 回执 = 解析头行 `(<total> entries)` → `24 项`;`(empty)` → `空目录`;
  截断尾行 `showing L of T` → 回执用 T、体内显分数。
- **活期**:`settle-only`。同族文法;目录列举通常亚秒,活期基本只有一次流光。无 liveBody。
- **落定体**:ToolWindow,窗头 = 目录绝对路径(dim,中段省略)+ 右侧 `显示 200 / 共 483`(截断时)。
  体 = `ToolHitList` 目录清单形:glyph 列(folder / link ↗ / file 圆点)+ 名字(dir 尾随 `/`,
  线缆本就目录优先 + 名字序,原样保留)+ 右侧两列 dim:`humanBytes`、`YYYY-MM-DD HH:MM`
  (仅 file 行有,线缆如此,dir/link 行 meta 留空不编造)。解析 = 头行正则 + 每行前 2 空格 +
  类型 token,任何不匹配行原样渲。stagger 点亮同族。
- **退化态**:空目录 → 回执 `空目录`,bodyless;截断 → 窗头分数 + 尾行
  `…显示 200 / 共 483·提高 limit 可见更多`(线缆尾行的翻译);`Directory not found:` /
  `Not a directory` → danger 回执 `目录不存在`/`不是目录` 自动展开原文案。
- **交互**:hover 行 copy 绝对路径(root + name 拼接);窗头 copy 根路径。
- **新原语**:复用 `ToolHitList`;`AnIcons.folder` 字形。
- **Wow**:一眼真目录——文件夹优先、尺寸右对齐、时间成列,像 Finder 列表视图的极简 mono 版,
  而不是一坨等宽字符汤;它是 ToolHitList 的最纯验收件。
- **可行性**:行式模板最规整(固定 2 空格缩进 + 类型 token 列),解析最容易;唯一注意名字本身
  可含连续空格——按「前两列 token + 余下右对齐 meta 列反向切」解析,切不动就整行原样渲。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| `ToolHitList` | feature(tool_card_skins 侧) | 机器窗内通用命中列表:glyph + 主文本 + 右侧 dim meta 列(含 count 热度条变体),相对根显示(根来源见族级文法:输出自带根 / Grep 有效根,绝不用 args.path 原文)/ hover copy 绝对路径 / 首 16 行 stagger 点亮(**亲历落定置 revealEligible、首次展开且列表真实挂载时消费播一次**——settle 瞬间 body 收拢未挂载,绝不在空气里播;历史挂载静态;标记存 reveal 外层)/ 封顶 200 行 + AnFadeCollapse(显式 surfaceSunken fade)+ 查看原始输出逃生口;gallery specimen 动(revealEligible 首展开)/ 静(历史)双态收录 |
| `GrepContentView` | feature | Grep content 模式分组视图:文件组头(相对路径+命中数)+ 行号 gutter + 行内命中 span 高亮(仅帽内行执行)+ 上下文行降色 + 行号跳跃与**整行 `--`(rg 组分隔)统一译成 `···` 分隔**;逐行容错、失败行原样渲;**封顶 ~200 匹配行(组头计入)+ AnFadeCollapse(collapsedHeight 400,显式 surfaceSunken fade)+ 查看原始输出逃生口 + 帽外尾行诚实注记** |
| `highlightMatches` | feature 纯函数 | `(line, pattern, {ignoreCase, multiline}) → List<TextSpan>`:按 args 重编译 Dart RegExp 点亮命中 span(`-i`→caseSensitive:false);`multiline:true` 或编译失败 → 无高亮原样返回(诚实降级——Go `(?s)` 跨行语义绝不映射 Dart multiLine);脱 widget 可单测(电池含 multiline 用例) |
| `AnCountUp` | core 微原语 | 数字滚升 Text(0→N,~300ms,tabular figures 不抖行宽;reduced→即时终值)——收起行计数回执与结果条通用,「计数揭示」的物理载体;带 `animateOnMount:false` 类开关(历史/挂载即落定的卡直接渲终值),gallery specimen 动/静双态收录。**依赖底盘缝扩展**:现 `ToolReceipt = ({String text, bool danger})` 纯字符串 record 挂不了滚数——须加可选 `count`(int)+`countedText` 模板字段(数据化:行渲染层遇 count 且亲历落定时用 AnCountUp 渲数字段,否则纯文本),同步 WRK-053 tool-cards.md,见建造顺序 2 |
| `AnIcons.folder` + toolIcon 精确表三条 | core 修正 | 新 folder 字形;精确表补 `Glob→search / Grep→search / LS→folder`(修现状三工具落兜底扳手的 bug) |

三个解析器(Glob JSON / Grep 三模式 / LS 行式)均为纯函数,进 `tool_receipts.dart` 同层,脱 widget 单测(空/截断/错误前缀/歧义行/伪装错误文案五电池;Grep 另加单文件根 + `~` 根[多文件 content / 单文件] + rg 裸数字 count + rg `--` 上下文分隔 + multiline 用例)。

## 族内建造顺序建议

1. **AnIcons 修正**(folder 字形 + 精确表三条)——五分钟独立件,先修现状 bug。
2. **回执缝扩展 + AnCountUp**(gallery-first:先进 gallery specimen)——先扩底盘缝:
   `ToolReceipt` 加可选 `count`(int)+`countedText` 模板字段(纯数据化,行渲染层遇 count 且
   亲历落定时用 AnCountUp 渲数字段,否则纯文本;同提交同步 WRK-053 tool-cards.md),再落
   AnCountUp micro——族魂载体,F04 结果条等他族也会要。
3. **ToolHitList + LS**——ToolHitList 进 gallery(revealEligible 动/静双态 specimen),LS 是它
   最纯的验收件(解析最规整、单 meta 形态),一并落 LS 解析器 + 空/截断/错误电池。
4. **Glob**——JSON 解析器 + size/mtime 双 meta 列 + truncated 分数叙事 + 计数揭示全套联动首秀
   (settle 收起行滚数 + 首次展开列表点亮两段齐验)。
5. **Grep files_with_matches / count**——复用 ToolHitList(count 上热度条变体);count 解析器
   带单行纯数字(rg 单文件)用例。
6. **Grep content**(GrepContentView + highlightMatches)——族内最重、解析最险,放最后;
   封顶 + FadeCollapse + 逃生口纪律随首版一起落(不后补);落地时带歧义行电池(路径含
   `:`/`-`、无 -n、单文件根、`~` 根多文件与单文件、rg `--` 上下文混排)+ multiline 高亮跳过 +
   伪装错误文案新用例;有效根锚定(后缀匹配 + 最长公共目录前缀)随首版落。
   可选伴生小改:后端 buildRgArgs 补 `--with-filename` + `--no-context-separator` 抹平双后端
   (同提交守 testend;前端解析器仍须容两形态,历史输出不重写)。
7. **族级错误前缀分类回执**——横切收尾,前缀表按工具分域 + 单行全输出双门(见族级文法);
   文案契约建议加 testend 黑盒锁(前端仅增强性使用:失配只丢回执、不丢内容)。


---

# F03 — shell 族完美态(Bash / BashOutput / KillShell)

> 线缆源:census/01-fs-shell.md §7–9 + census/10-framework.md。族定位(WRK-053 §4):终端窗+exit footer;
> 前台最强 progress 流;后台=持久运行态、BashOutput 增量追加;全族危险 summary 常显。

## 族级统一文法

- **终端窗身份**:全族机器产物住同一 `ToolWindow` 凹陷等宽窗(mono 12 `AnText.code`),
  头槽 = `$ 命令` 回显(Bash)或 `bsh_id` 会话标(BashOutput/KillShell);绝不借 thinking 低语语法。
- **footer 是族签名**:后端把终态编码在结果**尾部**(`[exit code: N]` / `[status: …]` / `[note: …]`)。
  前端统一做「**footer 剥离 → 结构化底条**」:窗体只显正文,尾注解析成底部一行 chips
  (exit chip 按码着色:0=muted、≠0=danger;note chip:超时/取消/拦截/溢出)。解析不上 → 原样显示、
  **无回执**(诚实铁律)。这些文案模式须由 testend 钉死(见风险)。
  ⚠️**双 cap 冲突(顶格输出 footer 必死)**:Bash 自身 256KB cap 保尾弃头**之后**才拼 footer,
  而通用 `ToolResultCapKB` 同为 256、保头截尾——顶格输出时 formatted 结果(头 marker + 256KB 正文
  + footer)必超通用 cap,footer 被砍、且头尾双截断注记方向矛盾;BashOutput 单次 ≤256KB ring +
  status footer 同理。族级对策:① footer 解析器把「尾部存在通用截断后缀
  `...[tool result truncated: ...]`」识别为**一等退化态**——回执降级为「exit 未知」chip(而非无回执;
  真正未知的是 exit、不是内容:「已截断」注记**仅当体=resultText 时并列**,体=progressText 全量在手
  时禁挂,防「看得到全文却标已截断」的混合信号;该退化态并入「截断 chip 与正文源绑定」测试矩阵),
  窗底条显诚实注记「footer 被截断,exit 未知」;② 按迭代守则②给后端小改:Bash/BashOutput 自身
  cap 预留 footer 余量(cap = ToolResultCap − 512B),使 footer 永不被通用 cap 砍;
  ③ testend 加顶格输出用例钉死两条路径。
- **ANSI + \r 管线(族级新地基)**:一切终端文本(活尾/落定窗/增量窗)过同一纯函数管线:
  `termFold`(折叠原地重写:`\r` 回车重写、`ESC[K` 擦行、**`ESC[nA` 上移 + `ESC[2K` 整行擦**
  ——行缓冲回退、仍是纯函数;覆盖 docker pull / cargo / bazel / npm 等 cursor-up 多行进度渲染器,
  进度条原地刷新只留最终帧)→ `ansiSpans`(SGR 16 色映射到主题化 token 色、256/真彩就近降级;
  **bold→w400** 守两档字重铁律、dim→inkFaint、underline 保留)。
  **可重写窗定死上界(增量承诺的前提)**:行缓冲回退只覆盖**最近 64 行可变窗**——窗前行永久凝固,
  增量喂入只处理新 chunk + 窗内回写、绝不全量回扫;`ESC[nA` 的 n 超窗(含异常/注入序列回指深历史)
  即归入下述「范围外 CSI 剥离=堆行退化」,行为有定义、不做错。范围之外的 CSI(绝对寻址/
  滚动区/超窗 cursor-up 等)静默剥离,其堆行效果**声明为已知退化态、如实显示**——Wow 不承诺
  未覆盖场景;五电池单测加 docker-pull 样本 + **超界 n / 跨 chunk 切断转义**注入用例锚定两侧行为。
  chunk 可能切断转义序列,解析器留尾缓冲;渲染层(AnTermTail/AnTermViewport)只 rebuild 可变窗内的行。
- **bash_id 会话链**:三工具共用同一 mono 会话 chip(`bsh_xxxx…`)。**收起行上 chip 纯展示**
  (最多 hover tooltip 显全 id)——32px 裸行整行是底盘展开/收起热区,不嵌套点击目标;
  **点击复制只落在展开体内的 chip**(落定体窗头/底条)。Bash(后台)→ BashOutput×N → KillShell
  在 transcript 里靠这枚 chip 串成一条可目视追踪的会话线。
- **危险姿态**:LLM 自报 summary 在**展开体窗上方常显**(`_intent` 现行);danger=dangerous 时
  V6 确认卡的主角是**完整命令装终端窗** + summary——用户批的是命令本身。后端 6 条灾难硬拦截
  (`blocked:`)是兜底、非 UI 门。
- **reduced motion 全等价(宪法第 6 条)**:AnTermTail 活尾生长在 reduced 下即时替换行内容
  (无 AnimatedSize 式过渡);AnTermViewport stick-to-bottom 与「回到最新」跳底**无平滑滚动**、
  直接定位;AnEdgeFade 是静态渐隐、保留;settled 底条禁呼吸(见 BashOutput)。
  新原语进 gallery specimen 一律带 reduced 态。
- **图标**:`AnIcons.toolIcon` 关键字表现走 `shell|bash|exec→tool(扳手)`;本族拍板:精确表补
  `Bash/BashOutput/KillShell → terminal` 字形(终端窗身份应有终端图标)。palette §6 字形集现
  **无 terminal 字形——属新增图标资产**,已登记进族级新原语汇总、挂建造顺序第 3 步。

---

### `Bash` — 正在运行 → 已运行(后台变体:正在启动后台命令 → 已转入后台)

- **收起行**:terminal icon · 动词(`run_in_background:true` 从 args-partial 检出即切后台动词对)·
  `commandChip(command)` 等宽 chip(首行 + 截断;args 流入期 partial 提取,命令逐字打进 chip)·
  回执 = footer 解析,**优先级写死 note(blocked > 超时 > cancelled)> exit code**(census:取消/
  超时/拦截时 exit 恒 -1,先认 note 才不误染):`blocked:` → `已拦截` danger;超时 → `超时 2m0s`
  danger;取消 → `已取消` muted(**不染 danger、不自动展开**——与底盘 cancelled 相位一致);
  无 note 才看 exit:0 → `exit 0` muted;N≠0 → `exit N` **danger→自动展开**;
  后台 → `bsh_xxxx · 后台` muted。优先级与文案逐字用例钉住。
- **活期(生长秀)**:**前台 = 本族唯一真 progress 流**(`progress 流`:stdout+stderr 原始字节 delta;
  census/10:WebFetch/install_mcp_server/run_function 等他族亦发 progress,「唯一」只对本族成立)。
  行下挂 **`AnTermTail`**(ToolLiveTail v2):尾 6 行、过 termFold+ansiSpans、顶部 `AnEdgeFade`
  渐隐——像一扇开在滚动流上的小窗;npm/wget 的 \r 进度条在窗内**原地刷新**而非逐帧堆行。
  行上 3s 起读秒(底盘已有)。后台模式**无 progress**(`settle-only`):活期只有流光动词,
  spawn 秒回。args 流入期:命令在 chip 里被打出来(`args-partial`)。
- **落定体**:intent 行(summary 常显)→ 终端窗:头 = `$ 命令`(wrap;**超约 8 行折进
  AnFadeCollapse**——census 标 command 准 PAYLOAD,heredoc 写整文件是常态,头部必须有界,
  surfaceSunken 上须显式传 fadeColor;头部 actions 槽 copy 恒为命令全文;widget 测试补 heredoc
  长命令电池)+ 非默认 timeout 时 meta 注 `timeout 5m` → 体 = 输出全文(progressText 优先、否则
  resultText 剥 footer;过 ANSI 管线)装 **`AnTermViewport`** 有界回滚窗(高 ~320,初始贴底=终端
  语义,向上滚回看,底部「回到最新」浮标;初始只物化最近 6000 chars + 显式截断注记,**顶部
  「显示更早 N 行」向上懒加载**——全文已在内存、分段物化 TextSpan、视口仍有界,MB 级中段在
  app 内可读=宪法第 8 条「查看全文」逃生口,copy 全文并列)→
  底条 = exit chip + note chip。**截断 chip 与正文源绑定(写死)**:体=progressText(全量累积、
  无截断)时**禁显** head 截断 chip——exit/note chips 仍从 resultText 的 footer 解析;
  体=resultText(如 DB 重放 progress 块缺失)且检出 `...[truncated N bytes from start]` marker
  时**才显**;双源各钉一条 widget 测试。**后台落定体**:薄一档——bash_id 会话 chip(copy)+ 一句
  时点中立的「已转入后台;输出经 BashOutput 轮询到达」(卡是历史快照,进程可能早已退出,
  不断言当下状态——当前状态判断留给后续 BashOutput 卡)+「请求终止」affordance(见交互;
  Kill 幂等无害,预填保留)。
- **退化态**:空输出+exit 0 → 窗内 `(无输出)` faint + 底条(诚实的静音成功);`blocked:` → 正文为空,
  窗内红字显拦截理由,回执 `已拦截`;结果被 256KB 保尾截断 → 窗**顶**诚实 chip「已截去开头 N 字节」
  (方向与通用截断相反,族内特有;仅体=resultText 时显,见落定体绑定规则);尾部检出通用截断后缀 →
  双 cap 冲突吃掉 footer:回执降级「exit 未知」chip(「已截断」仅体=resultText 时并列,
  体=progressText 全量在手时禁挂——见族级文法对策①),底条注记「footer 被截断,exit 未知」;
  footer 解析失败 → 原样全文、无回执;SSE 断线重连(前台活期)→ progress delta 是
  ephemeral(seq=0 不入 replay buffer),此前活尾内容不可恢复:**活尾清空、丢弃首个换行前的字节
  再续渲**(防从半截 ANSI/UTF-8 序列起头渲成乱码),faint 注记「输出已续接,此前滚动不可回看,
  落定后完整」,落定时以 close 快照全量重建自愈;取消 → 底盘 cancelled 相位 + note chip `已取消`。
- **交互**:头部 copy 命令 / 窗 actions copy 输出;bash_id chip 点击复制(仅展开体,见族级文法);后台卡「请求终止」=
  **composer 预填**「终止后台命令 bsh_x」(不自动发送)——线缆现实:KillShell 是 LLM 工具、
  无 REST 杀进程端点,按钮不能直杀,预填是唯一诚实路径。
- **新原语**:`termFold` + `ansiSpans`(纯函数)· `AnTermTail`(折行+ANSI+顶渐隐活尾)·
  `AnTermViewport`(有界贴底回滚终端窗,palette 缺口 #1/#2)· ToolWindow `actions` 头槽(缺口 #3/#12)。
- **Wow**:命令输出像真终端一样在行下活着滚——进度条原地刷新、颜色保真;落定后凝固成可回滚的
  记录,exit footer 一眼定生死。
- **可行性**:progress delta 无上限(census:截断只作用于 tool_result)——长跑命令 MB 级累积,
  活期必须**增量折行缓存**(只处理新 chunk,禁每帧全量 split);chunk 是原始字节,UTF-8/ANSI 序列
  可被切断,管线留尾缓冲 + 每帧合并(CoalescingNotifier);⚠️顶格输出时 formatted 结果
  (头 marker + 256KB 正文 + footer)必超通用 ToolResultCap、footer 被截尾砍掉——回执解析恰在
  最大输出上死亡,走族级文法「双 cap 冲突」三对策(解析器一等退化态 + 后端 cap 预留余量 +
  testend 顶格用例);无 duration 字段,且线缆 Open/Close 帧不携时间戳、落库是回合末 assembleBlocks
  统一折入(同回合各块时间戳近乎同刻)——**耗时/时点一律 live-only**:前端收帧时打本地时钟、
  存瞬时视图态;DB 重建历史省略耗时、不显假值。要历史可靠须按迭代守则②后端小改
  (close 快照落真实时刻)+ 同提交同步契约文档,本设计不预设。

### `BashOutput` — 正在轮询输出 → 已轮询

- **收起行**:terminal icon · 动词 · bash_id 会话 chip(args 提取)· 回执 = 增量行数 + 状态:
  `+42 行 · 运行中` / `无新输出 · 运行中` / `+7 行 · exit 0`(muted)/ `exit N` danger /
  `已终止` muted / `错误` danger;`Background shell process not found:` 文案 → `会话不存在` danger→自动展开。
  **exited(N)/errored 只染 danger 色、不自动展开**——进程死后每次轮询都返回同一 status,逐卡
  自动展开会把同一次失败在 transcript 里反复摊开(违「历史像目录不像日志」);本族自动展开
  只留「会话不存在」与 Bash 前台 exit≠0。
- **活期(生长秀)**:`settle-only`(单发无 progress)——流光动词 + 读秒;bash_id chip 从
  args-partial 先亮。
- **落定体**:终端窗:头 = bash_id 会话 chip + filter 存在时 `filter: /regex/` mono 注(游标语义
  meta 行「增量 · 自上次轮询」)→ 体 = 新输出过 ANSI 管线、装 AnTermViewport(同 Bash)→
  底条 = status chip(running=**静态** accent 点,文案「运行中·轮询时点」/ exited(0)=muted /
  exited(N)=danger / killed=muted / errored=danger)+ 溢出 note chip「缓冲已丢弃开头 N 字节」
  (诚实铁律)。**status 是轮询时点快照**——卡是历史,不活体刷新(下一次轮询是下一张卡);
  **时点本身 live-only**(线缆帧无时间戳,落库块时间戳是回合末统一折入、非真实时刻):前端收帧时
  打本地时钟入瞬时视图态、窗头 meta 显之,DB 重建时该 meta 省略或显式「时点未知」(同 Bash
  耗时规则,不用假时刻充诚实支柱);故 settled 底条**禁一切呼吸动效**(呼吸=「此刻活着」语义,进程可能早已退出,
  且 N 张历史卡各挂常驻动画违「历史读起来像目录」+ 无谓重绘)——呼吸只属于底盘真活期相位
  (argsStreaming/running),`AnStatusDot` 不进任何 settled 底条。
- **退化态**:`(no new output since last poll)` → 窗内 faint 一句「自上次轮询无新输出」+ 底条;
  会话不存在 → danger 行只陈述线缆事实「后台会话不存在:bsh_x」,下挂 faint 中性穷举 hint
  「已被终止 / 已清理 / 后端已重启」(绝不单一断言成因——回执铁律不猜);filter 滤空与真无输出
  线缆不可分——如实显示无新输出,filter 注在头上让用户自判。
- **交互**:copy 输出 / copy bash_id;status=running 时底条尾缀「请求终止」composer 预填(同 Bash 后台)。
- **新原语**:复用 Bash 全套(AnTermViewport/管线/底条);新增仅 `statusReceipt` 解析器(receipts 层)。
- **Wow**:每次轮询是同一后台会话的「续页」——bash_id 链 + 增量 meta + 状态快照,后台进程的
  一生在 transcript 里读起来像分章连载而非碎日志。
- **可行性**:增量正文 ≤256KB 单次、体积可控——但单次顶格(ring 满额)时 status footer 同中
  「双 cap 冲突」(见族级文法:解析器一等退化态 + 后端 cap 余量修复覆盖本工具);行数回执 =
  剥 footer 后行计数(确定性);status/note 全靠尾行文案模式解析,testend 钉住;
  filter 是后端过滤,前端零再过滤。

### `KillShell` — 正在终止 → 已终止(薄卡)

- **收起行**:terminal icon · 动词 · bash_id 会话 chip · 回执三态(逐字文案匹配):
  `Killed background shell` → 无回执(动词自足);`already finished; removed` → `已自行结束` muted
  (诚实纠偏:不是我杀的);`not found` → `会话不存在` warn。
- **活期**:`settle-only`,流光动词一闪即settled(组杀是瞬时)。
- **落定体**:通用薄体——intent 行(summary,进程终止属 cautious/危险倾向,常显)+ 结果原句装
  小机器窗。多数情况用户永不展开;幂等无害,不配确认剧场(克制条款:kill 就该是薄卡)。
- **退化态**:三种文案全是 err==nil 正常结果,无失败相位;文案不匹配 → 无回执、通用体兜底。
- **交互**:copy bash_id;无 deep link。
- **新原语**:无(全量复用族地基 + 通用体)。
- **Wow**:回执敢说「已自行结束」——连"没杀成因为它自己死了"这种幂等细节都如实入账,
  会话链的终章绝不撒谎。
- **可行性**:输出恒小、单发;三文案在 census 里逐字锚定,变更风险同族 footer 一并 testend 钉。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| `termFold` | core 纯函数 | 折叠原地重写:`\r`、`ESC[K`、`ESC[nA`+`ESC[2K`(cursor-up 多行进度;行缓冲回退限**最近 64 行可变窗**,超窗 n 归入范围外退化),只留最终帧;范围外 CSI 剥离=声明的堆行退化;增量喂入、尾缓冲防切断 |
| `ansiSpans` | core 纯函数 | SGR→TextSpan:16 色主题化映射(bold→w400 守两档字重)、256/真彩降级、其余 CSI 剥离 |
| `AnTermTail` | feature(ToolLiveTail v2) | 活尾 6 行:termFold+ansiSpans+顶部 AnEdgeFade;增量行缓存,禁每帧全量 split,只 rebuild 可变窗内行;reduced 下即时替换 |
| `AnTermViewport` | core/ui | 有界(~320)贴底回滚终端窗:初始 stick-to-bottom、上滚回看、「回到最新」浮标、初始封顶+诚实截断+「显示更早 N 行」懒加载查看全文+copy 并列逃生口;reduced 下跳底无平滑滚动(补 palette 缺口 #1/#2) |
| ToolWindow `actions` 头槽 | feature 扩展 | 机器窗头部动作位(copy 命令/输出),补缺口 #3/#12 |
| footer 解析器组 | receipts 层 | `bashReceipt` 扩展(note 优先于 exit:blocked > 超时 > cancelled;后台 bsh_id)+ `statusReceipt`(BashOutput 四态+溢出)+ KillShell 三态——全部逐字文案锚定;尾部通用截断后缀=一等退化态(回执降级「exit 未知」而非无回执,「已截断」仅体=resultText 时并列) |
| AnIcons `terminal` 字形 | core/ui 图标资产(**新增**) | 终端字形进精确表(Bash/BashOutput/KillShell)——palette §6 字形集现缺,须新画 |

## 族内建造顺序建议

1. **`termFold` + `ansiSpans`**(纯函数 + 五电池单测:空/超长/注入 ANSI 半截转义/海量 \r/极值色
   + docker-pull cursor-up 多行进度样本 + 超界 ESC[nA / 跨 chunk 切断转义注入用例)——族地基,先立。
2. **footer 解析器组**(receipts 层 + 逐字文案测试 + 双 cap 顶格截断退化用例)——收起行回执立刻
   升级,零 UI 风险。配套后端小改(迭代守则②):Bash/BashOutput cap 预留 footer 余量
   (= ToolResultCap − 512B)+ testend 顶格输出用例,同提交守后端纪律。
3. **`AnTermTail`** 替换现 ToolLiveTail(Bash 前台活期)+ **AnIcons `terminal` 字形**(新资产,
   同批可见收益)——最可见的收益,依赖 1。
4. **`AnTermViewport` + ToolWindow actions 槽**(gallery-first 进 specimen)——Bash/BashOutput 落定体。
5. **BashOutput 卡**(增量窗+status 底条+溢出诚实链)——依赖 2/4。
6. **KillShell 薄卡** + bash_id 会话 chip 统一(copy 交互)——收尾串链。
7. (可选)「请求终止」composer 预填 affordance——依赖 composer 注入缝,可独立后补。


---

# F04 — builds 族完美态(create/edit × function/handler/agent/workflow/control/approval/document/skill + create/edit_trigger,18 工具)

> 线缆事实源:census 02(fn/hd)、03(agent)、04(workflow)、05(ctrl/appr)、06(doc/skill)、07(trigger);
> 乐器:palette.md;图:graph.md。本族是 pivot 旗舰:create_workflow 图生长 / edit_workflow 图 morph /
> create_function 代码生长是用户点名三大场景。

---

## 族级统一文法

- **动词带类名词**(已落 i18n):`正在创建函数 → 已创建函数` / `正在更新工作流 → 已更新工作流`。
  收起行 icon 统一用**实体字形**(建的是什么 > 做的是什么)——须补 `AnIcons.toolIcon` 精确表:现在
  `create_control`/`create_approval` 走关键字推断落到锤/兜底,18 工具全部显式映射到对应实体形。
- **目标 chip**:create = 流中 `args.name`(`argStringPartial`,name 通常是首批 args 键,几百 ms 内打入);
  edit = 实体 id(mono);实体缓存有名则 settle 后换显示名。
- **回执 = id·vN·env 三色**(族级标准):`v1` tabular;fn/hd 追加 env 三色(ready ok / building warn /
  failed danger→自动展开);workflow create 追加 `未激活`(warn——建了≠上线的宪法级诚实);document 回执 =
  path 尾段;skill = slug;trigger = kind badge。**回执解析不匹配 → 无回执**(铁律 4)。
- **活期两层**:①args 流入期 = **内容窗**(本族全系统最强流式:代码窗/稿子窗/op ticker/规则梯/配置 KV,
  按 payload 类型分派,见各工具);②running 期(仅 fn/hd)= env-fix progress 尾行(`✓/✗/↻` 逐行,
  ToolLiveTail 缀于内容窗下)。**流动期成本纪律(铁律 8)**:代码类流动期纯 mono 不高亮;prose 类
  流动期只渲**尾窗切片**(末 4–6KB,按字节界——前文已滚出定高窗,不参与重排),切片**整体每帧重渲**
  AnMarkdown(切片有界故代价可受;未闭合围栏靠 AnMarkdown 流式容忍,**无围栏态机、无逐块 memo、
  无块边界切分**——切口落在 block 中间的顶部残迹由 AnEdgeFade 遮蔽);落定才换高亮/完整渲染态
  (受下条落定期纪律约束)。
- **落定期成本纪律(铁律 8,与流动期条款对称)**:prose 落定体一律**物理截喂**——AnFadeCollapse
  只是视觉裁切(ClipRect+heightFactor),child 全量 parse+layout 照付,1MB document 全文一次性排版
  = 秒级冻结 + 巨量内存,不可接受。落定渲染只喂**首 N KB / 首 M 个 block**(与底盘 6000 char 封顶
  同族定档)进 AnMarkdown,超限必带显式截断注记(「已截断 · 共 X KB」)+ 逃生口(「在实体面板 /
  documents 海洋查看全文」);document content / agent prompt / approval template / skill body 同规。
- **diff 尺寸门(AnVersionDiff 面向短中内容:每 build 全量 LCS + 逐行 IntrinsicWidth、无虚拟化)**:
  任一侧 >~50KB 或 >2000 行 → 不提供 diff tab,渲注记「内容过大,请在实体面板对比版本」;门内照常。
  此门入 before 懒取统一缝规格,四张用 AnVersionDiff 的卡(edit_function / edit_agent /
  edit_document / edit_approval)一次覆盖。
- **reduced motion(铁律 6,族级统一)**:计数徽标 120ms 亮度脉冲 / chip 次第淡入 / ticker 溶解 /
  结果条状态脉冲等一切微动效统一过 `AnMotionPref` reducedOrAssistive → **即时呈现**(chip 直接
  出现、计数直接跳终值),信息零丢失;图回放门控见 create_workflow。
- **结果条(升级现有 `_BuildResultBar` 为公共件 `BuildResultBar`)**:`AnRefPill(kind,id)` 可点跳实体
  面板 · vN · env 三色 · per-kind 扩展槽(envFixAttempts 时间线 / lifecycleState / listening / runtimeWarning)。
  create/edit 返回键不一致须兜:agent create 是 `id`、edit 是 `agentId`;workflow revert 是 `activeVersionId`
  (非本族但解析器共用);skill 无 id、RefPill 用 name(relation id = slug)。
- **morph 母语按补丁风格分派**(census 逐族核实):ops 整段替换(fn/hd/wf)→ 新内容为主、diff 需 before
  懒取;merge patch(agent、hd update_method)→ 键出现即「触碰 chips」;整体替换(ctrl/appr/skill、
  trigger config)→ **全新快照渲染**,绝不渲「未变」;字段 patch(doc/trigger meta)→ delta chips。
  **before 懒取**统一策略:展开时经实体 versions REST / 实体缓存取 vN−1;取不到 → 诚实注记
  「无旧版对比」只渲新态,绝不猜。
- **诚实矩阵(族级)**:env 半成功(envStatus failed 而工具 ok)、edit_handler `runtimeWarning`(brick
  揭穿)、document 软失败句(err=nil 但句为失败 → amber 卡)、create_document 自动改名 note、
  edit_skill 无版本可回退、create_workflow inactive、trigger create 恒 `listening:false`。
- **性能**:代码窗流动期 = 尾 N 行纯 mono(现 buildLiveBody 模式);prose 活窗只喂尾窗切片进
  AnMarkdown(ToolLiveWindow 的定高 clip 不省 layout 成本,必须物理截喂——1MB document 全文每
  delta 重 parse+layout 不可接受;有界切片整体重渲可受);**落定体同样物理截喂**(见「落定期
  成本纪律」);op ticker 每帧只对**新增字节**跑 `partialJsonEvents` 增量解析;图**绝不**流中
  重布局——settle-then-replay(graph.md §5)。

---

### `create_function` — 正在创建函数 → 已创建函数 ★旗舰:代码生长
- **收起行**:函数形 icon · 动词 · chip=流中 `set_meta.name` · 回执 `v1 · env 三色`(结果 JSON 的
  version/envStatus/envError;envFailed → danger 自动展开)。
- **活期**(`args-partial` + `progress 流`):
  - 分镜:t0 args 首字节 → 裸行 shimmer,无 chip;t1 `set_meta` 闭合 → name 打入 chip;t2 `set_code.code`
    字符串开始流 → **活代码窗**展开,代码尾 8 行逐字打出(纯 mono 12,窗随内容长,AnExpandReveal host);
    t3 `set_dependencies` 闭合 → 窗头亮 deps chips;t4 args 完 → running,若装依赖 → 窗下 ToolLiveTail
    progress 行(`✓ env ready` / `✗ attempt N failed` / `↻ revising deps with an LLM`——自愈过程可见);
    t5 settle → 活窗溶入落定体,收起行落「已创建函数 · name · v1 · env 就绪」。
- **落定体**:intent(summary)· `AnCodeEditor(code, python, reading)`(超长 AnFadeCollapse 400)·
  签名行(inputs→outputs,`name:type` mono)· deps AnTags readOnly · **结果条**:RefPill(fn_id) · v1 ·
  env 三色 · envFixAttempts>1 时 **EnvFixTimeline**(attempt N ✓/✗ + deps chips + error 行)。
- **退化**:无 set_code(违约)→ args JSON 窗兜底;envError → 红 mono 行;`FUNCTION_INVALID_CODE`
  /`FUNCTION_NAME_DUPLICATE` → 错误卡(message 已可自解释)。
- **交互**:RefPill 跳实体面板;代码窗 copy;「在实体面板打开」。
- **新原语**:`partialJsonEvents`(path-aware 流中增量 JSON 事件解析,全族共用)、`EnvFixTimeline`。
- **Wow**:函数在窗里被打出来;依赖装挂时你看着它「自己治好自己」(↻ 改依赖重试 ≤3)。
- **可行性**:code 是 string 字段,`argStringPartial` 已验证可流提;ops 元素闭合即可提(平衡括号);
  progress 是真实块;多个 set_code 后者胜 → 取最后一个完整 + 当前流中者。

### `edit_function` — 正在更新函数 → 已更新函数
- **收起行**:chip=functionId(缓存名优先)· 回执 `vN · env 三色`。
- **活期**:同 create(新 code 流入活代码窗);**空 ops**(合法:仅重建 env)→ 无内容窗,直接 progress 尾。
- **落定体**:每个 op 一段陈列:set_code → 代码窗;set_inputs/outputs → 签名行;set_meta → delta chips;
  结果条同 create。
- **morph**:展开时懒取 vN−1 code(versions REST/实体缓存)→ `AnVersionDiff(before, after, python)`
  (过族级 diff 尺寸门:任一侧超限 → 无 diff tab + 「在实体面板对比版本」注记);
  取不到 → 新码 + 注记「无法取得 v(N−1) 对比」。
- **退化**:空 ops → 薄卡(回执「仅重建环境 · env 三色」);`FUNCTION_VERSION_CONFLICT` → 错误卡
  「并发编辑撞版,先 get_function 重读」。
- **交互**:「对比 vN−1 → vN」跳实体面板版本页。
- **新原语**:复用 create 全套 + AnVersionDiff。
- **Wow**:「这次编辑到底改了什么」在卡内一屏直答,不用离开对话。
- **可行性**:ops=整段替换 → 行级 diff 只能靠 before 懒取;版本 REST 缝是本卡完整形态的前置依赖。

### `create_handler` — 正在创建处理器 → 已创建处理器
- **收起行**:处理器形 icon · chip=name · 回执 `v1 · env 三色`。**绝不显示运行态**(census:create 刻意
  不报 runtimeState,新 handler 不 spawn 是预期)。
- **活期**(args-partial + progress):`add_method` op 闭合 → **method chip 逐个点亮**(name mono 药丸排,
  streaming method 带 ⚡ 标);当前流入的 `body`/`initBody`/`imports` 进活代码窗尾 8 行;args 完 →
  env-fix progress 尾。
- **落定体**:类解剖卡——imports 窗(AnDisclosure 折叠)· init/shutdown 段(有则显)· **methods 手风琴**
  (每 method 一个 AnDisclosure:name · streaming ⚡ · timeout badge · 签名行 · body AnCodeEditor)·
  initArgsSchema 表(AnKv:name/type/required;sensitive → 🔒 chip,值永不显)· deps tags ·
  结果条 + 注记行**按 args 派生分叉**(本注记本质是对后端行为的预测,措辞按可证度分档):
  `set_init_args_schema` 含 **required 且无 default** 的项 → 「实例未启动——先
  update_handler_config 配置」;required 项全带 default → 中性措辞「可能需先配置」(InitArgSpec
  的 default 是否自动填充未经线缆证实,不下硬断言;核实后端语义后再定稿);无 required 项 →
  「实例将在首次调用时自动启动」(inkFaint——无必填配置的 handler 首次 call_handler 即自动 spawn)。
- **退化**:add_method 顶层多余键(census 防呆)→ `HANDLER_OP_INVALID` details 展开回示正确形状。
- **交互**:RefPill 跳实体;method 手风琴独立展开。
- **新原语**:复用 fn 套件;methods 手风琴用现成 AnDisclosure。
- **Wow**:一个常驻服务的解剖图在眼前逐 method 组装,秘密参数天生带锁。

### `edit_handler` — 正在更新处理器 → 已更新处理器(本族最重的诚实卡)
- **收起行**:chip=handlerId · 回执三径分派:①全 set_meta → 「已改元数据(不重启)」;②空 ops →
  「已重建环境 · 已重启」;③普通 → `vN · env 三色`;**runtimeState≠running → danger 回执
  「实例未运行」+ 自动展开**(env ready 但 `__init__` 坏 = brick,靠这字段揭穿假成功)。
- **活期**:同 create(代码窗 + method chips + env-fix 尾)。
- **落定体**:普通径 = create 布局 + 结果条追加 `runtimeState` badge;`runtimeWarning` 非空 → 红字整句
  (原文引导 fix or revert_handler);空 ops 径 → `restartNote` 整句 amber(「内存态已抹」非 no-op 提醒);
  set_meta 径 → delta chips 薄卡(「不铸版本、内存态保全」注记)。
- **morph**:`update_method` 是全族唯一 merge patch → **patch 键分流**(机器产物住机器窗,铁律 2,
  代码绝不进裸 chip):标量键(description/streaming/timeout)→ **method 字段级 delta chips**
  (`timeout: 3000→8000`,null 键 → 「已删」红 chip);**代码键 `body`**(method patch 里唯一的
  代码 payload 键;imports/initBody 走 set_* 整替 op,不经此径)→ 渲「body 已替换 · ±N 行」摘要
  chip,点开进代码窗:before 可得 → AnVersionDiff(过 diff 尺寸门),不可得 → 新码窗 +
  「无旧版对比」注记;inputs/outputs(结构化数组)→ 签名行渲新值,不塞 chip。⚠️ patch 线缆只带
  新值与 null 删键——旧值(3000)走族级 before 懒取(实体缓存 / get_handler);取不到 → AnDeltaChip
  退化为「触碰键 + 新值」(null 键仍确定渲「已删」,删除语义在 patch 本身);set_*(imports/init/
  shutdown)整替 → 同 edit_function 的 before 懒取 diff。
- **退化**:三径判定失败(结果键缺)→ 通用结果条,不猜径。
- **交互**:runtimeWarning 卡内按钮「revert_handler 建议」仅为文案提示(不代打)。
- **新原语**:`AnDeltaChip`(`key: old → new` 变更药丸,edit morph 全族通用)。
- **Wow**:卡自己揭穿「环境好了但实例没起来」的假成功——三条路径三种嗓音。

### `create_agent` — 正在创建智能体 → 已创建智能体
- **收起行**:智能体形 icon · chip=name · 回执 `v1`。
- **活期**(args-partial):**稿子流出**——`ToolLiveWindow`(有界底对齐渲染窗)里 `AnMarkdown` 渲染
  prompt 生长(渲染态,非源码瀑布;AnMarkdown A 级流式、容忍未闭合围栏);**装备架逐件挂上**:
  skill/knowledge/tools 键闭合 → RefPill 逐个亮(fn_/hd_.method/mcp: 按前缀推 kind)。
- **落定体**:岗位档案卡——prompt(AnMarkdown + AnFadeCollapse;**族级落定期截断**:只喂首 N KB,
  超限注记「已截断 · 共 X KB」+ 「在实体面板查看全文」逃生口——prompt 无线缆上限,绝不全文排版)·
  装备区(tools/knowledge/skill RefPill wrap,可点跳)· inputs/outputs 签名行(outputs 非空 →
  「终答为结构化 JSON」注记)· modelOverride chip · 结果条 RefPill(ag_id) · v1。
- **退化**:`AGENT_SKILL_NOT_FOUND`/`AGENT_KNOWLEDGE_NOT_FOUND`/`AGENT_TOOLS_AGENT_REF`(禁 ag_)→
  错误卡指名坏引用;prompt 空 → 校验错(`AGENT_NAME_PROMPT_REQUIRED`)。
- **交互**:每个装备 RefPill 深链;RefPill(ag_id) 跳实体面板。
- **新原语**:`ToolLiveWindow`(定高、内容底对齐 clip、顶部 AnEdgeFade——prose 类 payload 的
  「稿子流出」载体,document/skill/approval 共用)。**契约两条写死**:①只喂尾部切片(末 4–6KB,
  **按字节界**)进 AnMarkdown——滚出定高窗的前文不参与重排;②切片**整体每帧重渲**,无逐块 memo、
  无块切分器、无围栏态机(未闭合围栏靠 AnMarkdown A 级流式容忍;切口落在 block 中间的顶部残迹由
  AnEdgeFade 遮蔽),settle 才换完整渲染(受族级落定期截断纪律)。逐块 memo 是后续优化候选——
  届时须显式声明块切分 + 围栏态检测能力并配注入电池(围栏/表格/列表跨切片截断),不入首版契约。
- **Wow**:一份岗位说明书被写出来的同时,它的装备架在旁边逐件挂上。

### `edit_agent` — 正在更新智能体 → 已更新智能体
- **收起行**:chip=agentId(缓存名)· 回执 `vN`(结果键是 `agentId`,解析器兜)。
- **活期**:prompt 流出(同 create);无 prompt 的纯挂载编辑 → 只有触碰 chips 亮。
- **落定体 / morph**(merge patch = 本族最干净的 morph 源):首行**触碰 chips**——请求 JSON 里
  「键实际出现」的字段即列(prompt/skill/knowledge/tools/inputs/outputs/modelOverride);显式清空
  (`[]`/`""`/null)→ 「已清空」amber chip。prompt → before 懒取 diff(同 edit_function);
  tools/knowledge → **集合 delta**(与实体缓存旧集比:+N 绿 pill / −N 红 pill;无缓存 → 新集全量)。
- **退化**:`AGENT_META_NOT_IN_EDIT`(name/description/tags 混入)→ 错误卡引导 update_agent_meta
  (后端 message 自带指引,原句展示);`AGENT_VERSION_CONFLICT` → 同 fn。
- **交互**:「对比 vN−1」跳实体版本页。
- **新原语**:复用 AnDeltaChip + ToolLiveWindow。
- **Wow**:merge 语义被忠实翻译——你只看到真被触碰的键,一个没多、一个没少。

### `create_workflow` — 正在创建工作流 → 已创建工作流 ★旗舰:图生长
- **收起行**:工作流形 icon · chip=args.name · 回执 **`v1 · 未激活`**(warn tone——lifecycleState:
  inactive 直读结果;建了≠上线,回执替用户记住这件事)。
- **活期(幕一,args-partial:op ticker)**:诚实评估(graph.md §3):流中渲画布 = 每快照重布局 →
  节点瞬移、前向边翻回边、路由风格突变——**跳变不可接受,流中不画图**。替代:`partialJsonEvents`
  逐个提取闭合的 op:
  - 顶行**计数徽标**跳动:`节点 ×N · 边 ×M`(tabular,每 +1 一次 120ms 亮度脉冲);
  - 下方 **chip 流**:add_node 闭合 → `[kind字形] node-id` chip 淡入(kind 五色族与画布同源:
    trigger violet / action accent / agent teal / control warn / approval danger);add_edge →
    `a → b` 细 chip;set_meta → 灰 chip。wrap 排布,超 24 枚折「+N」。
- **落定(幕二,settle-then-replay 生长秀)**:**权威图源 = after 取数缝**(与 edit_workflow 共用):
  settle 后经实体缓存 / `GET /workflows/{id}` 取 active 版本 `graphParsed`——创建成功后 active 即
  所建图;前端 ops→Graph 折算**仅作回放分镜与 ticker 输入、不作图源**(后端在 ParseOps 前跑
  jsonrepair,LLM 畸形 JSON 可被后端救活成功创建,而前端折算可能失败或折出不同图——旗舰画布绝不
  渲可能失真的折算结果)。完整图到手 → `layoutGraph` **一次**、几何冻结 → `AnMiniGraph`(framed 380
  只读)按拓扑 rank staggered 揭示:节点 fade+scale 浮现(单 controller + rank Interval)、边
  draw-in(`PathMetric.extractPath(0, len*t)`,箭头随尖端)、回边最后入场;时长 = rank 数 × 250ms
  封顶 3s;`AnMotionPref` reduced → 直落终态,信息零丢失。
- **分镜**:t0 args 首字节 → 裸行 shimmer;t1 name 闭合 → chip 打入;t2 首个 add_node 闭合 →
  「节点 ×1」+ 首 chip 亮;t3 op 流继续,chips 次第点亮、计数跳动;t4 args 完 → running(校验+落库,
  亚秒);t5 settle → ticker 溶解,取 after 图(实体缓存 / GET workflow),mini 画布浮现并**回放生长**;t6 回放毕 → 收起行落
  「已创建工作流 · name · v1 · 未激活」。
- **落定体**:intent · AnMiniGraph · 图下 KV(节点/边数 · concurrency · changeReason)· 结果条
  RefPill(wf_id) · v1 · `未激活` badge + 提示行「activate_workflow 上线 / trigger_workflow 试跑」。
- **退化**:流中 op 畸形(后端有 jsonrepair,前端提取器自己容错)→ ticker 退化为「op ×N」纯计数;
  settle 后 **after 取数失败且折算不可信 → 诚实降级为「节点 ×N · 边 ×M」图例卡 + 已亮 chips +
  注记「图不可得」,绝不渲可能失真的画布**;`WORKFLOW_INVALID_GRAPH`/`WORKFLOW_INVALID_OPS` →
  错误卡带 details.reason(`ops[i] (op): 原因`精确定位),已亮 chips 保留——看得到它建到哪儿断的;
  >40 节点 → 画布可承(gallery 有 40 节点 specimen),回放封顶。
- **交互**:mini 画布点节点 → 跳 workflow 编辑器选中该节点;「重放」小按钮再看一次生长;RefPill 深链。
- **新原语**:`AnMiniGraph`(graph.md 路 C,~200-300 行)+ `GraphRevealState` + 画布揭示面
  (~300-450 行;graph.md §5 判定:与现有架构天然契合、全部动画原语同文件已有活用例)。
- **Wow**:用户点名的场景——蓝图先以零件清单点亮,落定瞬间在画布上按依赖序长成整图。
- **可行性**:权威图源 = settle 后 after 取数缝(实体缓存 / GET workflow 的 graphParsed),
  jsonrepair 分叉对落定画布免疫;ops→Graph 折算(add_node/add_edge 序列直接构图)纯 Dart 可单测,
  仅供回放分镜 / ticker;auto-layout 恒走(LLM 不发 pos)→ 冻结一次无跳变;settle-then-replay 是
  绕开增量布局的正确路径(graph.md 结论)。

### `edit_workflow` — 正在更新工作流 → 已更新工作流 ★旗舰:图 morph
- **收起行**:chip=workflowId(缓存名)· 回执 `vN`。
- **活期**:op ticker 的 **delta 方言**——op 动词着色:`+node` 绿 / `−node` 红 / `~node` amber /
  边同理 / set_meta 灰;顶行计数徽标 `+2 −1 ~3`(三色 tabular)。数据源 args-partial,同 create。
- **落定(morph 幕)**:关键洞察——**added/updated/deleted 集合从 ops 本身精确导出,无需 before 图**
  (add_node/delete_node/update_node 自带 id);但 **after 图不是 ops 可导出物**——ops 是施加在
  前端并不持有的 active 图上的 delta,画布必须 settle 后取数。三级方案:
  - **基本形(after 可得:settle 后经实体缓存 / GET /workflows/{id} 取 active 版本 graphParsed——
    此刻 active 即 after)**:AnMiniGraph 渲 after 图 + `GraphMorphState` 覆层:added 节点
    绿晕浮现、updated 节点呼吸一拍(breath 脉冲复用 W3 基建)、added 边 draw-in;deleted 无几何 →
    图下「已移除」名册:红划线 ghost chips(node id ×N,诚实降级)。
  - **完整形(before 也可得:实体缓存 vN−1 graphParsed / versions REST)**:before 图先渲 → deleted
    红晕淡出 → 存留节点 AnimatedPositioned 位移到 after 冻结布局(matched geometry,先例
    an_tabs/AnOceanSwitcher)→ added 浮现 + 边 draw-in。
  - **纯 delta 形(after 取数失败,零依赖恒可用)**:无画布——delta 图例 + 已亮 op chips +
    「已移除」名册 + 诚实注记「图不可得,仅列变更」。
- **分镜**:t0 chip=wf 名;t1 ops 流 → 三色计数跳;t2 settle → 取 after 图(实体缓存/GET workflow)
  → 图浮现,新节点绿晕次第长出、被改节点呼吸一拍、新边画入;t3 图下 **delta 图例**:`+2 节点 ·
  +1 边 · ~1 节点 · −1 边` + 已移除名册;
  t4 收起行落「已更新工作流 · name · v5」。
- **落定体**:intent · morph 画布 · delta 图例 · changeReason · 结果条 RefPill · vN ·
  「对比 v4 → v5」按钮(跳实体面板版本 diff)。
- **退化**:after 可得而 before 不可得 → 基本形;after 也取不到 → 纯 delta 形(图例 + chips +
  名册,无画布);`WORKFLOW_VERSION_CONFLICT`
  → 「并发编辑撞版」错误卡;update_node 的 patch 内 input 整对象替换 → 图例中 `~node` 不细分字段
  (诚实:不渲键级 diff,点节点跳编辑器看)。
- **交互**:画布节点点击跳编辑器;图例 chips hover 高亮画布对应节点。
- **新原语**:`GraphMorphState`(GraphRevealState 的 delta 变体,同一揭示面)。
- **Wow**:旧图长出新枝、枯枝以名册退场——变更审计变成一眼可读的动画。
- **可行性**:delta 集合零依赖(ops 即真相);**画布依赖 after 取数**(settle 后实体缓存 /
  GET /workflows/{id},active 版本即 after——这条取数可失败,与 before 缝同类);完整 morph 再
  依赖 before 版本缝;三级分级交付。

### `create_control` — 正在创建控制 → 已创建控制
- **收起行**:控制形 icon · chip=name · 回执 `v1`。
- **活期**(args-partial):branches 也是对象数组 → `partialJsonEvents` 同一解析器——**决策梯逐格亮起**:
  每条闭合 → `① [port badge] when-CEL(mono 13)` 行浮现;流中一律按普通规则行渲(流中无从知哪条
  是末条,且中段分支合法可 when 恒真——后端只校验末条,绝不流中猜「否则」);settle 拿到完整
  branches 后,仅当末条 when=="true" 才切「否则 → port」灰底钉底样式。
- **落定体**:**规则梯 `BranchRuleList`**——有序行 ①②③(first-true-wins 视觉:序号即语义)·
  port AnBadge(accent)· when CEL mono · emit chips(`key ← CEL`);catch-all 钉底灰行;头部 inputs
  签名行(when/emit 只可读 `input.*`,签名即词表)。结果条 RefPill(ctl_id) · v1。
- **退化**:`CONTROL_INVALID_CEL` → 错误卡展开 **details{branch, when|emit, reason}**(真 cel-go
  编译错,census 证实带 branch 索引)并**红框定位到第 N 条规则行**;`CONTROL_NO_CATCHALL` → 梯底
  虚线空行 + 红提示「末条必须 when:"true" 兜底」(定位靠错误码语义本身——兜底恒在末行,不依赖
  details);`CONTROL_INVALID_BRANCHES`(空/port 空/port 重复)→ **通用错误卡渲 message 原句**——
  其 details 形状未经线缆证实,不做行定位(核实后端 details 后再升级定位能力)。
- **交互**:RefPill 深链;CEL 行 copy。
- **新原语**:`BranchRuleList`(feature 件:有序规则行 + catch-all 钉底 + 错误行定位)。
- **Wow**:路由逻辑不是 JSON——是一架决策梯,一格格亮起、兜底垫在最下,坏格子会被红框点名。

### `edit_control` — 正在更新控制 → 已更新控制
- **收起行**:chip=controlId · 回执 `vN`。
- **活期**:新决策梯逐格亮(同 create)。
- **落定 / morph**:**整体替换语义**(census:"Pass the COMPLETE branch list")→ 默认渲全新快照梯;
  before 可得(versions REST)→ **行级 port 对齐 diff**:新增行绿底、删除行红底划线、when/emit 变更
  行内 `旧(划线)→ 新`;顺序变化 → 序号旁 `↑↓` 微标(first-true-wins 下顺序即逻辑,必须可见)。
- **退化**:before 不可得 → 快照 + 注记「整体替换,无旧版对比」;⚠️ name/description **不在** edit
  参数(census 明示,描述里的 set_meta 是谎)——卡绝不渲元数据变更。
- **交互**:「对比 vN−1」跳实体版本页。
- **新原语**:复用 BranchRuleList(+diff 态)。
- **Wow**:决策梯的重排一目了然——哪级台阶换了、哪级抽掉了、哪级挪了位。

### `create_approval` — 正在创建审批 → 已创建审批
- **收起行**:审批形 icon · chip=name · 回执 `v1`。
- **活期**(args-partial):template(markdown)在 `ToolLiveWindow` 里**以渲染态流出**;
  allowReason/timeout/timeoutBehavior 键闭合 → 规则 chips 亮。
- **落定体**:**`ApprovalFormPreview`——审批人未来看到的那张卡**:渲染 markdown(`{{ input.x }}`
  占位**预处理归一为内联码 span**——复用现成 inline code chip 视觉 + violet 前景,零新引擎;
  AnMarkdown 是 gpt_markdown 门面、自定义内联 widget 扩展点未经勘探,验证可行后才升级为真 chip
  内联——视觉降半档但占位语义不丢)· 底部 mock 决策行(✓ 批准 / ✗ 拒绝 双钮 disabled 预览;
  allowReason → 备注输入框影子)· 规则条:timeout badge(`30d`)+ 超时行为三色箭头(`超时 → reject`
  danger / `approve` ok / `fail` warn)· inputs 签名行。结果条 RefPill(apf_id) · v1。
- **退化**:`APPROVAL_INVALID_TEMPLATE` → details.reason(真 cel-go 因:`{{ payload.x }}` 即拒)展开;
  `APPROVAL_INVALID_TIMEOUT` 四种物理违例逐条人话(含 "0s 永不触发=坑" 这种);timeout 空 →
  规则条显「永不超时」(诚实,非缺省隐藏)。
- **交互**:RefPill 深链。
- **新原语**:`ApprovalFormPreview`(feature 件:渲染 template + 占位 chip + mock 决策行 + 规则条)。
- **Wow**:你直接看到审批人将来看到的整张卡——连按钮都替你摆好了。

### `edit_approval` — 正在更新审批 → 已更新审批
- **收起行**:chip=approvalId · 回执 `vN`。
- **活期**:同 create(新表流出)。
- **落定 / morph**:⚠️ **省略字段归零值**(census:allowReason/timeout 省略即 false/"")——卡必须按
  **全新快照**渲整张表(FormPreview 全量),规则 chips 全量重列,**绝不渲「未变」**;before 可得 →
  template 源 AnVersionDiff(markdown,过族级 diff 尺寸门)切换视图 + 规则行 before/after 双列
  (`timeout: 2h → 30d` AnDeltaChip)。
- **退化**:before 不可得 → 快照 + 「整体替换快照」注记;错误族同 create + `APPROVAL_VERSION_CONFLICT`。
- **交互**:「渲染预览 / 源码对比」双 tab(AnTabs flow)。
- **新原语**:复用 FormPreview + AnDeltaChip。
- **Wow**:快照语义被 UI 忠实执行——你看到的就是现在生效的整张表,一个隐式归零都藏不住。

### `create_document` — 正在创建文档 → 已创建文档
- **收起行**:文档形 icon · chip=name · 回执 = 结果句解析出的 path 尾段(模板
  `Created document "<name>" (id=…, path=…).` 正则提取;不匹配 → 无回执)。
- **活期**(args-partial):**稿子流出**——ToolLiveWindow + AnMarkdown 渲染 content 生长
  (排版态:标题降档、围栏码活块,不是 markdown 源码瀑布)。
- **落定体**:文档预览(AnMarkdown + AnFadeCollapse 400;**族级落定期截断**:只喂首 N KB / 首 M 个
  block,超限注记「已截断 · 共 X KB」+ 「在 documents 海洋查看全文」逃生口——content 线缆上限
  1MB,绝不一次性排版)· 位置行(path mono + parent)·
  **自动改名 note 必显**:结果句含 `auto-renamed` → amber 注记「请求名被占,已自动改名为 "X 2"」
  (create 撞名不报错是后端语义,卡必须替用户看见)。结果条 RefPill(doc_id)。
- **退化**:**软失败句检测**(document 族 err=nil 但句为失败):句首非 `Created document` → amber 卡 +
  原句全文展示(parent 不存在 / content 超 1MB 拒收 / 名字非法),不给成功回执;content 空 → 仅位置行。
- **交互**:回执/RefPill → documents 海洋该文档。
- **新原语**:复用 ToolLiveWindow;新增结果句解析器(`docSentenceReceipt`,纯函数)。
- **Wow**:一页排好版的稿子在窗里流出来;连「悄悄改了名」这种小事卡都替你记着。

### `edit_document` — 正在更新文档 → 已更新文档
- **收起行**:chip=id(文档缓存名优先)· 回执 = `Updated document "<name>" (…)` 解析的 path 尾段。
- **活期**:content 流出(同 create);纯改名/tags(无 content)→ 无活窗,薄卡。
- **落定 / morph**:首行**触碰字段 chips**(name/description/content/tags,args 键出现即列——字段级
  patch 语义);content → 新文渲染(**族级落定期截断**:首 N KB + 截断注记 + 「在 documents 海洋
  查看全文」逃生口)+ 注记「全文替换(无 diff 语义)」(census 原话);documents 缓存有旧文 →
  「源码对比」可选 tab(AnVersionDiff markdown,**过族级 diff 尺寸门**——MB 级对比不进 transcript,
  注记引至实体面板);name 变更 → 注记「后代 path 级联更新」。
- **退化**:软失败矩阵(句首非 `Updated document` → amber 卡 + 原句):not found / **兄弟重名
  (edit 不自动加后缀——与 create 不对称,卡文案点破)** / 超 1MB / `nothing to update…`(四字段全缺)。
- **交互**:RefPill → documents 海洋。
- **新原语**:复用全套。
- **Wow**:软失败不伪装成功——琥珀卡替你读出那行英文,并点破 create/edit 的不对称脾气。

### `create_skill` — 正在创建技能 → 已创建技能
- **收起行**:技能形 icon · chip=name(slug)· 回执 = `{created:"name"}` 的 name。
- **活期**(args-partial):body(markdown 指令)稿子流出;meta chips 随键闭合亮:slug 标题 ·
  context badge(inline/fork;fork → agent chip)· arguments 标签 · **allowedTools 药丸用 warn tone**
  (预授权语义:激活后这些工具**免危险确认**——这是权限让渡,必须一眼可见)· disableModelInvocation →
  「仅用户可触」badge。
- **落定体**:技能卡——slug 标题 + description · frontmatter chips 区(上述全量)· body 渲染
  (AnMarkdown + AnFadeCollapse,过族级落定期截断——body 上限 32KB,超档同样物理截喂 + 逃生口)。
  结果条 RefPill(kind=skill, id=name)。
- **退化**:`SKILL_INVALID_FRONTMATTER`(body 自带 frontmatter 拒收)→ details.reason 长解释展开;
  `SKILL_NAME_CONFLICT` → 错误卡引导 edit_skill;`SKILL_BODY_TOO_LARGE`(32KB)诚实报量。
- **交互**:RefPill 深链;allowedTools 药丸 hover 提示预授权语义。
- **新原语**:复用 ToolLiveWindow + chips。
- **Wow**:allowedTools 用警示色——一眼看清这个技能将替谁「免确认放行」。

### `edit_skill` — 正在更新技能 → 已更新技能
- **收起行**:chip=name · 回执 = `{updated:"name"}`。
- **活期**:同 create(整份新 SKILL.md 流出)。
- **落定 / morph**:同 create 布局(整体替换 → 全新快照);卡顶诚实小字注记
  **「整份覆盖 · 无版本可回退」**(inkFaint——别的实体都有 revert,skill 没有,这行小字是本族最诚实
  的一笔);机会性 diff:本对话早前有 get_skill 同名结果(工具卡缓存)→ 「对比修改前」可选 tab
  (机会性、不承诺,取不到不显示)。
- **退化**:`SKILL_NOT_FOUND` → 引导 create_skill;frontmatter/体积错误同 create。
- **交互**:同 create。
- **新原语**:复用。
- **Wow**:覆盖前最后一眼——无版本的实体,卡用小字提醒你这次写下去就没有回头路。

### `create_trigger` — 正在创建触发器 → 已创建触发器
- **收起行**:触发器形 icon · chip=name · 回执 = kind badge + **「未监听」**(create 恒
  `refCount:0, listening:false`,不走 attachRuntime——绝不显 lastFiredAt/nextFireAt,census 明示)。
- **活期**(args-partial,`partialJsonEvents` 键闭合事件):kind 键闭合 → kind badge 亮
  (cron/webhook/fsnotify/sensor 四形);config KV 随键闭合逐行亮(AnKv dense)。
- **落定体(`TriggerConfigCard` 四张脸)**:
  - **cron**:expression codeReading(mono 13)· w400 加重 · 主色(双轨字阶无 display 档,不开
    新字号;视觉重量由人话行承担)+ `cronDescribe` 人话行(内容 15,纯函数子集:「每天 09:00」;
    不识 → 只显表达式,诚实回落)+ 注记「创建不启动监听——active workflow 引用才开始听」;
  - **webhook**:**完整可用 URL** `POST /api/v1/webhooks/{trg_id}/{path}`(id 从结果 JSON 拿,拼好)
    `AnCopyChip` 一键复制 · secret/signatureAlgo chips(值永不显,🔒 有/无 + 算法名)· 幂等注记
    (同 body 同分钟去重);
  - **fsnotify**:path mono + events chips + pattern glob;
  - **sensor**:target RefPill(function/handler/mcp)· method · intervalSec badge(≥5)· condition
    CEL mono · output CEL · 注记「电平触发:条件持续成立每 interval 都 fire」。
  结果条 RefPill(trg_id)(结果是 Trigger 全形 JSON,id 直取)。
- **退化**:`TRIGGER_INVALID_CEL` → **details{field, cel, reason}** 展开定位(condition|output);
  `TRIGGER_SENSOR_TARGET_NOT_FOUND` → details 三键 + 死引用红 RefPill;`TRIGGER_INVALID_CRON`
  (@every/秒级不支持)原因直显。
- **交互**:webhook URL 复制;target RefPill 深链。
- **新原语**:`TriggerConfigCard`(四 kind 脸)、`AnCopyChip`(mono 值+copy+已复制 tick,补 palette
  缺口 #12)、`cronDescribe`(可选纯函数)。
- **Wow**:webhook 建完,可复制的完整 URL 已经躺在卡里——零脑内拼接。

### `edit_trigger` — 正在更新触发器 → 已更新触发器
- **收起行**:chip=triggerId(缓存名)· 回执 = kind badge;**listening:true → warn 徽「热更新已生效」**
  (census:live trigger 的 config 改动立即重注册 listener——这是本工具最重的语义,回执级呈现)。
- **活期**:config KV 逐行亮(同 create)。
- **落定 / morph(混合补丁的三种方言)**:
  - name/description = 指针 patch → AnDeltaChip(出现即列;旧值取实体缓存,无则只显新值);
  - **config = 整体替换**(census 原话 "Full replacement config")→ 新 config KV 全量渲 + 注记
    「config 整体替换」;实体缓存有旧 config → **KV 行级 diff**(键对齐:新键绿 / 消失键红划线 /
    变更键值内 `旧 → 新`);
  - outputs(仅 sensor)→ 签名行(非 sensor 被 canonical 盖章,卡不渲作者所填)。
- **结果条**(edit 走 attachRuntime,返回全形):RefPill(trg_id) · refCount(「N 个 workflow 在听」)·
  listening badge · cron → **nextFireAt 人话**(「下次触发 明早 09:00」——编辑活着的定时器,
  卡直接告诉你新节拍何时敲响)。
- **退化**:kind 不可变(schema 无此参数,不会出现;描述层「换 kind=删了重建」不进卡);
  `TRIGGER_NAME_DUPLICATE`/`TRIGGER_NOT_FOUND` 错误卡;config 校验族同 create。
- **交互**:RefPill 深链;URL 重拼(path 变了)照 create 给 AnCopyChip。
- **新原语**:复用 TriggerConfigCard(+diff 态)+ AnDeltaChip。
- **Wow**:「热更新已生效 · 下次触发 09:00」——你刚改了一台活着的钟,卡告诉你它下一声什么时候敲。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| `partialJsonEvents` | core 纯 Dart | path-aware 流中增量 JSON 事件解析器:任意路径上「值闭合」即发事件——数组元素(ops ticker / branch 梯 / method chips / 图计数)、顶层与嵌套键(trigger config KV / agent 装备键 / skill·approval 规则 chips)、boolean/number/object 标量全覆盖(平衡括号+字符串态机,容错畸形);无头单测五电池 |
| `AnMiniGraph` | core/ui | 只读迷你图画布(framed、无 IV/编辑/run 覆层),复用 layoutGraph + 边 painter(graph.md 路 C,~200-300 行,gallery-first) |
| `GraphRevealState` + 揭示面 | core/graph + 画布 | settle-then-replay:几何冻结后按 rank staggered 节点浮现 + 边 draw-in(PathMetric extractPath);reduced 直落终态(~300-450 行,graph.md §5 已勘) |
| `GraphMorphState` | core/graph | 揭示面的 delta 变体:added 绿晕 / updated 脉冲 / deleted 名册(画布依赖 settle 后 after 图取数;before 也可得时完整 morph + AnimatedPositioned 位移;取数皆失败退纯 delta 图例) |
| `ToolLiveWindow` | feature | 有界底对齐渲染活窗(定高 + 底对齐 clip + 顶部 AnEdgeFade):prose payload 的「稿子流出」载体(agent/doc/skill/approval 共用);契约:只喂尾窗切片(末 4–6KB,按字节界)进 AnMarkdown、切片整体每帧重渲(无逐块 memo / 无块切分器 / 无围栏态机,未闭合围栏靠 AnMarkdown 流式容忍),settle 换完整渲染(受族级落定期截断纪律) |
| `EnvFixTimeline` | feature | envFixAttempts 的 ✓/✗ attempt 行 + deps chips + error(自愈过程的落定陈列) |
| `BranchRuleList` | feature | control 决策梯:有序 port/when/emit 行 + catch-all 钉底 + 错误行红框定位 + diff 态 |
| `ApprovalFormPreview` | feature | 渲染 template + `{{input.*}}` 占位(预处理归一为内联码 span + violet 前景,零引擎扩展;真 chip 内联待验证 gpt_markdown 内联扩展点后升级)+ mock 决策行 + timeout 规则条 |
| `TriggerConfigCard` | feature | trigger 四 kind 配置脸(cron/webhook/fsnotify/sensor)+ config diff 态 |
| `AnCopyChip` | core/ui | mono 值 + 复制 affordance + 已复制 tick(补 palette 缺口 #12;webhook URL / id 通用) |
| `AnDeltaChip` | core/ui | `key: old → new` 变更药丸(merge/指针 patch 类 edit 的 morph 通货) |
| `BuildResultBar` 升级 | feature | 现 `_BuildResultBar` 公共化:AnRefPill 深链 + 双键名兜(id/agentId)+ per-kind 扩展槽(env/lifecycle/listening/runtime) |
| `cronDescribe` | core 纯函数(可选) | 5 段 cron 人话化子集;不识回落原表达式(诚实) |
| `docSentenceReceipt` | feature 纯函数 | document 族字符串结果句解析(Created/Updated/auto-renamed/软失败判别) |

## 族内建造顺序建议

1. **地基**:`partialJsonEvents`(path-aware 纯模型+五电池测)+ `BuildResultBar` 公共化(RefPill
   深链、双键兜、env 三色)——全 18 工具即刻受益,零视觉风险。
2. **fn/hd 完全体**(旗舰之一、最便宜):活代码窗接 partialJsonEvents(set_code/add_method 精确提取)+
   EnvFixTimeline + edit_handler 三径诚实 + `AnDeltaChip`;before 懒取 diff 视版本 REST 缝就绪度分级。
3. **workflow 旗舰**:`AnMiniGraph`(gallery specimen 先行)→ **settle 后 after 图取数缝**(实体
   缓存 / GET workflow 的 graphParsed——create/edit 共用权威图源,ops 折算不作图源)→
   `GraphRevealState` 生长回放 → create_workflow 幕一 op ticker → `GraphMorphState` →
   edit_workflow(基本形先落,含纯 delta 降级;完整 morph 等 before 数据缝)。本步量级最大
   (~600-800 行),独立成 WRK 切片。
4. **control + approval**:`BranchRuleList` + `ApprovalFormPreview`(共用 partialJsonEvents 与
   ToolLiveWindow;错误定位是亮点,成本低)。
5. **document + skill**:`ToolLiveWindow` 稿子流 + `docSentenceReceipt` 软失败矩阵 + skill 警示药丸。
6. **trigger 收尾**:`TriggerConfigCard` + `AnCopyChip` + `cronDescribe`(可选)+ edit 热更新徽。
7. **morph 深化横切**:before 懒取统一缝(versions REST / 实体缓存,**内建族级 diff 尺寸门**:
   任一侧 >~50KB 或 >2000 行 → 无 diff tab + 「内容过大,请在实体面板对比版本」注记)→
   fn/agent/doc/control/approval 的 diff 完整形 + edit_workflow 完整 morph 一次收口。

## 风险

- **取数缝(before/after)**:所有 edit 的完整 morph 依赖 vN−1 内容(versions REST / 实体缓存);
  create_workflow / edit_workflow 的**落定画布都依赖 settle 后的 after 图取数**(GET workflow /
  实体缓存——权威图源,ops 折算不作图源)。各卡已设计诚实降级(新快照 / 「节点 ×N · 边 ×M」图例 +
  注记),但完整体验要先确认前端 versions 端点/缓存现状。
- **流中畸形 JSON**:后端 jsonrepair 在 ParseOps 前救 LLM 畸形;前端 partialJsonEvents 面对同样的
  畸形流须自容错(注入电池必测:未闭合字符串、转义、嵌套、截断在任意字节、任意路径上的值闭合误判)。
  画布图源已改走 after 取数缝——jsonrepair 分叉只影响 ticker / 回放分镜(可降级),不再影响落定
  画布真相。
- **图回放量级**:AnMiniGraph + 揭示/morph 面合计 ~600-800 行,是本族最大单体;graph.md 判定原语
  全部有同文件活用例、风险低,但必须 gallery-first + 逐帧截图验收。
- **messages 流 args delta 粒度**:活窗依赖 tool_call args 逐 delta 到达(V3c 活代码窗已验证);
  op ticker 的「逐个亮起」体验受 delta 批次大小影响,大批次时退化为成组亮起(可接受,无需修后端)。


---

# F05 lifecycle 族 — 完美态设计(26 工具)

> revert×6 · delete×9 · workflow 生杀四将(stage/activate/deactivate/kill)· restart_handler ·
> activate_skill · move_document · update_meta×3 · update_handler_config。
> 族魂:**极薄卡**。一行陈述 + 不可抵赖的凭据。克制即完美——本族没有一个工具配得上大窗秀,
> 它们的"秀"全部浓缩在**回执的诚实度**与**一笔轻 morph** 上。

---

## 族级统一文法

**1. 全族无 liveBody。** args 都是几十字节的 id/version/键值,执行亚秒级——活期就是底盘原样:
流光动词 + partial 目标 chip(`argStringPartial` 容忍缺键),>3s 才读秒。绝不为薄卡造活窗。

**2. 回执 = 台账凭据。** 每个工具的回执从输出的**精确字段/模板**解析:版本号、依赖数、生命周期态、
运行态、新路径、被改字段名。解析不匹配 → 无回执、原始输出进通用窗(诚实铁律;**document 系例外**:
输出走 §4 **三值分类**——命中成功模板 / 命中已知软失败模板 / 两者皆不匹配,各有归宿,绝不把
"模板不识别"猜成成功**或失败**)。全族回执解析器集中进 `tool_receipts.dart`(纯函数,可单测)。

**3. 回执三色扩展(底盘小修)。** 现 `ToolReceipt = (text, danger:bool)`,本族需要**琥珀**
(draining / 软删含后代 / 内存态抹除):扩展为 `tone ∈ {none, warn, danger}`,danger 语义不变
(危险色回执仍自动展开一次)。一次改动,全族受益。

**4. "工具绿但物已坏"重分类缝(底盘小修)。** `restart_handler` 的失败折在结果里
(`{id, runtimeState, error}`,tool_result 状态是成功)——底盘按相位渲染会撒谎。新增
`ToolCardSpec.classifyResult(state) → {ok, failed, unrecognized}` 三值谓词钩子:`failed` 按
failed 相位处理(失败声调 + 红回执 + 自动展开);`unrecognized` 按**中性"结果未识别"态**处理
(中性声调收起行:动词退中性词形 + 灰尾注"结果未识别",无回执、不自动展开,原文进通用窗——
不用过去时成功动词,也不用失败声调)。本族**三处**用:
- **restart_handler**:二值——`error` 键存在 → failed,否则 ok(JSON 键判据精确,无 unrecognized)。
- **move_document / delete_document**(document 系软失败是 err=nil 的英文指引串)**三值**:
  ①命中成功模板 → ok;②命中**已知软失败模板**(census 06 全量:not found / 新 parent 不存在 /
  环 / parentId 键缺席)→ failed(失败声调 + 自动展开 + 软失败原文红 mono 首行,文案自带指引
  原样示人;绝不渲过去时成功动词把失败真相埋进收拢卡);③**两者皆不匹配 → unrecognized**——
  **mismatch ≠ 失败**:后端英文成功模板一字之改不得把每一次成功渲成响亮假失败,"回执绝不猜"
  对猜失败同样成立。
配套:document 系成功/软失败模板集加 **testend 模板锁死回归测**(后端措辞一动门禁即红);更优解
走迭代铁律②把 document 系输出迁 JSON(与其余 delete 对齐),迁完 unrecognized 分支自然收窄。
将来 F4 的 runtimeWarning 类半成功也能复用本缝。

**5. 危险梯度(确认凭据一行)。** LLM 自报 dangerous → 底盘 awaitingConfirm 相位(警示色行 +
意图行常显),本族不加新确认 UI(V6 的事)。族内预期梯度:
- **红核**:delete×7(function/handler/agent/workflow/control/approval/skill——均"not reversible")
  + kill_workflow(杀在途);
- **琥珀**:delete_document(软删可恢复)、delete_trigger(软删但断信号)、restart_handler /
  revert_handler / update_handler_config(重启实例、内存态抹除)、deactivate 的 draining 半态;
- **中性**:revert 其余五员、stage/activate(有 NOT_RUNNABLE 门禁)、move、update_meta。

**6. 墓碑 chip 规则。** delete 卡的目标 chip **刻意不做 AnRefPill**——物已死,不给可点的跳转
(死链接是最差体验);纯 mono id/name。非删除 **17** 员中,**除 activate_skill(skill 以 name 为
身份、无实体 id,不适用)外的 16 员**展开体里给一行活的 `AnRefPill` 跳实体面板;kind **按工具
静态指定**(每工具的目标实体类型编译期已知:function/handler/agent/workflow/control/approval/
document),不从 id 前缀猜。**唯一前缀派生豁免**:§7 依赖块的**字符串形** dependents
(delete_agent 尾巴只有裸 id,无处静态指定)——仅允许查 **S15 `database.md` 已登记前缀的白名单表**
(wf_/ag_/fn_/hd_/ctl_/apf_/trg_ 等,以登记表为准、编译期写死);未知前缀落 AnRefPill 开放集
"?" 兜底且**不可点**(kind 派生错会让 deep link 跳错面板——错导航比不可点更糟)。JSON 形
dependents 自带 `{kind,id}`,不适用派生。

**7. 依赖块(族共享件)`ToolDependentsBlock`。** delete 九员中**八员**(delete_document 除外,
它无 dependents 机制)的输出可能带 `dependents:[{kind,id}] + dependentCount + note`
(delete_agent 是字符串尾巴的 `[id id …]`,kind 经 §6 白名单表派生、未知前缀 "?" 不可点)。
统一渲染:一行"N 处引用受影响"(danger 色)+ `AnRefPill` Wrap(可点跳修)+ note 灰字。
**有界纪律(宪法 §8)**:线缆对 dependents 数组无上限——pill Wrap 封顶 **24 枚 + `+N` 溢出徽标**;
首行计数仍报全量"N 处引用受影响"(诚实计数不截);delete_agent 字符串解析同规则。海量电池必测。
有 dependents → 回执升 danger → 底盘自动展开一次:**删除即审计,损伤当场看见**。

**8. 问题清单块(族共享件)`ToolProblemsBlock`。** stage/activate 的 `WORKFLOW_NOT_RUNNABLE`
错误 details 带 `problems:[…]`(违例清单)。渲染成红色逐条 checklist(mono 短句列),
warnings(若有)黄条。**有界纪律(宪法 §8,与 §7 同规格)**:problems 数随节点/边数线性、
线缆无上限——逐条渲染封顶 **20 条 + `+N 条违例` 溢出行**(首行计数仍报全量,诚实计数不截);
warnings 同规格封顶。message-only 退化态(见下)整段红 mono 进机器窗,同守有界视口。
海量电池必测。将来 capability_check_workflow 卡直接复用。
**建造前置(线缆验证,未验证前本块不得动工)**:census 只确立 Go 侧 error struct 带
details.problems;**失败 tool_result 块在 messages 流上是否序列化 code+details 未经证实**
(S20 只保证 LLM 出口读 Message 文本)。先读 loop 侧序列化代码 / 抓一帧实测:若线上只有
message 散文 → 要么走迭代铁律②让后端把 details 序列化进块(同提交同步
`references/backend/events.md`),要么本块定义 **message-only 退化态**(整段红 mono 进机器窗,
不装结构化清单)。

**9. 动词对 i18n 一览**(全部新增 `chat.tool.*` 键,en/zh 双语;`<kind>` 复用 F4 的类名词):
| 工具组 | live | settled |
|---|---|---|
| revert×6 | 正在回退<kind> | 已回退<kind> |
| delete×9 | 正在删除<kind> | 已删除<kind> |
| stage | 正在设为待命 | 已待命 |
| activate_workflow | 正在上线 | 已上线 |
| deactivate_workflow | 正在下线 | 已停监听 |
| kill_workflow | 正在急停 | 已急停 |
| restart_handler | 正在重启 | 已重启(失败经 §4 缝改失败声调) |
| activate_skill | 正在激活技能 | 已激活技能 |
| move_document | 正在移动文档 | 已移动文档 |
| update_meta×3 | 正在更新信息(纯改名特化:正在改名——§12,args 完整后才切,argsStreaming 期恒通用对) | 已更新信息 / 已改名 |
| update_handler_config | 正在配置 | 已配置 |

**10. 图标补表。** `AnIcons.toolIcon` 关键字推断表(palette §6)只有
function/handler/agent/workflow|trigger 分支,**没有 control/approval**——`revert_control` /
`delete_control` / `revert_approval` / `delete_approval` 四员与 `*_skill` 两员一样落兜底扳手。
精确表同批补齐:`activate_skill` / `delete_skill` → skill 字形、`*_control` → control 字形、
`*_approval` → approval 字形(均与 AnRefPill 的 kind 字形同源;或在 AnIcons 关键字表加
`control|approval` → 实体形分支,二选一)。其余 20 员关键字命中正确
(revert_function 含 "function" → 实体形,move_document 含 "doc" → 文档形)。

**11. revert 的一笔轻 morph:`AnVersionRewindChip`。** 线缆只给目标版本
(`{id, activeVersionId, version}`),**旧 active 版本号不可知**——settle 后 entities 缓存已是
回退后状态,任何"vN→vM"双端徽标都必然是猜(违诚实铁律),故 morph 是单端**倒带**:mono chip
`⤺ v3`,落定瞬间 ⤺ 弧线逆时针一次性画出 + chip 从右向左滑入(指针回拨的体感),reduced motion
→ 静态。P1 先用纯文本回执 `⤺ v3`(零改动);chip 版随底盘加 `receiptWidget` 可选槽后上(P2)。

**12. 动词缝扩签名(底盘小修)。** 现底盘缝签名是 `ToolCardSpec.verb(t,{live})`(palette §0),
不接 state/args——update_meta 三胞胎"仅 name 键 → 改名对"的动态动词做不出来。扩为
`verb(t,{live,state})`(~5 行);动词特化**只准在 args 完整后(running 相位起)按 args 键集
生效**,argsStreaming 期恒用通用对(键渐进流入,先 name 后 tags 会让动词"正在改名↔正在更新信息"
来回闪变)。与 §3 tone 扩展、§4 classifyResult 并列进 P0.5 底盘批。

---

## 一、revert 六联(指针回拨)

### `revert_function` — 正在回退函数 → 已回退函数
- **收起行**:函数形 icon · 动词 · chip=`args.functionId`(mono)· 回执=`⤺ v{version}`
  (解析输出 `{id, activeVersionId, version}` 的 `version`;缺→无回执)。
- **活期**:settle-only。args 两键即到,流光动词足矣。
- **落定体**:极薄——一行 `AnRefPill(function, id)` 跳实体 + 灰字注记
  "仅还原代码/输入输出/依赖;名称·描述·标签不随版本"(契约事实,静态 i18n)。
- **morph**:§11 AnVersionRewindChip(P2)。
- **退化态**:`FUNCTION_VERSION_NOT_FOUND` 等 → 底盘失败相(红 + 错误码 + message,自动展开)。
- **交互**:ref pill 跳 entities 海洋该函数面板(版本史就在那里,卡不重复陈列)。
- **新原语**:AnVersionRewindChip(§11);回执解析器 `revertReceipt`。
- **Wow**:回执就一个倒带徽标——指针回拨这个抽象操作,被一笔画看见了。
- **可行性**:输出 <100B、恒 JSON;version 恒 int。零风险。

### `revert_handler` — 正在回退处理器 → 已回退处理器
- 同上,chip=`args.handlerId`;回执 `⤺ v{version}`。
- **差异(琥珀注记)**:回退**触发常驻实例重启、内存态被抹**——落定体注记行升琥珀:
  "已触发重启以运行 v{N};内存态已清空——运行状态见 handler 面板"(契约行为,静态文案)。
  **措辞只到线缆可证处**:输出 `{id, activeVersionId, version}` 不带 runtimeState,且
  edit_handler 先例表明重启失败不冒工具错误——绝不断言"已重启成功/已生效",ref pill 即核实
  入口;后续若走迭代铁律②给后端补 runtimeState 输出(与 restart_handler 对齐),注记才可
  升级为状态词。回执 tone=warn。
- 错误:`HANDLER_VERSION_NOT_FOUND` / `HANDLER_VERSION_POSITIVE`。

### `revert_agent` — 正在回退智能体 → 已回退智能体
- 同 revert_function,chip=`args.agentId`。
- **差异(线缆)**:输出键名不同——`{agentId, versionId, version}`(**无 id / activeVersionId**)。
  解析器按工具分键,绝不共用一个 key 猜。错误:`AGENT_REVERT_ARGS_REQUIRED` / `AGENT_VERSION_NOT_FOUND`。

### `revert_workflow` — 正在回退工作流 → 已回退工作流
- 同 revert_function,chip=`args.workflowId`;输出 `{id, activeVersionId, version}`。
- 落定体注记:"回退不改监听状态;上线中的 workflow 立即按旧图跑"——这句**不是**线缆事实,
  砍掉:只留 ref pill + 通用版本注记。错误:`WORKFLOW_VERSION_POSITIVE` / `WORKFLOW_VERSION_NOT_FOUND`。

### `revert_control` — 正在回退路由 → 已回退路由
- 同 revert_function,chip=`args.controlId`;输出 `{id, activeVersionId, version}`。
- 错误:`CONTROL_VERSION_POSITIVE` / `CONTROL_VERSION_NOT_FOUND`。

### `revert_approval` — 正在回退审批表 → 已回退审批表
- 同 revert_function,chip=`args.approvalId`;输出 `{id, activeVersionId, version}`。
- 错误:`APPROVAL_VERSION_POSITIVE` / `APPROVAL_VERSION_NOT_FOUND`。

---

## 二、delete 九员(红核 + 墓碑 + 审计)

### `delete_function` — 正在删除函数 → 已删除函数
- **收起行**:icon · 动词 · chip=`args.functionId`(**墓碑:纯 mono 不可点**,§6)· 回执:
  无依赖 → `已删除`;有依赖 → `已删除 · N 处引用受影响`(danger → 自动展开)。
- **活期**:settle-only;dangerous 自报时先经 awaitingConfirm 警示行(确认凭据=动词+目标一行)。
- **落定体**:意图行(LLM summary,危险族常显)+ `ToolDependentsBlock`(§7)。无依赖且无 summary
  → bodyless(回执即卡)。
- **退化态**:输出解析失败 → 无回执 + 原文进通用窗;`FUNCTION_NOT_FOUND` → 底盘失败相。
- **交互**:dependents pill 可点跳去修引用;墓碑 chip 不可点。
- **新原语**:`ToolDependentsBlock`;解析器 `deleteReceipt`(JSON 形)。
- **Wow**:删除不是一句"好了"——是一张当场摊开的损伤清单,每个受影响实体一键跳修。
- **可行性**:`{id, deleted:true, dependents?, dependentCount?, note?}` 恒 JSON,依赖删前快照、
  advisory(读失败键缺席即无块,不猜)。

### `delete_handler` — 正在删除处理器 → 已删除处理器
- 同上,chip=`args.handlerId`;输出同形。落定体注记多一行灰字:"常驻实例已停"(契约行为)。

### `delete_agent` — 正在删除智能体 → 已删除智能体
- 同 delete_function,chip=`args.agentId`。
- **差异(线缆,重要)**:输出是**人话字符串非 JSON**:`Deleted agent "ag_xxx".` + 可选尾巴
  `… Referencing entities: [wf_1 ag_2 …].`。解析器 `deleteAgentReceipt`:主句正则提 id 出回执;
  尾巴正则提 `[…]` 内 id 列表(kind 经 §6 的 S15 已登记前缀白名单表派生;未知前缀落 "?"
  兜底 pill、不可点)喂 ToolDependentsBlock。**任一段不匹配 → 该段
  放弃**(主句失败=无回执整卡通用窗;只尾巴失败=有回执无依赖块,原文进展开窗保底)。
- **可行性风险**:模板是后端英文散文,后端措辞一动即哑火——哑火安全(退化为原文窗),但建议
  后续后端对齐成 JSON 形(与 JSON 形七员一致;delete_document 同为模板形,宜与 §4 的
  document 系迁移同批);前端绝不因此猜。

### `delete_workflow` — 正在删除工作流 → 已删除工作流
- 同 delete_function,chip=`args.workflowId`;输出 `{id, deleted:true, …}` JSON 形。

### `delete_control` — 正在删除路由 → 已删除路由
- 同 delete_function,chip=`args.controlId`。落定体注记:"引用它的 workflow 将 capability check
  失败"已由 note 字段承载,不另造文案。

### `delete_approval` — 正在删除审批表 → 已删除审批表
- 同 delete_function,chip=`args.approvalId`。

### `delete_document` — 正在删除文档 → 已删除文档
- chip=`args.id`(墓碑)。**差异:软删可恢复 → 琥珀非红**(回执 tone=warn 不 danger,不自动展开)。
- 回执:解析字符串模板 `Deleted document <id> (no descendants).` → `已删除`;
  `…along with N descendant(s).` → `已删除 · 含 N 个后代`(warn)。
- 落定体:灰注记"软删除,可恢复"。无 dependents 机制(document 系没有)。
- 退化态(**§4 三值**):命中成功模板 → 成功;命中已知软失败模板 → failed 相(失败声调 +
  自动展开 + 软失败原文红 mono 首行,文案自带指引原样示人,**绝不渲"已删除文档"成功动词**;
  例外:not found("already deleted?")模板 → 中性声调、不自动展开——终态一致非事故,但同样
  无成功回执);**两者皆不匹配 → unrecognized 中性态**(动词退中性词形 + "结果未识别" 灰尾注,
  原文进通用窗、无回执、不自动展开——模板漂移不得渲假失败)。
- 可行性:同 delete_agent 的模板脆性;哑火安全。

### `delete_skill` — 正在删除技能 → 已删除技能
- chip=`args.name`(slug,墓碑)。**红核**(硬删目录,"Cannot be undone")。
- 回执:JSON `{deleted:"<name>", dependents?, dependentCount?, note?}` → `已删除` /
  `已删除 · N 处引用受影响`(danger)。dependents 的 relation id 即 skill name。
- 落定体:ToolDependentsBlock——受影响的多半是 equip 它的 agent,pill 跳修价值最高。
- 图标:精确表补 skill 字形(§10)。

### `delete_trigger` — 正在删除触发器 → 已删除触发器
- chip=`args.triggerId`(墓碑)。回执:JSON `{deleted:true, triggerId, dependents?, …}` →
  同 delete_function 文法;tone:有依赖 danger("收不到信号"此时才为真,由 ToolDependentsBlock
  落实),无依赖 **none**(无 dependents = 没有任何 workflow 引用它,"断信号"无从谈起;软删,
  与 delete_document 无后代同级)。落定体注记:**"监听已解除"**(条件安全措辞——listener 仅在
  有 active workflow 引用时才热,refCount=0 时"热 listener 已停"为假;不断言曾经热)。

---

## 三、workflow 生杀四将

### `stage_workflow` — 正在设为待命 → 已待命
- **收起行**:workflow icon · 动词 · chip=`args.workflowId` · 回执=`候下一发真实触发`
  (解析 `{staged:true, workflowId}`;staged≠true → 无回执)。
- **活期**:settle-only。
- **落定体**:ref pill + 一行灰注记"真实触发到来跑一次后自动解除"(契约语义)。
- **退化态(本工具的重头)**:`WORKFLOW_NOT_RUNNABLE` → 失败相 + `ToolProblemsBlock`
  (details.problems 红清单);`WORKFLOW_ALREADY_ACTIVE` → 失败相,message 自明("先 deactivate");
  `WORKFLOW_NO_TRIGGER_ENTRY` → 失败相 message。
- **交互**:ref pill 跳工作流面板看布防状态。
- **新原语**:`ToolProblemsBlock`(§8)。
- **Wow**:坏图想上膛,卡当场把违例逐条摊开——失败不是一句错误码,是整改清单。
- **可行性**:Go 侧 details.problems 是字符串数组;但**失败 tool_result 块是否携带结构化
  details 未经证实**(§8 建造前置)——验证前 ToolProblemsBlock 不动工,message-only 时
  按整段红 mono 退化态兜底。

### `activate_workflow` — 正在上线 → 已上线
- 同 stage 骨架。回执:解析 `{workflowId, lifecycleState:"active", active:true}` →
  `监听中`(ok 色语义靠文案,回执 tone=none;lifecycleState≠"active" → 无回执)。
- 落定体:ref pill + `AnBadge(label:'active', tone:ok, dot:AnStatus.done)` 一枚状态徽章——
  上线这件事的"落定感"。退化态:同 stage 的 NOT_RUNNABLE / NO_TRIGGER_ENTRY 三连。
- Wow:上线即绿章,坏图连门都进不来(与 stage 共享问题清单)。

### `deactivate_workflow` — 正在下线 → 已停监听
- 回执双态(诚实半态):`lifecycleState=="inactive"` → `已下线`(none);
  `=="draining"` → `排空中 · 在途运行跑完即停`(**warn,自动不展开**——预期半态非事故)。
- 落定体:ref pill;draining 时注记"要立即中止在途,用 kill_workflow"(契约指引)。
- 可行性:两枚举之外的值 → 无回执(开放集兜底)。

### `kill_workflow` — 正在急停 → 已急停(红核)
- **收起行**:回执=解析 `{workflowId, killed:N}`:N>0 → `杀停 N 个在途运行`(danger →
  自动展开);N==0 → `无在途运行`(none——空结果诚实说)。
- **活期**:dangerous 自报 → awaitingConfirm 警示行先行。
- **落定体**:意图行(危险族常显)+ ref pill + 灰注记"监听已停;被杀 run 状态=cancelled,
  可在 flowruns 里查"。
- **退化态**:`WORKFLOW_NOT_FOUND` → 失败相。
- **Wow**:急停按钮的份量在回执上——"杀停 3 个在途运行"红字,一条命一格,绝不轻描淡写。
- **可行性**:killed 恒 int;零解析风险。

---

## 四、restart_handler — 正在重启 → 已重启

- **收起行**:handler icon · 动词 · chip=`args.handlerId` · 回执=`runtimeState` 词
  (running → `running`(none)/ stopped → warn / crashed → danger)。
- **活期**:settle-only(重启通常 <2s;>3s 底盘读秒)。
- **落定体**:ref pill + 琥珀注记"内存态已清空"(契约行为)。
- **结果内失败(本工具的存在意义)**:输出带 `error` 键 → **§4 `classifyResult`=failed 缝生效**:
  整卡按 failed 相位渲(失败声调 + 自动展开),展开体首行红 mono 显 `error` 原文,
  runtimeState 徽章同显(crashed 红点)。tool_result 明明是"成功"——卡不跟着撒谎。
- **退化态**:输出非 JSON → 无回执通用窗。
- **交互**:ref pill 跳 handler 面板(配置/日志都在那)。
- **新原语**:复用 §4 底盘缝;解析器 `restartReceipt`。
- **Wow**:全系统"工具绿但物已坏"最典型的一张卡,被一个谓词治好——绿色外壳包不住红色事实。
- **可行性**:`{id, runtimeState, error?}` 恒 JSON;error 键存在性即失败判据,零猜测。

---

## 五、activate_skill — 正在激活技能 → 已激活技能

- **收起行**:skill icon(§10 补表)· 动词 · chip=`args.name`(+ 有 arguments 时缀
  ` · N 参`,args 派生)· 回执=`返回 N 行`(**仅计输出字符串行数,不定性**——inline/fork
  线缆不可分辨,"注入"会在 fork 模式下把子 agent 答案说成注入载荷,是猜;空串 → 无回执)。
- **活期**:settle-only(fork 模式可能跑很久 → 底盘读秒天然覆盖)。
- **落定体**:`ToolWindow` 装输出,**capped mono(6000 chars + 诚实截断注记)**——注入的是
  指令载荷,机器窗身份、不借散文;`AnFadeCollapse`(400 收合 + 展开行)只管窗内收合。
  **真逃生口(宪法 §8——展开后仍 6000 封顶,展开 ≠ 逃生口)**:①截断注记本身做成动作行
  **「查看全文」**→ 开全文浮层(完整输出,有界视口内滚动)——fork 的 subagent 长答案不落任何
  实体面板、全产品无处另读,6000 硬截断必须配它才合宪;②窗顶栏**整卡复制**(palette 缺口 #12
  的小原语,顺手补,全族机器窗受益);③inline 模式另附 deep link 跳 skill 面板读原文
  (name 即身份,skill 归 entities 海洋;fork 结果无面板可跳,①即其唯一全文出口)。
  窗上一行灰注记,**条件式措辞**:"其声明的 allowed-tools(如有)在本次运行余下部分免确认"
  (契约副作用两模式都生效、用户该知道;但本卡看不见 skill 是否真有 allowedTools——直陈式
  在无 allowedTools 时是空断言,故留"如有";确认卡承载版留给 V6)。
- **退化态**:inline / fork 两形态**线缆不可分辨**(都是裸字符串)——不猜,统一渲法;
  `SKILL_NOT_FOUND` / `SKILL_FORK_REQUIRES_AGENT` → 失败相。
- **交互**:chip 保持 mono(无实体 id);「查看全文」浮层 + 窗顶栏整卡复制(见落定体);
  inline 模式 deep link 跳 skill 面板;窗内容可选中复制。
- **新原语**:ToolWindow 顶栏整卡复制动作(palette 缺口 #12,小原语);全文浮层复用既有浮层原语。
- **Wow**:预授权副作用被写在明面上——权限的移动从不静默。
- **可行性**:输出 ≤32KB(inline)可控;fork 结果长度无界 → 封顶 + 逃生口必须。

---

## 六、move_document — 正在移动文档 → 已移动文档

- **收起行**:doc icon · 动词 · chip:live=`args.id`;settled 换**解析出的文档名**
  (settle-only 升级,拿不到就留 id)· 回执=`→ {new path}`(路径中段省略,封顶 chip 宽)。
- **活期**:settle-only。
- **落定体**:一行 `AnRefPill(document, id)` + KV 两行:`位置 → {parentId|root}`、
  `路径 → {path}`(全部来自输出模板解析;position 来自 args 若有:`第 N 位`)。
- **morph**:无(旧路径不在线上,单端陈述即可——路径 chip 落定滑入一次,轻)。
- **退化态(§4 三值)**:命中成功模板 `Moved "<name>" to <parent> (new path: <path>).` → 成功;
  命中已知软失败模板(err=nil 指引串:doc 不存在 / 新 parent 不存在 / 环 / parentId 键缺席,
  census 06 全量)→ failed 相——失败声调 + 自动展开 + 软失败原文红 mono 进展开体首行(文案
  自带修复指引,原样示人),**绝不渲"已移动文档"过去时成功动词 + 收拢卡**;**两者皆不匹配 →
  unrecognized 中性态**(动词退中性词形 + "结果未识别" 灰尾注,原文进通用窗、无回执——后端
  成功模板一字之改不得把每一次成功渲成假失败)。
- **交互**:ref pill 跳 documents 海洋该文档。
- **新原语**:解析器 `movedReceipt`(正则模板)。
- **Wow**:回执直接是新家地址——移动这件事的凭据就是路径本身。
- **可行性**:同 delete_document 的英文模板脆性;哑火安全降级已定义。

---

## 七、update_meta 三胞胎(function / handler / agent)

### `update_function_meta` — 正在更新信息 → 已更新信息(纯改名:正在改名 → 已改名)
- **收起行**:function icon · **动态动词**(确定性,从 args 键集派生:仅 `name` 键 → 改名对;
  否则更新信息对。**依赖 §12 底盘 verb 缝扩签名 `verb(t,{live,state})`**——现签名不接 state,
  做不出来;且特化只在 args 完整后(running 相位起)生效,argsStreaming 期恒用通用
  "正在更新信息"对,防键渐进流入时动词闪变)· chip=`args.functionId` · 回执=被改字段的中文名
  连缀:`名称 · 标签`(args 键存在性派生,与输出 `{id, name, description, tags}` 交叉核验——
  键在 args 里才算;**零字段退化**:args 只有 id、无任何可改键 → 回执落空即无回执,诚实铁律)。
- **活期**:settle-only。
- **落定体**:delta chips(**单端,诚实**——旧值不在线上,不渲 `a → b` 只渲 `→ b`):
  `AnKv` 行列,被改字段 `名称 → data-fetcher` / `标签 → 3 项`(tags 渲 `AnTags readOnly`);
  未动字段不列。尾行 ref pill。
- **morph**:delta chips 落定逐行淡入(AnExpandReveal 自然呈现),不做假双端。
- **退化态**:`FUNCTION_NAME_DUPLICATE` / `FUNCTION_INVALID_NAME` → 失败相(message 自明)。
- **新原语**:无(AnKv + AnTags 复用)。
- **Wow**:改了什么、只列什么——三行以内看完一次元数据手术。
- **可行性**:args 指针语义(缺席=不动)与输出全量行,键存在性判据精确。

### `update_handler_meta` — 同上
- chip=`args.handlerId`。**差异注记**:落定体多一行灰字"无新版本、无重启、内存态保全"
  (契约卖点——与 edit_handler 的重启路径相对照,值得一行)。

### `update_agent_meta` — 同上
- chip=`args.agentId`。错误族:`AGENT_NAME_CONFLICT`。无其它差异。

---

## 八、update_handler_config — 正在配置 → 已配置

- **收起行**:handler icon · 动词 · chip=`args.handlerId` · 回执=`N 键`(N=args.config 顶层
  键数,args 派生——**纯 args 可证事实,不写"实例已重启"**:输出只有 `{id, configUpdated:true}`、
  无 runtimeState,断言重启为既成事实违本族给 revert_handler 立的规矩;且首配场景
  (create_handler 后实例从未 spawn)根本无实例可"重启",断言直接为假)。tone=warn
  (触发重启、内存态抹除)。
- **活期**:settle-only。
- **落定体**:`AnKv` 键清单:每个 config 顶层键一行——值非 null → `key → <值,mono,≤64 字省略>`;
  值为 null → `key`(删除线 + 灰)`已移除`(merge patch 语义可视化)。**脱敏规则(掩码纯函数,
  分长短)**:len≥9 中段掩码(`sk-4…f2a` 式,首尾各 4 字);**len≤8 一律全遮 `••••`**——短值
  首 4+尾 4 = 完整泄漏,而 `true`/`5` 这类短值恰是 config 常态,掩码规则不得自己漏底;单测电池
  加短值/空串/CJK 用例。本卡拿不到 InitArgSpec 的 sensitive 位,按最坏假设处理(api key 是本
  工具的主场景);完整值本就在 transcript args 里,卡不做二次泄漏面。
  尾行 ref pill + 琥珀注记(触发式措辞,照 revert_handler 的标准):**"已触发重启以生效;
  运行状态见 handler 面板"**——绝不断言"已重启成功/已生效",ref pill 即核实入口;若要状态词,
  走迭代铁律②让后端在输出里带 runtimeState(与 restart_handler 对齐),注记才可升级。
- **退化态**:`HANDLER_CONFIG_DECRYPT_FAILED`(内部)→ 失败相;输出非 `{id, configUpdated:true}`
  → 无回执。
- **交互**:ref pill 跳 handler 面板(必填缺配 missingConfig 在那里看)。
- **新原语**:无(AnKv 复用;掩码是纯函数)。
- **Wow**:merge patch 的三种笔画——设值、删键、掩码——一张 KV 表说尽,秘密永远不露底。
- **可行性**:config 是自由 object;嵌套值渲 JSON 单行省略(不递归展开,薄卡纪律)。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| **ToolReceipt tone 扩展** | 底盘(model) | 回执 danger:bool → tone{none,warn,danger},琥珀半态(draining/软删/内存抹除)有了合法颜色;danger 仍自动展开 |
| **ToolCardSpec.classifyResult 缝** | 底盘(catalog) | 三值谓词钩子 {ok, failed, unrecognized}:结果内失败(restart_handler 的 error 键、document 系已知软失败模板)重分类为 failed 相位;模板不识别落中性"结果未识别"态——"工具绿但物已坏"不被吞,模板漂移也不渲假失败 |
| **ToolDependentsBlock** | feature(skins) | 删除审计块:N 处引用受影响 + AnRefPill Wrap 可点跳修 + note 灰字;兼容 JSON 形与 delete_agent 字符串形(字符串形 kind 经 S15 前缀白名单派生,未知前缀 "?" 不可点) |
| **ToolProblemsBlock** | feature(skins) | NOT_RUNNABLE 违例红清单(details.problems 逐条,封顶 20 条 + `+N 条违例` 溢出行)+ warnings 黄条(同规格);capability_check 卡可复用 |
| **ToolWindow 顶栏整卡复制** | core/ui(ToolWindow 小修) | 机器窗顶栏复制全文动作(palette 缺口 #12);activate_skill 截断逃生口之一,全族机器窗受益 |
| **AnVersionRewindChip** | core/ui(gallery-first,P2) | mono `⤺ vN` 倒带徽标:落定一次性逆时针画弧 + 右→左滑入;reduced 静态;需底盘 receiptWidget 可选槽 |
| **回执解析器组** | feature(tool_receipts) | revertReceipt / deleteReceipt(JSON)/ deleteAgentReceipt(字符串)/ deletedDocReceipt / movedReceipt / lifecycleReceipt / killReceipt / restartReceipt / metaFieldsReceipt——纯函数全单测 |

## 族内建造顺序建议

1. **P0 解析器组 + 26 员 catalog 条目**(动词对 i18n + 目标 chip + 文本回执):一次提交把全族
   从 generic 卡升到"薄卡完美态"的 80%;解析器纯函数,测试便宜(空/畸形/截断/双形状五电池)。
2. **P0.5 底盘双修**:ToolReceipt tone 扩展 + classifyResult 三值缝(各 ~20 行,restart_handler、
   document 系与琥珀回执立即受益;先于块组件,因为回执颜色是块的前提)。
3. **P1 ToolDependentsBlock**(delete 八员的审计价值核心;delete_agent 字符串形 + S15 前缀
   白名单兼容一并做)。
4. **P1 ToolProblemsBlock**(stage/activate 失败面,含 20 条封顶 + 溢出行;顺手给
   capability_check 留缝)。
5. **P1 activate_skill 真逃生口**(「查看全文」浮层 + ToolWindow 顶栏整卡复制)——6000 硬截断
   的合宪前提,随 activate_skill 卡落地同批。
6. **P2 AnVersionRewindChip**(gallery 先行 + 底盘 receiptWidget 槽;纯打磨,不阻塞)。
7. **P2 图标精确表补 skill 字形** + settled 目标 chip 升级(move_document 名字替换)。


---

# F06 — entity-get 族(get×8 + read_document + read_attachment,共 10)

> 族定位(WRK-053 §4):「正在查看 X → 已查看」;完美态 = **「模型看到了什么」的诚实小陈列**:
> 实体身份行 + 关键字段 KV + 大内容折叠。全族只读、零 progress、非 BuildTool——克制是本族的完美。

---

## 族级统一文法

1. **动词对**:实体 get 一律「正在查看〈类名词〉→ 已查看〈类名词〉」(Viewing/Viewed function…);
   `read_document`「正在阅读文档 → 已阅读文档」;`read_attachment`「正在读取附件 → 已读取附件」。
2. **chip 落定换名(族签名动效)**:活期 chip = args 里的 id(`argStringPartial`,容忍半截);落定后
   `target(state)` 优先读输出里的 `name`(read_document 解析首行 `# <name>`,read_attachment 解析
   引号内文件名)——收起行从 `fn_a1b2c3…` 无感变成 `fetch-weather`,id 移入展开体。历史读起来像目录。
3. **命脉回执**:回执 = 该实体的 1~3 个 vitals,全部从输出严格解析——JSON 系逐字段取、串模板系
   (read_document/read_attachment)按前缀/行序白名单取(解析不匹配即无回执,铁律 #4;白名单内的
   软失败形有自己的诚实回执,见文法 7);形如 `v3 · env ready`。**get 本身成功 ⇒ 回执一律
   danger:false**(实体自身的坏态是「被看见的信息」,用体内红徽章讲,不劫持自动展开)。
4. **活期 = settle-only**:args 只有一个短 id,瞬时流完;无 liveBody(克制,#9)。活感只有流光动词 +
   chip 浮现;>3s 读秒由底盘兜。
5. **落定体 = EntityGetBody 四段骨架**(全族一套,各工具只写投影):
   ① **身份行 ToolEntityHeader**:AnRefPill(kind+name,可点派 select intent 跳实体面板/海洋)+
      mono id + 右缘 meta(`vN · 相对 updatedAt`);
   ② **关键字段 AnKv**(dense,label 13/value 13~15;徽章类字段用 AnBadge 行内;**混排 KV 靠
      AnKvRow 行级 mono 开关**——本族几乎每张卡都在同一列表里混排散文值[description]与 mono 值
      [id/CEL/签名/`modelId @ apiKeyId`/webhook path],而现状 `mono` 是 AnKv **列表级**布尔
      [an_field.dart],行级开关是 core 小改,见汇总);
   ③ **大内容折叠区**:代码/prompt/模板/正文住机器窗(AnCodeEditor reading 档 / ToolReadingWindow),
      >50 行包 AnFadeCollapse(collapsedHeight 400,**fadeColor 显式传 surfaceSunken**),
      窗内容封顶 6000 chars + 诚实截断注记 + 「在实体面板查看全文」逃生口;
   ④ **RawResultDisclosure**:收拢的「原始返回」披露组(AnDisclosure + AnJsonTree@`AnSize.jsonViewport`
      / 串输出→capped mono)——「模型看到的完整底账」,诚实兜底 + 逃生口,全族统一收尾。
      **边界铁则:体内投影可选摘/可掩码,Raw 永不过滤字段**——一律喂未过滤完整 JSON(大串由
      AnJsonTree 单值 500 截断天然收敛,无体积风险);唯一例外是已知敏感值(如 webhook secret)
      可 `••••` 掩码,但**掩码必带注记**(「N 个敏感值已掩码——完整值在实体面板」),不得静默。
6. **图标**(现状按 icons.dart 已核):关键字推断覆盖 function/handler/agent/workflow(实体形);
   `get_trigger` 命中 `workflow|trigger` 正则落 **workflow 形(非 trigger 实体形,错形)**;
   `read_document`/`read_attachment` 命中 `read` 关键字落 **doc 形**(read_attachment 非落扳手——错形而非缺口);
   `get_control`/`get_approval`/`get_skill` 无命中→兜底扳手。**须补精确表**(精确表先于关键字推断,可覆写):
   control→分支形、approval→勾形、skill→书形、trigger→zap 实体形、attachment→回形针
   (`AnIcons.attach` 已存在,直接复用),与 entities rail 同形。
7. **退化统一**:输出 JSON 解析失败 → 通用体(capped mono 窗)+ 无回执;**not-found 软失败串**
   (document/attachment 系 err=nil、前缀是稳定模板:`Document "x" not found.` [document/read.go:56] /
   `Attachment "x" not found.` [attachment/read.go:57])→ **前缀入两解析器白名单,回执「未找到」
   (中性灰 danger:false)**,相位仍 succeeded、提示串(含引导句)原样进机器窗——前缀可严格解析
   就不装哑:「无回执」只留给真解析不匹配,否则收起行「已阅读文档 doc_x」与成功阅读在历史目录里
   零区别,违「空结果诚实说无」;单测锁两条前缀。其余未知串 → 无回执 + 原样进窗(不装懂)。

---

### `get_function` — 正在查看函数 → 已查看函数
- **收起行**:function 实体形 icon · chip 活期=`args.functionId`、落定换输出 `name` · 回执=
  `activeVersion.version`+`envStatus`,**四枚举全定**(线缆 pending|syncing|ready|failed,不留
  建造者即兴空间):ready→`v3 · env ready`、syncing→`v3 · env building`、pending→`v3 · env pending`、
  failed→`v3 · env failed`——get 成功⇒四枚举一律 danger:false(failed 的红只在体内徽章 + envError
  行,不劫持自动展开);i18n 四条一并登记(handler 同表复用)。
- **活期**:settle-only(见族文法 4)。
- **落定体**:EntityGetBody——身份行(pill 跳 entities 海洋该 fn);KV:description / tags(AnTags
  readOnly)/ 签名行 inputs→outputs(`name:type` 逗号串,mono)/ dependencies(pip 药丸)/
  pythonVersion / env(AnBadge 四枚举:ready ok・syncing warn・pending 灰・failed danger,
  `envError` 红 mono 行随后);
  内容区:`activeVersion.code` 装 AnCodeEditor(python,reading)+ AnFadeCollapse;RawResultDisclosure。
- **退化态**:activeVersion 缺席→「无活跃版本」灰占位行;code 超 6000 chars→封顶+注记+实体面板逃生口。
- **交互**:身份 pill 深链实体面板;代码窗自带 copy。
- **新原语**:复用族级 ToolEntityHeader/EntityGetBody/RawResultDisclosure;其余全现成。
- **Wow**:收起行即目录条——`已查看函数 fetch-weather · v3 · env ready`,一眼知道模型刚看了什么、它健不健康。
- **可行性**:单 JSON settle 全量;code 可达数十 KB——先按行/字符封顶再喂高亮(AnCodeEditor 无虚拟化)。

### `get_handler` — 正在查看处理器 → 已查看处理器
- **收起行**:handler 形 icon · chip=`args.handlerId`→输出 `name` · 回执=`v5 · 4 方法 · running`
  (version+methods 数+runtimeState,runtimeState 缺席则省)。
- **活期**:settle-only。
- **落定体**:身份行;**双态徽章行**(本工具独有):configState(ready ok / partially warn /
  unconfigured warn)+ runtimeState(running ok / stopped 灰 / crashed danger),`missingConfig`
  非空→红 mono 列出缺配键;KV:description/tags/dependencies/pythonVersion/env(同 function);
  **methods 表** AnThinTable(mono 列):name · 签名(`(a:string)→{…}`)· streaming ✓ · timeout;
  **initArgsSchema 表**:name · type · required · sensitive(锁形字符,**值永不出现**——线缆本就不含值);
  代码区:imports / initBody / **shutdownBody(非空时)** **分段窗**——每段窗外灰小节标签
  (13 档:`imports` / `__init__` / `shutdown`)+ 各自 AnCodeEditor(python,reading)只装该
  存储字段**原文**,整区包一个 AnFadeCollapse。**机器窗身份铁则:窗内容必须是真实字段一字不差、
  copy 出即原文——禁用合成注释行(`# imports` 等)把三字段拼成一份「看似真实源码」**,拼接物不是
  任何存储字段的原文,静默模糊机器窗与展示投影的边界;分段标签住窗外,窗内零合成字节。
  线缆 activeVersion 含 shutdownBody,空时省段但略过必须显式、不得静默吞字段(method body
  不全量陈列——在方法表行点开?v1 不做,逃生口去实体面板);
  RawResultDisclosure。
- **退化态**:activeVersion 缺席→占位;methods 空→「无方法」诚实行。
- **交互**:pill 深链;方法表 selectable 留待实体面板承接(v1 只读)。
- **新原语**:AnThinTable **列级 mono 开关**(小改现有原语);余复用族级件。
- **Wow**:configState×runtimeState 双态一行看穿——「代码好了但没配 key」和「配了但 crash」终于长得不一样。
- **可行性**:MethodSpec.body 是 PAYLOAD 但 v1 不展开陈列,体积可控;双态字段 omitempty,渲染须容忍缺席。

### `get_agent` — 正在查看智能体 → 已查看智能体
- **收起行**:agent 形 icon · chip=`args.agentId`→输出 `name` · 回执=`v4 · 3 工具`
  (activeVersion.version + tools 数;无 activeVersion→回执 `无活跃版本`)。
- **活期**:settle-only。
- **落定体**:身份行;**挂载陈列**(本卡主角):tools → AnRefPill Wrap(fn_/hd_ 可点深链,
  `mcp:server/tool` plug 形不可点;**pill label 定死 = 线缆 `tools[].name`**——它是创建时快照、
  也是模型看到的底账[运行时后端恒用实体现名、忽略此 name,census 03],合族「模型看到了什么」的
  使命;name 缺席回落 mono ref;规范注明「可能非实体现名,点击深链见真身」,不得改用 ref id
  作 label、不得另发请求解析现名),knowledge → document pill Wrap(**线缆只是 docId 数组、无 name
  ——v1 pill label = mono docId,诚实零额外请求,点击深链 documents 海洋;名称解析若做属 UI 增补,
  须失败静默回落 id,不得擅自超出规范**),skill → 单 pill;
  KV:description/tags/inputs→outputs 签名/modelOverride(`modelId @ apiKeyId` mono);
  内容区:`prompt` 装 AnCodeEditor(markdown,reading)+ AnFadeCollapse(prompt 是被创作的源码,
  不渲排版态——与 builds 族的活代码窗同一具身份);RawResultDisclosure。
- **退化态**:activeVersion omitempty 缺席→「无活跃版本」AnCallout(warn,提示 edit_agent/revert);
  tools/knowledge 空→省段不占位。
- **交互**:每个挂载 pill 都是深链——这张卡是「agent 的能力地图」,点哪去哪。
- **新原语**:复用族级件 + AnRefPill(现成,原语不碰导航、feature 接 intent)。
- **Wow**:一张卡摊开 agent 的全部装备——prompt 折着、能力 pill 亮着,像 Linear issue 卡陈列关联。
- **可行性**:prompt 可数十 KB→封顶;tools ref 解析 `hd_<id>.method` 需拆点号显示 method 缀。

### `get_workflow` — 正在查看工作流 → 已查看工作流
- **收起行**:workflow 形 icon · chip=`args.workflowId`→输出 `name` · 回执=
  `v2 · 6 节点 · active`(graphParsed.nodes 数 + lifecycleState;inactive 省略第三段)。
- **活期**:settle-only。
- **落定体**:身份行;状态徽章行:lifecycleState(active ok / draining warn / inactive 灰)+
  concurrency + `needsAttention`→AnCallout(warn,attentionReason 全文);
  **图摘要区**:`6 节点 · 7 边` 计数行 + 节点 AnThinTable(mono 列:id · kind · ref[实体 ref 可
  渲 pill 深链] · notes 省略截断);边不表列(噪声),收进 RawResultDisclosure;
  **升级路径**:F04 画布原语落地后,此区换**静态缩略图**(只读小画布,pos 已在线缆里)——设计留槽不阻塞;
  RawResultDisclosure(**喂未过滤完整 JSON,含 `graph` 原始串与 `graphParsed` 双份**——「只认
  graphParsed、忽略 graph」仅适用于体内图摘要投影;Raw 是完整底账、永不过滤[族文法 5④],
  大 graph 串由 AnJsonTree 单值截断天然收敛)。
- **退化态**:graphParsed 缺席/解析失败(同一路径)→ 回执退化为 `v2 · active`(**去节点段**——节点
  计数本身取自 graphParsed.nodes,缺席即无从数),体内省略整个图摘要区,仅 Raw 披露兜底;
  NO_ACTIVE_VERSION 是工具错误(底盘失败相位)。
- **交互**:身份 pill 深链;节点 ref pill 深链到被引用实体。
- **新原语**:复用族级件 + AnThinTable mono 小改;缩略图挂 F04 的画布原语(本族不新建)。
- **Wow**:模型看图,你看结构清单——每个节点的 ref 都是活的 pill,图的骨架一眼可点。
- **可行性**:大图数十 KB;节点表封顶 80 行 + 「N+」注记;pos 字段 v1 不消费。

### `get_control` — 正在查看控制逻辑 → 已查看控制逻辑
- **收起行**:control 形 icon(补精确表)· chip=`args.controlId`→输出 `name` · 回执=
  `v3 · 4 分支`(activeVersion.version + branches 数)。
- **活期**:settle-only。
- **落定体**:身份行;KV:description / inputs 签名;**分支表**(本卡主角,first-true-wins 语义即
  视觉):AnThinTable 带**序号列**(1..N,顺序即优先级)· port(AnBadge)· when(mono CEL)·
  emit(mono,`k←expr` 逗号串);**末行 `when:"true"` 兜底行**灰底标注「兜底」;RawResultDisclosure。
- **退化态**:activeVersion omitempty→「无活跃版本」占位;branches 空(理论不可能,建时强制)→诚实空行。
- **交互**:pill 深链实体面板。
- **新原语**:复用族级件 + AnThinTable mono 列。
- **Wow**:路由逻辑长成一张自上而下的判定表——顺序、兜底、出口一眼读完,不用啃 JSON。
- **可行性**:分支组 <5KB 紧凑;CEL 单行长表达式靠表列省略截断 + Raw 披露兜全文。

### `get_approval` — 正在查看审批表 → 已查看审批表
- **收起行**:approval 形 icon(补精确表)· chip=`args.approvalId`→输出 `name` · 回执=
  `v2 · 超时 30d`(version + timeout;timeout 空→`v2 · 永不超时`)。
- **活期**:settle-only。
- **落定体**:身份行;**规则 KV**:allowReason(✓/—)/ timeout / timeoutBehavior(reject/approve/
  fail 用 AnBadge:reject danger 倾向、approve ok、fail warn)/ inputs 签名;
  **模板区**:`template` 是 markdown 给人看的决策说明 → **ToolReadingWindow 渲排版态**(15/1.6);
  喂 AnMarkdown 前过**moustache 插值预处理**(纯函数):把 `{{ input.* }}` 段包成行内 code span
  ——AnMarkdown 只对反引号 span 渲 code chip,moustache 裸文本不会自动成 chip,线缆不保证模板
  作者自带反引号;chip 是**展示投影**、非原文(已带反引号的段不二次包;**先按 ``` 配对切分,
  围栏码区段整段跳过、只处理围栏外文本**——否则围栏内的 `{{ input.x }}` 被注入的反引号以字面
  形式渲进代码块,污染排版态;单测锁两形:已反引号不二次包 + 围栏内 moustache 不动形),
  Raw 披露保留未处理模板原文;+ AnFadeCollapse;RawResultDisclosure。
- **退化态**:activeVersion 缺席→占位;template 空(建时强制非空,防御性)→省段。
- **交互**:pill 深链。
- **新原语**:**ToolReadingWindow**(族级新建,见汇总)首用于此;**moustache 插值预处理**(纯函数,见汇总)。
- **Wow**:审批单在工具卡里就长成「将来给人看的那张单子」——预览即最终态,规则条一行读懂超时命运。
- **可行性**:template <5KB 典型;markdown 渲染 A 级流式适性但此处只喂 settled,零风险。

### `get_skill` — 正在查看技能 → 已查看技能
- **收起行**:skill 形 icon(补精确表)· chip=`args.name`(**本身即人话 slug,无换名步**)· 回执=
  `inline · ai`(读输出**顶层** `context` + `source` 字段——两者恒在有默认值;frontmatter 内的
  context/source 是 omitempty 可缺席,**不作回执源**、只作 KV 展示源,免得字段缺席平白丢回执;
  fork 则 `fork · user` 等)。
- **活期**:settle-only。
- **落定体**:身份行变体(skill 无 id——pill 以 name 为 id,kind=skill,深链 entities 海洋 skill 区);
  KV:description / context(inline/fork AnBadge)/ source(ai/user)/ agent(fork 时,pill 深链)/
  arguments(命名参数药丸)/ disableModelInvocation(✓ 时显「仅用户可触发」)/ updatedAt;
  **allowedTools 行**:AnTags readOnly + 灰 meta 注「激活后本次运行预授权免确认」(把安全语义说破);
  内容区:`body` 装 AnCodeEditor(markdown,reading)+ AnFadeCollapse(skill 是指令源码,不渲排版态);
  RawResultDisclosure。
- **退化态**:frontmatter 字段大量 omitempty——KV 只列出现的键,零空行。
- **交互**:pill 深链;agent pill 深链。
- **新原语**:全复用。
- **Wow**:allowedTools 那行灰字把「看不见的预授权」拉到光下——读一个 skill 就看清它激活后能免问干什么。
- **可行性**:body ≤32KB 有上限,封顶注记仍要;JSON 直返 Skill struct,解析稳。

### `get_trigger` — 正在查看触发器 → 已查看触发器
- **收起行**:trigger 形 icon · chip=`args.triggerId`→输出 `name` · 回执=`cron · 监听中`
  (kind + listening?「监听中」:「未监听」)。
- **活期**:settle-only。
- **落定体**:身份行(meta 位放 kind AnBadge——trigger 无版本);**命脉行**:AnStatusDot
  (listening→ok 静态,未听→idle 灰)+ `refCount` 个引用 + lastFiredAt / nextFireAt(cron,相对时间);
  **config KV(按 kind 投影)**:cron→expression(mono)+ 下次触发;webhook→完整 URL
  `POST /api/v1/webhooks/{id}/{path}`(mono,可复制价值最高)+ secret **掩码 `••••`**(注意:与
  handler sensitive「值不出线」不同,census 确认 trigger config 照存照返、secret 明文在线缆里——
  故 **Raw 披露对 `config.secret` 同样 `••••` 掩码 + 注记**「1 个敏感值已掩码——完整值在实体面板」,
  maskedValue helper 一并覆盖 KV 与 Raw 双投影,遵族文法 5④「掩码必注记」;两头一致才配说「值永不渲」)+
  signatureAlgo/Header;fsnotify→path(mono)/events 药丸/pattern;sensor→target
  (`targetKind:targetId` RefPill——function/handler 可点深链;**targetKind=mcp → plug 形不可点
  pill,与 get_agent 挂载陈列文法对齐**)+ method + intervalSec + condition/output(mono CEL);
  outputs 签名表(sensor 才是作者所填,余 kind 是 canonical 盖章——照实显示);RawResultDisclosure。
- **退化态**:lastFiredAt/nextFireAt omitempty→省行;config 键超出已知集→余键落 Raw 披露,不硬渲。
- **交互**:pill 深链;sensor target pill(function/handler)深链;webhook URL 的 mono KV 行
  **显式包 SelectionArea**(或加行内 copy affordance,顺手回应 palette 缺口 #12)——复制路径**不押**
  AnJsonTree 内文本选中能力(palette 只对 AnMarkdown 明文承诺 SelectionArea,TreeSliver 可选中
  未验证,该逃生口可能物理不存在)。
- **新原语**:复用族级件 + `maskedValue` 微 helper(secret/敏感值掩码,与 handler sensitive 共用,
  覆盖 KV 与 Raw 双投影 + 掩码注记)。
- **Wow**:一张卡回答「它听着吗、谁在听、上次/下次什么时候响」——信号源的心电图,而不是 config dump。
- **可行性**:<2KB 极小;config 自由 map,按 kind 白名单投影 + 余键兜 Raw,前向兼容。

### `read_document` — 正在阅读文档 → 已阅读文档
- **收起行**:doc 形 icon · chip=`args.id`→落定解析输出首行 `# <name>` 换名 · 回执=正文行数
  `142 行`(取 `---` 分隔符后段计行;not found 前缀→回执「未找到」[族文法 7];模板解析失败→无回执)。
- **活期**:settle-only。
- **落定体**(族嘱托:**渲排版态而非源码**):身份行变体——document pill(name,id 取自 `ID:` 行,
  深链 documents 海洋)+ **path 面包屑** meta(`Path:` 行)+ tags(`Tags:` 行,AnTags readOnly);
  **ToolReadingWindow**:正文 markdown 经 AnMarkdown 渲 15/1.6 排版态(标题降档/码块/表格全套),
  AnFadeCollapse 400px 渐隐收合,展开行「阅读全文」;卡内正文封顶 6000 chars + 诚实注记
  「全文 N 字符 — 在文档海洋打开」;RawResultDisclosure(原始模板串 capped mono——模型看到的
  一字不差的底账)。
- **退化态**:模板解析失败(格式漂移/多行 description)→整串 capped mono 机器窗 + 无回执;
  not found 软失败串→succeeded 相位 + **回执「未找到」**(前缀白名单严格解析,族文法 7)+
  提示串进窗(含「去 search/list_documents」引导原文);1MB 上限→封顶逃生口。
- **交互**:pill/逃生口深链 documents 海洋该文档;正文 SelectionArea 归宿主可选中复制。
- **新原语**:**ToolReadingWindow**(与 get_approval 共用)+ read_document **模板解析器**(纯函数,
  **严格行序状态机**:`# <name>`→空行→`Path:`→`ID:`→可选单行 `Description:`→可选单行 `Tags:`→
  `\n---\n\n`→正文;**任何一步不匹配即整串降级 capped mono + 无回执**——Description 是后端 `%s`
  直插的自由文本[read.go:63],可含换行甚至伪 `---` 段,宽松解析会把元数据错切进正文、行数回执与
  渲染正文双错;单测锁形 + 多行 description 注入用例)。
- **Wow**:工具卡里摊开一页排好版的稿子——模型读什么、你读什么,但你读到的是成品排版,不是源码墙。
- **可行性**:输出是字符串模板非 JSON——解析器脆,后端措辞一变即静默降级(需 testend/单测锁模板);
  AnMarkdown 围栏码每帧重高亮,只喂 settled 无虞。

### `read_attachment` — 正在读取附件 → 已读取附件
- **收起行**:回形针 icon(补精确表)· chip=`args.id`→落定解析输出 `"<filename>"` 换名 · 回执
  (按**六形前缀白名单**解析,见可行性):文本/文档形→截断标记出现则 `已截断`、否则字符量
  `12.4k 字符`——**截断标记只从首行头解析**(首个 `:\n` 之前的 `(truncated)` /
  `(text-extracted, truncated)`,attachment.go:262/300;**禁全文 substring 检测**——正文本身含
  "(truncated)" 字样会假报已截断,违铁律 #4);抽取失败/抽取不可用两形→回执**「未能抽取」**
  (中性灰 danger:false;**绝不落字符量**——占位串按字符量计会渲出 `59 字符`,暗示读到了内容);
  媒体类描述符→`不可转文本`(诚实的中性灰,非失败);not found→「未找到」(族文法 7);解析失败→无回执。
- **活期**:settle-only。
- **落定体**:**AnAttachmentCard 复用**(ready 态:kind 图标格 + filename + metaLine[mime·大小,
  从描述符句可得则填,不可得则仅文件名])作身份行——与 composer/气泡里的附件卡同一张脸,认知零成本;
  文本/文档类:抽取文本装机器窗(mono 12,capped 6000 + 注记;`(text-extracted)` 标记时窗头灰注
  「PDF/Office 抽取文本」);媒体类:窗内单行诚实说明「图像/音频内容无法转为文本——模型未看到内容」
  (把后端教学长句压成一行人话,原句在 Raw 披露);抽取失败 `[document "x" attached, but its
  text could not be extracted]` / 抽取不可用 `[document "x" attached, but text extraction is
  unavailable for this model]`(extractor 未配,attachment.go:285)**两形均入白名单**→窗内
  danger 色行(回执均「未能抽取」——它们是 document 类的合法输出形,不入白名单会错落「字符量」形);
  RawResultDisclosure(原始串)。
- **退化态**:not found 软失败串→窗内原样 + 回执「未找到」(族文法 7);400K 上限→封顶 + 「N+ 字符」注记。
- **交互**:附件卡 onTap v1 惰性(附件无海洋);文本可选中复制;**逃生口(宪法 #8,必须物理存在)**:
  窗与 Raw 双双封顶 ~6000 chars 而线缆最大 400K 字符、附件又无海洋可跳(对比 read_document 有
  文档海洋兜底)——机器窗头加**「复制全文」affordance**:点击复制未截断完整原文(完整串就在
  result block 内存里,零额外请求)+ 短暂「已复制 N 字符」确认;这是本卡唯一的全文通路,不得省略
  (顺手回应 palette 机器窗 copy 缺口)。
- **新原语**:复用 AnAttachmentCard + 族级件;文件名/截断标记解析器(纯函数,单测锁形);
  **ToolWindow「复制全文」affordance**(窗头小改,见汇总)。
- **Wow**:附件在对话里始终一张脸——发的时候什么卡,模型读回来还是什么卡,下面多一扇「它读到了什么」的窗。
- **可行性**:字符串模板分叉实为**六形**(文本内联/文档抽取/媒体描述符/抽取失败占位/抽取不可用
  占位/not found),解析按前缀白名单匹配、不匹配即整串裸渲;**单测反例必备**:①body 含
  "(truncated)" 而首行头无标记→回执必须是字符量、非「已截断」;②抽取不可用形样例(第五形);
  kind 无法从输出稳取(媒体句含 kind 字段可解析,文本句不含)→ AnAttachmentCard kind 允许 fallback other。

---

## 族级新原语汇总

| 原语 | 一句话能力 | 层 |
|---|---|---|
| **ToolEntityHeader** | get 族共享身份行:AnRefPill(kind+name,select intent 深链)+ mono id + 右缘 meta(vN·相对时间);skill/document 变体(name 即 id / path 面包屑) | feature skin |
| **EntityGetBody** | 四段骨架组装器(身份行→KV→内容折叠区→原始返回),各 get 只喂 kind 投影函数 | feature skin |
| **RawResultDisclosure** | 「原始返回」披露组:AnDisclosure + AnJsonTree@240(JSON)/capped mono(串)——全族统一诚实底账 + 逃生口;**永不过滤字段**,敏感值掩码必带注记(族文法 5④) | feature skin |
| **ToolReadingWindow** | 排版态阅读窗:AnSunkenPanel(bubble inset)+ AnMarkdown 15/1.6 + AnFadeCollapse(fadeColor=surfaceSunken);read_document / get_approval 共用 | feature skin |
| **AnThinTable mono 列开关** | 列级 `mono:bool`(CEL/ref/签名列等宽);小改现有原语非新建 | core 小改 |
| **AnKvRow 行级 mono 开关** | 行级 `mono:bool`——本族 KV 几乎张张混排散文值(description)与 mono 值(id/CEL/签名/`modelId @ apiKeyId`/webhook path),现状 `mono` 是 AnKv 列表级布尔(an_field.dart)只能全 mono 或全散文;与 AnThinTable mono 列同族小改 | core 小改 |
| **ToolWindow「复制全文」affordance** | 机器窗头 copy 钮:复制未截断完整原文 + 「已复制 N 字符」确认(完整串在 result block 内存,零请求);read_attachment 的唯一全文逃生口(宪法 #8——窗与 Raw 双封顶 6000 而线缆 400K、附件无海洋),他族窗可共用 | core 小改 |
| **maskedValue helper** | 敏感值掩码 `••••`(webhook secret / sensitive init-arg),覆盖 KV 与 Raw 双投影 + 掩码注记(族文法 5④) | 纯函数 |
| **moustache 插值预处理** | get_approval 模板 `{{ input.* }}` 段包成行内 code span 的展示投影(纯函数单测锁形;已带反引号不二次包;**围栏码区段整段跳过不注入**;Raw 保原文) | 纯函数 |
| **模板解析器×2** | read_document 头部模板(**严格行序状态机,一步不匹配整串降级**)/ read_attachment **六形前缀**(文本/抽取/媒体/抽取失败/抽取不可用/not-found;**截断标记只认首行头**)的纯函数解析(单测锁形 + 反例:body 含 "(truncated)" 不假报、多行 description 注入) | 纯函数 |
| **toolIcon 精确表补条** | control/approval/skill/trigger/attachment 五形补进 AnIcons.toolIcon 精确表(现状:control/approval/skill 落扳手,get_trigger 错落 workflow 形,read_attachment 错落 doc 形;精确表先于关键字推断可覆写;attachment 用已有 `AnIcons.attach`) | core 小改 |

## 族内建造顺序建议

1. **共享地基一步到位**:动词对 + chip 落定换名文法 + ToolEntityHeader + EntityGetBody +
   RawResultDisclosure + toolIcon 补条——8 个 get 立即获得「目录条 + 通用陈列」的合格态。
2. **get_function / get_handler**:最富 KV + 代码窗直接复用 builds 族现成件;handler 双态徽章行
   与 methods 表(带 AnThinTable mono 小改)。
3. **get_agent**:挂载 pill 陈列(AnRefPill 现成,验证 ref 拆解 `hd_<id>.method`/`mcp:` 三形)。
4. **get_trigger / get_control / get_approval**:KV/表投影 + ToolReadingWindow 首落(approval 模板)。
5. **get_workflow**:节点表落地;画布缩略图**挂起**等 F04 画布原语,留槽不阻塞。
6. **read_document**:ToolReadingWindow 完全体 + 模板解析器 + 回归锁(族 showpiece)。
7. **read_attachment**:AnAttachmentCard 复用 + 六形解析 + 「复制全文」逃生口,收尾。


---

# F07 — searches 族完美态(11 工具)

> 覆盖:`search_function` `search_handler` `search_agent` `search_workflow` `search_control`
> `search_approval`(实体×6)+ `search_documents` `search_triggers` `search_blocks` +
> `list_documents` `list_attachments`。
> 线缆源:census 02(fn/hd)· 03(agent)· 04(workflow)· 05(ctrl/appr)· 06(doc/att)· 07(trigger)· 09(blocks)。

---

## 族级统一文法

**族魂:搜索即导航。** 全族 11 个工具都是只读、零 progress、一次性返回(紧凑 JSON 或软字符串)。
「生长秀」无从谈起(settle-only)——所以本族的完美态押在**落定体**上:命中不是日志行,而是
**一排能推开的门**:每行 = 实体字形 + 名字 + snippet,tap 直达实体面板(与 AnRefPill 同一
select-intent 通道)。收起后历史读起来是「已搜索函数 "http 重试" · 12 个」一行目录。

1. **收起行**:放大镜 icon(`search_*` 关键字推断已命中;两个 `list_*` 需补精确表)· 动词 ·
   `"query"` mono chip(argStringPartial 提取、首行折叠空白、底盘省略)· 灰回执
   `N 个 / N·共M(截断) / 无匹配`。
2. **动词双声道**:6 实体 search + search_triggers 的 `query` 可选、**空 = 列全部**——动词按
   args 切声道:有 query →「正在搜索{类} → 已搜索{类}」;空/缺席 →「正在列{类} → 已列{类}」
   (与 WRK-053「正在搜索 "Q"→找到 N 个」对齐,count 由回执承载)。
   **声道判定时机**:推迟到 args 完整(进入 running 相位)后才切——argsStreaming 期「query 尚未
   流到」与「query 不会来」不可区分,期间**锁定默认「正在搜索」声道**(本族 args 极小、窗口毫秒级,
   不值得中性词),不许流中动词翻面。verbOf/state 缝的契约注释明写:live + args 未完整 → 默认声道。
   ⚙️ 底盘微改:`ToolCardSpec.verb` 增可读 `state`(可选参数,向后兼容;或新增 `verbOf` 覆盖档)。
3. **活期(全族统一)**:数据源 **settle-only**。活期 = shimmer 动词 + query chip 随 args 流入
   点名(args-partial)。**无 liveBody**——本地 SQLite 查询亚秒级,窗必闪烁(宪法 #9 克制 +
   AnDeferredLoading 精神)。
4. **落定体 = ToolHitList 命中窗**(族级新原语,住 ToolWindow):
   行 = kind 字形(复用 AnRefPill 的映射,抽 `entityKindGlyph` 共享查表)+ name(**15 w400,
   内容值档**——落定体是内容工作区,主文按宪法 #5 双轨走内容 15、对齐 AnKv 值配比,不停
   chrome 13 锚)+ snippet/次行(13 muted,内容标签档、maxLines:1 省略)+ 尾 meta 槽
   (faint 13:id / 徽章 / ref)。gallery specimen 与 AnKv 体并排验收字阶一致。
   **级联点亮(两级判定,宿主写死)**:行 30ms 间隔淡入。本族无 liveBody 且成功态不自动展开
   (宪法 #3),body 在 running→settled 那一刻**必然未挂载**——所以触发判定拆两级、各钉宿主,
   缺一即级联静默永不播:① `transitionObserved` 由**常驻收起行**(卡级 state,随 tool_call
   block 生命周期,**非 widget local**)在本会话观察到 running→settled 相位切换时置位;
   ② ToolHitList **首次 body 挂载**时读 `(transitionObserved && !hasAnimated)` → 为真则播级联
   并置 `hasAnimated`;其余一切挂载(历史重载 / CustomScrollView 虚拟化滚出滚入重挂 / 二次展开)
   一律即时全显,与 AnMotionPref.reducedOrAssistive 走同一条即时路径——settle-only 数据下本族的
   「生长」母语(清单逐项点亮),且历史读起来不闪、不白耗逐行 controller。
   **封顶 + 两种截断(不可混同)**:search 体 20 行、list 体 30 行。footer 分两个显式状态:
   ① **本地超封顶**(结果行数 > 封顶——fallback 全量场景,如 200 个 function):footer =
   **逃生口**「前 N · 共 M」(无 total 时「+N 更多」),tap 后同窗切换为有界 AnJsonTree
   (height=AnSize.jsonViewport,复用底盘通用 JSON 体既有路径)——全量结果实实在在装在 JSON 里,
   信息不丢(宪法 #8:有界视口 + 查看全文)。② **服务端截断**(`total>count` 且行数 ≤ 封顶——
   engine 路径页上限固定 20 恰等于 search 封顶,本地超限在此路径永不触发):**display-only
   注记行**「前 N · 共 M(服务端截断)」,不可点、不承诺查看全文——第 21+ 条根本不在 tool
   result JSON 里(只有 nextCursor,卡不能翻页),诚实注记而非假入口(宪法 #4:截断必有显式
   注记,且注记必须活在展开体内、不能只靠收起行回执)。两态 i18n 分键。绝不无界滚动。
5. **回执解析器 `searchReceipt`**(tool_receipts.dart 新纯函数):容忍**双形状**——
   engine 路径 `{count,total,<listKey>,nextCursor?,hasMore?}` / fallback 路径 `{count,<listKey>}`
   (无 total);`count==0` → 诚实「无匹配」;`total>count` → `N·共M`;已知软字符串
   (`No blocks matched …`)→「无匹配」;其余解析不中 → **无回执**(绝不猜)。
   **null 列表防御**:空结果最可能的物理形状是 Go nil slice → `{count:0,<listKey>:null}`
   (F170 同源;后端 HTTP 侧修过、tool ToJSON 路径未证免疫)——解析器**显式容忍 listKey 为
   null / 整键缺席**:`count` 可解析且 ==0 即判有效空 →「无匹配/空」;`count>0` 但列表缺失
   才判解析不中 → 无回执。否则本族核心空态(回执即卡)恰好被砸进通用体。
6. **双形状铁律**:engine/fallback 由**键存在性**探测(有 `total` 即 engine),绝不按"应该走哪条
   路"猜;fallback 独有字段(workflow 的 lifecycleState/active、trigger 的 kind/refCount/listening)
   **有则渲、无则整槽消失**——engine 路径不伪造徽章。
7. **空态**:count 0 → 回执「无匹配」(列举声道用「空」),**无 body 无 chevron**(回执即卡,
   Read 同款);不渲染一个空窗。
8. **deep link 诚实降级(运行时判定,不维护清单)**:行 onTap **不按设计时「已建面板」清单
   硬接**(清单必陈旧,接线即假链接)——统一经运行时**面板能力注册表**(go_router 已注册可
   导航的 entity kind 集合,单一事实源)判定:kind 在注册表 → 行可点(select intent 走
   AnRefPill 同通道);不在 → `onTap:null`,AnInteractive 惰性态,**不放假链接**。本文档只立
   规则、不罗列哪些面板已建——面板落地当天链接自动活、落地前自动惰性。
9. **i18n 新键**(chat.tool 下):`searchingKind/searchedKind/listingKind/listedKind`(带 {kind})、
   `hits(n)`、`hitsOfTotal(n,total)`、`moreHits(n)`、`cappedFooter(n,total)`(本地超封顶逃生口
   「前 N · 共 M」)、`serverTruncatedNote(n,total)`(服务端截断 display-only 注记)、`emptyList`、
   `kind.blocks`、`kind.attachment`、`refCount(n)`、`listeningOn/Off`。

---

### `search_function` — 正在搜索函数 → 已搜索函数(空 query:正在列函数 → 已列函数)
- **收起行**:🔍 · 动词双声道 · chip=`"query"`(argStringPartial `query`)· 回执=searchReceipt
  (listKey `functions`):`12 个` / `20·共47` / `无匹配`。
- **活期**:settle-only;shimmer 动词 + chip 随 args 点名;无 liveBody。
- **落定体**:ToolHitList——行 = fn 字形 + name + description/snippet 次行 + 尾 faint mono id;
  级联点亮;封顶 20 + footer。
- **退化态**:空→回执即卡;JSON 不中→无回执+通用体;fallback 无 total→footer 只报行数;
  snippet 先按纯文本渲(FTS 标记形状未核验,不猜)。
- **交互**:行 tap → `{kind:function, id}` select intent(AnRefPill 同通道)→ entities 海洋。
- **新原语**:复用 ToolHitList + searchReceipt(族级)。
- **Wow**:搜完即门——每行直达该函数面板,tool 卡变 mini 命令面板。
- **可行性**:query 唯一 arg、流中即提;双形状 census 已钉;slim 行体积小,零风险。

### `search_handler` — 正在搜索处理器 → 已搜索处理器(空 query:列声道)
- 同 `search_function` 全套文法,listKey=`handlers`、字形=handler、intent kind=handler。
- **可行性**:契约与 fn 逐字同构(census 02 共享节),catalog 里同一个 `_entitySearch` helper 出。

### `search_agent` — 正在搜索智能体 → 已搜索智能体(空 query:列声道)
- 同上,listKey=`agents`、kind=agent。
- **退化态补充**:engine 路径 `hasMore` 只在截断时出现且恒 true——解析只认 `total`,不依赖 hasMore。
- **可行性**:census 03 §1 同构;无 sentinel(坏 args 由底盘 failed 相位兜)。

### `search_workflow` — 正在搜索工作流 → 已搜索工作流(空 query:列声道)
- **收起行/活期**:同族文法,listKey=`workflows`、kind=workflow。
- **落定体**:ToolHitList;**fallback 路径独有** `lifecycleState/active` → 行尾徽章:
  active→AnBadge(ok)·「active」;draining→warn;inactive→无徽章(灰噪省略)。engine 路径无此
  字段 → 徽章槽整体消失(不猜)。
- **退化态**:两形状差异即上述徽章有无;余同族。
- **交互**:行 tap → workflow 面板;徽章纯展示。
- **新原语**:ToolHitList 的尾 meta 槽(通用 trailing builder,本工具第一个消费者)。
- **Wow**:列全部时一眼看清哪几条 workflow 正活着——搜索卡顺手当了状态板。
- **可行性**:census 04 §5 钉死「只有 fallback 带 lifecycleState/active」;键探测渲染,零假设。

### `search_control` — 正在搜索控制逻辑 → 已搜索控制逻辑(空 query:列声道)
- 同 `search_function` 文法,listKey=`controls`、kind=control;含 archived(census 05:引擎路径
  含 archived——不加任何猜测性「已归档」标记,线缆没给)。
- **可行性**:census 05 §1 同构;典型 <2KB。

### `search_approval` — 正在搜索审批表 → 已搜索审批表(空 query:列声道)
- 同上,listKey=`approvals`、kind=approval。
- **可行性**:census 05 §7 与 control 完全同构。

### `search_documents` — 正在搜索文档 → 已搜索文档(query **必填**,无列声道)
- **收起行**:🔍 · 动词(单声道)· chip=`"query"` · 回执=searchReceipt(listKey `documents`)。
- **活期**:settle-only;同族。
- **落定体**:ToolHitList;**两形状 hit 字段不同**——engine `{id,name,snippet}` → 次行=snippet;
  legacy `{id,name,path,description}` → 次行=`path`(faint mono)+ description(muted),
  两段中点相接、按存在性渲。封顶 20(limit 上限 50,超 20 走 footer)。
- **退化态**:limit 越界/空 query → ValidateInput 硬错 → 底盘 failed 红行自动展开(不入族体);
  引擎静默回退 → 靠 hit 键形状适配,用户无感。
- **交互**:行 tap intent=`{kind:document,id}`;可点性经文法 #8 能力注册表运行时判定
  (document kind 未注册期自动惰性,注册当天自动活)。
- **新原语**:无新增(次行双槽是 ToolHitRow 标配)。
- **Wow**:legacy 路径把 path 摆进次行——树上位置一眼可见,搜索结果自带面包屑。
- **可行性**:census 06 钉死双 hit 形状(docHit omitempty);≤50 slim 行 <2KB。

### `search_triggers` — 正在搜索触发器 → 已搜索触发器(空 query:列声道)
- **收起行/活期**:同族,listKey=`triggers`、kind=trigger。
- **落定体**:ToolHitList;**fallback 独有** `kind/refCount/listening` → 行尾:
  kind 徽章(cron/webhook/fsnotify/sensor,AnBadge none 调)+ listening 状态点
  (true→AnStatusDot ok + 「监听中」;false 省略)+ `N 引用`(faint,refCount>0 才显)。
  engine 路径(snippet、无 kind)→ 尾槽整体消失。
- **退化态**:同族;engine 丢 kind 是线缆事实,不用兜底图标猜 kind——字形统一 trigger 形。
- **交互**:行 tap intent=`{kind:trigger,id}`,可点性经文法 #8 注册表判定;徽章展示。
- **新原语**:复用 workflow 已开的 trailing 槽。
- **Wow**:列全部触发器时,哪个正在听、谁被几条 workflow 用着,一行看穿。
- **可行性**:census 07 §1 两形状钉死;fallback 内存全量(无分页)→ 封顶 20 + footer 必须做。

### `search_blocks` — 正在搜索积木 → 已搜索积木(query **必填**)
- **收起行**:🔍(精确表已有 search_blocks→search)· 动词 · chip=`"query"` · 回执=searchReceipt
  (listKey `blocks`;软串 `No blocks matched` → 「无匹配」)。
- **活期**:settle-only;`kinds` 过滤若在 args 流入可提,但**不进收起行**(chip 只留 query)。
- **落定体**:体头一行(可选):`kinds` 过滤药丸(AnTags readOnly,如 `function · handler`)——
  args 有才渲。ToolHitList:行 = **hit 自带的 kind** 字形(六类:function/handler/mcp/agent/
  control/approval)+ name + snippet 次行 + **尾 = ref mono chip**(`fn_…` / `hd_….m` /
  `mcp:s/t`——可直接接线的地址,AnText.codeInline faint)。封顶 20(limit max 20,天然有界)。
- **退化态**:软串无匹配→回执即卡;`SEARCH_TYPE_INVALID`(kinds 非法)→底盘 failed;
  snippet 缺席(omitempty)→次行消失。
- **交互**:行 tap intent=`{kind, entityId}`,可点性**逐 kind** 经文法 #8 注册表判定
  (六类各自独立降级,如 mcp 未注册期惰性);ref 尾不单独可点(v1 无复制 affordance,
  全局缺口 #12)。
- **新原语**:无新增(kinds 药丸=AnTags readOnly;ref 尾=trailing 槽)。
- **Wow**:积木抽屉——每个命中自带「这块积木怎么插」的接线地址,搜索卡直接对话 workflow 画布心智。
- **可行性**:census 09 钉死 `{count,blocks:[{ref,kind,entityId,name,snippet?}]}` 单形状(无双路径);
  handler 方法/mcp 工具逐个成行,行数=能力粒度,20 上限护体。

### `list_documents` — 正在列文档 → 已列文档
- **收起行**:📄(补精确表 `list_documents→doc`;关键字 `doc` 其实已命中,补表锁语义)· 动词 ·
  chip=`parentId`(mono)——**chip 判定与动词声道同一裁定(文法 #2)**:live + args 未完整 →
  **无 chip**(只 shimmer 动词;argsStreaming 期「parentId 未流到」与「不会来=根」不可区分,
  先渲 `/` 再翻成 doc id 即流中翻面,禁)· 进入 running(args 完整)后才渲 `/`(缺席/null=根)
  或 parentId;catalog 该工具 target(state) 契约注释明写 · 回执=searchReceipt(listKey
  `documents`):`N 项` / 空→`空`(emptyList,列举声道不说「无匹配」)。
- **活期**:settle-only;chip 待 args 完整(见收起行),余同族。
- **落定体**:ToolHitList(**不重排,保 sibling 序**——position 即语义):行 = doc 字形 + name +
  次行 `path`(faint mono)+ 尾 `#position`(faint tabular)。封顶 30 + footer「+N 更多 · 共 M」。
- **退化态**:空目录→回执即卡;description omitempty→无第三槽(v1 次行只放 path,description 省)。
- **交互**:行 tap intent=`{kind:document,id}`,可点性经文法 #8 注册表判定。
- **新原语**:无新增。
- **Wow**:AI 在树里走一层,用户看到的是**带序号的目录页**——move_document 的 position 语义
  在这里有了可视锚。
- **可行性**:census 06 单形状 JSON;一层子级全量无分页 → 封顶必须;<5KB 典型。

### `list_attachments` — 正在列附件 → 已列附件
- **收起行**:📎(补精确表 `list_attachments→attachment 形`,无则 doc;现关键字兜底=扳手,必须补)·
  动词 · **无 chip**(零 args,动词自足)· 回执:`N 个文件` / 空→`空`。
- **活期**:settle-only;无 chip 无 liveBody——shimmer 动词即全部。
- **落定体**:ToolHitList 文件行变奏:行 = kind 图标(**复用 AnAttachmentCard 的 kind→图标映射**,
  image/document/text/audio/video/other)+ filename(15 w400,值档同族)+ 尾 meta
  `mime · 人话大小 · 日期`(faint;sizeBytes → KB/MB 格式化归 feature,附件卡同款推导)。
  新→旧序保持;封顶 30 + footer。
- **退化态**:空→回执即卡;未知 kind → other 图标(线缆枚举封闭但防御);无截断风险(slim 行)。
- **交互**:**行不可点**(附件无实体面板;它是对话资产)——v1 惰性,右岛 touchpoint 落地后再议。
- **新原语**:**attachmentKindGlyph 抽表**(从 AnAttachmentCard 抽 kind→图标查表供 ToolHitRow
  文件行复用——与 entityKindGlyph 同性质的真实重构,入族级汇总表,绝不重画第二套)。
- **Wow**:与 composer 附件 chip / 消息附件卡**同一套图标语言**——AI 清点文件时,用户看到的
  就是自己上传过的那些东西,零翻译成本。
- **可行性**:census 06 单形状、无分页全量;`createdAt` UTC 秒级好格式化;最安全的一张卡。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| **ToolHitList / ToolHitRow** | feature(tool_card_skins 旁) | 住 ToolWindow 的结构化命中列表:行=字形+主文(15 值档)+次行(13 标签档)+尾 meta 槽(builder),AnInteractive hover/tap(onTap null=惰性),settle 后首次展开 30ms 级联点亮(transitionObserved && !hasAnimated 两级判定;其余挂载/reducedOrAssistive 即时),封顶 N 行+双态 footer(本地超封顶逃生口 / 服务端截断 display-only 注记) |
| **searchReceipt** | feature(tool_receipts.dart) | 双形状容忍的计数回执纯函数:JSON `{count,total?,<listKey>}` + 已知软字符串 → `N 个`/`N·共M`/`无匹配`;解析不中恒 null(绝不猜) |
| **entityKindGlyph 共享查表** | core 微改 | 把 AnRefPill 内的 kind→字形映射抽成可导出查表,ToolHitRow 复用同一套实体字形(不画第二套) |
| **attachmentKindGlyph 抽表** | core/feature 微改 | 把 AnAttachmentCard 内的 kind→图标映射(image/document/text/audio/video/other)抽成共享查表,ToolHitRow 文件行复用(与 entityKindGlyph 同性质,不画第二套) |
| **verb 双声道缝** | 底盘微调 | `ToolCardSpec.verb` 可读 state(可选参、向后兼容),空 query 切列举声道 |
| **AnIcons.toolIcon 补表** | core 两行 | `list_documents→doc`、`list_attachments→附件形(缺则 doc)`——后者现兜底扳手,语义错 |

新增 i18n 键见族级文法 #9。**不新建**:图标(全复用)、窗(ToolWindow 原样)、动效(AnMotion 现有档)。

## 族内建造顺序建议

1. **searchReceipt + i18n 键**(纯函数先行;五电池单测:空/双形状/软串/畸形 JSON/超大 count)。
2. **entityKindGlyph 抽表 + ToolHitList/ToolHitRow 进 gallery**(specimen:实体行/徽章尾行/
   ref 尾行/文件行/空态/双态 footer[本地超封顶逃生口·服务端截断注记]/级联点亮**两态验收**
   [settle 后首次展开播、二次展开不播] + reduced 即时;与 AnKv 体并排验字阶)。
3. **6 实体 search 编目**(catalog 共享 `_entitySearch` helper 一次出六张)+ verb 双声道缝。
4. **search_workflow / search_triggers 的 fallback 尾槽**(trailing builder 首两个消费者)。
5. **search_documents / search_blocks**(双 hit 形状适配 + kinds 药丸 + ref 尾 + 软串回执)。
6. **list_documents / list_attachments**(列举声道 + 文件行变奏 + toolIcon 补表 +
   **attachmentKindGlyph 抽表**——与 toolIcon 补表同批做,防漏成第二套手画图标)。
7. **widget-test 矩阵**(空/超长 snippet/海量行封顶/双形状注入/软串注入)入 fe-verify;
   真后端亲跑截图验(空 query 列全部、engine 截断、blocks kinds 过滤三景)。


---

# F08 exec 族完美态 — run_function / call_handler / invoke_agent / trigger_workflow / fire_trigger / replay_flowrun(6)

> 定位(WRK-053 §4):执行族 = 输入→黑箱→输出。卡的使命是把"跑了一次"变成**可核账的凭据**:
> 喂了什么、吐了什么、花了多久、留在哪张台账、坏在哪一步。

## 族级统一文法

1. **对陈体(输入/输出上下陈列)**:落定体的骨架恒为 `[意图行] → 输入节 → (过程节) → 输出节 → 执行结果条`。
   输入/输出各是一节 `ToolIOSection`:13 号灰标签(「输入」/「输出」)+ 机器窗内容。**值渲染是显式规则、
   绝非内容嗅探**(硬规则,不留给建造者临场判断):
   - 标量内联 mono;长文本 mono 封顶 6000 chars + 诚实截断注记;JSON ≤14 行整段内联;
   - **对象仅单键、或全键皆字符串型 → 逐键陈列**:13 灰键名标签 + 该键值按长文本规则渲染——
     **禁投 `AnJsonTree`**(树单值 500 chars 封顶、换行呈转义串,会截碎单声明 outputs 的
     `{name: 长文本}` 终答);`AnJsonTree`@`AnSize.jsonViewport`(240 有界)只留给**真嵌套结构**
     (含 object/array 键);
   - **prose 排版(`ToolWindow(inset: AnInset.bubble)` 内走 `AnMarkdown`)只在工具 spec 显式置
     `ToolIOSection(renderAsProse: true)` 的槽位生效**——本族仅 invoke_agent 的 string 终答与其
     单键/全字符串键 prose 输出置位;**默认一切字符串走 mono 封顶,严禁按内容嗅探**(function 返回的
     日志/报告串常含 #、``` 、* 等记号,嗅探会把机器字符串误排版成标题/围栏,违诚实铁律;
     ToolIOSection 反哺 generic 体时此默认随行)。
2. **执行结果条 `RunStatBar`**(**由 builds 的 `_BuildResultBar` 抽取升格、非并行新建第二套**——
   原则 8 强化地基:抽成状态词/耗时/计数/凭据 pill 四槽共享件,builds 侧**同提交**迁移消费,
   仓库只留一条结果条实现,否则两条必然漂移):状态词(语义色)· 耗时(`fmtElapsed`:
   430ms/1.2s)· 计数(步数/tokens/节点数,13 tabular)· **凭据 pill**(executionId/flowrunId/activationId
   → `AnRefPill`,深链语义见 §4 执行凭据 intent)。半成功/结果内失败(`ok:false`、flowrun.status=failed、
   running+parked 节点[park 是**节点**态,run 头枚举无 parked])必须在这条上显性。
3. **诚实双层失败**:tool error(sentinel 冒泡)走底盘 failed 相位;**结果内失败**(`ok:false` +
   `errorMsg`、flowrun.status=failed)由本族回执解析器识别 → 危险色回执 + 自动展开一次,errorMsg 红 mono
   进输出节。两层绝不混淆。
4. **凭据即深链(执行凭据 intent)**:执行 id(agexec_/fr_/act_)**不是** entities rail 实体——
   `AnRefPill` 现约只派 `{kind,id}`(kind=EntityKind 线缆值),光凭它打不开「agent 详情+run 终端」或
   「trigger 详情 activations tab」。故本族统一定义**执行凭据 intent**:
   `{kind: <宿主实体>, id: <宿主id>, focus: {execution|flowrun|activation: <执行id>}}`——
   宿主 id 由 spec 层从 args/输出组装(agentId/workflowId/triggerId 都在手);`AnRefPill` 仅作视觉件
   (kind 字形 + 截断执行 id),onTap 回调由卡注入、派上述 intent → entities 海洋宿主实体 + 焦点定位
   (run 终端 / activations tab)。输出**没有** id 的(run_function/call_handler),诚实降级为
   「查看执行历史」链到实体详情的 executions/calls tab(id 从 args 取)。
5. **危险姿态**:全族执行真实代码/启动真实运行——LLM 自报 danger;awaitingConfirm 相位下展开体
   置顶 `_intent` 意图行 + 输入节(用户批之前先看清**要跑什么**)。replay_flowrun 恒 cautious 倾向。
6. **logs/过程折叠**:print 日志、流式 yields 装 `AnDisclosure`(「日志 · N 行」)→ 机器窗;
   `AnFadeCollapse` 用于超长时须显式传 `fadeColor: surfaceSunken`。
7. **动词 i18n 键**:`chat.tool.exec.*`(runningFn/ranFn/callingMethod/calledMethod/invokingAgent/
   invokedAgent/triggeringWf/triggeredWf/firingTrigger/firedTrigger/replayingRun/replayedRun)。

---

### `run_function` — 正在运行函数 → 已运行函数

- **收起行**:icon `action` · 动词 · chip = `functionId`(args;若 `version` 给出则 `fn_… @v3`)· 回执:
  解析 ExecutionResult——`ok:true` → `1.2s`;`ok:false` → 危险色「运行失败 · 1.2s」+ 自动展开;解析不匹配→无回执。
- **活期**:⚠️ **settle-only**(线缆真相:run 不推 progress,嘱托中的"活日志窗"今天无数据源)。
  活期 = 流光动词 + 读秒;`args-partial` 可用:argsStreaming 期 liveBody 显**输入正在成形**——
  **原始 args JSON 文本的 mono 尾窗**(raw substring:流入期 JSON 半截、键序不可控,不按字段提取,
  原文尾窗天然容忍截断;输入即"将要发生的事",诚实且有生长感),执行期窗定格为完整输入
  (settled 后才按字段陈列进输入节)。
- **落定体**:意图行 → 输入节(`args.args` KV/JSON 树)→ 「日志」AnDisclosure(`logs` 字段,mono 窗封顶;
  无 logs 不渲)→ 输出节(`output` 智能渲染,可大,封顶+逃生)→ RunStatBar:`ok/失败` · elapsedMs ·
  「查看执行历史」→ function 详情 executions tab(输出**不含** executionId,不硬造 pill)。
- **退化态**:output=null 且 ok → 「无返回值」灰注;logs 缺席不渲节;FUNCTION_ENV_NOT_READY 等 sentinel
  → 底盘 failed 相位(错误码 + message);FUNCTION_RUN_TIMEOUT → failed + 回执「超时」。
- **交互**:functionId chip 可点(实体深链);输出节复制(逃生口:查看全文)。
- **新原语**:`ToolIOSection` + `RunStatBar`(族共享,首建于此)。
- **Wow**:批之前输入在窗里成形、落定后输入/输出对陈如账目——一次运行读起来像一张干净的凭证,不是日志汤。
- **可行性**:args 流入顺序不可控(functionId 可能晚于 args 到)——chip 容忍 null;output/logs 均可数十 KB,
  两级封顶硬性;**活期窗不做流式 JSON 字段提取**(按字段成形须 lenient 流式解析器——若将来引入,复用
  builds 侧那只并声明失败回退=显整段 raw;本期一律 raw 尾窗);**将来增强**:后端给 run 路径接 progress
  emitter(print 实时流)即可点亮活日志窗,前端缝已留(liveBody 换 ToolLiveTail 一行事)。

### `call_handler` — 正在调用方法 → 已调用方法

- **收起行**:icon `handler` · 动词 · chip = `method`(主角;handlerId 进体内——行上双 id 太重)· 回执:
  result 为标量 → 值预览 `→ true` / `→ "ok"`(截断 24 chars,小结果回执即卡);object/array → `→ {…}`;
  解析失败无回执。
- **活期**:流式 method 有真 progress(每个 yield 一行)→ **liveBody = ToolLiveTail**(Bash 同款族魂,
  尾 3 行小终端);非流式 method 同 run_function 的输入成形窗。数据源:`progress 流` + `args-partial`。
- **落定体**:意图行 → 输入节(`method` 13 标签 + `args` JSON)→ 「流式输出 · N 行」AnDisclosure
  (progressText 完整窗;仅流式 method 有)→ 输出节(`result` 智能渲染)→ RunStatBar:`ok` ·
  「查看调用历史」→ handler 详情 calls tab(输出仅 `{result}`,无 callId/elapsed——不编造耗时)。
- **退化态**:result=null → 「无返回值」;HANDLER_CONFIG_INCOMPLETE / HANDLER_CRASHED / HANDLER_RPC_TIMEOUT
  → 底盘 failed,错误码原样(CONFIG_INCOMPLETE 值得追加一句灰注「先在 handler 面板补配置」)。
- **交互**:handlerId pill 深链;progress 窗与 result 窗各自封顶 + 逃生。
- **新原语**:复用 ToolLiveTail / ToolIOSection / RunStatBar;标量值预览 = 回执解析器逻辑,非组件。
- **Wow**:流式 method 的 yields 像心跳一样在行下跳动,落定后收成一条「→ 42」——过程与答案各得其所。
- **可行性**:yields 可以是 JSON 序列化行(非字符串 yield),liveTail 原样显不解析——诚实;result 可大,封顶硬性。

### `invoke_agent` — 正在运行智能体 → 已运行智能体(持久态)

- **收起行**:icon `agent` · 动词 · chip = `agentId` · 回执:InvokeResult——status=ok → `12 步 · 8.4s`;
  failed/timeout → 危险色状态词 + 自动展开;**cancelled → 中性灰「已取消」、不自动展开**
  (多为用户主动按停——七相位里中断与失败是不同相位,宪法只给失败/危险色回执自动展开,
  把用户自己的动作渲成危险并弹开是噪音)。
- **活期(本族最大的秀)**:E3 嵌套——agent 的全部流式 block(text/reasoning/tool_call…)以
  `parentBlockId=本 tool_call` 实时嵌入。liveBody = **`NestedRunPane`**:**外壳恒为 `ToolWindow`
  (凹陷机器窗)**——内部一切嵌套 block(含 reasoning)以窗内 mono 行呈现,**无左竖线 rail、无裸散文**
  (机器产物绝不借 thinking 低语语法;与 Subagent 族协调共建时此句同步写进共建规范)。窗内紧凑
  迷你 transcript(reasoning 流光行、子工具卡 mini 行、text 生长),有界视口(~5 行高滚动尾随)+
  「N 步」计数徽标。
  **活期 text 生长一律纯 Text/mono、不高亮不排版**(builds 活窗同一先例——AnMarkdown 围栏码每帧
  全量重高亮,嵌套 agent 常吐长代码块,逐 delta 走它违流动期便宜铁律);落定即收拢成摘要行,
  卡内永不出现渲染态 markdown 轨迹——排版稿只给终答输出节。
  ⚠️数据源:**messages 流嵌套 block,不在 ToolCardState 里**——需要 transcript 层把子 block 树喂进卡
  (BlockTreeReducer 已会分树,是接线活不是发明活)。接线未至前退化:流光动词 + 读秒。
- **落定体**:嵌套轨迹收拢成一行摘要「轨迹 · 12 步」(点击 = 深链 run 终端,由 transcript 重水合——
  嵌套 block 仅流不落盘,**不在卡内重放**)→ 输出节(string 终答 → `renderAsProse` AnMarkdown 排版稿;
  **单声明 outputs `{name: 长文本}` / 全字符串键对象 → 逐键「13 标签 + prose/长文本」陈列,同 string
  终答路径——绝不塞 AnJsonTree 让 500 chars 封顶截碎终答**;真嵌套结构才 JSON 树,见族规第 1 条)
  → errorMsg 红 mono(failed 时)→ RunStatBar:状态 · steps · `↑tokensIn ↓tokensOut` ·
  elapsedMs · **executionId pill**(执行凭据 intent:`{kind:agent, id:args.agentId,
  focus.execution:executionId}` → agent 详情 + 右岛 run 终端;本族唯一自带持久 id 的执行工具)。
- **退化态**:output 缺席(failed 早夭)→ 只渲 errorMsg;timeout → 状态词「超时」+ 灰注「可 replay」;
  AGENT_OUTPUT_NOT_STRUCTURED → failed + 错误码。
- **交互**:executionId pill 深链(强链选区,agent 详情 + run 终端);输出复制。
- **新原语**:**`NestedRunPane`**(嵌套子运行迷你 transcript;与 Subagent 卡同构——两族共用,协调建)。
- **Wow**:一个 agent 在你的对话里真实地思考、调工具、写答案,整个生命过程内嵌在一张卡下面生长,
  完成后优雅地折成一行凭据。
- **可行性**:嵌套 block 是 ephemeral(仅流)——reload 后卡内轨迹消失是**设计**而非缺陷(耐久真相 =
  Execution.Transcript,深链去看);有界视口铁律(transcript 行绝不背无界滚动);token 数字须 tabular 对齐。

### `trigger_workflow` — 正在触发工作流 → 已触发工作流(持久态)

- **收起行**:icon `workflow` · 动词 · chip = `workflowId` · 回执 = `fr_a1b2…`(flowrunId 截断)。
  永不危险色——**工具只负责点火**,返回即成功;run 的死活是另一张台账。
- **活期**:近即时落定(异步启动,返回只有两个 id)。argsStreaming 期**原始 args JSON 文本尾窗**
  (raw substring,同 run_function——不按字段流式解析 payload);执行期几乎不可见。
- **落定体**:意图行 → 输入节(`payload`;空 `{}` 渲「空 payload」灰注,不装空树)→ **启动凭据行**:
  flowrunId `AnRefPill`(执行凭据 intent:`{kind:workflow, id:workflowId, focus.flowrun:flowrunId}`)
  + 「在运行台打开」→ **`FlowrunSnapshotPane`(野心层,fetch-on-expand)**:用户展开时**先 get flowrun
  拿 `flowrun.versionId`,再按该 versionId 取版本图 graphParsed**(flowrun pin 了版本——按 workflowId
  取的是 active 图,触发后 workflow 被编辑过会把 run 态套在错版本的图上、节点增删错位;repository 缝
  须支持按版本取图,非只 active)→ 静态只读图 + `deriveRunState` 渲**时点快照**:completed 实、
  running 呼吸、failed 红、future 虚——右上角「刷新」+ 快照时间戳(「摄于 12:03:41」,诚实声明非直播)。
- **退化态**:FLOWRUN_INVALID_ENTRY / WORKFLOW_NO_ACTIVE_VERSION → 底盘 failed + 错误码;快照取数失败
  → pane 内灰注「快照不可用」+ 深链仍在,绝不空白。
- **交互**:flowrunId pill = 深链 run 终端(那里才有活图直播);快照可刷新。
- **新原语**:**`FlowrunSnapshotPane`**(取数型展开面:凭 id fetch 图+run 态,复用 AnGraphCanvas/
  deriveRunState;需给工具卡开一条 repository 数据缝——本族唯一越出"卡=块状态纯函数"边界的组件)。
- **Wow**:触发之后一展开,整张工作流图带着运行温度出现在对话里——哪个节点已过、哪个正烧,一眼收账。
- **将来增强(明确列入,不在本期)**:快照 pane 接 entities 流 flowrun tick → 节点**逐个点亮的直播图**;
  跨流接线属 V8/右岛地界,卡内先做「快照 + 刷新 + 深链」三件套。
- **可行性**:工具落定时 run 才刚起步——落定即渲图会是一片 future 虚线,故 fetch-on-expand(用户展开
  时 run 已跑了一阵)+ 刷新是诚实解;framed 图 380 有界不违反滚动铁律,但**滚轮缩放是 AnGraphCanvas
  自定义 Listener(exp(-dy/666.67)缩放到光标,与 IV panEnabled 无关)**——光标悬在快照上滚动会缩放图
  而非滚聊天,且画布今天没有全静态只读 prop(内部只有拖拽期压 pan)。快照面须用**静态只读模式**:
  给 AnGraphCanvas 加 `interactive:false`(禁 IV 手势 + 禁滚轮 Listener + 禁 hover 连接柄),或走
  graph.md 路 C 建只读 `AnMiniGraph`(纯看,要玩去 run 终端);FlowrunSnapshotPane(两卡共用)按此件建。
  ⚠️**「按 versionId 取版本图 graphParsed」今天零证据**——census 的 get_workflow 只返 active 版图,
  REST 是否暴露任意版本的 graphParsed 未经核实;硬前置与降级拍板见族建造顺序第 6 步,端点核实前
  本 pane 不开工,**绝不用 active 图冒充版本图**(触发后 workflow 被编辑过 = 节点增删错位的不诚实图)。

### `fire_trigger` — 正在手动触发 → 已手动触发(薄卡)

- **收起行**:icon `trigger` · 动词 · chip = `triggerId` · 回执 = `act_a1b2…`(activationId 截断)。
- **活期**:即时返回,无活体。
- **落定体**(薄):一行凭据——activationId `AnRefPill`(执行凭据 intent:`{kind:trigger,
  id:args.triggerId, focus.activation:activationId}` → trigger 详情 activations tab)+ 固定灰注
  「payload 恒为 {manual:true};扇出与处置见触发日志」(线缆事实:无 payload 参数,fanout 数不在返回里
  ——绝不编造扇出数)。
- **退化态**:TRIGGER_NOT_FOUND → 底盘 failed。
- **交互**:activation pill 深链;trigger 面板的实时闪动走 entities fire 信号,是面板的事、非本卡。
- **新原语**:无(AnRefPill + 一行文案)。
- **Wow**:克制即完美——一次点火收成一枚可点的凭据,三秒读完。
- **可行性**:返回恒三键极小;此工具会真启动监听 workflow(危险中),awaitingConfirm 相位由底盘 + LLM 自报覆盖。

### `replay_flowrun` — 正在重放运行 → 已重放运行(cautious)

- **收起行**:icon `workflow` · 动词 · chip = `flowrunId` · 回执解析器(⚠️ FlowRun.status 枚举 =
  running|completed|failed|cancelled,**无 parked**——park 是节点态,停在审批节点的 run 头仍是 running):
  completed → `完成 · N 节点`(N 优先取 `nodeSummary.totalNodes`,缺席才数 nodes.length——截断时
  nodes.length=80 不是真数);failed → 危险色「仍失败」+ 自动展开;cancelled → 「已取消」;
  **running 且 nodes 含 parked 行 → 「等待审批」**(琥珀语义在体内,回执文本恒灰);
  running 且无 parked 行(理论边界)→ 无回执兜底。
- **活期**:同步执行、可能长(把剩余节点跑到下一终态/park)。**settle-only**(workflow 族零 progress)
  ——流光动词 + 读秒;awaitingConfirm 相位置顶意图行 + 目标 flowrunId(cautious:用原 pin 版本重跑,
  事后修的代码**不生效**——这句以灰注进确认态,是用户批前该知道的事)。
- **落定体(本族第二个秀,零 fetch)**:输出自带全部节点行!
  → **`FlowrunNodeList`**:每节点一行——kind 字形 · nodeId mono · `AnStatusDot`(completed ok /
  failed danger / parked warn)· iteration>0 缀 `×N` · failed 行下红 mono error 摘要(单行截断);
  超 80 封顶时头部诚实条:「显示 80/213 · completed 197 · failed 3」——**计数一律取 nodeSummary
  原文(totalNodes/shownNodes/byStatus),绝不数 nodes.length**
  → RunStatBar:状态词(同收起行解析器派生:running+parked 节点 → 「等待审批」琥珀入体)·
  `第 N 次重放`(replayCount)· flowrunId pill(执行凭据 intent,→ run 终端)
  → **图快照(野心层)**:同 trigger_workflow 的 FlowrunSnapshotPane(**按版本取图端点未经核实,
  硬前置与降级见建造顺序第 6 步**——所谓"零 fetch"的图形状仍需按版本取一次,悬在同一条端点上)。
  **零 fetch 路径仅限 nodeSummary 缺席时**(输出行即全量,deriveRunState 直接吃返回 nodes,
  仅图形状按 flowrun.versionId 取一次);
  **nodeSummary 在场 = 行被裁过**——被裁掉的早期 completed 行会让对应图节点渲成 future 虚线
  (完成画成没跑 = 不诚实图),此时禁用零 fetch:改走 REST `GET /flowruns/{id}` 取全量
  (与 trigger_workflow 同一 repository 缝,nodeSummary.note 明载该端点),或该情形只渲列表不渲图。
- **退化态**:FLOWRUN_NOT_REPLAYABLE(非 failed run)→ 底盘 failed + 灰注「仅 failed 运行可重放」;
  含 parked 节点(run 头仍 running)→ 节点列表琥珀行 + 「去审批」深链;nodes 空(理论上不可能)→
  「无节点记录」。
- **交互**:flowrunId pill、failed 节点行可点(→ run 终端定位该节点,将来增强);列表有界(~12 行视口
  + 展开全部逃生口)。
- **Wow**:重放归来,整场运行的生死簿直接摊在卡里——谁复活了、谁还躺着、卡在哪个审批,不用离开对话。
- **可行性**:返回同 get_flowrun 形状、受 80 节点硬封顶(F173)——列表体积有界是后端送的礼物;
  同步执行期间无任何心跳,长 run 只有读秒——诚实但寡淡,将来增强同跨流直播。

---

## 族级新原语汇总

| 原语 | 一句话能力 | 复用范围 |
|---|---|---|
| **ToolIOSection** | 13 标签 + 机器窗的输入/输出节;值显式规则渲染(标量内联 / 单键或全字符串键对象逐键陈列[禁 AnJsonTree 截碎] / 真嵌套才有界树 / 长文本封顶 / prose 仅 `renderAsProse: true` 置位槽走 AnMarkdown 于 bubble 窗,默认字符串一律 mono——**禁内容嗅探**) | 全族 6 工具;可反哺 generic 体(mono 默认随行) |
| **RunStatBar** | 执行结果条:状态语义色 · fmtElapsed · 计数(步/tokens/节点)· 凭据 AnRefPill 深链 | 全族;**抽自 builds `_BuildResultBar` 升格共享四槽件,builds 同提交迁移——仓库唯一结果条实现** |
| **NestedRunPane** | E3 嵌套子运行迷你 transcript(**外壳恒 ToolWindow 凹陷机器窗**,窗内 mono 行、无左竖线 rail 无裸散文;有界尾随视口 + 步数徽标;活期纯 Text/mono 不高亮不排版);需 transcript 层喂子 block 树 | invoke_agent + Subagent(跨族共用,窗身份写进共建规范) |
| **FlowrunNodeList** | FlowRunNode 行 → 状态点清单 + nodeSummary 封顶诚实条(计数取 nodeSummary 原文)+ failed 行红摘要 | replay_flowrun + decide_approval(F-审批族) |
| **FlowrunSnapshotPane** | fetch-on-expand 运行快照图:静态只读图(AnGraphCanvas 加 `interactive:false` 模式或建 AnMiniGraph,禁 IV 手势/滚轮 Listener/hover 连接柄)+ deriveRunState + 刷新/时间戳;取数恒先 get flowrun 拿 versionId 再按版本取图;需工具卡 repository 数据缝(含按版本取 graphParsed + REST 全量 flowrun;**版本图端点未经核实——硬前置见建造顺序 6,核实前不开工**) | trigger_workflow / replay_flowrun;将来接 flowrun tick 升级直播 |

## 族内建造顺序建议

1. **ToolIOSection + RunStatBar**(纯函数、settle-only)→ 一举点亮 run_function、call_handler
   (call_handler 活尾直接复用 ToolLiveTail)——族的账目骨架先立。**RunStatBar 不新建**:把 builds 的
   `_BuildResultBar` 抽成共享四槽件(状态词/耗时/计数/凭据 pill),builds 侧**同提交**迁移消费,
   仓库只留一条结果条实现(原则 8)。
2. **fire_trigger 薄卡**(半小时量级,顺手)。
3. **FlowrunNodeList** → replay_flowrun 落定体(零 fetch、数据有界,性价比最高的秀)——
   **回执解析器条目先改到位再动手**(running+parked 节点 → 「等待审批」,run 头无 parked)。
4. **trigger_workflow 凭据行 + 深链**(执行凭据 intent `{kind:宿主, id:宿主id, focus:{…}}` 接线;
   快照面先不做)。
5. **NestedRunPane**(最大接线量:transcript 子 block 树入卡;与 Subagent 卡设计者协调同建)。
6. **FlowrunSnapshotPane**(须先拍板"工具卡开 repository 缝"的架构问题——拍板清单三件,缺一不开工:
   ① **硬前置:先核 `references/backend/api.md` 是否真有按版本取 workflow 图(含 graphParsed)的
   GET 端点**——今天零证据(census 的 get_workflow 只返 active 版图,graph.md 三个消费面也全吃
   active graphParsed);缺则按迭代铁律②同提交加后端端点(N 系列 + 文档 1:1),或 spec 写死降级 =
   只渲 FlowrunNodeList + 深链、**绝不用 active 图冒充版本图**(版本漂移即不诚实图;replay 的
   零 fetch 路径同样悬在这条端点上);
   ② **按版本取图**[flowrun.versionId,非 active];
   ③ **AnGraphCanvas 静态只读模式**[`interactive:false` 或 AnMiniGraph];
   图快照两卡同吃)——将来增强(跨流直播、run_function 后端 progress)单列 backlog,不阻本期。


---

# F09 — run-logs 族完美态(13 工具)

> search/get × function_executions / handler_calls / agent_executions / flowruns / mcp_calls
> + search_firings / search_activations / get_activation。
> 线缆源:census 02(fn/hd §9-10、§11-12)、03(agent §9-10)、04(workflow §13-14)、07(trigger §7-9)、08(mcp §5-6)。

## 族级统一文法

**心智:档案阅览室。** 全族 13 个工具都是**只读**的执行史投影——search=台账(状态珠串 + 有界账本),get=卷宗(状态头条 + 输入/输出对陈 + 日志抽屉 + 因果链)。没有任何工具发 progress、没有 SSE-C 镜像、没有 morph——**全员 settle-only**,活期一律退化为流光动词 + 读秒(>3s),力气全花在落定体上。

1. **动词双声部**:search 族 = 「正在翻查X → 已翻查X」;get 族 = 「正在调阅X档案 → 已调阅X档案」。X 带类名词(函数运行史/调用史/执行史/扇出台账…),全 slang 双语。
2. **收起行回执的诚实语义**:档案里的 failed 是**历史**失败、不是本次调用失败——search 回执 `42 ✓ · 3 ✗` 恒灰(danger:false;✗ 的线缆语义=非 ok 总数、含取消/超时,见规 6);get 回执才把 status=failed|timeout 染 danger:true(你调一份失败档案,大概率就是来 triage 的——自动展开一次正中意图)。**空页三态**(带过滤的 search 严禁一刀切「无记录」):①**无过滤**且(无 aggregates 或 aggregates 双零)→ 回执「无记录」、无展开体(回执即卡);②**带过滤**(status/method/tool/firedOnly…)且页空 → **保留展开体**——内渲过滤回声 chips + 诚实句「无匹配(status=failed)」,回执写「无匹配 · 全史 N ✓ M ✗」(有 aggregates 时;无 aggregates 只写「无匹配」)——把「无 failed 记录」说成「无记录/从未运行」是谎言;③各工具退化态显式指向 ①/②,禁写模糊的「同族规」。
3. **尺寸纪律(本族风险全系统第一)**:线缆的 list 页每行都背全量 input/output/logs(agent 还背 transcript)——**UI 铁律:列表体只投影 slim 字段(id/status/时间/时长/方法名),input/output/logs/transcript 在 search 体内一个字不渲**。get 体内:JSON ≤14 行内联、否则 `AnJsonTree`@`AnSize.jsonViewport`(240)(沿用底盘规则);logs 走 `AnDisclosure` 抽屉 + 6000 chars 封顶——**双端保留:头 2000 + 尾 4000,中缝诚实注记「…中间省略 N chars…」**(日志最诊断性的内容[最后 yields/stderr 尾/临终输出]在尾部,取头截断=丢 triage 价值);账本 >14 行套 `AnFadeCollapse`(fadeColor 显式传 surfaceSunken);get_flowrun 靠后端 80 节点封顶 + 前端虚拟滚动双保险。**每个重体都有逃生口 deep link**(实体面板 / run cockpit / 右岛)。
4. **台账行文法**(RunLedger,新原语)——**显式槽位规范**:`leading 记号槽(AnStatusDot 状态点|AnBadge 词章|fired 记号,三选一)· 主槽(mono id 13,hover 可复制|人话文本,二选一)· chips 槽(method/tool/triggeredBy…)· trailing 槽(时长 metaTabular + 相对时间 inkFaint)· 可选展开槽(行内 AnDisclosure;任一打开 → 外层 AnFadeCollapse 自动切展开态)`。行高 28,住 ToolWindow(机器窗身份——台账是机器产物)。行首上方一条 **RunBeadStrip 状态珠串**(新→旧,每条记录一颗 6px 圆珠;**色表参数化**、由调用方传 status word→color:fn/hd/agent/mcp = ok 绿/failed 红/timeout 琥珀/cancelled 灰,flowruns 另传 running 蓝/completed 绿)——CI beads 式一眼读史。
5. **卷宗文法**(RunDossier,新原语):头条(status AnBadge + triggeredBy + elapsed + 起止时间)→ 输入/输出**对陈**(两个带 13 标签的机器窗,「输入」「输出」;失败档案的 errorMessage 换成 danger 色窗)→ 日志抽屉(AnDisclosure「日志 · N 行」)→ 底部 **ProvenanceLine 因果链**(conversation/message/flowrun/node#iteration/trigger 凭据行;**可点/不可点分界见原语汇总**——conversation/flowrun/trigger 可点,message/firing/node#iteration 为 mono 徽章 + hover 复制)。
6. **过滤回声**:search 体头部把 args 里的过滤条件回显成灰 chip(`status=failed` `method=send`)——用户不用展开 args 就知道这页台账是按什么切的。aggregates 忽略 status 过滤(线缆语义),措辞恒为「全部记录:N ✓ · M ✗(✗ 含取消/超时)」——线缆的 failedCount=非 ok 总数(census 03 §9),✗ 不注明就与珠串四色(cancelled 灰非红)在同卡语义打架;「全部记录」措辞防误读成本页统计。
7. **性能/动效**:全族体只在 settle 时 build 一次,零逐 delta 成本;唯一动件 = running 状态点的呼吸环(AnMotionPref 门控);珠串、瀑布条全静态。reduced motion 天然全等价。

---

### `search_function_executions` — 正在翻查函数运行史 → 已翻查函数运行史

- **收起行**:function icon · 动词 · chip=`args.functionId`(mono 原样,fn_ id 短)· 回执=解析 `aggregates`:`{ok} ✓ · {failed} ✗`(恒灰);空页按族规 2 三态(无过滤且 aggregates 双零→「无记录」;带过滤→「无匹配 · 全史 N ✓ M ✗」)。
- **活期**:`settle-only` —— 流光动词 + 读秒,无活窗。
- **落定体**:过滤回声 chips(status/versionId)→ RunBeadStrip(本页,新→旧)→ ToolWindow 内 RunLedger:状态点 · `exec id` · `triggeredBy` chip · flowrun 来源微标(有 flowrunId 的行)· 右贴 `elapsedMs` · 相对时间。>14 行套 AnFadeCollapse;`hasMore` → 底部诚实行「还有更多 — 在函数面板查看完整历史」。**行内绝不渲 input/output/logs**(线缆带、UI 丢弃)。
- **退化态**:空页=族规 2 ①(无过滤双零→回执即卡)/ ②(带 status/versionId 过滤→保留展开体:过滤回声 chips + 诚实句「无匹配」);result 非 JSON → 通用封顶 mono 窗、无回执;非法 status 过滤是工具错误(`FUNCTION_EXECUTION_INVALID_STATUS`)→ 底盘失败态。
- **交互**:行点击 → 实体面板该函数的执行历史(带 exec id 锚);id hover 复制;functionId chip → 实体面板。
- **新原语**:RunBeadStrip + RunLedger(全族共享,见汇总)。
- **Wow**:珠串让「这函数最近稳不稳」变成 0.3 秒的视觉判断——不用读一个数字。
- **可行性**:aggregates/executions/hasMore 均 settle 后一次解析;页大(全量 input/output 随行)——解析成本一次性,投影后即弃引用。

### `get_function_execution` — 正在调阅运行档案 → 已调阅运行档案

- **收起行**:function icon · 动词 · chip=`args.executionId` · 回执=`{status} · {elapsed 人话}`(如 `ok · 1.2s`);failed|timeout → danger:true **自动展开**(调失败档案=来 triage,正中意图)。
- **活期**:`settle-only`。
- **落定体**:RunDossier 全款——头条(status 徽章 + triggeredBy + elapsed + startedAt→endedAt)→ 「输入」窗(args JSON,≤14 行内联 / AnJsonTree@240)→ 「输出」窗(ok)或 errorMessage danger 窗(failed)→ 「日志」抽屉(print 输出,6000 封顶+截断注记)→ ProvenanceLine(conversationId·flowrunId 可点;messageId·nodeId#iteration mono 徽章不可点)。versionId 以 mono 微标进头条。
- **退化态**:output 空(函数返 null)→ 输出窗诚实「(无输出)」;logs 缺席 → 无抽屉;JSON 解析失败 → 通用窗。
- **交互**:因果链按 ProvenanceLine 分界——conversation → chat 海洋、flowrun → run cockpit 可点;message/node#iteration 不可点(mono 徽章 + hover 复制 id);id 复制。
- **新原语**:RunDossier + ProvenanceLine(共享)。
- **Wow**:一份档案 = 一页卷宗:输入怎么进、输出怎么出、当时打印了什么、**是谁在什么因果里触发的**——四问一屏答完。
- **可行性**:全字段 settle 后可得;output/logs 可大 → 双封顶(视口+字符)必须落实。

### `search_handler_calls` — 正在翻查调用史 → 已翻查调用史

- **收起行**:handler icon · 动词 · chip=`args.handlerId` · 回执=aggregates `{ok} ✓ · {failed} ✗`;空 → 「无记录」。
- **活期**:`settle-only`。
- **落定体**:同 fn 的台账文法,**多一列 `method`**(mono,主 id 之后)——handler 台账的灵魂是「哪个方法被叫」;过滤回声含 method/status。instanceId 有则以 inkFaint 微标缀行尾(实例代际线索:重启前后 instanceId 不同)。
- **退化态**:空页按族规 2 三态(带 method/status 过滤空 → 「无匹配 · 全史 N ✓ M ✗」+ 展开体过滤回声);余同 fn。
- **交互**:行 → 实体面板 handler 调用历史;method 切片一目了然靠头部过滤回声 chips(**不做 method chip 点击高亮**——台账槽位无此有状态能力,堆料删除)。
- **新原语**:复用 RunLedger(method 列即 chips 槽)。
- **Wow**:instanceId 微标让「重启抹了内存态」在台账上肉眼可辨(微标已足够表达代际,**不做珠串色阶轻变**)。
- **可行性**:Call 行含 method/instanceId,直接投影;行内 input/output/logs 照丢。

### `get_handler_call` — 正在调阅调用档案 → 已调阅调用档案

- **收起行**:handler icon · 动词 · chip=`args.callId` · 回执=`{status} · {elapsed}`;failed|timeout → danger 自动展开。
- **活期**:`settle-only`。
- **落定体**:RunDossier,头条多 `method` 徽章(`send()` mono);「日志」抽屉的说明文案点明内容=该次调用的 **yields + print/stderr**(流式 method 的中间产物在这里,不在输出窗);封顶严格走族规 3 双端保留——**最后几个 yields/临终 stderr 在尾部,是 triage 核心凭据,绝不被头截断吃掉**。其余同 get_function_execution。
- **退化态**:同族规;output 是任意 JSON(method 返回值)→ JSON 树兜底。
- **交互**:同族规;handlerId 头条药丸 → 实体面板。
- **新原语**:复用 RunDossier。
- **Wow**:流式 method 的一生(逐个 yield)在日志抽屉里按行重放——档案版的「活终端尾巴」。
- **可行性**:logs 已由后端 adapter 限长,前端 6000 封顶再兜一层。

### `search_agent_executions` — 正在翻查 agent 执行史 → 已翻查 agent 执行史

- **收起行**:agent icon · 动词 · chip=`args.agentId ?? conversationId ?? flowrunId`(全缺 → 无 chip,动词自足=「全 workspace」)· 回执=aggregates `{ok} ✓ · {failed} ✗`。
- **活期**:`settle-only`。
- **落定体**:台账文法;次要 chip=triggeredBy(chat|workflow|manual);status=timeout 行珠串琥珀。**⚠️ 线缆姊妹雷:list 行带全量 `transcript`**(census 03 §9 明示未瘦身)——投影时第一个丢它。过滤回声含 triggeredBy/conversationId/flowrunId。
- **退化态**:空页按族规 2 三态(带 status/triggeredBy/conversationId/flowrunId 过滤空 → 「无匹配 · 全史 N ✓ M ✗」+ 展开体过滤回声);非法 status → `AGENT_EXECUTION_INVALID_STATUS` 底盘失败态(Details 带合法集,错误体可示)。
- **交互**:行 → 实体面板 agent 执行历史;agentId chip → 实体面板。
- **新原语**:复用 RunLedger/RunBeadStrip。
- **Wow**:跨 agent 全景模式(无 agentId)时台账首列换成 agent id 药丸——一张表看清「今天谁在替我干活、谁在翻车」。
- **可行性**:agentId 可选是本族唯一「无必填目标」的 search——target 函数必须容忍全缺;transcript 随页进来,解析后立即丢引用防内存峰值滞留。

### `get_agent_execution` — 正在调阅执行档案 → 已调阅执行档案

- **收起行**:agent icon · 动词 · chip=`args.executionId` · 回执=`{status} · {elapsed}`;failed|timeout → danger 自动展开。
- **活期**:`settle-only`。
- **落定体**:RunDossier 头条(+modelId/provider 微标,有则显)→ 输入/输出对陈 → **轨迹速览 TranscriptPeek**(新原语):settled transcript 经**水合适配器**喂 `BlockTreeReducer`(reducer 消费实时帧,settled 块数组须先水合成帧序——非零集成成本,列建造顺序第 5 步前置工件),渲成有界步骤列——每 block 一行(型别字形 + 首行摘要 + tool_call 行带工具名 mono),嵌套 subagent 按 parentBlockId 缩进;**封顶 30 块,选块锚定意图:failed/timeout 档案取首 5 + 末 25(翻车现场在轨迹末端,中缝渲「…省略 N 块」诚实行)、ok 档案取头 30;+「还有 N 块 — 在右岛打开完整轨迹」逃生口**。→ ProvenanceLine。
- **退化态**:transcript 缺席/解析失败 → 速览槽整个不渲(诚实缺席,不给空壳);输出未结构化失败(`AGENT_OUTPUT_NOT_STRUCTURED` 的档案)→ errorMessage danger 窗。
- **交互**:「打开完整轨迹」→ 实体面板右岛 run 终端(现成 BlockTreeReducer 渲染面);因果链按 ProvenanceLine 分界可点。
- **新原语**:TranscriptPeek(见汇总)。
- **Wow**:一次 agent run 的 ReAct 全轨迹在卡内变成 30 行目录——像翻一本书的目录页,细读再去右岛。
- **可行性**:transcript 是全族单条最大 payload(数十 KB~更大);Peek 只做首行投影、绝不整块渲 markdown;30 块封顶是硬线;水合适配器与 invoke_agent 卡 reload 水合共用一份(census 03 §8:耐久记录=Execution.Transcript,前端本就要重水合)。

### `search_flowruns` — 正在翻查 workflow 运行 → 已翻查 workflow 运行

- **收起行**:workflow icon · 动词 · chip=`args.workflowId`(缺 → 无 chip=全 workspace)· 回执=`{runs.length} 条`(hasMore → `N+ 条`;**无 aggregates,不编造 ✓/✗ 汇总**)。
- **活期**:`settle-only`。
- **落定体**:珠串(**标注「本页」**——无全局 aggregates,页内统计不冒充全史)→ 台账:状态点(running=呼吸环)· `fr_ id` · workflow 药丸(全景模式)· `replayCount>0` → 「重放 ×N」微章 · failed 行缀 error 首行(inkFaint,截 1 行)· 右贴 startedAt→completedAt 时长。头部一条常驻 caption:「park 在审批的 run 头仍是 running——待审批请看审批收件箱」(线缆语义防误读,census 04 §14)。
- **退化态**:空页按族规 2 三态(无 aggregates:无过滤→「无记录」,带 workflowId/status 过滤→「无匹配」+ 展开体过滤回声——「无 failed run」≠「从未运行」);非法 status → `FLOWRUN_INVALID_STATUS` 底盘失败态。
- **交互**:行 → 该 run 的 cockpit(workflow 面板 run 页签);workflowId chip → 实体面板。
- **新原语**:复用 RunLedger(error 首行=行的第三槽变体)。
- **Wow**:replay ×N 微章 + 失败首行让「哪次 run 值得点进去」在台账层就有答案。
- **可行性**:run 头行是全族最瘦的 list(无 input/output)——唯一可以放心全渲的 search。

### `get_flowrun` — 正在调阅运行全档 → 已调阅运行全档(族别嘱托:解剖图)

- **收起行**:workflow icon · 动词 · chip=`args.flowrunId` · 回执=`{status} · {shownNodes}/{totalNodes} 节点`(无 nodeSummary → `{nodes.length} 节点`;capped → `80/2000`);failed → danger 自动展开。
- **活期**:`settle-only`(run 本身可能还在跑,但**本工具**是一次快照读——头条 running 状态点呼吸提示「这是快照,run 还在推进」)。
- **落定体(解剖图)**:
  1. **run 头条**:status 徽章 · workflow 药丸 · 「重放 ×N」· elapsed(startedAt→completedAt|快照时刻)· run 级 error danger 窗(有则显);
  2. **节点状态汇总条**:byStatus 计数(completed 绿 · failed 红 · parked 琥珀)——来自 nodeSummary,缺席则前端从 nodes 派生(标「本页派生」);
  3. **RunWaterfall 节点瀑布**(新原语,核心):有界视口(~360px)+ `ListView.builder` 虚拟滚动;每条节点记录一行:状态点 · `nodeId`(mono)· kind 字形(trigger/action/agent/control/approval 五形,复用 GraphColors 色族)· iteration>0 → `#N` 后缀 · **时间轴记号**——以 run 的 startedAt→completedAt|快照刻为横轴,**默认每节点画一颗「落账时刻」事件点**(状态色 dot,createdAt 定位),**不画时长棒**:节点无 startedAt、status 封闭集无 running 态(census 04 §13),record-once 下节点行大概率落定时一次写入(createdAt≈completedAt → 棒宽趋零;且同图混义——approval 棒=等待时长、action 棒≈零);仅对 createdAt→completedAt 存在真时长的行(如 approval:park 时建行、decide 时完成)加画状态色棒;**parked 行显式定义**:createdAt 起虚线延伸至快照刻 + 「等待中」注记(语义=已等待时长,非执行时长);**failed/parked 行排最前**(线缆本就把非 completed 全保留,triage 优先),failed 行可展开(AnDisclosure)看该节点 error + result 摘要(JSON 树@240);parked 行缀「等待决策」琥珀章;
  4. **封顶诚实条**:nodeSummary 在场 → AnCallout(info):「共 2000 节点,显示 80(全部失败/park + 最近完成尾)——完整解剖在 run cockpit」+ 跳转动作;
  5. **钉住版本抽屉**:AnDisclosure「钉住版本 · N」→ AnKv(entityId→versionId mono 行)——「replay 用原版本重跑」的物理凭据;
  6. ProvenanceLine(有则入链——这次 run 是哪次 fire 生的;triggerId 真实体药丸可点,firingId mono 徽章不可点)。
- **退化态**:nodes 空(刚起步的 running run)→ 瀑布槽换诚实句「节点结果按 record-once 落账——进行中的节点尚未成档」;result 巨大节点 → 行内只给摘要行,展开才建 JSON 树;时间轴=落账时序(节点无 startedAt,census 04 §13),事件点标注「按落账时刻」防误读成物理并发图。
- **交互**:「打开 run cockpit」主逃生口(真图上看这次 run,活图已有 deriveRunState);workflow 药丸 → 实体面板;失败节点展开内 ref 可点(fn_/ag_ → 实体面板)。
- **新原语**:RunWaterfall(见汇总)。
- **Wow**:**一次 run 的解剖图**——失败和 park 浮在最上、每个节点一颗落账刻度点(真时长行才有棒)、循环迭代 #N 排队可见;2000 节点的长循环 run 也只是一屏有界瀑布 + 一条诚实计数。
- **可行性**:后端 80 封顶(F173)是第一道闸,前端虚拟滚动是第二道;**不画图形 DAG**——工具结果没有边(edges 在 workflow 版本里,跨请求取图违反卡自包含),瀑布是纯 wire 可导出的最大信息形态;真 DAG 交给 cockpit 逃生口。

### `search_mcp_calls` — 正在翻查 MCP 调用史 → 已翻查 MCP 调用史

- **收起行**:plug icon · 动词 · chip=`args.serverId` · 回执=aggregates `{ok} ✓ · {failed} ✗`。
- **活期**:`settle-only`。
- **落定体**:台账文法;次要 chip=`tool`(mono,server 内工具名)——MCP 台账灵魂是「哪个工具被叫」;过滤回声 tool/status;行内 input/output/logs 照丢(census 08 §5:一页 50 条全量未瘦身)。
- **退化态**:空页按族规 2 三态(带 tool/status 过滤空 → 「无匹配 · 全史 N ✓ M ✗」+ 展开体过滤回声);非法 status → `MCP_CALL_INVALID_STATUS` 底盘失败态。
- **交互**:行 → get_mcp_call 心智(实体面板 MCP server 调用历史锚);serverId chip → 实体面板。
- **新原语**:复用 RunLedger。
- **Wow**:tool 列 + 珠串一起读 =「这个 server 哪个工具在拖后腿」一眼定位。
- **可行性**:与 fn/hd 台账同构,零新逻辑。

### `get_mcp_call` — 正在调阅 MCP 调用档案 → 已调阅 MCP 调用档案

- **收起行**:plug icon · 动词 · chip=`args.callId` · 回执=`{status} · {elapsed}`;failed|timeout → danger 自动展开。
- **活期**:`settle-only`。
- **落定体**:RunDossier,头条多 `tool` 徽章;「日志」抽屉说明=progress 通知留痕(64KB 半头半尾 cap 是**后端**语义,截断处后端自带记号);**前端封顶先切段、再分配预算**:先按后端分隔行 `--- server stderr tail…---` 切段,**stderr 段独立预算、整段保留**(后端本就 ≤8KB 有界),主日志段走族规 3 双端保留(头 2000+尾 4000+中缝注记)——stderr 段追加在日志**末尾**,按头截断会把分隔行和 stderr 段永远吃掉、招牌功能自灭;stderr 段染 danger 色调(机器窗内两段式),**段头保留后端原告诫「server 级尾巴,可能早于本次调用」**(slang 化但语义不减——丢掉它=把 server 级旧 stderr 说成本次调用的,违诚实铁律)。output 无后端截断 → 前端封顶必须硬。
- **退化态**:output 是任意文本/JSON → 先试 JSON 树、退纯 mono 窗;input 缺席(omitempty)→ 输入窗「(无入参)」。
- **交互**:因果链药丸;serverId → 实体面板。
- **新原语**:复用 RunDossier(stderr 分段是 dossier 日志槽的小变体)。
- **Wow**:stderr 尾分段染色——「工具报错」与「server 临终遗言」在同一窗里泾渭分明,triage 不用肉眼找分隔行。
- **可行性**:分隔行是后端固定字符串,解析确定;找不到分隔行 → 整段按普通日志渲(诚实回退)。

### `search_firings` — 正在翻查扇出台账 → 已翻查扇出台账

- **收起行**:trigger icon · 动词 · chip=`args.triggerId` · 回执=`{count} 条`(nextCursor → `N+ 条`)。
- **活期**:`settle-only`。
- **落定体**:**处置台账**——回答「fire 了为什么没跑」:头部按 status 五分计数(started 绿 · pending 琥珀 · skipped/superseded 灰 · shed 红,标「本页」)→ 台账行:处置词章(AnBadge,五色语义)· workflow 药丸 · started 行缀 `flowrunId` 药丸(可点进 cockpit)· dedupKey(inkFaint mono,hover 全显)· 相对时间。skipped/superseded 行的词章 hover 提示 overlap 策略语义(skip=串行政策跳过 / superseded=buffer_one 被顶替)。
- **退化态**:空页按族规 2 三态(带 status 过滤空 → 「无匹配」+ 展开体过滤回声;无 aggregates 不编造全史计数);全 pending 页 → caption「等 scheduler 领取」。
- **交互**:flowrunId → run cockpit;workflowId → 实体面板;triggerId chip → 实体面板。
- **新原语**:复用 RunLedger(词章即状态槽变体)。
- **Wow**:五色处置词章把 overlap 策略的暗箱(skip/supersede/shed)翻译成一眼可读的台账——「fire 了但没跑」第一次有了脸。
- **可行性**:Firing 行瘦(payload omitempty 丢弃不渲);status 封闭 5 值,词章表穷尽。

### `search_activations` — 正在翻查触发动作日志 → 已翻查触发动作日志

- **收起行**:trigger icon · 动词 · chip=`args.triggerId` · 回执=`{count} 条`(nextCursor → `N+`);`firedOnly=true` 时回执缀 `· 仅 fire`。
- **活期**:`settle-only`。
- **落定体**:「为什么没 fire」台账——行:fire 记号(实心绿珠=fired / 空心灰环=未 fire / 红=error)· `detail` 人话(「condition evaluated false」,主文案位)· fired 行缀 `扇出 ×{firingCount}` · 相对时间;行 chevron 展开(AnDisclosure)→ `returnValue` JSON 树@240(sensor 探测原值,**未 fire 也留**——这就是答案)+ `payload` 窗(fire 出去的物)。**returnValue 可很大**(census 07 §7)——绝不在行内渲,展开才建树。
- **退化态**:空页按族规 2 三态(firedOnly=true 过滤空 → 「无匹配 · 仅 fire」,非「无记录」);returnValue/payload/detail 全缺 → 行只剩记号+时间(cron/webhook 的动作日志本就薄)。
- **交互**:fired 行可跳 search_firings 心智(实体面板 trigger 扇出页);triggerId chip → 实体面板。
- **新原语**:复用 RunLedger(leading=fired 记号、主槽=detail 人话——族规 4 槽位规范显式支持的两个变体;行内 AnDisclosure 展开槽与 get_flowrun 失败节点行同款)。
- **Wow**:「sensor 明明探了为什么没 fire」——展开一行,条件为假时刻的真实返回值就躺在那,零猜测。
- **交互补充**:每行展开互斥不做(允许多开,AnExpandReveal 可安全嵌套);**任一行内 disclosure 打开 → 外层 AnFadeCollapse 自动切展开态**(FadeCollapse 是 NeverScrollable 裁切、展开态是内部 state——否则折叠视口下沿的行点了展开,新增的 returnValue JSON 树长在裁切外,什么都看不见;RunLedger 原语级规则,见族规 4)。
- **可行性**:一页 50 条 × 大 returnValue——解析成本一次性;树只在展开时构建(惰性),内存友好。

### `get_activation` — 正在调阅触发动作 → 已调阅触发动作(薄卡)

- **收起行**:trigger icon · 动词 · chip=`args.activationId` · 回执=fired → `已 fire · 扇出 {firingCount}`;未 fire → `未 fire`(灰——电平未满足是常态非事故);error 非空 → danger:true 自动展开。
- **落定体**:薄卷宗——fire 结论条(记号 + detail 人话)→ `returnValue` JSON 树@240 → fired 时 `payload` 窗 → error danger 窗(有则显)。无因果链(activation 是因果链的**源头**,只有 kind 徽章)。
- **退化态**:全 omitempty 字段缺席 → 只剩结论条(诚实薄卡)。
- **交互**:triggerId → 实体面板;「查看扇出」文字链(fired 且 firingCount>0)。
- **新原语**:无(RunDossier 的薄变体拼装)。
- **Wow**:克制即完美——一条动作记录就该是三行卡,不是仪表盘。
- **可行性**:单条 Activation 小;唯 returnValue 需视口封顶。

---

## 族级新原语汇总

| 原语 | 一句话能力 | 层 |
|---|---|---|
| **RunBeadStrip** | 状态珠串:一页执行记录渲成一排 6px 状态色珠(新→旧),CI-beads 式秒读健康史;**色表参数化**(status word→color 由调用方传:fn/hd/agent/mcp 四态,flowruns 另有 running/completed);纯静态 Wrap,hover 提示 id+status+时间 | feature(chat/ui) |
| **RunLedger** | 有界执行台账,**显式槽位规范**:leading 记号槽(状态点\|词章\|fired 记号)· 主槽(mono id\|人话文本)· chips 槽 · trailing 槽(tabular 时长/时间)· 可选行内 AnDisclosure 展开槽(**任一打开 → 外层 AnFadeCollapse 自动切展开态**,防裁切死角);行高 28,>14 行套 AnFadeCollapse,底部诚实 `+N 更多` 行;住 ToolWindow | feature(chat/ui) |
| **RunDossier** | 执行卷宗组装件:status 头条 + 「输入/输出」对陈机器窗(JSON ≤14 行内联/树@240)+ 「日志」AnDisclosure 抽屉(6000 封顶**双端保留**[头 2000+尾 4000+中缝注记];stderr 先切段、独立预算整段保留、段头带后端原告诫)+ ProvenanceLine 底链 | feature(chat/ui) |
| **ProvenanceLine** | 因果链凭据行:triggeredBy 字形 + **自带 kind→动作映射表**(**可点**:conversation→chat 海洋路由 / flowrun→run cockpit / trigger→实体面板[真实体,照旧 AnRefPill];**不可点**:message/firing/node#iteration→mono 徽章 + hover 复制 id)。**不整体复用 AnRefPill 的 {kind,id} select intent**——conversation/message/firing/node 非后端 EntityKind(AnRefPill 会渲 "?" 兜底),message 锚点跳转/cockpit 内 node#iteration 定位深链前端不存在 | feature(chat/ui) |
| **RunWaterfall** | flowrun 节点解剖:有界视口(~360px)ListView.builder 虚拟滚动;行=状态点+nodeId+kind 字形+#iteration+**落账时刻事件点**(默认;createdAt→completedAt 有真时长的行[如 approval]才加状态色棒,parked 行=createdAt 起虚线延伸至快照刻+「等待中」注记);failed/parked 置顶,failed 行可展开 error+result | feature(chat/ui),cockpit 未来可共享 |
| **TranscriptPeek** | agent 轨迹速览:settled transcript 经**水合适配器**喂 BlockTreeReducer(reducer 吃实时帧,须先水合成帧序),渲有界步骤目录(型别字形+首行摘要,parentBlockId 缩进);封顶 30 块,**选块锚定意图**(failed/timeout=首 5+末 25+中缝省略行、ok=头 30)+ 右岛逃生口 | feature(chat/ui) |

配套非原语工作:回执解析器 4 枚(aggregates 计数 / status+elapsed / flowrun 节点计数 / activation fire 结论)入 `tool_receipts.dart`;i18n 动词对 13 组;`AnIcons.toolIcon` 精确表**逐条钉死 13 工具 → 宿主实体形 icon**(台账/档案语义属于宿主实体,与「档案阅览室」心智一致):`search_function_executions·get_function_execution → function` / `search_handler_calls·get_handler_call → handler` / `search_agent_executions·get_agent_execution → agent` / `search_flowruns·get_flowrun → workflow` / `search_mcp_calls·get_mcp_call → plug` / `search_firings·search_activations·get_activation → trigger`。归因更正:palette §6 推断顺序里 **exec 关键字先于 search 命中——这些名字会先落扳手**(不是「走不到关键字分支」),故必须精确表逐条钉死。

## 族内建造顺序建议

1. **回执解析器 + 13 组动词对**(半天)——全族收起行立刻脱离 generic,零新原语依赖,单独可落。
2. **RunBeadStrip + RunLedger**——一次建成,6 个 search 工具(fn/hd/agent/mcp/flowruns/firings)全部点亮;activations 的行内展开槽在此步一并做(get_flowrun 失败节点行复用)。
3. **ProvenanceLine + RunDossier**——4 个薄 get(fn/hd/mcp/activation)落定体齐;stderr 分段在 mcp 皮肤内做。
4. **RunWaterfall → get_flowrun**(族内最大件)——**开工前先跑一次真 flowrun,验证节点 createdAt/completedAt 差值分布**(record-once 下大概率 ≈0;证实存在真时长行[如 approval/重试]才对该类行开棒,否则全事件点);瀑布 + 汇总条 + 封顶 callout + 钉住版本抽屉;gallery specimen 先行(空 run/80 封顶/全 failed/长循环 #N/parked 虚线 五电池)。
5. **TranscriptPeek → get_agent_execution**——**前置工件:transcript→reducer 水合适配器**(settled 块数组→帧序;与 invoke_agent 卡 reload 水合共用,census 03 §8);依赖 BlockTreeReducer 接线与右岛深链,放最后;右岛(V8)未落时逃生口先降级为实体面板执行页。


---

# F10 — web 族完美态设计(WebSearch / WebFetch,2 工具)

> 线缆源:census/08-mcp-web.md §8–9(`backend/internal/app/tool/web/{web,fetch,search,search_byok}.go`)。
> 本族无 edit 类,morph 全员 N/A。

## 族级统一文法

- **身份**:对外部世界的**网络动作**——icon 统一 globe。⚠️ 现 `AnIcons.toolIcon` 精确表登记的是
  `web_search/web_fetch`(蛇形),而真实工具名是 `WebSearch`/`WebFetch`;查表发生在
  `name.toLowerCase()` **之后**(icons.dart:155-156),故关键字推断下 `websearch` 先撞
  `search`→放大镜、族身份裂开(`webfetch` 经 `web|fetch` 关键字本已推中 globe,真正裂的只有
  WebSearch)。**须补精确表两条小写键:`websearch→web`、`webfetch→web`**——照原大小写登记
  永不命中;配断言测试 `AnIcons.toolIcon('WebSearch') == web`。
- **族级签名挑战——"假成功真失败"**:两工具几乎所有失败都走"成功返回 + 模板文案"(卡相位是
  succeeded,内容却是错误说明)。族地基 = `tool_receipts.dart` 两个**纯函数结局分类器**
  `webSearchOutcome(resultText)` / `webFetchOutcome(resultText, {String? url})`:**逐模板锚定匹配**——
  - **WebSearch 侧**(成功输出恒 JSON,无散文假阳性风险)用**确稳前缀锚**:
    `No search backend configured for "` / `Search via `(provider 失败)/
    `The configured default search key`(key 配错类目)/ `Search provider "`(缺 baseURL)——
    后两条是 search.go:153/160 的 provider-misconfig 模板;`Search provider "` 与 `Search via `
    是两个不同锚,勿混。
  - **WebFetch 侧**成功输出是**模型散文**——dev 向用户抓一篇讲网络排障的页面,摘要完全可能以
    "Failed to fetch " / "Cannot resolve host " / "Invalid URL \"" 开头,纯前缀锚有假阳性、
    违诚实铁律「回执绝不猜」。故 **URL 载体模板锚必须绑 URL 判别**:`Invalid URL "` /
    `Failed to fetch ` / 两条 Fetched 系,在 `url` 参数可得时(落定期 args 恒完整)**要求锚后
    紧跟 args.url 才判失败**;args 不可解析才退化纯前缀。`Refusing to fetch ` /
    `Cannot resolve host ` 锚后跟的是 host/IP,要求 args.url 的 host 出现;`URL has no host.`
    全串;`Summarisation unavailable (` 前缀。**Fetched 系两条口径不同**:empty-body 用
    **全串锚**(有 `$`)`^Fetched .+ but body was empty\.$`;JS 壳用**起始锚定前缀 regex
    (无 `$`)**`^Fetched .+, but the page has almost no readable text \(\d+ chars\)`——真模板
    (fetch.go:200)在 "(N chars)" 后还有长尾引导文(em-dash + "…switch the workspace web-fetch
    mode to Jina."),加 `$` 必 miss → JS 壳错误文被判 success、按 15 散文渲成「摘要」双重撒谎。
    裸 `startsWith('Fetched')` **禁用**。
  **匹配不上一律判 success**(诚实铁律:绝不猜)。分类器驱动回执文案与 `danger:true`
  (→底盘自动展开一次),纯函数、脱 widget 全矩阵单测;测试矩阵必含 fetch.go:200 **完整真样本**
  (含 em-dash 与 Jina 引导尾)+ **以失败模板开头的真散文摘要反例**(防假阳性)。
- **两种窗**:搜索命中/错误文案 = 机器产物 → `ToolWindow` mono;WebFetch 摘要 = 模型写给人读的
  散文 → **散文窗**(`AnSunkenPanel(inset: AnInset.bubble)` + 15/1.6 阅读排版——palette 已预留
  此配方,凹陷容器身份不变、只换排版,仍绝不借 thinking 低语语法)。
- **URL 出卡**:族内一切 URL 可点 → 系统默认浏览器(**成熟包 `url_launcher`**,原则 #8)。scheme
  白名单 = **http/https/mailto,与 AnMarkdown 链接闸(an_markdown.dart:46)逐字同一集合**——闸含
  mailto 而 openExternalUrl 只放 http/https 的话,摘要里的 mailto 链接会被 AnMarkdown 染成可点态、
  点击却被拒,死 affordance;url_launcher 原生支持 mailto,直接收编。hover 显完整 URL tooltip,
  行尾 copy。新 app 级服务 `openExternalUrl`(palette 缺口 #8 的 URL 半边)。
- **ghost 导航口门控**:族内两条 nav intent(「配置搜索 key / 查看搜索 key」→ settings/api-keys、
  「切换 Jina 抓取模式」→ settings/workspace `webFetchMode`)的目标 settings 面当前是「即将推出」
  占位——ghost 钮按**目标面存在性门控**:目标面未落地时不渲染钮、退化为纯文案引导(后端引导文
  原样在 mono 窗里,信息零丢失);nav intent 走 shared 常量、不硬编路径,settings 面落地即点亮。
- **i18n**:动词对/回执词全走 slang;下文给中文动词,英文自然对应(Searching→Searched 等)。

---

### `WebSearch` — 正在搜索 → 已搜索(Searching → Searched)

- **收起行**:globe · 正在搜索 · chip=`"query"`(`argStringPartial('query')` 引号包裹,流中可长;
  超 48 字符尾省略)· 回执:**成功 = 「N 条」,`truncated:true` → 「N+ 条」**(与展开体头行
  同源同格式;source 徽标只进展开体、不进回执);退化态回执见下。`limit` 不进收起行(进展开体 meta)。
- **活期**:`settle-only`。无 progress、单发 HTTP 10s 超时——活期只有流光动词 + 读秒,**无 liveBody**
  (克制条款:一两秒的调用不配骨架秀,骨架行数还会撒谎)。
- **落定体**:**命中列表窗**(本族陈列面)。头行:`AnBadge(source)`(brave/serper/tavily/bocha,
  tone none)+ `N 条`(13 faint;`truncated:true` → `N+ 条`,截断显式)。列表 = `WebHitList`:
  每行 title(15 w400 ink,单行省略)/ snippet(13 muted w300,钳 2 行)/ 域名(mono 12 faint,
  从 url 提 host)。≤30 行线缆硬上限,>10 行套 `AnFadeCollapse`(fadeColor 传 surfaceSunken)。
- **退化态**:
  - **空结果**(`results:[]`):回执「无结果」(danger:false,诚实空);体 = 空态行「没有找到结果」13 faint。
  - **未配 key**(`No search backend configured…`):回执「未配置搜索」danger→自动展开;体 = 引导
    文案原样进 ToolWindow mono + ghost 动作「配置搜索 key」(nav intent → settings/api-keys,
    按族级 ghost 门控——目标面未落地时不出钮,引导文案本身已足)。
  - **key 配错类目 / 缺 baseURL(provider-misconfig)**(`The configured default search key is
    provider "x"…` / `Search provider "x" has no base URL configured.`):回执「搜索 key 配置有误」
    danger→自动展开;体 = 文案原样 mono 窗 + 与 provider 失败态共用的「查看搜索 key」导航口
    (同上门控)。
  - **provider 失败**(`Search via <p> failed:…`):回执「搜索失败」danger;体 = 失败文案 mono 窗。
    ⚠️ 上游 401/403 后端已把 key 标 invalid(apikey 徽标会翻)——卡内**不做**"key 已失效"断言
    (文案里 sentinel 片段不稳定,回执绝不猜),只给同一个「查看搜索 key」导航口。
  - **解析失败**(非族模板亦非合法 JSON):落通用 mono 窗,绝不无声。
- **交互**:行点击 → `openExternalUrl`;hover tooltip 全 URL;行尾 hover 现 copy-URL 小钮
  (`AnButton.iconOnly` sm)。可选后续:行尾「抓取此页」把 URL 预填 composer(与 WebFetch 组合拳,V6 后再议)。
- **新原语**:`WebHitList/WebHitRow`(feature 层皮肤:AnInteractive 行 + 三层字阶命中排版);
  `openExternalUrl` app 服务(url_launcher 接线 + scheme 闸);`webSearchOutcome` 回执分类器。
- **Wow**:搜索结果不再是一坨 JSON——是一列可点进浏览器的真实链接卡,source 徽标一眼看出这次
  查询花的是谁家的 key。
- **可行性**:输出是全普查唯一 pretty JSON,`jsonDecode` 无碍;≤30×(title+url+snippet) 几 KB,
  落定后 parse 一次成本可忽略。失败态全走字符串模板,共**四类**:未配 key / key 配错类目 /
  缺 baseURL / provider 失败——分类器四锚全配(见族级文法),五电池测试矩阵四条模板逐一入列。

---

### `WebFetch` — 正在抓取 → 已抓取(Fetching → Fetched)

- **收起行**:globe · 正在抓取 · chip=URL 净化态(`argStringPartial('url')`:剥 scheme、host 恒完整、
  路径中段省略,封顶 ~48 字符)· 回执 = 结局分类器驱动:成功 →「N 字」(摘要字素数,确定性可数);
  空页 →「空页面」;raw 降级 →「摘要不可用 · 附原文」danger(**不报字节数**——线缆模板恒印
  "(first 4 KB)" 但短页实为全文,虚报违诚实铁律);JS 壳 →「JS 页面」danger;
  invalid/SSRF/fetch 失败 →「抓取失败」/「已拒绝」danger。
- **活期(生长秀——本族的 Wow 主场)**:数据源 = `progress 流`(census:摘要阶段 utility 模型每个
  text delta 实时 tee 进 progress,最终 result = 同一份全文)。两幕:
  ① **抓取幕**(无 progress 帧):只有流光动词 + 读秒,无窗——诚实,不演。
  ② **摘要幕**(首个 delta 到达):行下**散文窗**绽开,摘要**逐字被写出来**——15/1.6 阅读排版。
  **尾钳机制(显式,勿照 ToolLiveTail 抄)**:Flutter Text **没有**「显示尾 N 行」原语(maxLines
  钳头不钳尾),ToolLiveTail 的按 `\n` 切尾只适配 newline 密集的终端输出——散文摘要少换行,一整段
  =1「行」,wrap 出几十视觉行 → 活期卡高无界、违 constitution #8。live 态用**定高视口**:
  `SizedBox(height: 6 行 ×15×1.6 ≈ 144px)` + `ClipRect` + `Align(alignment: bottomLeft)` 装
  **全文** Text——文本长过视口自然只露底部,即「尾钳」。合并 ≤1/frame;几 KB 的 RenderParagraph
  每帧重排便宜;不逐帧跑 markdown/高亮。reduced motion 同构:窗即时出现、文本直接落最新值,零信息丢失。
- **落定体**:① 问句行:「问:」标签 13 + `args.prompt` 13 muted(确定性 arg,非 LLM summary——
  这是"摘要+prompt"对陈的 prompt 半边);② **散文窗**装 `AnMarkdown(summary)`(15/1.6,摘要常带
  列表/强调,落定才上 markdown 渲染)。**live→settled 无原位转场**:success 落定瞬间按底盘既定
  「完成即收拢」——活窗溶掉、卡收起;AnMarkdown 只住用户展开后的落定体,与活期纯 Text 不同屏
  (Text→markdown 全渲染必有重排,故不做原位替换,也不做"落定保窗")。超 400px 套
  `AnFadeCollapse(fadeColor: surfaceSunken)`——散文窗同在凹陷底上,palette 明示其默认
  fadeColor=canvas、照抄默认会出底色不匹配的渐隐 scrim(与 WebSearch 段口径对齐)+ 展开逃生口。
  摘要内链接经 AnMarkdown 链接闸 → `openExternalUrl`(http/https/mailto 逐字同一白名单,见族级文法)。
- **退化态**(族定位的"三退化态识别"+1):
  - **fail**(`Invalid URL` / `Refusing to…`(SSRF)/ `Cannot resolve` / `URL has no host` /
    `Failed to fetch`):回执 danger→自动展开;体 = 错误文案原样 ToolWindow mono(机器错误住机器窗)。
    SSRF 拒绝附一行 13 faint 说明「内网/环回地址按设计拒抓」——陈述设计事实,非猜测。
  - **empty**(`Fetched … but body was empty.`):回执「空页面」(danger:false);体 = 该句 mono 窗,薄卡即止。
  - **raw 降级**(`Summarisation unavailable (<err>). Raw content (first 4 KB):`):诚实半成功——
    回执「摘要不可用 · 附原文」danger→自动展开;体 = 降级原因行(13,danger 色)+ **原文进
    ToolWindow mono**(窗守 6000 字符封顶)。⚠️模板头恒印 "(first 4 KB)" 但 `truncate(content,4096)`
    对短页返全文且**无** `...[truncated]` 注记——窗内截断注记只在余文尾**真含** `...[truncated]`
    时显示,不做默认假设。原文是生页文本,归机器窗、不进散文窗。
  - **JS 壳**(`…almost no readable text (N chars)…`,仅 local 模式):回执「JS 页面」danger;体 =
    引导文案 + ghost 动作「切换 Jina 抓取模式」(nav intent → settings/workspace `webFetchMode`,
    按族级 ghost 门控——目标面未落地时不出钮,引导文案原样在 mono 窗里、信息零丢失)。
- **交互**:chip 点击/展开体 URL 行 → `openExternalUrl` 原页;散文窗 hover 现 copy 全文小钮——
  copy affordance 住**两窗共用层** `WindowCopyButton`(独立 hover overlay 件,ToolWindow 与
  ProseWindow 各自挂载;ProseWindow 基于 AnSunkenPanel、**不是** ToolWindow,做成 ToolWindow
  私有 action 槽本族最疼的散文窗恰恰拿不到)(palette 缺口 #12 在本工具最疼——摘要就是拿来引用的)。
- **新原语**:`ProseWindow`(feature 层薄具名:AnSunkenPanel(inset:bubble)+ 阅读排版 slot,
  live 态=定高 144px 视口+ClipRect+Align(bottomLeft) 尾钳全文 Text / settled 态=AnMarkdown,
  两态共用容器身份);`webFetchOutcome(resultText, {String? url})` 分类器;`WindowCopyButton`
  hover overlay 件(ToolWindow/ProseWindow 共用挂载,补 palette 缺口 #12)。
- **Wow**:输入一个 URL,看着整张网页在你眼前**被蒸馏成一段逐字生长的答案**——不是转圈等结果,
  是亲眼看提炼发生。
- **可行性**:args 流入顺序不保证(url/prompt 谁先到不定)——chip 与问句行都须容忍缺席;
  progress 逐 delta 追加、调用方合并 ≤1/frame 即可(定高视口尾钳,便宜);摘要典型几百字~几 KB,
  1MB cap 在后端、前端永不见生 HTML;分类器八锚覆盖 census §8 全部失败分支(empty-body 全串
  regex、JS 壳起始锚定前缀 regex、URL 载体锚绑 args.url 判别、余为确稳前缀,见族级文法),
  英文模板是后端硬编码字符串、稳定可锚(若后端他日改模板文案,须同提交改分类器——契约同步纪律延伸)。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| `webSearchOutcome` / `webFetchOutcome(resultText, {url})` | model(tool_receipts) | 按锚定模板匹配(search 确稳前缀锚;fetch URL 载体锚绑 args.url 判别 + empty-body 全串 regex + JS 壳起始锚定前缀 regex)把"假成功真失败"字符串分类成结局枚举(unknown→success),驱动回执与 danger 自动展开;纯函数全矩阵单测 |
| `WebHitList` / `WebHitRow` | feature 皮肤 | 搜索命中行:title 15 / snippet 13 钳 2 行 / host mono 12,AnInteractive 点击出卡 + hover copy |
| `ProseWindow` | feature 皮肤 | 机器窗的散文变体:AnSunkenPanel(inset:bubble) + 15/1.6 阅读排版;live 态定高 144px 视口+ClipRect+Align(bottomLeft) 尾钳(Flutter Text 无「尾 N 行」原语、ToolLiveTail 切行法对散文失效,勿抄)/ settled AnMarkdown 双态 |
| `openExternalUrl` | app 服务 | url_launcher 接线 + http/https/mailto scheme 闸(与 AnMarkdown 链接闸逐字同一白名单,防 mailto 死 affordance),族内一切 URL 出卡到系统浏览器(补 palette 缺口 #8 半边) |
| `WindowCopyButton` | core(独立 hover overlay 件) | 窗右上 hover 现一键复制窗内容;ToolWindow 与 ProseWindow 各自挂载(ProseWindow 非 ToolWindow,做成 ToolWindow 私有槽散文窗拿不到;补 palette 缺口 #12,Bash/检索族白得) |
| AnIcons 精确表补登 | core | 小写键 `websearch→web`、`webfetch→web`(查表在 toLowerCase 之后,照原大小写登记永不命中;真正裂的是 WebSearch 先撞 `search`)+ 断言测试 `toolIcon('WebSearch') == web` |

## 族内建造顺序建议

1. **结局分类器**(两工具共用地基;纯函数 + 五电池测试矩阵,**十二锚全覆盖**——WebFetch 八锚
   [empty-body 全串 regex + JS 壳起始锚定前缀 regex + URL 载体锚绑 args.url] + WebSearch 四锚
   [含 provider-misconfig 两锚,search.go:153/160];矩阵须含 fetch.go:200 **完整真样本**[含
   em-dash 与 Jina 引导尾]+ 以 "Failed to fetch "/"Fetched"/"Search" 等失败模板开头的
   **真散文摘要反例**防假阳性)——没有它一切回执都在撒谎。
2. **WebSearch 落定体**:hit list + source 徽标 + `openExternalUrl` 接线(settle-only,无活期
   复杂度,先把陈列面立住)。
3. **WebFetch**:ProseWindow 双态 → 活期打字摘要(族 Wow 主场;progress 管线 chassis 已有,
   只接散文窗)→ 落定 AnMarkdown + prompt 对陈。
4. **退化态收口**:两工具全部 danger 分支 + nav intent 两条(api-keys / webFetchMode;**前置条件:
   目标 settings 面已落地**——未落地则按族级 ghost 门控只留纯文案引导、钮不上)+ AnIcons
   精确表补登(小写键 + 断言测试)+ `WindowCopyButton` 两窗挂载。


---

# F11 memory-todo 族 — 完美态设计

> 5 工具:`write_memory` / `read_memory` / `forget_memory`(lazy 记忆三件)+ `todo_write` / `todo_read`(resident 清单对)。
> 线缆真相:census 09-misc——**全族无 progress 流**;**返回全是文本模板**(一句话确认 / `### name (source)` 记忆稿 / `- [ ] / [→] / [x]` markdown 清单),非 JSON。回执一律按稳定英文模板**前缀严格解析**,不匹配即无回执(诚实铁律 #4)。

## 族级统一文法

1. **动词族语**:记忆三件用拟人动词对——**正在记忆/已记忆 · 正在回忆/已回忆 · 正在遗忘/已遗忘**(Memorizing/Memorized · Recalling/Recalled · Forgetting/Forgot)。这是唯一允许拟人的族:工具本身就是模型的记忆器官,拟人即精确。todo 对用平实动词:todo_write settled **恒两态——已更新清单/已清空清单**(清空由 `args.items==[]` 确定性判,零历史依赖);todo_read 用读取清单。「正在规划」仅作 todo_write 活期修饰,且仅当本 scope 确知无前例(对话创建于本 session,或该 scope 历史已加载完整且无清单前例)才用,否则活期也回落「正在更新」——settled 恒不用,见该卡。
2. **目标 chip = name slug**:记忆三件的 `name` 是 ≤64 的小写 slug,天然适配 mono chip、无需截断策略;todo 对无 chip(动词自足,信息在回执 `m/n`)。
3. **两张族脸,各一个新窗内容**:`MemoryNoteCard`(索引卡:name + source 徽章 + 描述 + **渲染态 markdown** 正文——文档母语「排版稿」而非源码)与 `TodoChecklist`(复选清单:三态字形逐条点亮)。两者都住 ToolWindow/凹陷面板,守机器窗身份——绝不裸散文。
4. **回执解析器全族共享**:`tool_receipts.dart` 加纯函数,锁定后端模板前缀:`Saved memory "` / `Cannot save memory:` / `Memory "…" not found` / `Forgot memory "` / `### <name> (source:` / 清单三记号 / `(todo list cleared`。**软失败(Cannot save / not found)是 succeeded 相位里的坏消息**——必须显性成回执,绝不装成功。
5. **图标精确表补条**:现状 keyword 推断把 `write_memory`→doc、`forget_memory`→兜底扳手、`todo_write`→doc,语义全错。补精确表:记忆三件 → memory 形(一个字形三件共用),todo 对 → checklist 形。
6. **危险梯度**:全族 safe/只读,唯 `forget_memory` 不可逆删除——按宪法 #9 做**薄卡**(summary 常显 + 不可逆徽章),不表演。
7. **凹陷窗通则**:窗内一切 `AnFadeCollapse` 一律**显式传 `fadeColor: surfaceSunken`**(palette 默认 canvas,在凹陷底上会出现渐隐色断层)——`MemoryNoteCard` 与 `TodoChecklist` 共用此条。`MemoryNoteCard` 被 6000 cap 硬截时,展开到底部必带显式注记「已截断,余 N+ 字符——完整内容在记忆库」(诚实铁律 #4;deep link 落地前注记为纯文案,settings+memory 面落地后接 nav intent);未截断才用普通「查看全文/收起」标签。

---

### `write_memory` — 正在记忆 → 已记忆

- **收起行**:memory icon · 正在记忆 · `my-note-name` chip(`argStringPartial('name')`,slug 短、流中即现)· 回执**三分支正向门控**:输出 startsWith `Saved memory "` 才渲成功回执 `N 行`(行数从 **args**.content 算——args 是结构真相,但「成功」必须有输出凭据,不默认「非失败即成功」);`Cannot save memory:` 前缀 → 「未保存」`danger:true`(自动展开);两者皆不匹配(模板漂移)→ **无回执**、通用体倾倒原文(族级文法 #4;契约单测覆盖三分支)。
- **活期(生长秀)**:`args-partial`——content(markdown payload)随 LLM 打字流入 → liveBody 复用 builds 活窗模式:小机器窗尾 **6 行纯 mono**。⚠️ args 线缆上 content 是 **JSON 转义串**(`\n` 是两字符转义,还有 `\"`/`\uXXXX`,且转义序列可能被 delta 劈在 chunk 边界)——对原始 args 文本裸 split 找不到真换行;尾 6 行必须在**反转义后的文本**上 split:复用 builds 活代码窗的 partial-arg-string 反转义提取器,若它没有则先补族级纯函数 `partialJsonString`(单测覆盖 `\n`/`\"`/代理对被 chunk 劈半的用例)。观感 = 一张便签正在被一笔一笔写下。
- **落定体**:`MemoryNoteCard`——凹陷窗 header = `name` mono + `AnBadge('source: ai')`(写入恒 ai);体 = description(13 muted)+ 细分隔 + **AnMarkdown 渲染正文**(15/1.6,`AnInset.bubble`);超 ~400px 上 `AnFadeCollapse`(**fadeColor 显式传 surfaceSunken**)「查看全文」。
- **morph**:无——同名 upsert 整体覆盖、线缆不返旧文,不假装 diff(诚实:动词也恒「已记忆」,不妄称「新建/更新」——wire 不可辨)。
- **退化态**:description/content 缺 → 后端软拒串 → danger 回执 + 展开体窗内显软拒原文一行;name 非法同理;args 解析失败 → 无 chip 无回执、通用体。
- **交互**:落定后卡头「在记忆库打开」nav intent(按 name;等 settings+memory 面落地接线);正文随宿主 SelectionArea 可选拷。
- **新原语**:`MemoryNoteCard`(feature 层索引卡陈列件)+ `memoryReceipt` 解析器;活期依赖 partial-arg-string 反转义(builds 活窗已有则复用,缺则补 `partialJsonString`,见汇总表)。
- **Wow**:看着模型把便签一行行写下,落定瞬间翻面成一张排版好的索引卡——记忆从「正在形成」到「已归档」有实体感。
- **可行性**:args 键序不可控,但 partial 提取容忍(name/description 短、几乎必先完整);模板串是后端稳定英文,前缀解析可靠但需契约单测钉住;content 无上限 → 窗封顶 6000 chars + FadeCollapse 双保险。

### `read_memory` — 正在回忆 → 已回忆

- **收起行**:memory icon · 正在回忆 · `name` chip · 回执:输出首行匹配 `### <name> (source: <x>)` → `N 行`(正文行数);`not found` 前缀 → 回执「未找到」**灰非 danger**(读 miss 是诚实空、非事故,同 F2 noMatches 语气)。
- **活期**:`settle-only`——无 payload 无 progress;活期退化为动词流光 + >3s 读秒,无窗。
- **落定体**:复用 `MemoryNoteCard`——`parseMemoryTemplate` 反解模板(首行 name+source / 可缺的 description 行 / `---` 后正文);source 徽章此处有实义:`user` = 用户手写的记忆被模型回忆(与 `ai` 视觉区分,user 用 accent tone)。
- **退化态**:not found → 体 = 窗内一行软失败原文(灰);模板不匹配(后端未来改版)→ 通用体倾倒原文,绝不无声。
- **交互**:「在记忆库打开」同 write;卡与 write 落定卡同脸——转录里一眼认出「这是同一张记忆」。
- **新原语**:复用 `MemoryNoteCard`;`parseMemoryTemplate`(纯 Dart,单测锁模板)。
- **Wow**:回忆落定 = 整张索引卡浮现,写与忆共用同一张脸——两个工具、一个记忆实体的两次现身。
- **可行性**:输出**无截断**(正文多长返多长)→ 封顶 + FadeCollapse 必须;description 行可缺,解析器按 `---` 分隔容错。

### `forget_memory` — 正在遗忘 → 已遗忘(薄卡)

- **收起行**:memory icon · 正在遗忘 · `name` chip · 回执:`Forgot memory "…"` 匹配 → 无附加回执(过去时即凭据);`not found (already gone?)` → 「本就不存在」灰。
- **活期**:无(瞬时)——本卡主戏是 **awaitingConfirm 相位**:不可逆删除靠 LLM 自报 danger 触发 chassis 警示行(V6 内联批复落地后接按钮)。
- **落定体**:薄——summary **常显窗上**(危险族拍板 #1)+ 一行凭据:`name` chip + `AnBadge('不可逆', tone: danger)`。无机器窗。
- **退化态**:not found → 体一行软字符串原文(未删到东西也如实说)。
- **交互**:**无 deep link**——实体已物理删除,不给死链(诚实)。
- **新原语**:无(全复用)。
- **Wow**:克制即完美——删除不表演:一行、一枚不可逆徽章、一句自报意图,让用户的注意力全部落在「要不要放行」上。
- **可行性**:确认门禁依赖 LLM 自报 danger(S18 无中央门控)——模型若自报 safe 则直接执行;卡不越权造门禁,只忠实呈现相位。

### `todo_write` — 正在规划/更新/清空清单 → 已更新清单/已清空清单(settled 恒两态,族经典款)

- **收起行**:checklist icon · settled 动词**恒两态、零历史依赖**:`args.items==[]` → 已清空清单;否则 → 已更新清单(不妄称「已规划」——transcript 反向 prepend 翻页下更早历史未必已加载,历史依赖的动词会在旧页载入后回溯漂移=对用户撒谎)。活期「正在规划」仅当本 scope 确知无前例(见族级文法 #1),否则活期回落「正在更新」· 无 chip · 回执 `m/n`(从 args 结构算 completed/total;清空 → 无回执,动词自足)。
- **活期(生长秀,本族重头)**:`args-partial`——items 数组随流成形,`partialJsonItems` 提取已完整对象 → `TodoChecklist` 活窗**逐项点亮**:`☐` pending 灰 / `▸` in_progress accent + `AnStatusDot(run)` 呼吸 + activeForm / `☑` completed ok + content 划线沉灰。与 **per-scope 前态** `scopeChecklists`(session 态,键=parentBlockId,主对话键空——subagent 清单与主对话绝不互染)diff(按 content 串匹配,fallback 位置):**状态迁移行入场打一发一次性脉冲**——pending→completed 勾格填色 + 整行沉灰(fast120,白板上被人打勾的瞬间);→in_progress 呼吸点亮。**脉冲 fired 态住 chat 视图模型**(已放集合,键 (blockId, item content),仅本 session 活期状态迁移瞬间登记并播一次)——**绝不放 widget 内部 state**(transcript sliver 虚拟化滚离/滚回会 dispose 重建 widget → 脉冲整批重放);冷加载历史卡 / 滚回 / 重建一律查集合跳过、**永不放脉冲**。reduced motion:即时终态、零脉冲、信息零丢,fired 集合同样登记(不欠账不重放)。
- **落定体**:展开 = 同一 `TodoChecklist` settled 态(无呼吸,in_progress 行静态 accent);>12 行上 `AnFadeCollapse`(上限 64 项封死最坏高度,transcript 永不背无界)。
- **morph**:wholesale 整表替换——**不做**旧表→新表排版 morph(线缆无 op 流、位置寻址不可靠);状态迁移脉冲就是 morph 的诚实形态。被删项不演出(新表即真相;历史各卡存各自快照——目录不日志)。
- **退化态**:空表 → 体一行灰「(清单已清空)」;>64 / content 空 / status 非法 → ValidateInput 硬错(`TODO_TOO_MANY_ITEMS` 等)→ chassis 失败红 + 自动展开;args 解析失败 → 无回执通用体。
- **交互**:无 deep link(对话内状态);行**不可点**(看板只读,写入 LLM 专属——不给会失望的 affordance)。
- **新原语**:`TodoChecklist`(受控行列表 + 三态字形 + 迁移脉冲,fired 态外置;A 级流式)· `partialJsonItems`(流中不完整 JSON 数组提取完整元素,纯 Dart 单测)· `scopeChecklists` per-scope 前态 + fired 已放集合(chat 视图模型 session 态——只服务活期脉冲 diff 与活期「正在规划」判定,冷加载历史卡永不参与派生)。
- **Wow**:Claude Code 同款体验的完全体——计划逐条亮起、完成项当着你的面被勾掉;历史收起后一行 `已更新清单 · 3/7` 读起来像里程碑。
- **可行性**:schema 要求逐项 status 必填但域层缺省 pending——partial 提取须容忍缺 status(按 pending 渲);结果 markdown 回显**不用于渲染**(args 结构才是真相);每 delta 重 parse partial JSON 须记上次扫描偏移做增量、合并 ≤1/frame。

### `todo_read` — 正在读取清单 → 已读取清单(薄)

- **收起行**:checklist icon · 正在读取清单 · 无 chip(无参工具)· 回执 `m/n`(解析结果 markdown:行首数 `- [x]` / `- [→]` / `- [ ]`);`(todo list cleared — no tasks)` → 回执「空清单」灰。
- **活期**:`settle-only`——动词流光即全部,无窗。
- **落定体**:复用 `TodoChecklist`(settled 静态):`parseTodoMarkdown` 从模板反解 items——**注意** in_progress 行线缆上只有 activeForm(content 不在 wire)→ 照实显示 activeForm,不编 content(诚实)。
- **退化态**:空清单 → 一行灰;模板不匹配 → 通用体倾倒原文。
- **交互**:无。
- **新原语**:复用 `TodoChecklist`;`parseTodoMarkdown` 反解器(纯函数;与后端 render() **单源模板**逐字锁定——todo_write 回显同款,一个解析器两处受益,单测钉三记号)。
- **Wow**:读回与写入长同一张清单脸——两个工具、一个看板心智,agent「回忆计划」时用户看到的就是那块板。
- **可行性**:三记号行首精确匹配足够(content 在行内非行首,`- [` 开头的毒 content 骗不过行首锚)。⚠️ census 只背书 content「trim 后非空」、**未禁内部换行**——`"x\n- [x] fake"` 会让 render() 真产多行,m/n 与清单行随之陈述错误事实(违诚实铁律 #4)。按迭代铁律②给后端补不变量:domain 层拒绝(或归一化为空格)content/activeForm 内部换行,**同提交 testend 契约单测钉死「render 输出行数 == items 数」**;不变量落地前,解析器遇到任何不匹配三记号的非空行即整体按模板不匹配处理 → 无回执、通用体倾倒原文(诚实降级)。

---

## 族级新原语汇总

| 原语 | 层 | 一句话能力 |
|---|---|---|
| `TodoChecklist` | feature widget | 三态复选清单窗:pending/in_progress/completed 字形行,流中逐项点亮,可选 previous 快照做状态迁移脉冲——**脉冲 fired 态由调用方外置管理**(widget 自身无记忆,sliver 重建零重放;reduced motion 即时);受控、A 级流式 |
| `partialJsonItems` | model 纯 Dart | 从流中不完整 JSON 数组文本提取「已完整」的元素对象(记扫描偏移可增量);单测覆盖半截对象/转义/嵌套 |
| `partialJsonString`(builds 活窗若已有同能力则复用不新建) | model 纯 Dart | 从流中不完整 JSON 字符串字面量增量反转义出已确定文本(容忍 `\n`/`\"`/`\uXXXX`/代理对被 chunk 劈半);write_memory 活期便签尾 split 的基底 |
| `MemoryNoteCard` | feature widget | 记忆索引卡:name mono + source 徽章 + description + 渲染态 AnMarkdown 正文,FadeCollapse 封顶;write/read 共用 |
| 模板解析器组(`memoryReceipt` / `parseMemoryTemplate` / `parseTodoMarkdown` + `todoCountReceipt`) | tool_receipts.dart 纯函数 | 按稳定英文模板前缀/记号严格解析回执与结构;不匹配即无回执(诚实降级),契约单测钉死模板 |
| `scopeChecklists` 前态 + fired 集合 | chat 视图模型 session 态 | 按 scope(键=parentBlockId,主对话键空)记最近落定清单快照——**只服务活期脉冲 diff 与活期「正在规划」判定,冷加载历史卡永不参与动词派生**(settled 动词恒两态零历史依赖);fired 已放集合(键 (blockId, item content))保证脉冲一次性:滚回/重建/冷加载查集合跳过,reduced motion 同登记 |
| AnIcons 精确表补条 | core | memory 形(记忆三件)+ checklist 形(todo 对)——修正 keyword 推断的 doc/扳手误判 |

## 族内建造顺序建议

1. **图标补条 + 模板解析器组**(半天量):全族 5 行立刻有正确的收起行动词/chip/回执——零体也不无声,先把「目录感」立住。
2. **`TodoChecklist` 静态形 + `parseTodoMarkdown` → `todo_read` 先通**:settle-only 最薄路径验证清单渲染与三记号反解;同批按迭代铁律②落后端 content/activeForm 单行不变量 + testend 契约单测(「render 输出行数 == items 数」)。
3. **`partialJsonItems` + 活窗点亮 + 迁移脉冲 + `scopeChecklists`/fired 集合 → `todo_write` 完全体**(族冠,吃掉族内 60% 工作量;性能小心点全在这)。
4. **`MemoryNoteCard` + `write_memory`**(live 便签尾复用 builds 活窗模式;先确认其含 partial-arg-string 反转义,缺则补 `partialJsonString` 再接)。
5. **`read_memory`(复用卡 + `parseMemoryTemplate`)与 `forget_memory` 薄卡**收尾(顺手,各半小时级)。


---

# F12 introspection 族 — 完美态设计

> 工具:`get_relations` / `capability_check_workflow` / `search_tools` / `get_model_config`(4)。
> 线缆来源:census/09-misc.md(relations/tools/model)+ census/04-workflow.md §7(capability_check)。

## 族级统一文法

**族魂:自省 = agent 在「看清系统本身」**——查影响面、验健康度、翻工具箱、读模型盘。四个工具
全部**只读、零 progress、settle-only**(args 都是几十字节的小参数,Execute 不发中间流)。由此
定下族纪律:

1. **活期一律克制**:无 liveBody,活感只靠底盘的流光动词 + >3s 读秒。args 小到没有「生长」
   可看——硬造活窗是撒谎。省下的预算全押落定体。
2. **落定体 = 陈列,不是 JSON 倾倒**:关系给**星图**、体检给**报告卡**、工具给**命中卡列**、
   配置给**全景面板**。原始 JSON 永远留 AnJsonTree 逃生口(有界 `jsonViewport`),但绝不是首屏。
3. **回执统一计数格**:`N 关系` / `通过·N 提醒` / `N 工具` / `N key · M 模型`——落定行扫一眼即知
   分量,不点开也完整。空结果诚实:`无关系` / `无匹配`。
4. **实体引用一律 AnRefPill**(kind+name,id 可点派 `{kind,id}` select intent)——自省族输出
   天然全是实体坐标,可点跳转是本族的核心交互资产(fromName/toName 后端已解析,零额外请求)。
   select intent 层**按 kind 路由归宿**(实体海洋居民→实体详情;document→documents 海洋;
   mcp→settings);无归宿 kind(如 conversation)pill 传 `onTap:null` 惰性化——显示不撒谎、
   点击不派死链。
5. **危险色只属于「发现了问题」**:族内无破坏动作;capability_check 的 `ok:false` 回执走
   danger(红 + 自动展开一次)——这是「体检出病」的注意力语义,不是破坏语义。
6. 图标:`get_relations` 建议补精确表映射 →(关系/分享形);`capability_check_workflow` 命中
   关键字 `workflow` 实体形(可);`search_tools` 命中 `search` 放大镜(可);`get_model_config`
   无命中落兜底扳手——建议补精确表 →(芯片/滑杆形)。

---

### `get_relations` — 正在勘察关系 → 已勘察关系(Mapping relations → Mapped relations)

- **收起行**:关系形 icon · 动词 · chip=`args.id`(mono,`argStringPartial` 容忍流中片段;
  `depth>1` 时缀 ` · d2/d3`)· 回执=解析输出 JSON 的 `count`:`N 关系`,`0`→`无关系`
  (解析失败=无回执,诚实铁律)。
- **活期**:`settle-only`——流光动词 + 读秒,无活窗(args 仅 kind/id/depth 三小字段)。
- **落定体(星图形态,count≤24 且 depth=1)**:**RelationStarMap**——中心=被查实体大 pill
  (kind 字形 + name),左列=入边(谁在用它,`toId==查询id` 的边),右列=出边(它在用谁),
  连线 = CustomPaint 软色 bezier(入边指向中心、出边离开中心,箭头沿线)。**边动词 chip**
  (edge `kind`,开放集原样小写显示,如 `equip`/`link`,不做枚举映射)挂在线的**外端**、
  紧贴对端 pill 之前——随 pill 行垂直排布、天然不叠(挂线中点在扇入收窄区必然大面积互叠:
  720 阅读列三列布局中点区横向不足 100px,远低于 24 边即不可读);同一对端多条边合并为
  **一个 pill + 多 chip 串**。节点=AnRefPill(fromName/toName 现成)。窗底 meta 行:
  `N 关系 · 深度 d`。
- **落定体(列表退化,count>24 或 depth>1)**:分组列表——与查询实体**直接关联**的边
  (fromId 或 toId==查询id)分「被引用(入边)」「引用(出边)」两个 AnGroupLabel 节,行=
  `AnRefPill(对端) · kind chip · updatedAt(13 faint)`;depth>1 多跳邻域里两端都不是查询
  实体的边(如查 A 时的 C→B)**无「对端」可言、严禁塞入入/出组**(按 toId==查询id 分组
  会把非关联边错归方向,删前查影响面时错报依赖方向后果最重)——单列第三节「间接关系」,
  行显双端 `AnRefPill(from) → kind chip → AnRefPill(to)`(两端都画、方向由箭头承载,
  不假设对端);封顶 200 行 + `…还有 N 条`(N+ 诚实计数)。
- **退化态**:`count:0` → 单行居中「无关系——此实体未被引用、也未引用他物」(15 muted,
  这正是删前查影响面的黄金答案,值得一句完整话而非空白);`REL_INVALID_REF`/depth 越界
  → 底盘失败态(红,错误串在体内机器窗);attrs 有值时收进行尾 AnDisclosure(JSON 树)。
- **交互**:AnRefPill 点击派 `{kind,id}` select intent,**intent 层按 kind 路由归宿**
  (function/handler/agent/workflow/trigger/control/approval/skill → 实体海洋详情;
  document → documents 海洋;mcp → settings——relations kind 是开放集,统一派实体海洋
  对非居民 kind 是死链或错页);无归宿 kind(如 conversation)AnRefPill 传 `onTap:null`
  惰性化(pill 仍显示、不撒谎);中心 pill 同理;逃生口=窗右上「原始 JSON」切 AnJsonTree
  (`jsonViewport` 有界)。
- **新原语**:**RelationStarMap**(feature 层,~200 行):中心 pill + 双列 pill + CustomPaint
  连线层;**不**复用 1270 行 AnGraphCanvas(其节点模型是 workflow 五 kind 卡,关系邻域是开放
  实体 kind 集,硬套=错抽象);gallery-first 配 specimen(空/1 边/24 边[验收外端 chip
  零互叠 + 同对端多边合并]/敌意长名)。
- **Wow**:删除前的「影响面」第一次**看得见**——爆炸半径不再是 LLM 转述的一句话,而是一张
  以目标为圆心的星图,每颗卫星都能点过去。
- **可行性**:输出行自带 fromName/toName(RelationView 已解析)=星图零额外请求;`count` 顶层
  现成供回执;depth3 hub 实体可达数百边——24 上限是星图可读性红线,列表退化必备;边 `kind`
  开放集,chip 原样显示不猜语义。

---

### `capability_check_workflow` — 正在体检工作流 → 已体检工作流(Health-checking workflow → Health-checked workflow)

- **收起行**:workflow 实体形 icon · 动词 · chip=`args.workflowId`(mono)· 回执四态:
  `ok:true` 且 `resolved:false` → `结构通过 · 未验引用`(warn 琥珀——目录未接入=半张体检单,
  收起行是历史目录里的常驻形态、多数行永远不被点开,半检只藏展开体 warn badge = 伪装全过,
  违「半成功必须显性」);`ok:true` 且 `resolved:true` 且 warnings 空 → `通过`(ok 绿);
  `ok:true` 且 `resolved:true` 有 warnings → `通过 · N 提醒`;`ok:false` → `N 项阻塞`
  (**danger:true → 红 + 自动展开一次**——体检出病要立刻给用户看)。解析器防御分支:
  `ok:false` 且 problems 空(契约五字段独立布尔、不保证 ok:false ⟹ problems 非空)→
  回执落 `未通过` 不带计数(「0 项阻塞」自相矛盾,比无回执更失诚),danger 与自动展开不变。
- **活期**:`settle-only`(catalog 逐实体解析有真耗时,读秒是诚实的活感);无活窗。
- **落定体(体检报告卡)**:ToolWindow 内三段——
  ① **指标行**(报告头):两枚 AnBadge —— `结构` structurallyValid(ok/danger)· `引用解析`
  resolved(ok / **warn「目录未接入,未验引用」**——resolved:false 必须显性,这是半张体检单);
  ② **problems 节**(有则):ToolChecklist 行,✗ 红 glyph + 原文(mono 13,机器产物住窗内),
  逐条;③ **warnings 节**(有则):⚠ 琥珀 glyph + 原文。全清 → 单行 ✓ 绿「无发现」。
  ④ **窗底诚实注脚**(固定 i18n,源自工具自述):「体检不验数据流——干净报告仍建议 trigger
  实跑一次确认」(13 faint)。
- **退化态**:problems/warnings 超长(>40 条)→ AnFadeCollapse(fadeColor 传 surfaceSunken);
  `WORKFLOW_NOT_FOUND`/`WORKFLOW_NO_ACTIVE_VERSION` → 底盘失败态;输出解析失败 → 无回执 +
  通用体。
- **交互**:workflowId → AnRefPill 跳 workflow 详情;报告卡无其它动作(读物)。
- **新原语**:**ToolChecklist**(feature 层,~60 行):`rows: [(glyph 状态, text)]` 逐行
  status glyph(✓/✗/⚠ 语义色)+ mono 文本——体检/预检类通用件(mount CheckHealth、未来
  agent 预检同构复用)。
- **Wow**:「体检报告」隐喻落到实处——不是一坨 JSON 布尔,而是一张有指标行、红黄分区、
  带医嘱注脚的报告单;`ok:false` 自动展开=坏消息从不藏折叠后面。
- **可行性**:输出五字段全顶层、无嵌套歧义,回执/指标行提取零风险;problems/warnings 是
  字符串数组(原文展示、不解析内部格式);体积小(问题条数级),封顶仅防御性。

---

### `search_tools` — 正在检索工具 → 已检索工具(Searching tools → Searched tools)

- **收起行**:放大镜 icon · 动词 · chip=`"args.query"`(带引号,partial 容忍)· 回执:解析
  输出——JSON 成功 → `tools.length` 个:`N 工具`(契约上限 5);JSON 失败且前缀
  `No tools matched` → `无匹配`;其余解析失败=无回执。
- **活期**:`settle-only`(纯词法匹配,亚秒级,通常连读秒都不出现);无活窗。
- **落定体(工具箱命中列)**:逐命中一张**极薄卡**(AnInfoCard 无边风格,靠留白分组):
  首行 = mono 工具名(`AnText.codeInline`,15 档)+ **参数摘要 chip 串**——从
  `parameters.properties` 派生的一行:`query*, limit`(required 星标;**滤掉框架注入的
  summary/danger/execution_group 三字段**——它们是横切样板、每个工具都有,展示即噪音;
  完整 schema 在逃生口不删减);次行 = description(13 muted,>3 行 AnFadeCollapse)。
  每卡尾行 AnDisclosure「参数 schema」→ AnJsonTree(`jsonViewport` 有界,完整含三注入字段)。
- **退化态**:无匹配 → 软字符串原文进单行体(15 muted,后端句自带改道建议,原样陈列即可);
  description 缺失 → 只名行;schema 解析失败 → disclosure 内诚实显 AnJsonTree 的错误行。
- **交互**:AnDisclosure 逐卡独立展开;无 deep link(工具不是实体,无处可跳——诚实不硬造)。
- **新原语**:无新 widget;一个纯函数 `schemaParamDigest(Map schema) → List<(name, required)>`
  (~30 行,滤三注入字段 + required 集合并,无头单测)。
- **Wow**:模型「翻工具箱」这个元动作第一次可读——用户看见 agent 发现了什么能力、每个候选
  长什么样,像逛一排插件卡而不是滚一屏缩进 JSON。
- **可行性**:唯一**缩进 JSON** 输出(census:MarshalIndent)——`jsonDecode` 无所谓缩进,
  回执/卡片解析不受影响;上限 5 命中=体永远有界;动态 MCP 工具也走此路(F52),卡片文法
  对 `mcp__server__tool` 名照常成立(mono 名自然容纳双下划线)。

---

### `get_model_config` — 正在读模型配置 → 已读模型配置(Reading model config → Read model config)

- **收起行**:芯片形 icon(补精确表)· 动词 · **无 chip**(零参数,动词自足)· 回执:
  `apiKeys.length` + `availableModels.length` → `N key · M 模型`(解析失败=无回执)。
- **活期**:`settle-only`;无活窗(零参数、亚秒返回)。
- **落定体(配置全景,三段)**:
  ① **默认模型**:AnKv 三行(dialogue/utility/agent,按输出 map 迭代、场景集开放)——值=
  modelId(mono)+ 所属 key displayName(13 faint);`"not configured"` → AnBadge warn
  「未配置」(半空盘要显眼,这正是 agent 查它的原因);
  ② **API keys**:AnThinTable 四列 `displayName · provider · keyMasked(mono)· testStatus`
  ——testStatus 开放集:`ok`→AnBadge ok、含 `fail/error`→danger、其余原样 none tone(不猜);
  keyMasked 恒脱敏是后端铁律,UI 前缀锁形小字符强化「永无明文」;
  ③ **可用模型**:按 provider 分组(AnGroupLabel),行=`modelId(mono)· displayName ·
  contextWindow`(tabular,`128000` 显 `128k`);**硬封顶**:每 provider 组 12 行、全节
  50 行,超出行尾 `…还有 N 条`(N+ 诚实计数),全量走窗右上「原始 JSON」逃生口——
  AnFadeCollapse 只裁视口不裁构建(palette 明载 NeverScrollable 视口裁切、child 全建),
  AnThinTable 每行 intrinsic 重测,OpenRouter 类目录可达数百行:全量建表 jank 真实存在、
  展开态更是 transcript 行内无界高度,双违宪法 §8;AnFadeCollapse 只留给封顶内的收合。
- **退化态**:availableModels 空(catalog 尽力而为、读失败返空数组)→ 该节单行诚实
  「模型目录不可用或为空」(13 muted,不装没事);apiKeys 空 → 「未配置任何 API key」;
  整体解析失败 → 通用体。
- **交互**:无实体 pill(key/model 非 Quadrinity 实体);逃生口=窗右上「原始 JSON」切
  AnJsonTree(`jsonViewport` 有界,含全量模型目录——③ 节封顶后的完整事实源);预留
  「打开设置」尾动作(设置海洋即模型配置归宿)——nav intent 现成后一行接入,V1 可无。
- **新原语**:无——AnKv + AnThinTable + AnBadge + AnGroupLabel + AnFadeCollapse 全现成,
  纯组装。
- **Wow**:一眼全景「这台机器现在用什么脑子」——三场景默认、每把钥匙的健康灯、整个模型目录,
  排成一张仪表盘,而 agent 侧永远只见脱敏——UI 与后端在「不泄明文」上同一条战壕。
- **可行性**:三段结构顶层稳定;`defaultModels` 值是 union(对象 | 字符串 "not configured")
  ——解析须先 `is Map` 判型再走对象路径,字符串即未配置(census 明载,零猜测);体积中等
  (key 数 × 目录),③ 节硬封顶 + JSON 逃生口兜底(目录规模无上界,收合不裁构建、不够)。

---

## 族级新原语汇总

| 原语 | 层 | 量级 | 能力一句话 |
|---|---|---|---|
| **RelationStarMap** | feature(chat/ui)| ~200 行 + gallery specimen | 中心实体 pill + 入/出双列 AnRefPill + CustomPaint bezier 连线的只读星图(边动词 chip 挂线外端贴对端 pill,同对端多边合并一 pill 多 chip);count>24 或 depth>1 自动退化分组列表(直接边入/出两节 + 间接关系双端行) |
| **ToolChecklist** | feature(chat/ui)| ~60 行 | 状态 glyph(✓/✗/⚠ 语义色)+ mono 文本的逐行检查单;体检/预检族通用(mount CheckHealth 同构) |
| `schemaParamDigest` | 纯函数 | ~30 行 + 单测 | JSON Schema → 参数摘要行(required 星标,滤框架注入三字段) |

另:AnIcons 精确表补两条(`get_relations` → 关系形、`get_model_config` → 芯片形),否则双双落兜底扳手。

## 族内建造顺序建议

1. **四工具 catalog 条目 + 回执解析器**(动词对/chip/计数回执,体先走通用)——收起行先全部
   正确,一次提交,族即「不无声」。
2. **capability_check 报告体 + ToolChecklist**——价值/成本比最高(纯现成原语 + 60 行新件),
   且 ToolChecklist 是族外可复用资产。
3. **get_model_config 全景体**——零新原语纯组装,验证「三段陈列」文法。
4. **search_tools 命中列 + `schemaParamDigest`**——AnDisclosure/AnJsonTree 现成,函数带单测。
5. **get_relations 列表退化形态**——先上分组列表(直接边入/出两节 + 间接关系双端行,
   零新绘制代码,功能完整)。
6. **RelationStarMap 星图升级**——族内唯一新绘制原语,gallery specimen 先行(纪律),
   最后上;列表形态已兜底,星图纯增益、无阻塞。


---

# F13 mcp-mgmt — 完美态设计

> 族成员(4):`list_mcp_marketplace` / `install_mcp_server` / `uninstall_mcp_server` / `reconnect_mcp`。
> 线缆源:census/08-mcp-web.md §1–4(search_mcp_calls / get_mcp_call / 动态 `mcp__` 不在本族)。

## 族级统一文法

- **身份:插头族**。MCP 管理是对话里「插拔外接能力」的动作,图标统一 **plug**。⚠️物理核验
  (`core/ui/icons.dart:158-168`):关键字链对四个名字**无一命中**(`install_mcp_server` 不含
  shell/search/file/web/实体词,也不以 `mcp` 开头)→ 现全落扳手兜底。**须把四名登记进
  `_toolExact` → `AnIcons.mcp`**,不依赖推断。
- **cautious+ 族约定:summary 常显**——四工具展开体首行一律 `_intent`(LLM 自报意图,窗上方;
  `tool_card_skins.dart` 头注已预留 F3/F13/F14)。
- **失败模型:与 web 族相反,失败是真 Go err** → 底盘 failed 相位(红 + 自动展开)天然成立,
  无「假成功真失败」文案判别负担。错误 code 可辨(sentinel),按族分层渲染。
- **共享落定体**:install / reconnect 同返 `ToJSON(*ServerStatus)` → 共用 `McpServerStatusCard`。
- **状态色谱**(单一映射函数,receipt 尾与体内徽章同源):
  `ready→ok(绿) · degraded→warn(琥珀) · failed→danger(红) · connecting→accent · disconnected→inkFaint`。
- **target chip**:一律取 `name` arg(`argStringPartial` 容忍流中片段);install 的 registry 全名
  截末段显示(`io.github.upstash/context7` → chip `context7`),全名进体内。
- **大体量纪律**:ServerStatus 的 `tools[].inputSchema` 原样透传、几十 KB 级——**绝不整体 dump**,
  `jsonDecode` 后按行惰性(AnDisclosure → 有界 AnJsonTree),schema 永不转 string 内联。
  **「parse 一次」的承载点 = 卡的 view-model/state 层**(底盘 `ToolCardSpec.receipt(t,state)` 是
  build 期纯函数,transcript 滚动/主题切换等 rebuild 会对每张落定卡重跑,不能把 decode 放在它里面):
  解析物按 output identity(toolCallId + 内容 `identical`/哈希判等)memoize,**receipt 与展开体
  同源取同一份解析物**;marketplace 回执更轻——ToJSON 紧凑单行、`"count":N}` 恒在尾,
  尾部轻量正则提取 count,免全量 decode。

---

### `list_mcp_marketplace` — 正在浏览 MCP 市场 → 已浏览 MCP 市场(Browsing → Browsed MCP marketplace)

- **收起行**:plug · 动词 · chip=`"query"`(quoted;缺省/空=逛全目录,无 chip、动词自足)·
  回执=顶层 `count` **尾部轻量提取**(`"count":N}` 恒在尾,免全量 decode,见族级大体量纪律)→
  `N 个 server`;`count=0` → 「无匹配」。
- **活期**:`settle-only`(无 progress、args 仅一短 query)——流光动词 + 读秒即全部,不加戏。
- **落定体**:意图行 + **市场货架 `McpMarketList`(住 ToolWindow 凹陷窗内)**:每行 = mono server 名(emphasis 字重)+
  runtime 徽章(AnBadge:`node/python/docker/dotnet` 中性 tone、`remote` accent)+ 描述单行截断 +
  **env 需求 chips**:必填键实底 chip、可选键 faint + 「可选」字样——**F169 铁律:optional 绝不
  呈现成必填**。封顶 20 行 + 诚实注记「…还有 N 个(收窄 query 可精确)」——输出按命中词数降序,
  截断天然留最优。
- **退化态**:`count=0` → 窗内单行「无匹配 server」;JSON 解析失败 → 无回执 + 通用 raw 机器窗
  (capped);无过滤全目录 ~96 条 → cap 兜住,注记给真实总数。
- **交互**:行 hover 现 copy 钮(拷 registry **全名**,用户下一句「装它」零摩擦);无 deep link
  (未安装、无实体可跳)。
- **新原语**:`McpMarketList`(feature 层组合件:AnBadge + mono + chips + cap + copy)。
- **Wow**:LLM 替你逛街,你直接看到货架——名字/跑什么 runtime/要哪些钥匙一眼全,连模型的
  回复文本都不用读就能拍板装哪个。
- **可行性**:回执走尾部提取零 decode;货架体解析按族级 memoize 纪律(output identity 判等,
  rebuild 零重解);`env[].required` 布尔线缆已保真(F169 修复),UI 只消费不猜。

---

### `install_mcp_server` — 正在安装 MCP server → 已安装 MCP server(Installing → Installed)

- **收起行**:plug · 动词 · chip=name 末段 · 回执=ServerStatus 解析:`ready · N 工具`(ok)/
  `degraded`(warn)/ `failed`(danger → 底盘自动展开)。
- **活期(族魂,持久态)**:数据源 `progress 流`——`ensureEnv` 各阶段实时流入,行格式
  `[<stage>] <msg> (<pct>%)`。**`ToolStageTail`**:解析尾行 `[stage]` 前缀 → 当前阶段作 13 号
  流光标签(`npx` / `docker pull`…),下挂 mono 尾 4 行;百分比**原样留在行内文本**(底盘钦定
  读秒绝不进度条)。3 分钟超时窗内读秒常伴。**OAuth 型 remote 阻塞授权期线缆零 progress 帧**——
  退化为纯读秒。此退化标注为**已知盲区**:用户此刻其实该去浏览器点同意,读秒却暗示「机器在干活」,
  可能盲等到 3 分钟超时。按迭代铁律②提最小后端改动——OAuth 进入阻塞前经**现成 ensureEnv progress
  管道**发一行 `[oauth] waiting for browser authorization`,`ToolStageTail` 零改造即呈现;
  该后端改动落地前维持纯读秒,**不许前端伪造此阶段**。
- **落定体**:意图行 + **`McpServerStatusCard`(住 ToolWindow / 同 surfaceSunken 的专门卡面)**:
  ① 头行:`AnRefPill(kind: mcp, label: 全名)` **onTap 传 null(AnInteractive 惰性态,纯标注)**——
  产品已拍板 MCP 集成进 **settings 海洋**(非实体面板、该面尚未建),select intent 现只对实体 kind
  有路由,「跳 server 面板」是死链;字形无碍(`AnIcons.byKey` 已登记 `mcp→plug`,物理核验
  `icons.dart:129`,非 '?' 兜底)。**替代 affordance:行 hover 现 copy(拷 registry 全名 / mcp_ id)**。
  「跳 server 配置面」为**后置项**:①settings-MCP 面落地 ②select intent 路由扩展支持非实体 kind,
  两者齐才接线。头行另配状态徽章(tone 映射 + AnStatusDot)+ `connectedAt` 相对时;
  ② **工具清单逐项点亮**(`McpToolsList`,settle 后 stagger 浮现,reduced→即时):每行 mono
  工具名 + 描述单行截断,行尾 AnDisclosure chevron → 该工具 `inputSchema` 的 AnJsonTree
  (`jsonViewport` 有界)——schema 惰性、绝不内联;封顶 30 行 + 「…N more」。
- **半成功(必须显性)**:`status=failed` + `lastError`(**连接失败仍落盘**是线缆事实)→
  AnCallout(warn):「server 已落盘但连接失败:<lastError> —— reconnect 可恢复」。
- **退化态**:失败相位按 code 分层——`MCP_ENV_MISSING`:错误文本可解析出缺失键则渲「缺少环境
  变量」+ 键名 chips,解析不出**只显原文**(诚实铁律:不猜);`MCP_NAME_CONFLICT` → 单行
  「同名已装」;`MCP_REGISTRY_NOT_FOUND` / `MCP_NO_RUNNABLE_PACKAGE` / OAuth 4 错 → 原文机器窗;
  `tools:[]` → 「该 server 未通告任何工具」。
- **交互**:AnRefPill 惰性(跳转是后置项,见落定体①)+ 头行 hover copy 全名/id;工具行 copy 名;
  schema 树可折叠。
- **新原语**:`ToolStageTail`(通用 stage 进度尾)+ `McpServerStatusCard` + `McpToolsList`。
- **Wow**:装一个 server 像看包管理器现场施工(阶段一节节报),完成瞬间货舱门打开——新工具
  一件件亮起来,「能力被插上」全程可视。
- **可行性**:name/env args 小、流入顺序无碍;progress 行格式线缆确定(OAuth 阻塞期零帧,
  `[oauth]` 行是待落的后端最小改动,见活期);ServerStatus JSON 几十 KB → 按族级大体量纪律在
  view-model 层 memoize(output identity 判等)+ 惰性渲染,receipt 同源;`MCP_ENV_MISSING` 的
  `Details.missing` 是否进 tool 面错误文本**待真线缆核验**,解析器按「不匹配即原文」设防。

---

### `uninstall_mcp_server` — 正在卸载 MCP server → 已卸载 MCP server(Uninstalling → Uninstalled)【薄卡】

- **收起行**:plug · 动词 · chip=name · **无回执**(过去时动词即凭据;输出是纯文本模板
  `Uninstalled MCP server "<name>".`,不含可再提炼的量)。
- **活期**:`settle-only`,流光动词 + 读秒。
- **落定体(薄)**:意图行(summary 常显——删配置含加密凭据,用户须见自述)+ 单行机器窗回显
  后端原文。危险确认走底盘 awaitingConfirm 相位(V6 内联确认卡落地后接管),卡自身零堆料。
- **退化态**:`MCP_SERVER_NOT_FOUND` → failed 红 + 自动展开原文;name 空的校验错是
  `fmt.Errorf` **非 sentinel**(线缆注记:无稳定 code,走通用失败文案)。
- **交互 / 新原语**:无;全复用(ToolWindow + `_intent`)。
- **Wow**:克制即完美——删除类一行进一行出,危险感交给确认相位而非视觉。

---

### `reconnect_mcp` — 正在重连 MCP server → 已重连 MCP server(Reconnecting → Reconnected)

- **收起行**:plug · 动词 · chip=name · 回执=ServerStatus 同一映射:`ready · N 工具`(ok)/
  `degraded`(warn)/ `failed`(danger → 自动展开)。
- **活期**:`settle-only`(Reconnect 不走 ensureEnv,无 progress 帧)——流光 + 读秒,诚实不加戏。
- **落定体**:意图行 + 复用 **`McpServerStatusCard`**,以 `emphasis: health` 变体强调体检面:
  状态徽章 + AnKv(dense)健康行(`consecutiveFailures` / `totalCalls` / `totalFailures` /
  `connectedAt`)+ 刷新后的工具清单(同 install 的惰性 schema 行)。settle 到 ready 时徽章一次
  ok 呼吸脉冲(AnMotion.breath 单拍;reduced→静态)——「复活」的瞬间。
- **退化态**:重连后仍 `failed` → danger 回执 + `lastError` 单行 + 「可再次 reconnect / 检查 env」
  提示;`MCP_SERVER_NOT_FOUND` → failed 原文。
- **交互**:AnRefPill 惰性 + 头行 hover copy(同 install 落定体①,跳转为后置项);工具清单同 install。
- **新原语**:无新增(McpServerStatusCard 加一个 health 强调开关)。
- **Wow**:按下重置按钮,卡片直接递上体检报告——活没活、连败清没清、工具还在不在,一屏定案。
- **可行性**:返回同 install(全 tools + schema),同一 memoize+惰性路径(receipt/体同源单份解析物);
  无 progress 是线缆事实,活期不虚构。

---

## 族级新原语汇总

| 原语 | 层 | 能力一句话 |
|---|---|---|
| `ToolStageTail` | feature(通用) | 阶段化进度尾:解析 `[stage] msg (pct%)` 行,当前 stage 作流光标签 + mono 尾行;reduced 静态。install 首用,任何 staged-progress 工具可复用 |
| `McpServerStatusCard` | feature | ServerStatus JSON → 头行(惰性 AnRefPill + 状态徽章 + 时间)+ 可选健康 KV + 工具清单 + 半成功 AnCallout;install/reconnect 共用。**渲染于 ToolWindow(或同 surfaceSunken 的专门卡面)内,清单行永在窗内**——机器产物不借 thinking 裸文法,与 builds 结果条挂 ToolWindow 先例对齐 |
| `McpToolsList` | feature | 封顶工具行清单:mono 名 + 描述截断 + 行内 AnDisclosure→有界 AnJsonTree(inputSchema 惰性);settle 逐项点亮(reduced 即时) |
| `McpMarketList` | feature | 市场货架行:runtime 徽章 + env chips(必填/可选二色,F169)+ cap 诚实注记 + hover copy 全名。**渲染于 ToolWindow(或同 surfaceSunken 的专门卡面)内,货架行永在窗内、绝不裸铺散文层** |

零新 core 原语,全部 feature 层组合件。随附两件小事:①状态 tone 映射函数(receipt/徽章单源);
② `icons.dart _toolExact` 补四条 → `AnIcons.mcp`(现全落扳手兜底,物理核验过推断链)。

## 族内建造顺序建议

1. **缝先行**:`_toolExact` 图标四条 + i18n 动词对 + catalog 四条目 + receipt 解析器
   (ServerStatus 状态/工具数、marketplace count 走尾部提取、uninstall 纯文本模板)进 `tool_receipts`,
   **同步落 ServerStatus 解析物的 view-model 层 memoize 承载点**(receipt/体同源,见族级大体量纪律)。
   install 的 liveBody 先直挂现成 `ToolLiveTail`(progress 已能看)。**uninstall 至此完整落地**(薄卡零新件)。
2. **共享体**:`McpServerStatusCard` + `McpToolsList`(一次建、install/reconnect 两卡受益)→
   **reconnect 完整**。
3. **族魂动效**:`ToolStageTail` 替换 install 的 ToolLiveTail + 工具清单点亮 stagger →
   **install 完整**(此步依赖真线缆 progress 行核验;OAuth 阻塞期 `[oauth]` 行是待落的后端最小改动,
   未落地前活期维持纯读秒不伪造)。
4. **货架**:`McpMarketList` → **list_mcp_marketplace 完整**。

顺序理由:先缝后体、共享体优先摊薄成本、动效最后(其一依赖真机 progress 核验,其二第 1 步的
ToolLiveTail 兜底已保证 install 活期从 day-one 不哑)。


---

# F14 — mcp-dynamic + generic 兜底族 完美态设计

> 覆盖:`mcp__<server>__<tool>`(动态包装,∞ 个)+ **generic 通用兜底卡**(一切未编目工具的地板)。
> 线缆真相:census 08 §7(动态 MCP)+ census 10(框架三字段/tool_result/progress)。
> 族性:**cautious+**——LLM 自报 summary 常显于窗上方(现有 `_intent` 文法,F3/F13/F14 同盟);
> danger=dangerous 走底盘 V6 确认卡。本族无 edit 类,morph 全员 N/A。

## 族级统一文法 —— 零 schema 成形引擎 `sniffShape()`

本族的「完美」不靠 schema 知识,靠一套**纯函数嗅探管线**把任意 args/result 字符串「成形」
为五种既有母语之一(框架无关纯模型层,同 `BlockTreeReducer` 待遇:脱 widget 单测五电池):

| 形 | 嗅探条件(按序短路) | 呈现(全部住机器窗) | 流式 |
|---|---|---|---|
| **媒体占位** | 全文仅由 `[image: mime]` / `[audio: mime]` / `[resource: uri]` 标记行构成(joinContent 产物) | 每标记一枚占位 chip(图标+mime/uri),下注「内容未随行传输」——诚实:线缆只有标记无字节 | settle-only |
| **KV 表单** | JSON 且为**扁平对象**(值全是标量,≤14 键) | `AnKv` 行(键 13 / 值 15,mono 值) | **A**(活期逐键点亮,见下) |
| **表格** | JSON 且为**均质对象数组**(≥2 行、共享键 ≥2、≤6 列全标量) | `AnThinTable`,行封顶 30 + 「…N more」诚实尾行 | C |
| **树** | 其余合法 JSON(深/大) | `AnJsonTree` @ `AnSize.jsonViewport`(240 有界) | C(settled 才上,免展开态丢失) |
| **文档** | 非 JSON 且 markdown 密度过阈(标题/围栏/列表行占比 >25%,保守) | 默认 capped mono;窗头给「排版查看」切换 → `AnMarkdown` 入 `AnFadeCollapse`(400 收合,fadeColor=surfaceSunken) | B |
| **纯文本**(兜底) | 一切其余 | `_cappedMono`(6000 chars + 诚实截断注记) | A |

**诚实链三件套**(两卡共用):
1. 框架截断标记 `...[tool result truncated: X of Y bytes shown — …]` → 解析剥离,化为**灰**回执「截 X/Y KB」(框架标记给了精确字节数,直陈比模糊更诚实;N+ 记法留给只知下界的计数)+ 窗底显式截断注记(不把标记当内容渲)。**截断≠失败**:回执不入 danger 色族、不触发自动展开——256KB cap 对话痨 server 是常态,「成功但大」若逐个自动炸开,历史就不像目录了;danger 色与自动展开只留给真失败态。
2. 空结果 `""` → 回执灰字「无输出」,无窗。
3. 嗅探绝不篡改:文档形默认仍是 mono 原文,「排版查看」是用户主动切换——防 markdown 误判替用户做主。

**性能纪律(宪法 §8)**:shape 结果(五形判定 + 解析产物 + 回执串)在 state 层于 **settle 时刻
计算一次、按 block id 缓存**——**settle 单次成形、build 零解析**。嗅探(64KB 采样+decode)、回执
计数(对 ≤256KB 文本数行/数项)、表格/树成形一律不进 build():transcript 里任何其他卡在流式都会
带着可见卡整列 rebuild,build 内解析 = 逐帧重 decode。AnJsonTree 永远喂**同一个已解析对象引用**
(它按 data 引用变即整树重建、丢用户展开态)。单测钉:同串重 build 不再触 decode。

**活期母语「JSON 成形为表单」**(宪法 §设计母语):args delta 流入时,对 ≤2KB 的片段每帧
(合并 ≤1/frame)做 repair+decode——用户看着调用表单被逐项填写。**「点亮」完成判据(不靠
repair 补的闭合)**:一个键值对仅当**原始 args 文本**中该值之后已出现 `,`+下一键引号 或 终结
`}` 才算闭合、淡入点亮——jsonrepair 每帧会把未闭合值补闭合(`{"query":"hel` 每帧都「看似完整」),
不设此判据行会先点亮再连续突变。最后一个在流的 pair 以「生长中 mono 值」呈现(不淡入不定格);
**数字/布尔/嵌套对象一律闭合后才显示**(非 string 标量无 partial 语义:`12`→`123`、`tru` 的
repair 行为未定义),嵌套对象值闭合后显示为紧凑 JSON 串。框架键 summary/danger/execution_group
的剥离**顺序无关**:每帧对 repair+decode 出的 map 按键名整键剔除、再渲余键(census 10 只说
「通常最先到达」,到达顺序不可依赖,execution_group 还是可选键、可在任意位置出现)。片段 >2KB
或 repair 失败 → 退化为 mono 尾 8 行(builds 活窗同款)。reduced motion:淡入即时化。
闭合判据 + repair 突变样本 + 「框架键晚到」均入五电池单测。

---

### `mcp__<server>__<tool>` — 动词对(正在调用 → 已调用)

- **收起行**:plug 图标(AnIcons `mcp*→plug` 已命中)· 动词 · 目标 chip = **确定性拆名**:剥
  `mcp__` 前缀后按**第一个** `__` 切,左=server、右余全量=tool(toolName 是上游任意串、自身可含
  `__`,朴素 split('__') 会拆错段)→ `<server> · <tool>`(如 `context7 · query-docs`,mono,
  AnSize.block 封顶省略);不匹配前缀或切不出两段 → 整名原样 mono 呈现(诚实兜底,入极值电池)
  · 回执见下。server 段是身份主角——同 server 的连续调用在目录里天然成组可扫。
- **回执**(全部确定性解析,不猜):结果为 JSON 数组 → 「N 项」;多行文本 → 「N 行」;
  媒体标记形 → 「N 媒体」;空 → 「无输出」;带框架截断标记 → 灰「截 X/Y KB」(截断≠失败,
  不入 danger 色族、不触发自动展开);失败 → 底盘红标 + **sentinel 消息前缀分类徽章**(见退化态;
  线缆上拿不到 wire code——本族失败是**真 Go err**,与 Web 族假成功相反)。
- **活期(生长秀)**:三层叠加——
  ① `args-partial`:KV 成形窗(上表活期母语),调用表单逐项点亮;
  ② `progress 流`:server 发 progress notification 时切 `ToolLiveTail`(行格式 `<msg> (n/total)`);
  ③ 尾行若含 `(n/total)` 且 total>0 → 行尾读秒旁附**活比数** `n/total`(tabular 数字,替进度条——
  底盘钦定读秒绝不进度条,比数是文字不是条)。不发进度的 server 停在 ①。
- **落定体**:intent(summary)→ 「请求」机器窗(窗头 `<server> · <tool>` 回显 + copy)装
  args 成形(KV/树)→ progress 有留痕则 `AnDisclosure`「过程 N 行」收着完整 progress 窗(capped)
  → 「结果」窗装 result 成形(五形嗅探)。两窗一律有界,逃生口=「查看全文」(AnFadeCollapse 展开,仍受 6000 cap + 注记)。
- **退化态**:空 args(`{}`)→ 无请求窗;result 解析失败 → 纯文本兜底;失败 → 自动展开,错误窗
  顶行徽章(AnBadge danger)按**稳定 sentinel Message 前缀**分类——线缆上 tool_result output =
  `errorspkg.Surface(err)`,只有 Message + 拍平 details 文本(格式 `mcp tool call failed (reason=…)`),
  **wire code 不进任何字符串**(census 08 的「UI 可辨 code」只对 HTTP N1 envelope 成立):
  `mcp server not connected` / `mcp tool call failed` / `mcp tool call timed out` 三个稳定前缀 →
  前端映射表给显示用徽章文案;reason 提取 = 剥前缀 `(reason=` + 剥尾 `)`(该路径 Details 单键,
  确定性成立),原文直陈(server 自己点名坏字段,triage 直接可读);前缀不中或解析不中 → 整段
  Surface 文本原文直陈(诚实兜底)。**永远读 tool_result output、不读 close.error**(后者 =
  err.Error() 全包裹链,泄 Go 面包屑如 `mcp.Client.CallTool s/t: …`)。cancelled → 底盘中断态。
- **交互**:server 段可点 → nav intent 去 MCP server 实体面(settings-mcp 集成面);结果窗 copy;
  「排版查看」切换(文档形)。
- **新原语**:`sniffShape()` 纯函数 + `ShapedView`(feature 层,五形渲染门面)· `LiveKvForm`
  (活期 KV 点亮窗)· `MediaMarkerChip`(媒体占位 chip,AnBadge 基底)· ToolWindow 加 `onCopy`
  头部 affordance(补 palette 缺口 #12)。
- **Wow**:装什么 server 都体面——schema 零知识下,调用表单在眼前逐项点亮、结果自动成形为
  表格/树/文档,失败时 server 的原话错误直陈坏字段;第三方工具获得一等公民卡。
- **可行性**:args 流序不可控,框架键剥离靠**逐帧按名剔除**、不依赖到达顺序(required 排首只
  保证「通常最先到达」,晚到的 danger/execution_group 不得以 KV 行漏进表单);result 本层无截断
  (仅框架 256KB 保头 cap)→ 嗅探入口先做 64KB 采样闸,超采样直接纯文本形;`(n/total)` 解析
  只认尾行严格 regex;server 徽标 deep link 只有 serverName 无 `mcp_` id,需名→id 解析缝
  (settings-mcp provider 反查,查不到则 chip 惰性不可点——诚实)。

---

### generic 兜底 — 动词对(正在调用 → 已调用)

一切未编目工具的地板(V3a 承诺:绝不无声)。重设计 = 把 F14 成形引擎下沉为地板,让「没人
给它写皮肤」的工具也自动获得 80 分呈现。

- **收起行**:`AnIcons.toolIcon` 关键字推断(未知永不崩,"?" 兜底)· 正在调用/已调用 ·
  目标 chip = 原样工具名(mono,不做人性化改写——诚实优先)· 回执 = 与 MCP 同一套确定性
  回执引擎(N 项/N 行/无输出/灰「截 X/Y KB」)。
- **活期**:`args-partial` → 同一 KV 成形窗(≤2KB 闸,超限 mono 尾);无 progress 约定
  (未编目工具若真发 progress,底盘 `progressText` 非空即自动切 `ToolLiveTail`——白捡)。
- **落定体**:intent(summary,cautious+ 常显)→ args 成形窗 → result 成形窗(五形嗅探)。
  与 MCP 卡唯二差异:无 server 徽标窗头、无 progress 比数解析。**同一 `ShapedView` 代码路径**,
  零复制。
- **退化态**:拒绝/取消 = **成功态 tool_result + 固定散文**(census 10 硬事实 #4)——底盘
  denied/cancelled 相位已认散文,本卡不重复判,且**该两相位抑制 result 成形窗**(body 对该
  tool_result 不建窗,固定散文只由底盘相位语法呈现一次、不以「纯文本形机器窗」二次示人;
  MCP 卡同一 ShapedView 路径、同规则);`input validation failed: …` 前缀 → 失败态错误窗;
  未知工具名 `tool %q not found` → 失败态原文陈列。
- **交互**:结果窗 copy;文档形「排版查看」切换;无 deep link(无实体身份可锚)。
- **新原语**:无新增——完全消费 MCP 条目下沉的 `sniffShape()/ShapedView/LiveKvForm`。
- **Wow**:兜底不再是「工具名 + 4000 字生肉」——任何一个明天才诞生的工具,落地即有表单点亮、
  结果成形、诚实回执;地板抬到别家皮肤卡的 80%。
- **可行性**:现有 generic spec(tool_card_catalog.dart L55)只换 body/receipt/liveBody 三缝,
  底盘零改;回执引擎须容忍任意二进制样文本(count 前先 UTF-8 有效性闸,乱码直接无回执)。

---

## 族级新原语汇总

| 原语 | 层 | 一句话能力 |
|---|---|---|
| `sniffShape()` | feature 纯函数(chat/model) | 任意字符串 → 五形判定(媒体/KV/表格/树/文档/纯文本)+ 截断标记剥离 + 64KB 采样闸;settle 时刻单次调用、结果按 block id 缓存;框架无关、五电池单测 |
| `ShapedView` | feature widget | 按 sniffShape 结果调度既有原语(AnKv/AnThinTable/AnJsonTree/AnMarkdown/_cappedMono)渲进机器窗,含「排版查看」切换与诚实注记;**settle 单次成形、build 零解析**——只消费缓存成形结果,AnJsonTree 复用同一解析对象引用(展开态不丢),同串重 build 不触 decode(入单测) |
| `LiveKvForm` | feature widget | 活期 args 成形窗:partial JSON 每帧 repair+decode,键值对按**原文闭合判据**逐行淡入点亮(尾 pair 生长中 mono 值,非 string 值闭合后才显);框架键逐帧按名剔除;>2KB 或失败退化 mono 尾;reduced motion 即时化 |
| `MediaMarkerChip` | feature widget(AnBadge 基底) | `[image:/audio:/resource:]` 占位 chip:类型图标 + mime/uri + 「内容未随行传输」注 |
| ToolWindow `onCopy` | core 增强(an_sunken_panel 头槽) | 机器窗头部一键复制整窗内容(补 palette 缺口 #12,全族受益) |

(候选延后:`AnLinkPill` URL 药丸——palette 缺口 #8,等真实 MCP 结果里 URL 密度证明价值再上。)

## 族内建造顺序建议

1. **`sniffShape()` 纯函数 + 五电池单测**(空/超长/海量/极值/注入)——引擎先行,零 UI 依赖。
2. **`ShapedView` + 回执引擎接入 generic 兜底**——先抬地板,全部未编目工具立刻受益,真线缆
   随手可验(任何 lazy 工具都是试验田)。
3. **MCP 动态卡身份层**:确定性拆名 target chip、plug 精确表项、sentinel 前缀错误徽章窗、
   progress Disclosure——在 2 的地基上只加身份与错误陈列。
4. **`LiveKvForm` 活期成形**(生长秀,含原文闭合判据、框架键按名剔除与 2KB 闸)+ `(n/total)` 活比数。
5. **`MediaMarkerChip` + ToolWindow onCopy** 收尾打磨;server 徽标 deep link 等名→id 解析缝
   就绪后点亮。


---

# F15 — subagent 族完美态(Subagent / get_subagent_trace,共 2)

> 线缆:census 03 §11–12 + census 10 §7(E3 嵌套三层锚链)。族魂:**对话里长出一个「小对话」**——
> 子代理的 thinking / tool 卡在缩进的嵌套 transcript 里活着;递归工具卡直接复用整套注册表。

## 族级统一文法

- **第三身份:嵌套对话框(SubTranscriptFrame)**。本产品已有两种声音:thinking 的低语(左 rail 散文)
  与机器窗(凹陷 mono)。子代理产物**两者都不是**——它是一段真的对话(text/reasoning/tool_call),
  故立第三身份:**左缩进 s16 + 2px accent-faint 竖界 + 顶部身份行**(type 徽章 `AnBadge` + `AnStatusDot`
  + 步数 chip)。竖界用 accent 色系、非 thinking 的 ink 灰 rail;但两者结构同是「左竖线+缩进」,
  **不能只靠色相判别**(faint accent 在暗色主题与色弱下与灰 rail 难分)——**身份行是首要判别器**
  (徽章=非颜色信号,不可省略),竖界外再加一层判别冗余(frame 极淡底 tint,或与 thinking 不同的缩进量);
  faint 档须两主题+色弱模拟对比核验后定。内部字号**不降档**(仍 15/13 双轨),层级靠缩进与竖界,不靠缩小字。
- **递归 = 全注册表复用,零新皮肤**:嵌套 transcript 里的 tool_call 一律走 `toolCardSpecFor` →
  `ChatToolCard`——子代理跑 Bash 就有活终端尾,create_function 就有代码流入窗,原样在缩进层活着。
  深度可 >1(subagent 内 invoke_agent 再嵌):缩进每层 +s16、**视觉封顶 2 层**(更深层保持同缩进,防右挤)。
- **双层流·双层持久**:live 靠 messages 流 E3(sub-message Open 的 `parentId` = 派它的 tool_call 块 id,
  BlockTreeReducer 已天然折成子树);reload 靠**落库的 sub-message**(attrs `parentBlockId`)重水合——
  与 invoke_agent(仅 Execution.Transcript 持久)不同,**子代理自身块深度 1 完整耐久**。⚠️持久性止步于
  深度 1:子代理内 invoke_agent 的嵌套 block 仅流、不落 message_blocks(census 03 §8),reload 后该内层卡
  退化为只显终果 + 「查看轨迹」入口——重水合依赖 F-agent 族 get_agent_execution 的 Execution.Transcript
  路径,跨族对齐。
- **琥珀上浮铁律**:子代理内的 dangerous 调用会经继承 ctx 的 broker **阻塞整个调用栈**(census 10 §5)——
  嵌套卡渲它自己的确认卡(V6),同时父 `Subagent` 收起行必须上浮琥珀态(等待确认 tell + rail 琥珀点),
  否则用户看到的是「卡死的父卡」。派生:子树里任一 tool_call awaitingConfirm → 父 state.nestedAwaiting。
  **首次触发自动展开一次并滚锚到嵌套确认卡**(沿用失败的「一次」规则:用户手动收起后不再弹)——整条
  调用栈已阻塞停摆,不能要求用户注意琥珀→手动展开→自己找确认卡;resolved 信号后按既有「完成后收拢」
  文法回收。
- **有界铁律**:子代理可跑几十步——live 只给**尾窗摘要**(最近 K 行),展开体 transcript 装
  **有界 stick-to-bottom 视口**(内滚),绝不让嵌套树直接撑开父 transcript。

---

### `Subagent` — 正在运行子代理 → 已运行子代理(Running subagent → Ran subagent)

- **收起行**:icon=agent 实体形(关键字 `agent` 命中)· 动词 · chip = `subagent_type`(args-partial:
  required 序里排 prompt 前,几乎最先流到;enum 三值 mono 显示)· 回执 = `N 步`(子树 tool_call 计数)
  + 可得时 ` · X tok`(sub-message Close 快照的 tokens)——树缺席则无回执(诚实)。**终态 tell 从
  sub-message Close 的 `status` 派生**(census 10 §7 携 status/stopReason;与身份行 AnStatusDot 同一
  数据源,零猜测、零前缀解析;reload 从重水合 sub-message 的 status 取同一真相):failed → 危险色回执尾
  + 按宪法自动展开一次;cancelled → 「已中断」灰注记——失败/中断 run 在目录视图里绝不与干净成功无异。
  nestedAwaiting → 行尾琥珀「等待确认」覆盖读秒。
- **活期(双层活感,本族的 wow 现场)**:①argsStreaming:prompt 是 PAYLOAD——小机器窗流入任务书
  (复用 builds 活窗文法,尾 8 行纯 mono)。②tool_call 关、sub-message 开:活体切成
  **SubagentDigestTail**——SubTranscriptFrame 里最近 K(≈5)行:已落定块渲成**收起态微行**
  (reasoning→「思考了」muted 单行;tool_call→复用 ChatToolCard 收起行,含各自回执),当前 open 块
  **全活**:reasoning shimmer 逐字、tool_card 带自己的 liveBody(子代理的 Bash 终端尾在嵌套里滚动)。
  顶缘 AnEdgeFade + 「前 N 步」计数。⚠️数据源:messages 流 E3 子树(非 args、非 progress)。
- **落定体(成果陈列,不是日志)**:意图行(summary)→ **终答收进 SubTranscriptFrame 身份内**——终答是
  子代理的话、不是父助手的,**绝不裸 AnMarkdown 直陈**(裸奔=与父气泡 prose 同文法同字阶,造成语音归属
  歧义,且违宪法「机器产物无裸散文」):在带同款 accent 竖界+身份行的 frame 里作嵌套对话的**钉住终块**
  (label「终答」,disclosure 收起时仍常显),渲 markdown、字阶保 15/1.6 阅读档——答案仍是主角;
  >50 行 AnFadeCollapse。其上 AnDisclosure「查看过程 · N 步」展开其余嵌套 transcript(有界视口 ~420px
  内滚;块按序:reasoning 默认折叠、text 渲 markdown、tool_call 全功能可展开)。去重自然成立:嵌套树末
  text 块与终答逐字节相同时,它**就是**钉住终块本身(终答本来就是嵌套对话的最后一块),不重复渲。
- **退化态**:ValidateInput 散文错(`prompt is required` / enum 拒 / 递归拒)→ failed 相位自动展开,
  错误散文进通用窗;非干净收尾 → **相位从 sub-message Close 的 status/stopReason 结构化派生**(收起行
  危险色/灰注记见上);F150 前缀格式仍不解析、原文如实渲进终答(诚实铁律:结构化状态定相位,前缀原文
  只作正文透传);cancelled → 嵌套树冻结在最后一帧、终答区显「运行已中断」;帧丢失致树空 → 只渲终答、
  无过程 disclosure;256KB 截断注记随 tool_result 原文透传。
- **交互**:终答一键复制;嵌套 tool 卡各自的交互(deep link / 复制)原样可用;nestedAwaiting 首次触发
  自动展开+滚锚到嵌套确认卡(族级铁律),用户手动收起后点行可再滚达。
- **新原语**:`AnStickViewport`(独立有界 stick-to-bottom 视口)+ `SubTranscriptFrame`(嵌套对话容器,
  组合前者)、`SubagentDigestTail`(块树的最近 K 行活摘要,复用收起行渲染)——见族级汇总。
- **Wow**:对话里真的长出一个会思考、会用工具的小对话——子代理的终端尾、代码流入窗在缩进层
  **原样活着**,整套卡片文法免费递归。
- **可行性**:E3 键名 stream=`parentId` / 落库=`parentBlockId`,reducer 已吃 stream;**reload 重水合需
  chat 数据层把带 parentBlockId 的 sub-message 折回 tool_call 之下**(现 transcript 合并未做,须补缝)。
  sub-message 包裹节点 `node.type="message"` 的 BlockKind 归类需核(未知型兜底也不断链——children 按 id 挂)。
  ToolCardState 需扩 `nestedSteps/nestedAwaiting`(同一次子树遍历顺带算,廉价)。逐 delta 重渲须把
  rebuild 圈在嵌套卡内(transcript 已有 ≤1/frame 合并)。

---

### `get_subagent_trace` — 正在回读轨迹 → 已回读轨迹(Reading trace → Read trace)

- **收起行**:icon=放大镜(补 toolIcon 精确表;现关键字会误落 agent 形)· 动词 · chip =
  `subagentRunId`(subagt_… 中截;省略=列表形态,动词自足无 chip)· 回执:列表形态 `N 个运行`
  (解析 `count`);详情形态 `N 块`(`blocks.length`);解析失败无回执。
- **活期**:settle-only(无 progress、一次性返回)——活期即裸行读秒,无活窗。
- **落定体(克制:这是给 LLM 的回读工具,人类已有更好的视图——嵌套卡本体;故卡=索引+凭据,
  不重建第二个 transcript 渲染器)**:
  - **列表形态**:AnThinTable——每行:状态点(ok 绿/failed 红/cancelled 灰)· runId mono · finalText
    首行(截断省略)· blockCount 数。行可点 → **跳锚**:经 `spawningToolCallId` 滚到本对话里那张
    Subagent 卡并闪示(census 03 §12 只保证块在**同一对话**,不保证已翻进当前加载页——chat 是
    CustomScrollView+prepend 分页,未命中路径见交互,不许无声失败)。
  - **详情形态**:头部 KV(runId · status 徽章 · stopReason · errorMessage 红显)+ 首要动作钮
    「跳到子代理卡」(同上锚)+ `blocks` 装 AnJsonTree(@jsonViewport 有界,树自带节点封顶)作诚实原始凭据。
- **退化态**:两条降级字符串(不在对话内 / 未知 id)是**成功态 tool_result 原文**——原样渲通用窗、
  无回执(不猜);`count:0` → 「无子代理运行」诚实空态;详情 JSON 巨大 → AnJsonTree 封顶注记兜底;
  spawningToolCallId 缺席(fork skill 场景可空)→ 行不可点、无跳锚钮。
- **交互**:跳锚(scroll-anchor intent **必须定义未命中路径**:目标块不在已加载窗内 → 向上
  load-until-found[带页数上限],超限则诚实降级——「在更早历史中」提示+继续加载入口;此缝同时服务
  nestedAwaiting 滚锚,一次定对两处受益)· runId 点击复制。
- **新原语**:无(AnThinTable + AnJsonTree + AnBadge 全现成;「滚到块并闪示」是 chat feature 级
  scroll-anchor intent,非原语)。
- **Wow**:trace 卡不复读日志,而是把你**送回**那张活的子代理卡——工具输出变成对话内导航。
- **可行性**:双形态按输出 JSON 键判(有 `subagentRuns`=列表 / 有 `blocks`=详情 / 都无=降级串),确定性。
  ⚠️trace export 的 block 行**不带 attrs(无 tool 名)**——即便想富渲 tool_call 也认不出是哪个工具,
  这坐实了「JSON 凭据 + 跳锚」的克制路线;若未来要富渲,须后端在 export 里补 `tool` 字段(小改,
  走迭代铁律②)。

---

## 族级新原语汇总

1. **AnStickViewport** — 通用有界 stick-to-bottom 滚动视口:有界高 + 贴底跟随 + 顶缘 AnEdgeFade +
   新内容不打断用户上翻。**它才是关 palette 缺口 #1 的原语**(Bash 长日志等他族可直接复用——视口不与
   嵌套对话身份焊死)。reduced motion:滚动即时跳底(jumpTo 非 animateTo),信息零丢失。
2. **SubTranscriptFrame** — 嵌套对话容器:左缩进 s16 + 2px accent-faint 竖界(判别冗余见族级文法)+
   身份行(type 徽章/状态点/步数),**组合 AnStickViewport 作内滚视口**(缺口 #1 的消费者、非缺口本身);
   thinking 低语与机器窗之外的第三身份。reduced motion:open 块切换零动效直接替换、嵌套确认滚锚即时
   定位;双态(动/静)specimen 入 gallery 核验信息零丢失。
3. **SubagentDigestTail** — 块树活摘要:最近 K 行(落定块渲收起微行、open 块全活递归),
   顶缘渐隐 + 「前 N 步」计数;live 期的有界替身。reduced motion:微行进出零动效直接替换。
4. (纯模型,非 widget)ToolCardState 扩展 `nestedSteps / nestedTokens / nestedAwaiting` —— 同一次
   子树遍历派生,喂收起行回执与琥珀上浮。

## 族内建造顺序建议

1. **纯模型层先行**:子树投影(sub-message 定位 / 步数 / tokens / awaiting 上浮)+ **reload 重水合缝**
   (落库 sub-message 按 parentBlockId 折回树)——脱 widget 单测(乱序/孤儿/深嵌/去重五电池)。
2. **AnStickViewport → SubTranscriptFrame + 落定体**(先建独立视口原语再组合;静态先行,gallery
   fixture 树喂):钉住终答块 + disclosure 全轨迹,验证注册表递归复用与有界视口(含 reduced 双态)。
3. **SubagentDigestTail 活期**:digest 微行 + open 块全活 + 琥珀上浮(首触自动展开+滚锚);
   性能验证(嵌套 Bash 尾逐 delta)。
4. **get_subagent_trace 卡**:双形态判型 + AnThinTable 列表 + AnJsonTree 详情 + scroll-anchor intent
   (含 load-until-found/诚实降级未命中路径;intent 缝可与 3 并行,复用给 nestedAwaiting 滚锚)。


---

# F16 humanloop 族 — ask_user / decide_approval / list_approval_inbox(+ V6 危险确认门)

> census 源:09-misc(ask_user)、05-ctrl-appr §三(decide/inbox)、10-framework §5(humanloop 门)。
> 族定位:**唯一「用户是参与者、不是观众」的族**。其余全族的卡是给人看的;本族的卡是等人**动手**的。

## 族级统一文法

1. **琥珀等待态是族色**:凡卡在等人(ask 等答案 / danger 等批准),收起行动词换琥珀
   `AnStatusDot(wait)` + 琥珀动词(「等待你回答」/「等待确认」),**卡强制展开、不允许收起**
   ——一个必须回答的问题不能藏在 chevron 后面。该琥珀与 rail 的 awaitingInput 琥珀点同一语义轴:
   resolved 对称信号(`{"toolCallId","resolved":true}`)同时清卡态与 rail 点。
2. **交互岛 ≠ 机器窗**:等待人的请求是「说给人听的话 + 给人按的钮」,住新原语
   **ToolInteractionGate**(白岛感、非凹陷 mono;prompt 用阅读档 15/1.6)——机器窗铁律不破:
   窗仍只装机器产物(args payload 预览仍是小机器窗),但**问题与按钮绝不进凹陷 mono**。
3. **决议后不可变记录 + 章的诚实耐久分级**:任何 gate 一经决议立即冻结成记录态——按钮消失,
   被选项/决定盖**决议章**(AnBadge:已允许 ok / 已拒绝 danger / 已跳过 muted / 已允许·本对话总是
   accent),永不复活成可交互;会话期内(含重连,resolved 信号 + GET interactions 在场)读到的都是章,
   不是钮。耐久度诚实分级:**denied/declined/取消章冷历史经固定散文匹配可耐久重建;approved 章
   (含 approve 与 approve_always 之分)仅会话期存活**——冷历史(纯 DB blocks)无决议凭据,且
   danger=dangerous+completed 同样出自 approve_always 白名单/skill 预授权的后续调用,从组合推断
   「已允许」即猜测、违诚实铁律——冷历史**不渲已允许章**,按普通 completed 诚实渲。
4. **重连真相三源合一**:interaction 信号是 ephemeral(seq=0)——awaiting 态**必须**能从
   `GET /conversations/{id}/interactions` 重建;决议靠 resolved 信号,冷历史(纯 DB blocks)
   靠固定散文匹配(DenyFeedback / DeclineFeedback / 空答案 / 取消前散文 / NOT_PARKED 串
   "approval node is not awaiting a decision",精确串,census 10 §4 + 05 §14)兜底。
   三源按 toolCallId 键合一进 `pendingInteractionsProvider`,喂底盘相位覆盖。
5. **fail-safe 即视觉序**:非显式同意的一切动作都不执行(后端 fail-safe)——按钮排恒定
   「消极动作在左、ghost;积极动作在右、primary」;Esc 不等于拒绝(拒绝必须显式点)。
6. **诚实枚举**:action 封闭集 `approve|approve_always|deny|accept|decline`,前端绝不发集外词;
   `approve_always` 的诚实注记:仅本对话、仅内存、后端重启即忘(tooltip 写明)。

---

## V6 危险确认门(非工具——底盘 awaitingConfirm 相位的完整体,包一切 danger=dangerous 的调用)

- **触发线缆**:messages 流 Signal 帧 `node.type="interaction"`,content =
  `{"toolCallId","kind":"danger","tool","conversationId","prompt":{"summary","args"}}`
  ——args 是**已剥框架键的干净业务 args**(parsed object,可直接渲)。重连真相 = GET interactions。
- **收起行**:宿主工具自己的行不变(icon·动词·chip),动词被相位覆盖成琥珀「等待确认 /
  Awaiting approval」+ wait 点;卡自动展开且锁定展开。
- **门体(ToolInteractionGate danger 变体)**:
  1. 头行:`AnBadge(危险, tone: danger)` + LLM 自报 summary(阅读档 15——「它想干什么,它自己说」,
     用户裁决的主要证词);
  2. 证物区:prompt.args 渲 AnKv(扁平小值);payload 级长值(command/code/content)单独装小机器窗
     (AnCodeBlock,封顶 12 行 + 诚实截断);已编目工具(如 Bash)复用其 target 文法回显;
  3. 按钮排:`[拒绝](ghost danger)· [总是允许](ghost, tooltip: 本对话内不再询问 <tool>,重启即忘)·
     [允许](primary)`。POST interactions/{toolCallId} `{action}`。
- **决议后(冻结)**:按钮排 → 决议章行:「已允许 · 已拒绝 · 已允许(本对话总是)」;approve 后工具进
  正常生命周期(running→…),章保留在展开体首行作为出处凭据(**会话期凭据——冷历史不可重建,
  见族律3**);deny 后 tool_result 是 DenyFeedback 固定散文(status=completed!),底盘走 denied
  相位、动词「已拒绝」,门体冻结存档 summary+args。
- **退化态**:gate 等待中 ctx 取消 → 固定散文「The run was cancelled before this tool ran.」→
  cancelled 相位,章「已取消」;错过 resolved 信号 → tool_result 到达同样落定卡(双保险);
  冷历史无 interaction 记录 → 散文匹配复原 denied/取消章;approved 无散文凭据 → **不渲章**
  (不从 danger+completed 猜「已允许」,族律3),按普通 completed 诚实渲。
- **交互**:summary 可复制;args 证物区可复制;无 deep link(门是当下,不是导航)。
- **新原语**:ToolInteractionGate(danger 变体)——见族汇总。
- **Wow**:确认门和 ask 问答共用同一「人闸」语言——全产品只有一种「机器请求人类」的形状,
  而且它把 LLM 的自述(summary)和物理证物(args)并排给你裁决。
- **可行性**:cautious 不阻塞不进此门(只需底盘显著标记);subagent 的危险调用同样冒泡到此门
  (broker 随 ctx 继承)——门渲在对应 tool_call 块上,哪怕它在子树里;信号 event.id = tool_call
  块 id,与块树天然对齐。**子树可见性铁则**:祖先(宿主 Subagent 卡及任何祖先 tool_call)默认
  收拢会把锁定展开的门整体吞没成隐形死锁——awaiting 必须由 `pendingInteractionsProvider` 沿
  parentId 链向上冒泡:强制展开全部祖先(与门自身同一「锁定展开」机制),祖先 Subagent 行动词
  覆盖为琥珀「子任务等待确认」+ wait 点、点击滚动直达门;resolved 后祖先解锁、回落默认收拢。

---

### `ask_user` — 动词对(正在提问 → 已回答 / 已跳过)

- **收起行**:icon(对话气泡形,须补精确表——关键字推断落兜底扳手)· 动词三段:args 流入期
  「正在提问」(shimmer)→ 等待期琥珀「等待你回答」→ 落定「已回答/已跳过」· chip = args.message
  首行引号截断 ~40 字(`argStringPartial`,容忍半截)· 回执 = 答案首行引号截断 ~48 字;
  declined → 灰「未回答」;空答案散文 → 灰「空答案」。
- **活期(生长秀)**:`args-partial` 两幕——①问题正文随 LLM 打字流进交互岛(阅读档 15,
  liveBody 即岛的 prompt 槽,逐 delta 追加);②options 数组每完整解析出一项,点亮一颗带序号的
  选项钮(`1. 周一` `2. 周二`…浮现)。args 完、interaction 信号(kind:"ask")到 → 岛「活化」:
  钮变可点 + 自由文本框浮现,行动词切琥珀。**这卡的活期直接长成表单**——不存在退化。
- **落定体**:不可变 Q/A 记录——问题(阅读档,>20 行 AnFadeCollapse)+ 答案区:被选项冻结成
  选中章(其余选项淡出降透明度);自由文本答案渲成引用行——**逐字复用 AnMarkdown blockquote
  的条色/宽/内距 token**(blockquote 是「引用」的既定语义,与 thinking rail 物理区分,不留
  「细条」自由发挥空间);declined → 「已跳过」muted 章。落定后默认收起(历史像目录),
  回执携答案摘要。
- **退化态**:无 options → 纯文本框;options >8 → 竖排列表(全部显示,不截——选项是封闭集);
  问题超长 → FadeCollapse 但输入区恒在视口;提交空文本 → 回执诚实「空答案」;
  非交互语境 sentinel `ASK_NO_INTERACTIVE_USER` → failed 相位自动展开,错误条;
  等待中取消 → 线缆是 ctx 硬错,但对人是良性停止:错误串匹配 context canceled 族(或步级
  close status=cancelled)→ 映射底盘既有 **cancelled 相位**,章「已取消」,**不触发失败自动展开**
  (与 V6 门同场景处理对齐,不带失败红标);重连 → GET interactions 重建表单
  (已敲未发的草稿丢失——broker 内存态,诚实不假装恢复)。
- **交互**:选项钮数字键 1–9 快选(终端血统;**仅持焦点的门响应,非全局绑定**——并发多门
  仲裁见族汇总①);文本框 Enter 发送 / Shift+Enter 换行;
  「不回答」ghost 钮(action=decline,显式才算);问题可复制。POST `{action:"accept",answer}`。
- **新原语**:ToolInteractionGate(ask 变体:options 钮排 + 自由文本框 + decline);
  钮复用 AnButton(outline/ghost),框复用 AnInput。
- **Wow**:问题是被 LLM 一个字一个字「问出来」的,问完选项自己长出来、原地变成能按的表单——
  提问、等待、回答、存档四态在同一张卡上无缝相变。
- **可行性**:message 在 required 首位之后(summary/danger 先到),流中可稳定 partial 提取;
  options 数组解析须容忍未闭合(逐完整元素提取);阻塞期无 progress 块(等待本身即 interaction
  帧);resident 工具、每对话高频——岛的 build 必须便宜(纯 prop,无每帧重排)。

---

### `decide_approval` — 动词对(正在裁决 → 已批准 / 已否决)

- **收起行**:icon(章/印形)· 动词从 args.decision 定向:live「正在裁决」→ yes「已批准」/
  no「已否决」/未解析「已裁决」· chip = flowrunId(mono,中段省略)· 回执 = 落定后
  flowrun.status(解析 result JSON 的 flowrun.status,如「已批准 · running」);解析失败无回执。
- **活期(生长秀)**:`args-partial`——裁决书成形:decision 键一解析出来,✓批准(ok)/✗否决
  (danger)判词章即浮现;reason 随打字流入(阅读档 15)。落定前的 flowrun 后果为 settle-only。
  LLM 自报 dangerous 时天然先过 V6 门(替人做审批决定,门里 summary+args 正是判词预览)。
- **落定体**:两段——
  1. **判词块(默认全文直陈)**:章(AnBadge ✓批准/✗否决)+ reason 全文阅读档 15,不截断——
     这是司法记录;唯 reason 是 LLM 自由串,病态超长(宽容阈值 >60 行)走 AnFadeCollapse +
     「展开全文」逃生口(一键可全览、零信息丢失——守宪法#8 有界视口,不作无界承诺);
  2. **后果条(克制)**:flowrun.status badge + 计数排(completed n · running n · failed n,
     AnBadge 小章)。计数数据源两分支:`nodeSummary` 存在(**仅节点超 80 封顶时才出现**)→
     用 `nodeSummary.byStatus`(覆盖全量)+ 诚实注记「显示 shownNodes/totalNodes 节点,全量见
     flowrun」;缺席(最常见)→ 线缆上没有 byStatus 字段,前端遍历 `nodes[]` 自行按 status
     计数(≤80 行,便宜);绝不倾倒 nodes 原始 JSON。
- **退化态**:NOT_PARKED = **产品正常态**(首决胜/已超时/节点标识有误)。**检测手段**:错误码
  `FLOWRUN_APPROVAL_NOT_PARKED` 不上工具线缆(tool_result 只带 errorspkg.Surface 的 message
  文本)——把后端精确串 "approval node is not awaiting a decision" 加入族的固定散文匹配表
  (与 DenyFeedback 同机制,族律4;脆弱性注记:后端改文案即失配,失配则回落标准错误条)。
  命中 → error 相位但**文案不猜成因**:「该节点当前不在等待审批(可能已被决议、已超时或节点
  标识有误),本次裁决未生效」,非崩溃腔;`FLOWRUN_INVALID_DECISION` / not found → 标准错误条;
  result 解析失败 → 判词块仍从 args 渲(decision/reason 本来就在 args),后果条缺席——诚实降级。
- **交互**:后果条尾 AnRefPill 式跳转 flowrunId → select intent `{kind:flowrun,id}`(右岛 run
  终端/未来 flowrun 面;面未建时降级为复制 id);reason 可复制。
- **新原语**:无——AnBadge + AnKv + AnRefPill 全复用;判词块是布局不是原语。
- **Wow**:看得见「判决被写下来」——判词章先落、理由后书,和真实签批的心理顺序一致;
  且撞上首决胜竞态时它诚实地告诉你「别人已经决了」,而不是装失败。
- **可行性**:result 封顶 80 节点仍可达几十 KB——后果条只选择性解析 flowrun.status + 计数
  (nodeSummary.byStatus 或自数 nodes[],见落定体两分支),绝不渲全量;
  reason 是可选 args,缺席时判词块只有章一行(合法,克制);lazy 工具、低频,无性能压力。

---

### `list_approval_inbox` — 动词对(正在清点审批收件箱 → 已清点)

- **收起行**:icon(收件箱形)· 动词自足(**零参数,无 chip**)· 回执 = `count`:
  「N 件待审」/ 0 → 「无待审」(诚实空)。
- **活期(生长秀)**:`settle-only`(零 args、一次性 Execute)——活期只有 shimmer 动词 + 读秒,
  无活窗。这是克制:没有可看的生长就不假装有。
- **落定体**:待审薄表(AnThinTable,selectable)——列:`审批`(ref,mono)· `摘要`
  (rendered 首行拍平省略——人认审批靠这句)· `等待`(parkedAt → 相对时长「2h」「3d」,
  oldest first 后端已排,最久等的在最上)· `run`(flowrunId 短显)。行封顶 20 + 诚实
  「+N more」注记(count > 显示数时)。
- **退化态**:count=0 → 表不渲,一行 muted「收件箱空——没有 run 在等审批」;rendered 缺席
  (omitempty)→ 摘要格显灰 em dash;JSON 解析失败 → 通用体兜底;parkedAt 非法 → 原串直显。
- **交互**:行点按 → select intent `{kind:flowrun,id}` 跳该 run(右岛/flowrun 面;未建则复制 id);
  这是「发现待审批的唯一忠实途径」(search_flowruns 找不到 parked)——表就是收件箱的传送门。
- **新原语**:无——AnThinTable 全复用;相对时长格式化复用 rail 的 lastMessageAt 同一 util
  (若无共享 util,先抽一个,勿在卡内重写)。
- **Wow**:一张会呼吸的收件箱快照——最久等的人排最上、等待时长直说,点一行就站到那个 run 面前。
- **可行性**:slim 投影(后端刻意不吐 Result map,F173 精神)体积无忧;rendered 是 markdown——
  **只取首行拍平**,绝不在 cell 里渲 markdown(AnThinTable 单行 cell 契约);只读 safe,
  永不过 V6 门。

---

## 族级新原语汇总

1. **ToolInteractionGate**(feature 层,chat)——人在环交互岛:prompt 槽(阅读档 15/1.6,支持
   流入追加)+ 动作钮排(fail-safe 序:消极左 ghost / 积极右 primary)+ 可选带序号选项钮
   (数字键快选)+ 可选自由文本答框(Enter 发/Shift+Enter 换行)+ 两模式:awaiting(琥珀
   wait 点、锁定展开)↔ resolved(冻结记录:钮化章、选中项定格、其余淡出)。**焦点仲裁**:
   数字键/Enter 仅作用于持焦点的门——门活化时自动请求焦点,execution_group 并发批多门并存时
   Tab/点击切换焦点;**绝无全局快捷键绑定**(按错卡=替用户答错问题)。ask 与 danger
   两变体共用;reduced motion 下浮现/淡出即时化。**gallery-first:先进 gallery 五态 specimen
   (ask 流入/ask 活化/ask 冻结/danger 待决/danger 冻结)再接 transcript。**
2. **pendingInteractionsProvider**(状态基座,非视觉)——三源合一的交互真相:ephemeral
   interaction 信号 ⊕ `GET /conversations/{id}/interactions` 重连快照 ⊕ resolved 对称信号,
   按 toolCallId 键;派生①底盘相位覆盖(awaitingConfirm/awaitingAnswer)②rail 琥珀联动
   ③决议 POST 的乐观冻结④**祖先链冒泡**:awaiting 的 toolCallId 沿 parentId 链向上强制展开
   全部祖先(与门同一「锁定展开」机制),祖先 Subagent 行动词覆盖为琥珀「子任务等待确认」+
   wait 点、点击直达门;resolved 后祖先解锁回落。冷历史(无 broker 记录)由固定散文匹配兜底
   出 denied/declined/取消章(approved 无凭据不出章,族律3)。

(decide/inbox 零新原语——AnBadge/AnKv/AnThinTable/AnRefPill 全复用,克制即完美。)

## 族内建造顺序建议

1. **pendingInteractionsProvider**(真相基座先行——没有它一切 awaiting 态都是幻觉;
   含 GET/POST 契约层 + 信号 demux 接线 + 固定散文匹配表)。
2. **ToolInteractionGate 进 gallery**(五态 specimen,纯 prop 驱动、零网络)。
3. **V6 danger 门**接底盘 awaitingConfirm 相位(完成既有相位的体;所有 dangerous 工具立即受益
   ——这是族外溢价值最大的一步)。
4. **ask_user 卡**(ask 变体 + 三段动词 + Q/A 冻结记录;resident 高频,验收最充分)。
5. **decide_approval 卡**(判词块默认全文+宽容阈值 + 后果条计数双分支 + NOT_PARKED 散文匹配
   与不猜成因文案)。
6. **list_approval_inbox 卡**(薄表 + 相对时长 util 抽取)。


---

# F17 conversation 族 — manage_conversation / list_conversations / search_conversations

> 线缆真相:census/09-misc.md(2026-07-05 读码)。三工具全部 lazy、无 progress 流、输出轻量
> (manage=五字段状态回显 JSON;list=≤50 行/页;search=≤20 hit×snippet)。族定位(WRK-053 §4):
> **薄卡族**——宪法 #9「克制也是完美」是本族的第一法条。

## 族级统一文法

- **薄卡三件套**:32px 裸行 + 至多一扇紧凑机器窗。无活窗(无 progress 流可挂)、一切陈列
  settle-only;活期只有流光动词 + args-partial 目标 chip 的小生长。
- **对话行语言**:落定体里的对话一律渲成**可点对话行**(新原语 `ToolHitList`)住 `ToolWindow`
  凹陷窗——不是裸 JSON 尸体、不是 mono 日志。行 = 状态记号(置顶字形 / 归档灰徽)+ 标题
  (13 `emphasisWeight`,空标题回落 conversationId 截断)+ 可选次行 snippet(13 muted,2 行截)
  + 尾 meta(相对时间 / ×N chunks,13 faint tabular)。窗内紧凑行高 28(密度档,低于 AnSize.row)。
- **本族真正的舞台在卡外**:rename 的变化经**自动命名打字机管道复用**在浮层头 + rail 同播;
  pin/archive 的变化由 conversation 状态更新驱动 rail 自己动(置顶区移位 / 归档灰点)。卡保持
  一行安静的过去时——「看见变化本身」在薄卡族的正确解法是让变化发生在它居住的地方。
- **「当前对话」徽记**:list/search 结果含正在聊的这条时,行尾加 faint「当前」徽记、点击 no-op
  ——卡就活在这条对话里,诚实标注避免「点了没反应」的困惑(客户端自知,非线缆断言)。
- **图标**:`AnIcons.toolIcon` 精确表补 `manage_conversation` / `list_conversations` → 对话泡字形
  (今日两者落兜底扳手);`search_conversations` 走既有 `search` 关键字命中放大镜(动作语义优先)。
- **i18n**:五对动词 + 计数 + 徽记文案全进 slang(复用 `t.chat.tool.*` 计数模式)。

---

### `manage_conversation` — 动词对随 action 分派(五对 + fallback)

archive:正在归档对话→已归档对话 / unarchive:正在取消归档→已取消归档 / pin:正在置顶对话→已置顶对话 /
unpin:正在取消置顶→已取消置顶 / rename:正在重命名对话→已重命名对话;action 未达或不识 →
fallback 对「正在整理对话→已整理对话」。

- **收起行**:对话泡 icon · 动词分派**双源**:live 期按 `args.action`(args-partial,未达 →
  fallback 对,到达即 AnShimmerText 换串)只作流中预告;settle 后一律以 `output.action` 为
  **唯一真相源**(解析成功时——线缆真相在手就用它,极端情形 args 增量拼不出完整 JSON 也不卡
  fallback;解析失败走软失败探测路径,不变)· 目标 chip:仅 rename 显 `"args.title"`(argStringPartial,流中逐字
  长出;落定后换 `output.title` 线缆真相——已 trim)· 回执:解析输出 JSON
  `{conversationId,action,title,archived,pinned}`;rename → 无额外回执(chip 即凭据),其余 action
  无回执(动词自足——对象恒为当前对话,LLM 不传 id,无需指名)。
- **活期**:⚠️ 全部 `args-partial`,无活窗。rename 标题在 chip 里被打出来;其余 action 只有动词切换。
- **落定体**:极薄单窗——AnKv(dense)状态回显:`archived` / `pinned` 布尔 + `title`(来自输出,
  绝不猜);action=archive 时附一行 faint 产品事实「再发消息会自动取消归档」(census 线缆自述,
  诚实预告归档当前线程形同虚设);LLM summary 有则置体首(cautious 可逆族,不上窗顶常显)。
- **morph(rename)**:旧→新标题 morph **不在卡内**(旧值不在线缆上)——settle 即触发自动命名
  打字机管道:浮层头逐字打出新名 + rail 行同步(既有 head/rail 双落通道)。**触发前按值判重**:
  比对 head/rail 当前显示标题,== 新标题(后端 conversation 更新信号已先到、名已换上)→ 跳过
  动画直接静置;≠ 才走打字机——与两信号到达顺序无关,两种时序都对;reduced motion 同走静置路径。
- **退化态**:ctx 无 conversationId → Execute 返回**软字符串**(仍是 succeeded 相位!)——回执
  解析器兼职软失败探测:输出解析不出状态 JSON → 落定动词**降级为中性**「已调用」+ 无回执 +
  展开体 ToolWindow 显原文(否则「已归档对话」是谎言);枚举外 action / rename 空标题 → failed
  相位硬错,底盘自动展开;输出缺字段 → 只显有的位。
- **交互**:无 deep link(对象=当前对话,无处可跳);无逃生口(内容恒小)。
- **新原语**:无新组件。需两处缝:① **底盘 verb 缝扩展**——`ToolCardSpec.verb` 现签名
  `(t,{live})` 拿不到 state,action 分派动词 + 软失败降级动词都要 state(receipt 已有 state,
  仅 verb 缺;向后兼容扩为 `verb(t,state,{live})` 或加可选 `verbOf`);② **rename→autoname
  打字机接头**(chat feature wiring):settle(action=rename 且 JSON 解析成功)→ 喂既有打字机通道。
- **Wow**:改名不是卡里的一行字——整个 chrome 活过来:浮层头和 rail 像自动命名那样把新名字
  打出来,工具卡只留一行安静的过去时。
- **可行性**:args 顺序不可控(action 可能晚于 title 到)→ fallback 动词对必须有;输出五字段
  紧凑 JSON,体积恒小;**软失败以 succeeded 相位返回字符串是本卡最大诚实陷阱**,解析探测必做;
  rename 联动须防双触发——后端 rename 也会推 conversation 更新进 rail 数据源,且该信号与工具
  settle 帧到达顺序不保证;打字机以工具卡 settle 为唯一触发 + **接头处按标题值判重**(见 morph;
  不赖 autoname 管道既有去重——那是为 autoname 信号 vs REST 重取建的,未必按标题值判重)。

---

### `list_conversations` — 正在列出对话 → 已列出对话

- **收起行**:对话泡 icon · 动词 · chip:`includeArchived=true` → 「含归档」;`cursor` 在 →
  「续页」(可并列 mono 短词);默认无 chip · 回执:输出 `count` + `nextCursor` 存在 → 「N+ 条」
  (截断计数铁律)/ 不存在 → 「N 条」/ count=0 → 「无对话」。
- **活期**:⚠️ `settle-only`——args 全可选且极小,纯流光动词,无生长。
- **落定体**:ToolWindow 内 **ToolHitList**(枚举模式):每对话一行 = 置顶字形(faint)/ 归档
  灰徽(AnBadge)+ 标题 + 尾 lastMessageAt 相对时间(落定时刻静态计算,复用 rail 格式器;
  不活刷——工具卡是历史快照);当前对话行尾「当前」徽记;页尾 `nextCursor` 存在 → faint 注记
  「还有更多页」(诚实:这只是一页,非全集)。上限=线缆 50 行/页;**行数 >15 → 整列包进既有
  AnFadeCollapse**(collapsible 由行数判定;surfaceSunken 上须显式传 fadeColor——palette 已注明
  此坑;展开/收起标签走 slang),≤15 行不折叠——50 行 × 28px ≈ 1400px 直立墙不许立在 transcript
  里(宪法 #8 有界视口 + 逃生口精神,历史要读成目录不是日志)。
- **退化态**:conversations 空 → 窗内单行「无对话」;JSON 解析失败 → 无回执 + 原文窗;
  title 空 → conversationId 回落(rail 同款空标题回落语义)。
- **交互**:行点击 → go_router 切 `/chat/:id`(同海洋内导航,transcript 层注入
  `onOpenConversation` 回调——原语不碰导航);当前对话行 no-op。
- **新原语**:**ToolHitList**(chat feature 层)——见族级汇总。
- **Wow**:工具结果是一个迷你 rail:置顶在前、归档灰着、时间对齐,点哪条就走进哪条。
- **可行性**:单页 ≤50 行体积小;多页=多次调用=多张卡,各卡各页、不跨卡聚合(诚实);
  相对时间静态渲染是设计拍板(业界同款 stale 可接受)。

---

### `search_conversations` — 正在搜索对话 → 已搜索对话

- **收起行**:放大镜 icon(关键字自动命中)· 动词 · chip = `"query"`(argStringPartial,流中
  逐字长出、引号 mono)· 回执:输出 `total` → 「N 命中」;0 → 「无匹配」。措辞用「命中」不用
  「条对话」——线缆明令这是内容回忆、**非枚举**,卡的语言跟着守。
- **活期**:⚠️ `args-partial`——query 在 chip 里被打出来(薄卡族唯一的小生长);结果 settle-only。
- **落定体**:ToolWindow 内 ToolHitList(命中模式):行 = 标题(`title?` 缺 → conversationId
  截断)+ 次行 `snippet`(13 muted,2 行截断省略)+ 尾 `matchedChunks` → 「×N」(有才显);
  行可点。**页尾截断注记**:`hits.length < total` 时渲 faint「显示前 {hits.length} 条 · 共
  {total} 命中」(slang 计数模式;相等时不渲)——回执报 total 而窗内列被 limit 夹,列表本身就是
  被截断的呈现,无注记即违宪法 #4「截断必有显式注记」。≤20 行;行数 >15 同走 ToolHitList 内建
  AnFadeCollapse 折叠(带 snippet 次行的行更高,更须折)。
- **退化态**:hits 空 → 窗内单行「无匹配」(诚实,不装空列表);snippet/title 缺 → 只显有的;
  解析失败 → 无回执 + 原文窗。
- **交互**:行点击 → 切 `/chat/:id`;`messageId` 锚定跳到命中消息是完美态终点——但 transcript
  现为 CustomScrollView center 锚 + 尾部分页,**无任意消息定位能力** → v1 降级仅开对话,
  「@消息」落点徽记留 P2(能力落地即点亮,不预渲假承诺)。
- **新原语**:复用 ToolHitList(次行 snippet 模式)。
- **Wow**:记忆变成门——每条命中都是可推开的门,直接走回那段对话(P2 直达那句话)。
- **可行性**:snippet 由后端截好、绝不返全文,体积恒小;messageId 锚定是唯一硬技术依赖
  (transcript 锚定加载未建,须挂 P2 不阻本卡);`total` 与 hits.length 可能不等(total=命中
  总数、hits 被 limit 夹)→ 回执用 total、列表如数渲 hits + **页尾截断注记补齐差额**(一行条件,
  零新原语)——单靠「两者并存」不够诚实,用户数行数必须对得上回执数。

---

## 族级新原语汇总

1. **ToolHitList**(chat feature 层,tool_card_skins 旁)——机器窗内可点命中行列:状态记号/徽记 +
   主行(13 w400)+ 可选次行 snippet(13 muted 2 行截)+ 尾 meta(13 faint tabular)+ 行点击回调 +
   「当前」徽记内建;行高 28 紧凑档。**内建两条有界性行为**:①行数 >15 自动包既有 AnFadeCollapse
   (surfaceSunken 上显式传 fadeColor,展开/收起标签走 slang;≤15 行原样直渲)——宪法 #8 有界
   视口;②页尾 faint 注记槽(调用方喂文案:list 的「还有更多页」、search 的截断注记)——宪法 #4
   显式注记的落点。是「命中/枚举」类工具结果的唯一陈列容器,未来 search_blocks / search_tools
   等命中族直接复用(部分回应 palette 缺口 #8「结果行可点」)。
2. **底盘 verb 缝扩展**(非组件,V3a 底盘一次向后兼容签名变更)——`ToolCardSpec.verb` 增拿
   state:manage 的 action 分派动词与软失败降级动词都依赖它。**双源约定**:live 期以 `args.action`
   分派(流中预告),settle 后解析成功一律以 `output.action` 为唯一真相源;旧 catalog 条目零改动
   包装过渡。
3. **rename→autoname 打字机接头**(wiring,非组件)——manage_conversation settle(rename 且
   解析成功)→ 喂既有 head/rail 打字机通道;**接头自带按标题值判重**(当前显示标题 == 新标题 →
   静置跳动画,≠ → 打字机),与后端 conversation 更新信号的到达顺序无关、防双触发不赖 autoname
   管道既有去重。
4. **AnIcons.toolIcon 精确表补两行**——manage_conversation / list_conversations → 对话泡字形。

## 族内建造顺序建议

1. **底盘 verb 缝扩展**(先修缝,不破坏既有 F1–F4 catalog——默认包装旧签名)。
2. **ToolHitList + list_conversations**(纯只读、结构最简,验证行列渲染 + deep link 注入缝)。
3. **search_conversations**(复用 ToolHitList 加 snippet 次行模式;messageId 锚定记 P2 TODO)。
4. **manage_conversation**(依赖 1:动词分派 + 软失败探测;rename 打字机接头联动测试最重,压轴)。
5. toolIcon 精确表 + slang 词条随各步同提交(文档纪律 #9)。
