---
id: WRK-069
type: working
status: draft
owner: @weilin
created: 2026-07-16
reviewed: 2026-07-16
review-due: 2026-10-14
audience: [human, ai]
---

# Scheduler 第四海洋 —— 产品形态与建造规范(已拍板)

> 终案 = **方案 B(渐进披露)为主胎** + **方案 C 活性宪法整体并入** + **方案 A 矩阵/失败聚合语义降级收编**(三判官共识:B 43/43、C 43/42.5/42,A 的矩阵为唯一真信息增量但须降为透镜)。判官指出的共同盲区(止血/批量/统计窗口/孤儿 run/T6 引擎报价/冷打开空窗/cancel 语义/misfire/空态/a11y)逐条吸收,见各节与 §16。
> 用户已拍板框架(不可推翻):托管自动化指挥中心,轴=workflow;run 无论来源皆归档于此;rail=运营投影;Overview/运营主页/run 旗舰三级;有操作权力;配置归 entities;E1 三流铁律;核心命题=信息全面 × 不乱。
> **2026-07-16 用户终拍板:原 6 项 open questions 全部按「最全最完整最彻底」方案判决**(§16 记档):①暂停/恢复调度=运行时权力就地开关 ②批量操作(批量批准/拒绝/replay/cancel)首发即做 ③矩阵第三脸做(**+联动格/甘特全宽破例——此半已于 0717 被用户当面否决作废,见下**) ④run 历史保留策略实装(Settings 存储面板配置+后端清理) ⑤排队段**引擎手术排期**(节点时间戳→甘特三段条) ⑥misfire=跳过+missed 记账,catchup 作为 trigger 配置项归 entities。
>
> **⚠️ 2026-07-17 用户当面否决判决③ 的「全宽」半**(矩阵第三脸半**保留**、已落):原话「你现在搞了这个超宽的东西。**我不允许有这种超宽的东西**。请都改回到标准的。如果甘特图真的信息不够展示,**可以弄那种可以左右滑动的**」。**新判决(不可推翻)**:①**全宽破例取消**——scheduler 全部区段回归标准 720 阅读列;②信息宽度不够的改**横向滚动**,在 720 内自己滑。**已执行**:`AnZonedPage`+`AnPageZone` **物理删除**(fullBleed 是其唯一存在理由 → 死码即删),两页回 `AnPage(child: Column)`(几何字节级同构=纯删非改写);三脸各自解决宽度(甘特 `[0,1]` 分数轨无损缩放 / 图 `InteractiveViewer` 平移缩放 / 矩阵自带 `RawScrollbar` 横滚 + 方向键 `ensureVisible`)。**法在 [`design-system.md`](../../references/frontend/design-system.md) §5 `AnPage` 条目「720 阅读列绝对律」**(全 App 宽度契约,含横滚件三条硬约束)。

> **⚠️ 2026-07-17(同日晚)用户拍板「主页重建」(§16-Q7,不可推翻)**:矩阵**升页顶常驻**(「Matrix 作用于所有 run,甘特/图作用于单次 run」——判决③ 的「矩阵=联动格第三脸/降为透镜」定性就此作废)、点列/点格**直接导航进 run 旗舰**(?node= 预选)、大表行单击=**行内速览卡**(?run= 展开行,底部联动格删除)、**页级 `AnTimeRangePicker`** 一颗胶囊治矩阵+大表(24h/7d/30d 下拉删除)、矩阵**时序左旧右新锚最新端**+左缘懒加载、健康头珠串删除。当前物理形态=§4;契约连带=工单⑩ 改 `?flowrunIds` 纯批查。

---

## 0. 两条宪法(本海洋防乱的机理级立法)

1. **脊柱=「问题→现场→证据」三级钻取**(B):Overview 答「要不要管」→ workflow 主页答「哪次坏了/多慢」→ run 详情答「为什么」。每页只回答一个问题,页内披露 ≤1 层(NN/g 硬限),证据永远在点击之后;「全面」= 每一跳都有完整出口,不靠一屏轰炸。
2. **活性军规**(C,三判官全票必收,可继承进 design-system):**tick 只改瞬时外观(色/呼吸/时长/进度),永不改几何(行序/视口/选区);几何变更只随用户动作或 durable 落账发生。** 推论:新 run 不插行走「N 条新运行」pill 归位;落定原地变色+洗亮;live 绝不夺视口;失败(一次)与人闸是唯二例外上浮(WRK-065 同律)。

另三条军规:**聚合先于明细**(Overview 绝不混排流水账);**成功是背景音**(见下,**分层**);**禁虚荣数字**(每个 KPI 过「决策测试」且必是预过滤深链,「总运行次数」禁入)。

**「成功是背景音」的适用层(用户 0717 判决 —— 本条曾写作「灰调海洋里唯一饱和像素是红/琥珀」,与 §7 状态学的 `started→done→绿` 直接打架,真机在调度轨上把矛盾摊开:同两次开火,轨上绿点、正下方「FAILURES·7D」红字。用户裁定**保持绿**,故本条按当前事实重述)**:

- **聚合层(KPI 牌 / 聚合区)——成功不出声**:成功既不出牌也不出数。「错过 0」这张牌**不存在**(牌不在本身就是好消息);没有「成功 N」「总运行次数」。这一层里成功的表达方式是**沉默**。
- **明细层(调度轨火点 / 台账状态点)——逐事件陈述事实,照 §7 状态学配色**:一个刻度开了火就是 `started→done→绿`,不因「绿是饱和色」而改判。**理由**:轨问的是**调度器**的问题(刻度有没有变成 run),不是 run 的结局问题——后者归失败区与 run 详情。两者相邻但不矛盾。
- **已知代价(判决时明知并接受)**:注意力梯度在轨上是反的——例行的(开火成功)是饱和绿、抢眼,异常的(错过 ✕)是中性灰、不抢眼。且「绿点正上方、红字正下方,说的是同两次」这个邻接读起来别扭。**这是明码标价的取舍,不是疏漏**;若日后要翻案,备选是 `started→中性`(靠 §7 已立的形状通道 实心/半环/空心/✗ 承载分辨,整轨零饱和像素)。

## 1. 定位与语法

- **rail 回答「现在」**:每个 workflow 此刻的运营态(在跑/等人/最近失败/下次调度),不是配置清单。
- **海洋回答「全部」**:Overview=全局盘面;运营主页=单 workflow 全史;run 详情=单次执行全证据。
- **entities 回答「定义」**:workflow/trigger/control/approval 的创建与编辑仍归 entities,本海洋只观测+运行时操作,处处深链互通(panel_registry 缝)。
- chat 执行的家在 chat 侧幕、实体手动测试的家在 entities 详情;但 **workflow 的每一次 run 无论来源(cron/webhook/manual/chat)都归档于此**,来源是 run 的字段+过滤器(工单①)。

## 2. 左岛 rail

行 = 现成 `AnSidebarList` + `SidebarRow{dot,label,meta}`(扩 meta 槽,零新件):

- **dot**(AnStatus 单源):蓝=在跑 > 琥珀=等人(parked)> 红=needsAttention 最近失败 > 无。蓝压琥珀沿 chat 心智(自愈叙事);红有 REST 持久字段兜底、completed 自愈熄灭。灰(inactive/draining)不占点位,走生命周期标签段。
- **label** = workflow 名单行。**meta** 单值:在跑「运行中·1m」(分钟粒度,单顶层 Timer,**禁逐秒跳字**——判官3「毛躁」裁定);有 cron「⏱ 3m 后」(⏱ 字形即调度徽,不另占槽;hover AnTooltip 给绝对时刻+时区);否则上次 run 相对时间;从未跑「—」。一行两信息封顶。
- **排序单轴=最近活动时间**(B 护空间记忆),但按活性军规执行:**行序只在 durable 事件(`run_started`/`run_terminal`)落账时重算**,tick 绝不重排,hover rail 期间钉住(C)。从未跑沉底折叠段「未运行 (n) ▸」;inactive 再沉一段「停用 (n) ▸」(GHA 三件套)。
- **Overview 固定首行**(headless SidebarType,sidebar_model 注释预留场景):右缘**等人计数徽**——rail 唯一数字,因它是唯一「需要你」的数。
- **数据**:workflow list + 工单③批量 stats(rail 逐页喂当页 ids,免 N+1)+ triggers `nextFireAt`(现成读时投影,纯前端)。真相=REST 行,帧只触发 refetch。
- **过滤框识别 `fr_` 前缀**:粘贴任何 fr_ id → GET /flowruns/{id} 补全宿主 → 直达 run 详情(解「拿着通知里的 fr_ id 无处可去」盲区)。
- **空态** AnRailStates:「还没有 workflow——去 Entities 创建,或让对话替你建」双深链。

```
│ ◫ Overview              ❷ │ ←等人计数徽
│ 🔎 过滤 / 粘贴 fr_ id…  ⚙ │
│ ● 数据清洗流水线  ⏱ 3m 后 │ ←蓝·在跑,有 cron
│ ◐ 周报生成        12m 前  │ ←琥珀·等人
│ ○ 库存同步        2h 前   │ ←红·最近失败
│ ○ 邮件归档        昨天    │
│ ▸ 未运行 (3)               │
│ ▸ 停用 (2)                 │
```

## 3. Overview 全局看板(`/scheduler`,无选中态)

单页 AnPage 720,自上而下按「需要人的程度」排,首屏完整可下滚:

1. **KPI 牌**(AnCard+AnCountUp):在跑 N / 等你 N / 24h 失败 N(**delta 箭头** ▲2,A 收编)/ 下次调度 in 3m / **错过 N**(判决⑥ **✅ 已落**,S6:**有 missed 才出现的第五牌**——「错过 0」过不了决策测试,是醒着的机器的常态,天天读 0 的牌是装饰且吃掉另外四张的宽[禁虚荣数字 军规];**牌不在,本身就是好消息**[成功是背景音]。增删只随 durable 重取、绝不随 tick,故活性军规允许这处几何变化。点击=**滚动到并洗亮调度轨**——它数的那些刻度就是轨上的 ✕,同窗同谓词)。

    **钻取 ✅ 全落**(五张牌逐张过「点开**它数的**那个列表」这条宪法——**24h 失败随判决⑮ 补后端接线后,最后一张惰性牌也点开了它的证据,五张全可深链**;共用**一个**揭示引擎=`_ZoneAnchor`[GlobalKey 锚 + 洗亮 seq,**seq 只在用户点击时变**故洗亮不可能因重取发生,活性军规]):

    - **在跑 N → 「正在跑」区** · **等你 N → 「等你处理」区**:牌的数字**就是**该区那份列表的 `length`,**别无来源**——两者同一个事实,只许一个源。**两个貌似更权威的后端计数被明确拒绝**:`totals.running` 是同一件事的**第二次计数**(第二条查询、第二个瞬间);`totals.parkedNodes` 尽管叫这个名,数的却是 **run**(一个 run park 在两个审批上=那边 1、这边 2 行)。顺带**修掉一个活着的口径 bug**:「正在跑」区旧的**逐 workflow 探针循环**(由 workflow 列表驱动)**永远走不到孤儿的 run**(宿主软删、run 照跑,§5.7 一等公民),而牌数着它——区头本就渲着自己的 `rows.length`,故「牌写 2、区头写 1」是**已经在屏上**的谎。现改为**一次工作区级提问** `GET /flowruns?status=running`(`workflowId` 一直是可选的,`ListFilter.WorkflowID` 空=全部;翻页拉全)→ N+1 变 1 次调用,孤儿行回落**裸 id** 显示。
    - **下次调度 → 轨上它念的那个刻度**:**可点性派生自它自己的证据在不在场**(`nextFireOnTrack`),而**不是**派生自「两个源但愿一致」——牌的值来自 `triggers.nextFireAt`、轨的刻度来自 `trigger-schedule`,**两个端点各在自己的读时投影 `cron.Next`、经两张不同的表连接(relation 边 vs 活的监听表),且只有轨被钳在 24h**;三条让所念时刻落在轴外的路都是真的(越过视野的周 cron / 监听表没解出的泳道 / 跨过 cron 边界的两次调用)。故**刻度在才可点**,越视野时牌**照说真话**(「in 1d」)但保持惰性。
    - **24h 失败 N → 「24h 失败」区(判决⑮ ✅ 已落,补后端接前端)**。它数的是窗口内**落定**为 failed 的 run(后端 `failedSince` 按 **`completed_at`** 开窗),而在工单⑮ 之前本海洋问得到的每一份 run 列表都按 **`started_at`** 开窗——照它建的列表会漏掉「30h 前起跑、1h 前失败」的那个,又会混进「窗内起跑、还在跑」的那个,故它曾是**唯一没有面表达得了其谓词**的牌。**判决=补后端**(迭代流程铁律②「必要时改后端」):`GET /flowruns` 加 **`?completedAfter`/`?completedBefore`**(completed_at 上的另一个半开窗,未落定 run 的 `completed_at` 为 NULL、`NULL >= ?` 永不为真故被剔除),与 `failedSince` **逐字节同谓词**(裸 `completed_at >= ?`;顺带修掉后端 `julianday()` 假「格式漂移」——实测无漂移且它只到毫秒会让牌与列表在窗口边缘打架);新增 `idx_fr_ws_status_completed` 索引(实测 50.3ms→33.6µs,EXPLAIN 守卫 `flowrun_plan_test.go`)。前端牌**深链到一个新的按 run 失败区** `SchedulerFailedZone`(仅非空时在场、`_ZoneAnchor` 揭示+洗亮),牌数=`failedRuns.length`(拉全 `listFailedSince(kpiSince)`,同 running/waiting 的口径同源——锚点 `kpiSince` 前端算一次、同一绝对时刻发给 stats 的 `?since=` 与列表的 `?completedAfter=`,突变体已验杀)。**下面的「失败聚合 7d」是宪法点名的那个相近但不同的列表**:按**连败**聚合 **workflow**、不按窗口聚合 run——整夜失败 4 次然后跑通的 workflow 在那里缺席(已自愈)、在这里(24h 按 run)在场,故两区**相邻同读而不相混**(不同窗、不同轴,链错就是「牌写 4、点开一个空区」)。
    - **零行即惰性**:「在跑 0」/「等你 0」/「24h 失败 0」不可点——没有列表可开,死可供性是谎(同失败区 [最新 run] 直通车的规矩);24h 失败牌的可点性与 `SchedulerFailedZone` 的在场是同一个条件 `failedRuns.isNotEmpty`(delta 可在 0 计数时仍非零=改善 ▼,牌仍显数与箭头、只是惰性)。
    - **a11y**:牌成控件即**念成控件**——label(句子说清这一下会做什么)+ `isButton` + **tap 动作**,**dump 实证**非推理。**label 标在卡内部、且只标 label**(`button`/`enabled` 的所有权留给 `AnCard` 的 `AnInteractive`,两份配置不共享旗标故合并成**一个**节点,design-system §2)。**顺带修掉第五张牌落地时的 a11y 形状**:从**外面**包一张 `ExcludeSemantics` 过的卡,实测丢 `isFocusable`/`hasEnabledState`,更要命的是丢 **tap 动作**——桌面上动作是少数真到得了读屏的东西之一,于是它念出一个**按不动**的按钮。
