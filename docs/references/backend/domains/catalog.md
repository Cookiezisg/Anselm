---
id: DOC-103
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-05
review-due: 2026-09-01
audience: [human, ai]
---
# Capability Catalog Domain — 能力概览（实体名录）

> **核心地位**：Catalog 是 Forgify 的**能力概览**——它只回答大模型一个问题：「你现在有哪些实体？」把 Function / Handler / Workflow / Agent / Skill / MCP / Document 各域的实体聚合成一份「名字 + 描述」的分组清单，注入 chat system prompt，让 LLM 知道自己的能力存在。**它刻意不做精确引用**：要真正用某个能力，LLM 去调对应的搜索工具。

---

## 1. 物理模型

Catalog 是**纯派生视图，不持久化、不缓存、按需现查**（无 store、无表）。

### 1.1 `Item`（一条能力）
```go
type Item struct {
    Source      string // 实体类型（分组用）："function" / "workflow" / ...
    ID          string // 主键（仅进 Coverage，不渲染给 LLM）
    Name        string
    Description string
}
```

### 1.2 `Catalog`（聚合结果）
```go
type Catalog struct {
    Summary  string              // 注入 system prompt 的分组菜单文本
    Coverage map[string][]string // source → ids，供 HTTP 巡检（不进 Summary）
}
```

---

## 2. 核心原理

### 2.1 多源聚合（`CatalogSource`）
catalog 定义窄接口 `CatalogSource{ Name(); ListItems(ctx) }`，**7 个实体域各实现一个**（function/handler/workflow/agent/skill/mcp/document），`RegisterSource` 注册、`build()` 时遍历聚合。
- **粒度与调用方式不归 source 管**——它只交「名字 + 描述」。
- 各 source 的 `ListItems` 经 orm 层按 workspace 自动隔离（本层不传 workspace id）。

### 2.2 只报名字 + 描述
菜单**只渲染 Name + Description**，按实体类型分组：
```
You currently have these capabilities (to use one, search with the matching tool):

### function
- **greet**: 发送问候
- **poll_inbox**: 轮询收件箱

### workflow
- **deploy**: 自动部署

### document
- **spec**: /Projects/Q1/spec
```
- **不报 id、不报调用工具**：catalog 不负责精确指认。
- **document 例外**：Name = 文档名，Description = 路径（让 LLM 看懂层级关系）。
- 描述按 rune 截断（48），防单条啰嗦撑大 prompt。
- 空库：整段不输出（全新 workspace 无 header 下空白怪态）。

### 2.3 两段式：概览 → 搜索
catalog 只让 LLM **知道能力存在**；要真正定位 + 调用，LLM 调对应**搜索工具**（`search_function` 等，波次 2）拿到精确实体（含 id / 详情），再调用。所以：
- catalog 菜单**重名无所谓**（两个 `deploy` 只是告诉 LLM「你有俩部署流」，搜索时区分）。
- 因此 **id 不进菜单、name 不要求唯一**——都不需要。

### 2.4 容错
- **部分 source 失败**：跳过它，用成功的渲染。
- **全部 source 失败**：`ErrAllSourcesFailed`（系统故障，503）。
- chat 注入若失败：返 `""`，对话照常（无能力段）。

---

## 3. 生命周期
1. **装配**：boot 时各实体域 `RegisterSource`（波次 3）。
2. **现查**：`GET /api/v1/catalog`（巡检）或 chat 开场（`GetForSystemPrompt`）→ `build()` 现扫所有 source。
3. **失效**：无——派生视图，下次现查自然反映最新（实体增删改不需要通知 catalog）。

---

## 4. 跨域集成
- **chat（波次 5）**：最重要消费者，经 `SystemPromptProvider.GetForSystemPrompt` 注入提示词。
- **搜索工具（波次 2）**：catalog 的下游——LLM 看完概览去搜。
- **7 个实体域（波次 3）**：各实现 `AsCatalogSource()` 提供「名字 + 描述」并 `RegisterSource`。

---

## 5. 错误字典

| Sentinel | Wire Code | HTTP | 场景 |
|---|---|---|---|
| `ErrAllSourcesFailed` | `CATALOG_ALL_SOURCES_FAILED` | 503 | 所有 source 失败（系统故障，如 DB 不可达）|
