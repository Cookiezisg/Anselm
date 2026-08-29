# 台架前置失败清理回归 · 2026-08-29

## 发现

第二套 `rig-up` 在端口已被第一套台架占用时，会在 `start_app_and_record` 捕获 App baseline 之前退出。旧清理逻辑无条件执行 `stop_new_apps`，因此把第一套仍在使用的真实 Anselm App 误判为本次尝试的新进程并杀掉。另一个诊断缺陷是 `RIG_RECORD=0` 时 manifest 没有窗口 ID，`rig-check` 仍对空 ID 调 Swift 强制解包，返回 `SIGTRAP(133)` 而不是可解释的门禁失败。

## 修复与证据

- `testend/rig/rig-up.sh` 新增 `BASELINE_APP_PIDS_CAPTURED`；只有捕获 baseline 后才允许清理新 App。
- `testend/rig/rig-check.sh` 仅在窗口 ID 非空时执行 CoreGraphics owner 查询；诊断录像关闭时明确报告不能通过正式验收，不再崩溃。
- 第一套诊断台架 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-142652`，App PID=`31971`。
- 第二套故意端口冲突返回 `1`，冲突清理完成后第一套 App PID=`31971` 仍为 `Ss` 且命令为精确 Anselm bundle；随后第一套 backend/ssetap/llmtap 与 App 正常收台。
- 修复后的 `RIG_RECORD=0` `rig-check` 返回 `1`，输出明确的 `window ID missing` 与 `recorder dead`，不再返回 `133`。

结论：前置失败不会破坏已有台架；诊断模式失败也必须是可读的 fail-closed，而非脚本崩溃。该回归属于台架 L1，不推进产品 COVERAGE 批次。