2. **等你处理**(最贵地皮):`/flowrun-inbox` 全集(工单④enrich 带 workflow 名+deadline),每行=workflow 名+节点+等待时长+**AnCountdown 超时倒计时**(新原语,单顶层 Timer 共驱)+`ApprovalGate` 就地批/拒(带 reason);决策后行滑出;first-wins 输家 422→诚实 toast+refetch。**批量操作(判决②)**:行首 hover checkbox,选中≥2 浮出 `AnBatchBar` 批量条(「已选 3 · [批量批准][批量拒绝▾(共用理由)]」);批量=前端逐发 decide+**显式挂账**(每行 pending→逐行落定滑出),first-wins 批量语义=输家 422 汇总 toast「已批准 2 · 1 条已被别处处理」。
3. **正在跑**:AnLedgerRow 活行=状态点+workflow 名+mono fr_ id+来源徽+节点进度 x/y+活耗时+hover ⏹ 取消。tick 只驱动本区外观;`run_started`(工单①)durable 加行。**多选批量取消**(判决②):AnBatchBar 同构,danger 弹窗带清单「将取消这 3 个 run」。
4. **调度时间轴「近 24h · 未来 24h」**(判决⑥ **✅ 已落**,S6):**一条轴、两半**——`AnScheduleTrack` 的过去实心点着状态色(真开过的火)/未来空心虚点(措辞「预计」)/**missed 灰 ✕**(机器睡过头的刻度必须有脸,桌面 app 第一现实;**灰不红**=§7「未执行」中性桶,刻意背离 Temporal 惯例)。**now 线居中而非偏左**(原句「now 线偏左」作废——判决⑥ 让过去半从装饰变成「错过 N」牌的**证据**,故 `trackPastWindow ≡ kpiWindow` **构造上**相等:轨若回看得比牌数的短,就会有被牌数进去、却落在它自己点开的那个面的轴外的刻度)。**已暂停 trigger 的泳道灰显不消失**(判决①:止血状态可见,标「已暂停」),且它仍带着暂停之前开过的火。仅 cron 有未来点,其余 kind 如实缺席;过去点亦只挂在 cron 泳道上(本区答的是**排程**,webhook 是外部事件、不是排程)。**两处独立截断各一句诚实话**:`truncated`(未来半:窗内还有更多预告)与 `pastTruncated`(过去半:firing 账无界且按新→旧翻页,故撞帽的一页是**最新那片**、`pastFrom` 之前是**未知**而非**空**——句子点名可信数据从哪开始)。
5. **失败聚合(7d)**:**Top-N 榜,「连续失败计数+自愈清除」定义**(A 收编,Temporal Task Issues:连败才值得浮顶,自愈行灰化留痕)——workflow 名+连败 ×N 徽+错误首句+**[最新 run] 直通车**(A 收编,跳过主页中转直达详情)+就地 replay(C)。宿主已软删的失败带「已删除」墓碑徽,行仍可点进 run 详情。

**零数据首用态**(盲区补):四区不渲空框废墟,整页收成一张教育卡——「第一个自动化还没建。去 Entities 建 workflow 并挂上 cron,或在对话里说『每天早上八点抓数据发我』」双深链 + 三行示意图。任一 workflow 出现即换正常盘面。

```
Scheduler · Overview
┌在跑 3┐┌等你 2┐┌24h失败 4 ▲2┐┌下次 3m┐   ←全可点深链
▎等你处理 (2)
◐ 周报生成 · fr_9a12 · approve_send  等 18m · ⏳剩 2h
  「本周报可以发出吗?」 理由[____] [拒绝][批准] 查看 run →
▎正在跑 (3)
● 数据清洗 fr_a1b2 cron   4/7 1m32s ⏹
● 库存同步 fr_c3d4 chat   2/5 12s   ⏹
▎未来 24h                 now┆
 清洗 ▪▪✕▪●┆─○────○────○─      ←实过去/✕missed/空心预计
 周报 ▪    ┆───○
▎失败聚合 (7d)
 库存同步  连败×4  HTTP 502…      [replay][最新 run →]
 归档清理† 已自愈  磁盘满(已删除)  [历史]
```

## 4. workflow 运营主页(`/scheduler/w/:id`)

单页 AnPage 文档流(不做平行 tab),四段(**0717 主页重建拍板**——矩阵升页顶、时间范围统一、行内速览取代底部联动格,判决 §16-Q7):

1. **文档化页头**(0717-晚 需求②③,entities 同文法 `AnOceanHeader`):页内面包屑「调度」→ 大标题=名 → meta 行(生命周期徽 · **范围统计句**[成功率/均时**跟随页级范围**——`schedulerRangeStatsProvider` 逐 (workflow,范围) 1-id 批查,窗按 `statsWindowOf` 映射进 stats `since`/`until`;句子窗口词=胶囊之词;**答案盖范围章**(provider 返 `(range, stats)`,widget 只在章与胶囊相符时渲数字)——换胶囊的 reload 期间 Riverpod 保留旧值,新词配旧数=句子撒谎,故切换期渲「—」等新数落地,同范围 rail 节拍重载章不变不闪] · **页级 `AnTimeRangePicker` 胶囊**)→ 右上动作([Run now]+⋯菜单[:kill / 去 entities 编辑])。**珠串已删**(0717 问题2)。健康统计到此为止,不开洞察页。
2. **矩阵区(页顶,0717 拍板;0717-晚 需求①②修形)**:**无段标题**(NODE × RUN 已删)、胶囊已上移页头 meta 行(**一颗胶囊治矩阵+大表+统计句**,大表原 24h/7d/30d 下拉已删)——**时序 `AnRunMatrix`** 直接坐页头下(旧在左新在右=时间轴,视口 `reverse` 锚最新端;滑近最旧缘懒加载更旧页[`SchedulerMatrixWindowController`:翻 `GET /flowruns` 页 → 逐页 `flowrun-matrix?flowrunIds=` 批查 → 归并,页尺 50=批帽,`runsById` 随窗累积供人话]、前插零位移;节点名车道冻结在滚动器外)。**列头两层**(需求①:颜色=状态/长度=耗时/蓝=在跑):上=选中指示条(选中墨色、平时透明占位),下=耗时比例条穿最终状态淡色(与格子同族),在跑实蓝满条;常驻灰基线删。**格阵是发射台**:点列头→直进该 run 旗舰页、点格→旗舰 + `?node=` 预选,行头惰性只作名;`?run=` 展开行的列被点亮(一个选区两处投影)。**列 tooltip/读屏=来源短语+时刻**(需求⑤,id 收 tooltip 末行)。空窗渲诚实句「这段时间没有运行」。
3. **run 大表**(0717-晚 需求⑤⑦重排):AnLedgerRow 列表+keyset 分页哨兵。**行文法=「来源词 · 开始时刻」**(`run_phrase.dart` 唯一文法:当天 HH:mm/跨天 M/D HH:mm;cron 旧 HH:mm 摘要并入统一后缀;GHA「cron run 全长一样」之鉴)+ **可操作动词紧随其后常驻**(在跑=⏹ 终止/失败=↻ 重试——不再是给所有行占位的 hover 行尾格)+ ↻N 徽;**右缘只留执行时长**(左边已说「何时」,旧相对 ago 删=同一事实说两遍);**行内无裸 id**(fr_/cv_ 药丸删,完整 id 收速览卡+tooltip);失败行错误首句(sub,danger;**lead 状态点与主文首行同心**——旧 s8 顶距红点漂移 bug 已修入 AnLedgerRow 原语)。**过滤=状态计数条**(全部|在跑 n|失败 n|等人 n——三数皆**范围内同文法探针**[复审⑤口径同源];「等人」走 inbox 派生,**绝不 `?status=parked`**)+来源下拉。新 run 不插行,表顶 pill 归位。**行内速览卡**:单击行=开合 `?run=`(一次一行、再点收起;`expandBuilder` 惰性[C-006]),卡=[甘特 ⇄ 图]双脸+状态点+id 药丸+对话药丸(origin=chat)+「打开 →」旗舰门,快速双击直进旗舰。**批量 replay(判决②)**:过滤到失败态后行首 checkbox 多选,AnBatchBar [↻ 批量重放]合并真数字;批量 cancel 同构。
4. **triggers 调度陈列**(只观测,编辑深链 entities):每 trigger 一卡=kind 脸+cron 人话+**下 3 次具体时刻**(B 收编,crontab.guru 双保险,防「翻译对但表达式错」)+lastFiredAt+近 30 次 firing 竖条串(Uptime Kuma,有界+hover)+「N 次 skipped ▸」两级钻取 activations→firings(skipped/superseded/shed/**missed**(判决⑥)处置词,灰不染红)+**[暂停/恢复] 止血开关**(判决①定案:运行时权力就地开关,工单⑦;cron 表达式编辑仍归 entities)+**misfire 策略行**(判决⑥:「跳过并记账」默认,catchup 配置深链 entities trigger 编辑面)。

```
数据清洗流水线 [active] ●●●✗●●●●✗● 80% · 均 42s  [Run now][⋯]
▎运行  [全部|在跑 2|失败 3|等人 0] 来源[全部▾] 窗口[7d▾]  ⌃2 条新运行
✗ cron·09:00   fr_c3d4  v7 7/7 8s   ↻1  超时: LLM…  1h 前 [↻]
● 对话「补数据」fr_a1b2  v7 4/7 已 1m32s            3m 前 [⏹]
✓ 手动         fr_7f00  v6 7/7 39s                 3h 前
        …加载更多…
┌ 本次运行 fr_c3d4 ──────────[甘特 ⇄ 图]· 打开 → ┐
│ fetch    ▬ 0.9s                                 │
│ analyze  ▬▬▬▬ 5.2s ✗                            │
│ notify   · 未及                                  │
└─────────────────────────────────────────────────┘
▎触发器(编辑归 Entities ↗)
⏱ cron 每天 09:00 · 下次 明 09:00、后天 09:00、周四 09:00(预计)
   ▂▄▆▂ 97% · 3 次 skipped ▸        [⏸ 暂停]
⚡ webhook /invoice · 上次 2h 前                    [⏸]
```

## 5. 单 run 旗舰详情页(`/scheduler/w/:id/runs/:frId`,主战场)

解法=**单选区 × 三海拔 × 右岛放大镜**:全信息在场,默认只渲轮廓;任何点击不跳页只换右岛的脸;三海拔共享同一节点选区(点图节点=甘特行洗亮=台账滚到该行=右岛换脸),Esc 清选区。

1. **卷宗头**(AnStatBar):终态徽+起止+耗时+vN 钉版+↻N+来源徽 + `ProvenanceLine` 一行(`cron 09:05 → firing trf_x → 对话「补数据」→`,逐环深链:firing→trigger 观测、conversation→chat W6 `?around=` 回现场)+操作钮。**错误摘要红句在头部,与台账失败行、甘特红条同句同源**(C 收编:一份文案三处投影,用户在哪层错误就在哪层)。
2. **流转图**(AnGraphCanvas 只读染色):**按 `flowrun.versionId` 取钉版拓扑**(顺修 run_cockpit 用 active 图看历史 run 的错图 bug);走过路径高亮/失败红环/parked 琥珀环/未及灰弱/循环 ×N 叠卡;图=导航器,点节点即选区。
3. **完整甘特**(AnNodeGantt 扩 props 非新件,**守 720 阅读列**——用户 0717 判决,全宽破例作废;甘特轨是归一化 `[0,1]` 分数、随宽度**无损缩放**,720 列下轨仍得 ~480–512px,故它是三脸里**唯一连横滚都不需要**的那个):时间刻度眉+hover 起止/毫秒+now 线;**running 条几何诚实延伸到 now**(C);**条分段三段(判决⑤定案):排队灰段(ready→started,工单⑫引擎手术供数)+执行段(状态色,工单⑤真时长)+parked 琥珀段(frn created→completed 真区间)**;⑫ 落地前按两段渲、⑤ 也未落时整体回退等宽顺序槽——分段能力跟着数据可得性走,不撒谎。台账行与卷宗头耗时同步拆「排队 x · 执行 y」。control 瞬时点。
4. **节点台账**(FlowrunNodeList 上收版):**失败/parked 稳定置顶,失败是唯一自动展开**(A/WRK-065 同律,首屏即见错误+I/O 入口);循环/扇出同节点折叠 ×N 一行计数展开(Temporal Compact);行=一行摘要(状态点+nodeId+#iter+耗时+错误句),行点击=选区→右岛,**页内披露只此一层**;诚实账头(byStatus 真数);页面本身零 JSON 倾倒。
5. **冷打开空窗**(盲区补,判官2 #2):DB 无 running 节点行——深链/重启进在跑 run 时,前端由钉版图+completed/parked 行推 ready 前沿,标**「推测执行中」弱蓝呼吸态**(词条 `scheduler.status.inferredRunning`),首个 tick 或对账 GET 到来即结实化;绝不空白也绝不装权威。
6. **活性**:tick 原地推进呼吸/甘特生长,视口不动;durable `run_terminal`→整页对账 refetch+一次落定洗亮(谢幕落账先例);parked 时 ApprovalGate 例外上浮台账顶。
7. **孤儿 run**:宿主 workflow 软删后本页仍可达(URL/深链/fr_ 直达),头部「宿主已删除」墓碑徽,操作钮除 replay 外禁用。

```
Scheduler / 数据清洗 / fr_c3d4
✗ 失败 · 09:12→09:12 · 8s · v7 钉版 · ↻1 · 来源 chat
出处: cron — · 对话「补数据」↗        [⟲ 重放(重跑1·复用6)][AI 诊断]
错误: analyze 超时: LLM 30s 无响应      ←头/台账/甘特同句同源
▎流转 (v7 钉版)
 (fetch✓)─(gate✓)─(analyze✗)┄(notify·未及,灰弱)
▎甘特            09:12:00 ────── :08
 fetch    ▬ 0.9s
 gate     · μs → port:high
 analyze  ▬▬▬▬▬ 5.2s ✗
 notify   未及
▎节点台账 (4 = ✓2 ✗1 ◌1) · 失败置顶·唯一自动展开
 ✗ analyze #0  5.2s  超时: LLM…   [I/O→右岛]  ←展开态
 ✓ gate    #0  → high
 ✓ fetch   #0  0.9s
 ◌ notify  未及
```

## 6. 右岛 = 双脸检查器(仅 run 详情揭示)

Overview/主页不占右岛(看板与页顶矩阵+行内速览自足,不为放而放);详情页右岛按需揭示,inspector 三元链加一支,零壳改:

- **无节点选中 = run 卷宗脸**(永不空白):pinned 闭包、replay 史、入口 payload、error 全文、`:triage` AI 诊断入口(202→conversationId 跳 chat)。
- **选中节点 = 检查器脸**:头(kind+nodeId+状态+**迭代切换器 `#0 ▾`**,C 收编——循环节点逐迭代取证)→ 错误 callout 全文 → 输入/输出 AnJsonTree(AnCap 折叠,650KB 级物理隔离于此)→ 执行日志深链(execId→entities)→ 上游行跳转 → **parked = ApprovalGate 就地决** → 失败 = 就地 replay。Esc 清选区回卷宗脸。

```
┌ 检查器 · analyze ──────────┐
│ ✗ 失败 · agent ag_x · #0 ▾│ ←迭代切换
│ 耗时 5.2s (09:12:02→:07)  │
│ ⚠ 超时: LLM 30s 无响应    │
│ ▸ 输入 {invoice: …}       │
│ ▸ 输出 —                  │
│ 执行日志 ex_9a2f ↗        │
│ [Replay 失败节点]          │
└───────────────────────────┘
```

## 7. 状态学(全表,单源 `status_state.dart`)

**后端枚举逐字对齐**:flowrun 头 CHECK 4 值 `running→completed/failed/cancelled`(first-wins,唯一回转 failed→running=:replay——**该回转写同样上 first-wins 守卫**〔`WHERE status='failed'`〕,并发 :replay 的输家得 422 而非把已落定的 run 复活;「等人」不是 run 状态);flowrun_nodes CHECK **4 值** `completed/failed/parked/cancelled`(**无 running 行**,呈现六态=行四态+合成 running+未及)——**`cancelled` 节点行**=被手动停掉的 run 所 park 的审批被收割时记的**真实处置**(唯一写者 `CancelParkedNodes`,且**只有赢得头守卫者**才收割),它落本节的**未执行**桶、渲中性灰;后端不变式:cancelled 行只存在于 cancelled run 上,故解释器永不走到它;firing 6 值 `pending→claimed→started` + 旁路 `skipped/superseded/shed`;workflow 生命周期 `active/draining/inactive` + 独立维度 `needsAttention`;approval=parked 行 first-wins,control 内联无 pending。

**呈现 6 桶(上限)**:在跑(running/合成/claimed)· 等人(running∧parked,inbox 派生桶)· 排队(pending/serial 推迟)· 成功(completed/started/fired)· 失败(failed/timeout)· **未执行**(cancelled/skipped/superseded/shed——中性处置非错误,染红=假警报;missed 落此桶带处置词,依工单⑨)。等人 vs 排队必须分(行动请求 vs 系统承诺),同琥珀靠词分裂。

> **「中性」是后端立法、不只是配色**(0716 对抗复审:`cancelled` 一词曾在三处三种互斥含义——节点行伪装 `failed` / 连败当**完全自愈** / 成功率中性,`domain/flowrun/stats.go` 相隔 8 行自打耳光)。现已收敛为**唯一立法**并在后端逐字执行:cancelled **两边都不算**——永不算失败,也**永不算健康的证据**;运行上与 running 同待遇(**透明**)。落点三处:①**连败** running 与 cancelled 均跳过、**只有 completed 停**(自愈=证明跑通)②**成功率**两边都不算 ③**节点行**记 `cancelled` 不记 failed。此立法的用户可见代价(反例):算失败 → 用户按的 ⏹ 读成故障;算健康 → **一次 ⏹ 就把正在进行的 3 连败整个从失败榜抹掉**(本页失败聚合按 `consecutiveFailures > 0` 过滤),且用 `replace` 策略的 workflow(每个被顶替的 run 都**自动**取消)连败**永久钉在 ~1**、零用户动作。

**AnStatus/AnTone 映射**:既有 alias 全覆盖主干(running→run 蓝/completed→done 绿/failed·timeout→err 红/cancelled·inactive→idle 灰/parked·pending·draining·claimed→wait 琥珀/started·fired·active→done);**仅新增 3 alias:skipped/superseded/shed→idle**。绝不出现平行色表(批7c 教训);色永不独行,点旁必有状态词+形状通道(实心/半环/空心/✗,WCAG 1.4.1)。

**rail 点优先级**:蓝>琥珀>红>无(§2);灰生命周期另一维。

**i18n `scheduler.status.*`**(slang,零硬编码):running 在跑/waiting 等你处理/queued 排队中/completed 成功/failed 失败/cancelled 已取消/skipped 已跳过/superseded 已顶替/shed 已作废/missed 已错过/parkedNode 等审批/inferredRunning 推测执行中/draining 收尾中/active·inactive 生效·停用/firingPending·firingStarted 待跑·已开跑/nextFire·lastRun 下次·上次 {time}/replayed 已重放 ×{n}。

## 8. 统计窗口立法(盲区补,单源常量档)

四处窗口各说各话本身即「乱」——全部窗口进单源常量档 `SchedulerWindows`(feature 根),i18n 句显式含窗口词:**矩阵+大表=页级时间范围**(0717 拍板:`schedulerTimeRangeProvider`,默认近 7 天预设,`AnTimeRangePicker` 一颗胶囊同治两区;预设是活表达式、每次取数现解析;矩阵页尺 `matrixPageSize=50`=flowrunIds 批帽);**失败聚合=7d 滚动**(凌晨 26h 前的失败不能漏窗——24h 否决);**KPI 失败牌=24h**(带 delta);**成功率/均时=7d**(工单③ `since` 参数统一)。珠串窗已死(珠串 0717 删除)。

**run 历史保留策略(判决④定案,实装)**:Settings **存储面板**加「Run 历史保留」配置项(30d/90d/180d/永久,默认 90d),工作区域持久化(后端 `settings.json`);后端定期清理任务按保留线清理 run 记录(工单⑬——须过 D1 立法:log 表物理删除的归档线例外要像 `:replay` 清 failed 行那样显式登记 database.md);统计与失败聚合窗口(≤7d)天然不受影响;run 大表翻至保留线出**诚实墓碑行**「更早的运行已按保留策略(90d)清理」,绝不无声消失。

## 9. 实时机制(E1 三流内,零新流)

订阅拓扑三条:**rail+Overview 常驻** `kindStream(entities,'workflow')` 一条 O(1);**选中页** `scopeStream(workflow:id)`(+图上 trigger 的 `scopeStream(trigger:id)`)autoDispose;**通知** `rawStream(notifications)` 按 `workflow.` 前缀。flowrun-watch 对账缝(tick 自滤+300ms 去抖 GET+4s 慢轮询兜底)自 run_terminal_controller 上收 core,三消费一源。

| 信号 | 性质 | 更新动作(严守活性军规) |
|---|---|---|
| `run_started`(工单①新) | durable | rail 行重排+Overview 在跑加行+stats refetch;大表顶 pill +1(不插行) |
| `run_terminal` | durable | 落账:refetch stats/行/inbox;详情页整页对账+落定洗亮;rail 重排 |
| tick(节点推进) | seq=0 | 只改瞬时外观:活图呼吸/甘特生长/进度/耗时;未知 flowrunId→去抖 refetch |
| `fire` | signal | refetch activations/nextFireAt(nextFireAt 无推送=接受,惰性刷) |
| `workflow.approval_pending`/`run_failed`/`attention_changed`/`lifecycle_changed` | notifications | refetch inbox/stats/行;**绝不据帧 +1**(N0 裁决) |
| 410 `SEQ_TOO_OLD` | — | resync:REST 全量重取再续订 |
| 断流 | — | 诚实「重连中」横幅,盘面不装活 |

铁律:DB 行是真相,ephemeral 只改瞬时视图;倒计时/活时长=单顶层 Timer 共驱(AnCountdown),绝不逐行 ticker(C 轨)。

## 10. 操作权力与确认(用户在哪层,权力就在哪层)

| 动作 | 端点 | 落位 | 确认 |
|---|---|---|---|
| Run now | `:trigger` | 主页头 | 无 |
| 取消单 run | 工单② `:cancel` | 详情头/大表行 hover/Overview 在跑行 | AnDialog danger:「将取消,parked 审批一并收回」——可重放非毁灭,不用 TypeToConfirm |
| 重放(仅 failed) | `:replay` | 详情头/失败行/失败聚合 | AnDialog **真数字**:「重跑 N 个失败节点,复用 M 个已完成结果」(A 收编,记忆化承诺文案) |
| `:kill` 整 workflow | 既有 | 主页 ⋯ 菜单唯一入口 | **AnTypeToConfirm**+影响面清单「将取消 N 个在途 run」 |
| 人闸 decide | `:decide` | Overview 等你处理/台账 parked 行/右岛,三处就地 | 无;first-wins 输家 422→toast「已被处理」+refetch |
| 暂停/恢复调度 | 工单⑦ | triggers 陈列行开关 | AnDialog:「暂停后不再产生新 firing,在途 run 不受影响」 |
| AI 诊断 | `:triage` | 失败详情头/右岛卷宗脸 | 202→conversationId 跳 chat |
| **批量批准/拒绝**(判决②) | 逐发 `:decide` | Overview 等你处理 AnBatchBar | 拒绝可共用 reason;first-wins 输家 422 汇总 toast |
| **批量 replay**(判决②) | 逐发 `:replay` | 主页大表失败过滤态 AnBatchBar | AnDialog 合并真数字「共重跑 N 节点,复用 M 结果」 |
| **批量 cancel**(判决②) | 逐发工单② `:cancel` | Overview 正在跑/大表 AnBatchBar | AnDialog danger 带清单「将取消这 N 个 run」 |

**批量语义统一**(盲区「批量挂账」判决落地):前端逐发+**显式挂账**(每行 pending 态→逐行落定/滑出,绝不假装原子);失败/422 逐行标注+汇总 toast;若真机发现逐发延迟不可接受再立批量端点(工单⑪ 预留,先不建)。

## 11. 路由

```
/scheduler                                Overview(可深链位置)
/scheduler/w/:workflowId                  运营主页(?run= = 行内速览展开的那一行,0717 拍板)
/scheduler/w/:workflowId/runs/:flowrunId  run 详情(?node= 节点选区深链)
```

全走 `_shellPage` 常量 key 壳永不重挂;`selectedSchedulerProvider` 只读单向派生自 URL;app_shell `ref.listen` 海洋拉动(深链自动切海洋);**panel_registry 登记 `flowrun`**(firing→宿主 run)→chat 卷宗/通知/entities 的 flowrun 引用全域自动点亮;headOwners 登记,面包屑 `shellHeadProvider.bind` 三段「Scheduler / 名 / fr_x」。选区(?node/?run)入 URL 可分享回现场;tab/过滤器不入 URL——**页级时间范围亦判不入 URL**(0717 裁:它是会话镜头非选区,`schedulerTimeRangeProvider` 常驻跨 workflow 存活)。矩阵点击**不写 ?run=**(0717 拍板:点列/点格=直接导航进旗舰,`?node=` 预选)。孤儿 run 路径在宿主软删后仍解析(墓碑态,§5-7)。

## 12. 原语复用清单与新原语规格

**直接复用**:AnSidebarList/AnRailStates/AnStatus(+3 alias)/AnLedgerRow/AnLedgerList/AnStatBar/AnRunBoard/AnGraphCanvas+deriveRunState/AnNodeGantt+flowrunTimeline/ApprovalGate/AnPage/AnSection/AnCard/AnCountUp/AnHeatBar/AnJsonTree/AnFollowPill.jump/AnWashHighlight/AnTypeToConfirm/AnDialog/AnTooltip/AnKv/AnChip(来源徽预设)/ToolIOSection/TriggerConfigCard。

**上收批(S0 前置,chat→core/ui,~2–3 天)**:FlowrunNodeList/ProvenanceLine(+toolNavPill 皮)/RunBeadStrip/RunLedgerRow/NodeTick+FlowrunProgress/runStatusWord;flowrun-watch 对账缝上收 core(三消费一源);i18n 迁 `scheduler.*` 或中性空间(先例 chat.stage.*→feedback.cast.*)。

**扩 props 非新件**:AnNodeGantt(+刻度眉/nowLine/hover/segments 执行·parked/live 延伸)、SidebarRow(+meta 槽)、AnFollowPill(+label)。

**新原语(gallery-first,先 specimen 再组装)**:
- `AnCountdown({required DateTime deadline, AnTone tone})` — 相对倒计时文本,单顶层 Timer 共驱,极薄。
- `AnScheduleTrack({required List<TrackLane> lanes, required DateTime now, Duration window, void Function(TrackEvent)? onTap})` — 绝对时间轴 CustomPainter:刻度眉+now 线+泳道点(过去实心着状态色/未来空心虚「预计」/missed ✕ 灰叉),bucket 聚合防爆+hover 清单。**a11y**(盲区补,W7 四播报先例):每 lane 一 Semantics 节点,事件读「{workflow} {time} {status}」,←→ 键盘遍历;gallery 验收含读屏走查。
- `AnRunMatrix`(0717 主页重建重铸):节点×run 格阵+列顶时长微条;**列=时序**(旧在左新在右,视口 `reverse` 锚最新端——offset 0=最新缘,首帧零跳动、前插旧页零位移)+ `onNearOldestEdge` 左缘懒加载缝(滞回)+ `loadingOlder` 转圈 + **节点名车道冻结在滚动器外**(右锚下滚内车道天然在屏外);**宿主守 720** → 自带横滚(`RawScrollbar(thumbVisibility)` 可发现 + 框架 `defaultTraversalRequestFocusCallback` 拖视口[原生对齐映射在 reverse 轴实测原样成立]);同套 Semantics 要求(行摘要随冻结车道行头走)。**落地偏差**:仍不虚拟化——列按 ≤50 有界页到达、只随用户显式滑动生长,widget 数由用户计量(深翻历史若成习惯,盯逐格 FocusNode 表)。当前形态法典化于 design-system §5。
- `AnTimeRangePicker`/`AnCalendar`(0717 拍板新原语,gallery-first 已落):Grafana 族页级时间范围——胶囊+双面板弹层(快捷预设点即生效存活表达式 / 绝对表单日期+时间双端+恒 6 行 42 格月历+显式应用;终点早于起点就地拒绝绝不交换);模型 `core/model/time_range.dart`(sealed 预设|绝对,闭分钟端→API 半开 [from,to+1min),月算术全构造器归一)。法典化于 design-system §5。
- `AnBatchBar`(判决②新原语):`({required int count, required List<BatchAction> actions, VoidCallback onClear})` — 多选浮出的批量操作条(「已选 N · [动作…] ✕」),挂在列表区顶;配套 hover checkbox 行选择模式;批量执行时驱动逐行 pending→落定的显式挂账呈现。gallery-first。
- **~~全宽豁免~~ → 720 阅读列绝对律**(用户 0717 当面否决判决③ 的全宽半):**全 App 无宽度豁免、无全宽逃生口**;运营主页矩阵/速览与 run 旗舰甘特/图区**一律守 720**,信息真比 720 宽的自带横滚(法在 design-system §5 `AnPage` 条目——含横滚件三条硬约束:滚动器在自己容器内 / 条即可发现性[非渐隐,渐隐会染状态色] / 键盘光标必须拖视口)。`AnZonedPage`+`AnPageZone` 已物理删除。

## 13. 后端工单清单(可直接开工;全套唯一 schema 变更=①两列)

- **① 来源 provenance + run_started 帧(P0,越晚旧行 null 越多)**:`flowruns` 加两可空列 `origin`(CHECK ∈ manual|chat|cron|webhook|fsnotify|sensor,写入定死)+ `conversation_id`;StartRun 签名带来源,chat `trigger_workflow` 传 conversationId,claimFiring 按 activation.kind 盖章;线缆 omitempty,旧行 null→前端 unknown 兜底。顺手:起 run 发 durable Signal `node.type="run_started"` content `{flowrunId, origin}`(scope=workflow;词表归 producer,不违 E1)。
- **② 单 run cancel(P0,引擎级并发设计——F174 同级报价,非薄端点)**:`POST /flowruns/{id}:cancel`,202 返 `{flowrun, nodes首页, nextCursor}`(对齐 :replay 形);仅 running 可取,否则 422 `FLOWRUN_NOT_CANCELLABLE`(登记 error-codes.md)。语义必须显式设计:守卫更新 `WHERE status='running'`→cancelled(first-wins,**先标头再 cancel ctx**)→cancel 该 run inflight ctx(取消传播进 LLM 流式)→**被打断在飞节点不落行、不误写 failed**(cancelled 不在节点行 CHECK 内,行只写终态语义不破)→`CancelParkedNodes` 收 parked(收件箱不留死项)→markRunTerminal 发 durable;与 record-once/replay 相容;取消 draining workflow 最后在途 run 触发 draining→inactive 结算(对齐 :kill)。
- **③ 运营统计批量(P0)**:`GET /flowrun-stats?workflowIds=<csv≤50>&recentN=10&since=`→`{totals:{running,completedSince,failedSince,parkedNodes}, byWorkflow:[{workflowId, running, lastRun, recent:[status…], successRate, avgElapsedMs, consecutiveFailures}]}`(**补 `consecutiveFailures`**——失败聚合「连败+自愈」语义的数据源);纯读投影,零新表零新列,有界批查 N4 豁免。
- **④ inbox enrich(P1)**:`GET /flowrun-inbox` 行补 `{workflowId, workflowName, deadline?}`(join run 头+workflow 名批读;deadline=parked.createdAt+approval 版本 timeout,复用 CheckTimeouts 解析);铃托盘顺手受益。
- **⑤ 按 run 聚合活动时长(P1,甘特+台账)**:`GET /flowruns/{id}/activity?cursor&limit`(N4)→`[{nodeId, iteration, kind, execId, status, startedAt, endedAt, elapsedMs}]`;UNION 四张执行日志表按 flowrun_id(偏索引已备)。**诚实报价**:此工单只给执行段;排队段由工单⑫引擎手术供数(判决⑤定案排期)。
- **⑥ 列表过滤器(P1)**:`GET /flowruns` 增 `?startedAfter&startedBefore&triggerId&origin=`(依赖①);非法值 422 大声拒带 allowed;零 schema 变更。
- **⑦ 暂停/恢复调度(P1,先调研)**:核实 trigger 域既有生命周期端点可否直用(listening/停用轴);缺则补 N5 `:pause`/`:resume`;语义=不再产生新 firing、在途 run 不受影响、nextFireAt 置空;归属已判决(§16-Q1):运行时权力就地开关。
- **⑧ 调度时间线(P2)**:`GET /trigger-schedule?within=168h&limit=200`→`[{at, triggerId, workflowIds}]`,cron `NextAfter` 迭代,顺解 trigger→workflow 反查断链;webhook 等无未来点不入线。
- **⑨ misfire 策略+missed 呈现 ✅ 已入库**(后端 `57556263`;前端 S6 收尾):**默认跳过+missed 记账**(本地 app 补跑风暴危险)——sidecar 睡醒后把错过的 firing 落 `missed` 处置态(不补跑),行 `createdAt` **回拨到错过的刻度本身**、`flowrunId` 恒空、`activationId` 恒空串;幂等靠 `idx_trf_dedup`(fired 与 missed 互斥)。**catchup 作为 trigger 级配置项**(默认 skip,可选 catchup-one=醒来补跑最近一次)已在 trigger 域,配置编辑归 entities trigger 面。**前端呈现**:时间轴灰 ✕ + Overview 第五牌(S6,判决⑥ 完成)。**firing 串「N 次 skipped ▸」两级钻取仍未做**(§4-4 的 trigger 卡,待 S7 起——`GET /firings?triggerId=` 的能力已在,只欠消费)。
- **⑩ 矩阵批量端点 ✅ 已入库(0717 主页重建改形)**:`GET /flowrun-matrix?flowrunIds=<csv,去重后 ≤50>` → `{cols,rows,cells}`——纯有界批查按**显式 run id 集**答格阵,逐字沿用 flowrun-stats ids 纪律(请求序去重/空集 400/越界 422 `FLOWRUN_MATRIX_TOO_MANY_IDS` 带 details);**recentN/workflowId 参数已按 #7 整体删除**(重建后零消费者——哪些 run 在屏上归客户端,它按时间窗文法翻 `GET /flowruns` 逐页批取)。**两条**有界查询(请求 run 头一条 orm `WhereIn` 重排回正典 `started_at DESC, id DESC`——**与请求顺序无关**,乱序不许左右行轴 + 节点行一条 `flowrun_id IN (…)` 走 `idx_frn_run`;零 schema 变更、绝不逐 run 拉详情)。**形不变的部分**:rows 首次出现序(刻意不用图拓扑序)、行带 `kind`(最新一次出现)、cells 稀疏、多迭代最坏处置聚合、刻意无逐格 elapsedMs。未知/异 workspace id **静默缺席**(cols 自带键、缺席可发现)。契约全文见 api.md;新错误码登记 error-codes.md(316 码)。
- **⑭ firings 工作区级检索 + 错过 KPI ✅ 已入库**(后端 `1e62a6b3`;判决⑥ 的最后一里,由 S5 偏差①② 提的单):**`GET /firings?triggerId=&status=&createdAfter=&createdBefore=&cursor=&limit=`**——**一个 handler 两个 URL**(扁平 workspace 级 + 既有 `GET /triggers/{id}/firings` 逐 trigger,路径 id 只是替 `?triggerId` 把 filter 填上、**不是**第二套文法);窗是 `created_at` 上的**半开区间** `[after, before)`,逐字沿用 flowruns 的窗口文法;N4 cursor+limit(firing 是**无界** Log,非有界投影豁免)。**`GET /flowrun-stats` 增 `totals.missed`**——数 `trigger_firings`,由 app 层经 scheduler 既有的 **FiringInbox 端口**缝入(domain 只拥有形状、不伸手够 store),**刻意排在 `q.Since` 默认化之后**故第五张牌与另外四张**物理上**同窗。**`firingQuery` 单点表达 filter 语义**,`SearchFirings`(页)与 `CountFirings`(数)共用——两份拷贝就是一个装了倒计时的 bug:牌上写 3、点开列表显示 4。三索引 `idx_trf_ws_{created,status,trigger}`(此前无任何索引带 `workspace_id`=每次读全表扫),EXPLAIN 守卫钉死走索引。零 schema 变更。
- **⑪ 批量操作端点(预留不建)**:批量语义首发=前端逐发+显式挂账(§10);真机若逐发延迟不可接受再立。
- **⑫ 节点排队时间戳引擎手术(P1,判决⑤定案排期)**:`flowrun_nodes` 补时间列(`ready_at`/`started_at`,或经工单⑤执行日志侧扩展——两径调研后择一),让甘特排队灰段有真数据;**必须与 record-once/replay 语义一起设计**:replay 重跑节点的旧戳怎么呈现(新迭代新戳/旧迭代戳保留)要立法进 database.md;这是六项判决里唯一的引擎级重活,排 S4 前完成。
- **⑬ run 历史保留清理 ✅ 已入库**:**配置域定案=机器级**(`<dataDir>/settings.json` 第三段 `retention`,与 limits/network 并列)——规范原话「工作区域持久化(后端 settings.json)」是**自相矛盾**的:settings.json 物理上无 workspace 维度(`Load(dataDir)` 无 ws 参、单份内存副本、boot 在任何 ws 存在前就读它,且有 `TestLimits_AreMachineGlobal_NotWorkspaceScoped`/F162 钉死);工作区级配置的既有机制是 `workspaces` 表列——为一条保留线加列/加表违「零 schema 变更优先」,且本地单用户下一台机器一条线即正确(与 limits/network 同立场)。**端点** `GET /retention` + `PATCH /retention`(照 network 平铺、非 `/settings/*`;PATCH **部分合并**基底=当前值,`{}` 是 no-op;**`0`=永久**且往返存活[fileShape 里该段用指针使段缺席与显式 0 可区分——值类型会把用户刻意的「永久」在下次 boot 读回成 90d 默认、开始删他的历史];负数 400 `SETTINGS_RETENTION_INVALID`;**30/90/180 值集不在后端强制**——那是产品可供性,拒 60 是校验剧场[#6],故无 `/retention/schema`)。**清理**:boot 起一趟 + 每 6h ticker + **每次 PATCH 踢一趟**(`SetOnRetentionChanged` 钩子→bootstrap buffered(1) kick channel;收紧的线立刻回收,否则用户改完 6h 内像坏了);逐 ws(Detached ctx)分批(200/事务,单连接 DB 上无界 DELETE 会阻塞所有写)、批间查 ctx 使关停在批边界停。**只删终态**(completed/failed/cancelled)且 `completed_at` 非 NULL 且严格早于 cutoff——**running/parked 永不删**(不管多老)、终态但断不了年份的(completed_at NULL)也留;窗口按 `completed_at` 开(与 stats 的 completedSince 同源:跑了很久刚失败的是**新鲜**的)。**级联**=头+节点行+**该 run 产生的**四张审计表行(同事务、子先于父、删头重申终态守卫使并发 `:replay` 赢);对话跑的 `flowrun_id=''` 不碰;firing/通知/触点**不删**(各有真相轴+`idx_trf_dedup` 是 D3 铁律),其 flowrunId 成悬挂引用→深链 404→孤儿墓碑。**墓碑信号裁量=前端读 settings 自渲、后端零特殊字段**(list 端点不加 `retentionDays`:墓碑是**呈现**决策,后端加个只为渲染服务的字段=契约污染;前端 S5 本就要读 `GET /retention` 渲存储面板的当前值,同一份真相顺手渲墓碑句)。**无 `:sweep` 端点**(裁量:清理是后台卫生非用户动作,PATCH 已给出「改配置即见效」的即时通路;测试用 app 层 `SweepRunRetention(ctx,cutoff)`——CheckTimeouts/SweepMisfires 签名家族)。**D1 立法**已登记 database.md flowrun 节(例外①`:replay` 清非结果 / **例外②保留清理删真实历史**——正当性=用户配置的容量治理、UI 出墓碑不留静默缺口、保留窗内真相完整)。**覆盖切分**:黑盒**没法给 run 倒签日期**(它造的 run 只有几秒大、线最紧 1 天),故「旧 run 被删」归单测(store 层精确时间戳钉死 cutoff 边界/终态过滤/级联/分批/幂等/D2);testend 证只有它能证的——HTTP 契约 + 收紧的线对真服务器踢真清理后新鲜历史仍在、进程仍健康(钩子在锁外触发,死锁/panic 在此现形)。Settings 存储面板前端工单随 S5。

- **⑮ `GET /flowruns` completed_at 窗 + 「24h 失败」牌接线 ✅ 已入库**(判决⑮——「消灭最后一条在册宪法违规:24h 失败牌不可点」;前一批证「不可接」的证明成立、但结论只对一半,补后端即可接):**`GET /flowruns` 加 `?completedAfter&completedBefore`**(completed_at 上的第二个半开窗,与 started_at 窗**逐字翻版**;未落定 run `completed_at` 为 NULL、`NULL >= ?` 永不真故任一界剔除它——刻意,`TestListRuns_CompletedWindow` 钉死)。**谓词与 `failedSince` 逐字节相同**(裸 `completed_at >= ?`):**顺带修掉后端一条真 bug**——`stats.go` 的 `since` 窗曾包 `julianday()` 声称归一「格式漂移」,**hex 实测无漂移**(落库 DATETIME 与绑定 time.Time 走同一序列化器 `2026-07-17 10:00:00+00:00`,前提=写者全 `.UTC()`,由 `TestTimeText_OrdersChronologically` 钉 225 对 + UTC 前提 + julianday 只到毫秒的反例),而 `julianday()` 只到毫秒会让一个界前 0.4ms 落定的 run 被牌数进、被列表剔除=「牌上写 3、点开列表显示 4」,故拆到裸比较(retention/matrix 的同款注释一并勘正;`julianday()` 只余 stats ① 的 `AVG` 时长算术)。**新索引 `idx_fr_ws_status_completed(workspace_id,status,completed_at DESC,id DESC)`**——`completed_at` 上此前零索引,牌深链 `?status=failed&completedAfter=` 在健康 workspace(24h 内 ~4 失败)会沿 `idx_fr_ws_created` 走遍整个 workspace 证明没有第 5 条,**实测 129,600 行 50.3ms→33.6µs(1,507×)**、逐条实测既有五读全不动;守卫 `flowrun_plan_test.go` 经记录型 driver 抓真 SQL EXPLAIN、断言索引名 + **完整谓词签名** + **用真实边界**(本索引靠选择性赢,NULL 参数下规划器看不见窗窄会误报——刻意背离 firings 守卫的 NULL 参数)、突变去索引即红。ORM keyset 键在 `started_at`(pointer 字段 `completed_at` keyset 不了),故排序不动、窗只 seek。复用既有 `FLOWRUN_LIST_INVALID_FILTER`(同资源、不另分码,对比 firings 的 `TRIGGER_FIRING_INVALID_FILTER` 刻意分码)。**前端接线**:牌深链新 `SchedulerFailedZone`(按 run 失败区,仅 `failedRuns.isNotEmpty` 时在场、`_ZoneAnchor` 揭示洗亮、紧挨 7d 失败聚合之上不相混),牌数=`failedRuns.length`(拉全 `listFailedSince(kpiSince)`,同 running/waiting 口径同源——`kpiSince` 前端算一次、同一 RFC3339 绝对时刻发给 stats `?since=` 与列表 `?completedAfter=`;`SAME PREDICATE` 测断言逐字节同锚,突变体「第二口钟」当场红);a11y 牌成控件即念控件(label 标卡内、delta 非零时并入句防 ExcludeSemantics 吞掉,零计数惰性=家具)。testend `TestFlowruns_CompletedWindow`(半开边界由 run 自己 completedAt 钉死 + NULL 剔除 `status=running&completedAfter` 空 + AND 组合 + 422)。文档 1:1 同步(api.md/database.md[补登先前漏登的 flowruns 四索引 + 索引立法块]/error-codes.md/foundation/scheduler-flowrun.md/contract 无字段变化不改)。

**记档不立单**:list 行 `pinnedRefs` 冗余重量(见性能痛再议 `?slim=`)。

## 14. 建造批次划分(每批:fe-verify 全绿+真机截图+demo 同批种齐+文档 1:1)

- **S0 地基 ✅**(无后端依赖):上收批六件(`core/run/`:run_ledger 三件/run_nav/flowrun_progress/flowrun_node_list/provenance_line+runStatusWord;唯一硬前置=23 个 `chat.tool.*` 键迁 core 可见顶层 `run.*` 命名空间,批6a)+AnStatus 3 alias(skipped/superseded/shed→idle)+OceanKind.scheduler 转已建(壳四处+isBuilt)+路由四段(`/scheduler`,`/w/:id`,`/w/:id/runs/:frId`,**`/runs/:frId` fr_ 直达中转位**)+`selectedSchedulerProvider` URL 单向派生(sealed 四态)+panel_registry `flowrun` 登记+headOwners+海洋一致性 listener+AnCountdown 进 gallery(单顶层 Timer 共驱)+S0 电池(解析表/alias/倒计时三态/共享 Timer)。**两处有据偏差**:demo fixture 骨架随 S1(repo 契约依赖工单③形,先建无意义);flowrun-watch 缝上收改 S4(侦察裁定:RunTerminalController 深耦 entity_repository 且 keyed by EntityRef,整收不现实,S4 起 scheduler controller 时抽共享逻辑)。**验收**:chat 758 测零回归;analyze 净;S0 电池 9 测绿;覆盖台账对账(整迁三件保留已挣状态)。
- **S1 rail**(依赖③):AnSidebarList 接线+三状态点+durable 重排/hover 钉住+未运行·停用折叠段+Overview 固定行+fr_ 直达+空态。**验收**:真机 rail 全态(demo 电池);tick 不重排的对抗测试;`fr_` 粘贴直达。
- **S2 Overview**(依赖③④):KPI 牌+delta/等你处理(AnCountdown+ApprovalGate 就地+first-wins 422 toast+**AnBatchBar 批量批准/拒绝**[判决②,原语随本批进 gallery])/正在跑(+**批量取消**)/失败聚合(连败语义+[最新 run]+墓碑)/未来调度简版行/零数据首用卡。**验收**:四区空态与满态真机帧;倒计时单 Timer(性能预算);牌全深链;批量挂账逐行落定真机走查。
  - **S2a 已落(2026-07-16)**:看板第一拍=KPI 牌四张(在跑/等你/24h 失败+**delta 双窗差分**[stats(24h)/stats(48h),▲红▼绿 0 隐]/下次调度=rail nextFire 全局最早)+正在跑区(repo 新 `listFlowruns`,AnLedgerRow:状态点+名+fr_ chip+活耗时[AnTimePulse 半分钟脉搏只改字],点行进旗舰路径)+未来 24h 简版(rail 的 triggers/edges **同源带出**,(trigger×workflow) 对时间升序,空态灰句)+失败聚合(连败 Top-5 降序+`?status=failed&limit=1` 探针取错误首句+[最新 run →] 直通车,探不到不假可点)+零数据教育卡(AnState+双深链走海洋 provider);refetch 拓扑=overview watch rail.future(durable 去抖同拍,tick 永不达)。fixture 全态种齐+demo_fixture_test 断言;widget 电池(满/空/delta 双向/首用/深链/错态)。fe-verify 3840 绿。**有据偏差**:①KPI 牌本拍不可点(真过滤深链随 S3 大表;无目标不做成可点)②失败行无 replay(确认文案真数字依赖 run composite,S4)③自愈行不渲(7d 语义细化随 S3)④「等你处理」区+AnBatchBar=S2b(已落,见下)。
  - **S2b 已落(2026-07-16)**:Overview 第二拍=「等你处理」完全体+批量操作+正在跑接取消。**repo 扩三方法**(`listInbox()` 解析工单④ enrich 行 `SchedulerInboxRow{node,workflowId,workflowName,deadline?}`[软删名回落裸 id 前端再兜一层;deadline 键缺席=null 不渲倒计时] / `decideApproval` 信封形照抄 entities[postEntity→FlowrunComposite,reason 可选] / `cancelRun` 工单②[:cancel 同 :replay 信封];**repo.waitingCount() 删除**——rail `_fetch` 改拉 `listInbox()` 全行随 `SchedulerRailData.inbox` 带出,`waitingCount` 降为 `inbox.length` getter,**牌/徽/区三处同一 fetch 同一真相**[provider 合一裁量:不另立 inbox provider,沿 rail 唯一节拍,零新订阅])。**等你处理区**(`SchedulerWaitingZone`,KPI 与正在跑之间):行=琥珀点+workflowName+nodeId chip+mono fr_ chip+等待时长(AnTimePulse 半分钟脉搏)+AnCountdown(有 deadline 才渲;超时红脸)+就地 `ApprovalGate`(reason 输入按节点 allowReason)——**ApprovalGate 上收 `core/run/`**(features 互不依赖,scheduler 不能 import entities;照 S0 上收批先例,i18n 5 键 `entities.run.{approvalTitle,approve,reject,approvalHint,reasonHint}` 迁顶层 `run.*`,entities 三消费点+测试同步);决策成功行 AnExpandReveal 滑出→延迟对账 refetch 收行(活性军规:用户动作几何变更合法);first-wins 422→诚实 toast「已被处理」+refetch。**AnBatchBar 新原语**(gallery-first:`core/ui/an_batch_bar.dart`+specimen 进 catalog G1;`AnBatchBar{count,actions:[BatchAction{label,icon?,tone,onRun}],onClear,busy}` count≤0 渲空+busy 冻结;配套 `AnBatchCheck` 行选择框[12px 合 lead 定宽格,真 checked 语义非 Material Checkbox]):行首 hover 换框、选中≥2 浮出条;**批量=前端逐发+显式挂账**(逐行 pending spinner→落定滑出,绝不装原子;`_BatchZone` mixin 两区共享引擎)——批量批准直发 / **批量拒绝共用理由=内联收集条**(有据偏差:AnDialog v1 无输入位,理由条贴条浮出,非模态弹窗)且理由只送 allowReason 行;汇总 toast「已批准 2 · 1 条已被别处处理」(非零桶入句,最坏桶定声调)。**正在跑区**(`SchedulerRunningZone`):行尾 hover ⏹(定宽格零位移,danger iconOnly)→AnDialog danger「将取消 …;parked 审批一并收回」→cancelRun→滑出+refetch;422→诚实 toast「run 已自行结束」+对账;**批量取消**同 AnBatchBar,danger 弹窗带行清单(逐行「名 · fr_id」)。**fixture 三形种齐+有状态**(带 deadline 剩~2h/无 deadline[allowReason:false]/宿主软删名回落且已超时;+wf_deploy 等人行;decide/cancel 有状态:决了行消失、取消后 running 行与其 parked 收件箱行同消[CancelParkedNodes]、二次操作诚实 422;totals 跟随动作)。i18n `scheduler.overview.*` 补 25 键+`feedback.batch.*` 2 键。**电池**:S2b widget 11 测(满/空/无 deadline/软删名/决策滑出/422 toast/批量挂账逐行落定+半输竞态/共用理由只送 allowReason/取消确认+422+批量清单)+AnBatchBar 原语 5 测+demo_fixture 3 测(三形/decide 有状态/cancel 有状态);S2a 电池随 stub 收编 `stub_scheduler_repo.dart` 共用。覆盖台账对账(approval_gate 整迁保留 converged)。
- **S3 运营主页**(依赖①②⑥⑦):健康头+大表(来源行身份+计数条过滤+pill 归位+**失败态批量 replay**[判决②])+联动格(甘特⇄图双脸先行)+triggers 陈列(下 3 次时刻+firing 串+skipped 钻取+**暂停/恢复开关**[判决①,工单⑦]+misfire 策略行)+:kill/Run now。**⚠️ 0717 主页重建(§16-Q7)已整体取代本批的联动格形态**:矩阵升页顶(时序+右锚+懒加载)、页级时间范围胶囊取代大表时间窗下拉、行内速览卡(?run= 展开行)取代底部联动格、珠串删除——当前物理形态见 §4。**验收**:过滤计数=真数;新 run 不插行走 pill;暂停后 nextFireAt 消失、rail meta 变「⏸ 已暂停」、Overview 泳道灰显;批量 replay 合并真数字弹窗。
  - **S3 已落(2026-07-16)**:`/scheduler/w/:id` 四段全体。**契约两补**(codegen 入库):`Flowrun.origin?`/`conversationId?`(工单① omitempty,旧行 null→unknown 脸)+ `TriggerEntity.paused`(工单⑦,paused 时线缆 `listening=false`+`nextFireAt` 缺席=契约三键同动)。**repo 扩八法**(`listFlowruns` 长全过滤参数[status/origin/triggerId/startedAfter·startedBefore 走 RFC3339 UTC]/`getWorkflow`/`getRunFull`[节点翻页拉全,**末页 `nextCursor` 是 `""` 非 null**——复合形在 data 内经 Go map 序列化,空串即完否则死循环]/`getRun`[limit=1 头对账读]/`runNow`/`killWorkflow`/`replayRun`/`pause·resumeTrigger`)。**新件**:~~`AnZonedPage`+`AnPageZone`~~(**0717 已物理删除**——用户当面否决全宽破例,fullBleed 是其唯一存在理由 → 死码即删;两页回 `AnPage(child: Column)`,几何字节级同构故是纯删非改写)· `scheduler_home_model.dart` 纯投影(`runListFilter` 唯一线缆文法/`runSourceOf` 来源短语/`waitingRunIds`/`replayCounts`)· `scheduler_home_provider.dart` 三 provider(workflow 详情/联动 run 复合/`RunTableState` 大表)· `batch_engine.dart`(`BatchZone` mixin 自 overview_zones **上收 feature 级**,S3 大表复用)· `scheduler_home.dart` 四段页。**①健康头**:名+生命周期徽+`RunBeadStrip` 近 10 珠+7d 统计句(successRate/avgElapsedMs 缺席渲「—」绝不 0%)+[Run now] 钮(打 `:trigger`→toast+回顶重取)+⋯菜单(去 Entities 编辑走 `goToPanel`/`:kill`→`AnTypeToConfirm` 内联揭示+**影响面真数**「将取消 N 个在途 run」取自 stats.running)。浮层头 `shellHeadProvider.bind`「Scheduler / 名」后帧绑(entities 先例),Overview 分支 `clear()` 收旧 crumb。**②run 大表**:`AnLedgerRow` 行**身份=来源短语**(cron·本次 HH:mm / 对话 / 手动 / webhook·path[config 胜过名] / 未知来源)、mono fr_ id 降 chip、失败行错误**首句**入 danger sub、耗时(落定 `fmtDuration` 精确 / 在跑走脉搏 `fmtWaited` 粗粒)、相对时间右缘;**计数条=真数**(在跑←stats / 失败←**同文法探针**[≤50 封顶越界渲「50+」] / 等人←inbox 派生,**绝不 `?status=parked`**)+来源·窗口两下拉(工单⑥ startedAfter);keyset 分页哨兵;**新 run 不插行**(durable `run_started`→`AnFollowPill.jump` 计数,点击 refetchTop 归位);hover 行尾定宽格 ⏹(running)/↻(failed);**批量**=`AnBatchBar`+逐发挂账(失败态批量 replay 合并真数字/在跑态批量 cancel 带清单——**选择模式限失败·在跑两态**,记裁量②)。**③联动格**(`?run=`):`AnPage` 里普通的 720 段(**0717 反转**:原为 `AnZonedPage` fullBleed 区),[甘特⇄图] 两脸 toggle(甘特=`flowrunTimeline`+`AnNodeGantt`,无时长数据时等宽顺序槽诚实渲[工单⑤⑫ 未入库];图=`AnGraphCanvas`+`deriveRunState` 只读染色)+格角「打开 →」深链旗舰;**双击行直进旗舰**(手工判 300ms,首击零延迟)。**④triggers 陈列**:逐卡 kind 图标+名+cron mono+调度句(下次相对+绝对/上次/从未)+**[⏸ 暂停/▶ 恢复]**(暂停走 AnDialog 点明语义「不再产生新 firing,在途 run 不受影响」;**恢复无害幂等不弹确认**,记裁量③)+暂停卡信息簇灰显+「已暂停」徽+编辑深链;三面(卡/rail meta/Overview 泳道)随**同一次 rail refresh** 跟随。**活性军规**:tick 永不达大表(`env.durable` 门 + scope 自滤)、`run_started` 只加 pill、`run_terminal` 走**单 run 对账读**(`getRun`)原位补行/滤出即收行、**保住已翻页上下文**(不整表回顶,记裁量④)。**电池 66 测**(纯投影 18[过滤文法/来源短语含旧行·未知词·断链 trigger/等人去重/replay 真数字] + widget 27[四段满/空/null stats 渲「—」/:kill 名字不对不执行/计数条真数+每次点击真到线缆/等人绝不发 parked/窗口·来源下拉真收窄/keyset 翻页/单·批量 replay 真数字+取数失败走无数字句/逐发挂账序/pill 三规则[durable 加 pill 不插行·tick 不达·他人台账不入]/暂停确认+取消不翻+恢复幂等/未知 workflow 诚实 not-found] + fixture 17[25+ 多页 run 史·全来源+旧行·失败带错误/过滤真收窄/逐 run 节点行/活跃版本图/paused 种子/pause·resume·replay·runNow·kill 全有状态] + `AnPage` 原语 4[**0717 反转**:原「散文钳 720/全宽=页宽−2×pageX/两类共存/窄海洋不溢出」四测→「每段钳 720/body 单轴纵向/窄海洋不溢出/逃生口已删」四测])。**i18n** `scheduler.home.*` 81 键 + `scheduler.status.*` 3 键双语。fe-verify **3937 绿**。
    - **有据偏差**:①~~「design-system §7 豁免表」物理不存在 → 全宽豁免改登记在 §5 `AnZonedPage` 条目~~ — **0717 整条作废**:豁免本身被用户否决,`AnZonedPage` 已删;§5 `AnPage` 条目改登记其**反面**=「720 阅读列绝对律」(无豁免 + 横滚件三条硬约束)。②**选择模式限失败·在跑两态**(all 态不混 replay/cancel 两种动作语义;规范未言明,记裁量)。③**恢复不弹确认**(暂停=止血须点明语义,恢复无害且幂等——弹窗是噪声)。④**terminal 对账不整表回顶**(单 run 读原位落定,保住用户已翻页的上下文;整表 refetch 会吞掉滚动位置)。⑤**cron 人话翻译未做**——pub 生态唯一候选 `cron_expression_descriptor` 无中文 locale(仅英文)、本项目双语强制,故本拍只渲 cron mono + nextFireAt 相对/绝对时刻;**「下 3 次具体时刻」记偏差待工单⑧**(`GET /trigger-schedule` 未入库,前端无第二、三次的真相来源——自算 cron 迭代=手搓且与后端调度器可能不一致,违原则 #8)。⑥**firing 竖条串与「N 次 skipped ▸」钻取未做**(需 firings 分页端点消费,范围控制,**待 S5**)。⑦**misfire 策略行未渲**(工单⑨ 未入库,无 catchup 配置真相可读)。⑧**chat 行 `[[id]]` 真名缝不存在**——现渲 mono `cv_` 药丸(经 panel_registry 可深链回对话);真名需跨 feature 的 conversation Namer(features 互不依赖,须先上收 core,不在本拍范围)。
- **S4 run 旗舰+右岛**(依赖⑤**+⑫**[判决⑤:排队时间戳引擎手术排本批前],②③已备):卷宗头+ProvenanceLine+错误同句三投影/钉版图(顺修 run_cockpit 错图 bug)/完整甘特(**三段条:排队灰+执行状态色+parked 琥珀**,running 伸 now,**守 720**[0717 反转;分数轨无损缩放故无需横滚];⑫未落回退两段、⑤未落回退等宽槽)/台账(失败置顶自动展开+×N 折叠+**耗时拆「排队·执行」**)/右岛双脸+迭代切换器+就地人闸·replay/冷打开推测态/孤儿墓碑。**验收**:三海拔单选区联动真机走查;冷打开在跑 run 不空白;650KB 注入电池不卡(build 预算);三段条与台账双数同源。
  - **S4 已落(2026-07-16)**:`/scheduler/w/:id/runs/:frId` 全体 + 右岛双脸 + `/scheduler/runs/:frId` 中转位。**契约两补**(codegen 入库):`FlowrunNode.readyAt?/startedAt?`(工单⑫ 两戳,omitempty;旧行与 seed trigger 行缺席=无排队段,绝不装 0)+ 新 `FlowrunActivityRow`(工单⑤:`{nodeId,iteration,kind,execId,status,readyAt?,startedAt,endedAt,elapsedMs}`;kind=审计表族非图节点 kind)。**repo 扩三法**(`listActivity` 翻页拉全+防御帽 / `getWorkflowVersion`[**端点已存在**:`GET /workflows/{id}/versions/{version}` 的 `{version}` 接版本号**或 wfv_ id**,故按 `flowrun.versionId` 直取钉版,无需新端点] / `triageRun`[`POST /executions/{id}:triage` 按 id 前缀分发,fr_ 走 flowrun 诊断→202 conversationId])。**新件**:`core/run/flowrun_watch.dart`(**S0 记档的 flowrun-watch 缝上收于此兑现**——整收 RunTerminalController 仍不现实[keyed by EntityRef + 深耦 entity_repository],但可共享的是**规则**而非状态机:`FlowrunWatch.{reconcileDelay,pollEvery}` 节拍 + `flowrunTickOf` 帧解析 + `FlowrunTick.row` 占位行 + `upsertNodeRow` record-once 合并;entities run_terminal_controller **已改吃同一缝**,三消费一源)· `scheduler_run_model.dart` 纯投影(`errorSentence` **唯一红句**/`nodeTiming`·`runTiming` 排队·执行·停车三拆/`foldNodeLedger` ×N 折叠+诊断置顶/`inferredRunningNodes` 复用 `deriveRunState`/`graphOfVersion`[scheduler_home 的私 `_graphOf` 并入])· `scheduler_run_provider.dart`(一 provider 持四读 + tick 只作画去抖对账 + durable `run_terminal` 整页对账并洗亮 + 活 run 慢轮询兜底)· `scheduler_run.dart` 四区页 · `scheduler_run_inspector.dart` 双脸 · `scheduler_run_relay.dart`。**扩件非新件**:`flowrun_timeline` 长出 `GanttChart`(绝对轴 + `timeMode` + `nowAt`)与三段 `GanttSegment`(`queueW`/`parkedW`/绝对起止/`execId`),`flowrunTimeline()` 兼容脸保留;`AnNodeGantt` 长出 `chart`/`ruler`/`nowLine`/hover 真起止;`FlowrunNodeList` 长出旗舰脸(`lines` 预折行 + 选区 + `onPick` + 唯一自动展开),朴素脸(chat 卡)零改;`fmtClock` 进 `time_format`(秒级钟点——分钟粒度会让刻度眉两端印出同一串)。**①卷宗头**:终态徽+起止+总耗时+**「排队 x · 执行 y」真数据**+钉版+↻N+来源徽+`ProvenanceLine` 逐环深链+错误红句(**`errorSentence` 算一次投影三处**:头/台账行/甘特红条同源)+操作钮(replay 真数字[**全量节点行已在页内,零额外取数**]/cancel/AI 诊断→跳 chat)。**②钉版图**:`getWorkflowVersion(versionId)` 取真图 → `deriveRunState` 只读染色 → 点节点=选区;**取不到钉版才回退 active 图且渲 `graphNotPinned` 横幅明说**。**③完整甘特**(**0717 反转**:原为全宽区,现守 720 阅读列——`[0,1]` 分数轨随宽度无损缩放,720 下轨仍 ~480–512px):刻度眉+now 线+三段条+hover 绝对起止与拆分;`timeMode=false`(时刻全重合)时**不画刻度眉/now 线**并渲「只表顺序不表时长」句。**④台账**:诚实账头+失败/parked 置顶+×N 一行(展开逐轮、点轮即选中该迭代)+失败唯一自动展开(错误全文)+parked 例外上浮 `ApprovalGate` 就地决。**⑤右岛双脸**:无选中=卷宗脸(run.error 全文/pinnedRefs 闭包/replay 史/`:triage`)、选中=检查器脸(头+迭代切换器[**单轮不长出**]+错误 callout+`AnJsonTree` **有界 viewport**[650KB 物理隔离于此,页面零 JSON]+execId 执行日志+就地人闸/replay);Esc 清选区回卷宗脸。**电池 55 测**(纯投影 24[错误首句三态/三拆含**审批人等不算执行**/负跨度钳制/×N 折叠与排序/推测前沿三态/三段条随数据可得性降级/塌缩轴回退] + widget 24[头三投影分工/钉版 vs active 真断言/墓碑/冷打开不空白/URL 选区双向/双脸切换/650KB 页面零 JSON 且岛内不炸/迭代切换器有无/execId/⑤ 读失败仍渲/中转位跳转与死 id 诚实错态/triage 跳 chat/replay 真数字/tick 只作画不进耐久缓存+兄弟 run 自滤+真相行不被覆退] + fixture 7[×3 循环+650KB/孤儿/冷打开/⑤ 同源派生/旧行无戳/triage])。**i18n** `scheduler.run.*` 44 键双语 + `run.inferredRunning`。fe-verify **3985 绿**。
    - **有据偏差**:①**`inferredRunning` 词条落在 `run.*` 而非规范 §7 所写的 `scheduler.status.*`**——渲它的是两个 **core 原语**(`FlowrunNodeList`/`AnNodeGantt`),而 core 不得读 feature 命名空间(批6a);两处各立一键即是平行词表(批7c 教训),故单源落 core 可见的 `run.*`,scheduler feature 也读它。②**`run_cockpit` 的错图 bug 未顺修**——本批把「按钉版取图」建在 scheduler repo 里;entities 的驾驶舱要同款须给 `entity_repository` 加 `getWorkflowVersion` + 改 cockpit state + fixture + 测试(features 互不依赖,不能借 scheduler 的缝),属独立一刀,**记账待办**,本批范围控制。③**失败行的页内披露=节点 error 全文**(非只指向右岛):`flowrun.error`(引擎摘要)与 `flowrun_nodes.error`(原始失败)是**两个字段**,头读前者、台账行读后者,不是重复;§5.4「首屏即见错误」由此兑现,而「页面零 JSON」仍守(错误是文本非 JSON,且走 `AnCap.monoErrorLines` 有界)。④**甘特刻度眉=起点/跨度/终点三锚**,非等分假刻度(run 跨度常在秒级,等分刻度会撞在一起)。⑤**`_live()` stub 修**:旧 stub 手抄字段、静默丢 `pinnedRefs`/`firingId`,改 `copyWith` 只覆有状态三字段——否则真丢字段也会一路绿灯。⑥**`demo_fixture_test` 的跨度断言改写**:旧断言 `completedAt - createdAt > 0` 编码的是 ⑫ 之前的假象(把 createdAt 当节点起点);真相行 `createdAt` = 写入时刻 ≈ `completedAt`,跨度住在两戳里,故改断言 `startedAt→completedAt` 并补 `createdAt == completedAt` 反向锁。
