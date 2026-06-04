# Round 0018 — workspace（波次 1 · M1.1，原 user 正名）

类型 / 目标：波次 1 开篇。`user` → `workspace` 全量正名 + 垂直切片重写（domain/store/app/handler）。借此轮补两处地基缺口：**orm 补 ErrConflict**、**handler 包基础设施首建**。

依赖扫描：
- **上游**：全波次 0 地基就绪（orm / errorsdomain / reqctx workspace / idgen / auth `WorkspaceResolver` 端口 / response 框架）。
- **复用盘点（新纪律 §设计原则#8）**：id→`pkg/idgen` 直接用；UNIQUE 冲突识别→应进 `pkg/orm`（地基缺口，补之）；name 校验→标准库（trim + utf8 长度，**无正则**，故不扩 wikilink/不建 validate 包）；language→domain 枚举。**无业务层造轮子**。
- **考古**：user 是「本地多 profile」伪认证（598 行）；半吊子多用户（DB 多行，但文件只用 `local-user` 一桶）；`userpath` per-user 分桶已判删（R0004）。

旧实现历史包袱（删 / 改）：
- `Username` slug（`[a-z0-9_-]{1,32}` 强制小写，因旧代码拿它当文件路径）→ 删，改自由展示名 `Name`（中文 / 空格 / 大小写，≤64 rune，UNIQUE）。
- `GetByUsername` / `USERNAME_*` 一条链 → 删（唯一性靠 DB UNIQUE + orm 翻译，不做应用层预检）。
- `EnsureExists`（测试播种固定 id）→ 删（boot 默认 workspace 改用 `Count==0 → Create`，M7）。
- `gorm.DeletedAt` / gorm tag → 纯 struct + `db` tag。
- 6 个 `errors.New` → `errorsdomain.New`（§S20）。

关键设计决策（与用户敲定）：
- **多 workspace（数据隔离）+ 资源不分桶（文件共享）**：把旧「半吊子多用户」定型——业务表持 `workspace_id`（orm 自动隔离），但 `mcp/skills/settings/catalog` 共享一份 `~/.forgify/`（不 per-workspace）。**workspace = 数据边界，非文件边界**。
- `Name` 强制唯一（DB `UNIQUE INDEX ... WHERE deleted_at IS NULL` partial，软删名可重用）。
- `Language` 是第一个 workspace 级偏好；**不预建 `preferences` 容器（YAGNI）**；`settings.json` 边界留 settings 轮。

地基补完（顺手强化，非 workspace 专属）：
- **orm ErrConflict**：`errors.go` 加哨兵 + `writeErr` 识别 SQLite `"UNIQUE constraint failed"`；Create/Save 经 `writeErr`。对称收口 NotFound + Conflict，store 永不手搓 SQLite 字符串。+2 测试（Create/Save 两路径）。
- **handler 基础设施首建**：`registrar.go`(Registrar) + `util.go`(idAndAction，`strings.Cut`) + `decode.go`(decodeJSON + `ErrInvalidRequest.WithCause`)。所有未来 handler 共享。

新实现要点：
- **domain**：`Workspace` 纯 struct（**无 workspace_id = 隔离根**，orm `meta.ws==nil` 不隔离 → onboarding 无 ctx 可 List）；6 sentinel；Repository 6 法（去 GetByUsername）。
- **store**：`orm.For[Workspace]`；`ErrConflict→ErrNameConflict`、`ErrNotFound→ErrNotFound`；导出 `Schema []string`（建表 + partial unique index）。
- **app**：Service CRUD + 最后一个拒删 + `Validate`（`WorkspaceResolver` 端口实现，M7 注入）；`cleanName`(trim+utf8≤64)、`resolveLanguage`(默认 zh-CN)。
- **handler**：`/workspaces` CRUD + `:activate`；onboarding 豁免鉴权。

契约变更（→ contract-changes #2 落地 + #3 扩展）：端点 `/users`→`/workspaces`；字段 `username/displayName`→`name`（去 slug）；error code `USER_*`/`USERNAME_*`→`WORKSPACE_*`（`USERNAME_INVALID`→`WORKSPACE_NAME_TOO_LONG`）；header（M0.7 已落地）。

新测试：orm +2（冲突翻译 Create/Save）；store 8（roundtrip / 重名 ErrNameConflict / not-found / List 无 ctx / 软删名可重用 / touch / count）；app 10（fake repo：默认 / 校验 / 重名 / 部分更新 / 拒删 / Validate）。

验证：`gofmt -l` 空 / `go build ./...` / `go vet` / `go test ./... -race` 全绿。

是否更干净：分支减少（去 slug 正则 / GetByUsername / EnsureExists）；地基收口冲突翻译（store 不碰 SQLite 字符串）；handler 基础设施立起复用底座。✅

覆盖状态：workspace（隔离根 CRUD + 准入端口 + 数据隔离 + 资源共享决策）。

遗留 / 下一步：
- deps-todo：`settings.json`↔workspace 偏好边界（settings 轮）；通用 `validate` 包观察点（≥2 模块共享格式校验才抽）；userpath 资源布局落地点（M7）；boot 默认 workspace + `WorkspaceResolver` 注入（M7）。
- 下一轮：**M1.2 apikey**。
