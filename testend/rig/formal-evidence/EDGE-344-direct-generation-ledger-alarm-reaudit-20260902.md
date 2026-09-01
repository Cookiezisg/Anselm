# EDGE-344 账本/警报独立复审

- 本次新增三格为同一个真实 App session 的 L3=`A1`、L4=`C4`、L5=`G1`，证据文件为
  `EDGE-344-direct-generation-l3-l5-real-app-20260902.md`；不是只凭一张终帧写绿。
- session `/private/tmp/anselm-rig-formal-20260902-14/sessions/20260902-033025` 的五通道文件齐全，conductor-owned
  `screen.mov` 以 `SIGINT` 封口且 `ffprobe` 可读(`3104x1848 / 60fps / 147.316667s`)；`rig-check.sh` 在真实路径前后全绿；LLM body、SSE close、App 气泡和 backend 日志逐项交叉一致。
- anchors 在本次写账前重新校准为 `10/10`。`gen_coverage.py --check` 保持 `848 rows, 848 carried
  judgments, 0 tombstones`，没有改阈值、法典、锚点集或顺序门。
- 三格连续入账后 `alarms.py check` 按原阈值打开 `discovery-collapse`（近 50 条 fail 占比 `4.0%`）。
  该信号不是被忽略：复核了三格的真实证据、前置正反锚点与五通道完整性，确认不是证据缺失或橡皮章，
  按原脚本 `ack`，未调整阈值；后续新裁决仍会重新计算曲线。
