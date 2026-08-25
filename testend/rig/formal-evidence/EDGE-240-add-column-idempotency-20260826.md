# EDGE-240 · ADD COLUMN 结果幂等

## L1 focused evidence

- `backend/internal/infra/db/db_test.go:TestMigrate_AddColumnIdempotentByOutcome` 通过：已存在列的 duplicate-column 结果视作已应用，非 duplicate 的真实迁移错误仍失败。
- `TestMigrate_CreatesTableIdempotent` 与 `backend/internal/infra/db/rebuild_test.go` 的重复迁移回归通过。

## 判定

L1=`F5`：重复启动不会把已经完成的 schema 迁移误报为故障，也不会吞掉真正错误。L2-L5 本轮无真实升级重启 App session，记 `na`。
