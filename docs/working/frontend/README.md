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
| **Phase 4.2 Chat** | 🔨 在建 | **纯聊天骨干完整体已落**(rail + 中心海洋 transcript/composer/浮层头 + 自动命名 + @提及 + 附件三入口);**tool 卡 V3a–V3c 已落**(底盘 + 机器窗口 + shell·fs·builds 皮肤,WRK-053);**完美态蓝图已拍板 + B1 人闸全落**(2026-07-06:113 工具逐个设计 + 50 新原语,WRK-056 + 底册 WRK-057;**B1「人闸」F16 全族已建**——AnIcons 精确表 / ToolReceipt tone / pendingInteractionsProvider 三源合一 / ToolInteractionGate 人闸原语 / V6 危险门接底盘 / ask_user / decide_approval / list_approval_inbox,1747 测绿;**下一批 B2 builds 旗舰**);V5 特殊块/V8 右岛另计 | [`chat.md`](chat.md) · [`tool-cards.md`](tool-cards.md) · [`tool-card-blueprints.md`](tool-card-blueprints.md) |
| **实体页雕琢 + 实体可视化** | 🔨 在建 | 逐实体 ideal 实体页;**function F1–F2 已落**(变换盒 hero + 代码渐隐 + 环境合卡 + meta 就地编辑 + 版本 tab,F3 暂缓);**workflow 站 W1–W5 全落**(图地基/页面/活运行/驾驶舱/编辑器) | [`entity-pages.md`](entity-pages.md) · [`workflow-page.md`](workflow-page.md) |
| **Notifications(通知中心 + toast)** | 🔨 在建 | 左岛铃托盘(两段式:待你处理 + 通知流)+ 右上悬浮 toast + OS 原生通知。**N0 后端分径**(Emit 落行/Broadcast 仅帧,mcp 补 status)· **N1 契约数据缝**(DTO/Repository/Signal/unreadCount)· **N2 托盘**(N2a 后端补实体名 + N2b 行原语·文案 + N2c 两段式托盘接壳,真壳 E2E 亲验)**已全落**;**N3 toast / N4 OS 通知 / N5 组装** 待建 | [`notifications.md`](notifications.md) |
| **Phase 4.3 Scheduler** | ⏳ | 调度海洋(占位「即将推出」) | — |
| **Phase 4.4 Documents** | ⏳ | 文档海洋(占位) | — |

### 3.2 当前焦点 + 下一步

- **现在**:**Notifications 模块**([`notifications.md`](notifications.md),WRK-058)——调研(10 agent 全对抗验证)+ 四拍板已定,按阶梯 N0(后端分径)→ N1(契约缝)→ N2(托盘)→ N3(toast 右上)→ N4(OS 通知)→ N5(组装)建。
- **随后**:function F3 收尾(右岛按签名渲结果 + hero 活态)→ 逐个聊下一实体。
- **chat 尾巴**:V5 特殊块 · V8 右岛(后端 touchpoint 台账已就绪)。
- **远期弧线**:Chat/实体全成 → Scheduler 4.3 → Documents 4.4。

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
