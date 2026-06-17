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

# Iteration Loop —— Finding 账本（append-only）

> 每条 finding：证据（轨迹 seq）+ 定位（哪一层）+ 提案 + 状态（`open` / `proposed` / `fixed` / `regression-case`）。
> **只增不删**（同 D1 Log 语义）。新发现追加在末尾。先读这里，别重复挖。

## 元发现 · 为什么这个 loop 值得（2026-06-18）

第一圈（T1+T2，deepseek-v4-flash）即证明：**轨迹判官抓得到 code-based 终态测试瞎掉的真 finding**。`golden J5` 对 T2 那条轨迹只断言「版本 >1」→ 绿；但模型中途把 `get_function` 调错、绕一圈才恢复——**终态测试看不见，轨迹判官看见了**（F1）。这是这个 loop 的核心价值证明：同样的结果状态，轨迹质量的差距只有智能判官抓得到。

## F1 · get_function 按名查的 affordance / 描述缺口 【hard · open】
- **来源**：T2（`TestSelfIter_FixBuggyFunction`），`/tmp/anselm_selfiter/fixbuggy.messages.json` seq 3。
- **现象**：模型首调 `get_function` 传 `{"search_function_id":"buggy_double"}`——**发明了不存在的参数 `search_function_id`，且传名字而非 `fn_` id** → 报错 `functionId is required` → 恢复（`search_function` 拿 id → 重调成功）。
- **根因**：模型调用前只看到 system prompt 那一行 `get_function: Get one function with its active version (code, parameters...)`——**没说要 `fn_` id、要先 `search_function` 换 id**。模型从名字出发就猜了个融合参数。它发明的 `search_function_id` 正是它想要的 affordance（按名查）。
- **定位**：tool 描述层（`get_function` 的 `Description()`，`backend/internal/app/tool/...`）+ 可选 tool 设计层（`.go`，让 get_function 接受 name 或 id）。
- **提案**：
  - **便宜版（描述）**：改一行 → `get_function: Get one function by its fn_ id (use search_function first to resolve a name→id) — returns code, parameters, ...`。大概率消掉这次失败调用。
  - **深版（.go）**：让 `get_function` 接受 `name | id`，合并 search→get 两步。
- **状态**：open（待提 PR + 人 review）。修后 T2 成 regression case。

## F2 · 工具 resident vs searchable 措辞被半误读 【soft · open】
- **来源**：T1（`TestSelfIter_BuildRunFunction`），`buildrun.messages.json` seq 5。
- **现象**：模型 reasoning 说 "I already have the create_function tool definition in my system prompt"，随即又 `search_tools` 拉它。system prompt 实际只给了 create_function **一行用途**（它在 "Searchable tools" 下），并非全定义。模型半误读了 resident/searchable 边界，但**行为正确**（还是搜了，没硬调）。
- **定位**：system prompt `<section name="tools">` 措辞（`buildrun.systemprompt.json`，"Resident tools are always available. Other tools are listed below by name and one-line purpose only..."）。
- **提案**：措辞更刀地分「resident（全定义已在）」vs「searchable（只列名+用途，用前必 search_tools）」。低优先（行为已正确）。
- **状态**：open（soft）。

## F3 · 简单任务 ~75K input token 【signal · watch】
- **来源**：T1 79,191 / T2 72,845 input tokens（`*.usage.json`）。
- **现象**：trivial 任务烧 ~75K input token。主因：`search_tools` 返回的**冗长工具 schema**（深转义 op-shape 串，~2KB/个）进 history 后，每个 loop 回合（约 6 轮）重发。
- **定位**：lazy-load schema 体积 + 历史投影。可考虑：工具用过即把其 `search_tools` 结果 demote 到 warm/cold；或精简 op-shape 示例。
- **状态**：watch（非 bug，跨版本盯成本趋势线）。
