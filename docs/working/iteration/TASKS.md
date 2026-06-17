---
id: WRK-027
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-18
review-due: 2026-09-16
audience: [human, ai]
landed-into:
---

# Iteration Loop —— 任务 + 预期注册表

> 每条任务 = **多轮对话剧本** + 跑发器 test 名 + **预期**（判官按此判）+ **后端 ground-truth 查询**（端到端真相，不只看回复）。
> 加任务：在 `testend/golden/selfiter_probe_test.go` 写 `TestSelfIter_<名>`，在此登记。
> 选任务原则：**端到端压全栈**——覆盖 tool-call 质量 **AND** 整套工程（build/sandbox/durable/handler/trigger/search）。优先补能压**引擎**的（最能暴露"整套工程转不转"）。
> **多轮**：理想态是 user-simulator 带目标跟 agent 聊 N 轮（会追问/反驳）。当前 probe 多为单轮——升多轮见 README「还要建的」。

## T1 · 从零造 function 并调通
- **test**：`TestSelfIter_BuildRunFunction` · **tag**：`buildrun`
- **剧本**：Create a Python function `add(a,b)` returning `{"sum": a+b}`, then run it with a=2,b=3.
- **压**：tool 选择/参数/顺序 + build 管线 + sandbox（envfix）
- **预期**：（可选）查重名 → `search_tools` 载 schema → `create_function`（ops 合法）→ `run_function`（`{a:2,b:3}`）→ 报 5。可接受 double-check/envfix 重试。
- **后端 ground-truth 查询**：`GET /functions`（建了没）→ 取 fn id → `GET /functions/{id}/versions`（version=1）→ `GET /functions/{id}/executions` 或 run 结果（真跑出 `{"sum":5}` 没，非只看回复说 5）。
- **状态**：✅ 跑过（2026-06-18），PASS，无 hard finding；软 **F2** 见 LOG。

## T2 · 修埋雷 function（诊断 + 恢复）
- **test**：`TestSelfIter_FixBuggyFunction` · **tag**：`fixbuggy`
- **预置**：`buggy_double` 引用未定义变量 `undefined_factor`。
- **剧本**：buggy_double is broken — fix it to return `{"out": n*2}`, verify on n=4.
- **压**：诊断 + edit_function + **恢复动态**
- **预期**：取代码（`get_function` 需 `fn_` id → 应先 `search_function`）→ 诊断 → `edit_function`（n*2）→ run(n=4) → 报 8。可接受先 run 看报错再修。
- **后端 ground-truth 查询**：`GET /functions/{id}/versions`（active version >1、且新版 code 真是 `n*2`）→ run(n=4) 真返 `{"out":8}`（查执行记录，非只看回复）。
- **状态**：✅ 跑过（2026-06-18），PASS + 恢复 5/5；**挖出 hard F1**（get_function 按名查），见 LOG。**正在 CONFIRM**（`selfiter_confirm_f1_test.go`）。

## 待加（覆盖「整套工程转不转」，每条都要带后端 ground-truth 查询）
- **T3 · workflow + durable**：agent 造 function → 串 workflow → trigger → 撞 approval → `kill -9` 恢复。**后端查**：`GET /flowruns/{id}` 节点 status（真 advance 没/记忆化对没/恢复后到 completed 没）、firing 记录。harness 有 `Kill9`+`Restart`。
- **T4 · handler 常驻**：造 handler + call method。**后端查**：`GET /handlers/{id}` + 实例状态 + 执行记录（method 真跑出对值没）。
- **T5 · search RAG**：预置实体，让 agent 搜到指定那个。**后端查**：search 索引可见性（`waitIndexed`）+ agent 报的名字 = 实际实体名。
- **T6 · 多工具编排**：跨 function+memory+document 协作。**后端查**：三类实体终态都对没。
