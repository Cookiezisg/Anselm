# standards —— 评审中确认/精炼的 canonical 标准（尺子）

> docswriter 是"以文档为手段的设计评审"。每评审一个模块，先**确认该领域的 canonical 标准**记在这里（尺子），再拿后续模块对照——**偏离即 findings**（见 `findings.md`）。
> 本文件是评审期的**工作尺子**；定稿后沉淀去真文档：标准的「规则」入 `CLAUDE.md`（N/D/E/S 系列）+ `references/backend/*`，标准的「枚举」（如全部错误码）入 `references/backend/error-codes.md`。
> 一条 `STD-N`，按确认顺序编号。

---

## STD-1 错误处理

**确认于** errors 模块（`domain/errors` + `transport/httpapi/response/errmap.go`）。**结论：标准设计优秀，152 个 sentinel 基本遵守；偏差见 F-1/F-2。**

### 框架
`errorsdomain.Error{Kind, Code, Message, Details, cause}`；`New(kind, code, msg)` 构造。
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
跨域 sentinel 在 `domain/errors/sentinel.go`（`ErrInvalidRequest` / `ErrUnauthorizedNoWorkspace`）；按域 sentinel 在各自包——但**都用 `errorsdomain.New` 构造**。

### `errorsdomain.New` vs std `errors.New` 边界（= S20 的实操判据）
- **会冒泡到 HTTP 的 domain 错误 → 一律 `errorsdomain.New`**（带 Kind+Code）。否则 `FromDomainError` 认不出 → 落 default → **不透明 500、丢 wire code**。
- **不冒泡到 HTTP 的**（如 LLM tool 内部错误，回流给 LLM 作文本）→ std `errors.New` 可。
- `errors.Is` / `errors.As` 始终用标准库。

### HTTP 落地（`FromDomainError`）
`*errorsdomain.Error` → `statusForKind(Kind)` + Code + Details；`context.Canceled`→499 / `DeadlineExceeded`→504（唯二特例）；其余 → 500 `INTERNAL_ERROR`（隐藏原文、记日志，绝不泄露内部）。
