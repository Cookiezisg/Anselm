# Round 0022 — catalog（波次 1 · M1.5）能力概览聚合层

类型 / 目标：M1.5 catalog 模块新建——能力概览（实体名录）。考古旧实现 + 多轮讨论大幅收窄。

## 核心方针（一句话）
**catalog 只回答「你有哪些实体」——每个实体只报名字+描述、按类型分组；精确定位+调用全部下放给搜索工具。**

## 关键设计决策（经讨论拍板）
1. **职责收窄到极致**：catalog = 纯「能力概览」，告诉 LLM「有什么」，不管「怎么调」。砍 `InvokeTool`（调用是搜索工具/调用层的事）。
2. **只报名字 + 描述**：实体强制有 name+description，故砍描述回退链；砍所有花活——handler 方法列表/配置态、mcp 工具合成、Kind(polling 后缀)、Active([INACTIVE])。
3. **两段式：概览 → 搜索**：catalog 让 LLM 知道能力存在，真用走 `search_*`（波次 2）拿精确实体。故 **id 不进菜单、name 不要求唯一**（重名无所谓，搜索区分）——化解了 id/唯一性的纠结。
4. **document 例外**：Name=文档名，Description=路径（让 LLM 看懂层级）。
5. **砍预留**：`Generator` seam（压缩/检索）+ `GeneratedBy`（恒 mechanical）+ `Granularity`（PerItem/PerServer，仅喂 Generator，assemble 无视）+ `Category`（仅喂 Generator）+ `activate_tools`（文档预留）全砍。YAGNI + 单机定位。
6. **无 store 沿用**：派生视图、按需现查、不缓存。

## 考古发现（旧文档历史错误）
- 标题「…与 RAG 索引」——代码明确无 RAG。
- §4「Relation：依赖 RelGraph 判定活跃度」——catalog 根本不 import relation，虚构依赖。
- CatalogItem 有 `kind` 字段——代码 Item 用 `Source`。
- 错误字典列 `ErrItemNotFound`——无对应端点；`ErrAllSourcesFailed` 旧为 `errors.New` 走 500 未映射。

## 新实现
- **domain/catalog**：`Item{Source,ID,Name,Description}` + `CatalogSource{Name,ListItems}` + `Catalog{Summary,Coverage}` + `SystemPromptProvider` + `ErrAllSourcesFailed`(S20, KindUnavailable 503)。
- **app/catalog**：`Service`(RegisterSource + build 遍历聚合 + Get + GetForSystemPrompt) + `mechanical.assemble`(按类型分组渲染、无 id/无调用工具、空库不输出、desc 截断 48)；砍 Generator；去显式 GetUserID(orm 自动隔离)。
- **handler**：`GET /api/v1/catalog`。

## 测试
app 6：多源聚合+分组+name 排序+无 id 泄漏+coverage 含 id、全失败 ErrAllSourcesFailed、部分失败用成功的、空库空 summary、无 source 不报错、GetForSystemPrompt 失败返 ""。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./...` 0 · `go test ./... -race` 全 ok。

## 契约（无对外破坏性变更，端点不变）
domains/catalog.md 整篇重写；error-codes.md `ErrAllSourcesFailed` 从未映射清单→正式 503 表行(`CATALOG_ALL_SOURCES_FAILED`)；api.md `GET /catalog` 已一致；catalog 无表，database.md 不涉及。

## 是否更干净
旧：6 字段 Item（Category/Kind/Active/Granularity）、Generator/GeneratedBy 空预留、InvokeTool 越界管调用、文档 RAG/虚构依赖、ErrAllSourcesFailed 未映射。
新：4 字段 Item、纯名字+描述概览、职责单一（不管调用）、两段式下放搜索、错误正确 503。✅

## 遗留 / 下一步
- **M1.6 mention**（波次 1 续）。
- 7 个实体域 `AsCatalogSource()` 实现 + boot `RegisterSource` → 波次 3；强制实体 name+description（创建校验）→ 各实体域；真用走 `search_*` → 波次 2。（见 deps-todo）
