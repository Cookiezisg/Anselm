# findings —— 评审中发现的偏差（不合理 / 冗余 / 产品问题）

> docswriter 真正的产出。一条 `F-N`：模块 · 类型 · 描述 · 对照的标准 · 建议修法（**标准化、不打补丁**）· 严重度 · 状态（open / 待裁 / 已修 / 转ADR / wontfix）。
> 流程：我列 → **用户裁决修哪些、怎么修** → 修 + 文档 → 下一模块。修法默认走"统一到标准"，不加特例。

| 类型 | 含义 |
|---|---|
| 不合理 | 设计讲不通 / 海拔错 / 该是 A 却 B |
| 冗余 | 同一概念两处实现 / 重复样板（标准>冗余：统一掉） |
| 产品 | 功能本身建模错 / 缺失 / 不一致 |
| 真bug | 代码确实错 |

---

## F-1 todo 的 domain 错误绕过错误标准（违 S20 / STD-1）

- **模块**：errors 评审横切到 `domain/todo`
- **类型**：冗余 + 不合理
- **现状**：`domain/todo/todo.go` 的 `ErrEmptyContent` / `ErrInvalidStatus` / `ErrTooManyItems` 用 std `errors.New` 构造（全库唯三在 domain 层这么干的；其余 152 个走 `errorsdomain.New`）。它们从 `app/todo/render.go` 返回。
- **对照标准**：STD-1 ——会冒泡到 HTTP 的 domain 错误一律 `errorsdomain.New`。todo 有 HTTP 端点（`GET /conversations/{id}/todos` 等）；这些 std-error 一旦冒泡 → `FromDomainError` 落 default → **不透明 500**（本应 400 `TODO_*` / 422）。
- **冗余佐证**：`app/chat` 已有**正确版** `ErrEmptyContent = errorsdomain.New(KindInvalid, "EMPTY_CONTENT", …)`——同一"内容为空"概念，chat 守标准、todo 绕过。
- **建议修法（标准化）**：todo 三个 sentinel 改 `errorsdomain.New(Kind, "TODO_EMPTY_CONTENT"/"TODO_INVALID_STATUS"/"TODO_TOO_MANY_ITEMS", …)`，Kind 取 `KindInvalid`/`KindUnprocessable`。**不打补丁**（不在 transport 加 todo 特判）。
- **严重度**：中（端到端错误码语义错 + 标准破口）
- **状态**：**open（待你裁决）**

## F-2 websearch 无标准 sentinel（待查）

- **模块**：errors 评审横切到 websearch
- **类型**：待定（可能 不合理）
- **现状**：`domain/websearch` 无 `errorsdomain.New` sentinel；`app/tool/web` 的 `ErrAuthFailed`/`ErrRateLimited`/`ErrUpstreamHTTP` 是 std `errors.New`。websearch **无独立 HTTP handler**（初步），所以这些错误大概只回流 LLM（按 STD-1 边界 std 可）。
- **待查**：websearch 是否经其它路径（如某 service）冒泡到 HTTP？若是，upstream 失败应映射 `KindBadGateway`(502)/`KindRateLimited`(429) 而非沦为 500。
- **建议**：到 websearch 模块评审时确认；当前**不动**。
- **状态**：open（websearch 模块再定）
