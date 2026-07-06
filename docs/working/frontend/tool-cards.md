---
id: WRK-053
type: working
status: active
owner: @weilin
created: 2026-07-03
reviewed: 2026-07-03
review-due: 2026-10-01
audience: [human, ai]
---

# V3 tool_call 卡片 —— 建造规范(在建)

> chat 中心海洋的工具卡模块:**一个底盘 + 每族一张精心皮肤**,119 个工具全落座。经四路扇出调研
> (后端线缆逐帧真相 / 业界模式目录[Vercel AI Elements 7 态机、Cursor/Claude Code/ChatGPT agent 等] /
> 17+1 工具分类学 / demo 仅当块型清单**不当设计参照**——用户明确定调),用户 2026-07-03 拍板四点(§1)。
> 建完 → 结论提取进 `references/frontend/features/chat.md` + `design-system.md`,本页归 archive。母文档 [`chat.md`](chat.md)。
> **完美态蓝图已拍板**(2026-07-06,113 工具逐个设计 + 50 新原语 + B1–B7 建造顺序):[`tool-card-blueprints.md`](tool-card-blueprints.md)(WRK-056,逐族实施的设计事实源)+ 线缆普查底册 [`tool-card-census.md`](tool-card-census.md)(WRK-057);拍板结果已入 §1 #6–9 与 §6。

## 1. 已拍板决策(2026-07-03 / 2026-07-06)

| # | 决策 | 取值 |
|---|---|---|
| 1 | 收起行文案主体 | **注册表确定性动词**(双语、可靠、诚实);LLM 自报 `summary` 放展开卡首行作「意图」;仅 MCP 动态等无文法工具用 summary 当收起行 |
| 2 | 行形态 | **无边框裸行**(32px,与 thinking 低语同韵);展开体才有容器 |
| 3 | 批次顺序 | V3a 底盘 → V3b shell+fs → V3c builds(三批已落)→ **B1–B7**(2026-07-06 蓝图拍板重排,取代旧 V3d/V3e 划分,见 §6) |
| 4 | 路线图 | **取消独立 V4**(tool_result 三形状被族皮肤吸收);V6 人在环紧随 V3c(底盘先留「等待确认」态) |
| 5 | **机器窗口身份**(2026-07-03 截图拍板「对味」) | tool call 是对外部世界的**操作**、非模型内心低语——机器输出**绝不**借 thinking 的低语语法(无左竖线 rail、无裸散文);一切机器产物住**凹陷圆角容器窗**(`ToolWindow`:终端/diff/命中列表同容器不同内容),行保持裸动词行。Bash 执行中=收起行下的**活终端窗**(progress 尾 3 行) |
| 6 | **完美态蓝图 + B1–B7 顺序**(2026-07-06) | 113 工具逐个完美态设计定稿于 [`tool-card-blueprints.md`](tool-card-blueprints.md)(WRK-056,含六种生长母语/五种 morph 笔法/50 新原语总表/R1–R12 裁决);建造顺序 **B1–B7 认可**(见 §6) |
| 7 | **嵌套运行身份**(2026-07-06,改判 R1) | **保留两套**:Subagent = `SubTranscriptFrame` 嵌套对话框(全注册表递归);invoke_agent = `NestedRunPane` 轻量运行窗(F08 专属) |
| 8 | **取数缝**(2026-07-06) | 允许工具卡越出「块状态纯函数」边界,开**统一一条 fetch-on-expand repository 缝**(before 懒取 diff / edit_workflow after 图 / 运行快照图 / mount map),取不到一律诚实降级 |
| 9 | **后端小改包 6 项全做**(2026-07-06) | document 系输出迁 JSON / Bash cap 预留 footer 余量 / todo 单行不变量 / rg 双后端抹平 / MCP OAuth progress 行 / 失败 details 上线缆——各随消费批次同提交、守 testend;其余六题(时间语义/chip 单热区/settled 禁呼吸/HitList 归一/generic 地板 B2 后穿插/P2 挂起)按 WRK-056 推荐执行 |

## 2. 卡片状态机(线缆判据锚定)

```
args 流入中 ──→ [等待确认]* ──→ 执行中 ──→ 终态(成功 / 失败 / 已拒绝 / 已中断)
```

