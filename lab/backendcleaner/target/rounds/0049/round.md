# Round 0049 — scheduler（波次 4 · M4.3 · 🔴 最大重灾区）

类型 / 目标：编排核心的**durable 图解释器**——把钉死的 workflow 图驱动到完成、可崩溃恢复。order.md 点名「14→5 dispatcher / 删 topo-walk / 只保留 durable interpreter」的重写主因。

依赖扫描：
- 上游就绪：flowrun（R0048 `RunStore`）、workflow（R0047 `WorkflowReader`/`BuildPinClosure`/`GetVersion`〔pin 版本〕 + 纯 `ValidateGraph`/`BackEdges`）、control/approval（`Resolve(id,versionID)`）、trigger（`ClaimFiring` 单事务）、pkg/cel（`ScopedEnv` + `Compile` + `CompileTemplate`）。
- 下游接口（DIP）：`Dispatcher`（RunAction/RunAgent，M7 注真）、`WorkflowReader`/`ControlResolver`/`ApprovalResolver`/`FiringInbox`/`RunStore`（全端口，测试 fake）。
- 考古：旧 `app/scheduler` 9302 行——14 个 dispatch_*.go + state.go(297)/pause.go(241) topo-walk + generation 代数 + Agenda 待办栈。**只读、绝不照搬结构**（lab SPEC §5）。

旧实现历史包袱：14 dispatcher 分裂（function/handler/mcp/agent/llm/http/skill/tool/variable/wait/condition/approval/trigger/loop_parallel）、topo-walk + paused_state（一半旧一半新）、generation 自增代、LoopDispatcher、Agenda、分布式味（lease/worker/sharding 残留）。**全删。**

修改后完整逻辑（= doc 21 §4 + domains/scheduler.md DOC-119）：
- **幂等 `advance(flowrunID)`**：读 frn 行 + **pin 的图**（`GetVersion(run.VersionID)` 非 active）→ `computeReady` → `runNode`（dispatch/内联）→ `InsertNodeResult` → loop until 无 ready → `finalize`（completed / 有 parked 则仍 running / 失败 fail-fast）。崩溃恢复 = 再调一次（completed 行抄不重跑）。
- **`computeReady`（walk.go，判定②核心）**：从 seed 的 trigger BFS、**从 control/approval 已落库决策（chosenPort）重推活跃子图**——边剪枝（completed ctl/apf 选了别的 port）；readiness 统一 **AND-join**（并行：所有 live 入边源 completed）与 **simple-merge**（control 下游：只等被激活那条，绝不等被剪的）；**无 skip 信号传播**（model B 红利：决策已在行里，重推 O(图) 纯计算）。**回边**（BackEdges，control/approval 源）仅源 completed+port 命中才走、iteration+1；`MaxIterations` 安全帽防失控循环。`scopeFor` = 按 node-id 取祖先 result（max-iter ≤ 当前，循环内取当前轮/外取固定）。
- **dispatch 14→2 + 2 内联**：`RunAction`[fn/hd/mcp] + `RunAgent`（**粗粒度** activity，崩溃整体重跑）+ control（first-true-wins When/Emit）/ approval（渲染 + park）内联。**CEL 双轨**：节点 Input = ScopedEnv（node-id 根）；control when/emit + approval template 读 `input`（节点解析出的 input map）。fail-fast（写 failed 行 + 标 run failed）。
- **run 生命周期（run.go）**：`StartRun`（建-run 原语）两入口——手动（`POST /flowruns` 直调）+ firing（`ClaimFiring` 单事务 claim + `SeedRunOnTx` ADR-021）+ overlap（serial defer / Skip drop / AllowAll）；`Recover`（boot 跨 ws 重走）；`DecideApproval`（first-wins）；`CheckTimeouts`（approval durable timer：reject/approve/fail）；`Replay`（清 failed 行 + 重走）。
- **handler 6 端点**：`GET /flowruns`(?workflowId) · **`POST /flowruns`**(手动起 run) · `GET /flowruns/{id}` · `POST {idAction}`(:replay) · `GET /flowrun-inbox` · `POST .../approvals/{nodeId}:decide`。

删除 / 合并：14 dispatcher → 2+2；state.go/pause.go/generation/LoopDispatcher/Agenda 删。旧虚构端点 `/nodes`·`/failures`·`/trace`·`DELETE`·`GET /approvals` 删。

契约变更（→ contract-changes #31）：doc 17 事件溯源契约执行层面被 doc 21 取代；database §2.4/S15/D3、api §3、error-codes §2.8、events `flowrun.*` 校准、domains/flowrun.md(DOC-109)+scheduler.md(DOC-119) 整篇重写、doc 21 §3.2 control result 扁平 doc-fix。

新实现要点：scheduler.go（Service + 6 端口 + helper）、walk.go（reachability/readiness/scope/chosenPort）、dispatch.go（runNode + evalInput/evalControl/renderApproval）、advance.go（Advance/finalize/failRun）、run.go（StartRun/Drain/Recover/Decide/Timeouts/Replay）、query.go（读面）、handlers/flowrun.go。

新测试（集成，核心模块必须；fake Dispatcher/Workflows/Control/Approval + 真 flowrun/trigger store）：**18 个全绿**——走图（线性 / 并行 AND-join / control XOR / control 后 simple-merge / 回边循环带状态）+ 三血泪边界（replay 确定性〔重复 advance 行集不变〕/ record-once / approval first-wins）+ 崩溃恢复（completed 跳过）+ at-least-once（丢行重跑 count=2，证语义非假装 exactly-once）+ park/resume/timeout + firing 单事务 claim + overlap serial/Skip + replay 修复。

验证：gofmt / `go build ./...`（整仓）/ vet / `go test`（scheduler + store）全绿。

是否更干净（自证）：9302→~1500+2 表；分支大减（14 dispatcher→2+2、无 generation/topo-walk/pause-state）；fallback/alias 减少（无事件日志 dedup、无分布式 lease）；职责更直接（一个幂等 advance + 从决策重推活跃子图）；无多余抽象（DIP 端口皆 M7/测试实际需要）。

覆盖状态（capability-ledger）：durable 执行引擎本体落地（workflow 执行 = 解释 + 记忆化 + 崩溃恢复 + 人在环 + 重放）。

遗留 / 下一步：**M7 中央装配**（Dispatcher 注 fn/hd/mcp/agent Service、FiringInbox 接 trigger store、ticker DrainFirings/CheckTimeouts、boot Recover、eventlog Emitter〔flowrun.* 事件〕、`trigger_workflow` LLM 工具、Toolset/Register/migrate）。trigger Attach/Detach（workflow :activate 引用计数）。v2：resume-mid-agent（frs_ + loop.Run durable 重放）、continue-as-new、durable timer 通用门、overlap Buffer*、catch-up。**波次 4 编排核心收官 🎉**。