- **S5 增益**(依赖⑧⑨⑩⑬):AnScheduleTrack 真时间轴(+missed 灰叉+暂停泳道灰显)+**矩阵第三脸**(判决③,AnRunMatrix+工单⑩)+**Settings 存储面板「Run 历史保留」配置+大表保留墓碑行**(判决④,工单⑬)+Overview 错过 KPI 牌。**验收**:CustomPainter 两件 a11y 读屏走查+键盘遍历;矩阵横滚可发现性 + 方向键 `ensureVisible`(虚拟化列窗**证伪不做**,见 §11 偏差);保留策略端到端(改配置→清理→墓碑行)真机验。
  - **S5 已落(2026-07-17)**:两新原语 + 矩阵第三脸 + 保留线两端 + 窗口档。**契约四补**(codegen 入库):`TriggerSchedule`/`SchedulePoint`(⑧)· `FlowrunMatrix`/`MatrixCol`/`MatrixRow`/`MatrixCell`(⑩)· `RetentionConfig`(⑬,`core/contract/` 与 network 并列)· **`FiringStatus` 补第 7 值 `missed`**(⑨ 契约缺口:后端 `FiringStatuses` 7 值而 Dart 只 seal 了 6,`missed` 会静默解成 `unknown`——**发现即修**,同补 `AnStatus` 显式 alias `missed→idle`[四个处置词的 idle 是**裁决**、须在表里读得出,不靠 unknown 兜底])。**新原语两件**(gallery-first,规格见 design-system §5):`AnScheduleTrack`(13 测)+ `AnRunMatrix`(10 测),各带全文法 + 压力床 specimen 进 catalog `_entityViz`。**`SchedulerWindows` 窗口档**(§8 立法首次兑现):收编散落的 `recentN=10`/`since='168h'`/`'24h'`/`'48h'` 五处 + 矩阵的 20(唯一新值)。**repo 扩三法**(`triggerSchedule`/`runMatrix`/`retention` 只读)+ settings repo 扩两法(`getRetention`/`patchRetention`)。**Overview 未来区**:简版行列表 → 真轨道(泳道行集**取自 trigger 列表**、点只是挂件;暂停泳道灰显+「已暂停」;truncated 诚实句)。**运营主页**:`_PaneFace` 加 `matrix`(三脸走 `ctlSlotLg`)、**惰性**(不点不取数)、三粒度选区(点列/点格→`?run=` 落 URL[可分享];点行→本地节点透镜[本页无右岛,§6])。**保留线两端**:存储面板 `AnDropdown` 30/90/180/永久(节级 machine 域徽——存储是**混域**页,S-16 页头徽必撒谎;水化自线缆、**无 modified/onReset**[无客户端默认可比对]) + 大表末尾墓碑行(读同一条线缆自渲,永久=不渲)。**电池 +83**(原语 23 + 矩阵脸/墓碑 8 + 轨道 4 + 保留面板 3 + fixture 5 + 既有全绿)。fe-verify **4076 绿**。
    - **有据偏差(五条,均已核后端代码+文档双对账;**①② 已由工单⑭ + S6 关账**,见下)**:①**〔已解决 → S6〕过去点与 missed ✕ 无数据源 → 只渲未来 + now 线贴左**:`GET /triggers/{id}/firings` 是**逐 trigger、无时间窗过滤、无计数/聚合**(`FiringFilter` 只有 `{TriggerID,Status,Cursor,Limit}`),拉 24h 历史=把每个 trigger 的整本 firing 账逐页拖干、无界且随窗口回滚线性劣化;**只渲「拿得到的那部分 run」比不渲更糟**——skipped/superseded/missed 会成为一条看起来完整的轨道上的**隐形空洞**。原语的三张脸**已建全**(gallery+测试锁死),待后端补口子即接。②**〔已解决 → S6〕Overview 错过 KPI 牌不做**(同源):`flowrun-stats` 结构上够不着 `trigger_firings`(跨库域),无 firing count 端点;且**无时间窗的 all-time missed 是永远增长的虚荣数字**,违「禁虚荣数字」军规。→ **建议后端工单⑭**(两条,最省力位置已定位):`GET /triggers/{id}/firings` 补 `?createdAfter`/`?createdBefore`(`GET /flowruns` 已有同类参数先例可抄)+ **workspace 级批查路由**(store 层 `SearchFirings` **已支持 `TriggerID==""`**,只差一条路由);另需 firing count/stats(可能在 trigger 域新开 `GET /trigger-firing-stats`,而非扩 flowrun-stats)。③**矩阵不虚拟化**(§12 写「虚拟化列窗」时后端上限未定):`recentN` 后端钳 20(默认即上限)、行是图节点(几十不是几千)、格**全部可见**→ 官方 `ListView` 的「构造全部 vs 只构造可见」之差为 0,虚拟化连理论收益都没有;`TableView` 另有 `shrinkWrap` 缺口(flutter#155537 OPEN)会逼出死高度。改为按内容定尺寸 + 仅窄宿主横向自滚。④**`SchedulerWindows` 放 `features/scheduler/` 而非 §8 所写的 core**:core 是 features **共享**之物,本 feature 之外无人读这些——scheduler 专用表停在 core 正是此法要防的污染(同 S4 偏差① 先例:放它诚实该在的地方并记档);后端独立钉同一组数(matrix.go 按名引用本表)=共享的**决定**、非共享的 import。⑤**`missed` 灰不红**:外部惯例(Temporal)把 missed 判为**故障**渲红,本项目 §7 状态学与判决⑥ 明立「未执行」中性桶——**依本项目法**(本地桌面 app 夜里睡觉是常态而非故障),记此为**刻意背离**外部最佳实践、非疏漏。
    - **a11y 走查结论(§12 硬要求)**:①**←→ 键盘遍历成立**——每个事件点/格/头是真 `AnInteractive`(=`FocusableActionDetector`),`WidgetsApp.defaultShortcuts` 默认把四方向键绑到 `DirectionalFocusIntent`,故方向遍历由**框架**给、零手搓(原则 #8)。②**每 lane 一 Semantics 容器 + 逐事件「{workflow} {time} {status}」**已落,`explicitChildNodes: true` 是承重的(语义树 dump 实证:没有它容器会吸收后代 label、点不再是可寻址节点)。③**桌面 role 层不可用是硬约束**(Flutter 桌面仅 9 role 存活,table/row/cell/grid **不过 embedder ABI**;flutter#100056 OPEN 官方确认 NVDA 只读文本;Windows UIA 编译关闭只剩无 table pattern 的 MSAA)→ 坐标只能**编码进 label**,已照此渲(矩阵逐格/列/行 label 由调用方给)。④**唯一 a11y 待决项(需用户拍板)**:APG grid 规范要求「整个格阵=**单个** tab stop + 作者自管内部焦点移动」(roving tabindex),而当前每格/每点各是一个 tab stop——20×24 格阵=数百个 Tab 停靠。改法有标准解(`FocusTraversalGroup(descendantsAreTraversable:false)` + `Shortcuts` 重绑方向键为自定义 `_MoveCell` Intent + `activeCell` 索引 + `SemanticsService.announce` 播报坐标[桌面 `liveRegion` 是 no-op]),但那是**换焦点模型**(格子不再是焦点节点、选中态改为画出来的),属独立一刀,**不在最后一批里单方面重写**——记账待用户裁。

- **S6 判决⑥ 收尾 ✅ 已落(2026-07-17,依赖工单⑭)**:S5 偏差①② 关账——**一条时间轴长齐两半**。**契约两补**(codegen 入库):`SchedulerTotals` 补 `missed`(⑭)· `FiringStatus` doc **勘正**(旧注仍写「只发真六种」,与它下面一行的「7 values」自相矛盾——`missed` 早已在集合内;同 `contract.md` §「仅 seal 真封闭集」把 FiringStatus 写成 6 值,两处**同一个** stale 事实,一并修)。**repo 扩一法** `listFirings({triggerId,status,createdAfter,createdBefore,cursor,limit})`,逐字镜像后端过滤文法(`unknown` 作过滤即 assert——它是入站兜底,发回去只会 422;**静默丢弃过滤会放宽查询、答一个与调用方所问不同的问题**)。
  - **口径同源=物理的,不是文档上的**:窗口锚点由 `SchedulerWindows.kpiWindow`(**Duration,不再是线缆词 `'24h'`**)在**前端算一次**,同一个绝对时刻(RFC3339)发给两个端点——`?since=`(其 `totals.missed` **就是**牌)与 `?createdAfter=`(✕ 所来自的那页)。**为何非如此不可**:相对词 `'24h'` 会让后端按**它的** now 解锚、前端只能为列表再猜第二个;两口钟、两份谓词,在窗口边缘静默打架=「牌上写 3、点开列表显示 4」——本海洋立法明禁的那一种 bug。后端 `?since` 本就收 RFC3339 绝对起点(api.md 契约),故零后端改。**突变体已验杀**:把列表的锚改成第二次 `DateTime.now()` 读 → 测试当场红。
  - **✕ 完整性的两条守卫**:①`trackPastWindow ≡ kpiWindow`(**构造上**相等;把它缩到 6h → 3 测红)②**孤儿 missed 自造泳道**——刻度到期之后 workflow 不再监听那个 trigger、或 trigger 被删,泳道就没了,但**牌仍数着它**;丢掉它=牌与它自己点开的 ✕ 对不上。**这不破判决①**:那条法守的是**未来**半(从点反推会让暂停的泳道静默消失);missed firing 不是预告、是 durable **事实**,而事实必须有地方可显示。**只有 missed 配得上**:孤儿 `shed`/`started` 是没人数的上下文,照旧丢弃(fixture 种了一条 shed 孤儿专门锁死这两条路径不同)。
  - **两条查询、刻意不合一**:通用页(全 status)喂实心过去点、missed 页**单取**喂 ✕。理由:行按新→旧翻页且帽 200,一个话痨 cron 的 200 行足以把每一个 ✕ 挤出「最新一页」,而牌照数不误——**牌的证据自己一条查询,其完整性不取决于别的 trigger 有多忙**。通用页只贡献**非** missed 行,故两页绝不把同一刻度标记两次。
  - **诚实边界**:撞帽 → `pastTruncated` + `pastFrom` 点名可信数据从哪开始(**「隐形空洞」正是 S5 宁可不发过去半的理由**——一条看起来完整却藏着洞的轨,比一条老实承认自己从 now 开始的轨更糟;现在能**检测**并**明说**它,故可以发了)。firing 读**失败**绝不吞成 0 → 整块看板走诚实错误态(「你什么都没错过」与「我查不出来」是两句话,只有一句可以渲成让人放心的空牌)。
  - **词表**:新 `scheduler.status.{firingFired,firingQueued,firingNotRun}` + `overview.{scheduleHead,scheduleEmpty,kpiMissed,kpiMissedA11y,trackFiredA11y,trackMissedA11y,trackPastTruncated}`;`upcomingHead`/`upcomingEmpty` **物理删除**(区不再只讲未来)。**a11y**:过去点的词取自 `TrackEvent.status`——**点所画的正是这个值**,故词与色**构造上**一致;刻意**不**从 Firing 行查(24h 过去轴按 ~1.8h 分桶,15 分钟的 cron 折 ~7 次火成一点、折叠报**最坏**状态,从任一行取词都会描述一次与颜色所说不同的火)。预告句说「预计」,**绝不**给过去点复用(把已发生的火念成「预计」是最直白的谎)。
  - **fixture**:`_firingSeeds()` 八行=**处置调色板全齐**(started/skipped/superseded/shed/missed,兑现 §15「各一」+「missed 预留」)+ `_firingsMatching()` **单点谓词**(listFirings 与 `totals.missed` 共用,镜像后端 `firingQuery`)+ `_sinceInstant()` 照 `parseSince` 收绝对/`<n>d`/duration 三形(只认字面 `'24h'` 的旧 switch 会让每次 KPI 读都拿到 7d 的数)。**故事是一台机器的一夜**:6h 的 cron 睡过 −19h/−13h 两刻→missed,醒着的 −7h/−1h 跑了且失败→正是失败聚合已在讲的那条 ×4 连败(相隔 6h=它的节拍本身)。**验收测写成普遍律**(0717 那批的教训):「trigger 的 lastFiredAt 不可能早于它自己产出的 firing」——**该律当场抓出我自己的种子 bug**(活 run 的 firing 盖在了 run 的 `startedAt` 而非 fire 时刻,让 `tr_cron_clean` 自称「上次触发」早于它产出的 firing)。
  - **电池 +21**(纯派生 6[挂泳道/轴外丢弃/**孤儿 missed 自造泳道**/孤儿 shed 丢弃/暂停泳道仍带旧火/窗口构造相等] + 牌 6[0 不出牌/出牌带后端数/**点击洗亮它的证据**/**SAME PREDICATE 逐字节同锚**/✕ 落轨/撞帽明说/读失败不成 0] + fixture 7[调色板/**牌数==列表长**/missed 三律/lastFired 普遍律/started 互指/半开窗+AND/帽自报/一夜一史] + s0 补锁 `missed→idle`[别名表一直带着它、却从没测钉过,而它是判决⑥ 最吃重的裁决])。**三个突变体全杀**(第二口钟/孤儿丢弃/窗口缩短)。fe-verify **4156 绿** + `make docs` 净。
  - **有据偏差(两条)**:①**「点开那个列表」= 滚动到并洗亮调度轨,而非一个新的行列表页**——牌数的刻度**就活在轨上**(每个 ✕ 都在它到期的那一刻、它的泳道上),§3 草图与「点击深链 firing missed 过滤」指的正是这个面;另起一个行列表会把同一份信息在 Overview 最贵的地皮上讲第二遍,且与「聚合先于明细」相左。**记为裁量,待用户复核**:若要的是真·行列表(每行 workflow+trigger+刻度),那是另一刀。②**另四张 KPI 牌仍不可点**——S2a 偏差① 指望 S3 大表来还,S3 落了却没接线;本批**刻意不顺手补**:missed 有真去处(轨),另四张的去处(预过滤大表/inbox)是各自独立的一刀,而链到「差不多」的地方比不链更糟。**记账待裁**。③**`started` 的火渲绿,而它生的 run 可能失败**——真机帧实证(库存同步:−7h/−1h 两点 `rgb(83,162,88)` 绿,其正下方「FAILURES · 7D」写着 `failing ×4`,**说的是同两次**)。**这是照 §7 状态学落的**(firing 六桶把 `started` 放在**成功**桶),且本区问的是**排程**面的问题——「刻度成没成 run」,`started`=成了,run 自己的结局是失败聚合与大表的职责,轨上没有第二根轴放它。**替代方案的代价**:要让点着**run 的**结局色,得逐 firing 拉它的 run(N+1),或后端在 firing 行上 join run status(契约污染)。**记为裁量、交用户一眼**:若判「绿=声称了它没有的成功」,改法是 `started` 落中性(它只是**交接**成功),那是一刀独立的裁决。
- **真机验收修复批 ✅ 已落(2026-07-17)**:S5 收官后主会话**亲自在真机上走查** Scheduler 海洋,抓到四条;逐条根因已独立复核后修。本批的方法学教训:**测试全绿 ≠ 没 bug**——缺陷② 的旧代码全绿了一整场战役,因为没有任何进程内测试能观察到 `main()` 造出的是哪口 binding;而缺陷①③④ 全是「数据/状态在**时间**里演化」或「**跨面**互锁」类,单面快照测天然照不到。
  - **① 「Next fire」KPI 退化成骗人的「—」(product-side 真 bug)**。**现象**:demo 开着看,牌走 `in 2m → in 1m → in <1m → —`,然后**永远**停在「—」。**根因**:三处过滤把「过去的 fire」滤掉(`earliestNextFire` / `schedulerRailMeta` / `_KpiStrip` 各一处)——**过滤本身没错**(「in -5m」是胡话),错在对「我缓存的未来变成了过去」的**反应**:它选择了「假装没有调度」,而正确反应是「**我的数据过期了,去重取**」。**为何是真 bug 而非 fixture 假象**:rail 只在 durable 帧(run_started/run_terminal)上 refetch;合上笔记本、第二天早上打开 → 所有缓存 nextFireAt 都成过去 → 每个 workflow 的「下次调度」全渲「—」、rail 的 ⏱ meta 全部消失回落成「上次 run 2h 前」,而它们明明每天 09:00 都要跑;要等某个 run 真起来才恢复,**而若那次 fire 因机器睡着被记成 `missed`(判决⑥ 立法的正是这个场景,根本不产生 run)就永远停在骗人的「—」上**。**修法**:`AnTimePulse`(本就每 30s 在跑的**唯一**心跳)兼任**陈旧探测器**——任一缓存 nextFireAt 已成过去 ⇒ **快照过期** ⇒ 重取(零新机制、不铸第二口钟)。**三条边界**:①**死循环风险已证伪**——后端 `NextFireAt` 是 **`db:"-"` 读时投影**(`app/trigger/lifecycle.go:180` 的 `croninfra.NextAfter(expr, time.Now())` = `sched.Next(now)`,严格晚于 now),故监听中的 cron **按构造**必给未来值,「重取后仍是过去」结构上不成立;sidecar 与客户端同机同钟,时钟偏移亦无。纵深防御仍加 **`staleFireFingerprint` 单问语义**:同一个答案至多问一次(线缆咬定一个过去时刻也转不起来,**突变体验证:去掉闩 → 12 次取数**)。②**重取期间不闪**:`refresh()` 保留旧值(既有行为),失败亦保留旧真相;但**闩只闩真收到的答案**——重取没落地即释放,否则一次网络抖动会把「—」钉死到下一个 durable 帧(**突变体验证:不释放 → 卡在 2 次**)。③**rail 与 Overview 同源**:两张脸读同一份 `nextFireByWorkflow`(Overview watch rail.future),一处自愈两处同愈,不可能打架。**电池 +11**(纯函数 6[全未来/空集≠陈旧/恰在 now 已耗尽/序无关/答案变了=新问题/混合只取陈旧] + 控制器 4[陈旧→重取且前提断言「这份快照确实渲「—」」/新鲜绝不重取(脉搏是探测器不是轮询器)/单问反自旋/抖动后释放闩再问])。
  - **② demo 的 ⌘± 是死的,而注释宣称它活着**。**根因**:`main.dart:35` 造 `ScaledWidgetsFlutterBinding.ensureInitialized(scaleFactor: WindowZoom.scaleFactorCallback)`,而 `demo_main.dart` 只造**裸** `WidgetsFlutterBinding.ensureInitialized()` → `window_zoom.dart:89` 的 `if (binding is ScaledWidgetsFlutterBinding)` **恒假** → `_apply()` 设了 `factor.value` 却不 `handleMetricsChanged()` → **静默无效**(真机实测:⌘B 生效、⌘− 无任何反应);demo 另缺 `WindowZoom.useSettingsPrefs(prefs)` 与 `WindowZoom.restore()`。而 `demo_main.dart` 的注释白纸黑字写着「⌘± … Handlers are pure provider/static calls — no backend needed. 镜像 app 快捷键」并挂 **D-035** 的账——**注释与证据相反**(与 an_toast「announce 是 desktop-broken」同型)。**这破了启动面铁律**:「app 与 demo 共用唯一壳,**只差两点**:①数据源 ②启动门控」——zoom 既非数据源亦非门控。**修法**=**接真**(而非改注释认输):demo 补 scaled binding + `useSettingsPrefs` + `restore`,与 app 逐字同款;注释同步说清「本层只负责把和弦送到,让树重排的是上面那口 scaled binding」。**新 guard `test/guards/demo_parity_guard_test.dart`**:①期望值**派生自 `main.dart`**(扫**去注释后的代码**取 `ScaledWidgetsFlutterBinding.ensureInitialized`/`WindowZoom.*` 全集,逐个要求 demo 也有)——真入口将来新增 zoom bootstrap 调用,本 guard 自动同时要求 demo,无需任何人记得改它;②反向钉死 bug 指纹:demo 不得出现**裸** `WidgetsFlutterBinding.ensureInitialized`(lookbehind 放行 Scaled 子类,其名含之)。**为何扫源码而非 widget 测**:此分叉活在 `main()` 里、在任何 widget 之前——是 **binding 对象本身**,而测试 binding 由 flutter_test 造,**进程内无任何测试能观察到 demo_main#main() 会造出哪口 binding**,唯一可观测量就是源码(另一个是真机——本条正是这样被抓到的)。**去注释是承重的**:`main.dart:25` 的文档注释点名 `[WindowZoom.factor]`,那是**散文不是调用**,不去注释会让期望集混入假项(本 guard 的由来正是一句撒谎的注释,它绝不再拿注释当证据)。**双向验证**:对修复版全绿、对旧版两测皆红。
  - **③ run 旗舰无图时整段静默消失**。**根因**:`scheduler_run.dart` 的 `if (d.graph != null)` 无 else → graph 为 null 时**整段不发射**,§5 承诺的「三海拔」在此只剩两拔,页面读起来像坏了(真机:`库存同步` 的 run 旗舰只有 卷宗头 + TIMELINE + NODES)。**graph 为 null 的真实成因**(已核 `scheduler_run_provider._fetch`):钉版解不出(旧 run 无 `versionId` / 版本行随宿主软删一起没了 §5.7)**且**宿主也无 active 图可回退。**修法**:补 else 分支,同一个区头(`graphHead`)下渲**诚实话** `scheduler.run.graphEmpty` 双语新键——与甘特(`ganttEmpty`)/台账(`ledgerEmpty`)各留一句空句**同等待遇**;「在哪儿发生的」由「没回答」变成回答「我们无从得知」。**注意**:`graphNotPinned` 免责横幅在此**不渲**——根本没有图可免责,渲它才是谎。**与 fixture 注释的关系(勘正)**:`scheduler_demo_fixture` 的「the honest «no graph» sentence」注释**没有撒谎**——它说的是 **linked pane** 的脸(`scheduler_home.dart:924` 的 `t.noGraph`「活跃版本没有图」,真实存在);缺口在**旗舰**,故新键用旗舰自己的语言(钉版口径),不复用 pane 的「活跃版本」口径。**电池 +1**(stub 加 `noGraph` 种:钉版读不出**且**宿主无图 → 诚实话在场 / 不画图 / 不渲错图横幅 / 另两拔照常——缺的是**地图**不是**页面**)。**无冲突**:全宽撤销者已先落地(`AnZonedPage`+`fullBleed` → `AnPage`+`Column`),本改只碰 `graph == null` 分支,与全宽/横滑正交。
  - **④ demo fixture 自洽性破了**。**现象**:`库存同步` 的 run 行显示 `cron · 01:11`/`cron · 19:11`,同页 TRIGGERS 区却说「**No triggers equip this workflow.**」——一个没有任何 cron trigger 的 workflow,却有 cron 触发的 run(破 D 轨「自洽互锁世界」立法)。**修法**(取「给 wf_inventory 种 cron」而非「改 origin 成 manual」:连败叙事本就该有个 cron 在定时捅它):补 `tr_cron_inventory`(`0 */6 * * *`「每 6 小时」,**6h 节拍即连败叙事本身**——两条失败种子恰好相隔 6h)+ 边 `rel_5` + 两条 run 补 `triggerId` + `triggerSchedule` 补 4 刻(窗内,泳道上板)。`nextFire` 置 `+5h` 故**不夺** KPI 最早位(仍是 `tr_cron_clean` 的 `+3m`)。**关键**:验收测**写成对全部种子的普遍律**而非对被抓那一行的点检——「每条 cron 来源的 run 都必须有一个**真存在、kind=cron、且装备在该 workflow 上**的 trigger 在它背后」;该律**当场又抓出两条同类**(`wf_archive` 的 `fr_d4e5f60718293a4b`/`fr_e5f60718293a4b5c`:origin=cron 却无 triggerId,真机走查没走到),一并补 `triggerId: 'tr_cron_archive'`;顺带修 `tr_cron_archive.lastFired`(-4d → -26h = 它发出的最新那条 run):**trigger 的「上次触发」不可能早于它自己发出的 run**,否则旗舰 ProvenanceLine 的 cron → firing → run 链自相矛盾。**电池 +1**(该普遍律,含「确实有 cron run 可查」的反空过前提断言)。
  - **验收**:`make fe-verify` **4135 绿** + `UPDATE_COVERAGE=1` 台账对账净 + `make docs` 净。**突变体验杀**(证测试有牙,非验收剧场):反自旋闩去掉 → 取数 2 次变 **12** 次(自旋真实存在)、闩释放去掉 → 抖动后**卡死在 2 次**(「—」被钉死)、demo parity guard 对旧版**两测皆红**/对修复版全绿(双向)。
  - **⚠️ 缺陷①② 的真机自验:未完成(环境阻塞,非「已验」也非「验失败」)**。经过与结论必须**如实记档**,因为中途出现过一个**极具误导性**的假象:
    - **假象**:新构建后 `open …/anselm.app` → 真机按 ⌘−(`key code 27`)**无任何反应**,而对照组 ⌘B **生效**——与修复前的症状**一模一样**,看起来像「修了但没用」。
    - **真相**:`ps aux` 揭穿——在跑的是 **pid 34354、启动于 01:53AM、已烧 25 分钟 CPU** 的**陈旧实例**(主会话自己那趟真机走查留下的);macOS 的 `open` 对**已在跑**的同一 bundle **只做前置激活、不会重启**,故**我新构建的二进制从未运行过**。⌘B 活而 ⌘− 死,正是**旧二进制**的签名(旧版有 ⌘B、无 scaled binding)。**教训**:真机验收必须先确认「在跑的确实是刚构建的那个进程」——否则会拿旧二进制的行为去给新代码定罪(或脱罪)。
    - **未能收尾的原因**:环境的 Bash 安全分类器在本次会话后段**持续不可用**,`pkill`/`killall`/`osascript quit`/⌘Q keystroke/`open -n`(新实例)**全部被拒**(只有 `pgrep`/`ps`/`grep` 等只读命令放行,约 20 次跨时段重试均未恢复),故**无法终止陈旧实例、也无法起新实例**。→ **①② 的真机复验交还主会话**(先 `pkill -x anselm` 确认进程消失,再 `open`;验 ⌘− 真缩放、验 `Next fire` 跨 3 分钟仍诚实)。
    - **意外收获——陈旧实例本身就是缺陷① 的活体证据**:该实例把 `fr_cold00000000e1`(fixture 种在 **`now − 4s`**、读时 `_shift` 重定基)渲成 **「34m ago」**——即它的快照是 **34 分钟前**取的、此后**一次都没重取**。机制与缺陷① 完全同源:demo 无 SSE gateway → 无 durable 帧 → rail 唯一的 refetch 触发器永不响 → 快照无限变老。它渲「34m ago」的同一时刻,「下次调度」牌必然早已退化成「—」并永久停在那里。**这正是本修复要根治的东西,在真机上自己演了一遍。**

## 15. demo fixture 策略

`features/scheduler/data/scheduler_demo_fixture.dart` 数据级电池(D 轨战术:fixture 纯数据非渲染,`demo_fixture_test.dart` 锁种子正确性),AppShell 一次接线 app+demo 同得。种子必含全态:在跑(多节点推进中)/等人(带 deadline 将超时)/连败 ×4/已自愈/skipped·superseded·shed·started 各一(firing 账,S6)/cancelled/replay ×N/未来 24h 调度扎堆/**missed ×2**(S6:一台机器的一夜——6h 的 cron 睡过两刻,与 ×4 连败是同一段历史的两个视图)/孤儿墓碑 run/从未运行/停用/650KB 大 I/O 注入/20+ run 翻页。demo 脚本驱动一条活 run 走完(tick→terminal→洗亮)供活性军规逐帧验收。

## 16. 判决记录(2026-07-16 用户终拍板:六项全按最全方案)

- **Q1 暂停调度 ✅ 判决**:运行时权力——本海洋 triggers 陈列就地 [⏸/▶] 开关(工单⑦);cron 表达式编辑仍归 entities;暂停态全链路可见(rail meta「⏸ 已暂停」/Overview 泳道灰显/nextFireAt 置空)。
- **Q2 批量操作 ✅ 判决**:首发即做——批量批准/拒绝(Overview)、批量 replay(大表失败态)、批量 cancel;形态=`AnBatchBar`+hover checkbox;语义=前端逐发+显式挂账(逐行 pending→落定),first-wins 输家 422 汇总 toast;批量端点(工单⑪)预留不建。
- **Q8 主页打磨七条(2026-07-17 晚 用户拍板,不可推翻)**:①**列头重构**——上=选中指示条(仅选中可见,透明占位防跳变)/下=耗时比例条穿**最终状态淡色**(绿成/红败/灰取消,与格子同族;「历史跑完的不用蓝,蓝=在跑专属」),常驻灰基线删(用户报「两个灰条看不懂」);②**头部整合**——NODE × RUN 段标题删、胶囊上移统计句行,**成功率/均时跟随选择器**(后端 stats 加 `until` 终点[commit 089060f2:RFC3339-only/半开/封五窗口量/`FLOWRUN_STATS_INVALID_UNTIL`],前端 `statsWindowOf` 映射+`schedulerRangeStatsProvider` 逐范围 1-id 批查,「全部」=epoch 绝对界);③④**双页文档化**——照 entities 文法:`AnOceanHeader`(页内面包屑+大标题+meta+右上动作)+全段 `AnSectionVariant.plain` 文档级大标题;run 页大标题=**来源短语**(「Cron · 19:14」),动词(重放/取消/诊断)上移页头右上;⑤**id 人话化**——全 scheduler 面无裸 id:行内 fr_/cv_ 药丸删、trigger 出处药丸念**真名**(`ProvenanceLine.triggerName` 缝)、钉版念 **v3**(`pinnedVersionNumber`)、矩阵列 tooltip/读屏念来源短语(id 降 tooltip 末行);⑥**run 页 ✕ + Esc**——壳 `headTrailing` 槽(与 chat 图标簇同位)`_CloseRunButton` 回运营主页,页内 Esc 阶梯(有节点选区先清选区、无选区即 ✕);⑦**行重排**——左=来源词+时刻+常驻动词,右缘只留执行时长(ago 删),红点与主文首行同心(AnLedgerRow 原语修)。孤儿 run 的 FLOW 提示语用户拍板保持现状。
- **Q8 复审(0717-深夜,13-agent 对抗:9 候选→6 confirmed 全修)**:①**范围章**——统计句曾在换胶囊的 reload 期间「新窗口词配旧范围数字」(Riverpod copyWithPrevious 保留旧值):`schedulerRangeStatsProvider` 改返 `(range, stats)` 章对,widget 章符才渲数、切换期诚实「—」(widget 测锁在飞双断言);②**矩阵状态词漏英文**——列/格 tooltip+读屏曾走 `runStatusWord`(执行域 ok/timeout 封闭集),flowrun/节点域的 completed/running/parked 原样漏线缆词:core 新 `flowrunStatusWord`(running=运行中/completed=完成/failed=失败/parked=等待/cancelled=已取消,全复用 `run.*` 既有键)四站点换用;③**statsWindowOf 零覆盖**——全 app 唯一非空 `until` 发射点(后端 089060f2 的整个前端理由)无测:单测全 6 分支+widget 测绝对区间上线缆 `until`=闭分钟端+1min;④**Esc 阶梯无测**:两档各一 widget 测(有选区清选区留旗舰/无选区落运营主页,stub 落点路由);⑤死键 `runIdLabel` 删(与「死键清」自相矛盾的同提交新增);⑥error-codes.md 三数重算(307+7+4=318,复核方法行同步——修前 317/306/304 三方漂移)。scheduler 套件 250→258 绿。
- **Q8 复审后追查(0717-深夜,用户点名「运行中 failed」帧)**:右岛卷宗脸 KV 首行曾渲「运行中 → failed」——**双病一行**:标签错用 AnStatus 脸词 `status.run`(「运行中」,不是「状态」栏目词)+值直渲 `run.status` 裸线缆词。修法:新键 `scheduler.run.kvStatus`(状态/Status)做标签、值走 `flowrunStatusWord`;节点脸执行日志行同病同修(`status.done` 错当标签,值本就走执行域词表不动);顺修卷宗脸钉版行念 `v7` 人话版本号(需求⑤ 补漏,解不出才落裸 id)。测试:cancelled 种子锁四断言(EN 下 failed 词=线缆词不可证,cancelled 大小写可分辨);真机帧重截核验「状态 → 失败」。
- **Q9 头部去双显 + 选择器手感三条(2026-07-17 深夜 用户拍板)**:①**「近 7 天」双显删**——用户裁「胶囊放前面,成功率放后面,去掉句子的近七天」:meta 行序=[生命周期徽]→[AnTimeRangePicker 胶囊]→[成功率·均时句],`statsLine` 撤 `$window` 参数、`_rangeWord` 随之退役(窗口由紧邻胶囊唯一陈述);②**星期头折行修**——EN 三字母在 24px 格折成「Mo\nn」(真机帧),en weekdays 改双字母 `Mo Tu…` + AnCalendar 原语级 `maxLines 1/softWrap false`(锁死任何 locale 不可折);③**时刻改滚轮**——用户「具体时间不要自己写,改成滚轮滑时间」:新 core 原语 **AnTimeWheel**(循环 HH:MM 双列轮/滚轮一格一步 Listener 显式驱动/拖拽/↑↓/焦点环/读屏可调节/落座压回声),picker 端点时刻场退打字、`parseTimeInput` 死码删;顺修日期框 104→116 截字(帧核出 2026-07-17 裁成 9 字)。gallery 滚轮标本 + wheel 5 测 + picker 11 测;capture_demo 新 `SCHEDPICK=1` 开面板帧;真机两帧核验(头部单陈述/面板全显)。
- **Q7 主页重建(2026-07-17 用户拍板,不可推翻)——矩阵升页顶 + 统一时间范围 + 行内速览**:用户逐条定调:①「Matrix 是作用于所有 run 的,甘特图和图是作用于单次 run 的」→ **矩阵移出联动格、常驻页顶**(健康头下),跨 run 透镜归跨 run 的位置;②「点击的话直接跳转到对应的子页面,不要跳转到下面」→ **矩阵点列/点格=导航进 run 旗舰**(格带 `?node=` 预选),格阵是发射台、不再向下选中;③「下面列表点击是展开小卡」→ **行内速览卡**:单击行开合 `?run=`(URL 真相、一次一行、双击直进旗舰),底部联动格删除;④「这俩选择器融合到一起…可以选日期+时间,起点终点,还有快速日期选项」→ **页级 `AnTimeRangePicker`**(Grafana 族:快捷预设+绝对日期时间双端)一颗胶囊同治矩阵+大表,大表 24h/7d/30d 下拉删除;⑤「不要最近 20 次了,就根据默认的走吧。默认划到最右端,也就是最新的那些点点」→ 预设默认**近 7 天**、矩阵**时序左旧右新、开屏锚最新端**、向左滑懒加载更旧页;⑥问题2 同意 → **健康头珠串删除**(矩阵列头即同一条新闻)。**连带契约**:flowrun-matrix 改 `?flowrunIds` 纯批查(recentN/workflowId 按 #7 删,后端半 commit f788d315);新原语 AnTimeRangePicker/AnCalendar;AnRunMatrix 重铸(reverse 锚+冻结车道+懒加载缝);AnLedgerRow 长 `expandBuilder` 惰性披露。
- **Q3 矩阵与全宽 — 判决③ 半存半废**:①**矩阵第三脸 ✅ 保留**(S5,工单⑩,已落);②**全宽破例 ❌ 作废**——0716 拍板「联动格与旗舰甘特/图/矩阵区全宽破例、登记 design-system 豁免」,S3/S4/S5 已按此落地,**用户 0717 真机看到即当面否决**:「你现在搞了这个超宽的东西。**我不允许有这种超宽的东西**。请都改回到标准的。如果甘特图真的信息不够展示,**可以弄那种可以左右滑动的**」。**新判决(不可推翻)**:全部区段回归 720 阅读列;宽度不够者在 720 内自己横滑。**已执行**:`AnZonedPage`/`AnPageZone` 物理删除、两页回 `AnPage(child: Column)`、矩阵长出自带横滚(条即可发现性 + 方向键 `ensureVisible`)、甘特与图**本就不需要**任何改动(分数轨 / InteractiveViewer)。法登记在 design-system §5 `AnPage` 条目「720 阅读列绝对律」。**教训**:0716 那句「720 截断伤可读性」是**推定而非实测**——真去量:甘特 720 下轨仍 480–512px(分数轨本就无损缩放)、图是可平移视口(与页宽无关)、**只有矩阵真的宽,且仅溢出 52px**。三个「需要全宽」的理由里有两个半是假的,而全宽的代价(整页视觉破相)用户一眼就看见了。**先量再立法**。
- **Q4 run 历史保留 ✅ 判决**:实装——Settings 存储面板配置(默认 90d)+后端定期清理(工单⑬,D1 归档线例外立法)+大表保留墓碑行。
- **Q5 排队段 ✅ 判决**:排期引擎手术(工单⑫,S4 前完成)——`flowrun_nodes` 补排队时间戳,甘特三段条(排队灰+执行+parked),台账/卷宗头耗时拆「排队·执行」;replay 旧戳语义随工单立法。
- **Q6 misfire ✅ 判决 → ✅ 全落**(后端工单⑨ `57556263` + ⑭ `1e62a6b3`;前端 S6):默认跳过+missed 记账;catchup-one 作为 trigger 级配置项(默认 skip)归 entities 编辑面。**呈现**:时间线灰 ✕ ✅ + Overview 第五牌(有 missed 才出现,点击洗亮它数的那些 ✕)✅;**firing 串第三态待 S7**(§4-4 trigger 卡的「N 次 skipped ▸」两级钻取——`GET /firings?triggerId=` 的能力已在,只欠消费)。**口径同源是物理的**:窗口锚点前端算一次,同一个绝对时刻同时发给 `?since=` 与 `?createdAfter=`,故「牌上写 3、点开列表显示 4」**不可达**而非**不太可能**。
