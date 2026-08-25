# EDGE-236 · 父进程死人开关

## L1 focused evidence

- `frontend/test/core/process/backend_controller_test.dart` 断言 spawn 传递 `ANSELM_PARENT_WATCH=1`，并覆盖 sidecar 退出与重启边界；通过。
- `backend/internal/bootstrap/build_test.go:TestApp_BootShutdownNoPanic` 与 reap 回归证明收到统一关停信号后能完成收台。

## 判定

L1=`F5`：父进程死亡监视接入同一有序关停链。真实 `kill -9` 父进程的 App 五通道 session 本轮未重跑，L2-L5 记 `na`。
