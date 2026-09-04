---
id: DOC-048
type: reference
status: active
owner: @weilin
created: 2026-06-30
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Feature：Entities（实体海洋）——当前形态

> 本篇描述 `frontend/lib/features/entities/` 的当前产品投影。DTO 见 [`contract.md`](../contract.md)，各实体契约从 [`function.md`](../../backend/domains/function.md)、[`handler.md`](../../backend/domains/handler.md)、[`agent.md`](../../backend/domains/agent.md)、[`workflow.md`](../../backend/domains/workflow.md)、[`control.md`](../../backend/domains/control.md)、[`approval.md`](../../backend/domains/approval.md) 与 [`trigger.md`](../../backend/domains/trigger.md) 进入；运行真相见 [`scheduler-flowrun.md`](../../backend/foundation/scheduler-flowrun.md)。

## 1. 产品面

| 面 | 当前事实 |
|---|---|
| 总览 | `/` 与 `/entities` 展示实体计数、关系图和最近更新；关系图可进入 `/entities/graph` 全屏探索。探索页默认只显示结构关系，图例隐藏某类实体时同步隐藏其节点、标签和相连边；打开显示溯源后，右岛会按“创建于/编辑于”或“创建/编辑”解释会话与实体的方向关系；涟漪只降低点/边的视觉优先级，不降低仍存在的实体名称可读性 |
| 左岛 rail | Function、Handler、Agent、Workflow 与 Control、Approval、Trigger 七类；过滤、排序、计数、分页与 lifecycle signal 更新；Handler 的懒启动/调用收尾也会重读列表投影，保证运行态点不落后于详情；搜索无匹配时明确显示空结果提示，不把空白误作加载失败 |
| 中心详情 | `/entities/:kind/:id`；同一阅读列承载头、概览、版本与日志/运行。Trigger 使用活动/派发观测面 |
| 右岛调试台 | 对可执行实体提供 JSON-first 输入、示例、最近输入复用、实时执行流、停止与结果；是手工执行的唯一入口 |
| Workflow 图 | 概览显示当前图、节点/边计数和活态覆层；`/entities/workflow/:id/editor` 提供全屏图编辑、节点/边 inspector 与一次会话一版；新增节点先固化当前可见布局，再放入带安全间距的第一个空位，避免叠卡或把旧节点挪走；全屏工具栏的保存反馈落在工具栏下方，不遮挡 `Discard`/`Save` |
| Workflow 治理 | 概览治理卡可直接选择五种并发策略（串行、运行时跳过、仅保留最新、替换当前、全部并行）；选择走 Workflow meta PATCH，不创建新版本 |
| Workflow 运行 | 运行驾驶舱展示 run 列表、节点甘特、图覆层、ledger、approval、replay 与 kill；深链到 Scheduler run 卷宗 |
| 审批收件箱 | 跨 run 汇总 parked approval，复用同一个 first-wins `:decide` 契约；打开期间订阅耐久 `workflow.approval_pending` 与 workflow scope 的 `run_terminal` 脉冲，并从 `GET /flowrun-inbox` 重取真实列表；notifications/entities 任一 410 都重取，不能要求用户关闭再打开托盘 |

## 2. 数据边界

- `EntityRepository` 是唯一数据缝；`LiveEntityRepository` 接 HTTP/SSE，`FixtureEntityRepository` 驱动 demo 与测试。
- 选中实体单向派生自 URL；切实体时整页以 last-known-good 换代，头、tab 与正文不会分别显示不同实体。
- Function、Handler、Agent、Workflow 是版本化可执行实体；Control、Approval 是版本化支撑实体，复用同一版本历史/差异面但没有执行台；Trigger 是唯一无版本支撑实体，不能被硬塞进通用版本 tab。
- rail 上的无参生命周期动作（Workflow 上线/下线、Trigger 暂停/恢复、Handler 重启）失败时保留服务端的可行动原因；Workflow `WORKFLOW_NOT_RUNNABLE` 还展示结构化问题的首条，不能把“图不可运行”压成没有下一步的泛化「操作失败」。非 API/传输异常仍使用通用兜底。
- meta 修改不升版本；workflow 图 `:edit` 以一次编辑会话的一组 ops 生成一个新版本；`:revert` 只移动 active 指针。
- 版本页执行 `:revert` 后，Handler 的详情与 resident 状态必须重读，Versions 页就地重算 active 标记；若右岛已有已落定的运行结果，版本指针改变后清掉这份瞬时结果但保留方法/来源选择与 Recent 审计，禁止把旧版本输出挂在新版本标题下。失败只显示具体错误，active 指针和既有结果不伪造改变。
- Function/Handler/Workflow 的说明、标签和标题编辑都按异步 PATCH 的结果收口：请求未完成时不宣称已保存，失败保留可修正草稿、显示错误并重读后端真相；说明/标签失败必须说说明/标签，不得误称成名称失败；禁止把乐观本地标题当成已落盘实体名。Workflow 的并发策略也走同一条 meta PATCH，五种策略必须在界面上可发现并解释运行语义，且不升版本；Handler 的 PATCH 不升版本、不重启常驻实例。
- 版本内容只读；前端不提供手写签名、代码或依赖的旁路。
- flowrun 与节点行是运行真相。SSE tick 负责可见实时，终态仍以重取后的 durable 行裁决。
- rail 的普通空名册保留完整结构；只有输入了搜索词且没有任何可见行时，才显示本地化的「无匹配」提示。

