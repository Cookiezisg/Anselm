# EDGE-293 · 删被依赖实体

## L1 focused evidence

- `backend/internal/app/relation/relation_test.go:TestPurgeEntity_EmitsDependencyBroken` 通过：清除关系边前快照依赖，并发出聚合 `relation.dependency_broken`。
- `backend/internal/app/relation/relation_test.go:TestPurgeEntity_NotifyEdgeCases` 通过：无依赖与通知边界均有覆盖。

## 判定

L1=`F1`：删除后的依赖断裂事实可由关系与通知持久化投影解释。L2-L5 本批未启动真实 App，记 `na`。
