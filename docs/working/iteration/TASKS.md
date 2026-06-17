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

> 每条任务 = 一句真用户 prompt + 跑发器 test 名 + **预期**（判官按此判）+ 确定性断言。
> 加任务：在 `testend/golden/selfiter_probe_test.go` 写 `TestSelfIter_<名>`，在此登记预期。
> 选任务原则：**端到端压全栈**（不是孤立工具 ping）——覆盖 tool-call 质量 **AND** 整套工程（build/sandbox/durable/handler/trigger/search）。

## T1 · 从零造 function 并调通
- **test**：`TestSelfIter_BuildRunFunction` · **tag**：`buildrun`
- **prompt**：Create a Python function named `add` that takes two integers a,b and returns `{"sum": a+b}`. Then run it with a=2,b=3 and tell me the result.
- **压**：tool 选择/参数/顺序 + build 管线 + sandbox（envfix）
- **预期**：（可选）search 确认无重名 → `search_tools` 载 `create_function` schema → `create_function`（ops: set_meta/set_code/set_inputs/set_outputs，代码合法）→ `search_tools` 载 `run_function` → `run_function`（args `{a:2,b:3}`）→ 报出 5。**可接受**：先列工具、double-check、envfix 重试。
- **确定性断言**：`GET /functions` ≥1；最终 text 含 `5`。
- **状态**：✅ 跑过（2026-06-18），PASS，无 hard finding；软 finding **F2** 见 LOG。

## T2 · 修埋雷 function（诊断 + 恢复）
- **test**：`TestSelfIter_FixBuggyFunction` · **tag**：`fixbuggy`
- **预置**：`buggy_double` 引用未定义变量 `undefined_factor`。
- **prompt**：The function buggy_double is broken — it references an undefined variable. Fix it so it returns n doubled as `{"out": n*2}`, then verify it works on n=4.
- **压**：诊断 + edit_function + **恢复动态**
- **预期**：取函数代码（`get_function` 需 `fn_` id，故应先 `search_function` 拿 id）→ 诊断未定义变量 → `edit_function`（set_code `n*2`）→ `run_function`（n=4）→ 报出 8。**可接受**：先 run 看报错再修；调错后恢复。
- **确定性断言**：active 版本 >1。
- **状态**：✅ 跑过（2026-06-18），PASS + 恢复 5/5；**挖出 hard finding F1**（get_function 按名查），见 LOG。

## 待加（覆盖「整套工程转不转」）
> 写 test + 在此登记预期 + 标「待跑」。优先补能压**引擎**的，因为它们最能暴露"整套工程"问题。

- **T3 · workflow + durable**：让 agent 造 function → 串进 workflow → trigger → 撞 approval → `kill -9` 再恢复。压 durable 引擎（记忆化 / 崩溃恢复）。harness 已有 `Kill9`+`Restart`（同 dataDir 新端口）可复用。
- **T4 · handler 常驻**：造 handler + call 其 method。压有状态进程 + stdio RPC。
- **T5 · search 检索 RAG**：预置若干实体，让 agent 搜到指定的那个。压综搜/垂搜。
- **T6 · 多工具编排**：一句话要求跨 function+memory+document 协作完成，压工具选择在大工具面下的准确率。
