---
id: WRK-028
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-18
review-due: 2026-09-16
audience: [human, ai]
landed-into:
---

# Iteration Loop —— Finding 索引（一行一条，永不写成 essay）

> **规范（强制）**：一个 finding = **一行**，每格一个短语。证据→轨迹 dump；修法详情→commit；本表只做索引。
> 状态：`open` 待修 · `confirmed` 已复现待修 · `fixed` 已修+验+回归 · `watch` 观察 · `not-bug` 判断后非 bug（成本/性能/可恢复且行为正确——不算）· `dup` 被他条覆盖。
> 新发现追加在表末。**别删行**（同 D1 Log 语义）。

| ID | 状态 | 问题（一句话） | 范围 | 修法（定位） | 验证（前→后） | commit |
|---|---|---|---|---|---|---|
| F1 | fixed | lazy 工具概览不点名 id 参数 → 模型瞎猜参数名（`query`/`function_name`…） | **系统性 49/50** | 地基：`toolset.Overview` 浮出必填参数名 + `prompt` 渲 `name(args)` + preamble id→search 解析 | function+handler 修前 4/4 错 → 修后 4/4 一次对、零 error；79/91 工具现渲参数 | dfe2a361 |
| F2 | not-bug | "resident vs searchable" 措辞被半误读——但 agent 行为本就正确，非 bug | — | — | — | — |
| F3 | not-bug | 简单任务 ~75K input token（冗长 schema 重发）——成本/性能，**非 bug**（作者明示不算） | — | — | — | — |
| F4 | watch | `run_function` 首调 args 平铺非 `{"args":{…}}`（修 F1 后未复现，疑被 F1 一并修掉） | 待 CONFIRM | — | — | — |
| F5 | open | 模型用无效字段类型 `"integer"`（schema 只认 number）→ 一次失败调用 + 恢复 | 疑系统性（`pkg/schema` 共享） | 倾向宽容：`integer→number` 等别名归一 | — | — |
| F6 | fixed | edit 带 set_meta 不更新实体行 name/desc/tags（只移版本指针）→ agent 以为改了名、后端没改 | function+handler（workflow 本就对；agent/control/approval 无 set_meta op） | `Edit` 把 draft meta 带回行 + `SaveVersionAndActivate(v, f)` 同事务 Save 整行（6 文件） | `:edit set_meta` 重命名后 GET 真变；零 token 回归 `Test{Function,Handler}_EditPersistsMeta` 绿；make verify 绿 | e356cf2f |
| F7 | fixed | tool 错误对 LLM 不透明：`Error()` 只给 Message、丢 `Details`，而 workflow 校验把违例节点+真实 CEL 错放在 `Details.reason` → agent 见 "workflow graph is invalid" 盲猜 CEL ~8 次卡死 | **系统性**（tool-error→LLM 边界丢所有工具的 Details） | `loop/tools.go` 加 `llmErrText`，在 executeTool 把 Details 渲进 LLM 可见错（一处修全部工具，原则 #8） | 零 token 单测 `TestLLMErrText` 绿；make verify 绿；agent 重跑见详错、自纠建成 workflow、turn completed（前 ERROR） | _pending_ |
| F8 | fixed | workflow CEL 错说 "undeclared reference to 'X'" 但不列**可用**标识符 → agent 试 payload/trigger/celsius/input/receive 5 次才中 | workflow-only（control/approval/trigger 用固定 env payload/ctx/input，无此问题） | `crud.go` compileGraphCEL 首层错附 "this node may read: [祖先节点 id]" | 零 token 回归 `TestWorkflow_InvalidCELListsAvailableNodes` 绿；make verify 绿 | _pending_ |
| F10 | open | `invoke_agent` 的 `input` 非 required → 概览只显 `invoke_agent(agentId)`，agent 猜 `prompt`（未知键被静默丢）→ 空 input 跑出通用问候**却 ok:true**（误导成功）；search_tools 后用对 `input` 得正解（30C=86F） | invoke_agent（深层泛：未知参数静默丢）| 候选：`input` 设 required（概览显 + 缺失报错；但 self-contained agent 需传 `{}`），或框架拒未知参数。**需小设计定夺**——故先 log 不抢修 | — | — |
| F9 | not-bug | `get_flowrun` "not found"——查实：模型把 `trigger_workflow` 返回的 id `fr_…b4a` **截成 `fr_…b4`**（漏末位）后端正确报无；用全 id 重试即中。后端正确、模型复制错+恢复 | — | — | — | — |

## 元注（一次性，非 finding）
- **为什么这 loop 值得**：F1 那条轨迹 `golden J5` 只断言"版本>1"是绿的；轨迹判官却抓到模型把 `get_function` 调错绕一圈——终态测试瞎、判官看见。
- **workflow + durable 子系统验证通过**（2026-06-18）：F7+F8 修后，agent 建成 workflow（trigger→convert→classify）、`trigger_workflow` 跑通；durable 引擎逐节点记忆化、结果正确（celsius=100 → convert `{fahrenheit:212}` → classify `{label:"hot"}`，三节点 completed）。"整套工程"在此方向确认能转。
- 永久回归 test：`selfiter_confirm_f1_*`、`_f1batch_*`（F1）· `Test{Function,Handler}_EditPersistsMeta`（F6）· `TestLLMErrText`（F7）· `TestWorkflow_InvalidCELListsAvailableNodes`（F8）。
