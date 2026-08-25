# EDGE-234 · 三步优雅关停

## L1 focused evidence

- `backend/internal/bootstrap/build_test.go:TestApp_BootShutdownNoPanic` 完整 Boot/Shutdown 通过。
- `backend/internal/bootstrap/reap_unix_test.go:TestApp_ShutdownReapsBackgroundShellProcs` 覆盖 sidecar 关停后的后台 shell 收台；通过。
- `frontend/test/core/process/backend_controller_test.dart` 覆盖 SIGTERM、等待退出与超时 SIGKILL 分支；通过。

## 判定

L1=`F5`：关停链有序且有界，不把 in-flight/后台子进程留成孤儿。L2-L5 本轮无三路 SSE 真实 App session，记 `na`。
