# Round 0008 — pkg/orm 自研轻量 ORM（波次 0 · M0.2 数据库层）

类型 / 目标：M0.2 数据库层根本决策 + 自研 `pkg/orm`（去 GORM）。

## 重大发现（催生决策）

`domain` 层 **27 个文件**全部 `import gorm` 且带 `gorm:"..."` struct tag + `TableName()` + `gorm.DeletedAt` —— domain 实体 struct 同时焊死 **domain / GORM 持久化 model / API DTO** 三个角色。系统性违反 CLAUDE.md #3「domain 依赖 nothing」。这是 backend-new 最大架构债。

## 决策（用户拍板）

1. **去 GORM**。
2. 数据库引擎仍用 glebarez 纯 Go SQLite，但换成 **`github.com/glebarez/go-sqlite`**（`database/sql` driver，非 gorm driver），底层 modernc，无 CGO。
3. **pkg 自研轻量链式 ORM**（项目查询不复杂：全仓 0 个 Preload/Join/Group，CRUD 面就是 Where/Save/Order/First/Find）。
4. domain 实体改纯 struct + 轻量 **`db:"col,..."` tag**（纯字符串元数据、reflect 读、**不 import 任何包**），故仍满足「依赖 nothing」。

## ORM 设计

- 三层：`DB`（连接/事务）→ `Repo[T]`（表句柄 + by-pk 便利 + 链式入口）→ `Query[T]`（链式构建器，条件/排序/分页/读写收口）。
- db tag 角色：`pk` / `ws`（自动 workspace 过滤）/ `json`（自动序列化）/ `created` / `updated` / `deleted`（软删）。
- **自动横切**（零魔法、可显式关）：workspace **读写双向**隔离（写入也自动打 workspace_id，store 漏不掉）、软删除 `deleted_at IS NULL`（`.Unscoped()` 关）、时间戳。`.CrossWorkspace()` 跳过隔离。
- 链式 + escape hatch：`Where`/`WhereEq`/`WhereIn`/`WhereNull`/`Order`/`Limit`/`Offset` + 原始 SQL 片段（OR 用 `Where("(a OR b)")`）；终结 `First`/`Find`/`Count`/`Exists`/`Pluck`/`Page`（cursor）/`Update`/`Updates`/`Delete`/`Create`/`Save`(upsert)。
- 类型安全（泛型 `*T`，无 `interface{}` 出参）；终结方法强制 `ctx`（S9）。

## 文件拆分（9 源）

`errors`（哨兵）· `db`（DB/DBTX/Open/Transaction）· `meta`（db tag 反射 + 类型缓存）· `query`（链式构建）· `compile`（私有：Query→SQL+args，注入 ws/软删）· `scan`（私有：行↔struct、json）· `repo`（Repo + For + 入口 + Get）· `select`（读终结）· `mutation`（写 + 时间戳 + 写入 ws 注入）。

## 不预造（用户原则）

去掉 `Or`（原始片段够）、`Select`（scan-to-struct footgun）；不造 `GroupBy`/`Join`/`Sum`/`Raw`（全仓零需求）。链式 builder 结构使后续加功能是纯加法，随真实需求再加。`reflect.TypeFor[T]()` 简化（Go 1.22+）。

## 依赖

`github.com/glebarez/go-sqlite v1.21.2`（direct）+ `modernc.org/sqlite v1.23.1`（其传递依赖，与主 backend 的 v1.50.0 不同 module 独立无妨）。

## 测试（21 个，真内存 SQLite）

meta（角色解析 + 无 pk/未知 opt panic）· crud（创建/读/upsert preserve-created/软删/json 往返/time 往返/无 workspace 拒写）· query（Where+Order/WhereIn/空 IN/Count/Exists/**workspace 隔离 + CrossWorkspace**/Limit）· page（cursor 分页不重不漏 3 页）· tx（提交/回滚）· mutation（Updates/单列 Update/**跨 workspace 改 0 行**/Pluck）。

验证：`gofmt -l` 净 / `go build` OK / `go vet` OK / `go test` **21 PASS**。

## 影响（贯穿后续所有业务模块）

**domain 去 GORM 化**成为全局方针：每个业务模块（M1.1+）的 domain 实体剥 `import gorm` + gorm tag → 纯 struct + `db` tag、删 `TableName`/`gorm.DeletedAt`；store 基于 `pkg/orm` 重写。`pkg/orm` 是这 29 个 store 的统一底座。

## 下一步

M0.2 续：`infra/db` 网关用 `database/sql` + `glebarez/go-sqlite` 重写（连接/WAL/pragma/单连接 + 手写 schema DDL 对齐 `database.md` 契约，取代 GORM AutoMigrate）。
