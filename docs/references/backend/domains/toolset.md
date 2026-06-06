---
id: DOC-303
type: reference
status: active
owner: @weilin
created: 2026-06-06
reviewed: 2026-06-06
review-due: 2026-09-01
audience: [human, ai]
---
# Toolset — 工具懒加载（目录卡 + 按需 search，无按类激活）

> **核心地位**:解决"工具太多 / Parameters schema 太大撑爆 context"——把系统工具分**常驻(resident)**与**懒加载(lazy)**。Resident 完整定义每回合都在;Lazy 默认只以"一行概览(name + 一句话 description)"出现,LLM 调 `search_tools` 才取某工具的**完整定义**(含大 Parameters schema)。
>
> **设计哲学(2026 调研收敛)**:业界(Anthropic Tool Search Tool / LangChain bigtool / LlamaIndex / MCP-Zero)已收敛到**语义/检索式按需加载**,**"按类激活整组"是被淘汰的 legacy**(它仍把整组 schema 锁进整对话、粗粒度、还是 bloat)。Forgify 采**检索式 + 概览常驻**:比纯 Tool Search Tool(defer 全部、盲搜、实测召回 ~64%)更稳——**概览常驻让 LLM 知道全集、精确取而非赌检索命中**。

---

## 1. 物理布局

```
backend/internal/app/tool/toolset.go        # Toolset{Resident, Lazy} + Overview() + FindLazy() + All()
backend/internal/app/tool/toolset/search.go # search_tools 工具 + rankLazy 关键词排序
backend/internal/pkg/agentstate             # discoveredTools(search 已浮出的工具，host 后续回合纳入)
```

`Toolset` 是 `app/tool` 包的数据结构;`search_tools` 是 `tool/toolset` 子包的工具适配器(同 filesystem/search/web)。

---

## 2. 三个部件

### 2.1 `Toolset{Resident, Lazy []Tool}`
- **Resident**:完整定义(name + description + Parameters)每个 LLM 回合都在 —— core 工具(Read/Write/Edit/LS/Glob/Grep/Web/Bash)+ `search_tools` 自己
- **Lazy**:扁平 `[]Tool`(**砍了旧的 `map[category][]Tool` 按类分组**)—— 默认不进 context,只出概览
- `Overview() []ToolBrief`:把每个 lazy 工具投影成 `{Name, Description}`(**不含 Parameters**)—— host 注入 system prompt 的目录卡
- `FindLazy(name)`:供 `search_tools` 取命中工具的完整定义
- `All()`:Resident + Lazy 展平,给工具总览 handler

### 2.2 `search_tools` 工具(resident)
- 参数:`query`(LLM 用关键词/短语描述要找的能力)
- 逻辑:`rankLazy` 在 lazy 工具的 `name + description` 上**大小写不敏感关键词重叠打分** → top-K(默认 5)→ 返回命中工具的**完整定义 JSON**(`{tools:[{name,description,parameters}]}`)+ 对每个调 `agentstate.MarkToolDiscovered`
- 无匹配 → 可操作字符串("No tools matched … try different keywords"),非错误
- **纯关键词、无 embedding**:LLM 从概览自拟 query,本地 lazy 全集小到词法排序即够;向量检索留作"实体上千、概览放不下"时的增强

> **编写规范**:lazy 工具的 `Description()` 写成**一句话概括**(目录卡用),详细参数说明放 `Parameters()` 各字段的 description——这样目录卡小、细节在按需取的 Parameters 里。

### 2.3 `agentstate.discoveredTools`
- `MarkToolDiscovered(name)` / `IsToolDiscovered(name)` / `DiscoveredTools()`
- 记本次运行 `search_tools` 浮出过哪些工具 → host 后续回合把它们纳入 LLM 工具列表(发现的工具可继续调,无需重搜)

---

## 3. 完整工作流(图书馆类比)

```
system prompt 注入目录卡（Toolset.Overview，host 波次 5）：
  run_function     — Run a user-defined function by id with arguments.
  trigger_workflow — Start a workflow run by id.
  call_mcp_tool    — Call a tool on a connected MCP server.
  …（约 48 个 lazy 工具，一行一个，只有 name + 一句话）

LLM 想跑某个 function：
  ① 看目录卡 → 知道有 run_function（知道全集，不盲搜）
  ② search_tools("run function") → 返回 run_function 完整定义（含 Parameters）+ 记 discovered
  ③ 下一回合 host.Tools = resident + discovered → run_function 进列表
  ④ run_function(functionId, args) 调用
```

