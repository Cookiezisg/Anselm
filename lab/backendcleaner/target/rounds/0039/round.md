---
# Round 0039 — trigger 升格为独立实体（信号源 + 引用计数 + sensor/CEL + 填 polling 坑）

类型 / 目标：波次 3 **加站**（用户提）。把 trigger 从「workflow 图里的节点」提升为**独立实体类型**，顺带填 M3.1 剥离 polling 留下的坑。设计稿见同目录 `design.md`。

## 核心方针（一句话）
**trigger = 独立信号源实体（`trg_`，地位同 function）：4 source（cron/webhook/fsnotify/sensor）+ 引用计数生命周期 + 3 表（实体/收件箱/动作日志）。无版本、无 sandbox、无 envfix——配置实体。**

## 用户拍板的决策（研讨 6 轮）
1. **独立模块/实体**：workflow「用」trigger = 监听它；进 catalog + relation **第 9 节点** + 8 个 LLM 工具。
2. **引用计数生命周期**：≥1 个 active workflow 引用才起 listener；N workflow 共享一个 listener，fire 扇出。
3. **polling → `sensor`**（用户选名）：绑一个 function 或 handler.method（都看 active 版本）+ `intervalSec`(≥5) + CEL `condition`/`output`。**要状态绑 handler**（进程自记游标）、**不要状态绑 function**；trigger 自身无状态。CEL 借鉴 workflow 节点控制。
4. **无版本号**（配置实体，改即生效）。
5. **砍 manual**（手动跑是 workflow 自己的能力，不监听任何东西）。
6. **Activation 动作日志**（用户提：触没触发都记，否则无法排查「为什么没动」）+ 对应查询工具。

## 信号传递的关键洞察
旧 trigger 节点是 **no-op 透传** `flowrun.TriggerInput`（`dispatch_trigger.go` 仅 26 行）。所以 trigger 搬出图**不丢信号**——payload 走 `firing → flowrun.input`，workflow 从入口消费。这化解了用户「trigger 会传递信号」的担忧，也定了 **target = workflow**（方案 A）。

## 新增 / 重写
- **domain/trigger**：Trigger（`trg_`，无版本）+ Firing（`trf_`，收件箱）+ Activation（`tra_`，动作日志）+ 4 source config + `ParseSensorConfig`/`ValidateConfig` + errorsdomain（12 错误）。去 GORM。
- **infra/store/trigger**：orm 3 表 + Schema DDL；`AppendFiring`（dedup 幂等）/`ListPendingFirings`/`ClaimFiring`（单事务 ADR-021，消费留波次 4）/Activation append+search。
- **pkg/cel 新建 ★**：CEL 编译/求值共享包（`Compile`/`Eval`/`EvalBool`，只读 `payload`/`ctx`、无 `now()`）；从旧 `app/workflow/cel.go` 提炼，sensor + workflow（M4）复用——避免 infra→app 依赖。
- **infra/trigger**：`listener.go`（`ReportFunc` + `Activity` + `Listener` 接口，**key=triggerID**）+ cron/fsnotify/webhook **照搬去 gorm 改 triggerID 维度** + **sensor 新写**（invoke→CEL→fire）。**回调升级为 `ReportFunc`（每次动作都报，Fired 与否）**——让「没触发」也落 Activation，统一 4 listener。
- **app/trigger**：引用计数 map（`Attach`/`Detach` 0↔1 启停）+ `onReport`/`fanOut`（写 Activation + Fired 时扇出 Firing）+ `FireManual` + CRUD + `Search` + `validate`（cron/CEL 语法）+ `SensorInvoker` 端口 + catalog/relation 适配器（第 9 节点 + sensor `equip` 边）。
- **app/tool/trigger**：8 工具（search/get/create/edit/delete/fire/search_activations/get_activation）。
- **transport**：`trigger.go`（REST + `:fire` + activations 查询）。
- **relation**：加第 9 节点 `EntityKindTrigger` + `prefixKind["trg"]`（同步更新 entitykind_test）。
- **go.mod**：+robfig/cron v3 + fsnotify v1.10 + google/cel-go v0.28。

## 砍掉的旧物
旧 trigger 寄生 workflow（`(workflowId, nodeId)` 无独立 id）+ per-workflow 重复 listener + polling 寄生 function（`kind=polling`，M3.1 已剥）+ 旧 3 表 `trigger_schedules`/`trigger_firings`/`polling_states`（gorm）+ 前缀 `ts_`/`tfi_`。missed-tick cron 补跑（需 schedule 表持久化 lastFire）这轮不做，留 deps-todo（可用 Activation 日志重建）。

## 测试（全离线）
store 5（CRUD/隔离/firing dedup/单事务 claim/activation bool 过滤）+ sensor 3（CEL 触发/不触发/出错三态，fake invoker）+ app 7（引用计数共享 listener 0↔1 启停 / fire 扇出多 Firing+Activation / 不触发只记 Activation+returnValue / validate 拒坏 cron+CEL / edit 重启热 listener / delete 停+移除 / catalog source）+ relation（第 9 节点）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./...` 0 · `go test -race`（store/sensor/app/relation）全绿。

## 契约
`domains/trigger.md` **整篇重写**（DOC-125，独立实体）+ `api.md`（§2.5 Triggers）+ `error-codes.md`（§2.6.1 Trigger，12 码）+ `database.md`（§4.3 三表 + 前缀 `trg_`/`trf_`/`tra_` 取代 `ts_`/`tfi_`）+ `relation.md`（节点 8→9）+ `contract-changes #19`。

## 跨波次接线（deps-todo 登记）
- claim Firing → 建 flowrun：scheduler **M4.3**。
- workflow 开关 = Attach/Detach（active 永久 / 手动一次 = 监听额度 1）：workflow + scheduler **M4**。
- boot 重建 Attach + 注入 `SensorInvoker`（function/handler 适配器）+ listener `Start`/`Shutdown`：**M7**。
- `pkg/cel`：workflow 节点控制 **M4** 复用。
- workflow→trigger 监听边 + 旧 workflow 内嵌 trigger 节点清理：**M4**。
- missed-tick cron 补跑（可用 Activation 重建）：择机。
- `:iterate`（askai）：波次 6。
