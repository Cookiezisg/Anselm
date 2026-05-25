# Catalog 重构:懒生成 + Mechanical — 设计

> Date: 2026-05-25 · Status: 待用户审 · Scope: 后端 `app/catalog` 单子系统(含其 HTTP API + testend 巡检视图)

---

## 1. 背景与问题

Catalog 的唯一职责:把一份"能力清单"注入 chat 系统提示,让助手知道当前有哪些 function / handler / skill / mcp 可用。

**现状(eager 设计):** 后台每 1s 轮询 → per-user 扇出 → 5 个 source 收集 item → 指纹(sorted Source+Name+Description SHA256)→ 指纹变了就调 **LLM** 润色成 summary → 落磁盘 cache + 版本 history → `GetForSystemPrompt()` 读缓存注入。

**问题(本次重构的触发):**

1. **烧 API 余额。** 每次内容变 + 每次冷启动(cache miss)都触发一次 LLM 润色。开发期反复重启后端 → 反复烧 key。这是直接痛点。
2. **1s 后台轮询 + per-user 扇出** 对单用户本地是纯空转。
3. **MCP source 指纹抖动**:server status / tools 一变指纹就变 → 触发本不必要的重生成。
4. **磁盘 cache + versioning + history + diff** 全是为"管理 eager 重生成"而存在的脚手架 —— 懒生成后毫无意义。
5. **documents 进 catalog** 是噪音、且不 scale(几十个文档名塞进每条系统提示)。文档应在用户 **@ 引用** 时才进上下文(独立功能,见 §10)。

## 2. 目标

Catalog 收敛成:**开聊时按需、用 mechanical 拼一份能力清单注入系统提示。** 零 LLM、零后台 goroutine、零缓存陈旧、零指纹/版本。documents 移出 catalog。

保留一个干净的 `Generator` 接口当"缝":将来清单变大,可往缝里塞按规模触发的 **压缩 / 检索** 策略(本次不建,YAGNI)。

## 3. 设计

### 3.1 触发 = 懒生成(on-demand)

`chat.runner` 组装系统提示时调 `catalog.GetForSystemPrompt(ctx)`:现查 4 个 source → 拼清单 → 返回。**无 goroutine、无 ticker、无 poll、无 per-user 扇出。** ctx 带 userID,各 source 按当前 user 现查(行为同现状 `Refresh(ctx)`)。

清单构建极便宜(几条 DB 查询 + 字符串拼装),单用户每对话回合现查可忽略,**不加缓存**(YAGNI;将来要也只是个可选 TTL,留作后续)。

### 3.2 生成 = mechanical only

`mechanicalFallback`(现已存在,产出干净的 `## Available capabilities` Markdown)升为**唯一构建路径**,改名 `build`。

保留 domain `Generator` 接口当缝;**删掉具体 `LLMGenerator` 实现 + 其接线**(YAGNI:不接的 LLM 代码 = dead code,会被 staticcheck/deadcode 抓)。将来要压缩/检索时,实现一个新 Generator 塞进缝即可。

### 3.3 sources

保留 **function / handler / skill / mcp**。**删 document**(@-mention TODO,§10)。

MCP status 抖动**无害**:懒构建只读当前态拼字符串,不触发任何 LLM / 重生成。

### 3.4 消费接口(签名变更)

```go
// domain/catalog/catalog.go
type SystemPromptProvider interface {
    GetForSystemPrompt(ctx context.Context) string  // 原:GetForSystemPrompt() string
}
```

- 全源失败 → 返 `""`(优雅降级:聊天照常,只是没有能力清单段;记 warn)。
- 部分源失败 → 用成功的源拼(保留现状 `Refresh` 的 `failedCount` 行为)。
- `chat.runner:210` 调用点改为传 ctx。
- **memory 的平行 `memorydomain.SystemPromptProvider` 不动**(独立接口;其 ctx 化/重构另议)。

### 3.5 Catalog struct 瘦身

