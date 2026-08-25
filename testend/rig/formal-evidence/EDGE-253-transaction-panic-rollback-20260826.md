# EDGE-253 · 单连接 panic 事务砖化

## L1 focused evidence

- `backend/internal/pkg/orm/tx_test.go:TestTransaction_PanicRollsBackAndFreesConnection` 通过。
- 同包 commit/rollback 基础测试同时通过；panic 路径验证 defer 回滚并释放唯一连接。

## 判定

L1=`F5`：事务 panic 不会永久占住连接，后续数据库操作仍可继续。L2-L5 本批未启动真实 App，记 `na`。
