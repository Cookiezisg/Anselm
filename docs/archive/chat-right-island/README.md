---
id: WRK-061
type: working
status: archived
owner: @weilin
created: 2026-07-08
reviewed: 2026-07-08
review-due: 2026-10-06
audience: [human, ai]
landed-into: references/frontend/features/chat-sidestage.md, references/frontend/contract.md, references/backend/api.md, references/backend/events.md
---

# Chat 右岛「侧幕 Sidestage」—— V8 entity-workspace 建造规范

> **调研出身**:23-agent 五段扇出(7 读码 + 5 联网 + 4 独立设计概念 + 3 评审 + 4 对抗,105 万 token)。冠军=「侧幕 Sidestage」(3 评审 2 票 + 对抗验证对象),嫁接「Flight Deck 随航控制台」的仪表可用性与另两案(Vivarium/导播台)的单点最优,吸收 50 条对抗挑刺的全部修法。原始材料(四概念全文/逐 kind 四案对照/挑刺原文)在调研 journal,本文是**唯一施工蓝图**——按本文建,不必回读原始材料。
>
> **用户拍板(2026-07-08)**:①AI 干活时右岛自动活起来(跟随为主,平时安静) ②第一版全套戏剧性 ③**不计代价、全覆盖**——凡对话能碰的每种 kind 都有量身活舞台 ④这是产品前端最亮眼的招牌。

---

## 0. 一句话 + 名词表

**侧幕 = 对话的伴生舞台**:左边 transcript 是剧本在演(时间流·叙事),右岛是被造之物的现在时(状态)——AI 一动手,函数、工作流、文档就在侧幕登台,当着用户的面逐字长成、落定盖章、谢幕入册。每一帧动效由真实数据**触发**(见 §4 裁决 R-12),落定必对账,失败必诚实。

| 名词 | 是什么 |
|---|---|
| **舞台 Stage** | 岛上部伸缩区,实体活窗登台处(idle 高 0 ↔ 占岛 ~60% ↔ 升全页) |
| **主角** | 当前在舞台上的实体/执行(一次一位;并行者进频道条) |
| **频道条 Channel Strip** | 舞台头下的并行活动 mini-tab 排(kind 图标+状态点+未读数)——Flight Deck 嫁接,替代纯脉冲待机条 |
| **场记 Rundown** | todos 板,贴舞台下沿,有 todo 信号才出现 |
| **群像 Ensemble** | ≥2 并行 subagent/执行时的等高卡列模式 |
| **演员表 Cast** | 触点台账列表,岛的常驻主体(静场时=整个岛) |
| **场次条 Acts** | 长对话导航抽屉(首版降级为「最近场次」,见 §7.5) |
| **导演器 stageDirector** | 每对话一只状态机 Notifier,仲裁登台/换台/待机/谢幕 |
| **对账 settle** | close 后 GET 真相 cross-fade 替换流中画面——落定画面永远是 REST 真相 |

---

## 1. 信息架构(三态)

右岛 = 固定 320px `AnIsland` + `AnInspector(headless)`(净宽 264px),与 entities/documents 两右岛同构。纵向:**头带**(剧场图标+「侧幕」+ Following 开关 + Acts 目录钮 + ✕)→ 频道条(≥2 活动才有)→ **舞台区**(伸缩)→ **场记层**(todo,有则现)→ 发丝线 → **后台层**(隐条滚动体:群像分节 → 演员表分节)。

- **静场(idle)**:舞台高 0,演员表是岛的主体——一张「这场对话碰过什么」的安静台账,新鲜度靠 `AnFreshnessHalo` 衰老曲线(见 §7.4),**零动效**(静息降级,§10-P4)。
- **跟场(following)**:AI 发起 build/执行 → 舞台展开、主角登台、导演器自动换台;Cast 对应行左缘亮活动脉冲(由导演器当前主角 itemId 驱动,**非** touchpoint 行,§4 R-6)。
- **锁场(pinned)**:用户点 Cast 行/点频道 tab/**在舞台内滚动或任何交互** → 镜头交还用户;AI 新活动只以 `AnFollowPill` + 频道未读数提示,绝不抢。

**接壳(app_shell.dart 三处,照 entities RunTerminal 先例)**:揭示条件 = `onChat && selectedConversation != null && !rightCollapsed`(89-91 行选中门)、inspector 三元加 chat 分支(202 行)、自动跟随(204/217 行)。**sticky 收起轴按海洋分桶**(P0,一行 provider 改动,§9);收起时 AI 活动**永不自动弹岛**——浮层头 panel-right 钮亮 accent 脉冲点,首次主角登台时升级为富 tooltip「AI 正在编辑 X · 打开侧幕观看」(每对话至多一次)。收起期间只留超轻 `activityBitProvider`(bool+未读计数,gateway demux 直喂,无累积状态)——**放弃「后台照常聚合」**,开岛时台账 REST 水化 + 活现场从 transcript reducer 现存 delta 重建(§4 R-15)。

---

## 2. 状态机(修正版:两维正交 + 六态)

对抗验证裁定原稿两处硬伤已修:**Following 开关与 pin 正交化**(开关只承载全局意愿,pin 绝不碰它)、**anchored 升级为 pinned**(舞台内滚动=用户占用)。

**两维**:`followMode`(用户全局意愿,三档:never / 每对话首次 / 每次,默认「每次」,进 settings;per-conversation 内存态,会话切换复位)× `镜头锁`(导演器持镜 / 用户持镜)。

**六态**:`idle`(静场)→ `following`(跟场)→ `pinned`(锁场)→ `curtain`(谢幕过渡)→ `failed-hold`(失败驻留)→ 子态 `anchored`(贴底⇄脱底,仅同主角内)。

| 转换 | 触发 | 编排 |
|---|---|---|
| idle→following | 登台工具集(§3.4 闭表)open 且 followMode 允许且岛开着,**且 open 后 ~500ms 未 close**(短操作不登台,只走 Cast 行高亮——防「3 秒动效包装 0.3 秒事实」) | 舞台 240ms 自顶展开;展开前对后台层 ScrollController 做像素补偿(可见内容零位移);后台层近 2s 有滚动手势则延迟登台只亮脉冲 |
| following 换台 | 新主角 open,且当前主角 idle>800ms(防抖)+ 当前主角已驻留 ≥2400ms(最小驻留) | 旧主角(若活)FLIP 进频道条 120ms,新主角 cross-fade 240ms;**优先级插队表**:人闸待决 > build 活窗 > 执行终端 > subagent 直播 |
| following→pinned | (a)点 Cast 行 (b)点频道 tab (c)点 pin (d)**舞台内任何用户输入:滚/选/拖/点**(N 秒内有输入即视为占用) | pin 实心+主角眉「已锁定」微词;Following 开关**不动** |
| pinned 期间新活动 | 新 open | 绝不换台;`AnFollowPill`「AI 正在编辑 X →」(breath 脉动)+ 频道 tab 未读 AnCountUp;人闸例外:琥珀 pill「AI 在等你决定 →」突破一切静默(含 followMode=never 与岛收起的浮层头琥珀脉冲),点击**一律跳 transcript 白岛门**——决策只在那一处做,右岛只提示与陈列,绝不承载第二个决策控件 |
| pinned→following | 点 AnFollowPill / 点「回到直播」 | 镜头 340ms 滑到当前活动主角 |
| →curtain→idle | 主角 close 且无其他活主角,**仅 following 态** | 落定停 breath1800 → 谢幕:舞台 fade-out + Cast 对应行 slide-in + 「vN·刚刚」高亮 1.8s 衰减(**fade+slide 是默认**;几何 FLIP 仅当目标行恰在视口内才做;行被过滤/未加载则只 fade-out+微词「已入册」)。curtain 期新 open 可抢占提前谢幕 |
| **pinned 下主角 close** | — | **永不自动收场**:就地定格(live 徽熄+落定章翻上)驻留,用户点 ✕/点别行/回 following 才收 |
| →failed-hold | 主角 failed/取消 | 半截草稿披红纱驻留(可滚阅可抢救文本);**可被新 open 挤成带红点的频道 tab**(现场保留),点回可看;显式 ✕ 才收;同实体重试 edit 就地续演并保留失败折子 |
| anchored 子态 | **只由用户滚动手势触发脱底**(绝不用像素位置反推;复用 transcript 现成贴底逻辑),恢复=显式滚回底或点 `AnJumpPill`「▾ 直播中 +N」 | 内容锚定,写入继续视口纹丝不动;**同时升级为 pinned**(滚动=占用) |
| 升全页 | 仅 following 态且近 N 秒无岛内交互;首版**只有 workflow create 允许自动升页**,其余一律用户点主角眉显式升;ESC/把手一键回 | 后台层收成 32px 把手 |

**选文本**:选择手势按下即把该窗**冻结为静态快照**(新内容进缓冲,`AnJumpPill` 带累积计数),选区/复制完成后恢复——与 minimap「点击=静读该段」共享同一冻结机制。

---

## 3. 数据地基(逐字契约 + 四条硬裁决)

### 3.1 touchpoint 台账(演员表数据源,后端 100% 就绪)

- **行 DTO**:`{id:"tp_<16hex>", conversationId, itemKind, itemId, itemName, verb, lastActor, count:int64, firstAt:RFC3339, lastAt:RFC3339, lastMessageId:string(可空)}`。
- **verb 7 种**(CHECK 强制,可 seal):`mentioned/created/edited/viewed/executed/attached/deleted`;**itemKind 12 种**(relation 11 + `attachment`);`lastActor 3 种:user/assistant/subagent`。
- **端点**:`GET /api/v1/conversations/{id}/touchpoints?cursor&limit(≤200,默认50)&kind&verb` → `{data:[行], nextCursor?, hasMore}`;未知对话=空页;kind/verb 拼错=400 `TP_INVALID_KIND/VERB`。keyset=(last_at DESC,id DESC),**排序键会变**(再触碰行跳页)。
- **实时**:messages 流 durable Signal `node.type="touchpoint"`,scope=conversation,payload=完整单行——按行 id 幂等 upsert,重放安全,漏推 REST 兜回。
- **известные边界**:itemName 可空(回退 itemId mono 灰);lastMessageId 可空(空则藏「跳到发生处」);嵌套 invoke 内锚外层 tool_call 块 id;mcp itemId 三径不收敛(install=mcp_ id,动态/uninstall/reconnect=短名);skill itemId=短名;count 是 best-effort 非审计数。

### 3.2 其余面板数据源

- **todos**:`GET /conversations/{id}/todos?subagentId` → `{conversationId, subagentId?, todos:[{content, activeForm, status: pending|in_progress|completed}]}`,≤64 项、无 id、**整表替换语义**;messages 流 durable `node.type="todo"` 整表帧,`payload.subagentId` 分组。行动画按 content 串匹配,match 不上整节 120ms cross-fade(不硬凑)。
- **subagent**:E3 嵌套(`parentBlockId`),`BlockTreeReducer` 折树(幂等/孤儿挂根);open 帧 `content{role,subagent:true}`,close 带 `{status,stopReason,tokens}`。**嵌套子树 LIVE-only**(不落 message_blocks)——历史/重启回看走 `lastMessageId→tool_call 块→result.executionId→GET agent-execution transcript` 重水合;result 无 executionId 则如实降级「去执行档案」nav(§4 R-14)。
- **块级 Delta 恒 ephemeral**(E2):断线即丢——见 R-3 缺口哨兵。
- **flowrun**:节点 tick 是 entities 流 ephemeral Signal `{flowrunId,nodeId,iteration,status}`,**无 durable 终态帧、tick 不带 __port**(见 §9 后端增补件)。

### 3.3 双源裁决(R-1,契约级)

**messages 流 `argumentsText` 是一切活舞台的唯一驱动源**(与 tool 卡同源天然同步);entities 流只取 chat 流没有的**补充**:env 物化终端行、run 终端 Delta、mcp status 信号、flowrun 节点 tick。任何 kindStage 的 entrance 一律由 `tool_call open` 驱动,禁止双读。

### 3.4 登台工具闭表(「等」字禁令)

**触发登台**(创建/编辑 16 build:`create/edit_function|handler|agent|workflow|trigger|control|approval|document|skill` + `write_memory` + `install_mcp_server`;执行:`run_function/call_handler/invoke_agent/trigger_workflow/fire_trigger` + `mcp__` 动态 + `Subagent`;人闸:`ask_user/decide_approval` 走人闸专则)。**不登台**:全部 get/read/search/list 类(viewed 只进 Cast)、`attached`(actor=user 静默入 Cast;attachment 永不自动登台,仅手动 pin)、`delete_*`(Cast 行墓碑化+一次 240ms 灰化,不值一场戏)、conversation kind(不设舞台,点行=切换对话)。

---

## 4. 十六条硬性裁决(挑刺修法,违反=实现 bug)

- **R-1 双源**:见 §3.3。
- **R-2 Cast 实体聚合**:台账物理行是每 (物,**动词**) 一条;`touchpointLedgerProvider` 在 upsert 层**按 (kind,itemId) 二次聚合**(mcp 先归一到 name)成实体行——主显 lastAt 最新 verb,其余 verb 渲微徽序列(悬停展开 per-verb count/时间);任一 deleted 行到达即整实体墓碑化+封禁 GET;实体行排序键=各 verb 行 max(lastAt)。服务端 ?verb= 过滤只用于展开视图。
- **R-3 缺口哨兵**:SSE 断线-重连边界给 `argumentsText` 插缺口哨兵;活舞台见哨兵即**冻结生长**、盖「实时流有缺口」丝带、绝不把缺口后增量继续喂解析器;close 快照/REST 对账到达后整窗重渲真相;resync 后所有 live 主角降级为等待回执态。
- **R-4 live 期禁成功语义**:op 芯片/签名药丸/腰带扣入等一切流中完成态视觉一律**中性「已听写」态**(轮廓勾/墨点/无色);close 对账后按 `opsApplied`/GET 真相才盖实心成功勾;失败时折子整体盖「未应用」斜纹。
- **R-5 edit 登台即 GET 旧真相**(一石四鸟):args 首键(functionId/… 恰为第一键)一解析即 GET 单读——名字(候名期 shimmer)、`AnLayerDiff` 淡墨地层(40-55%,「改之前的它」全程在场)、diff 底料(close 后新旧真相算真 diff)、document 前缀快进基线,四件共用这一次 GET。create 候 set_meta 补名,无旧版不显 diff 徽章。**基线竞态**:document 前缀对账基线一律=本次 open 后新发 GET 完成的快照,content 增量先缓冲至基线就绪;GET 失败/超时整篇退慢拍生长(宁慢勿假)。
- **R-6 Cast 活动脉冲由导演器当前主角 itemId 驱动**,不依赖 touchpoint 行(首碰时行尚不存在——行在工具执行后才落)。
- **R-7 失败无台账行**:loop 只记「真派发跑到返回且工具层 ok」——failed create 从未入册,失败谢幕**不做缩回 Cast 动画**;失败的唯一持久档案=transcript tool 卡(tool_result error 是 durable),failed-hold 驻留 + 「在对话中查看失败详情」nav;错误微章=session-local 覆层(悬停注明非台账事实)。
- **R-8 env 物化不阻谢幕**:谢幕照常;syncing 由 Cast 行琥珀微章 + RunStatBar 承接,前端对 envStatus∈{pending,syncing} 退避轮询 GET(或吃 notifications 流 function.updated 触发 refetch)至 ready/failed;envFixTimeline 完整版留给实体页,右岛演到谢幕为止。
- **R-9 args 缺省键渐进开区**:舞台按「args 流中实际出现的键」开区;未出现的槽渲 40% 饱和度旧真相(R-5 地层),出现且显式空才演「卸下」;`edit_document` 无 content 键不开散文幕,降级元数据小卡——缺省保留与显式清空绝不渲成同一种「空」。
- **R-10 执行类生命周期 LifecycleSource 三型**:导演器把主角生命周期抽象为接口——`tool-close 型`(build/同步执行)、`signal-terminal 型`(mcp=status 信号到 ready/failed/degraded 即 settle)、`poll 型`(flowrun=entities Signal 静默 N 秒 + GET 轮询兜底,或等 §9 后端终态帧)。`trigger_workflow` 202 即 close——绝不能按 close 谢幕。
- **R-11 control/approval 命中级**:tick 不带 __port——收到 completed/parked tick 后**惰性 GET flowrun 节点页**取 `__port`/`rendered` 再点亮(点亮前渲「判定中」中性态);禁止用「最后一个 op」猜。
- **R-12 重播预算**:闭合值入场重播上限 ~200-300ms;积压 >2 个未演事件即跳过入场动画直接渲累积态(只保最后一个的动效)。措辞铁律:动效由真实数据**触发**(不承诺逐帧「驱动」)。
- **R-13 动画窗口有界**:词级淡入只在尾部滑动窗口(≤最近 1-2 行 / ≤30 词)内发生,滑出即合并进静态前缀(单 Text/RichText 零子 widget);或单 CustomPainter 按词 alpha(一个 ticker 零子树)。`AnCelGrow` 同帧至多 1 个活动画实例。
- **R-14 subagent 历史水化**:live 用 reducer 子树;历史用 executionId 径(§3.2);群像谢幕**由 transcript 锚承接**(Subagent tool_call 块 id durable)而非 Cast(role 式 subagent 在台账没有影子)——invoke_agent(有 Cast 行)与 Subagent(仅 transcript 档案)两条谢幕路径分开写。
- **R-15 收起=只留 activityBit**:见 §1。开岛才开始跟,历史靠 REST 补。
- **R-16 trigger 计数只信 GET**:nextFireAt 倒计时每分钟 tick,检测已过期即重 GET 刷新(归零顺手闪一记);fire ephemeral 信号仅作提前刷新触发器;firingCount 只从 GET 渲染绝不据帧 +1(与通知模块同裁决)。

---

## 5. 性能纪律(P0 前置工程,先绿再开舞台)

对抗验证的头号发现:**流中 JSON 引擎现状是 O(n²),直接铺 13 舞台必炸帧**。以下为 W0 前置件,gallery 里各配 perf specimen(timeline 证明流入期 UI 帧 <16ms)后才准开工舞台:

1. **partialJsonEvents 增量化**:可恢复解析器(持久化 parse offset+容器栈,新 delta 只喂尾段,已闭合值不重发)。
2. **argStringPartialAt(带路径在途尾值通道)**:现 `argStringPartial` 是全片正则**首匹配**、无路径——handler 多 method 的 body、fn 多 set_code、wf node.input 在途值全拍不出来;扩 partialJsonEvents 报 `(path, partialString)` 在途尾值事件。**document/agent prompt/approval template/skill body 的在途驱动源=此通道**(partialJsonEvents 闭合值通道对流中字符串一个事件都不发——原设计整场黑屏)。含截断/转义/畸形五电池。
3. **argumentsText/派生缓存 memoize**:按 delta.length 缓存物化结果;`blockToolCardState` 对同 BlockNode 同长度返回缓存实例。
4. **`_delta.clear()` on close 快照**(block_tree_reducer FrameClose 一行改动,防 1MB 文档双份驻留)+ 落定对账后释放舞台 argsText 派生缓存。
5. **durable 信号不进 CoalescingNotifier**(其契约 EPHEMERAL-ONLY):touchpoint/todo 走 Riverpod cache 直接 patch(照 pendingInteractions 先例);重排「视觉」节流在 UI 层——用户滚离列表顶部即**冻结行序**(upsert 只改行内样式),回顶才一次性重排;深翻页时收到信号只置「列表已变化 ↻」小条。
6. **静息降级**:全部脉冲/呼吸共享一个 ticker(单相位源+各自 RepaintBoundary);无新帧 N 秒后降级为静态实心点;收起态浮层头脉冲=一次性 3 次后转静态角标。
7. **op 批处理窗口**:ops 进队列每 ≥240ms 聚一批做一次 relayout+一轮 tween;fitView 相机去抖 800ms;画布整体 RepaintBoundary、节点微动画各自 boundary。
8. **ReAct 剧场虚拟化**:不复用 block_tree_view(非虚拟化 Column)——CustomScrollView+SliverList 顶层块序列虚拟化;reducer 加 O(1) 尾指针字段(apply 时维护),Ensemble 摘要/shimmer 禁 build 期遍历子树。
9. **游标一致性**:已载区按行 id upsert 去重;loadMore 游标取当前已载最末行 (lastAt,id) 现值(或信号后标记游标脏、下次先重拉首页);五电池含「滚到第 3 页收到已载/未载行各一条信号」专测。
10. **>20KB 文本换挡**:行级节流 10ms/行、上文折叠「…前文 N 字」、动画层只挂尾块 leaf;minimap 单 CustomPainter+前沿光标独立小 layer;段落切分只对新 delta 找边界(偏移数组 append-only)。

---

## 6. 五面板

- **① 舞台**:`AnStageShell`(0↔~60%↔全页)+ 主角眉(kind 图标+名 w400+verb 徽章+live/落定/失败章+pin+✕)+ 按 kind 路由 13 舞台(§7)。铁律:live 全程挂 `AnHonestyRibbon`;落定必对账;换台绝不硬切占用中的主角。
- **② 场记(todos)**:`AnRundownList` 贴舞台下沿,进度眉 `AnTaskRing`(completed/total,推进补弧,全满一次 240ms 温和辉光绝不彩带);行=pending 空圈/in_progress **activeForm 进行时文案**+accent 呼吸点/completed 勾+划线灰化下沉;subagentId 子清单折叠于对应 subagent 行下、该频道活跃时自动展开;只读。
- **③ 群像(subagent)**:`AnEnsembleGrid`,**≥2** 并行即群像(统一裁决);卡=名+当前动作 AnShimmerText(读 reducer 尾指针)+3 行 AnTermTail;点卡=pin+升 ReAct 剧场,其余缩频道 tab;close→卡结算(status 勾叉+tokens AnCountUp+stopReason)。
- **④ 演员表(touchpoints)**:`AnCastRow` 实体聚合行(R-2)=kind 图标+itemName(空回退 id mono 灰)+主 verb 微词(七动词 i18n:**verb 单轨 key+kind 名作参数**,7 条非 91 条)+verb 微徽序列+count 上标+lastAt 相对时间+`AnFreshnessHalo`(衰老=去饱和绝非透明化:<2min 光晕渐灭,<1h 全饱和,随时间沉淀成灰;只对可视区计算);活动脉冲(R-6);deleted=墓碑;交互=点行 pin 登台(live 续演/落定 GET 陈列/墓碑静态)、行尾 focus 常显两动作「跳到发生处」(lastMessageId→transcriptJump;空则藏)与「去实体页」(toolNavTo);顶部 kind segmented 过滤(服务端 ?kind=);keyset 无限滚。
- **⑤ 场次条(导航)**:**真解直上**(§12 拍板 3:后端 anchors+around 端点在 W6 正式建)——全量锚点、任意深度秒跳;头带目录钮开覆盖抽屉:待决人闸(琥珀,置顶)>危险工具>user 回合(首行截断)>compaction>异常终态;**连续 N 个工具折叠为一簇「⚙ 6 项操作」**;点锚=transcriptJump+抽屉自收。端点落地前的开发过渡=已加载 BlockNode 提取+循环 loadOlder(不作为交付形态)。BlockNode 无 createdAt→hydrate 补透传(流式新块用本地到达时刻标~)。

---

## 7. 逐 kind 活舞台目录(13 座,全覆盖核心交付)

> 通则:登场一律 `tool_call open` 驱动(R-1);edit 一律 R-5 起手(GET 旧真相=名字+地层+diff 底料);live 中性语义(R-4);落定=close 回执+GET 对账 cross-fade+RunStatBar;失败=failed-hold(红纱驻留,R-7);全部动效走 AnMotion + reduced-motion 门控,**每个 transient 动效必须声明静态残留物**(依赖虚线→hover 常驻连线;patch diff→红绿底色驻留;新鲜度→halo 曲线+「新」微章;补名→tooltip 留一拍)。

1. **function** —— 本质=activeVersion.code+inputs/outputs 签名+dependencies+env 镜像。登场:λ 眉+`AnLayerDiff` 旧码地层(edit);流式:`OpTicker` 逐 op 落中性芯片;set_code→`AnLiveCodeWindow`(行级 chunk 释放绝不逐字,尾 24 行,贴底/锚定,行数 AnCountUp,R-13 有界淡入);set_inputs/outputs→签名药丸 stagger 点亮;set_dependencies→依赖芯片;set_meta→眉名 cross-fade。落定:AnCodeEditor 全量高亮+diff 徽「+n −m」(R-5 底料真算)+RunStatBar(id·vN·env);env 按 R-8。执行(run_function):舞台切终端页,entities 流 Delta 进 AnTermViewport,elapsed 活秒;结算 {ok,elapsedMs}。
2. **handler** —— 本质=methods 数组(name/body/streaming/timeout)+imports+init/shutdown 生命周期+initArgsSchema(sensitive 掩码)。**无 match 判别式(契约如此,勿设想)**。登场:竖向生命周期轨 init▸方法架▸shutdown 幽灵虚框;流式(**依赖 argStringPartialAt**,多 method body 同键):add_method→方法书脊 FLIP 插架(名+streaming 波浪+timeout 钟),body 书脊内小窗续长;update_method(RFC7396)→书脊翻开 240ms,patch 键原位红绿微 diff;delete_method→书脊降饱和抽走;set_init/shutdown→对应段活代码窗(尾 12 行);set_init_args_schema→配置面预览表,sensitive 直接演 `••••` 掩码。落定:configState 三色徽+missingConfig 点名药丸+runtimeState 心跳点(running 绿脉/stopped 灰/crashed 红);restarted→「热重启」徽脉冲+restartNote。执行(call_handler):方法名章+yield progress 流水贴底+instanceId mono。
3. **agent** —— 本质=prompt 散文+tools 腰带+knowledge 书包+skill 徽+modelOverride。登场:「人格装配台」=中央 prompt 散文窗+三装配槽剪影;流式:prompt(argStringPartialAt)词级淡入(R-13 窗口);tools 每 ToolRef 闭合→腰带扣芯片(fn_/hd_.method/mcp:s/t 按 AnIcons,中性态);knowledge→id 芯片 shimmer 候名;modelOverride→铭牌翻牌;**edit 合并语义=R-9 渐进开区**(未提及槽 40% 墨静默——一眼看清「AI 只动了这些」;显式空才演芯片集体降饱和滑出)。落定:GET+**mount-health 体检**——腰带逐 mount 点灯(healthy 绿/error 红+悬停错因,80ms stagger 检查单),allHealthy 盖「装配完好」章;knowledge 芯片真名替换。执行(invoke_agent)→subagent 舞台(#13)。
4. **workflow** —— 本质=graphParsed nodes/edges+每 node.input 裸 CEL+边 fromPort+lifecycleState/concurrency。登场:create=升全页(首版唯一自动升页)空画布;edit=GET 现图 AnGraphCanvas 静置底座再 morph(「改之前的它」先在场)。流式:ops 批处理窗口(§5-7)——add_node 落点(scale 0.92→1+dagre 增量布局温柔推开+fitView 340ms 去抖跟拍);add_edge 抽丝画线+fromPort 标签随线生长;**CEL 判别式抽屉**:node.input 每值在节点下沿 `AnCelGrow` 逐 token 淡入,`上游.field` 引用渲 nav 芯片+向上游节点闪 60% 数据流虚线 340ms 一次(**水脉闪**——依赖可见即戏剧);update_node→节点脉冲+抽屉整体重演(input 整体替换语义如实);delete_node→降饱和缩小+级联边同退;布局 FLIP 三相。落定:GET graphParsed 对账 cross-fade+RunStatBar(id·vN·nodes/edges AnCountUp)+lifecycleState 徽。执行(trigger_workflow):**LifecycleSource=poll 型**(R-10);同画布叠 GraphRunState 覆层,ephemeral tick 点亮节点(running 呼吸/completed 绿/failed 红/parked 琥珀站牌——approval 节点渲 rendered 预览+去决策 nav,__port 按 R-11 惰性 GET);iteration>1 角标 ×n;断流只影响动画不影响终态。
5. **trigger** —— 本质=config 四形(cron.expression/webhook path+签名三件/fsnotify path+events+pattern/sensor 四件)+outputs;非 build,args 流照有(R-1)。登场:「哨位」剪影,args 首键 kind 解出即换 `TriggerConfigCard` 对应脸(cron 钟面/webhook 端口/fsnotify 文件眼/sensor 透镜);等待回执期 `AnRadarSweep` 单色脉冲环(诚实等待,不伪造进度)。流式:cron 五段逐段落格+人话预告实时刷新(「每天 09:00」);webhook path 落格+secret 锁扣+signatureAlgo 药丸;fsnotify AnPathChip+events 药丸+pattern mono;**sensor=判别式专场**:targetKind/Id 落靶→intervalSec 节拍器→condition CEL「条件透镜」AnCelGrow(payload.* 入射药丸)→output CEL「出射面板」构形。落定:GET 对账——listening 绿呼吸点(全目录唯一持续呼吸,它的本质就是等待)+**nextFireAt 活倒计时行「下次点火 T-2h14m」**(R-16)+refCount「被 n 条 workflow 引用」nav;fire=雷达闪一记+计数按 R-16。
6. **control** —— 本质=branches[{port,when,emit}] 决策梯+inputs;**判别式生长正殿**。登场:决策梯骨架(B2 落定形)+左缘**求值顺序流向丝线**先亮;edit=旧梯 40% 垫底(全量替换语义诚实预告)。流式:branches 逐个闭合→梯级自上滑入 stagger 60ms——port 名牌 w400+when `AnCelGrow` 逐 token(input.* 引用与顶部 inputs 表对应行闪虚线)+emit 出射格生长(空 emit=「透传」幽灵字 w300 40%);末级 when="true" 自动渲「否则」兜底灰徽(不渲成代码)。落定:GET 对账+vN;运行期(flowrun)**丝线流到命中级即止**+命中级亮 accent、未命中降墨(__port 按 R-11)——first-true-wins 被看见。
7. **approval** —— 本质=template(markdown+{{ CEL }} 插值)+timeout 三轴+allowReason+inputs。登场:「审批信笺」纸质卡(ProseWindow 变体)+三轴仪表虚框+「预览·尚未寄出」幽灵章。流式:template 散文词级生长(argStringPartialAt),**{{ input.* }} 流中即时凝成琥珀插值药囊**(AnCelGrow 微型,散文与判别式双语混排——approval 独有);allowReason→理由栏虚线框;timeout→沙漏+人话(「30d 后 reject」三向各自措辞,""=∞「永不超时」)。落定:GET 对账+**「预演」帧**(inputs 名空样张渲一遍——用户看到审批者将看到的样子,复用 B2 表单预览);运行期 parked=琥珀站牌渲 rendered 真文+决策双钮**只读镜像**(决策仍在中心人闸,右岛不抢决策权)。
8. **document** —— 本质=content(markdown ≤1MB,全量替换)+name/path+sizeBytes;[[id]] 渲 mention 药丸。登场:「散文幕」=文档头(名+AnPathChip)+左缘 `AnMinimapSpine` 书脊空条+主窗虚框 stagger 亮。流式(argStringPartialAt):**前缀对账快进**(R-5 基线)——与旧 content 公共前缀段速览快进滚过(不假装重写),分叉点起才词级慢拍生长;书脊同步着墨+写入前沿 accent 光标匀速下移(整篇进度一眼可见,流速超阅读=收窄取景框而非放慢);主窗只渲最近 ~40 行(块级拆 widget 仅尾块 reparse);[[id]] 流中即药丸化;>20KB 换挡(§5-10);点书脊=冻结静读该段+「回到前沿」pill。落定:GET 对账 cross-fade 成与文档海洋 1:1 阅读态+诚实徽章「全量替换 · 2.3KB→5.1KB」(sizeBytes AnCountUp)+「在文档海洋打开」nav;失败:红纱+「草稿未保存」丝带,全文可滚可抢救(failed-hold)。
9. **skill** —— 本质=frontmatter 铭牌(name slug/description/allowedTools/context inline|fork/agent/arguments/disableModelInvocation)+body(≤32KB,$ 占位)。登场:「技能卡装订台」=上铭牌区(AnSunkenPanel+发丝边)+下 body 散文窗。流式:**name slug 逐字 mono 落格**(全系统唯一允许逐字处——slug 即身份,≤64 字符,给命名一点仪式感);allowedTools 药丸逐扣(**琥珀细边示「预授权免确认」权力感**);context inline|fork 翻定(fork 时 agent 槽亮 nav 芯片);arguments 表逐行;disableModelInvocation→「仅人可唤」微章;body 散文生长,`$ARGUMENTS/$1/${CLAUDE_SESSION_ID}` 占位渲 accent 空槽芯片(模板血统可见)。落定:GET /skills/{name} 对账;**名即身份无 vN——「slug 印章」落章动效**(120ms scale-in);updated=全量写语义如实 cross-fade。
10. **memory** —— 本质=content+description+pinned(仅 REST 用户特权)+source 不可变;非 build,args 流照有。登场:「记忆笺」便笺小窗 340ms 轻落(translateY −4→0),slug 笺角 mono。流式:content 词级长满笺面;**同名 upsert 就地更新**:旧笺 40% 垫底,新文长于其上盖到哪算哪(诚实呈现 upsert);**pinned 图钉微微一颤**(120ms)+悬停注「AI 动不了你的图钉」——权限边界成为品牌瞬间。落定:GET 对账+pinned 针脚只读陈列+source 微词;`forget_memory`=「揉纸」谢幕(降饱和+scale 0.96 淡出)+Cast 行墓碑。
11. **mcp** —— 本质=安装配置(stdio|remote)+tools 货架+status 状态机(disconnected→connecting→ready/degraded/failed,不落盘);**LifecycleSource=signal-terminal 型**(R-10:settle=status 到 ready/failed/degraded,不按 tool close 谢幕)。登场:「接线现场」(允许手动升全页)=顶部 `AnStatusLadder` 状态梯(当前站呼吸蓝)+主区安装终端。流式:args{name,env}→铭牌+env 键名药丸(**值恒掩码**);entities 流 progress Delta 滚终端(termFold/ansiSpans);status 信号每变一站→光点 240ms 滑站;reconnect 同轨复演;uninstall→梯反向走灭。落定:ready→GET 对账,**tools[] 工具货架逐行亮(stagger 40ms)+「发现 N 个工具」AnCountUp**(接驳成功的 payoff);degraded/failed→lastError 红条+consecutiveFailures+「查看 stderr」(GET /{name}/stderr 进终端页);右岛只陈列不给重连钮(操作去实体页)。舞台按短名归并双径;台账如实双行、Cast 视觉按 (kind,itemName) 折叠 ×2。
12. **attachment** —— 本质=filename+mimeType+kind 六型+sizeBytes+sha256;静物,**永不自动登台**(§3.4)。手动 pin=「展品座」美术馆开灯(opacity 0→1+scale 0.97→1):kind 图标+filename w400+sizeBytes+sha256 前 8 位 mono「内容寻址指纹」;image→GET content 缩略图。唯一动效:`read_attachment` 时阅读光标自上而下扫一次 340ms+viewed 计数上标。无落定概念,展品即真相。
13. **subagent/执行档案** —— 本质=E3 嵌套块流+close{status,stopReason,tokens}+各自 todo。登场:Subagent open→频道 tab 弹入;≥2=群像。流式:紧凑 ReAct 尾(最近 6 块:reasoning 一行 shimmer/tool_call 裸行/text 摘要,读尾指针);内层 Bash/长输出活跃时**升整页终端**(AnTermViewport fill+termFold+ansiSpans+贴底,「一整页是终端用的」);todo 帧同步 Rundown。落定:tab 状态点翻绿/红+结算行 tokens in/out AnCountUp+stopReason 非 end_turn 如实陈词;群像全落定=结算态并列停 breath1800(截图时刻)→谢幕按 R-14(transcript 锚承接);历史回看按 R-14 executionId 径;ephemeral 断流→AnHonestyRibbon「输出可能有缺口,以执行记录为准」。

---

## 8. 四分镜(修正版要点)

原侧幕分镜 a–d 整体成立,按裁决修正后的关键拍:

- **a) edit_function**:T0 open→~500ms 防抖→登台(眉=shimmer 候名,**非**触点快照);args 首键 functionId 解析→GET 旧真相(R-5)→名字+地层同落;set_code 行级生长(中性芯片);close→对账 cross-fade+真 diff 徽;env 按 R-8 谢幕不等 syncing;curtain 缩回 Cast=fade+slide 默认。
- **b) create_workflow→edit_workflow**:create 自动升全页(唯一);ops 批处理落节点+CEL 抽屉+水脉闪;create close 对账**不谢幕**(同 itemId 新 open 就地续演,verb 徽翻「editing」count ×2);用户拖画布=pinned;edit close 对账+「v2」章→谢幕。
- **c) 三 subagent 并行+todo**:三 open→群像三卡 stagger 滑入+频道条三 tab;todo 首帧→Rundown 升起;用户点卡=pinned+升 ReAct 剧场(虚拟化),其余 tab 积未读数;逐 close 翻状态点;全落定=群像结算同框→transcript 锚谢幕(R-14)。
- **d) edit_document**:登台三件套 stagger;基线 GET 就绪前 content 缓冲;**前缀快进**至分叉点→词级慢拍+书脊着墨+前沿光标;用户点书脊=冻结静读;close→对账+「全量替换 2.3KB→5.1KB」;失败=红纱驻留可抢救。

---

## 9. 组件清单

**复用**(零改或小改):AnIsland/AnInspector(headless)/AnInspectorHead/AnSection(quiet)/AnRow/AnKvRow/AnState(inset) · partialJsonEvents(增量化后)/argStringPartial(→argStringPartialAt) · AnMiniGraphGrowth(休眠资产正式启用)/AnGraphCanvas+GraphRunState/graphFromWorkflowOps/workflowEditDelta · AnCodeEditor/AnTermViewport(补 fill-parent 模式)/AnStickViewport/AnTermTail/termFold/ansiSpans · AnShimmerText/AnCountUp/AnSunkenPanel/AnPathChip/mention 药丸 · ToolWindow family bodies/ProseWindow/TriggerConfigCard 四脸/B2 决策梯/表单预览/RunStatBar(RefPill 顺手接 toolNavTo)/envFixTimeline · BlockTreeReducer(+尾指针)/pendingInteractionsProvider 先例/KeysetQueryPaging/CoalescingNotifier(仅 ephemeral)/SseGateway conversationFrames · panelLocationFor→toolNavTo · outlineJumpProvider 先例 · AnIcons 精确表/resultFailed 缝/ToolReceipt tone。

**新原语**(gallery-first,~24 件):

| 层 | 件 |
|---|---|
| 编排 | `stageDirectorProvider`(六态+LifecycleSource 三型+优先级表+防抖/驻留参数) · `touchpointLedgerProvider`(三源合一+R-2 聚合+游标纪律) · `transcriptJumpProvider`(**独立 spike**:双 sliver 中心锚+可变行高下按 id 双向步进,「跳转期间新帧不得夺视口」为验收) · `activityBitProvider` |
| 壳 | `AnStageShell` · `AnChannelStrip`(频道 tab+未读+matched-geometry 下划线,cap4 溢出) · `AnFollowPill` · `AnJumpPill` · `AnHonestyRibbon`(live/未保存/缺口/全量替换/「真相仍是 vN」五触发) · `AnCurtainCall` |
| 台账 | `AnCastRow` · `AnFreshnessHalo` |
| 窗 | `AnLiveCodeWindow` · `AnCelGrow`(判别式生长+水脉闪+流向丝线 mode) · `AnMinimapSpine` · `AnLayerDiff` · `AnMethodRack` · `AnAssemblyBay` · `AnStatusLadder` · `AnRadarSweep` · `OpTicker` · `AnRundownList` · `AnTaskRing` · `AnEnsembleGrid` · `AnActsRail` |
| 引擎 | partialJsonEvents 增量化 + argStringPartialAt(§5-1/2,P0) |

**后端增补件**(迭代铁律②,同提交守 N/D/E/S/T+文档纪律):P0-a `GET /conversations/{id}/messages?around=<messageId>`(深历史跳转,前端循环 loadOlder+20 页上限兜底到它落地);P1-b flowrun 终态 durable 帧(或前端 poll 兜底,R-10);P2-c control/approval tick 捎带 __port(一行,免 R-11 惰性 GET);P2-d anchors 端点(场次条真解);P1-e BlockNode createdAt hydrate 透传;P2-f 版本单读端点(跨会话历史 diff,首版不承诺)。

**AppShell 增补**:P0 sticky 收起轴按海洋分桶(✅ W0 已落);**右岛全域可拖宽 ✅(0708 二次拍板已落)**——AnShell `_RightReveal` 镜像左岛 grip(280–640 默认 320,`ShellChrome.rightWidth` 持久化 `fy.side.rightw`,动态上限=海洋保底,窗口最小宽公式改用右岛 min=1192),图画布局促问题由用户自行拖宽解决。

---

## 10. 建造顺序 W0–W7(每批独立可交付)

| 批 | 内容 | 门 |
|---|---|---|
| **W0 前置工程 ✅(2026-07-08 已落)** | §5 全部——①`PartialJsonSession` 增量引擎(显式栈可续解析,O(delta) 每喂、闭合值不重发;`core/model/partial_json.dart`,旧 `partialJsonEvents` 门面在其上重实现、语义逐字保持)②argStringPartialAt=`inFlightString`/`inFlightStringAt`(带路径在途尾值)+`liveStringNamed`(任意深度按键、在途优先——handler 多 method body 各归其位)+`arrayItemsAt`/`closedValueAt`/`closedStringAt` 门面+`argsSessionOf`(BlockNode↔session Expando 桥,开/关两相、关帧快照重建一次)③memoize:BlockNode 子树 `revision`(reducer 沿祖先链自增)+`deltaText` 按长缓存+`derivedCache` 槽;`ToolCardState.of` 同 (revision,人闸旗) 返同实例 ④`_releaseDeltaIfSnapshotted`(close 快照盖住即清 delta 缓冲,免双份驻留)⑤durable 通道契约已写死在 CoalescingNotifier 文档(EPHEMERAL-ONLY),touchpoint/todo 接线随 W1 ⑥`PulseClock`(core/perf:单 Ticker 相位源+poke 活动门+静息降级冻回静态姿态)⑦sticky 收起轴按海洋分桶(`RightPanelCollapsed`→Map<OceanKind,bool>)⑧AnTermViewport/AnStickViewport `fill` 撑满父高模式 ⑨活窗消费者全换 session(write/edit/builds/workflow ops/control branches + document/skill/writeToolBody/editToolBody 落定体)+`tailLines` O(tail) 取尾 | **✅ 真机 profile 三床全绿**(错峰自动跑,HUD 全程 0 帧 >16.7ms:1MB content 最差 15.2ms/1008 帧 · 50op/s×400 最差 14.0ms/953 帧 · 5000 词 最差 14.6ms/1403 帧;gallery「性能 Perf」类目,截图脚本 `test/dev/shot_perf.sh` 按窗口 ID 截不抢焦点)。**门禁抓到的真崩点**:`argString` 回溯正则捕获组在 MB 级值上**爆栈**(profile ErrorWidget=灰墙),且 settled 族体在收起 reveal 里**每帧仍被构造**——argString 已手写化 O(n) 零递归,settled 体长值一律 `closedStringAt`(每帧 O(事件数));回归钉死于 `tool_card_stream_pressure_test.dart` |
| **W1 底盘 ✅ 主体已落(2026-07-08)** | ①数据缝:`core/contract/touchpoint.dart`(verb/actor enum+unknown 兜底)+`listTouchpoints`(接口/Live/Fixture 三实现+fixture `touch()` 脚本钩)+`touchpointLedgerProvider`(订阅先于水化/durable 直 patch 绝不过 CoalescingNotifier/R-2 (kind,itemId) 聚合 mcp 按名归一/deleted 墓碑/§5-9 按行 id 去重 lastAt 新者胜/410 重同步=重拉首页并入[缺口行 lastAt 必新,首页即覆盖]) ②`StageDirector` 纯状态机(六态/500ms 登台防抖/800ms+2400ms 换台仲裁/优先级插队/curtain 接场/pinned 永不自动收/failed-hold 挤台成红点 tab/dismiss 重挣;全事件带 now、期限制,毫秒级单测 11 条含抢镜 VETO)+`stageDirectorProvider` 宿主(帧投影/唯一闹钟 advance(到期时刻)非墙钟/人闸旗;**StageState 输出快照化 `StageActivityView`**——修掉真 bug:可变 StageActivity 引用让 previous/next 同对象、close 广播被值相等吞掉) ③UI 原语 5 件+gallery specimens:`AnCastRow`(新鲜度四档+分级降显 LayoutBuilder<265 舍装饰)/`AnChannelStrip`(cap4+溢出)/`AnFollowPill`(共享 PulseClock 呼吸;reduced 零 ticker 可 settle)/`AnHonestyRibbon`(live/gap/failed 三触发;**干净落定撤丝带**)/`AnFreshnessHalo`(衰老=去饱和) ④**通用舞台**(主角眉 kind 字形+候名 shimmer+相位章+pinned 微词、闭合顶层 args AnKvRow 陈列剥框架键、在途尾值 ToolWindow 活窗、落定 RunStatBar、失败红纱+errorText;骑 transcript coalescer,liveBlock 缺失渲诚实缺口占位) ⑤接壳三处(chat 选中揭示/inspector 三元 StagePanel/sticky 分桶已在 W0)+`ConversationTranscript.liveBlock` ⑥demo 剧本升级(create_document 流式一幕+close 快照+touchpoint durable 信号+cv_sync 台账种子,app+demo 同壳同活) | **抢镜电池入 fe-verify**(director VETO 11 测+panel 3+ledger 9+host 5)+**真机 demo 全链路截图验证**:静场 Cast R-2 聚合(sync_inventory=Ran+✎ 双动词一行)→发送→登台(眉+Settled 章+KV+活尾)→谢幕回静场→Cast 顶部实时落行 quarterly-fix.md·Created。**W1 尾巴(记账,随 W2 动效批一起打磨)**:`AnCurtainCall` 完整谢幕动效(fade-out+Cast 行 slide-in+1.8s 高亮衰减——现为 reveal 收起)/收起态 `activityBitProvider`(R-15)/舞台内滚动=pinned 的手势侦听(现仅点按占用) |
| **W2 旗舰 ✅ 主体已落(2026-07-08)** | ①三原语+specimens:`AnLiveCodeWindow`(**整行释放绝不逐字**·未完尾行按住不显·尾 24 行贴底·行数 AnCountUp 增量统计 O(delta)·换源诚实重扫·R-13 淡入仅限新落行)/`AnMinimapSpine`(单 CustomPainter 书脊:着墨→前沿 accent 刻度→快进前缀 muted→段界细线,tap 报分数)/`AnLayerDiff`(旧真相地层:低墨节选+vN 出处签,live 期在场、落定退位) ②R-5 数据缝:ChatRepository `getFunctionSnapshot/getDocumentSnapshot`(Live+Fixture 可种)+`functionTruthProvider/documentTruthProvider`(失败=诚实降级为无基线,宁慢勿假) ③**FunctionStage**:edit 登台即地层(v3·改之前)→OpTicker 中性芯片(R-4 轮廓点,落定实心)→set_code 活代码窗→签名/依赖药丸→落定 AnCodeEditor 高亮+**真 diff 徽 +n −m**(lineDiff(fetched before, landed after))+RunStatBar;失败残稿可读 ④**DocumentStage**:头+AnPathChip→书脊+散文尾窗(尾 40 行贴前沿,[[id]] 内联药丸)→**前缀快进**(增量比对 O(delta):快进中/前 N 字一致·已快进 两态标)→落定 ProseWindow 1:1 排版+「全量替换 aKB→bKB」徽;**R-9** 无 content 键=元数据小卡+「本次未改动正文」绝不伪造散文幕;失败整篇残稿可滚可救 ⑤`stageBodies` registry(kind→量身体,W3–W5 逐批补满)+StageScene 载体+demo 双幕剧本(edit_function 压旧真相种子→create_document 接场)| **✅ 集成电池 3 条**(fn 全周期含 +3/−1 真 diff 断言·doc 快进/分叉/落定徽·R-9)+原语电池 4 条+**真机逐帧截图验收**:fn 流中帧(地层+ticker+活窗 8L+Cast 主角脉冲 R-6 同框)/doc 流中帧(书脊+散文尾+换台后 sync_inventory·Edited 落账)/全落定帧(v4 徽+文件名回执+Cast 双行+谢幕)。**W2 尾巴**(记账,归 W7 polish):词级淡入/快进滚动动画的完整动效版(现为 R-12/13 有界简洁版)/[[id]] 真名解析(MentionSource)/doc 落定态真机单帧 |
| **W3 图与判别式 ✅ 主体已落(2026-07-08)** | ①两原语+specimens:`AnCelGrow`(CEL 判别式陈列:点路径引用凝 accent 药囊=数据入射可见,live 只尾段淡入 R-13,compact 档供散文内嵌)/`AnRadarSweep`(共享 PulseClock 扫描环=诚实等待,reduced/静息=静态驻点) ②真相缝×4(workflow/control/approval/trigger 单读:接口+Live+Fixture 可种+providers) ③**WorkflowStage**:闭合 ops 建图上真 `AnGraphCanvas`(节点/边计数)+「最新判别式」抽屉(最新带 input 的节点逐条 AnCelGrow)+edit 静置旧图 0.55 墨(R-5 地层)+「基于 vN 起改」+落定 RunStatBar ④**ControlStage**:左缘求值顺序丝线(序号圈+竖线)+梯级(port w400/when AnCelGrow/emit 出射格/空 emit=幽灵「透传」/末级 when:"true"=灰徽「否则」绝不渲代码)+edit 旧梯 40% 垫底+落定 RunStatBar ⑤**ApprovalStage**:信笺纸质卡({{ CEL }} 流中凝**琥珀**插值药囊,散文判别式混排)+timeout 人话三向(30d 后自动拒绝/通过/置失败,空=永不超时)+allowReason 虚线栏+「预览·尚未寄出」幽灵章+落定复用 B2 表单预览(预演帧) ⑥**TriggerStage**:kind 未闭合=AnRadarSweep+等待回执→kind 闭合换四脸(逐字复用 B2 `triggerConfigFaces`)+sensor 判别式专场(condition/output AnCelGrow)+**R-16 落定事实只从 GET**(listening 点/nextFireAt 人话/refCount,绝不信帧) ⑦registry 补满 6/13+demo 第三幕(create_workflow 7 ops 流) | **✅ 集成电池 4 条**(wf 闭合计数+抽屉/control 梯级全文法含双幽灵+否则徽/approval 药囊+人话/trigger R-16 帧假 GET 真专测)+**分镜 b 真机逐帧**:首节点落点(1 nodes·0 edges)/全流水线 pull→fix_tz→rollup→gate+判别式抽屉(rows←fix_tz.result 药囊)/落定三卡三行(v1 徽+Cast 登顶)。**W3 尾巴(归 W4/W7)**:dagre 增量布局+fitView 跟拍+FLIP 三相/水脉闪真连线/update_node 脉冲/webhook·fsnotify 脸的 stage 级增强/nextFireAt 分钟活 tick |
| **W4 执行族 ✅ 主体已落(2026-07-08)** | ①todo 契约+缝:`core/contract/todo.dart`(TodoEntry/ConversationTodos 整表语义)+`getTodos`(接口/Live/Fixture+`emitTodos` 脚本钩)+`rundownProvider`(durable todo 帧**整表替换**直 patch[绝不过 CoalescingNotifier]+GET 水化,按 subagentId 分板) ②`AnTaskRing`(completed/total 补弧,全满 ok 收束绝不彩带)+`AnRundownList`(pending 空圈/in_progress activeForm 进行时+accent 实点/completed 勾+划线灰沉;整表替换不搞逐行动画机器)+接进 StagePanel 舞台下沿(有板才现,多板各带微标题) ③**reducer O(1) 尾指针**(§5-8:`BlockNode.lastDescendant`,_bump 祖先链顺路维护)——「当前动作」零遍历 ④**SubagentStage**:单席=任务名(args description)+当前动作(尾指针投影:reasoning 低语/tool 动词行/text 尾行)+紧凑 ReAct 尾 6 块(E3 轨迹摊平 message 包装);**群像**=≥2 live 分身等高卡(名+动作 shimmer+3 行尾),点 peer 卡=pin 换台;close 结算(勾叉+tokens AnCountUp+非 end_turn 止因如实) ⑤**R-10 LifecycleSource**:`stageRouteOf` 带 lifecycle,`trigger_workflow`=poll 型——**202 close 绝不谢幕**(驻留到收场/挤台),director close 分支按型处理 ⑥demo 分镜 c 幕(双分身并行嵌套流+todo 三帧演进) | **✅ 电池 4 条**(rundown 整表替换+子板/subagent 单席轨迹+结算/群像点卡 pin 换台/R-10 poll 永不谢幕专测)+**分镜 c 真机逐帧**:群像双卡+当前动作+频道 tab+Rundown 0/2 activeForm→结算 2/2 全勾+workflow 接场。**W4 尾巴(记账)**:整页终端升页交互(fill 模式已备,归 W7)/flowrun tick 覆层(需 entities 流+后端终态帧,随 W6 后端批)/R-14 transcript 锚谢幕(W6)/AnEnsembleGrid 提炼 kit 原语(W7) |
| **W5 长尾 ✅ 主体已落(2026-07-08)** | ①**HandlerStage**(方法架):竖向生命周期轨(init▸methods▸shutdown 点亮段)+add_method 上架书脊(名 w400+streaming 波浪+timeout 钟)+body 小活窗续长——**W0 带路径通道让同名 `body` 各归其位**(二号方法流中绝不串进一号书脊)+initArgsSchema 预览(sensitive 恒 ••••)+落定 configState/runtimeState 双徽+RunStatBar;无 match 判别式(契约如此,勿设想) ②**AgentStage**(装配台,R-9 渐进开区):prompt 散文中央窗(词尾)/args 未提及的槽以 **40% 墨保留旧真相**(prompt 走 AnLayerDiff vN 出处签、旧腰带 Opacity 0.4)——「AI 只动了这些」一眼可读;ToolRef 腰带扣(线缆形={ref,name},名优先 ref 兜底)+knowledge 芯片+modelOverride 翻牌;mount-health 灯归实体页档(蓝图既定非欠账) ③**SkillStage**(装订台):slug mono 铭牌+context inline|fork 徽+allowedTools **琥珀细边**药丸(预授权=权力让渡必须可见)+「仅人可唤」微章+body 散文 `$ARGUMENTS`/`$1`/`${…}` 占位凝 accent 空槽 ④**MemoryStage**(记忆笺):便笺卡+slug 笺角+content 逐词长满;**图钉 REST-only 舞台零 pin 控件**(「AI 动不了你的图钉」) ⑤**McpStage**(接线现场):铭牌+env **键名**药丸(值恒 ••••)+安装 progress 终端尾+落定**工具货架**(「N 个工具已发现」AnCountUp+逐行)+失败如实 lastError ⑥`_subjectName` 修深度盲抓(改顶层 `closedStringAt(['name'])??inFlightStringAt(['name'])`,不再误吞 agent 嵌套 tools[0].name)+registry 补满 **12/13**+demo ACT 2.8(write_memory 记忆笺幕+touchpoint 落账) | **✅ 电池 5 条**(handler 同名 body 路径隔离+settle 双徽/agent R-9 旧地层+新腰带扣/skill 琥珀+占位槽+仅人可唤/memory 笺角+内容/mcp 键显值掩+货架计数)+**真机双帧**(burst 逐帧截):live 帧=Live 徽+「Listening live」诚实缎带+笺上内容恰断在第二 delta 处+Cast 尚无 retry-policy;settled 帧=Settled 徽+全文静置+Cast `retry-policy·Created` 登顶带主角脉冲(R-6)。**type-scale 守卫抓获裸 fontSize:15→AnText.mono 归轨**(mono id 恒 13 档,系统故意压 15 词一级)。**W5 尾巴(归 W6)**:attachment 展品座——附件无建造工具入口(从 composer 进、不走 director tool-open 径),须随 W6「跳到发生处」/Cast 点行登台(exhibit mode)一并建 |
| **W6 导航 ✅ 主体已落(2026-07-08)** | **✅ 后端批**(§13-1 契约逐项,make verify 绿+docs 0 警):①orm `PageTimeAsc`(时间键升序第三 keyset 路径,同支点游标喂 Page=旧半/喂它=新半,支点不落两半)②`?around=`(窗 envelope `{data,targetId,olderCursor?,newerCursor?,hasOlder,hasNewer}`,limit 摊两半钳≥2,身份锚点 404 MESSAGE_NOT_FOUND,around×cursor×dir 互斥 400)+`?dir=newer`(store ASC→app 反转,线缆恒 newest-first)③`GET /{id}/anchors`(lean 扫描[tool_result/progress/assistant 散文永不读盘]+buildAnchors 六 kind[user 首行节选/tools 折叠簇 count·人类内容硬边界/danger/compaction/abnormal/gate broker 活状态只骑首页顶]+内存 keyset)④P1-b durable `run_terminal`(三终态四发点:markRunTerminal+kill+replace)⑤P2-c tick 带 `port`(control emit 时 __port;approval 已决 tick 由 decide/timeout 径专发 `emitApprovalDecided`——Advance 重入不 tick 既存行,读盘 record-once 行)⑥P1-e 后端本就序列化 block createdAt——缺口纯前端 DTO。测:orm×2+store×4+chatapp×3(锚分类学/节选边界/分页)+scheduler×2(port tick+durable 终态)+bootstrap HTTP e2e×1;文档 api/events/messages/chat/control/approval/orm/scheduler-flowrun 八处 1:1。**🔨 前端半待建**(§13-2):契约层(ChatBlock.createdAt+窗/锚 DTO)+transcriptJump re-anchor+场次条 drawer+Cast 双动作+exhibit mode+R-14 | 跳转不夺视口验收+后端 verify 绿 ✅ |
| **W7 polish ✅ 主体已落(2026-07-08)** | ①**跟随三档接线**:`followModeProvider` 持久化(`fy.stage.follow`,壳同款先默认后异步恢复)+侧幕头带 `_FollowMenu`(眼形钮+AnMenu 三档带勾;settings 模块[路线⑤]读同一 provider,面板落位随它) ②**R-15 activityBit**:`AnShell.rightActivity` 新 prop(panel-right 钮柔 accent 点)+AppShell 以 `stageDirectorProvider.select(channels.any(live))` 点亮——收起只留活动位 ③**R-10 退役**:`StageDirector.onRunTerminal`(净→停拍谢幕/败→红纱/早于回执或非 poll 一律 no-op)+宿主 poll 记账(工具名留 open/workflowId 解关帧 args/flowrunId 解入队回执)+`workflowFrames` repo 缝(Live=entities scope 订阅/Fixture=emitWorkflowFrame 钩)——**按 flowrunId 匹配 durable `run_terminal`,别的 run 终态不落定本台** ④**AnCurtainCall-lite**:干净落定的主角 Cast 行落账洗亮(accentSoft ~1.8s easeOut 衰减,reduced 直落终态;完整飞入行编舞记为奢侈项) ⑤**a11y 章**:四播报(`SemanticsService.sendAnnouncement` polite:登台/人闸/失败/落定)+live 流式区 `ExcludeSemantics`(播报+落定真相载义)+循环动效 PulseClock reduced 冻结既有 ⑥**i18n 专项审查**:侧幕全面(stages/panel/exhibit/toc/cast)零硬编码人类文案(仅符号/数据字面量);富 tooltip 裁决=semanticLabel 全覆盖、`AnTooltip` 原语归 kit 批(不用裸 Flutter Tooltip 破视觉一致) | **✅ 测 6 条**(director 终态 3:净落定谢幕/败红纱/早到+非 poll no-op;host e2e:202 驻留→错 flowrunId 不动→对的终态停拍谢幕;三档持久恢复+写穿;洗亮出现+衰减)+fe-verify 全绿 **2604**。**真机**:三档菜单帧(Auto-staging/Never/First/Every time✓)+收起态活动点帧(panel-right 蓝点)+doc live 舞台回归帧;洗亮由组测钉死(渲染与已真机验证的跳转洗亮同源)。**奢侈项清单**(非欠账,按需另立工单)→ [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md) §7 |

---

## 11. 测试与验收

- **五电池**(每件新原语):空/超长/海量/极值/注入。
- **抢镜电池**(独立入 fe-verify,一票否决门禁):用户滚动/交互后任意帧不得自动换台、不得夺焦点、不得夺视口;舞台展开前后后台层可见内容零位移。
- **perf 电池**:1MB content 流入、50 op/秒、5000 词 prompt、3 subagent 并行、千条触点滚动——timeline UI/raster <16ms。
- **诚实电池**:断线中途重连(哨兵冻结)、close 前 args 与 GET 真相不符(对账修正)、失败/取消(red-hold 驻留+「真相仍是 vN」)、deleted 实体(墓碑不 GET)。
- **a11y 章**(独立验收):全交互件键盘可达(Cast 行动作 focus 常显);流式区 ExcludeSemantics;登台/人闸/失败/落定四事件 SemanticsService.announce;循环动效受 disableAnimations+Following OFF 双闸;细点击目标 ≥24px;WCAG 2.2.2(>5s 自动动画可暂停)。
- **回归**:transcript 共用改动(尾指针/createdAt/RefPill→toolNavTo)必须跑满 chat 现有矩阵。

## 12. 拍板记录(2026-07-08,全部已定)

1. **自动登台默认「每次」**(settings 三档保留可调)。
2. **~~480px 全页宽档~~ → 右岛全域可拖宽(用户 0708 二次拍板,已落地)**:右岛基建改为与左岛同款用户拖调(280–640 默认 320,`fy.side.rightw` 持久化,拖拽实时钳到「海洋保底」动态上限;workflow 编辑页局部检查器同吃一份宽)——**宽度自主权全交用户,舞台升全页不再做程序化展宽动画**;480 动画宽档方案作废。真机验证:拖宽 320→460+重启恢复。
3. **后端放行**:场次条不降级——`messages?around=` 与 anchors 端点在 W6 按后端纪律正式建,场次条直上真解;flowrun 终态帧/tick 捎带 __port/BlockNode createdAt 同样从兜底升级为正式建(R-10/R-11 的惰性 GET 与 poll 兜底仅作为端点落地前的过渡)。
4. **13 座舞台同一标准、零分层**:W2–W5 只是施工顺序(先建风险最大的引擎:W2 文本双引擎 fn+document → W3 图引擎),不是质量等级——每座都走 gallery-first → 对抗复审 → 真机逐帧截图。

## 13. W6 施工契约(2026-07-08 定稿,三路调研合成:后端读码+前端读码+业界一手规范)

### 13-1 后端批(同提交守 N/D/E/S/T+文档 1:1+make verify)

- **around 开窗**:`GET /api/v1/conversations/{id}/messages?around=<messageId>&limit=`——`around` 与 `cursor` **互斥**(同给=400 `INVALID_REQUEST`,契约逐字钉死,Discord 句式);limit 作用于目标前后之和(Matrix 语义,目标恒返回);目标不存在/不属本对话=404 `MESSAGE_NOT_FOUND`(身份锚点派,非 Discord 位置语义——我们的锚 id 全来自转录内引用)。响应=bespoke 双向坐标(顶层,绝不进 data):`{"data":[newest-first],"targetId","olderCursor","newerCursor","hasOlder","hasNewer"}`——续翻**不自铸协议**:olderCursor 喂回既有 `?cursor=`(向旧),newerCursor 喂 `?cursor=&dir=newer`(list 端点新加方向参数;wire 排序恒 newest-first 单一规则,避开 Matrix 前后数组反向陷阱;store 层 ASC 取再反转,orm 无时间 ASC 键集→手写 store 查询)。
- **anchors 场次目录**:`GET /api/v1/conversations/{id}/anchors`(ChatHandler 家——**待决人闸只活在内存 broker 无表**,必须 chatapp 合流);N4 keyset(?cursor&limit,newest-first)。锚点单位(业界收敛+蓝图):`user`(首行节选)/`gate`(broker.Pending 待决人闸)/`danger`(tool_call attrs.$.danger='dangerous')/`compaction`(块型)/`abnormal`(messages.status∈{error,cancelled} 或异常 stop_reason)/`tools`(**连续机器动作折叠簇**,Linear 式「相似+连续才并、人类内容是硬边界」,行带 count)。行形:`{kind,messageId,blockId?,title,count?,at}`。单用户本地库:store 一次 lean 扫描(messages+blocks 投影)→app 层建锚→内存键集分页。
- **P1-b flowrun 终态 durable 帧**:`markRunTerminal` 三终态(completed/failed/cancelled)都发 entities 流 `Signal{Ephemeral:false}`(入 seq+replay ring;今天只有 failed 落通知收件箱行,completed/cancelled 仅 DB 列)。
- **P2-c tick 捎带 port**:control 节点 `row.Result["__port"]` emit 时已在手——`emitNodeProgress` 穿 row、tick payload 加 `port`;**approval 节点 parked 时决策不存在且决断后无 tick**——在 DecideApproval/ResolveParkedNode 径补终决 emit(带 port)。
- **P1-e 已满足零改**:block `createdAt` 后端本就落列+序列化,缺口在前端 DTO(见 13-2)。
- 错误码全复用零新增;docs 触发面:api.md(conversation 表)+events.md(tick payload/终态帧/producer 注册)+domains/{chat,conversation,messages,control,approval}+foundation/scheduler-flowrun.md。

### 13-2 前端批(围 around/anchors 消费)

- **契约层**:`ChatBlock.createdAt`(P1-e 补齐)+around 窗 DTO+anchors DTO+repo 方法(Live/Fixture)+`dir=newer`。
- **transcriptJump=「re-anchor 重锚」零依赖包**(调研裁决:super_sliver_list 与 center+anchor **架构级不兼容**[#59+维护者亲判],scrollable_positioned_list 宿主仓 2025-10 已归档;Stream/FluffyChat/Flyer 全部收敛同一形):近跳(目标已加载)=`Scrollable.ensureVisible`;深跳=拉 around 窗→**丢弃当前窗、以目标为新 center sliver 首项重建**(目标天然落 anchor 位、零 extent 估算;更旧进上 sliver 反向生长、更新进下 sliver 正向生长,双向续翻沿用 prepend 零位移)→帧后对齐+高亮(落定后 1s hold+1s fade,Stream 对标 Slack permalink)。**替换而非缝合**——现 `prependOlder` 盲插无去重,disjoint 窗缝合必重复/断层,窗口模式绕开它。跳走后「回到现场」pill(Discord Jump to Present 形);用户抢滚=框架内建作废 animateTo;reduce-motion/超远改瞬跳;贴底跟随退出/重咬常数照 use-stick-to-bottom(上向即退/≤70px 重咬)。
- **场次条 drawer**:目录钮进 `ChatHead`(浮层头,非右岛头);drawer 基座=`AnMenu`/`AnPopover`(AnMenuSection 五组:待决人闸[琥珀置顶]>危险工具>user 回合>compaction>异常终态;`tools` 簇=「⚙ N 项操作」一行);点锚=transcriptJump+抽屉自收。
- **Cast 行动作**:`lastMessageId` 经 `CastEntity.primary` 已可达但 UI 从未消费——行尾 focus/hover 常显两动作「跳到发生处」(''=藏)+「去实体页」(`toolNavTo`+`hasPanelFor` 藏规则);窄行分级降显续用。
- **exhibit mode(展品座)**:**独立 `exhibitProvider`,绝不合成 director activity**(StageScene.session/node/state 非空必填、StageActivity 只能由 tool_call open 产生——代码现实);StagePanel 优先渲 exhibit;实体 kind 用 stage_truth 8 provider GET 陈列,attachment=`getAttachment/getAttachmentBytes` 静物卡(美术馆开灯 opacity 0→1+scale 0.97→1);Cast 点行=设 exhibit。
- **R-14 群像谢幕**:Subagent(role 式,台账无影)谢幕由 transcript 锚承接——tool_call 块 id durable,谢幕=transcriptJump 到块+高亮;invoke_agent(有 Cast 行)照旧 Cast 谢幕,两径分开写。
- 验收:**跳转不夺视口**(流式期间深跳/近跳,新帧不得拽底)+后端 verify 绿+四电池+真机逐帧。