| 状态 | 线缆判据(messages 流) | 呈现 |
|---|---|---|
| args 流入中 | tool_call `Open`(只带 `{name}`)后、`Close` 前;args 经 Delta 逐 token 流入(**含未剥的 summary/danger 键**,渲染前须容忍) | 动词流光,目标未知则只动词 |
| 等待确认 | `interaction` 信号(seq=0 ephemeral,payload 带 kind/tool/prompt{summary,args});重连**必拉** `GET .../interactions` | V3a 占位视觉;完整卡 V6 |
| 执行中 | tool_call 已 `Close`(status completed,快照落 `attrs{tool,summary,danger}` + arguments)且**无 tool_result 子块** | 流光 + 3s 后计时;progress 块 delta = 流窗尾巴 |
| 成功/失败 | tool_result `Open`(整体内容,≤256KB)+ `Close`(completed/error,error 带信息) | 过去时 + 回执;失败自动展开 |
| 已拒绝 | tool_result 文本 = "The user denied running this tool…"(status **completed**) | ⊘ 专属态,一等公民不消失 |
| 已中断 | tool_call Close status=cancelled(args 期);或 Bash 尾部 `[cancelled]`;或 gate 解阻文本 "cancelled before this tool ran" | 「已中断」标记,流光必须落定 |

progress 块:懒 Open(首字节)→ Delta 逐块(**字节粒度非行保证**,渲染侧按行切)→ Close 带全量快照;durable 可重放;一个 tool_call 至多一个。发射者:Bash 前台、run_function print、call_handler 流式方法、create/edit_function env-fix 行、WebFetch、MCP 动态、mount 工具。

## 3. 收起行文法

```
执行中:  ⟨icon⟩ 正在读取 overview.md …        ← 动词 AnShimmerText;… 即活感;>3s 追加 · 4s 计时
完成:    ⟨icon⟩ 已读取 overview.md · 120 行    ← 过去时 + 灰回执后缀(行数/命中数/耗时/exit)
失败:    ⟨icon⟩ 已执行 npm test · exit 1       ← 过去时文法不破 + 失败标记 + 自动展开
拒绝:    ⊘ 已拒绝执行 delete_agent
中断:    ⟨icon⟩ 已中断 · 读取 overview.md
```

- **动词=正文字重,目标=等宽 chip**(路径中截断 `src/…/foo.ts`,query 尾截断);全文案 slang 双语。
- **回执后缀**是过去时的凭据(业界铁律);无目标工具引号包 query、必带结果计数。
- **id→name 升级**:args 阶段只有 id/path,终态从输出提 name 替换,失败保持 id。
- 双键目标(`get_relations` kind+id / `decide_approval` flowrun+node)渲「主目标+徽标」。
- 展开 affordance:有展开体才显 chevron(AnDisclosure 常驻式);Read 类完成后**无展开体**只留回执。

## 4. 17+1 族全表(每族一张皮肤;动词对为 zh 版,en 对应入 slang)

