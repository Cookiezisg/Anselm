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

# WRK-066 全 App 收敛战役 —— 视觉收敛 · 规范科学化 · 性能 · demo 全展示(四轨一伞)

> **本档是战役的唯一契约**:法典入口 + 四轨台账 + 棘轮基线 spec + 豁免记录全部住这里。
> 任何会话进入本战役,**第一动作是读本档台账**,不凭记忆续。纪律 binding 源在 [`CLAUDE.md`](../../../CLAUDE.md);
> 本档台账条目的关闭权见 §2.2——**建造者(AI)无权单方关闭任何条目**。

---

## §0 出身与目标

2026-07-11 用户对现状的四点批评(讨论定纲,全盘成立):

1. **手搓泛滥**:大量视觉件没走 An* 原语,族体文件的私有 `_helper` 是重灾区(不进 gallery、不受审)。
2. **原语只生不收**:G0–G6 49 件 + WRK-056 50 件 + 侧幕一批,从无 consolidation pass;同角色多件并存(三条结果条/两个活尾/四种带边框容器),本该是**一个当家件 + 热插拔 variant**。
3. **版式无文法**:左聚 vs 两端对齐等排布决策从未成文,选原语时没有「内容→角色→用哪件」的判断步骤,全靠现场发明。
4. **视觉选型错、绕开地基**:需求不满足时在 feature 层造新件(如 builds 活代码 = ToolWindow 塞裸 mono,而非给 AnCodeEditor 长 live 形态)——违反原则 #8「强化地基、非模块内重抄」。

**目标**:全 App 视觉规范统一收敛 + 规范科学化 + 性能达预算 + demo 全展示。信条:**越干净的组织 bug 越少,视觉也更统一**(本仓已证:WRK-065 修的一串 bug 全是重复实现各自烂)。

## §1 已拍板决策(2026-07-11 用户)

| # | 决策 |
|---|---|
| 1 | **scope = 全 App**(chat/entities/documents/settings/notifications/shell/gallery 全域;gallery 本身既是收敛对象也是最终法典) |
| 2 | **后端默认不碰**;demo 补种或性能修复需要的小端点逐案豁免(记 §6) |
| 3 | 四轨全要:**A 视觉收敛 / B 规范科学化 / C 性能 / D demo 全展示** |
| 4 | 优先序:P1 四轨一把普查 → A+B 法典拍板(决定一切的地基) → D 随手做 → C 按测量结果排 |
| 5 | 用户日常跑 `make app`(debug)→ C 轨第一步 = release 下复现定性 |
| 6 | **harness 六层 + 棘轮基线为主武器**(§2)——「别信自觉,信基线行数」 |

## §2 Harness(约束机器——防的是建造者自己)

### 2.1 设计输入:建造者的已证失效模式

① 提前宣捷(实锤:tool-cards.md 曾积压 7 个「待提取」尾巴) ② 质量随批次衰减 ③ 静默缩 scope(用「engineering judgment」包装跳过) ④ 自己给自己打分 ⑤ 跨会话失忆(compaction 后按残缺记忆行事) ⑥ 复发(战役结束后新代码重新手搓——本次的乱即来源)。

### 2.2 六层约束