## 3. 详情与执行

- Function：说明、标签、代码、输入/输出、环境与执行日志。`envStatus=failed` 时页头与 Environment 卡都要显式显示失败；主面展示本地化的构建失败摘要、原因与下一步，原始 `envError` 只在用户主动展开的技术详情中显示并受长度上限约束，不能把 SDK、URL 或堆栈异常当作主文案。
- Handler：说明/标签 meta 就地编辑、方法、实例/config 状态、版本、调用日志与 restart/config 写面；meta PATCH 不升版本、不重启常驻实例。概览必须把三种正交状态分开：`runtimeState`（实例是否运行）、`configState`（初始化参数是否齐全）和 active version 的 `envStatus`（运行环境是否构建成功）；`envStatus=failed` 时页头与 Environment 卡都要显式显示失败，并以本地化的构建失败摘要、原因与下一步呈现，不能用 `stopped` 或 `ready` 掩盖环境失败。原始 `envError` 只在用户主动展开的技术详情中显示，并受长度上限约束；主产品面不得直接暴露 SDK、URL 或堆栈异常。
- Handler 首次 `:call` 可能懒起常驻实例；调用成功或失败收尾后，详情与 rail 列表都必须重读服务端 `runtimeState`，不能让概览或 rail 继续显示旧的 `stopped`。
- Agent：定义、版本、执行日志与流式 block tree。
- Workflow：图、治理信息、版本 diff、运行驾驶舱与全屏图编辑器。运行信息把“运行周期”（首次启动到最终落定的墙钟生命周期）与“执行耗时”（`GET /flowruns/{id}/activity` 的执行审计汇总）分开；replay 保留历史尝试时，执行耗时可以包含多次实际执行，但不把人工等待伪装成执行时间。节点调试优先显示对应审计行的测量，只有审计缺席才回落到节点自身的开始/结束戳。
- Control：输入与分支/端口规则；版本 tab 展示分页历史、路由行为 diff 和 active 标记。
- Approval：审批模板与规则、版本 tab；运行期决定发生在具体 parked node。
- Trigger：cron/webhook/fsnotify/sensor 等配置、listener 状态、activation 与 firing 两条观测流，并支持手动 fire。Activity/Dispatch 的筛选器使用紧凑 ghost 控件，避免把列表过滤误读成可编辑字段。Webhook 概览必须同时说明挂载 URL 与认证携带方式：HMAC 显示算法/签名头，明文 secret 显示 `X-Webhook-Secret` 请求头或 `?token=` 查询参数，但永不回显 secret 本身。
- Trigger 暂停时详情头仍保留 `Fire` 的空间位置，但按钮必须 inert，徽标显示 `Paused`，hover/focus 提示先恢复再催发；后端 `TRIGGER_PAUSED` 仍是最终防线。
- Trigger 的 Dispatch 首次读取允许短暂显示 `pending`：firing 先落 durable 行，再由 scheduler 决定 `started`、`skipped`、`superseded`、`shed` 或 `missed`。只要当前页仍有 pending，前端每 500ms 重读同一 REST 页并替换现有行；全部行进入终态后立即停止，不能让用户离开再回来才能看到真实处置。筛选暴露全部用户可理解的处置词，`claimed` 只作为瞬态认领阶段留在全量/机器真相里，不作为停留筛选；`missed` 是持久错过台账，必须可直接筛选，且列表行使用 slang 双语词而不是裸 wire 枚举。列表主行使用 API 读时补全的 workflow 名，详情同时保留独立的 workflow ID；workflow 已删除时才回落裸 ID，避免首屏先闪出机器 ID 再跳名。
- Trigger 详情打开期间收到本 trigger scope 的 `seq=0` `fire` 信号时，必须把它当作**重读提示**而不是第二份历史：详情重取 `GET /triggers/{id}` 以更新 `Last fired`，Activity 与 Dispatch 的**所有已挂载筛选实例**各自订阅 fire 脉冲并从 REST 端点重取。首次重读若仍处于 scheduler 写入窗口，两个列表都在最多 5 秒内按 500ms 继续重读；一旦页内容改变或窗口耗尽即停止，持续可见的 `pending` 再交给原有 pending poll。Trigger 的 `listening` 是 active workflow 绑定的读时派生值，因此已打开的 trigger 详情与 rail 还必须在 workflow durable lifecycle signal 后重读；否则最后一个 workflow 下线后会留下陈旧的 `Listening`。信号 payload 只用于唤醒，不得直接 patch `lastFiredAt`、firing 状态或计数；这样外部 webhook 在详情页到达时，即使当前终态筛选页原本为空，也会从 durable 真相收敛，而不要求用户离开再回来。

