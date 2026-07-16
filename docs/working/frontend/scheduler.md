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
> **2026-07-16 用户终拍板:原 6 项 open questions 全部按「最全最完整最彻底」方案判决**(§16 记档):①暂停/恢复调度=运行时权力就地开关 ②批量操作(批量批准/拒绝/replay/cancel)首发即做 ③矩阵第三脸做+联动格/甘特**全宽破例** ④run 历史保留策略实装(Settings 存储面板配置+后端清理) ⑤排队段**引擎手术排期**(节点时间戳→甘特三段条) ⑥misfire=跳过+missed 记账,catchup 作为 trigger 配置项归 entities。

---

## 0. 两条宪法(本海洋防乱的机理级立法)

1. **脊柱=「问题→现场→证据」三级钻取**(B):Overview 答「要不要管」→ workflow 主页答「哪次坏了/多慢」→ run 详情答「为什么」。每页只回答一个问题,页内披露 ≤1 层(NN/g 硬限),证据永远在点击之后;「全面」= 每一跳都有完整出口,不靠一屏轰炸。
2. **活性军规**(C,三判官全票必收,可继承进 design-system):**tick 只改瞬时外观(色/呼吸/时长/进度),永不改几何(行序/视口/选区);几何变更只随用户动作或 durable 落账发生。** 推论:新 run 不插行走「N 条新运行」pill 归位;落定原地变色+洗亮;live 绝不夺视口;失败(一次)与人闸是唯二例外上浮(WRK-065 同律)。

另三条军规:**聚合先于明细**(Overview 绝不混排流水账);**成功是背景音**(饱和色只给异常,灰调海洋里唯一饱和像素是红/琥珀);**禁虚荣数字**(每个 KPI 过「决策测试」且必是预过滤深链,「总运行次数」禁入)。

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