| 族 | 成员 | 动词对(进行→完成) | 目标 | 展开体 | 流式 | 风险 |
|---|---|---|---|---|---|---|
| F1 fs-ops | Read/Write/Edit (3) | 正在读取/写入/编辑→已读取/写入/编辑 | `file_path` basename | Read 无体只回执;Write=内容代码块;Edit=old→new **diff** | Write/Edit args 增长 | Write/Edit cautious |
| F2 fs-search | Glob/Grep/LS (3) | 正在检索→找到 N 个文件/匹配 | 引号包 pattern/path | 命中列表(Grep 三模式) | 计数揭示 | — |
| F3 shell | Bash/BashOutput/KillShell (3) | 正在执行命令→完成(exit 0)/失败(exit N)/超时 | `command` 首行等宽 | 终端视图+exit footer 解析;**后台=持久运行态**,BashOutput 增量追加 | **最强进度流**(前台 progress 逐行) | ⚠️ 全族红,summary 常显 |
| F4 builds | create/edit×8 实体+trigger 两个 (18) | 正在创建/修改 kind X→已创建 X (vN) | create=output.id(流中用 args.name);edit=args.<k>Id | 内容区**打字机流入**+结果条(id/version/**envStatus 半成功态**/restarted)+「在实体面板查看」 | **全系统最强**(args 即内容) | edit cautious;create_document 输出纯文本正则/create_skill 无 id/create_trigger 整实体 |
| F5 lifecycle | revert×6/delete×9/wf 四态/restart/activate_skill/move/meta×4 (26) | 正在删除/回滚/激活…→已删除/已回滚到 vN | args.<k>Id(+version) | 极薄:目标+动作+确认一行 | 无 | ⚠️ delete 9 员+kill_workflow 红核 |
| F6 entity-get | get×8+read_document/attachment (10) | 正在查看 X→已查看 X | args id(终态升 name) | 实体摘要+内容折叠区(截断+逃生口) | 无 | — |
| F7 searches | search×9+list×2 (11) | 正在搜索 "Q"→找到 N 个 | 引号 query | 命中行列表,可点→右岛;空态「无匹配」 | 计数揭示 | — |
| F8 exec | run/call/invoke/trigger/fire/replay (6) | 正在运行 X→运行成功(1.2s)/失败 | args id(call 附 `.method()`) | 输入 JSON 树/输出(`{ok,output,errorMsg,elapsedMs,logs}`)/logs 折叠/flowrunId 深链 | args 流入+耗时揭示;invoke/trigger 持久态 | replay cautious |
| F9 run-logs | search/get × 执行档案 (13) | 正在查执行历史→找到 N 条 | 父实体 id(两个 optional)/记录 id | search=状态列表+rollup;get=单条全档;**get_flowrun 节点表虚拟滚动+nodeSummary 省略提示** | 无 | 尺寸风险第一 |
| F10 web | WebSearch/WebFetch (2) | 正在搜索网页 "Q"→找到 N 条;正在抓取 域名→已抓取 | query/裸域名 | Search=链接列表(source 徽标/truncated);Fetch=摘要+prompt;**三退化态识别**(fail/empty/raw-4KB) | 计数/首行揭示 | — |
| F11 memory-todo | write/read/forget_memory+todo×2 (5) | 正在记忆/回忆/遗忘 "name";待办已更新 (3/7) | name/ctx 无目标 | memory=名+文本;**todo=复选清单卡** | todo items 逐条 | forget 红标 |
| F12 introspection | get_relations/capability_check/search_tools/get_model_config (4) | 正在分析依赖 X→找到 N 条关系 | 双键/无目标 | 边列表/问题清单/工具列表/键值表 | 无 | — |
| F13 mcp-mgmt | marketplace/install/uninstall/reconnect (4) | 正在安装 X→已安装 X (N 个工具) | 短名(install=registry 全名截短) | install=ServerStatus 卡(**tools 列表**) | install 慢=持久态 | ⚠️ cautious+,summary 常显 |
| F14 mcp-dynamic | `mcp__*__*` (∞) | 正在调用 server 的 tool→调用完成 | 名剥取 server+tool | **通用 JSON 卡**(schema-less,截断兜底必备) | args 流入 | ⚠️ 全族 cautious+ |
| F15 subagent | Subagent/get_subagent_trace (2) | 正在派遣子代理→子代理已完成 | subagent_type;树数据自 **E3 嵌套**非输出 | **嵌套 transcript**(reducer 已备)+调用计数徽标 | 双层流,持久态 | 继承内部 |
| F16 humanloop | ask_user/decide_approval/list_approval_inbox (3) | 正在等待你的回答→你已回答 | 无/flowrun+node 双键 | **ask_user=唯一交互阻塞卡**(V6);decide=决定全文永不折叠 | ask 持久琥珀态(联动 rail) | decide 即权限动作 |
| F17 conversation | manage/list/search_conversations (3) | 正在重命名对话→已重命名为 "T" | ctx/无 | 薄卡;manage 改名联动浮层头/rail(复用自动命名管道) | 无 | — |

## 5. 横切规则

