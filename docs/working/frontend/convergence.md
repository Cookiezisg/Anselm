---
id: WRK-066
type: working
status: active
owner: "@weilin"
created: 2026-07-11
reviewed: 2026-07-11
review-due: 2026-10-01
audience: [human, ai]
---

# WRK-066 「同轨」—— 全 App 系统级收敛与优化战役

> **代号「同轨」**,取「书同文,车同轨,一度量衡」:统一原语(文字)、统一版式文法(轨距)、统一 token 与预算(度量衡)。
> 一场**超级大的系统级优化**:视觉收敛 · 规范科学化 · 性能 · demo 全展示,四轨一伞。
>
> **本档是战役的唯一契约**:法典入口 + 四轨台账 + 棘轮基线 spec + 豁免记录全部住这里。
> 任何会话进入本战役,**第一动作是读本档 §6 台账**,不凭记忆续。纪律 binding 源在 [`CLAUDE.md`](../../../CLAUDE.md);
> 台账条目的关闭权见 §3.2——**建造者(AI)无权单方关闭任何条目**。

---

## §0 出身与目标

2026-07-11 用户对现状的四点批评(讨论定纲,全盘成立):

1. **手搓泛滥**:大量视觉件没走 An* 原语,族体文件的私有 `_helper` 是重灾区(不进 gallery、不受审)。
2. **原语只生不收**:G0–G6 49 件 + WRK-056 50 件 + 侧幕一批,从无 consolidation pass;同角色多件并存(三条结果条/两个活尾/四种带边框容器),本该是**一个当家件 + 热插拔 variant**。
3. **版式无文法**:左聚 vs 两端对齐等排布决策从未成文,选原语时没有「内容→角色→用哪件」的判断步骤,全靠现场发明。
4. **视觉选型错、绕开地基**:需求不满足时在 feature 层造新件(如 builds 活代码 = ToolWindow 塞裸 mono,而非给 AnCodeEditor 长 live 形态)——违反原则 #8「强化地基、非模块内重抄」。

**目标**:全 App 视觉规范统一收敛 + 规范科学化 + 性能全面达预算 + demo 全展示。信条:**越干净的组织 bug 越少,视觉也更统一**(本仓已证:WRK-065 修的一串 bug 全是重复实现各自烂)。

## §1 项目全貌(本节文字比重 ≈ 各项工作量)

**P4 批量迁移是这场仗的主体,约四成体量。** 全 App 每一处手搓视觉点——初步估计横跨 chat 二十多个工具卡族体文件、侧幕十二个 kind 舞台、entities 详情页与编辑器、documents 右岛、settings 十三个面板、notifications 托盘、shell 与 gallery 自身——逐个替换成当家原语。每一批都是完整闭环:机械替换 → 全新上下文对抗复审 → 真机 3–5 帧截图 → 台账与棘轮基线同提交递减、**覆盖分母状态同提交推进**(§3.3b);被吃掉的旧原语(三条结果条、两个活尾、四种描边容器、各私有 chip/行/窗)**物理删除**,死码清零。批次之外还有**全量扫尾批**:451 个文件的分母台账里从未被任何族批碰到的文件(P1 只点名了 114 个——发现驱动不等于全覆盖)逐个过审,视觉承载文件按六族+文法全查、state/data 层按轻表查(i18n/魔数/死码),每文件终局 converged / reviewed-clean / 用户签字 exempt 三者其一。这一相位的风险也最典型:批次多、后半程质量易衰减——所以它是 harness 火力最集中的地方,基线不到 0、分母 pending 不清零都不算完,第二轮全新普查还要回来对账。

**P3 地基改造与 C 性能轨各占约一成五。** P3 把六族当家件真正喂饱:窗壳长出 header/actions/tone 槽与 term/code/prose/json/diff 内容模式;AnCodeEditor 长出 live 形态(同壳同框同 copy 位,流动 mono 尾、落定高亮,换脸不换壳);chip 族收拢 tone/icon/mono/copy/nav 热插拔;AnKv 吃下全部标签-值排布;结果条三合一;活尾二合一——全部 gallery 先行、全 variant 展示页齐活。C 轨**不等任何人给靶子、全覆盖自驱**:先建 trace 采集基建(release 模式脚本化跑主场景),给**全部主面**定帧预算——长对话流式、transcript 滚动、海洋切换、documents 打字、entities 图渲染、右岛手风琴、冷启动——已知嫌疑人(收起卡体每帧陪跑构建、族体每帧全量 jsonDecode、常驻 timer/shimmer 群)测量定罪后修,预算测试常驻 fe-verify;此外 P4 每一批迁移**顺手清掉所在文件的性能违规**(反正正在动它)。

