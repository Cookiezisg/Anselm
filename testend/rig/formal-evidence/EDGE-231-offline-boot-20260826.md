# EDGE-231 · 断网启动

## L1 focused evidence

- `backend/internal/bootstrap/build_test.go:TestApp_BootShutdownNoPanic` 构造临时数据目录完成完整 Build → Boot → Shutdown，测试明确约束 Boot 不拉运行时；通过。
- `backend/internal/app/freetier/freetier_test.go:TestProvisionNow_ReportsHonestly`、`TestProvisionNow_TransientFailureNeverRotates`、`TestProvisionNow_HealFailureLeavesRowIntact` 覆盖网关不可达/瞬时失败时的 best-effort 降级与不轮换；通过。
- `frontend/test/core/process/backend_controller_test.dart` 与 `master_key_test.dart` 覆盖冷启动、sidecar 重启、keychain 缺失降级；Flutter focused suite 33 tests passed。

## 判定

L1=`F5`：离线启动保持本地壳可启动，免费档失败不伪造成功。L2-L5 本轮未启动真实 App、未接断网五通道 session，按规则不计绿。
