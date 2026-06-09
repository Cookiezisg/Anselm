# Round 0048 — flowrun（波次 4 · M4.2）

类型 / 目标：编排核心执行引擎的**持久化状态层**——flowrun domain + store。durable 执行的真相落地。

依赖扫描：
- 上游就绪：workspace（ws 隔离）、pkg/orm（链式 + ErrConflict + Transaction + 自动 ws）、idgen（自由前缀，frs_ 本不引入故 fr_/frn_ 够）、trigger（`Firing` + `ClaimFiring(create 回调)` 已为 scheduler 备好）。
- 下游接口：scheduler（R0049）经 `RunStore` 端口消费（domain.Repository + 两个 store 具体的原子建-run 方法 SeedRunOnTx/CreateRunWithTrigger）。
- 考古：旧 `backend` 的 flowruns + flowrun_events（fre_ 事件日志）+ approvals（apv_ 投影）+ generation——**事件溯源模型**。本轮**不照搬**：节点结果记忆化（doc 21 定调）。

旧实现历史包袱：事件日志（fre_，append-only journal）+ generation 代数（replay 自增代）+ approvals 投影表（apv_）+ GORM tag + user_id。**全卸**。

修改后完整逻辑（= doc 21 §3 + domains/flowrun.md DOC-109）：
- **2 表**：`flowruns`（fr_ header：workspace_id/workflow_id/version_id〔pin 拓扑〕/pinned_refs〔pin 引用版本〕/trigger_id/firing_id/status〔running|completed|failed〕/replay_count/error/时间戳）+ `flowrun_nodes`（frn_ ★真相：node_id/iteration/kind/ref/status〔completed|failed|parked，只写终态〕/result〔per-kind〕/error/时间戳）。两张 **Log 表无 deleted_at**（D1）。
- **record-once** = `idx_frn_once` UNIQUE(flowrun_id,node_id,iteration)（D3）：`InsertNodeResult` first-wins（Create→ErrConflict→inserted=false）；**approval first-wins** = `ResolveParkedNode` 条件 `UPDATE … WHERE status='parked'`（won = rowsAffected>0）。
- **result 形状契约**：`ControlResult(port,emit)` = emit 字段**扁平** + 保留键 `__port`（对齐 doc 20 §5.4 下游读 gate.feedback）；`ApprovalDecision(decision,reason)`。
- **`:replay` 半**：`DeleteFailedNodes`（物理删 failed 行——Log 表唯一允许的删，failed 是非结果）+ `ReopenForReplay`（failed→running + replay_count++，非 failed→ErrNotReplayable）。**取代 generation**。
- **建 run**：`SeedRunOnTx(tx,run,trig)` 原子建 header + seed trigger 节点（firing 路径在 ClaimFiring 的 tx 内调）；`CreateRunWithTrigger` 自有 tx 包一层（手动路径）。
- **overlap 输入**：`CountRunningByWorkflow`；**boot 恢复**：`ListRunningRuns` 跨 ws（`CrossWorkspace`）；**inbox** = `ListParkedNodes`（parked 行即收件箱，无 apv_）。

删除 / 合并：`flowrun_events`(fre_)、`approvals`(apv_)、generation、GORM、user_id；`frs_`(agent 子步)**不引入**（agent 粗粒度，doc 21 §3.3）。

契约变更（→ contract-changes #30，随 R0049 整体落 database/api/error-codes/domains）：S15 删 fre_/apv_、重定义 frn_；§2.4 as-built 2 表；D3 idx_frn_once；5 错误码 FLOWRUN_*（NOT_FOUND/NOT_REPLAYABLE/APPROVAL_NOT_PARKED/INVALID_ENTRY/INVALID_DECISION）。

新实现要点：domain（FlowRun/FlowRunNode + Repository + result-key 常量 + 2 helper + 5 errorsdomain）；store（2 表手写 DDL + CHECK + 3 索引 + record-once/first-wins/原子建-run/replay 物理删）。

新测试（store，全离线 in-memory sqlite）：record-once first-wins（重复 InsertNodeResult 一行）、approval first-wins（人 vs timeout 竞争一行）、replay（清 failed 留 completed + replay_count++ + 非 failed 拒）、ws 隔离 + 跨 ws boot、seed+pin json 往返。

验证：gofmt / `go build ./...` / vet / `go test`（domain[无测试]/store）全绿。

是否更干净（自证）：分支减少（无 generation 代数、无事件日志 append/dedup）；fallback/alias 减少（无 GORM serializer、无 user_id 兼容）；职责更直接（一张真相表 + record-once，崩溃恢复 = 重走抄行）；无多余抽象（2 表，per-kind result 由常量约束）。

覆盖状态（capability-ledger）：durable 执行的「持久化状态」能力落地（执行引擎本体 R0049）。

遗留 / 下一步：R0049 scheduler（解释器消费本层）。frs_/resume-mid-agent、continue-as-new、durable timer 通用门、overlap Buffer* → v2。