**P1 普查加棘轮上线约一成。** workflow 大扇出读全码,一次出四份机器可读台账(手搓点/token 违规/性能嫌疑/demo 缺口),全部对抗核实;同批把棘轮 guard 写进 `frontend/test/guards/`、基线 v0 冻结现状——从第一天起新违规就进不来。

**P2 法典约百分之八。** 六族当家件 API 设计 + 版式文法成文(何时两端对齐、何时左聚、标签层级、选型查表) + gallery mockup,**用户逐族拍板后冻结**——是全场唯一需要用户正经花时间的相位。

**D demo 全展示约百分之七。** 可达性矩阵(每 feature × 关键状态 → demo 怎么到达)、补 fixture 种子(entities 的 trigger/control/approval/flowrun 面、documents 编辑器各状态、settings 面板数据、notifications 托盘各状态、右岛各 kind 舞台稳定入口),矩阵测试收口;守住「不加 per-feature 入口」规范,随时可插批。

**P6 收口约百分之五。** 第二轮全新普查对空账(抓第一轮盲区)、覆盖分母 451/451 终局核验、design-system.md 整体重述、landed-into、归档。

## §2 已拍板决策(2026-07-11 用户)

| # | 决策 |
|---|---|
| 1 | **scope = 全 App**(chat/entities/documents/settings/notifications/shell/gallery 全域;gallery 本身既是收敛对象也是最终法典) |
| 2 | **后端默认不碰**;demo 补种或性能修复需要的小端点逐案豁免(记 §7) |
| 3 | 四轨全要:**A 视觉收敛 / B 规范科学化 / C 性能 / D demo 全展示** |
| 4 | 优先序:P1 四轨一把普查 → A+B 法典拍板(决定一切的地基) → D 随手做 → C 按测量 |
| 5 | 用户日常跑 `make app`(debug)→ C 轨须先在 release 下定性 |
| 6 | **harness 六层 + 棘轮基线为主武器**(§3)——「别信自觉,信基线行数」 |
| 7 | **C 轨不等用户给靶子**:全覆盖自驱,每一步(含 P4 迁移批)都把性能顺手做好;主面全部进预算 |
| 8 | 战役代号 **「同轨」** |

## §3 Harness(约束机器——防的是建造者自己)

### 3.1 设计输入:建造者的已证失效模式

① 提前宣捷(实锤:tool-cards.md 曾积压 7 个「待提取」尾巴) ② 质量随批次衰减 ③ 静默缩 scope(用「engineering judgment」包装跳过) ④ 自己给自己打分 ⑤ 跨会话失忆(compaction 后按残缺记忆行事) ⑥ 复发(战役结束后新代码重新手搓——本次的乱即来源)。

### 3.2 六层约束

