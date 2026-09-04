# EDGE-168 每租户模板 URL · 前置阻塞复跑记录

- 日期：2026-09-02
- session：`/private/tmp/anselm-rig-formal-20260902-37/sessions/20260902-204925`
- 结果：**阻塞，不是验收裁决；没有调用 `judge.py`，没有改变 COVERAGE**

重启后的新 session 重新由 conductor 启动 backend、`ssetap`、`llmtap`、真实 macOS Anselm App 和
窗口录屏；App 停在干净的 `Create a workspace` onboarding，未进入 marketplace，未填写租户 URL，
未点击授权。

`rig-check.sh` 仍拒绝 channel 1：系统 `Notification Center`（PID `15305`，layer `21`，bounds=
`(0,0,1440,900)`）覆盖录制区域。Computer Use 能读取干净的 Anselm 窗口，但无法将该系统层窗口
作为可操作 App 获取 AX 树；`Escape`、菜单栏坐标和点击 Anselm 内容区都没有改变窗口登记。
其余通道归属/健康检查通过。随后 `rig-down.sh` 正常收台，录屏封口 `43.665000s`，owned processes
全部停止，日志保留在 session 目录。

本记录不构成 `na` 或 `fail`；必须在 Notification Center 消失后从新 session 重跑真实授权流程。