| 层 | 机制 | 防什么 |
|---|---|---|
| **① 法典层** | P2 产出每族当家件 API + 版式文法,**用户逐族拍板后冻结**;争议回法典查表,不现场发明;法典入 `design-system.md`(reference 级,逐字同步代码) | 无据可依 |
| **② 台账层** | 本档 §5 四张台账,条目有编号+状态。**条目只能三种方式关闭:完成(有证据链) / 证伪(复审确认) / 用户签字豁免(§6)**——AI 无权单方关闭;台账更新与代码同提交(纪律 #9) | 静默消失 |
| **③ 门禁层** | **棘轮基线**(§2.3),战役**第一批就上线**(先立法冻结现状,整场仗=清空基线);性能预算测试、demo 可达性矩阵测试同理 | 复发 + 宣捷 |
| **④ 复审层** | 每批落地后,**全新上下文对抗复审 agent**(不带建造记忆,prompt 明令证伪)按台账逐条核;**复审不过 = 批次不关**(本仓已证有效:sceneFromTruth 4 修/手风琴 3 修/WRK-065 document·skill 漏网) | 自我打分 |
| **⑤ 验收层** | 每批真机截图自验 + 交用户 **3–5 张关键帧抽查**;只有法典级决策要用户正式拍板(把用户时间压到最小最高杠杆点) | 测试绿但难看 |
| **⑥ 续航层** | `/goal` + Stop hook 挂机器判据(§2.5);每会话首动作=读本档台账;战役 memory 只记「重进入点」 | 跨会话失忆 |

### 2.3 棘轮基线机制(spec)

- **位置**:`frontend/test/guards/` 新 guard 测试 + 基线文件(入库,如 `convergence_baseline.txt`)。
- **格式(抗行号漂移)**:按 `文件 · 违规类别 → 计数` 聚合,行序稳定可 diff。**计数只许减不许增**(棘轮);文件删除/计数归零则条目必须删(防基线腐烂)。
- **规则**:扫描源码 → 与基线 diff → **任何文件任何类别计数超基线 = 测试红**(新违规从第一天起物理进不来);基线条目已不成立必须移除。
- **违规类别初表**(P1 定稿,features/ 层禁、core/ui 白名单):裸 `BoxDecoration` / 裸 `Border.all`·`borderRadius` / 裸 `Color`·`withValues` 私调 / **token 裸算术**(如 `AnSize.iconSm - 4` = 私铸尺寸档) / 裸 `EdgeInsets` 数字 / (B 轨补:tone 误用、动效 reduced 模式不一致等可静态判定项)。
- **进度 = 基线总计数单调递减,完成 = 基线为空**。任何人任何时刻 `wc -l` 可查,不依赖 AI 汇报。
- 先例:`type_scale_guard_test` 已证明此模式能长期守住(字重纪律)。

### 2.4 四轨完成判据(机器可判定)

| 轨 | 完成 = | 判定者 |
|---|---|---|
| A 视觉收敛 | 手搓类基线 = 0 **且** 被吃掉的旧原语物理删除(死码清零) | guard 测试 + 死码扫描 |
| B 规范科学化 | token/文法类基线 = 0 **且** 文法入 `design-system.md` 与代码逐字同步 | guard + `make docs` |
| C 性能 | 靶子场景 release trace 达预算 **且** 预算测试常驻 fe-verify **且** 用户真机试用签字 | 预算测试 + 用户 |
| D demo 全展示 | 可达性矩阵测试绿(每 feature × 关键状态在 demo fixture 可达) | 矩阵测试(仿 `chat_showcase_fixture_test` 先例) |

### 2.5 /goal 判据(供设 goal 用)

`A/B 基线为空 ∧ C 预算测试绿+用户签字 ∧ D 矩阵测试绿 ∧ §5 台账无 open 条目 ∧ §6 之外无未记录跳过`

## §3 四轨 scope

### A 视觉收敛(原语六族 + 手搓清剿)

| 族 | 当家件(收敛目标) | 吃掉谁(初步,P1 普查定稿) |
|---|---|---|
| 窗(机器产物容器) | 一个窗壳:header/actions/tone 槽 + 内容模式(term/code/prose/json/diff) | ToolWindow、ProseWindow、各手搓描边卡(approval 信笺/subagent 卡/MemoryNoteCard 壳…) |
| 代码 | AnCodeEditor + **live 模式**(同壳同框同 copy 位,流动期 mono 尾、落定高亮——换脸不换壳) | builds/Write 灰框裸 mono、AnLiveCodeWindow |
| 芯片 | 一个 chip 族:tone/icon/mono/copy/nav 热插拔 | AnBadge/AnRefPill/AnCopyChip/AnPathChip/一切手搓 chip(_beltChip/_morphChip/op ticker 点…) |
| 行(键值/标签-值) | AnKv + 成文对齐文法 | ToolIOSection 标签排布、_metaRow、各手搓 label-value |
| 条(结果/状态条) | 一条 AnStatBar,槽位化 | RunStatBar/ExecResultBar/_InvokeStatBar |
| 活尾 | AnTermTail 一件 | ToolLiveTail(v1/v2 并存至今) |

### B 规范科学化(文法成文 + 静态可判项进棘轮)

① **间距续账**——旧间距战役(AnGap/AnInset/AnFlow)P3「铺满全原语+各面」未完,并入本轨清账;档位封闭+禁裸算术。② 色调语义(ok/warn/danger/accent 用法规则;禁 `withValues` 私调透明档)。③ 圆角/边框档选档规则。④ 图标尺寸档(禁现场减法)。⑤ 动效(时长档 + reduced-motion 统一处理模式)。⑥ 状态渲染(loading/empty/error 一律 AnState,清手搓 skeleton)。⑦ i18n 键分类学。产出=版式文法章入 `design-system.md` + gallery 正反例页。

### C 性能(测量先行,读码只出嫌疑人)

- **方法论**:先 release 复现定性(用户日常 debug,先排除假象)→ trace 基建(DevTools timeline 脚本化采集,靶子场景)→ 定预算(流式帧时/启动/滚动)→ 修 → 预算测试入 fe-verify。
- **已知嫌疑人**(仅供 P1 参考,以测量为准):收起工具卡体每帧陪跑构建(AnExpandReveal child 恒构造)/族体每帧全量 `jsonDecode` resultText/常驻 Timer·shimmer(N 活卡=N 每秒 setState)/transcript 流式期重建范围。
- 仓内已有资产:W0 流式压力床、perf specimens——升级为常设预算门禁。

### D demo 全展示

- **可达性矩阵**:每 feature × 关键状态 → demo 里怎么到达(哪个会话/实体/操作);缺口补 fixture 种子。
- 已知缺口(P1 定稿):entities 的 trigger/control/approval/flowrun 面、documents 编辑器各状态、settings 面板 fixture 数据、notifications 托盘各状态、右岛各 kind 舞台稳定复现入口。
- **守住规范**:不加 per-feature 入口,全部经更富种子 + 展台会话进唯一 `AppShell`。
- 收口=矩阵测试(每 feature×状态断言可达,缺=红)。

## §4 路线与批次门

| 相位 | 内容 | 门 |
|---|---|---|
| **P0 定纲** ✅ | scope/harness/四轨/判据(本档,2026-07-11) | 用户拍板 ✅ |
| **P1 四轨一把普查** | workflow 大扇出读全码,**一次出四份**:①手搓点全量台账 ②token/文法违规台账 ③性能嫌疑人清单(标注:仅嫌疑,测量定罪) ④demo 可达性矩阵缺口表;全部对抗核实;**棘轮 guard + 基线 v0 同批上线**(冻结现状) | 台账落 §5;guard 红绿可跑;fe-verify 绿 |
| **P2 法典** | 六族当家件 API 设计 + 版式文法成文;gallery mockup 逐族 | **🙋 用户逐族拍板**后冻结 |
| **P3 地基改造** | 当家原语长出 variant/slot(gallery 先行),旧件标记 deprecated | gallery 全 variant 展示;fe-verify 绿 |
| **P4 批量迁移** | 按族逐批机械替换;每批=建 → 对抗复审 → 真机 3–5 帧 → 台账/基线降(同提交);死件物理删除 | **基线到 0**;死码零 |
| **P5 性能轨** | 与 P2–P4 并行,按 §3-C 方法论推进 | 预算测试绿 + 用户签字 |
| **P6 收口** | **第二轮全新普查对空账**(抓第一轮盲区)→ design-system.md 整体重述 → landed-into → 归档 | `make docs` 绿;/goal 判据全满足 |

D 轨随时插批(纯加法零风险),矩阵测试随最后一批收口。

## §5 台账(P1 普查填充;状态:open / done / refuted / 豁免→§6)

### 5-A 视觉收敛台账
> 待 P1。格式:`A-### · 文件 · 违规/收敛项 · 状态 · 证据(commit/复审)`

### 5-B 规范科学化台账
> 待 P1。同上格式;间距旧账 P3 项并入。

### 5-C 性能台账
> 待 P1(嫌疑人)+ P5(测量定罪后转正式条目)。格式:`C-### · 场景 · 测量值→预算 · 状态`

### 5-D demo 可达性矩阵
> 待 P1。格式:`D-### · feature × 状态 · 到达路径(或 GAP) · 状态`

## §6 豁免记录(唯一合法的「不做」;用户签字才生效)

| # | 条目 | 理由 | 用户签字日期 |
|---|---|---|---|
| — | (空) | | |

## §7 开放问题

1. **C 轨靶子场景**:用户觉得「不顺」的 2–3 个具体场景(长对话流式?切海洋?documents 编辑?启动?)——待用户给,C 轨才有靶子。
2. 基线文件最终格式:P1 试跑后按实际漂移情况微调(§2.3 的聚合计数形为起点)。
3. 六族划法/当家件取舍:P2 逐族拍板点,允许推翻 §3-A 初表。