| 层 | 机制 | 防什么 |
|---|---|---|
| **① 法典层** | P2 产出每族当家件 API + 版式文法,**用户逐族拍板后冻结**;争议回法典查表,不现场发明;法典入 `design-system.md`(reference 级,逐字同步代码) | 无据可依 |
| **② 台账层** | 本档 §6 四张台账,条目有编号+状态。**条目只能三种方式关闭:完成(有证据链) / 证伪(复审确认) / 用户签字豁免(§7)**——AI 无权单方关闭;台账更新与代码同提交(纪律 #9) | 静默消失 |
| **③ 门禁层** | **棘轮基线**(§3.3),战役**第一批就上线**(先立法冻结现状,整场仗=清空基线);性能预算测试、demo 可达性矩阵测试同理 | 复发 + 宣捷 |
| **④ 复审层** | 每批落地后,**全新上下文对抗复审 agent**(不带建造记忆,prompt 明令证伪)按台账逐条核;**复审不过 = 批次不关**(本仓已证有效:sceneFromTruth 4 修/手风琴 3 修/WRK-065 document·skill 漏网) | 自我打分 |
| **⑤ 验收层** | 每批真机截图自验 + 交用户 **3–5 张关键帧抽查**;只有法典级决策要用户正式拍板(把用户时间压到最小最高杠杆点) | 测试绿但难看 |
| **⑥ 续航层** | `/goal` + Stop hook 挂机器判据(§3.5);每会话首动作=读本档台账;战役 memory 只记「重进入点」 | 跨会话失忆 |

### 3.3 棘轮基线机制(spec)

- **位置**:`frontend/test/guards/` 新 guard 测试 + 基线文件(入库,如 `convergence_baseline.txt`)。
- **格式(抗行号漂移)**:按 `文件 · 违规类别 → 计数` 聚合,行序稳定可 diff。**计数只许减不许增**(棘轮);文件删除/计数归零则条目必须删(防基线腐烂)。
- **规则**:扫描源码 → 与基线 diff → **任何文件任何类别计数超基线 = 测试红**(新违规从第一天起物理进不来);基线条目已不成立必须移除。
- **违规类别初表**(P1 定稿,features/ 层禁、core/ui 白名单):裸 `BoxDecoration` / 裸 `Border.all`·`borderRadius` / 裸 `Color`·`withValues` 私调 / **token 裸算术**(如 `AnSize.iconSm - 4` = 私铸尺寸档) / 裸 `EdgeInsets` 数字 / (B 轨补:tone 误用、动效 reduced 模式不一致等可静态判定项)。
- **进度 = 基线总计数单调递减,完成 = 基线为空**。任何人任何时刻 `wc -l` 可查,不依赖 AI 汇报。
- 先例:`type_scale_guard_test` 已证明此模式能长期守住(字重纪律)。

### 3.3b 覆盖分母台账(「全部都看过」的证据轴)

棘轮只证明**找到的债在收缩**;它证明不了**每个文件都被看过**(P1 普查点名 114/451 文件——发现驱动
≠ 全覆盖,这正是重测战役 COVERAGE.md 的教训)。补分母轴:

- **位置**:`frontend/test/guards/convergence_coverage.txt`(入库)+ `convergence_coverage_guard_test.dart`。
- **格式**:全部非生成 `lib/**.dart` 逐文件一行 `path<TAB>status`;status ∈ `pending`(未审)/
  `ledgered`(普查在案,随 P4 批走)/ `reviewed`(已对抗复审、findings 已修,但尚未完全落当家件)/
  `converged`(终态:已审**且**完全同轨)/ `exempt`(用户签字豁免,AI 无权自判)。
- **guard 规则**:与真实文件树**集合相等**——新文件必登记(`UPDATE_COVERAGE=1` 以 pending 加入)、
  删文件必销账;`UPDATE_COVERAGE` **绝不改既有状态**,状态推进=手改、每次都在 commit diff 里可审。
- **审查深度分层**:视觉承载文件(features/ui·core/ui·design·editor·app·gallery,约 272)按六族+文法
  全查;state/data/契约层按轻表查(i18n 硬编码/魔数/死码)——分母都进,checklist 不同。
- **进度 = `grep -c pending` 单调递减;完成 = pending 与 ledgered 双清零**(每文件终局:converged /
  reviewed-clean / exempt 三者其一)。P4 每批迁移完的文件同提交推状态;从未被任何批碰到的文件由
  **全量扫尾批**(P4 尾段)逐个清。

### 3.4 四轨完成判据(机器可判定)

| 轨 | 完成 = | 判定者 |
|---|---|---|
| A 视觉收敛 | 手搓类基线 = 0 **且** 被吃掉的旧原语物理删除(死码清零) **且** 覆盖台账 pending/ledgered 双清零(§3.3b) | guard 测试 + 死码扫描 + coverage guard |
| B 规范科学化 | token/文法类基线 = 0 **且** 文法入 `design-system.md` 与代码逐字同步 | guard + `make docs` |
| C 性能 | 主面场景套件(流式/滚动/切海洋/编辑器打字/图渲染/手风琴/冷启动)release trace 全部达预算 **且** 预算测试常驻 fe-verify **且** 嫌疑人台账清零(测量定罪或测量赦免) | 预算测试 |
| D demo 全展示 | 可达性矩阵测试绿(每 feature × 关键状态在 demo fixture 可达) | 矩阵测试(仿 `chat_showcase_fixture_test` 先例) |

### 3.5 /goal 判据(供设 goal 用)

`A/B 基线为空 ∧ 覆盖分母 pending·ledgered 双清零(§3.3b) ∧ C 预算测试绿(主面场景套件全覆盖) ∧ D 矩阵测试绿 ∧ §6 台账无 open 条目 ∧ §7 之外无未记录跳过`

## §4 四轨 scope

### A 视觉收敛(原语六族 + 手搓清剿)

| 族 | 当家件(收敛目标) | 吃掉谁(初步,P1 普查定稿) |
|---|---|---|
| 窗(机器产物容器) | **`AnWindow` ✅批4**(P2 拍板改判=纯壳不嗅探:child?/header 单行/actions/maxHeight+collapsible/footer 注记 + 叶子律 assert;tone 槽与内容模式方案被法典否决) | ToolWindow ✅批4 物理删除、ProseWindow/MemoryNoteCard 壳 ✅批4 并入、approval 信笺/subagent 卡 ✅批1 |
| 代码 | AnCodeEditor + **live 模式**(同壳同框同 copy 位;P2 拍板改判=live 全量高亮+行号+有界贴底视口,两脸同档零跳变) | builds/Write 灰框裸 mono、AnLiveCodeWindow(批2 已吃掉并物理删除) |
| 芯片 | 一个 chip 族:tone/icon/mono/copy/nav 热插拔 | AnBadge/AnRefPill/AnCopyChip/AnPathChip/一切手搓 chip(_beltChip/_morphChip/op ticker 点…) |
| 行(键值/标签-值) | AnKv(`an_kv.dart`)+AnFieldSection+AnFormField+AnLedgerRow/AnLedgerList+AnLadder,排布选型查表成文 | ToolIOSection 私排、_metaRow、_RunRow/_nodeRow/_WebHits/_ToolHitCard、TodoChecklist、手搓 escape×2(**✅批6 已吃掉并物理删除**) |
| 条(结果/状态条) | 一条 AnStatBar,槽位化 | RunStatBar/ExecResultBar/_InvokeStatBar |
| 活尾 | AnTermTail 一件 | ToolLiveTail(v1/v2 并存至今) |

### B 规范科学化(文法成文 + 静态可判项进棘轮)

① **间距续账**——旧间距战役(AnGap/AnInset/AnFlow)P3「铺满全原语+各面」未完,并入本轨清账;档位封闭+禁裸算术。② 色调语义(ok/warn/danger/accent 用法规则;禁 `withValues` 私调透明档)。③ 圆角/边框档选档规则。④ 图标尺寸档(禁现场减法)。⑤ 动效(时长档 + reduced-motion 统一处理模式)。⑥ 状态渲染(loading/empty/error 一律 AnState,清手搓 skeleton)。⑦ i18n 键分类学。产出=版式文法章入 `design-system.md` + gallery 正反例页。

### C 性能(测量先行,全覆盖自驱——不等靶子)

- **方法论**:release 复现定性(用户日常 debug,先排除假象)→ trace 基建(DevTools timeline 脚本化采集)→ **主面场景套件**定预算:长对话流式 / transcript 滚动 / 海洋切换 / documents 打字 / entities 图渲染 / 右岛手风琴 / 冷启动 → 修 → 预算测试入 fe-verify。
- **已知嫌疑人**(仅供 P1 参考,测量定罪):收起工具卡体每帧陪跑构建(AnExpandReveal child 恒构造)/族体每帧全量 `jsonDecode` resultText/常驻 Timer·shimmer(N 活卡=N 每秒 setState)/transcript 流式期重建范围。
- **每步顺手做好**(决策 #7):P4 每一批迁移同时清掉所在文件的性能违规——动一个文件只动一次。
- 仓内已有资产:W0 流式压力床、perf specimens——升级为常设预算门禁。

### D demo 全展示

- **可达性矩阵**:每 feature × 关键状态 → demo 里怎么到达(哪个会话/实体/操作);缺口补 fixture 种子。
- 已知缺口(P1 定稿):entities 的 trigger/control/approval/flowrun 面、documents 编辑器各状态、settings 面板 fixture 数据、notifications 托盘各状态、右岛各 kind 舞台稳定复现入口。
- **守住规范**:不加 per-feature 入口,全部经更富种子 + 展台会话进唯一 `AppShell`。
- 收口=矩阵测试(每 feature×状态断言可达,缺=红)。

## §5 路线与批次门

| 相位 | 内容 | 门 |
|---|---|---|
| **P0 定纲** ✅ | scope/harness/四轨/判据/代号(本档,2026-07-11) | 用户拍板 ✅ |
| **P1 四轨一把普查** | workflow 大扇出读全码,**一次出四份**:①手搓点全量台账 ②token/文法违规台账 ③性能嫌疑人清单(标注:仅嫌疑,测量定罪) ④demo 可达性矩阵缺口表;全部对抗核实;**棘轮 guard + 基线 v0 同批上线**(冻结现状) | 台账落 §6;guard 红绿可跑;fe-verify 绿 |
| **P2 法典** | 六族当家件 API 设计 + 版式文法成文;gallery mockup 逐族 | **🙋 用户逐族拍板**后冻结 |
| **P3 地基改造** | 当家原语长出 variant/slot(gallery 先行),旧件标记 deprecated | gallery 全 variant 展示;fe-verify 绿 |
| **P4 批量迁移** | 按族逐批机械替换;每批=建 → 对抗复审 → 真机 3–5 帧 → 台账/基线降+**覆盖状态推进**(同提交);**顺手清所在文件性能违规**;死件物理删除;尾段**全量扫尾批**清分母 pending | **基线到 0**;死码零;**coverage pending·ledgered 双清零** |
| **P5 性能轨** | 与 P2–P4 并行,按 §4-C 方法论推进(全覆盖场景套件) | 预算测试绿;嫌疑人台账清零 |
| **P6 收口** | **第二轮全新普查对空账**(抓第一轮盲区)→ design-system.md 整体重述 → landed-into → 归档 | `make docs` 绿;/goal 判据全满足 |

D 轨随时插批(纯加法零风险),矩阵测试随最后一批收口。

## §6 台账(P1 已填充 → 本体在 [`convergence-ledgers.md`](convergence-ledgers.md) WRK-067)

P1 普查完成(2026-07-11,11 区 finder + 20 条抽样对抗审计,**假阳率 0/20**):

| 轨 | 规模 | 摘要 |
|---|---|---|
| **A 视觉收敛** | **115 条** open | 按族:行 34 · 芯片 25 · 窗 18 · 其它 17 · 条 9 · 活尾 7 · 代码 5;工作量 S70/M41/L4。§4-A 初表全数坐实,另普查补录第四条结果条(`_RunFooter`)、双日志抽屉、状态点/状态色双系统等 |
| **B 规范科学化** | **75 条** open | 按域:间距 30(魔数视口高/裸算术/私铸常量)· 状态 14 · 动效 11 · 色调 9(含 feature 层私铸 hex 色盘)· 图标 5 · 圆角 2 · i18n 2 |
| **C 性能嫌疑** | **43 条** open(高危 8) | 嫌疑非定罪,P5 测量后转正式/赦免;高危含:收起卡体每帧陪跑构建、每卡 1s Timer、AnStatusDot 每实例常驻 AnimationController、切海洋整树替换 |
| **D demo 矩阵** | **35 GAP** open + 79 已可达 | 已可达行=矩阵测试断言底稿;GAP 集中在 entities 的 trigger/control/approval/flowrun 面、settings fixture 数据、notifications 各态 |

**机器账**(与本台账相交不相等):棘轮基线 `frontend/test/guards/convergence_baseline.txt` = 46 条目 · 62 处五类硬违规(guard 已上线,commit 8243538a)。

## §7 豁免记录(唯一合法的「不做」;用户签字才生效)

| # | 条目 | 理由 | 用户签字日期 |
|---|---|---|---|
| — | (空) | | |

## §8 开放问题

1. 基线文件最终格式:P1 试跑后按实际漂移情况微调(§3.3 的聚合计数形为起点)。
2. 六族划法/当家件取舍:P2 逐族拍板点,允许推翻 §4-A 初表。
3. C 轨主面场景套件的预算数值:P5 首轮测量后定档(先测后定,不拍脑袋)。
