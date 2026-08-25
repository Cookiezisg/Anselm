# SURF-100 账本与警报复审

## 触发

SURF-100 的五级裁决写入后，`alarms.py check` 按原机制打开 `gap-too-fast` 与 `discovery-collapse`。前者来自五次账本写入连续执行形成的 0 秒间隔；后者来自本近窗没有失败裁决。两项都是控制信号，不是 SURF-100 产品证据的结论。

## 独立复核

- 五条裁决均为 `pass`，法条分别为 `E2`、`F2`、`B2`、`C4`、`G1`；`i18n/appName` 已在 COVERAGE 形成 `✓✓✓✓✓`。
- L2 使用同一正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-071353/evidence/SURF-100-i18n-app-name-five-channel.md`，不是仓库调查文档替代；session 的 screen/backend/frontend/SSE/LLM 五通道文件齐全，`rig-check` 与 `rig-down` 均通过。
- 真实 screen 关键帧与源码/locale focused test 相互印证；SSE 三流连接事实已记录，因路径没有业务实体而无 durable business frame，未被伪造为业务成功。
- anchor 校准仍有效：`anchor-check.json` 记录 10/10，SHA256=`e5f1899af88a71a5c16989e88a5bf188ad3e1c0379f901e525718d70366b6b08`，与 `testend/rig/anchors.json` 一致，且在四小时有效窗口内。
- `gen_coverage.py --check`、focused locale test 和 `git diff --check` 均需在本格收口时重新通过。
- 本次复审不修改警报阈值、统计算法、CODEX 法条、anchor 集或账本 gate。

## 处置

两个警报按本记录串行 ack。ack 只关闭已经核验的 alarm evidenceThrough，不把通过率或裁决间隔曲线改写为绿色；后续裁决仍继续经过同一三曲线机制。
