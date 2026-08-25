# EDGE-235 · 关停预算格

## L1 focused evidence

- `backend/internal/bootstrap/shutdown_budget_test.go:TestShutdownBudget_NestsInsideAppGrace` 通过，锁住 `WaitDelay < drainShutdownGrace < shutdownGrace < app grace` 与最坏串行预算。
- `backend/internal/app/tool/shell/shell_test.go:TestBash_Timeout_GrandchildHoldingPipe` 覆盖孙进程持管道时仍有界返回；通过。
- `frontend/test/core/process/backend_controller_test.dart` 的 grace/SIGKILL 两个分支通过。

## 判定

L1=`A4`：关停即使子系统拖延也有明确预算，不无限等待。L2-L5 本轮无真实卡住子系统与 App 五通道 session，记 `na`。