日志列表页保持轻量：列表行不携带可能达到 64 KiB 的 `logs`，也不携带 Agent 的完整 `transcript`。
用户展开 Function execution、Handler call 或 Agent execution 时，分别请求对应的单条端点；展开期间显示骨架，
失败显示原始服务端解释与重试，成功后在同一行展示完整的 input/output/error/timing。Agent 的 durable transcript
经共享 `hydrateTranscriptTree` 水合，复用调试台的 `BlockTreeView` 显示嵌套 reasoning/text/tool-call/tool-result
轨迹；列表页的轻量投影不能冒充“没有日志”，详情请求失败也不能静默留白。

实体 rail 的删除确认必须说明对象会从当前目录移除且不可撤销；确认前对所有实体刷新
`GET /api/v1/relgraph`，列出入向 `equip/link` 使用者（最多显示三个名称并汇总剩余数量）；关系快照读失败时
不继续执行删除。确认后才调用统一 `DELETE`，列表按 durable `deleted` 信号对账，打开中的详情回到实体首页。
删除不会因入向关系阻塞，后端清边并保留适用的历史/审计事实；前端不得用含糊的“已删除”成功文案掩盖软删与后续不可用状态。
Trigger 的确认框是更严格的专用预检：在通用依赖影响说明之外，listener 热时明确说明删除会停止监听。
这样用户在确认前能知道受影响的实体，删除后的 `trigger.deleted` 与
`relation.dependency_broken` 仍由 durable 流和 REST 真相收口。

调试台始终展示一份可直接修改和运行的 JSON。schema 示例优先使用 example/default/enum，缺失时生成类型骨架；workflow 按触发源生成点火 payload。编辑器的可见文本、session 草稿、实时 JSON lint 和 Run CTA 必须共享同一份当前文本：非法 JSON 立即显示可解释的红色错误并禁用 Run，禁止把旧草稿静默送入 HTTP；只有合法对象才进入 `:run`。无执行历史时不制造 Idle 墓碑，只有真实结果、错误或在飞状态才出现。

运行失败时，右岛保留错误码与服务端 message，并在有结构化 `details` 时以人类可读的键值代码区展示；多行 traceback 保留真实换行，正文有硬上限，不能只显示一个泛化“调用失败”或把 `\\n` 转义串直接交给用户。执行日志仍从同一调用审计事实读取，成功与失败都必须可在最近调用条和 Logs 面重查。

实体面板的 `entities` 流是执行过程的观察线，不是执行历史的第二份真相。收到可重放的
`close` 帧后，右岛以短去抖重取对应执行账本；因此 REST、Chat 或 Workflow 入口在另一个
表面落账的运行也会进入「最近」与速览计数。若右岛正在显示旧的落定结果，新的顶层 run
block 会先切换成独立的 observed run，终态再从执行账本收口；不会把旧结果卡与新 trace 混在
同一面板里，也不会从流式帧自行拼出历史或猜测总数。

Workflow 详情的 Runs 驾驶舱也订阅本 workflow scope 的 `entities` 流：durable
`run_started`/`run_terminal` 只作为重读当前可见 flowrun 窗口和选中 composite 的提示，行与节点
仍由 REST 台账提供。`seq=0` 的节点 tick、trigger fire 和未知面板帧不改变历史；重读去抖 120ms，
保留用户当前选中的 run/node，只有选中 run 自己的生命周期帧才重取它的完整节点。这样一个保持打开
的 Runs 页会在真实 run 落账后自行从空态收敛，而不是要求用户离开再回来。

Logs 档案面也订阅同一实体 scope：收到 durable `close` 后短去抖重取当前已加载窗口与聚合，
不会把运行中的 delta 当成历史，也不会用缓存的旧计数盖住新落账。重取沿用最近可信快照，
保留仍在当前窗口内的展开行；若网络瞬时失败，原有行继续可读，用户可用显式重试恢复。

## 4. 关键不变量

1. URL 是实体与关系图选区的唯一事实源。
2. 前端不重算后端实体状态、调度规则或 workflow 执行语义。
3. workflow 运行图必须使用该 flowrun 钉住的版本；版本不可解析时诚实降级，不能拿当前图冒充历史。
4. approval first-wins；迟到决定必须对账服务器赢家。
5. replay 只用于失败 run，kill 是硬停止；两者不能在 UI 中互换语义。
6. workflow 编辑器的 ref 与 control/approval 端口来自 repository 候选，不靠自由文本猜 wire 值。
7. 关系图默认只呈现结构关系；conversation provenance 由用户显式开启，且开启后选中任一会话或实体都必须在右岛说明其 create/edit 关系，不能只在画布上画线。

## 5. 验证入口

- feature 测试：`frontend/test/features/entities/`
- 图与运行纯模型：`frontend/test/core/graph/`、`frontend/test/core/run/`
- 路由与壳：`frontend/test/core/router/`、`frontend/test/core/shell/`
- 产品黑盒：`testend/scenarios/` 中 entity、workflow、trigger、flowrun、approval 场景
- 人眼验收：`make -C frontend demo` 或 `make -C frontend app`
