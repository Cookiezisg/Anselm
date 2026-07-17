---
id: WRK-070
type: working
status: draft
owner: @weilin
created: 2026-07-17
reviewed: 2026-07-17
review-due: 2026-10-15
audience: [human, ai]
---

# WRK-070 · Chat 右岛「侧幕」打磨台账（0717-深夜 聊题中）

> **状态：收集问题阶段——用户逐条提、先聊透、绝不动手；用户说「开工」后一口气全做。**
> 每条问题记：用户原话要点 → 代码定位（侦察补充）→ 拍板的做法。做完逐条勾。

## 议题清单

### #1 左缘对齐乱（0717-深夜 提出，含两个子问题）

**用户原话要点**：

1. subagent 的细节小行里 icon 和字没有水平对齐。
2. 视觉边缘问题普遍存在：展开体分两种——**带白框的**（代码窗/审批信笺等）与**不带框的**（裸文字/KV 行）。当前都占满岛宽，导致对不齐：框内文字起点天然靠后，裸文字却顶格。且上一层「展开」本身也是带逻辑框的东西——github MCP 例子里特别明显。
   - **有框的 → 框应占满整个岛宽**（handler 的代码窗现在没做到，还有退格）；
   - **裸文字的 → 起点要与框内文字起点一个感觉**（同一条视觉线）；
   - 框+文字交叠的 stage 要想清楚怎么排才舒服；
   - 有些原语自带退格，怎么处理要统一想。

**代码定位**（0717-深夜 侦察完成，体左缘=相对 X）：

- **左缘现状共 9 种起点**：0（裸 Text:墓碑/timeout/「审批人将看到」/「N tools」/honesty/error + 各框的框缘 + 小行 icon）· 8（AnKv 键 / 行头 glyph）· 9（AnLayerDiff 内文）· 12（mcp 工具名 / **handler 全部代码窗框=退格来源**）· 16（mcp 铭牌名 / approval 预览句）· 17（一切 AnWindow/AnCard 框内文字=AnInset.card 16+border 1）· 18（AnLedgerRow primary）· 32（AnRow 行头 label）。
- **handler 退格确切来源**：`handler_stage.dart` 四处硬编码 `EdgeInsets.only(left: s12)`（:67 init 窗 / :78 live 窗 / :84 shutdown 窗 / :125 方法 spine）——把 AnCodeEditor 框推到 X=12,与 function 同原语（X=0 满宽）直接互相打脸。
- **小行 icon 不齐两病并存**：同构「iconXs 8 + s4 + 文字」小行，subagent 尾行用 `CrossAxisAlignment.start`（subagent_stage.dart:122,icon 贴行顶）、mcp 工具行用默认 `center`（skill_memory_mcp_stage.dart:196）——互不一致且都偏离文字光学中线；8px icon 在 meta 行高里两种对法都不居中于字面。
- **同体内典型打架**：\_GenericStage KV 键(8)↔窗内码(17)↔裸错误(0)；mcp 一体四种起点(0/12/16/17)；approval 提示句(0)↔卡内文字(17)；Deleted 态 KV 键(8)↔红字墓碑(0)。
- **展开体与行头**：体与行头框同宽（体左缘=行头框左缘）,行头 label 在 X=32 自成一系。
- **岛链**：岛缘→13（AnIsland border1+s12）→17 绝对体左缘（ListView h:s4）；AnInspectorHead 头带自己 16 起,与列表天然错 12（另记）。

**用户裁定思路（0717-深夜二轮，否决双轨魔法数）**：**「假想框律」**——不定像素线，按原语的设计语言思考：
- 每个块逻辑上都住在一个框里。真框（AnWindow/AnCard）有真内距；**裸内容配假想框**，边距从既有原语来（AnKv 行的 h:s8 就是假想框的现成实现——图 #18 的 id/Deleted KV 行「两端对齐、逻辑上都在框里」即舒服的原因）；红字 Deleted 破相是因为它没框（X=0 裸奔）。
- **icon 开头的行同理**（图 #19 控制梯 / 图 #20 mcp）：**icon 对 icon、文字对文字**——一条固定 icon 沟（AnLedgerRow lead 沟的思路），不同尺寸 icon 在沟内光学居中，文字全落同一列；无 icon 的行（如「4 tools discovered」）文字也落文字列。
- **真框占满体宽**（handler 四处手写 s12 删，方法层级由方法名行自己表达——名行=icon 沟行）。
- **表头（行头灰壳）设计好的，不动。**
- 执行要点=「不去动那些原语，借已有思路解决」：能直接用原语就用（AnKv/AnLedgerRow/AnIndent），不能就按同一套框/沟文法摆裸内容；所有偏移从原语派生，零新魔法数。

