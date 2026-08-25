# SURF-105 · 账本与警报独立复审

## 复审范围

复审对象为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-083508` 的五通道封存包、`SURF-105-stage-control-investigation-20260825.md`、定向 Flutter 测试结果和当前 anchors。

## 复审结论

- `rig-check.sh` 在 App rebind 后通过：backend PID、SSE tap、LLM tap、App PID/window 和 recorder 均由 manifest 物理归属；`rig-down.sh` 后无残留。
- `gen_coverage.py --check`、anchors `10/10` 和 `alarms.py check` 前置状态均 clean；本格五级裁决只在证据文件和法条存在后写入。
- 真实录屏中同时出现一次人为残缺输入的澄清/validation 负路径和一次成功 control 创建；负路径未写实体，不能被误计为产品成功，也不能阻挡成功路径的 stage 判断。
- 写账若触发 `gap-too-fast` 或 `discovery-collapse`，只按同一封存 session、红负路径、绿终帧和五通道 journal 独立 ack；不改阈值、算法、法典、锚点或 gate。

因此允许将 `SURF-105` 的五个等级写入中央 ledger；后续仍受每 50 格统一门禁约束。
