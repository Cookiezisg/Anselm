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
| 总览 | `/` 与 `/entities` 展示实体计数、关系图和最近更新；关系图可进入 `/entities/graph` 全屏探索 |
| 左岛 rail | Function、Handler、Agent、Workflow 与 Control、Approval、Trigger 七类；过滤、排序、计数、分页与 lifecycle signal 更新；搜索无匹配时明确显示空结果提示，不把空白误作加载失败 |
| 中心详情 | `/entities/:kind/:id`；同一阅读列承载头、概览、版本与日志/运行。Trigger 使用活动/派发观测面 |
| 右岛调试台 | 对可执行实体提供 JSON-first 输入、示例、最近输入复用、实时执行流、停止与结果；是手工执行的唯一入口 |
| Workflow 图 | 概览显示当前图和活态覆层；`/entities/workflow/:id/editor` 提供全屏图编辑、节点/边 inspector 与一次会话一版 |
| Workflow 运行 | 运行驾驶舱展示 run 列表、节点甘特、图覆层、ledger、approval、replay 与 kill；深链到 Scheduler run 卷宗 |
| 审批收件箱 | 跨 run 汇总 parked approval，复用同一个 first-wins `:decide` 契约 |

## 2. 数据边界

- `EntityRepository` 是唯一数据缝；`LiveEntityRepository` 接 HTTP/SSE，`FixtureEntityRepository` 驱动 demo 与测试。
- 选中实体单向派生自 URL；切实体时整页以 last-known-good 换代，头、tab 与正文不会分别显示不同实体。
- Function、Handler、Agent、Workflow 是版本化可执行实体；Control、Approval、Trigger 是支撑实体。Trigger 无版本，不能被硬塞进通用版本 tab。
- meta 修改不升版本；workflow 图 `:edit` 以一次编辑会话的一组 ops 生成一个新版本；`:revert` 只移动 active 指针。
- 版本页执行 `:revert` 后，Handler 的详情与 resident 状态必须重读，Versions 页就地重算 active 标记；若右岛已有已落定的运行结果，版本指针改变后清掉这份瞬时结果但保留方法/来源选择与 Recent 审计，禁止把旧版本输出挂在新版本标题下。失败只显示具体错误，active 指针和既有结果不伪造改变。
- Function/Handler/Workflow 的说明、标签和标题编辑都按异步 PATCH 的结果收口：请求未完成时不宣称已保存，失败保留可修正草稿、显示错误并重读后端真相；说明/标签失败必须说说明/标签，不得误称成名称失败；禁止把乐观本地标题当成已落盘实体名。Handler 的 PATCH 不升版本、不重启常驻实例。
- 版本内容只读；前端不提供手写签名、代码或依赖的旁路。
- flowrun 与节点行是运行真相。SSE tick 负责可见实时，终态仍以重取后的 durable 行裁决。
- rail 的普通空名册保留完整结构；只有输入了搜索词且没有任何可见行时，才显示本地化的「无匹配」提示。

## 3. 详情与执行

- Function：说明、标签、代码、输入/输出、环境与执行日志。
- Handler：说明/标签 meta 就地编辑、方法、实例/config 状态、版本、调用日志与 restart/config 写面；meta PATCH 不升版本、不重启常驻实例。
- Handler 首次 `:call` 可能懒起常驻实例；调用成功或失败收尾后，详情必须重读服务端 `runtimeState`，不能让概览继续显示旧的 `stopped`。
- Agent：定义、版本、执行日志与流式 block tree。
- Workflow：图、治理信息、版本 diff、运行驾驶舱与全屏图编辑器。
- Control：输入与分支/端口规则。
- Approval：审批模板与规则；运行期决定发生在具体 parked node。
- Trigger：cron/webhook/fsnotify/sensor 等配置、listener 状态、activation 与 firing 两条观测流，并支持手动 fire。

日志列表页保持轻量：列表行不携带可能达到 64 KiB 的 `logs`，用户展开 Function execution 时才请求
`GET /api/v1/function-executions/{id}`；展开期间显示骨架，失败显示原始服务端解释与重试，成功后在同一行展示
完整的 input/output/error/logs/timing。不能用列表页的缺省 logs 冒充“没有日志”，也不能在详情请求失败时静默留白。

实体 rail 的删除确认必须说明对象会从当前目录移除且不可撤销；确认后才调用统一 `DELETE`，列表按 durable
`deleted` 信号对账，打开中的详情回到实体首页。删除不会因入向关系阻塞，后端清边并保留适用的历史/审计事实；前端
不得用含糊的“已删除”成功文案掩盖软删与后续不可用状态。

调试台始终展示一份可直接修改和运行的 JSON。schema 示例优先使用 example/default/enum，缺失时生成类型骨架；workflow 按触发源生成点火 payload。编辑器的可见文本、session 草稿、实时 JSON lint 和 Run CTA 必须共享同一份当前文本：非法 JSON 立即显示可解释的红色错误并禁用 Run，禁止把旧草稿静默送入 HTTP；只有合法对象才进入 `:run`。无执行历史时不制造 Idle 墓碑，只有真实结果、错误或在飞状态才出现。

运行失败时，右岛保留错误码与服务端 message，并在有结构化 `details` 时以人类可读的键值代码区展示；多行 traceback 保留真实换行，正文有硬上限，不能只显示一个泛化“调用失败”或把 `\\n` 转义串直接交给用户。执行日志仍从同一调用审计事实读取，成功与失败都必须可在最近调用条和 Logs 面重查。

## 4. 关键不变量

1. URL 是实体与关系图选区的唯一事实源。
2. 前端不重算后端实体状态、调度规则或 workflow 执行语义。
3. workflow 运行图必须使用该 flowrun 钉住的版本；版本不可解析时诚实降级，不能拿当前图冒充历史。
4. approval first-wins；迟到决定必须对账服务器赢家。
5. replay 只用于失败 run，kill 是硬停止；两者不能在 UI 中互换语义。
6. workflow 编辑器的 ref 与 control/approval 端口来自 repository 候选，不靠自由文本猜 wire 值。
7. 关系图默认只呈现结构关系；conversation provenance 由用户显式开启。

## 5. 验证入口

- feature 测试：`frontend/test/features/entities/`
- 图与运行纯模型：`frontend/test/core/graph/`、`frontend/test/core/run/`
- 路由与壳：`frontend/test/core/router/`、`frontend/test/core/shell/`
- 产品黑盒：`testend/scenarios/` 中 entity、workflow、trigger、flowrun、approval 场景
- 人眼验收：`make -C frontend demo` 或 `make -C frontend app`
