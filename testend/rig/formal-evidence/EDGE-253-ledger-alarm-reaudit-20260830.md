# EDGE-253 · 单连接 panic 事务砖化 · ledger/alarm re-audit

- 普通回归：`go test -count=1 ./internal/pkg/orm -run TestTransaction_PanicRollsBackAndFreesConnection` 通过。
- race 回归：`go test -race -count=1 ./internal/pkg/orm -run TestTransaction_PanicRollsBackAndFreesConnection` 通过。
- 本次 L2/L3 裁决只说明内部 ORM seam 的适用性边界；没有将后端测试冒充真实 App、五通道或视觉证据。
- 告警按原阈值触发 `discovery-collapse`，原因是最近 50 条裁决的 fail 占比低于 5%；这是统计信号，不修改算法。复核确认本次 `na` 均有具体适用性理由，故按原流程销账。
- anchors=`10/10`；销账后 `alarms.py check` 应保持 clean，并由 `evidenceThrough` 水位锁住本轮已复核 journal。