- **截断安全网**:卡内容区硬上限+「已截断,查看全文」逃生口;重灾:get_flowrun(后端已 cap+nodeSummary)>agent 轨迹>Bash 256KB(footer 解析)>Read 2000 行>文档正文>F14 全体。
- **自动展开**:仅 错误 + 等待确认;完成后重新收拢(历史读起来像目录不像日志)。
- **批量折叠**(V3e):连续同动词行折「读取了 5 个文件 ▸」。
- 危险自报 `summary` 在 F3/F13/F14 常显。
- 全部 `Animated*` reduced 即时;流光/计时/流窗复用 V2 原语(AnShimmerText/AnExpandReveal/流窗滚动)。

## 6. 批次与验收

| 批次 | 内容 | 验收 |
|---|---|---|
| V3a 底盘 ✅ | `tool_card_state.dart`(纯派生:七相位,拒绝/取消散文=线缆契约)+ `tool_card_catalog.dart`(注册表缝,通用动词兜底)+ `chat_tool_card.dart`(裸行:流光动词/等宽目标 chip/灰回执/tick 读秒 3s 现/reduced 无表;通用体:意图/参数/进度尾凹面板/结果[≤14 行美化 mono,大 JSON 240px 有界虚拟树]/错误;失败自动展开一次)+ transcript 接线 + `capture_tool_card.dart`;**mono 回退链 MiSans 置首**(地基:mono 语境 CJK 确定性) | gallery 10 specimen×双动效轴电池 + 模型/widget 14 测 + fe-verify 1243 绿 |
| V3b ✅ | F1+F2+F3 落地(机器窗口身份):`tool_receipts.dart` 纯解析器(bash exit footer/超时 note/cat -n 行数+截断/计数+N+ 下界/"No matches" 诚实空/**流中容忍 argString**[未闭合字段返 null])+ `tool_card_skins.dart`(`ToolWindow` 容器 + `ToolLiveTail` 活终端尾 3 行 + bash \$ 回显头终端窗/Write 代码窗/Edit `AnVersionDiff` diff 窗/检索命中窗)+ 目录 7 工具族条目(Read **bodyless 回执即卡**);chassis 增:族回执上行(灰/危险色)+ **危险色回执视同失败自动展开**(Bash 非零 exit 线缆上是 completed);BashOutput/KillShell 暂走通用(V3e 细化) | 解析器 13 测 + 族行为 6 测 + gallery 12 specimen×双轴电池;fe-verify **1286 测绿**;截图用户拍板「对味」 |
| V3c ✅ | F4 builds 落地(18 工具):动词带**类名词**(正在创建函数,`creatingKind($kind)` i18n 参数化)+ create 目标=**流中 args.name**、edit=实体 id;`argStringPartial`(未闭合值提取——活代码窗随 LLM 打字流入,流动期纯等宽[逐 delta 重高亮烧帧]、落定换 `AnCodeEditor` 高亮)+ `buildContentOf` 按 kind 路由(fn/hd=set_code code、agent=prompt、doc=content、skill=body、其余 JSON 配置窗)+ **结果条** id·vN·env 三色(ready 绿/building 琥珀/failed 红+envError 红行,危险色回执→自动展开);`liveTail` 泛化成 `liveBody` 缝(F3 终端尾/F4 代码流共用);**错误段上提底盘**(族体免费获得失败显示——V3a 测试揪出的真缺口) | 解析器+路由 2 测 + 族行为 4 测 + gallery 6 specimen×双轴电池;fe-verify **1304 测绿**;截图已发用户 |
| **B1 人闸**(=V6)✅ | F16 全族全落。**a** AnIcons 精确表 116 工具(`ccb43249`)· **b** ToolReceipt tone 三声调(`75bc3098`)· **c** pendingInteractionsProvider 三源合一(`800b8c36`)· **d** ToolInteractionGate 人闸原语+gallery 七态(`11cad5ef`)· **e** V6 门接底盘(纯 prop interaction/onResolve、transcript select 单块下喂、待决锁定展开门、approve 出处章,`0f727e85`)· **f** ask_user 三段动词+落定 Q/A 复用 gate resolved(兑现 B1.b 延后的 verb-state 缝 awaitingVerb/terminalVerb,`f5882183`)· **g** decide_approval 判词章+后果条+NOT_PARKED 友好呈现(ownsError 缝,`20eca9f8`)· **h** list_approval_inbox 薄表+空态+fmtWaited 相对时长 util(core 共享)· **底盘缝一揽子**(tone/verb-state/ownsError)+ AnIcons 收口随各步落。**F16 结论待提取进 features/chat.md**。**下一批 B2 builds 旗舰** | gallery specimen 全过 + 1747 测绿 + 真机逐态截图审 |
| **B2 builds 旗舰** ✅ | F4 全族深化落定(WRK-056 蓝图):**B2.0** `partialJsonEvents` 流中 JSON 事件引擎(core 纯 Dart,单调性不变量)· **B2.1** `RunStatBar` 结果条唯一实现(状态/耗时/计数/凭据 pill 四槽 + per-kind 扩展)· **B2.2** fn/hd 完全体(活代码窗 + `EnvFixTimeline` 自愈时间线 + edit_handler 三径 crashed/stopped/benign)· **B2.3** `AnMiniGraph` 只读迷你图(复用 layoutGraph,fit-to-box,5 色 kind 家族)· **B2.4** `GraphRevealState`(revealProgress 0..1 纯帧:节点 rank 渐显 + 边 PathMetric 画入)+ `AnMiniGraphGrowth` 驱动 · **B2.5** ★**create_workflow 两幕生长**(op ticker → 图回放生长,pivot 旗舰)· **B2.6** ★**edit_workflow 图 morph**(纯 delta 花名册:绿添/琥珀改/红删划线)· **B2.7** control 决策梯(`BranchRuleList` 否则钉底)+ approval 表单预览(`ApprovalFormPreview` moustache→内联码 + mock 决策)· **B2.8** document/skill `ProseWindow`(排版稿子 + `AnFadeCollapse` 软失败重构 + allowedTools 警示药丸=权限让渡)· **B2.9** `TriggerConfigCard` 四 kind 脸(cron 表达式加重 / webhook `AnCopyChip` 可复制 URL+🔒密钥 / fsnotify 路径+事件 chips / sensor 目标药丸+CEL 条件·输出)+ 监听回执(create=未监听、edit=热更新)。新原语:AnMiniGraph/AnMiniGraphGrowth/ProseWindow/AnCopyChip/BranchRuleList/ApprovalFormPreview。cronDescribe 挂起 P2(裸表达式已够);取数缝(#50)推迟(after 图/before diff/flowrun 快照需 Consumer 体,gallery 不兼容)。**F4 结论待提取进 features/chat.md** | gallery 逐帧 specimen + 真机四脸截图审 + fe-verify **1834 测绿** |
| B3 目录感普查 | F5+F6+F7+F17(50 工具):回执解析器群 + 动词对一次铺完 → ToolHitList 统一版 + 面板能力注册表 → EntityGetBody / ToolDependentsBlock / ToolChecklist → 各族落定体 | 解析器全单测 + 真后端 |
| B4 终端与文件手术 | F3(termFold/ansiSpans → AnTermTail → AnStickViewport+AnTermViewport + 后端 cap 余量)+ F1(fsErrorReceipt/AnPathChip/Write 活窗/ToolEditLivePane/mount resolver)+ F2(AnCountUp/GrepContentView) | 同上 |
| B5 执行与档案 | F8(ToolIOSection → run/call/fire → FlowrunNodeList → replay;invoke_agent NestedRunPane)+ F9(RunBeadStrip/RunLedger → RunDossier+ProvenanceLine → RunWaterfall → transcript 水合适配器+TranscriptPeek) | 同上 |
| B6 嵌套对话 | F15:子树投影 + reload 重水合缝 → SubTranscriptFrame + 钉住终答 → SubagentDigestTail + 琥珀上浮 → get_subagent_trace + scroll-anchor intent | 同上 |
| B7 生态收尾(可并行/穿插) | F14 sniffShape+ShapedView generic 地板(可 B2 后提前)+ LiveKvForm + mcp 动态卡 · F11 TodoChecklist(可提前)+ MemoryNoteCard · F10 web 结局分类器+WebHitList · F13 McpServerStatusCard 三件+ToolStageTail · F12 ToolChecklist+RelationStarMap;批量折叠 + transcript 全接线收口 | 真后端端到端 |

landed-into:
