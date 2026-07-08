---
id: WRK-049
type: working
status: active
owner: @weilin
created: 2026-06-30
reviewed: 2026-06-30
review-due: 2026-09-28
audience: [human, ai]
---

# 前端 working hub —— one-stop:背景 · 怎么协作 · 到哪了/去哪走

> **本页是前端的中央仪表盘**,三件事一站给齐:
> ① **想快速懂这是什么、长什么样** → 读 [`references/frontend/overview.md`](../../references/frontend/overview.md)(鸟瞰,不用翻代码)。
> ② **想知道我们怎么一起干**(你调研、必 gallery、在哪拍板)→ 读本页 **§2 协作规范**。
> ③ **想知道有什么、到哪了、下一步** → 读本页 **§3 进展 · 路线** + **§4 档案索引**。
>
> 纪律的 binding 源永远是 [`CLAUDE.md`](../../../CLAUDE.md)(每会话加载);本页是**前端可读版**,冲突以 CLAUDE.md 为准。代码级权威(原语 props / DTO 字段 / 文件路径)在 [`design-system`](../../references/frontend/design-system.md) / [`contract`](../../references/frontend/contract.md) / [`architecture`](../../references/frontend/architecture.md),本页只链不抄。**§3 进展账改任何状态 = 整体重述本节、不追加。**

---

## §1 一分钟定位

Anselm 前端 = 一个 **Flutter 桌面 app**,是内嵌 **Go sidecar** 的纯客户端(本地优先、单用户、不做 SaaS)。三岛壳 `AnShell`(左岛 rail / 中心海洋 / 右岛 inspector)+ 四海洋(chat/entities/scheduler/documents)。状态 Riverpod + 三条 SSE 流。**一切视觉由 `An*` 原语组装、禁手搓**。完整心智模型见 [`overview.md`](../../references/frontend/overview.md)。

---

## §2 协作规范(我们怎么建一个 feature)

### 2.1 总原则(一行一条;binding 全在 CLAUDE.md)

- **中文交流**——所有对话回复用中文(代码/标识符/commit 不限)。
- **复用优先、禁手搓 + 最佳实践优先**(原则#8):能复用 `pkg/*`·`core/*`·gallery 原语就复用;遇不确定**先联网查成熟方案/官方文档**,绝不一上来手搓。
- **单一事实源、状态即重述**(原则#7):项目未上线,禁维护兼容/历史演化;改状态文档 = **整体重述当前状态**、不在旧内容旁堆叠。
- **文档物理同步**(原则#9,最高优先级):改代码 → **同提交**改对应文档。文档落后 = 与编译失败同级的 Bug。
- **反校验剧场**(原则#6):只留有物理价值的校验。

### 2.2 建造流水线(7 步;每步标:做什么 / 产出 / 你在哪拍板)

> 这是 CLAUDE.md「🔁 迭代流程铁律」落到前端的可照敲序列。

| # | 步 | 做什么 | 产出 / 门 |
|---|---|---|---|
| ① | **吃透后端** | 多 agent 扇出读后端代码 + `references/backend/`,**绝不照猜后端** | 精确「集成契约」(端点/帧/DTO/错误码/SSE 语义,带 file:line) |
| ② | **查 best-practice** | 联网调研该方案怎么建好:成熟包 / 业界模式 / 已知坑(原则#8) | 方案;两段都过对抗验证 |
| ③ | **写规范** | 落 `working/frontend/<feature>.md`(集成契约 + 决策 + STEP 拆解) | → **🙋 你拍板** |
| ④ | **gallery 先行** | 原语不够 → 先进 gallery 建 `An*` specimen(视觉在 gallery 里迭代) | gallery 有件可截图;**禁手搓** |
| ⑤ | **单一作者建** | app/demo 组装接线(共用唯一壳;data→state→ui) | 编译/装配通 |
| ⑥ | **超强覆盖测** | widget 测 + **五电池**(见 2.3)入 `make fe-verify`;涉后端改动配 `testend` | 门禁全绿 |
| ⑦ | **真机验 + 收口** | 真机 Skia 截图肉眼核对(不能只靠无头测就声称完成)→ landed-into | 截图过 → 提取进 `references/frontend/features/<f>.md` + 建造文档归 `archive/` |

### 2.3 门禁与验证

- **`make fe-verify`**:codegen(freezed/json/slang)+ `flutter analyze` 净 + `flutter test` 绿。**pre-push 必过**。
- **五电池**(每个 feature 的 widget 测矩阵):**空 · 超长 · 海量 · 极值 · 注入**。
- **真机截图**(`test/dev/capture_*.dart` → Skia toImage → PNG):凡有视觉的步骤必真机核对——隔离 widget 测会漏集成/壳门控 bug(教训反复)。
- **三启动面**:`make gallery`(原语目录)· `make app`(真壳真后端)· `make demo`(真壳假数据零后端);app/demo 共用唯一 `app/app_shell.dart`。

---

## §3 进展 · 路线(活的仪表盘)

### 3.1 进展账

| 相位 | 状态 | 一句话 | 看详情 |
|---|---|---|---|
| **UI kit G0–G6** | ✅ | 49 原语 + gallery(控件/反馈/行卡/导航壳/代码数据/浮层) | [`design-system`](../../references/frontend/design-system.md) + §4 归档 |
| **Phase 4.0 运行时骨干** | ✅ | 契约/net/SSE/进程托管/Riverpod 装配/loopback/错误边界/L0–L2 流式原语 | [`overview`](../../references/frontend/overview.md) §4–5 · 归档 [`WRK-045`](../../archive/phase-4.0-runtime-backbone/README.md) |
| **Phase 4.1 Entities** | ✅ | 实体导航 + 详情海洋 + 执行右岛(STEP 0–6 + 5.5) | [`features/entities`](../../references/frontend/features/entities.md) · 归档 [`WRK-046`](../../archive/entities/README.md) |
| **Phase 4.2 Chat** | 🔨 在建 | **纯聊天骨干完整体已落**(rail + 中心海洋 transcript/composer/浮层头 + 自动命名 + @提及 + 附件三入口);**tool 卡 V3a–V3c 已落**(底盘 + 机器窗口 + shell·fs·builds 皮肤,WRK-053);**完美态蓝图已拍板 + B1 人闸全落**(2026-07-06:113 工具逐个设计 + 50 新原语,WRK-056 + 底册 WRK-057;**B1「人闸」F16 全族已建**——AnIcons 精确表 / ToolReceipt tone / pendingInteractionsProvider 三源合一 / ToolInteractionGate 人闸原语 / V6 危险门接底盘 / ask_user / decide_approval / list_approval_inbox,1747 测绿;**下一批 B2 builds 旗舰**);V5 特殊块已落;**V8 右岛「侧幕」W0–W7 全落 ✅**(WRK-061:增量 JSON 引擎+六态导演器+触点台账+12/13 kind 量身活舞台+Rundown+W6 导航[around/anchors/run_terminal+re-anchor 深跳/场次条/exhibit]+W7 polish[三档持久/activityBit/R-10 退役/落账洗亮/a11y 章];当前形态 [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md),建造史归档 [`WRK-061`](../../archive/chat-right-island/README.md)) | [`chat.md`](chat.md) · [`tool-cards.md`](tool-cards.md) · [`tool-card-blueprints.md`](tool-card-blueprints.md) |
| **实体页雕琢 + 实体可视化** | 🔨 在建 | 逐实体 ideal 实体页;**function F1–F2 已落**(变换盒 hero + 代码渐隐 + 环境合卡 + meta 就地编辑 + 版本 tab,F3 暂缓);**workflow 站 W1–W5 全落**(图地基/页面/活运行/驾驶舱/编辑器) | [`entity-pages.md`](entity-pages.md) · [`workflow-page.md`](workflow-page.md) |
| **Notifications(通知中心 + toast)** | ✅ | 左岛铃两段式托盘(待你处理 + 通知时间流)+ 右上悬浮 toast(important-only,hover 暂停)+ OS 原生通知(未聚焦时)。N0 后端分径(Emit 落行/Broadcast 仅帧)· N1 契约数据缝 · N2 托盘(后端补名字 + 行原语·文案 + 两段式接壳)· N3 toast(迁右上 + 事件→toast 派发器)· N4 OS 通知(DIP + 焦点路由)**全落**;真壳 E2E + macOS build 验证 | [`features/notifications`](../../references/frontend/features/notifications.md) · 建造账 [`notifications.md`](notifications.md) |
| **Phase 4.3 Scheduler** | ⏳ | 调度海洋(占位「即将推出」) | — |
| **Phase 4.4 Documents** | ⏳ | 文档海洋(占位) | — |

### 3.2 当前焦点 + 总路线(2026-07-08 用户拍板的执行序,逐段做完再进下一段)

> **实施纪律(用户明令)**:每段实施必须**完整端到端真机试验、AI 亲自验证**(build → 开 app → 交互 → 截图核对),不得只靠无头测试收工。

1. **① 右岛建设 ✅ 全段完工(2026-07-08)**——按归档 [`WRK-061`](../../archive/chat-right-island/README.md)(拍板全落 §12,当前形态 [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md))**W0 性能前置 ✅(2026-07-08:增量 JSON 会话引擎+argStringPartialAt+revision memoize+delta 释放+PulseClock+sticky 分桶+fill 模式+活窗全换 session;真机 profile 三床 perf 门禁全绿 0 帧超 16.7ms,顺手抓杀 argString 正则 MB 值爆栈真崩点)** → **W1 底盘 ✅ 主体已落(2026-07-08:touchpoint 契约+ledger[R-2 聚合/游标纪律/410 并入]+StageDirector 纯状态机[六态/防抖/仲裁/抢镜 VETO 11 测]+宿主[StageState 快照化,修掉可变引用吞 close 广播真 bug]+AnCastRow/AnChannelStrip/AnFollowPill/AnHonestyRibbon/AnFreshnessHalo 五原语+通用舞台+接壳+demo create_document 一幕;真机 demo 全链路截图验证:静场聚合→登台流式→落定撤丝带→谢幕→Cast 实时落行;尾巴=AnCurtainCall 完整谢幕动效/activityBit/舞台滚动占用,随 W2 动效批)** → **W2 文本双旗舰 ✅ 主体已落(2026-07-08:AnLiveCodeWindow 整行释放/AnMinimapSpine 书脊/AnLayerDiff 地层三原语+R-5 真相缝+FunctionStage[地层→中性 ticker→活窗→落定真 diff 徽]+DocumentStage[书脊+前缀快进+R-9+全量替换徽]+registry;集成电池 3+原语电池 4;真机逐帧:fn 流中全要素同框/doc 书脊流/全落定双落账;右岛已改用户拖宽基建[0708 二次拍板,480 宽档作废])** → **W3 图+判别式 ✅ 主体已落(2026-07-08:AnCelGrow 判别式药囊/AnRadarSweep 诚实等待环+四真相缝+Workflow[真画布图生长+判别式抽屉+R-5 静置旧图]/Control[丝线决策梯+透传幽灵+否则徽]/Approval[信笺+琥珀插值+timeout 人话]/Trigger[四脸复用+R-16 只信 GET] 四舞台,registry 6/13;集成电池 4;分镜 b 真机逐帧:首节点→全流水线+判别式抽屉→落定三卡三行)** → **W4 执行族 ✅ 主体已落(2026-07-08:todo 契约+rundownProvider 整表替换+AnTaskRing/AnRundownList+reducer O(1) 尾指针+SubagentStage[单席 ReAct 尾/群像点卡换台/tokens 结算]+R-10 poll 型[trigger_workflow 202 永不谢幕];电池 4;分镜 c 真机:群像双卡+Rundown 0/2→2/2 全勾)** → **W5 长尾 ✅ 主体已落(2026-07-08:Handler 方法架[W0 带路径通道同名 body 隔离]/Agent 装配台[R-9 未提及槽 40% 旧真相]/Skill 装订台[琥珀 allowedTools+$ 占位槽+仅人可唤]/Memory 记忆笺[图钉 REST-only 零 pin 控件]/Mcp 接线现场[env 键显值掩+工具货架] 五舞台,registry 12/13;电池 5;真机双帧 live 缎带+settled Cast 登顶;attachment 展品座随 W6 exhibit mode)** → **W6 导航 ✅ 主体已落(2026-07-08:后端批=orm PageTimeAsc 第三 keyset 路径+?around= 窗 envelope+?dir=newer+GET anchors 六 kind 锚[user 主锚/tools 折叠簇/danger/compaction/abnormal/gate broker 活状态]+P1-b durable run_terminal+P2-c tick 带 port[含 approval 已决专发],verify 绿+八处文档 1:1;前端批=ChatBlock.createdAt+窗/锚 DTO+transcriptJump「re-anchor」[近跳移锚/深跳整窗替换+回到现场 pill+洗亮+流式绝不夺视口]+场次条 drawer[ChatHead 目录钮+gate 置顶+⚙ 簇行]+Cast hover 双动作+exhibit mode[点行登台+attachment 展品座]+R-14 眉部回合锚;测 11 条+真机四帧)** → **W7 polish ✅(2026-07-08:跟随三档持久化+侧幕头菜单/R-15 activityBit[AnShell.rightActivity]/R-10 退役[onRunTerminal+workflowFrames 缝,poll 舞台按 flowrunId 匹配 durable run_terminal 自动落定]/AnCurtainCall-lite 落账洗亮/a11y 四播报+ExcludeSemantics/i18n 零硬编码审查;测 6+真机三帧[三档菜单/收起态活动点/doc live 回归];fe-verify 2604 绿)**。**遗留清账批 ✅(0708,用户拍板「不留账单/不花哨/流式舒服/企业级」)**:已实现=活运行卷(poll 舞台 flowrun tick 逐行+port 徽+durable 终态收卷,demo ACT 2.9)/`AnTooltip` kit 原语+侧幕全控件/nextFireAt 分钟活钟/舞台滚动=pinned/`[[id]]` 真名解析(MentionSource 单源)/subagent 内联终端活窗/场次条 560 高+fixture gate 镜像/attachment·memory kind 字形/demo 补种(64 回合长卷+附件展品座);**真机抓获真 bug**=归队不贴底(快速重拉不换 State、旧 `_pinned` 残留)→显式重钉修复+组测钉死;已裁决不做(口味一致)=词级淡入/快进滚动/飞入编舞/FLIP 节点滑移(边线脱节视感如 bug)/水脉闪加戏/update_node 脉冲/AnEnsembleGrid 提炼(原则 #8),全录 features 文档 §7。真机四帧:运行卷(四节点+→pass+Run completed)/深跳窗+Jump to present pill/归队贴底/附件展品座。**下一段=路线② chat 修复(WRK-059 剩余)**。
2. **② chat 模块修复**——[`chat-review-backlog.md`](chat-review-backlog.md)(WRK-059)剩余 confirmed:H2 六工具编目+webOutcome、M4/M7/M8/M9、L5、B4 exec-list 父名;需用户在场项(demo taste/图 1:1/native chrome/IME 签字)单列等用户。
3. **③ document 模块遗留**——删 webview 死码(core/doc_editor + tool/doc-editor + assets/editor + Makefile 目标,S22 卫生)、A6(Linux 降级验证+文档同步)、原生编辑器 polish(co-scroll 头/划选条 link 按钮)、大件后置(图片需后端图床/数学 KaTeX 离线)。
4. **④ settings 决策问答**——[`settings.md`](settings.md)(WRK-062,20-agent 调研已成:双骨架 IA + 13 面板逐项目录 + 16 硬裁决 + 后端工单 + S0–S6 切片)§8 的 20 条决策清单交用户逐条拍板 → 完善建造计划。
5. **⑤ settings 模块建造**——按拍板后的 [`settings.md`](settings.md) 完整落地。
6. **⑥ 遗留 todos 清账**——spacing P3(铺全原语+各面)、entity-pages F3(function 右岛按签名渲结果+hero 活态)、approval 配置面+收件箱(type-landscape 续)、tool-card census 快照重读、其余散项见任务表。

远期弧线不变:全部收敛 → Scheduler 4.3 海洋。

---

## §4 档案索引(建造日志,可追溯「当初怎么建的」)

> 这些是冻结的建造日志(`type: working, status: archived`),记录每相位的 STEP/决策/调研/复审。**想知道某件原语为什么这么建、某 feature 当时怎么拆的,点进去。**

| 归档 | 是什么 |
|---|---|
| [`WRK-036`](../../archive/gallery-hardening/README.md) | demo 组件库硬化(Flutter 移植的 web 事实源) |
| [`WRK-037`](../../archive/g2-feedback-states/README.md) | G2 反馈态套件 |
| [`WRK-038`](../../archive/g3-rows-cards/README.md) | G3 行与卡套件 |
| [`WRK-039`](../../archive/g4-nav-shell/README.md) | G4 导航与壳 |
| [`WRK-040`](../../archive/g5-code-data/README.md) | G5 代码与数据 |
| [`WRK-041`](../../archive/g6-overlays/README.md) | G6 浮层(Dialog + Toast) |
| [`WRK-045`](../../archive/phase-4.0-runtime-backbone/README.md) | Phase 4.0 运行时骨干 |
| [`WRK-046`](../../archive/entities/README.md) | Phase 4.1 Entities 建造日志 |

平台地基(未建相位的前瞻 backlog,**仍 working**):[`WRK-042`](../platform-foundation/README.md)(平台地基总账)· [`WRK-043`](../platform-foundation/release-distribution-playbook.md)(发行 playbook)。

---

## §5 导航地图(找什么去哪)

| 要找 | 去 |
|---|---|
| 快速理解前端(心智模型,不读代码) | [`references/frontend/overview.md`](../../references/frontend/overview.md) |
| 工程纪律(binding,N/D/E/S/T + 设计原则) | [`CLAUDE.md`](../../../CLAUDE.md) |
| 原语目录(G0–G6,props/a11y) | [`references/frontend/design-system.md`](../../references/frontend/design-system.md) |
| 物理文件图 + 路由 + 装配 | [`references/frontend/architecture.md`](../../references/frontend/architecture.md) |
| 后端线缆的 Dart 投影(DTO) | [`references/frontend/contract.md`](../../references/frontend/contract.md) |
| 某个 feature 当前是什么样 | [`references/frontend/features/`](../../references/frontend/features/) |
| 后端契约(端点/表/错误码/事件/分域) | [`references/backend/`](../../references/backend/) |
| **怎么协作 / 到哪了 / 去哪走** | **本页** |
