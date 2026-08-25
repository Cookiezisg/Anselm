# EDGE-239 · CHECK 加词整表重建

## L1 focused evidence

- `backend/internal/infra/db/rebuild_test.go:TestMigrateRebuild_WidensCheckAndPreservesData` 覆盖旧表 CHECK 变更、逐列迁移、数据保留；通过。
- `backend/internal/infra/store/{trigger,flowrun,messages}/rebuild_test.go` 的三类 store 重建回归通过；`TestMigrateRebuild_FreshInstallAndMissingTableNoOp` 锁住新库/缺表 no-op。

## 判定

L1=`F5`：旧库升级后仍可启动、数据与索引语义不丢。L2-L5 本轮未做真实旧库启动 App session，记 `na`。