**省 token 的账**(~48 lazy 工具):常驻只花 48 行简述(一两千 token),而非 48 份完整 Parameters schema(上万 token);用哪个才取哪个的完整 schema。

**两份概览,别混**(与 catalog 正交):
- **本文档的工具目录卡**:LLM 会哪些**操作**(run_function / search_workflow / call_mcp_tool…),**固定**(动词×实体类)
- **catalog(DOC,实体名录)**:有哪些**实体实例**可操作(function "处理Excel"…),**动态**(随用户建的实体)
- LLM 干活两者都要:工具目录知道"能 run_function",catalog 知道"有哪个 function",再 search 取 run_function 完整 schema → 调用

---

## 4. 为什么砍掉 `activate_tools` 按类激活

旧设计:`activate_tools(category)` 让 LLM 激活整组(function/handler/…),整组 schema 加载、锁定整对话,激活状态记 `agentstate.activatedGroups`。

**2026 调研(对抗式核实)否定它**:
- 整组激活仍把**整组**的完整 schema 灌进 context(粗粒度,没真省);锁定整对话(state-heavy);LLM 还得先"选对组"
- 检索式只取 3-5 个**逐个相关**的工具(跨组无所谓),且可随任务重搜
- MCP-Zero:让模型**自己写检索 query**比"按类/按 user-query 一次性选"高 20-30 点准确率

所以 `activate_tools` + `Toolset.Lazy map[category]` + `agentstate.activatedGroups` **整套删除**,换成 `search_tools` + 扁平 `Lazy` + `discoveredTools`。

---

## 5. 现状与跨域接线

**当下 lazy 为空**:core 工具(filesystem/search/web)全 resident;lazy 实体工具(run_function/trigger_workflow/call_mcp_tool…)**波次 3 才建**。本轮搭好机制(Toolset/search_tools/discoveredTools),用 fake lazy 工具测;波次 3 上架真工具即用。

| 接线 | 当下 | 实接 |
|---|---|---|
| lazy 实体工具进 `Toolset.Lazy` | 机制就位 | 波次 3 各实体域(tool/function 等) |
| 目录卡(`Overview`)注入 system prompt | `Overview()` 已提供 | chat host M5.2 |
| `host.Tools(ctx)` = resident + discovered lazy | `DiscoveredTools()` 已提供 | chat host M5.2(loop 的 `AutoActivator` 钩子) |
| discoveredTools 跨 run 持久 | 本 run 内有效 | chat host M5.2:`LoadHistory` 重放历史 `search_tools` 调用重建(durable，不靠内存缓存) |
| `search_tools` 装进 resident | `NewSearchTools(ts.Lazy)` | server boot M7 / chat host |

---

## 6. 测试矩阵(全离线)

- **toolset**(tool_test):`All()` resident-first · `Overview()` 返 name+desc(无 params)· `FindLazy` 命中 lazy / resident 返 nil / 未知返 nil
- **search_tools**:`ValidateInput`(空 query)· Execute 命中返完整定义(含 Parameters)+ 记 discovered · 无匹配返引导 · 无 AgentState 容忍 · `rankLazy` 打分排序 + limit 截断
- **agentstate**:discoveredTools 往返 + 并发 MarkToolDiscovered

---

## 7. 决策快照

- **检索式 > 按类激活**:2026 调研业界收敛检索式,activate_tools 是 legacy(整组锁定、粗粒度、仍 bloat)——整套删
- **概览常驻补召回**:纯 Tool Search Tool defer 全部盲搜(~64% 召回);Forgify 目录卡常驻 → LLM 知全集、精确取,召回稳
- **无 embedding**:lazy 全集小 + LLM 自拟 query,关键词排序够;向量留 scale 增强
- **lazy = 扁平 []Tool**:砍按类分组(配合 activate_tools 的,不要了)
- **Description = 简述、Parameters = 大头**:目录卡用 Description(短),lazy 省的是 Parameters schema(详细参数)。约定:lazy 工具 `Description()` 写一句话概括(目录卡可读),详细参数说明放 `Parameters` 各字段的 description
- **discoveredTools 而非 activatedGroups**:按工具名记(细粒度),非按组;跨 run 由 host 从历史重放重建(durable)
- **无 HTTP 端点 / DDL / 错误码**:工具失败软返 tool-result 串
