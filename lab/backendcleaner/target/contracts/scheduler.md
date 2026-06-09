# 契约 — flowrun（M4.2）+ scheduler（M4.3）

> **权威 = `docs/working/workflow-revamp/21-flowrun-scheduler-design.md`**（完整设计）。本文是 lab 轮次摘要：去包袱 / 守边界 / 删除清单 / 契约变更，供 R0048（flowrun）+ R0049（scheduler）施工对照。
> 核心模块（scheduler 是 🔴 order.md 点名最大重灾区）——**本契约 + doc 21 给用户审过、才动代码**（PLAYBOOK 步骤1）。

## 0. 一句话

一次执行 = durable 解释器照**钉死的图**走一遍，**每个节点 result 记进 `flowrun_nodes` 行表（记忆化）**，崩溃后重走时 completed 行抄结果、不重跑。**不存事件流、不重放用户代码**（没有用户代码，只有图解释器）。doc 17 那套事件溯源（journal/generations/polling/GORM/user_id）全卸。

## 1. 考古（旧 backend 屎山 = 重写主因）

- `backend/internal/app/scheduler/` ~9302 行：`interpreter.go`(870) / `state.go`(297) / `pause.go`(241) / `scheduler.go`(231) / `retry.go` / `dispatcher.go` / `replay.go` + ~14 个 `dispatch_*.go`。
- 病灶：① **14 节点类型 dispatcher 分裂**（function/handler/mcp/agent/llm/http/skill/tool/variable/wait/condition/approval/trigger/loop_parallel）② **topo-walk 旧链（state/pause）与 durable journal 并存**（一半旧一半新）③ generation 代数 + 事件日志的分布式味偶然复杂度。
- **只读考古**：提取产品逻辑 + 血泪边界；**绝不 copy 结构、绝不被它驱动**。

## 2. 去包袱（删除清单 · doc 21 §7）

14 dispatcher → **2 dispatch（RunAction[fn/hd/mcp] + RunAgent）+ 2 内联（control/approval 解释器内求值）**；删 `state.go`/`pause.go`（topo-walk + paused_state）、`LoopDispatcher`（结构化 loop 取代）、generation 代数、`flowrun_events`（`fre_` 事件日志）、`approvals`（`apv_` 投影表）、所有分布式机制（task queue / worker / sticky / sharding / lease / stale-claim 回收）。

## 3. 数据模型（2 表 · doc 21 §3）

- **`flowruns`（`fr_`）** header：workflow_id + **pin 的 version_id + pinned_refs JSON** + trigger_id/firing_id（手动 :trigger 时空）+ status（running|completed|failed）+ replay_count。
- **`flowrun_nodes`（`frn_`）★真相表**：`UNIQUE(flowrun_id,node_id,iteration)` → status/result；action·agent·control·approval 各写自己的 result；parked 行 = 审批收件箱。
- **agent = 粗粒度 activity（无 `frs_`）**：和 action 一样只记忆化最终 result 进 frn、崩溃整体重跑（at-least-once）。卡点 = `app/loop.Run` 是流式黑盒、无 resume 入口；resume-mid-agent（子步记忆化 + loop durable 重放）→ v2，要动 loop.go。
- 全 Log 性质**严禁删除**（D1）、workspace 隔离（D2）。

## 4. 必须保证的行为（三血泪边界 = 新测试规格 · doc 21 §6）

1. **replay 确定性**：重复 `advance`（含崩溃 boot 恢复）→ frn 行集逐字节一致。靠 pin 冻结 + 决策记忆化 + CEL 纯函数。
2. **record-once 幂等**：`UNIQUE(flowrun_id,node_id,iteration)` + `INSERT OR IGNORE`，同 (节点,轮次) 永不两行、首写赢。
3. **approval first-wins**：人决策 vs timeout 竞争同一 parked 行 → upsert first-wins，第一个定终身、第二个静默忽略。

> 另：**join = 从 control/approval 决策重推活跃子图**（doc 21 §4.3，BPMN 状态式 / Conductor decider 标准解；control 严格 XOR + 并行严格 AND → 只有 AND-join 与 simple-merge，无 skip 信号传播）。**at-least-once 诚实**（崩溃在「action 完成、写行前」→ 重跑；不假装 exactly-once，给 callable 传确定性幂等键）。

## 5. DIP 端口（doc 21 §5）

唯一新增 = **`Dispatcher`**（`RunAction`/`RunAgent`，两者**粗粒度**、M7 接 fn/hd/mcp/agent Service、测试 fake）。其余全已落地直接 import：`WorkflowReader` / `BuildPinClosure` / `ValidateGraph` / `BackEdges` / `control.Resolve` / `approval.Resolve` / `pkg/cel`（ScopedEnv/Program/Template）/ trigger firings claim。scheduler **暴露 `StartRun`**（建-run 原语，手动 :trigger 与 firing 两入口共用）。

## 6. 契约变更（→ contract-changes.md，落地时记 #30/#31）

- **database.md**：S15 删 `fre_`/`apv_`、重定义 `frn_`（**不加 frs_**，agent 粗粒度）；§1 Execution 段删旧 GORM-tag 前瞻 struct、写 as-built 2 表；D3 → `idx_frn_once`。
- **events.md**：`flowrun.*` 事件保留（前端实时视图），校准 source 路径 + tick payload；tick 仍 E2 Ephemeral seq=0；三流不变（E1）。
- **api.md**：+ `GET /flowruns`、`GET /flowruns/{id}`、`POST …:replay`、`POST …/approvals/{nodeId}:decide` + **`POST /workflows/{id}:trigger`**（手动起 run，body `{entryNode?, payload}`；payload 表单 schema = **入口 trigger.Outputs**，客户端用现有端点自组装无需新端点；`trigger_workflow` LLM 工具随 M7）。
- **error-codes.md**：+ `FLOWRUN_*`。
- **domains/flowrun.md + domains/scheduler.md**：旧引擎契约整篇重写为 as-built。

## 7. 延后 v2

通用 durable timer 门（at?/after?）/ continue-as-new / overlap BufferOne·BufferAll / catch-up 补偿 / **resume-mid-agent**（agent 子步记忆化 `frs_` + loop.Run durable 重放改造，要动 loop.go）/ `trigger_workflow` LLM 工具（随 M7）。

## 8. 顺序（PLAYBOOK 四步 · 每步 verify+commit+push）

1. ✅ 契约（本文 + doc 21）→ **用户审**（当前）。
2. **R0048 flowrun**：domain（2 实体 fr_/frn_ + record-once 不变式）+ store（2 表 orm + 手写 DDL）+ 测试。
3. **R0049 scheduler**：app 解释器（**StartRun** / advance / computeLiveSubgraph / dispatch / park-resume / firing claim / boot 恢复 / :replay）+ `Dispatcher` 端口 + handler（flowrun REST + **`POST /workflows/{id}:trigger`** 手动起 run）+ **集成测试**（doc 21 §11，核心模块必须）。
4. 契约文档同步（§6）+ lab round + verify + commit push。M7 装配（Dispatcher 注真 / ticker / boot）延后。