### #2 Composer 三钮雷霆大 + 回车发送（0718-凌晨）
- **定位**：@/📎/发送三钮全 `AnButtonSize.lg`（chat_composer.dart:444/446/459）——44px 级按钮配 15px 正文,比例失衡;壳被撑到 ~64 高。
- **✅ 用户 0718 拍板（三档同框样机比选）：28 档**——三钮全切 `AnButtonSize.md`(28 盒/16 形),发送=28 主色实心圆+16 箭头,壳单行态随之自然收矮;多行只长中间、两侧钮钉底行。样机 rig `test/dev/capture_composer_mock.dart` 用完即删。
- **回车**：代码契约已是 Enter 发/Shift+Enter 换行/IME 合成期不发(默认档;可切 ⌘Enter)——开工真机验证,若实测不符按 bug 修。

---

## §B Scheduler 议题（0718-凌晨 提出，十条）

### B1 裸 id 仍遍布（Overview / 子页面包屑 / 右岛 dossier / 搜索框）
用户：保留粘 fr_ id 的**能力**，但别到处「这么说」；rail 搜索框照 entities 样式（placeholder 普通词 + **右侧 sliders 显示控制器**，控制下面显示什么）。
**定位与拟案**：
- Overview 三段行（等你/在跑/失败）的 `fr_` 药丸删 → 行身份=workflow 名 + run 短语（`runPhrase` 已有文法）；
- 面包屑第三段 `fr_hist00000…` → run 短语短版；
- 右岛 dossier 出处药丸：trigger 念真名（`triggerName` 缝已有、dossier 未接）；run id 降级为复制 affordance（不作为文字陈列）；
- rail 搜索框 placeholder「Filter / paste fr_ id...」→「搜索」；粘 id 能力保留；右侧加 sliders 菜单（排序 + 行 meta 显示挡位 + 是否显示停用）。**✅ 用户 0718 拍板（「同意」）**。

### B2 时间选择器改三列 ✅ 已落(0718,三列+回显上膛+解析面整体退役)
用户裁「太丑」→ **三列**：①快捷预设 ②日历（只选日期）③起/终**时间滚轮**。
拟案：第三列=「从」日期回显+HH:MM 滚轮 /「到」日期回显+滚轮 / 应用钮；日期只经日历改（回显可点=聚焦日历对应端）。**✅ 用户 0718 拍板（「对」）**。

### B3 间距体系与 entities 不对齐（主页）
- 矩阵上方大空档（=列头车道+段距叠加，读作「给标题留位」）→ **补段大标题**；**✅ 用户 0718 拍板：方案 A，段题叫「Matrix View」**（en=Matrix View / zh=矩阵视图）。
且用户强调：**间距问题是系统性的、不只这一处**——修法不是逐点补，而是**整轮间距标准化审计**：以 entities 段节奏为准绳（AnSection 题距/块距/AnGap 档），把 scheduler 运营主页（页头 meta↔首段/矩阵段↔Runs 段/过滤条↔列表）+ run 子页（B7 Nodes meta↔台账窗及全段）+ Overview + 右岛（B8 及 dossier 段间）逐段过账，超标者全部收编，零手写距离。
- 墓碑句与「Editing belongs to Entities ↗」**已删 ✅(0718)**：墓碑整链退役（widget/provider/repo 方法/stub/demo/i18n/测试），D1 立法措辞已同步（database.md + CLAUDE.md 整体重述该句）。

### B4 run 列表互动感 + 翻页器(后端半 ✅ 292bdc92:offset+total+互斥 422;前端半随 B10 批)
- hover：整行浅灰 + 状态点变 ▸ 箭头（展开后 ▾）——左岛树同款可点感。
- 列表改**每页 10 条 + 底部标准翻页器**（←/→、页码、跳转输入框；单页不显示）。
- **技术点**：页码+跳转需要 offset+总数：后端小工单=flowruns list 加 `?offset`+返回 total。**✅ 用户 0718 拍板「加后端」**。

