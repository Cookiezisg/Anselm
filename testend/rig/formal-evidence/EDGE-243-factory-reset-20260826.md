# EDGE-243 · 出厂重置

## L1 focused evidence

- 已有真实 Storage 面正式证据 `testend/rig/formal-evidence/SURF-075-settings-panel-storage-five-level.md`：真实 App 中输入 `Anselm`、点击危险动作、sidecar 停止、数据根/数据库消失、replacement App 回到 onboarding，且五通道与录屏均有封口记录。
- 本轮 Flutter `s5_storage_limits_test.dart` 重新通过 factory zone 的 typed confirmation guard；没有把 widget test 当作新的黑盒 session。

## 判定

L1=`G1`：不可逆动作有可发现的确认路径，完成后回到真实全新安装态。历史 session 目录已不在当前台架，L2-L5 本轮不重写为绿，记 `na`。
