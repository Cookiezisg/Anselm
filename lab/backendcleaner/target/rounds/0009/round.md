# Round 0009 — infra/db 网关重写 GORM→database/sql（波次 0 · M0.2 数据库层）

类型 / 目标：db 网关从 GORM 换成 `database/sql` + `glebarez/go-sqlite`，回归纯通用。

依赖扫描：
- 旧下游：`cmd/server/main.go`（Open + Migrate）+ 大量 `*_test.go`（各 store/handler 用 db.Open 建测试库）。
- 新接口被 M7.1（main 装配）+ 各模块 store 测试消费 → 各自那轮适配。

旧实现：GORM `Open` → `*gorm.DB`；`Migrate(models...)` AutoMigrate；`schema_extras.go` 硬编码 api_keys/functions/relations… 的 partial index + trigger（**通用网关耦合业务表**）。

修改后完整逻辑：
- `db.go`：`Open(Config)` → `sql.Open("sqlite", dsn)`（glebarez/go-sqlite，modernc，无 CGO）+ `SetMaxOpenConns(1)`（WAL 单写、避免 SQLITE_BUSY 竞升锁、内存库共享）+ `verifyPragmas`（FK 总验、file DB 验 WAL）→ 包成 `*orm.DB` 返回。
- `migrate.go`：`Migrate(db, stmts ...string)` 在单事务内按序执行幂等 DDL，取代 AutoMigrate。
- **`schema_extras.go` 删除**：业务表的 `CREATE TABLE`/index/trigger 分散到各模块 store（`workspace_id` 正名），`cmd/server` 汇总后传 `Migrate`。网关持**零**业务表知识。
- `orm` 补 `Exec`（DDL/PRAGMA 逃生口）+ `Close`（关池，nil/tx-wrapper 安全）。

删除 / 移出：`schema_extras` 的业务表 DDL → 各模块 store（M1.x，随表一起建，user_id→workspace_id）。

契约变更：内部 Go API。`Open` 返 `*orm.DB`（非 `*gorm.DB`）；`Migrate` 收 DDL 字符串（非 model）。下游 main（M7.1）+ store 测试在各模块轮适配。不进 contract-changes（非对外契约）。

新测试：infra/db 5（Open 内存/文件建档/非法 dir；Migrate 建表/幂等/表可用/nil）+ orm 2（Exec 原始语句、Close nil 安全）。

验证：`gofmt` 净 / `go vet` OK / 全量 `go build ./...` + `go test ./...` 绿（cmd/server + infra/db + 9 pkg）。

是否更干净：网关从「GORM + 耦合业务表索引」→「database/sql 纯通用 + schema 分散各模块」。pragma 配错启动期响亮失败。

覆盖状态：infra/db cleaned。**M0.2 数据库层完成**（pkg/orm R0008 + db 网关 R0009）。schema DDL 分散方针随各业务模块（M1.x）执行。

下一步：M0.3 `infra/logger` + `infra/crypto`（zap + AES-GCM）。
