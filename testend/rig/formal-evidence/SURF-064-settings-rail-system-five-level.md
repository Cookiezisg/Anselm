# SURF-064 · settings/rail-system

## 判定

`pass`。本项验证 System 目录的 Storage & logs、Advanced limits、Network、Shortcuts、About 五面板，重点确认机器级边界、运行中 sidecar 真相、错误/重试文案和系统动作反馈。没有发现需要 stop-and-fix 的产品缺陷。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-212039`
- Data: `/private/tmp/anselm-data-surf064-20260819-r1`
- Workspace: `ws_b34dfc17c20ccd09` (`Acceptance SURF-064`)
- Storage & logs 显示运行中 sidecar 返回的真实数据目录 `/private/tmp/anselm-data-surf064-20260819-r1`，Disk usage `0 B`、数据库 `784.0 KB / 0 B reclaimable`、Attachments `0 B / 0 B reclaimable`，同时提供 Finder 定位、diagnostics、90 days retention、Compact database、Reset local preferences 与明确的 factory reset 危险区。没有执行不可逆 factory reset。
- Advanced limits 显示机器级说明、服务端 schema 的 `agent/context/timeout` 分组、每行当前值、范围与 default，以及 `Reset all to defaults`；表单不是空白占位。
- Network 显示 machine scope、HTTP/HTTPS/no-proxy 三个字段、Save 与明确的“proxy fully takes effect after restarting the engine”提示。
- Shortcuts 显示六个全局命令及当前键位 `⌘B`、`⌘\\`、`⌘,`、`⌘=`、`⌘−`、`⌘0`，并提供 `Reset all to defaults`。
- About 显示 app `0.1.0`、engine `dev`、更新检查按钮和可读的 `Couldn't check for updates (offline or nothing published yet)` 状态；点击 `Copy diagnostics` 后顶带出现 `Copied`，操作反馈闭环；字体许可说明完整可见。

关键帧：

- `evidence/SURF-064-storage.png`
- `evidence/SURF-064-limits.png`
- `evidence/SURF-064-network.png`
- `evidence/SURF-064-shortcuts.png`
- `evidence/SURF-064-about.png`

## 五通道证据

1. **Frame**：`screen.mov` 由 conductor 正常收束，最终时长 `116.973333s`；五个系统面板与 About 的 `Copied` 回执均已观察并封存。
2. **Backend**：`backend.log`=`171` 行；无 panic / fatal / exception / stack trace / RenderFlex / RenderBox 应用红线。
3. **SSE**：`sse.jsonl`=`4` 行；三条流真实连接，本项没有聊天/实体耐久 mutation，不伪造业务帧。
4. **Frontend terminal**：`frontend.log`=`4` 行；仅正常启动、Flutter VM 与已知 macOS 输入法宿主噪声，无 Flutter / Dart / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl`=`10` 行，managed proof challenge / install / models 真实返回 `200`；系统设置路径没有 LLM completion，不伪造 completion。

`rig-check` 在 App 运行期间证明同一 session 的五通道归属：backend PID=`9210`、ssetap PID=`9240`、llmtap PID=`9185`、App PID=`9716`、recorder PID=`9760`。rig-down 正常收束，进程审计无残留。

## 本地验证

- `mise exec -- flutter test test/features/settings/s5_storage_limits_test.dart test/features/settings/s5_network_test.dart test/features/settings/s6_shortcuts_test.dart test/features/settings/s3_workspaces_about_test.dart`：通过。
- 系统面板 focused tests 与 `dart analyze`：通过。
- `python3 testend/rig/gen_coverage.py --check`：通过，848 rows，无 tombstone。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：clean。
- `git diff --check`：通过。

## 法条

- `G1`：五个系统面板均从 Settings System 目录直接发现，危险动作与恢复动作都有明确入口或边界。
- `F1`：数据目录、磁盘/数据库投影、limits schema、proxy scope、shortcut catalog、版本与诊断回执均与运行中 App/sidecar 事实对账。
- `B2`：机器级表单、长限额表、网络配置与快捷键目录均保持可读，没有把系统设置压成空白或溢出布局。
- `C4`：重启提示、更新失败、factory reset 危险区、diagnostics `Copied` 回执均使用准确可行动的人话。