1. **KPI 牌**(AnCard+AnCountUp,全部预过滤深链):在跑 N / 等你 N / 24h 失败 N(**delta 箭头** ▲2,A 收编)/ **错过 N**(判决⑥:有 missed 才出现的第五牌,点击深链 firing missed 过滤)/ 下次调度 in 3m。
2. **等你处理**(最贵地皮):`/flowrun-inbox` 全集(工单④enrich 带 workflow 名+deadline),每行=workflow 名+节点+等待时长+**AnCountdown 超时倒计时**(新原语,单顶层 Timer 共驱)+`ApprovalGate` 就地批/拒(带 reason);决策后行滑出;first-wins 输家 422→诚实 toast+refetch。**批量操作(判决②)**:行首 hover checkbox,选中≥2 浮出 `AnBatchBar` 批量条(「已选 3 · [批量批准][批量拒绝▾(共用理由)]」);批量=前端逐发 decide+**显式挂账**(每行 pending→逐行落定滑出),first-wins 批量语义=输家 422 汇总 toast「已批准 2 · 1 条已被别处处理」。
3. **正在跑**:AnLedgerRow 活行=状态点+workflow 名+mono fr_ id+来源徽+节点进度 x/y+活耗时+hover ⏹ 取消。tick 只驱动本区外观;`run_started`(工单①)durable 加行。**多选批量取消**(判决②):AnBatchBar 同构,danger 弹窗带清单「将取消这 3 个 run」。
4. **未来 24h 调度**:首发简版(triggers `nextFireAt` 行列表,纯前端);S5 升级 `AnScheduleTrack` 时间轴(工单⑧)——过去实心点着状态色/未来空心虚点(措辞「预计」)/now 线偏左/**missed 第三态 ✕ 灰叉**(工单⑨,机器睡过头的调度点必须有脸,桌面 app 第一现实)。**已暂停 trigger 的泳道灰显不消失**(判决①:止血状态可见,标「已暂停」)。仅 cron 有未来点,其余 kind 如实缺席。
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

单页 AnPage 文档流(不做平行 tab),四段:

1. **健康头**:名+生命周期徽+`RunBeadStrip` 近 10 珠串+成功率+均时(工单③,窗口=7d,见 §8 窗口立法)+[Run now]+⋯菜单(:kill / 去 entities 编辑)。健康统计到此为止,不开洞察页。
2. **run 大表**:AnLedgerRow 列表+keyset 分页哨兵(不立表格新件;海量有官方 TableView 退路)。**行身份=来源短语**(GHA「cron run 全长一样」之鉴):主文本=来源徽+触发摘要(cron·08:00 / 对话名走 [[id]] 真名缝 / 手动 / webhook path),mono fr_ id 降为 meta;列:状态点+vN 版本+节点进度+**耗时(排队 · 执行 双数,判决⑤,工单⑫落地前只显执行段)**+相对时间右缘铁线+↻N 徽+失败行错误首句(sub,danger);hover 行尾 ⏹/↻。**过滤=状态计数条**(C 收编:全部|在跑 n|失败 n|等人 n,真数可点即过滤;「等人」走 inbox 派生,**绝不 `?status=parked`**——封闭集无此值,422)+来源下拉+时间窗(工单⑥)。新 run 不插行,表顶「N 条新运行」pill(AnFollowPill 扩 label)归位。**批量 replay(判决②)**:过滤到失败态后行首 checkbox 多选(或「全选失败」),AnBatchBar 给 [↻ 批量重放],确认弹窗合并真数字(「共重跑 7 个失败节点,复用 15 个已完成结果」);批量 cancel 同构(danger 带清单)。
3. **本次运行联动区**(地图+放大镜,永不跳页):选中 run → 下格 **[甘特 ⇄ 图 ⇄ 矩阵] 三脸 toggle**(判决③:矩阵首发即随建造计划做,不再 P2 悬置),同一选区三投影,默认甘特(「甘特是单 run 的透镜非一等页面」——A 论证成文);格角「打开 →」进旗舰页。**联动格全宽破例**(判决③):此格突破 720 阅读列、占满海洋宽度(全宽豁免登记 design-system §7;页面其余段仍 720)——矩阵近 20 列在全宽下基本免横滚。矩阵=`AnRunMatrix` 节点×近 20 run 格阵+列顶时长微条+三粒度选区(点格=该 run 该节点/点列=该 run/点行=节点历史),依赖工单⑩,随 S5 落地。
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
3. **完整甘特**(AnNodeGantt 扩 props 非新件,**全宽破例同判决③**):时间刻度眉+hover 起止/毫秒+now 线;**running 条几何诚实延伸到 now**(C);**条分段三段(判决⑤定案):排队灰段(ready→started,工单⑫引擎手术供数)+执行段(状态色,工单⑤真时长)+parked 琥珀段(frn created→completed 真区间)**;⑫ 落地前按两段渲、⑤ 也未落时整体回退等宽顺序槽——分段能力跟着数据可得性走,不撒谎。台账行与卷宗头耗时同步拆「排队 x · 执行 y」。control 瞬时点。
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

Overview/主页不占右岛(看板与联动格自足,不为放而放);详情页右岛按需揭示,inspector 三元链加一支,零壳改:

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

**后端枚举逐字对齐**:flowrun 头 CHECK 4 值 `running→completed/failed/cancelled`(first-wins,唯一回转 failed→running=:replay;「等人」不是 run 状态);flowrun_nodes CHECK 3 值 `completed/failed/parked`(**无 running 行**,呈现五态=行三态+合成 running+未及);firing 6 值 `pending→claimed→started` + 旁路 `skipped/superseded/shed`;workflow 生命周期 `active/draining/inactive` + 独立维度 `needsAttention`;approval=parked 行 first-wins,control 内联无 pending。

**呈现 6 桶(上限)**:在跑(running/合成/claimed)· 等人(running∧parked,inbox 派生桶)· 排队(pending/serial 推迟)· 成功(completed/started/fired)· 失败(failed/timeout)· **未执行**(cancelled/skipped/superseded/shed——中性处置非错误,染红=假警报;missed 落此桶带处置词,依工单⑨)。等人 vs 排队必须分(行动请求 vs 系统承诺),同琥珀靠词分裂。

**AnStatus/AnTone 映射**:既有 alias 全覆盖主干(running→run 蓝/completed→done 绿/failed·timeout→err 红/cancelled·inactive→idle 灰/parked·pending·draining·claimed→wait 琥珀/started·fired·active→done);**仅新增 3 alias:skipped/superseded/shed→idle**。绝不出现平行色表(批7c 教训);色永不独行,点旁必有状态词+形状通道(实心/半环/空心/✗,WCAG 1.4.1)。

**rail 点优先级**:蓝>琥珀>红>无(§2);灰生命周期另一维。

**i18n `scheduler.status.*`**(slang,零硬编码):running 在跑/waiting 等你处理/queued 排队中/completed 成功/failed 失败/cancelled 已取消/skipped 已跳过/superseded 已顶替/shed 已作废/missed 已错过/parkedNode 等审批/inferredRunning 推测执行中/draining 收尾中/active·inactive 生效·停用/firingPending·firingStarted 待跑·已开跑/nextFire·lastRun 下次·上次 {time}/replayed 已重放 ×{n}。

## 8. 统计窗口立法(盲区补,单源常量档)

四处窗口各说各话本身即「乱」——全部窗口进单源常量档 `SchedulerWindows`(core),i18n 句显式含窗口词:**珠串=近 10**;**矩阵=近 20**;**失败聚合=7d 滚动**(凌晨 26h 前的失败不能漏窗——24h 否决);**KPI 失败牌=24h**(带 delta);**成功率/均时=7d**(工单③ `since` 参数统一)。

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
/scheduler/w/:workflowId                  运营主页(?run= 联动区选中)
/scheduler/w/:workflowId/runs/:flowrunId  run 详情(?node= 节点选区深链)
```

全走 `_shellPage` 常量 key 壳永不重挂;`selectedSchedulerProvider` 只读单向派生自 URL;app_shell `ref.listen` 海洋拉动(深链自动切海洋);**panel_registry 登记 `flowrun`**(firing→宿主 run)→chat 卷宗/通知/entities 的 flowrun 引用全域自动点亮;headOwners 登记,面包屑 `shellHeadProvider.bind` 三段「Scheduler / 名 / fr_x」。选区(?node/?run)入 URL 可分享回现场;tab/过滤器不入 URL。孤儿 run 路径在宿主软删后仍解析(墓碑态,§5-7)。

## 12. 原语复用清单与新原语规格

**直接复用**:AnSidebarList/AnRailStates/AnStatus(+3 alias)/AnLedgerRow/AnLedgerList/AnStatBar/AnRunBoard/AnGraphCanvas+deriveRunState/AnNodeGantt+flowrunTimeline/ApprovalGate/AnPage/AnSection/AnCard/AnCountUp/AnHeatBar/AnJsonTree/AnFollowPill.jump/AnWashHighlight/AnTypeToConfirm/AnDialog/AnTooltip/AnKv/AnChip(来源徽预设)/ToolIOSection/TriggerConfigCard。

**上收批(S0 前置,chat→core/ui,~2–3 天)**:FlowrunNodeList/ProvenanceLine(+toolNavPill 皮)/RunBeadStrip/RunLedgerRow/NodeTick+FlowrunProgress/runStatusWord;flowrun-watch 对账缝上收 core(三消费一源);i18n 迁 `scheduler.*` 或中性空间(先例 chat.stage.*→feedback.cast.*)。

**扩 props 非新件**:AnNodeGantt(+刻度眉/nowLine/hover/segments 执行·parked/live 延伸)、SidebarRow(+meta 槽)、AnFollowPill(+label)。

**新原语(gallery-first,先 specimen 再组装)**:
- `AnCountdown({required DateTime deadline, AnTone tone})` — 相对倒计时文本,单顶层 Timer 共驱,极薄。
- `AnScheduleTrack({required List<TrackLane> lanes, required DateTime now, Duration window, void Function(TrackEvent)? onTap})` — 绝对时间轴 CustomPainter:刻度眉+now 线+泳道点(过去实心着状态色/未来空心虚「预计」/missed ✕ 灰叉),bucket 聚合防爆+hover 清单。**a11y**(盲区补,W7 四播报先例):每 lane 一 Semantics 节点,事件读「{workflow} {time} {status}」,←→ 键盘遍历;gallery 验收含读屏走查。
- `AnRunMatrix`(判决③确认,随 S5):`({rows: [nodeId], cols: [RunColumn(id, elapsedMs, status)], cellStatus, onCell/onCol/onRow, selection})` — 节点×run 格阵+列顶时长微条+三粒度选区,虚拟化列窗;**宿主联动格全宽**(判决③),近 20 列基本免横滚;同套 Semantics 要求。
- `AnBatchBar`(判决②新原语):`({required int count, required List<BatchAction> actions, VoidCallback onClear})` — 多选浮出的批量操作条(「已选 N · [动作…] ✕」),挂在列表区顶;配套 hover checkbox 行选择模式;批量执行时驱动逐行 pending→落定的显式挂账呈现。gallery-first。
- **全宽豁免**(判决③):运营主页联动格与 run 旗舰甘特/图/矩阵区突破 720 阅读列占满海洋宽度——建造时登记 design-system §7 豁免表(理由:时间轴/矩阵的信息密度天然横向,720 截断伤可读性;页面 prose 段保持 720)。

## 13. 后端工单清单(可直接开工;全套唯一 schema 变更=①两列)

- **① 来源 provenance + run_started 帧(P0,越晚旧行 null 越多)**:`flowruns` 加两可空列 `origin`(CHECK ∈ manual|chat|cron|webhook|fsnotify|sensor,写入定死)+ `conversation_id`;StartRun 签名带来源,chat `trigger_workflow` 传 conversationId,claimFiring 按 activation.kind 盖章;线缆 omitempty,旧行 null→前端 unknown 兜底。顺手:起 run 发 durable Signal `node.type="run_started"` content `{flowrunId, origin}`(scope=workflow;词表归 producer,不违 E1)。
- **② 单 run cancel(P0,引擎级并发设计——F174 同级报价,非薄端点)**:`POST /flowruns/{id}:cancel`,202 返 `{flowrun, nodes首页, nextCursor}`(对齐 :replay 形);仅 running 可取,否则 422 `FLOWRUN_NOT_CANCELLABLE`(登记 error-codes.md)。语义必须显式设计:守卫更新 `WHERE status='running'`→cancelled(first-wins,**先标头再 cancel ctx**)→cancel 该 run inflight ctx(取消传播进 LLM 流式)→**被打断在飞节点不落行、不误写 failed**(cancelled 不在节点行 CHECK 内,行只写终态语义不破)→`CancelParkedNodes` 收 parked(收件箱不留死项)→markRunTerminal 发 durable;与 record-once/replay 相容;取消 draining workflow 最后在途 run 触发 draining→inactive 结算(对齐 :kill)。
- **③ 运营统计批量(P0)**:`GET /flowrun-stats?workflowIds=<csv≤50>&recentN=10&since=`→`{totals:{running,completedSince,failedSince,parkedNodes}, byWorkflow:[{workflowId, running, lastRun, recent:[status…], successRate, avgElapsedMs, consecutiveFailures}]}`(**补 `consecutiveFailures`**——失败聚合「连败+自愈」语义的数据源);纯读投影,零新表零新列,有界批查 N4 豁免。
- **④ inbox enrich(P1)**:`GET /flowrun-inbox` 行补 `{workflowId, workflowName, deadline?}`(join run 头+workflow 名批读;deadline=parked.createdAt+approval 版本 timeout,复用 CheckTimeouts 解析);铃托盘顺手受益。
- **⑤ 按 run 聚合活动时长(P1,甘特+台账)**:`GET /flowruns/{id}/activity?cursor&limit`(N4)→`[{nodeId, iteration, kind, execId, status, startedAt, endedAt, elapsedMs}]`;UNION 四张执行日志表按 flowrun_id(偏索引已备)。**诚实报价**:此工单只给执行段;排队段由工单⑫引擎手术供数(判决⑤定案排期)。
- **⑥ 列表过滤器(P1)**:`GET /flowruns` 增 `?startedAfter&startedBefore&triggerId&origin=`(依赖①);非法值 422 大声拒带 allowed;零 schema 变更。
- **⑦ 暂停/恢复调度(P1,先调研)**:核实 trigger 域既有生命周期端点可否直用(listening/停用轴);缺则补 N5 `:pause`/`:resume`;语义=不再产生新 firing、在途 run 不受影响、nextFireAt 置空;归属已判决(§16-Q1):运行时权力就地开关。
- **⑧ 调度时间线(P2)**:`GET /trigger-schedule?within=168h&limit=200`→`[{at, triggerId, workflowIds}]`,cron `NextAfter` 迭代,顺解 trigger→workflow 反查断链;webhook 等无未来点不入线。
- **⑨ misfire 策略+missed 呈现(P2,判决⑥定案)**:**默认跳过+missed 记账**(本地 app 补跑风暴危险)——sidecar 睡醒后把错过的 firing 落 `missed` 处置态(不补跑);时间线/firing 串/Overview KPI 第五牌均呈现 missed;**catchup 作为 trigger 级配置项**(默认 skip,可选 catchup-one=醒来补跑最近一次)归 trigger 域,配置编辑在 entities trigger 面。先查 trigger 域现状定落地形。
- **⑩ 矩阵批量端点(随 S5 矩阵第三脸,判决③确认)**:节点×近 20 run 状态阵一次取(判官2 裁定:T1 聚合给不了,逐 run 拉详情=N+1,须立单再建)。
- **⑪ 批量操作端点(预留不建)**:批量语义首发=前端逐发+显式挂账(§10);真机若逐发延迟不可接受再立。
- **⑫ 节点排队时间戳引擎手术(P1,判决⑤定案排期)**:`flowrun_nodes` 补时间列(`ready_at`/`started_at`,或经工单⑤执行日志侧扩展——两径调研后择一),让甘特排队灰段有真数据;**必须与 record-once/replay 语义一起设计**:replay 重跑节点的旧戳怎么呈现(新迭代新戳/旧迭代戳保留)要立法进 database.md;这是六项判决里唯一的引擎级重活,排 S4 前完成。
- **⑬ run 历史保留清理(P1,判决④定案)**:保留线配置入 `settings.json`(30d/90d/180d/永久,默认 90d)+定期清理任务;**D1 立法**:log 表物理删除的归档线例外显式登记 database.md(先例=`:replay` 清 failed 行);清理原子性(flowruns+flowrun_nodes+关联执行日志同事务);Settings 存储面板前端工单随 S5。

**记档不立单**:list 行 `pinnedRefs` 冗余重量(见性能痛再议 `?slim=`)。

## 14. 建造批次划分(每批:fe-verify 全绿+真机截图+demo 同批种齐+文档 1:1)

- **S0 地基**(无后端依赖):上收批六件+flowrun-watch 缝上收+AnStatus 3 alias+i18n 命名空间迁移+OceanKind.scheduler+路由骨架三段+panel_registry `flowrun` 登记+headOwners+demo fixture 电池骨架+AnCountdown 进 gallery。**验收**:chat/entities 零回归(上收件消费处全绿);gallery 上收件 specimen 齐;路由深链可达空壳。
- **S1 rail**(依赖③):AnSidebarList 接线+三状态点+durable 重排/hover 钉住+未运行·停用折叠段+Overview 固定行+fr_ 直达+空态。**验收**:真机 rail 全态(demo 电池);tick 不重排的对抗测试;`fr_` 粘贴直达。
- **S2 Overview**(依赖③④):KPI 牌+delta/等你处理(AnCountdown+ApprovalGate 就地+first-wins 422 toast+**AnBatchBar 批量批准/拒绝**[判决②,原语随本批进 gallery])/正在跑(+**批量取消**)/失败聚合(连败语义+[最新 run]+墓碑)/未来调度简版行/零数据首用卡。**验收**:四区空态与满态真机帧;倒计时单 Timer(性能预算);牌全深链;批量挂账逐行落定真机走查。
- **S3 运营主页**(依赖①②⑥⑦):健康头+大表(来源行身份+计数条过滤+pill 归位+**失败态批量 replay**[判决②])+联动格(甘特⇄图双脸先行,**全宽破例落地+design-system §7 豁免登记**[判决③])+triggers 陈列(下 3 次时刻+firing 串+skipped 钻取+**暂停/恢复开关**[判决①,工单⑦]+misfire 策略行)+:kill/Run now。**验收**:过滤计数=真数;新 run 不插行走 pill;暂停后 nextFireAt 消失、rail meta 变「⏸ 已暂停」、Overview 泳道灰显;批量 replay 合并真数字弹窗。
- **S4 run 旗舰+右岛**(依赖⑤**+⑫**[判决⑤:排队时间戳引擎手术排本批前],②③已备):卷宗头+ProvenanceLine+错误同句三投影/钉版图(顺修 run_cockpit 错图 bug)/完整甘特(**三段条:排队灰+执行状态色+parked 琥珀**,running 伸 now,**全宽**;⑫未落回退两段、⑤未落回退等宽槽)/台账(失败置顶自动展开+×N 折叠+**耗时拆「排队·执行」**)/右岛双脸+迭代切换器+就地人闸·replay/冷打开推测态/孤儿墓碑。**验收**:三海拔单选区联动真机走查;冷打开在跑 run 不空白;650KB 注入电池不卡(build 预算);三段条与台账双数同源。
- **S5 增益**(依赖⑧⑨⑩⑬):AnScheduleTrack 真时间轴(+missed 灰叉+暂停泳道灰显)+**矩阵第三脸**(判决③,AnRunMatrix+工单⑩)+**Settings 存储面板「Run 历史保留」配置+大表保留墓碑行**(判决④,工单⑬)+Overview 错过 KPI 牌。**验收**:CustomPainter 两件 a11y 读屏走查+键盘遍历;矩阵虚拟化列窗性能预算;保留策略端到端(改配置→清理→墓碑行)真机验。

## 15. demo fixture 策略

`features/scheduler/data/scheduler_demo_fixture.dart` 数据级电池(D 轨战术:fixture 纯数据非渲染,`demo_fixture_test.dart` 锁种子正确性),AppShell 一次接线 app+demo 同得。种子必含全态:在跑(多节点推进中)/等人(带 deadline 将超时)/连败 ×4/已自愈/skipped·superseded·shed 各一/cancelled/replay ×N/未来 24h 调度扎堆/missed 预留/孤儿墓碑 run/从未运行/停用/650KB 大 I/O 注入/20+ run 翻页。demo 脚本驱动一条活 run 走完(tick→terminal→洗亮)供活性军规逐帧验收。

## 16. 判决记录(2026-07-16 用户终拍板:六项全按最全方案)

- **Q1 暂停调度 ✅ 判决**:运行时权力——本海洋 triggers 陈列就地 [⏸/▶] 开关(工单⑦);cron 表达式编辑仍归 entities;暂停态全链路可见(rail meta「⏸ 已暂停」/Overview 泳道灰显/nextFireAt 置空)。
- **Q2 批量操作 ✅ 判决**:首发即做——批量批准/拒绝(Overview)、批量 replay(大表失败态)、批量 cancel;形态=`AnBatchBar`+hover checkbox;语义=前端逐发+显式挂账(逐行 pending→落定),first-wins 输家 422 汇总 toast;批量端点(工单⑪)预留不建。
- **Q3 矩阵与全宽 ✅ 判决**:矩阵第三脸做(S5,工单⑩);联动格与旗舰甘特/图/矩阵区**全宽破例**,登记 design-system §7 豁免(prose 段保持 720)。
- **Q4 run 历史保留 ✅ 判决**:实装——Settings 存储面板配置(默认 90d)+后端定期清理(工单⑬,D1 归档线例外立法)+大表保留墓碑行。
- **Q5 排队段 ✅ 判决**:排期引擎手术(工单⑫,S4 前完成)——`flowrun_nodes` 补排队时间戳,甘特三段条(排队灰+执行+parked),台账/卷宗头耗时拆「排队·执行」;replay 旧戳语义随工单立法。
- **Q6 misfire ✅ 判决**:默认跳过+missed 记账(工单⑨);catchup-one 作为 trigger 级配置项(默认 skip)归 entities 编辑面;missed 全链路呈现(时间线灰叉/firing 串第三态/Overview 第五牌)。
