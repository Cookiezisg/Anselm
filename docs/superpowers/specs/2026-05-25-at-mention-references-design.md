# @-Mention 引用：把实体内容快照进消息 — 设计

> Date: 2026-05-25 · Status: 待用户审 · Scope: 后端 chat + 4 个 MentionResolver + 前端 composer 收尾

---

## 1. 背景与问题

用户在 chat 里 `@` 一个实体，应把该实体的内容拉进对话上下文。现状是**半成品 + 断链**：

- **前端**：composer（plain textarea + `@` 正则）已有 mention pool，覆盖 5 类（function/handler/workflow/skill/document），选中渲染成 chip。但 `ChatPane` 发送时 `body.mentions = mentions.map(m => m.id)` —— **只发 id，类型丢了**。
- **后端**：**完全没有 mention 处理**。且 `sendMessageRequest` 只有 `{Content, AttachmentIDs}`，`decodeJSON` 用 `DisallowUnknownFields()`（严格）—— 所以前端一旦真发 `mentions` 字段，**后端直接 422 拒收**。@ 目前端到端是断的。
- **document 的特殊性**：document 不在 catalog、也没有任何 LLM 工具（无 `read_document`）能够到 —— @ 是 LLM 接触文档的**唯一**路径（这正是我们把 document 移出 catalog 的原因）。

## 2. 目标

通用 @-mention：用户 @ 一个实体（document / function / handler / workflow）→ 发送时把它的内容**快照**进这条用户消息 → 之后就是普通历史消息，LLM 自然看得到，**零每轮重注入**。

## 3. 范围

**可 @ 4 类**：

| 类型 | 注入内容（结构化块） | 来源 |
|---|---|---|
| **document** | name + description + **正文 markdown** | `documentapp.Service.Get` → `Document.Content` |
| **function** | name + description + 入参签名 + **代码** | `functionapp.Service.Get` → `Function.Code` |
| **handler** | name + description + **方法列表（签名）** + init-args schema | `handlerapp.Service.Get` → `Handler.Methods` / `InitArgsSchema` |
| **workflow** | name + description + **节点/边定义** | `workflowapp.Service.Get` → `Workflow` active `Graph`（Nodes/Edges）|

**不做**：
- **skill**：有 `activate_skill`（LLM 自驱按需加载）+ 在 catalog 露名；@ 它的正文 = 跟自身机制打架。
- **mcp**：有 `search_mcp_tools` / `call_mcp_tool`。
- 判据：**"LLM 自己有工具能拉的就不 @"**。document 无工具 → 必须；trinity 有 `get_X` 但**产品上"指着代码问"是核心交互**，接受冗余保留；skill/mcp 有更重的 activation，排除。

**代码类的 stale 处理**：function/handler/workflow 的块带一句 `(snapshot at <消息发送时间>)`，提示 LLM"要改先 get 最新"。单用户基本是当前版，标注零成本。

## 4. 设计

### 4.1 数据模型（零迁移）

Message 已有 `Attrs map[string]any`（`gorm:"type:text;serializer:json"`），attachments 就存在 `Attrs["attachments"]`。**mentions 同构存 `Attrs["mentions"] = []mentiondomain.Reference`**，无新表、无 schema 改动。

```go
// internal/domain/mention/mention.go（新包，参照 domain/catalog）
type MentionType string
const (
    MentionDocument MentionType = "document"
    MentionFunction MentionType = "function"
    MentionHandler  MentionType = "handler"
    MentionWorkflow MentionType = "workflow"
)

// Reference is the resolved snapshot stored on the message + rendered into the transcript.
//
// Reference 是存进消息、渲进 transcript 的已解析快照。
type Reference struct {
    Type    MentionType `json:"type"`
    ID      string      `json:"id"`
    Name    string      `json:"name"`
    Content string      `json:"content"` // 类型自渲染的内文（代码/正文/方法/图）；快照
}

// Resolver is the port each capability app implements; chat holds a type→resolver registry.
//
// Resolver 是各 app 实现的端口；chat 持 type→resolver 注册表。
type Resolver interface {
    Type() MentionType
    Resolve(ctx context.Context, id string) (*Reference, error)
}

var ErrNotFound = errors.New("mention: referenced entity not found")
```

### 4.2 端到端数据流

```
前端：@ 选 {type, id} → onSend { content, mentions: [{type,id}, ...] }
后端 ChatHandler.SendMessage：sendMessageRequest 加 Mentions []MentionInput{Type,ID}
  → chatapp.Service.Send(ctx, convID, SendInput{Content, AttachmentIDs, Mentions})
      → 对每个 mention：resolvers[type].Resolve(ctx, id) → Reference（快照）
        · not-found → 存 stub Reference{Name:"(已删除)", Content:""}，不阻断
      → 存进 user Message 的 Attrs["mentions"] = []Reference
组 LLM transcript：chatapp history.buildUserLLMMessage（已存在）
  → 现有顺序：text blocks → attachments
  → 新增：在 text blocks 之后渲染 Attrs["mentions"] 成 XML text part
之后：普通历史消息，buildUserLLMMessage 每轮只读已存快照 + 渲染，零重解析
```