```go
type Catalog struct {
    Summary     string              `json:"summary"`
    Coverage    map[string][]string `json:"coverage"`
    GeneratedAt time.Time           `json:"generatedAt"`
    GeneratedBy string              `json:"generatedBy"` // 恒为 "mechanical"
}
```

删 `Fingerprint / Version / SourcesAt`(无变更检测、无版本、无 per-source 时间戳)。

### 3.6 HTTP API:4 → 1

保留 **`GET /api/v1/catalog`**(按需构建,供 testend / curl 巡检"助手当前看到哪些能力")。
删 **`POST /api/v1/catalog:refresh`**(懒生成下等价于 GET)、**`GET /api/v1/catalog/history`**、**`GET /api/v1/catalog/diff`**(无版本)。

## 4. 删除清单(精确)

**backend / app/catalog:**
- `polling.go` 整文件:`Start / Stop / pollLoop / tryRefresh / RefreshAll / Refresh / fingerprint / historyID`。
- `disk.go` 整文件:`loadFromDisk / saveToDisk`。
- `generator.go`(LLMGenerator 实现)+ `generator_test.go`。
- `catalog.go` Service 字段:`cachePath / pollInterval / notif / cache / lastFP / busy / historyRepo / userList / version / stopOnce / stopCancel / pollDone`(`notif` 一并删 —— 见下方"通知");方法 `SetGenerator / SetHistoryRepo / SetUserLister / SetPollInterval / HistoryRepo / nextVersion`;`Get` / `GetForSystemPrompt` 改签名 + 按需构建(见 §6)。
- `UserLister` 接口、`defaultPollInterval` 常量。

**backend / domain/catalog:**
- `history.go` 整文件:`HistoryEntry / HistoryRepository`。
- `catalog.go`:删 `ErrCoverageIncomplete / ErrGenerationFailed`(LLM-only);`Catalog` 按 §3.5 瘦身;`SystemPromptProvider` 按 §3.4 改签名。

**backend / infra/store:**
- `cataloghistory/` 整包。

**backend / transport/httpapi:**
- `handlers/catalog.go`:删 `Refresh / History / Diff / stringSet`;`Register` 只留 `GET /api/v1/catalog`;`Get` 改为 `svc.Get(r.Context())` 按需构建(全源失败返 503)。
- `response/errmap.go`:保留 `ErrAllSourcesFailed → CATALOG_ALL_SOURCES_FAILED`;handler 内联的 `CATALOG_HISTORY_UNAVAILABLE / CATALOG_VERSION_NOT_FOUND` 随端点删。

**backend / cmd/server/main.go:**
- L99 `cataloghistorystore` import;L188 `&catalogdomain.HistoryEntry{}` AutoMigrate;L405 `New` 改签名(不再要 `.catalog.json` 路径);L406 `SetGenerator`;L407 `SetHistoryRepo`;L408 `SetUserLister`;L423 `RegisterSource(documentService...)`;L424 `Start`;L652 `Stop`。
- L209/213/219 注释里 `.catalog.json` 的提及随之清理(catalog 不再落盘)。

**通知:** `Refresh` 里的 `notif.Publish(ctx, "catalog", ...)` 随 `Refresh` 删。前端 `useNotifications.js` / `NotificationsDrawer.jsx` 的 `catalog` 分支无害(未知类型优雅处理),可留可删 —— 本次顺手删保持干净。

**testend(Vue):**
- `stores/catalog.ts`:去 `refresh` action(保留 `get`)。
- `views/observe/Catalog.vue`:去 version / fingerprint / history / diff / refresh 按钮,只展示当前 Summary + Coverage。
- `api/resources.ts`:`catalogAPI` 去 `refresh`。
- `api/misc.ts`:去 `catalogHistoryAPI`(+ 对应 `CatalogHistoryEntry` 类型)。
- `App.vue:68`:`catalog.refresh()` → `catalog.get()`(或移除启动预取)。

## 5. 保留