### B5 排期时间线上的小数字看不懂 ✅ 已落(0718)
定位：`an_schedule_track.dart` bucket 折叠——密集 firing（如 */5 cron）按像素桶折叠，点上方小数字=该桶折叠数。用户看不懂。
拟案：数字撤下，折叠点渲成「厚点/胶囊 ×N」形 + hover tooltip 说人话（「这小时 9 次」）。**✅ 用户 0718「都同意」**。

### B6 emoji 禁令 ✅ 已落(0718,含 no_emoji_guard 卫士测试+⚙ 双渲清除)
定位：`scheduler.nextFireIn = "⏱ $d 后"`。**✅ 用户 0718 立法：「只允许 icon，不允许 emoji」**——撤字符（icon 归 widget 层 AnIcons），全库审计可疑彩渲字符（⚙ 嫌疑；✓✗▲▼⌘ 文本字形逐个核）。

### B7 run 子页 Nodes 段 meta 与台账窗超距
「6 nodes · Completed 6」与下方窗空间过大——与 entities 段节奏对齐（同 B3 标准化）。

### B8 右岛 inspector 大空隙 ✅ 已落(0718,按内容高上限 240,两测锁)
定位：Output 段 `AnSize.jsonViewport` 固定 240 高——小结果（3 行）也撑 240,剩白。拟案：按内容高、上限 240（AnJsonTree 虚拟视口不能 shrinkwrap,需按顶层条目估高或给小结果走非虚拟径）。

### B9 Triggers 卡改双列卡片式 ✅ 已落(0718,AnAutoGrid;顺删「Editing belongs to Entities」提示)
现全宽堆叠行+右侧 Pause → 改双列卡片网格。

### B10（改判 0718）Overview run 列表全面对齐运营主页
用户澄清：#10 那批图看的是 **Overview**——原「删行内停止钮/选一个就弹条」作废。**新裁决=Overview 三段 run 列表（等你/在跑/失败）整体收敛成运营主页大表的同一套**（**✅ 用户 0718 复述确认「嗯嗯，是这个意思」**）：
- 行文法：workflow 名（跨 workflow 保留）+ run 来源短语 + **常驻动词 ⏹/↻**（failed 行补上缺失的 Retry、Stop 位置照大表）+ 右缘时长；
- **勾选框多选**（failed 也能多选——现在不能）；批量条 **≥2 才出**（大表原规），形=全宽平条+右缘 ✕、**无阴影**（an_batch_bar 的 shadowFloat 去掉——全 app 别处无浮影）；
- **单击=展开行内速览卡**（甘特/图，与大表一模一样，不再跳转）；卡内「打开 →」进 run 子页；
- **翻页器同款搬过来**（B4 的 10 条/页）。

### B11 Overview 补标准面包屑 ✅ 已落(0718,AnOceanHeader+浮层头绑定)
用户：Overview 也要标准面包屑文法——上=浅灰「Scheduler」crumb,下=大标题「Overview」;下滑后浮层头左上出「Scheduler / Overview」。修：AnOceanHeader(crumbs+title) + shellHead 绑定,与运营主页同款。

### B12 function 页孤儿「pydantic」✅ 已落(0718,「依赖」标签 tags 行)
定位：`function_overview.dart:105`——venv 依赖列表渲成**无标签**的 `AnRow(label: dep, passive: true)` 裸行,挂在 Last synced 下面,读作神秘词。它是环境声明的依赖包名(demo 种子 `dependencies: ['pydantic']`)。修：给它身份——「Dependencies」标签(如 KV 行+chips 形),不再裸行。

### B13 审批卡重构 ✅ 已落(0718,+Reason 药丸按需长出/framed=AnCard 有边壳全消费面/Overview AnAutoGrid 双列卡/裸 fr_ 药丸随删)
用户：Reason (optional) 常驻输入框「看着怪恶心」——改**小药丸「+ Reason」**,点击长出输入框(理由纯审计可选,不影响任何东西);审批卡**外面要一圈边框**(不裸);**Overview=双列卡片**,run 子页=单列占满。子页的 ApprovalGate 同款 +Reason 行为。

## 拍板状态（0718 落档）

**全部议题已拍板 ✅**（§A #1 假想框律 / #2 composer 28 档 + §B B1–B13 全部）——0718「都同意，落一下档」。待用户宣布开工后一口气建造；交付纪律=每条带测试、双门禁全绿、demo 帧逐条核对、opus 车队对抗复审、文档 1:1 同提交、后端半（B4 offset+total）守 N/D/E/S/T。

## 拍板记录

（聊定一条记一条；「开工」前全部经用户确认。）