### 4.3 架构（与 catalog 对称）

- 端口 + Reference 定义在 `internal/domain/mention/`（参照 `domain/catalog` 的 `CatalogSource` + `Item`）。
- 每个 app 实现 `Resolver`：`functionapp.AsMentionResolver()` / `handlerapp...` / `workflowapp...` / `documentapp...`（小适配器：调 `Service.Get` + 按类型渲染 `Content`）。
- `chatapp.Service` 持 `mentionResolvers map[MentionType]mentiondomain.Resolver` + `RegisterMentionResolver(r)`（参照 `RegisterSource`）。
- main.go 装配：`chatService.RegisterMentionResolver(documentService.AsMentionResolver())` ×4。
- **解析时机**：Send（消息创建）时一次性解析 + 快照存盘。`buildUserLLMMessage` 只读存好的快照渲染，**不重解析**（这就是"快照 + 历史原生"）。

### 4.4 渲染格式（镜像 `RenderAttachedAsXML`）

外层统一、内文各类型自渲（"处理方式不一样"落在 `Content`）：

```xml
<mentions>
<mention type="function" id="f_1" name="csv_clean">
(snapshot at 2026-05-25T16:00:00Z)
description: 清洗 CSV，去 BOM
def csv_clean(args): ...
</mention>
<mention type="document" id="doc_9" name="Q1-planning">
[文档正文 markdown]
</mention>
</mentions>
```

作为一个 `ContentPart{Type:"text"}` 追加进 `buildUserLLMMessage` 的 parts（text blocks 之后）。

### 4.5 前端收尾

- `mentionPool` **去掉 skill**（剩 function/handler/workflow/document）。
- mention 对象保留 `{type, id, label, icon}`；`ChatPane` 发送改为 `mentions: picked.map(m => ({ type: m.type, id: m.id }))`（现在丢了 type）。
- chip 显示不变。

## 5. 错误处理

| 情况 | 处理 |
|---|---|
| @ 的实体发送前被删 / Get 返 not-found | 存 stub `Reference{Type,ID,Name:"(已删除)",Content:""}`；渲染成 `<mention ... name="(已删除)">[引用的实体已不存在]</mention>`；**不阻断发消息** |
| 未知 type | Send 时跳过该 mention + log Warn（前端只会发 4 类，属防御）|
| resolver Get 其它错误 | 同 not-found 兜底（存 stub）；不让一条坏引用毁掉整条消息 |

## 6. 不做 / Out of scope

- skill / mcp @（自有 activation/工具机制）。
- 会话级钉住：`conversation.AttachedDocuments`（每轮 live 重注入）已覆盖"整个对话常驻"语义；@ 是每消息快照，互补，不动它。
- token 预算机械裁剪：快照 + 文档 1MB 上限是天然边界，YAGNI。
- `read_document` LLM 工具：**故意不加** —— document 保持 @-only（与"移出 catalog"逻辑闭环）。

## 7. 测试

- **单测**：每个 `AsMentionResolver().Resolve` 产出正确 Reference（function 含 Code / document 含 Content / handler 含方法 / workflow 含 Graph）；not-found → `ErrNotFound`。chat 渲染：`Attrs["mentions"]` → 正确 `<mentions>` XML；stub 渲染。`sendMessageRequest` 接受 `mentions`（不再 422）。
- **pipeline**（harness）：@ 一个 document → 该 doc 正文出现在 LLM transcript 的 user 消息里；@ 已删实体 → stub 块、消息照发；快照稳定：第二轮 transcript 里该消息内容不变（即使实体被改）。
- 基线：`make test-backend` + catalog/chat pipeline 全绿；`cd backend && go build ./... && staticcheck ./...` 干净；前端 `npm run build` + 相关测试。

## 8. 文档同步（§S14）

| 文档 | 改动 |
|---|---|
| `service-design-documents/mention.md`（新）| 本设计落地：端口 / 4 resolver / Attrs["mentions"] / 渲染 / 范围 |
| `service-design-documents/chat.md` | `buildUserLLMMessage` 注入 mentions；`SendInput.Mentions`；`Message.Attrs["mentions"]` |
| `service-design-documents/{document,function,handler,workflow}.md` | 各加"实现 mention.Resolver" |
| `service-contract-documents/api-design.md` | `POST /conversations/{id}/messages` 请求体加 `mentions: [{type,id}]` |
| `service-contract-documents/error-codes.md` | **无需改** —— `ErrNotFound` 内部兜底为 stub，Send 永不因 mention 失败，不直达 handler |
| `frontend-prd.md` | §17 mention 发送 shape（type+id）；mentionPool 去 skill |
| `progress-record.md` | dev log |

## 9. 待你拍板（spec review gate）

1. **范围**：document + function/handler/workflow 四类，skill/mcp 不做 —— 确认?
2. **快照存全文**：doc 正文（≤1MB）整段存进 `Attrs["mentions"]` JSON（一条消息可能较大但只存一次）—— 可接受?
3. **渲染外层统一 `<mention type=... name=...>` + 内文各类型自渲** —— 同意这个分工?