- domain:`Generator` 接口(缝)、`CatalogSource`、`Granularity`、`Item`、瘦身后的 `Catalog`、改签名的 `SystemPromptProvider`、`ErrAllSourcesFailed`。
- function / handler / skill / mcp 的 `AsCatalogSource()`。
- `mechanicalFallback` 的全部产出逻辑(改名 `build`,空库跳段 + 多源排序 + per-item/per-server 头 + "MAY call multiple search tools in parallel" 尾句)。

## 6. 构造与内部签名

```go
// 原:New(cachePath, notif, log) → 现(notif 不再需要:catalog 不再发通知):
func New(log *zap.Logger) *Service

// 内部统一构建入口;Get 与 GetForSystemPrompt 都走它:
func (s *Service) build(ctx context.Context) (*catalogdomain.Catalog, error)
func (s *Service) Get(ctx context.Context) (*catalogdomain.Catalog, error) // HTTP:全源失败返 err → 503
func (s *Service) GetForSystemPrompt(ctx context.Context) string           // runner:err / 空 → ""
```

`main.go:405` 同步改:`catalogService := catalogapp.New(log)`(`notificationsPub` 不再传入)。

## 7. 错误处理

| 入口 | 全源失败 | 部分源失败 | 空库 |
|---|---|---|---|
| `GetForSystemPrompt(ctx)`(runner) | 返 `""` + warn(聊天照常) | 用成功源拼 | 返 `""`(跳段) |
| `GET /api/v1/catalog`(HTTP) | 503 `CATALOG_ALL_SOURCES_FAILED` | 用成功源拼 200 | 200 + 空 Summary |

## 8. 测试

- **单测**(`catalog_test.go` 重写):`build` 正确性(空库跳段 / 多源字母序 / mcp per-server 头 / item 缺 description 显 `(no description)` / 部分源失败降级);`GetForSystemPrompt(ctx)` 缺 userID 的行为;全源失败返 `""`。
- **pipeline**(已有 chat pipeline):有 function 时系统提示含 `## Available capabilities`;无任何能力时不含该段;document 不出现在清单(即使存在文档实体)。
- 删 `generator_test.go`。
- **基线**:`cd backend && go build ./... && make test-unit && staticcheck ./...` 全绿;testend `npm run build` 通过。

## 9. 文档同步(§S14,最高优先级)

| 文档 | 改动 |
|---|---|
| `service-design-documents/catalog.md` | 整体改写:触发(懒)/ 生成(mechanical)/ sources(去 document)/ API(4→1)/ struct 瘦身;删 §4.7 history 段 |
| `service-contract-documents/api-design.md` | catalog 端点 4 → 1 |
| `service-contract-documents/error-codes.md` | 删 history 相关码;留 `CATALOG_ALL_SOURCES_FAILED` |
| `service-contract-documents/events-design.md` | notifications 词表移除 `catalog` 类型(或标注停发) |
| `service-contract-documents/database-design.md` | 移除 `catalog_history` 表 |
| `desktop-packaging-notes.md` / testend-design | catalog 巡检视图简化;`.catalog.json` 不再生成 |
| `progress-record.md` | dev log(做了什么 + 测试数 + 决策) |

## 10. Out of scope / TODO

- **@-mention 文档 → 注入内容**:独立 spec,本次 catalog 重构完成后做。后端目前**完全没有** mention 处理(前端发 `body.mentions`,后端不消费),是要新建的功能。
- **规模化压缩 / 检索**:`Generator` 缝留着,清单变大再塞(YAGNI)。届时倾向"检索相关子集"而非"LLM 总结全量"。
- **memory provider 的 ctx 化 / 重构**:另议。

## 11. 待你拍板(spec review gate)

1. **(A) HTTP 取舍** — 保留 `GET /catalog`(按需巡检)+ 删 refresh/history/diff?**(我推荐)** 还是连 GET 一起删、catalog 纯内部不暴露 API?
2. **(B) Catalog struct 瘦身** — 删 fingerprint/version/sourcesAt,确认?
3. **(C) testend 视图简化纳入本次** — 确认?(否则 testend Catalog 视图会调到已删端点报错。)
