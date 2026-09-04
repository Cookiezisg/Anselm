# EDGE-168 每租户模板 URL · 真实 App 前置阻塞（Notification Center）

- 日期：2026-09-02
- session：`/private/tmp/anselm-rig-formal-20260902-36/sessions/20260902-204509`
- 结果：**阻塞，不是验收裁决；没有调用 `judge.py`，没有改变 COVERAGE**

## 现场

全新台架由 conductor 启动并归属 backend、`ssetap`、`llmtap`、真实 macOS Anselm App 和窗口录屏，
`RIG_SEED=0` 保留 onboarding。Anselm 已正常显示 `Create a workspace`，但尚未进入 marketplace、
尚未填写租户 URL、尚未触发 `Connect & authorize`。

## 阻塞原因

`rig-check.sh` 在 channel 1 拒绝 session：macOS `Notification Center` 窗口（PID `15305`，layer `21`，
bounds=`(0,0,1440,900)`）覆盖整个 Anselm 录制区域。Computer Use 读取的 Anselm 窗口画面本身干净，
但该系统层窗口无法作为可操作 App 获取 AX 树；向 Anselm 发送 `Escape` 以及尝试菜单栏入口均未
改变窗口登记。按台架规则，不能把不可确认的系统遮挡忽略，也不能修改 `rig-check` 绕过它。

channel 2/3/4/5 的归属、健康和 recorder lifecycle 均通过。随后 `rig-down.sh` 正常收台，录屏封口
为 `144.151667s`，所有 owned processes 已停止，完整日志保留在 session 目录。

## 后续

收起 Notification Center 后，从新 session 重跑 EDGE-168。该记录不构成 L2-L5 的 `na` 或 `fail`，
不改变顺序门或五级标准，不得用 API-only 或 focused 证据越过真实 App 授权流程。
