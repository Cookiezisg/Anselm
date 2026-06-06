---
# Round 0036 — tool/toolset：砍 activate_tools 按类激活 → search_tools 检索式懒加载（波次 2 收官）

类型 / 目标:M2.3 叶子工具第 4 个（波次 2 最后一个）——`tool/toolset`。**深度调研(103 agent / 25 声明对抗式核实)后改判**:砍掉旧 `activate_tools` 按类激活(被业界淘汰的 legacy),换成**检索式懒加载**:Toolset 扁平 Lazy + `search_tools` 工具(LLM 自拟 query 关键词检索)+ agentstate `discoveredTools`。波次 2 收官。

## 核心方针(一句话)
**工具懒加载 = 目录卡(name+一句话,常驻)+ `search_tools` 按需取完整定义(含大 Parameters schema)+ discoveredTools 记账;砍 activate_tools 按类激活,与 catalog(实体名录)正交互补。**

## 背景:为什么改判(用户质疑 + 调研)
- 用户质疑旧 `activate_tools`"按类激活、只增不减、整组锁定"不合理。
- 跑 deep-research(Anthropic Tool Search Tool / LangChain bigtool / LlamaIndex / ToolLLM / MCP-Zero):**业界 2024-2026 收敛到语义/检索式按需加载,"按类激活"无人推荐(legacy)**。硬伤:整组激活仍把整组 schema 灌进 context、锁定整对话、粗粒度。MCP-Zero:让模型**自己写检索 query** 比按类/按 user-query 一次性选高 20-30 点准确率。
- 用户洞察:**LLM 得先知道有哪些工具**(否则纯 defer 盲搜召回仅 ~64%)→ 概览常驻补召回。
- 用户纠正:**catalog 只查实体**(function/workflow 实例),工具(尤其 lazy)需要**自己的"基本描述概览"**——两份正交的地图(工具能力 vs 实体实例)。

## 关键决策(用户拍板）
1. **三层最终设计**:① resident 工具完整常驻(core + search_tools)② 两份概览常驻轻量(工具目录卡 `Overview` + catalog 实体名录)③ 按需取完整(`search_tools` 取 lazy 工具完整定义)。
2. **砍 `activate_tools` + `Toolset.Lazy map[category]` + `agentstate.activatedGroups`**(整套按类激活,旧 backend 的 activate.go 不迁)。
3. **`Toolset.Lazy` 扁平 `[]Tool`** + `Overview()`(name+desc 目录卡,不含 Parameters)+ `FindLazy(name)`。
4. **`search_tools` 工具**:query → `rankLazy` 关键词重叠打分 → top-5 → 返完整定义 JSON(含 Parameters)+ `agentstate.MarkToolDiscovered`。**纯关键词、无 embedding**(LLM 自拟 query + lazy 全集小;向量留 scale 增强)。
5. **`agentstate.discoveredTools`**(替 activatedGroups,按工具名细粒度)。跨 run 持久由 host 从历史重放 search_tools 调用重建(durable,不靠内存缓存)。
6. **Description=简述、Parameters=大头**:目录卡用 Description(短),lazy 省的是 Parameters schema。

## 新实现
- `tool/toolset.go`:`Toolset{Resident, Lazy []Tool}`(Lazy 扁平)+ `ToolBrief` + `Overview()` + `FindLazy()` + `All()`。
- `tool/toolset/search.go`(★新子包):`SearchTools` 工具(5 方法)+ `NewSearchTools(lazy)` + `rankLazy`(关键词打分,min limit)。
- `pkg/agentstate`:加 `discoveredTools` + `MarkToolDiscovered`/`IsToolDiscovered`/`DiscoveredTools`(渐进第二块:SeenFiles→filesystem、discoveredTools→toolset)。
- tool_test:`TestToolset_All` 改扁平 Lazy + 加 `TestToolset_OverviewAndFindLazy`。

## 测试(全离线)
- toolset(tool_test）：All resident-first / Overview(name+desc 无 params) / FindLazy(命中 lazy、resident 返 nil、未知 nil)。
- search_tools 5：ValidateInput / Execute 命中返完整定义(含 Parameters functionId)+ 记 discovered / 无匹配引导 / 无 AgentState 容忍 / rankLazy 打分排序 + limit。
- agentstate 2：discoveredTools 往返 / 并发 MarkToolDiscovered。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet` 0 · `go test -race -count=1 ./internal/app/tool/... ./internal/pkg/agentstate/...` 全绿(tool 2.4s / filesystem 2.7 / search 3.2 / toolset 3.6 / web 4.1 / agentstate 4.5)。

## 契约
- `domains/toolset.md` **新建**(DOC-303):三层设计 + 目录卡 + search_tools + 砍 activate_tools 论证 + 与 catalog 正交 + 决策快照。
- `contract-changes #16`(工具发现机制:LLM 通过 search_tools 检索而非 activate_tools 按类激活;前端工具气泡多 `search_tools` 一个常驻工具)。
- S18:lazy 工具 Description 写一句话简述规范(toolset.md §7 自述,不动 CLAUDE.md)。
- 无新 HTTP 端点 / 无 DB 表 / 无 error code。

## 跨波次接线
- **lazy 实体工具进 Toolset.Lazy** → 波次 3 各实体域(tool/function 等)。
- **目录卡注入 system prompt + host.Tools 组装(resident + discovered)** → chat host M5.2(loop AutoActivator 钩子)。
- **discoveredTools 跨 run 从历史重建** → chat host M5.2 LoadHistory。
- **search_tools 装进 resident** → server boot M7 / chat host。

## 波次 2 收官 🎉
M2.1 tool ✅ → M2.2 loop ✅ → M2.3 #1 filesystem ✅ · #2 search ✅ · 搜索配置 ✅ · #3 web ✅ · **#4 toolset ✅** → **波次 2(tool + 执行原语)全部完成**。下一站波次 3 Quadrinity 执行体。
