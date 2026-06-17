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

# Iteration Loop —— 任务索引（一行一条）

> **规范（强制）**：一个 task = **一行**。完整 prompt / 完整预期 / 后端查询写在 **test 文件的注释**里（`testend/golden/selfiter_*_test.go`），本表只做索引 + 一句话预期。
> 选任务原则：**端到端压全栈**（非孤立工具 ping），覆盖 tool 质量 **AND** 整套工程（build/sandbox/durable/handler/trigger/search）。理想多轮（user-simulator 带目标聊 N 轮）。
> 状态：`✅` 跑过 · `▶` 待跑 · `↻` 回归集。

| ID | 任务（一句话） | 压什么 | test | 预期（一句话） | 后端 ground-truth | 状态 |
|---|---|---|---|---|---|---|
| T1 | 造 `add(a,b)` 并跑通 | tool 选择/参数 + build/sandbox | `TestSelfIter_BuildRunFunction` | create_function → run(a=2,b=3) → 报 5 | `/functions` 建了 + run 真返 `{sum:5}` | ✅ |
| T2 | 修埋雷 `buggy_double` | 诊断 + edit + 恢复 | `TestSelfIter_FixBuggyFunction` | search→get(id)→edit(n*2)→run(4)→8 | 版本 >1 + 新 code 是 `n*2` + run 返 `{out:8}` | ✅↻ |
| — | F1 回归（按名查 function/handler） | tool 参数（id 解析） | `TestConfirmF1_*` / `TestConfirmF1Batch_*` | search_X→get_X(xId) 一次对 | get_X 零 error | ↻ |
| T3 | workflow + durable 崩溃恢复 | durable 引擎 | _待写_ | 造 fn→串 workflow→trigger→approval→kill-9→恢复 | `/flowruns/{id}` 节点真 advance + 恢复到 completed | ▶ |
| T4 | handler 常驻 + call method | 有状态进程 + RPC | _待写_ | create_handler→call→对值 | `/handlers/{id}` + 执行记录对 | ▶ |
| T5 | search RAG 检索 | 综搜/垂搜 | _待写_ | 预置实体→agent 搜到指定那个 | 索引可见 + 报的名=实际名 | ▶ |
