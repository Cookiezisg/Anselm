---
# Round 0039 设计稿 — trigger 升格为独立实体(开工蓝本)

> 开工前定稿(用户逐点拍板 2026-06-07)。收尾记录见同目录 round.md。

## 一句话
trigger 从「workflow 图里的节点」提升为 **独立的信号源实体**:`[source 产生信号] → [扇给监听它的 workflow]`。它是**配置实体**,不是执行体——无版本、无 sandbox、无 envfix。

## 旧模型的局限(为什么要改)
旧 trigger 没有独立身份,主键 `(workflowID, nodeID)`,完全寄生 workflow 图:`:activate`→`extractTriggers`→注册 listener,fire 只能触发**宿主 workflow**。后果:① 不能复用(两个 workflow 都要"每天 9 点"得各画一个 cron 节点 = 两个重复 listener)② 没有独立列表/观测面 ③ 目标写死。

## 用户拍板的决策
1. **独立实体**:有 id/name/desc/kind/config,地位同 function——进 catalog、relation,有自己的 LLM 工具。
2. **生命周期 = 引用计数**:trigger 光存在不干活;**有 ≥1 个 active workflow 引用它 → listener 启(热);引用归 0 → 停(冷)**。开关权不在 trigger 自己,在"谁在用它"。
3. **共享**:N 个 workflow 引用同一 trigger → 只跑**一个** listener,fire 一次扇给这 N 个 workflow 各起一个 flowrun。(旧模型重复 N 个 listener——这是独立实体最值的地方。)
4. **信号流**:fire 产 payload → 每个被扇到的 workflow 拿它当 flowrun 初始 input。旧 trigger 节点本就是 no-op 透传 `flowrun.TriggerInput`,所以搬出图不丢信号。
5. **4 种 source**(砍 manual):`cron`(到点)/ `webhook`(别人推)/ `fsnotify`(盯文件)/ `sensor`(定时探)。manual 不是 trigger——手动跑是 workflow 自己的 `:trigger` 能力。
6. **sensor**(原 polling 改名,用户选定):**绑一个 function 或一个 handler.method(都看 active 版本)** + `intervalSec`(必填/最小 5s/不能 0)+ CEL `condition` + CEL `output`。每 interval 调 → 拿返回值 → condition 判 → true 就 output 构造 payload → fire。**要状态绑 handler**(进程自己记游标/session)、**不要状态绑 function**;trigger 自身永远无状态。
7. **无版本号**:配置实体,改即生效。
8. **可观测**:每个 trigger 的**每一次动作都记**(触没触发都记),否则无法排查"为什么没动"。

## 三张表
| 表 | 前缀 | 作用 |
|---|---|---|
| **Trigger** | `trg_` | 实体本体(name/kind/config),无版本,软删 |
| **Firing** | `trf_` | durable 收件箱:触发后待 scheduler 认领的信号(persist-before-act + dedup + 单事务 claim) |
| **Activation** | `tra_` | 动作日志:每次活动一条,**触没触发都记**(可观测/排查) |

```
Trigger{ ID(trg_), WorkspaceID, Name(唯一), Description, Kind, Config(JSON), 时间戳/DeletedAt }
Firing{ ID(trf_), WorkspaceID, TriggerID, WorkflowID, ActivationID, Payload, DedupKey, Status, FlowrunID, EnqueuedAt }
   Status: pending → claimed → started → {skipped, superseded, shed}   // claim 留波次 4
   UNIQUE(workflow_id, trigger_id, dedup_key) 保证幂等
Activation{ ID(tra_), WorkspaceID, TriggerID, Kind, OccurredAt,
            Fired(bool),                  // 到底触没触发
            ReturnValue?, ConditionMet?,   // sensor 专属:函数返回啥、CEL 判定
            Payload?,                      // 触发了的话 fire 出的内容
            Error?, Detail? }              // 没触发原因/调用失败/验签失败
```
一次 Activation 产 **0 条**(没触发)或 **N 条**(扇出 N workflow)Firing;Firing 反指 `activationId`。
**保留策略**:sensor 高频(每 60s 一条),日志会涨——v1 先全留,GC/保留窗口留 TODO。

## 生命周期:引用计数(内存态)
- app/trigger 维护 `map[triggerID] → set[workflowID]` + 4 个 listener 实例。
- 原语 `Attach(triggerID, workflowID)` / `Detach(...)`:**0→1 启 listener,1→0 停**。
- 持久真相在 workflow(谁 active + 引用谁),trigger 自己不存引用关系;**boot 时 scheduler 重新 Attach 重建**。

## 信号流
`listener 响 → 查 map 得监听的 workflow → 每个写一条 Firing(扇出)+ 写一条 Activation → (claim→flowrun 留波次 4)`。payload 最终成 workflow flowrun 初始 input。

## sensor 怎么接(DIP,不硬依赖 function/handler)
- 端口 `SensorInvoker{ Invoke(ctx, targetKind, targetId, method) (returnValue map[string]any, err error) }`,function app / handler app 各写一个适配器,boot 注入。
- CEL 复用项目引擎(旧封装 `app/workflow/cel.go`;backend-new 这轮引入 `cel-go`,workflow 节点控制波次 4 复用)。

## 工具组(8 个,地位同 function)
`search_triggers` / `get_trigger` / `create_trigger` / `edit_trigger` / `delete_trigger` / `fire_trigger`(手动催一次,测试用)/ `search_activations` / `get_activation`。

## 跨域
- **catalog**:进(名字+描述按 kind 分组)。
- **relation**:trigger 升为**第 9 个节点类型**(`EntityKindTrigger` + `prefixKind["trg"]` + `KindForID`);sensor 绑定记一条 `trigger → function/handler` 边;`workflow → trigger` 监听边波次 4 由 workflow 产。
- **mention**:不进(配置实体,非内容快照)。

## 留给后面波次(deps-todo 登记)
- **claim Firing → 建 flowrun**(消费收件箱):scheduler **M4.3**。
- **workflow 开关 = Attach/Detach**(active 永久 / 手动一次 = 监听额度 1):workflow + scheduler **M4**。
- **boot 重建引用 + 注入 SensorInvoker + 4 listener 起停**:**M7**。
- **CEL 引擎**:本轮引 `cel-go`,workflow 节点控制 **M4** 复用(是否抽 `pkg/cel` 共享包届时定)。

## 它在 Quadrinity 里的定位
| | function | handler | trigger |
|---|---|---|---|
| 状态 | 无状态 | 有状态常驻 | 无状态(配置) |
| 版本 / sandbox / envfix | 有 | 有 | 全无 |
| 执行日志 | Execution | Call | Activation |
| 生命周期 | 无常驻 | MCP 单例常驻 | 引用计数(随 workflow 起停) |

## 切片
`domain/trigger` + `infra/store/trigger`(3 表 DDL)+ `infra/trigger/{cron,fsnotify,webhook,sensor}` + `app/trigger` + `app/tool/trigger` + `transport/.../trigger.go`。前 3 listener 照搬旧的去 gorm,sensor 新写;新增依赖 robfig/cron v3 + fsnotify v1.10 + google/cel-go。

## 测试(全离线)
实体 CRUD、引用计数 0↔1 启停、fire 扇出写多条 Firing+Activation、sensor CEL 判定(fake invoker,含触发/不触发/出错三种 Activation)、Firing dedup。
