---
id: DOC-114
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-05
review-due: 2026-09-01
audience: [human, ai]
---
# @-Mention Domain — 实体引用快照与发送即冻结

> **核心职责**：Mention 让用户在对话里用 `@` 引用一个实体，**在发送瞬间抓取其内容快照**注入这条消息的 LLM 上下文。Mention 是一个**纯 domain 契约**：定义可 @ 的类型集、前端 input、解析后的 Reference、各实体 app 实现的 Resolver 接口——解析与渲染在消费方（各域 resolver + chat），本包无 app / store / handler / error。

---

## 1. 物理模型

Mention **无独立表**：解析后的 `Reference` 快照存在 `messages.attrs` 里（随消息持久化，由 chat 波次 5 落地）。

### 1.1 可 @ 的类型（封闭集 · 5 种）
四件套 + 知识文档——**用户锻造的、有可注入内容快照的实体**：

| `MentionType` | `@` 注入的内容 |
|---|---|
| `document` | markdown 正文 |
| `function` | 描述 + 代码 |
| `handler` | 描述 + 方法/代码 |
| `workflow` | 图定义 |
| `agent` | 配置/定义 |

> 不可 @：`conversation`（对话流无单一快照）、`skill` / `mcp`（外部能力，是「调用」非「引用内容」）。

### 1.2 三个类型
```go
MentionInput{ Type, ID }              // 前端发来:只 type + id
Reference{ Type, ID, Name, Content }  // 解析后的快照(Content=各类型自渲内文)
Resolver{ Type(); Resolve(ctx, id) }  // 各实体 app 实现
```

---

## 2. 核心原理

### 2.1 Freeze-on-Send（发送即冻结）
**不支持动态引用**（LLM 生成时再查最新）。用户点「发送」的瞬间，chat 调各域 `Resolver` 抓取实体**当前内容**快照、附在该回合输入里。即使实体 10 分钟后被改/删，这条历史消息里「当时所见」始终一致。

### 2.2 注册表式扩展（各域 Resolver）
mention domain 不持业务逻辑，只定义 `Resolver` 接口。**5 个实体域各实现一个**（`AsMentionResolver()`），boot 时注册进 chat 的 type→resolver 注册表。chat 收到 `@` 数组 → 遍历调对应 resolver → 拿 `Reference`。

### 2.3 统一渲染 + 快照标记
chat 把所有 `Reference` 渲成**统一**的 `<mentions>` 块（不是各类型不同标签）：
```xml
<mentions>
<mention type="function" id="fn_x" name="greet">
(snapshot at 2026-06-05T...)
<函数描述 + 代码>
</mention>
</mentions>
```
- **代码类**（function/handler/workflow/agent）带 `(snapshot at 时间)` 标记，提示 LLM「这是快照，改前先 get 最新」。
- **document** 是静态参考，不带快照标记。
- 实体加载失败 → `[引用的实体无法加载]`，**不中断**消息发送。

---

## 3. 生命周期
1. **选点**：前端输入 `@` → 调 catalog / 搜索选中实体。
2. **提交**：`POST /messages` body 带 `mentions` 数组（`[{type, id}]`）。
3. **解析**：chat 遍历数组 → 各域 `Resolver.Resolve(id)` 抓 `Reference`。
4. **注入**：渲成 `<mentions>` 块拼进 wire prompt。
5. **持久化**：`Reference` 快照存进 `messages.attrs`。

---

## 4. 跨域集成
- **chat（波次 5）**：主消费者 + 流程控制——持注册表、发送时解析、渲染注入。
- **5 个实体域（波次 3）**：各实现 `Resolver` 提供快照。
- **catalog**：前端 `@` 自动补全的备选来源（前端行为）。

> Mention **不依赖 relation**，也**不产生任何 relation 边**（@ 是消息内的内容快照，非实体拓扑关系）。

---

## 5. 错误
mention domain **不持任何 error**（纯契约）。消费时的错误由 **chat** 处理：resolver 未注册 / input 类型非法 / 实体解析失败（回退「无法加载」stub，不中断）——见 chat（波次 5）。
