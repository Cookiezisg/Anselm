# EDGE-323 账本与警报独立复审

- 复审对象：`testend/rig/formal-evidence/EDGE-323-fullscreen-white-band-l4-real-app-20260901.md` 与 `...-l5-real-app-20260901.md`。
- 触发：L4/L5 连续写账后，近尾 50 条裁决的 fail share 为 `0.0%`，按原阈值打开 `discovery-collapse`。
- 复审证据：`anchors.py check`=`10/10`；`gen_coverage.py --check`=`848 rows, 848 carried judgments, 0 tombstones`；真实 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-215951` 的五通道 journal、D1 归属、`rig-down` 和 owned process 收台均已核对。
- 产品结论：WindowServer 整屏帧与绑定窗口 `screen.mov` 均无白带；Computer Use 原生全屏截图的彩色噪带只在采集适配层出现，已原样保留并与产品帧分流，不删除异常、不修改阈值、不降低法典或五级标准。
- 处置：按本复审记录串行 ack `discovery-collapse`；最终 `alarms.py check`=`clean (348 live judgments; 4240 baseline judgments excluded from drift curves)`。
