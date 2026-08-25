# EDGE-252 · stats blobBytes 超时

## L1 focused evidence

- `backend/internal/app/workspace/workspace_test.go:TestStats_AssemblesPortsAndDegradesHonestly` 通过。
- `backend/internal/infra/store/workspace/workspace_test.go:TestStats` 覆盖统计装配与未知大小的诚实降级。

## 判定

L1=`F1`：统计投影来自仓储和 sizer，无法在预算内确定时保留 `-1`，不伪造 `0`。L2-L5 本批未启动真实 App，记 `na`。
