# standards —— 评审中确认/精炼的 canonical 标准（尺子）

> docswriter 是"以文档为手段的设计评审"。每评审一个模块，先**确认该领域的 canonical 标准**记在这里（尺子），再拿后续模块对照——**偏离即 findings**（见 `findings.md`）。
> 本文件是评审期的**工作尺子**；定稿后沉淀去真文档：标准的「规则」入 `CLAUDE.md`（N/D/E/S 系列）+ `references/backend/*`，标准的「枚举」（如全部错误码）入 `references/backend/error-codes.md`。
> 一条 `STD-N`，按确认顺序编号。

---

## STD-1 错误处理

**确认于** errors 模块（`pkg/errors` + `errmap.go` + 全库错误用法，全扫）。**结论：标准优秀、已全量统一**——错误类型移到 `pkg/errors`（纯机制、全层可用）；**所有命名 sentinel 一律 `errorspkg.New`**（全库无 std-errors 命名 sentinel）；wire code 100% 唯一 + 100% `<ENTITY>_<REASON>` SCREAMING_SNAKE；Kind 分布健康。见 [`decisions/0002`](../../../docs/decisions/0002-unified-error-type.md)。

### 框架
`errorspkg.Error{Kind, Code, Message, Details, cause}`（`pkg/errors`——纯机制地基，pkg/infra/domain/app 全层可 import、无反向依赖）；`New(kind, code, msg)` 构造。
- `Is` **按 Code 匹配** → sentinel 与其 `WithCause`/`WithDetails` 副本在 `errors.Is` 下仍相等（保留 sentinel 比较习惯 + 允许包裹）。
- `Unwrap` 暴露 cause 供 `errors.Is/As`。`Details` → N1 `error.details`。

### Kind 分类（15，封闭集；零值 = `KindInternal` 安全兜底）
每个 Kind 的注释即权威 HTTP 映射：

| Kind | HTTP | Kind | HTTP | Kind | HTTP |
|---|---|---|---|---|---|
| Internal | 500 | Unprocessable | 422 | GatewayTimeout | 504 |
| Invalid | 400 | TooLarge | 413 | Accepted | 202 |
| Unauthorized | 401 | UnsupportedMedia | 415 | ClientClosed | 499 |
| NotFound | 404 | RateLimited | 429 | Gone | 410 |
| Conflict | 409 | BadGateway | 502 | Unavailable | 503 |

### 单一映射表
`response/errmap.go::statusForKind` 是 domain→HTTP 的**唯一**表（transport 不持逐错误表、不 import 任何业务 domain；旧 errmap 曾 293 行 import 27 包，被结构化 `Error{Kind,Code}` 塌缩到此）。**只有新增 Kind 才动它。**

### wire code 命名规约
**`<ENTITY>_<REASON>`，SCREAMING_SNAKE，按实体命名空间，全库唯一。**
范例（function 是模板）：`FUNCTION_NOT_FOUND` · `FUNCTION_NAME_DUPLICATE` · `FUNCTION_VERSION_NOT_FOUND` · `FUNCTION_NO_ACTIVE_VERSION` · `FUNCTION_SANDBOX_UNAVAILABLE`。

### sentinel 归属
跨域 sentinel 在 `pkg/errors/sentinel.go`（`ErrInvalidRequest` / `ErrUnauthorizedNoWorkspace`）；按域/按包 sentinel 在各自包——但**一律用 `errorspkg.New` 构造**（含 pkg/infra 原语，如 `orm.ErrNotFound`）。

### 统一规则（S20，无"是否冒泡 HTTP"之分）
- **所有命名 sentinel → 一律 `errorspkg.New`**（含 tool 错误、pkg/infra 原语）。区别不在造法、在**出口**：HTTP 读 Kind/Code 走 Envelope；LLM tool 读 Message（Kind/Code 该路径不用，但未来若冒到 HTTP 即正确映射）。
- **泛型原语**（`orm.ErrNotFound`/`ErrConflict`）带兜底码（`ORM_*`），但 domain 仍 `errors.Is` 后翻成具体码（`FUNCTION_NOT_FOUND`）——类型全层可用、翻译保特异性（见 [`decisions/0002`](../../../docs/decisions/0002-unified-error-type.md)）。
- `fmt.Errorf("…: %w", err)` 包裹照常（保留 `errorspkg.Error` 链）；**禁止** std `errors.New` 造命名 sentinel。`errors.Is`/`errors.As` 用标准库。

### HTTP 落地（`FromDomainError`）
`*errorspkg.Error` → `statusForKind(Kind)` + Code + Details；`context.Canceled`→499 / `DeadlineExceeded`→504（唯二特例）；其余 → 500 `INTERNAL_ERROR`（隐藏原文、记日志，绝不泄露内部）。

---

## STD-2 数据访问

**确认于** orm 模块（`pkg/orm` + 20 处 store 用法）。**结论：框架优秀、用法 100% 统一，无 findings。**

### 框架
泛型 `Repo[T]` / `Query[T]`（`For[T](db, table)`）。链式 `Where`/`WhereEq`/`WhereIn`/`Order`/`Limit` + `First`/`Find`/`Count`/`Exists`/`Pluck`/`Page(cursor, limit)` + `Create`/`Save`(upsert)/`Update`/`Updates`/`Delete`。表元数据靠 struct tag（`pk` / `ws` / `created` / `updated` / `deleted`）。

### 五条自动行为（地基统一、业务层不手搓）
1. **workspace 隔离**：`,ws` 列由 `applyWorkspace` 从 ctx 写入（写）+ `whereClause` 过滤（读）——调用方永不手设 `workspace_id`，不可能跨 workspace 误写/误读。
2. **软删**：有 `deleted` 列且非 `Unscoped` → `Delete` 设 `deleted_at`（UPDATE）；否则物理 DELETE。
3. **时间戳**：`created`（仅首次/零值）+ `updated`（每次）自动 stamp。
4. **UNIQUE 冲突 → `ErrConflict` 翻译**（地基翻译，业务不手搓——原则 #8「强化地基」范例）。
5. **first-wins 守卫更新范式**：竞态终态翻转用 `WhereEq("status", Running).Updates(...)`——先到者赢、输家 0 行 no-op（如 flowrun `MarkRunTerminal`）。

### 用法标准
所有 store 走 `For[T]` + 链式，**无裸 SQL**（document 子树软删 = `WhereIn("id",…).Delete`、flowrun 终态 = 链式 Updates）、**无手搓 workspace_id 过滤**。store 文件名 = Repository 接口（S5）。
