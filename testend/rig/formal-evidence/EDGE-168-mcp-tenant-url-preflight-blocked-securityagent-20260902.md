# EDGE-168 每租户模板 URL · 真实 App 前置阻塞

- 日期：2026-09-02
- session：`/private/tmp/anselm-rig-formal-20260902-35/sessions/20260902-065753`
- 结果：**阻塞，不是验收裁决；没有调用 `judge.py`，没有改变 COVERAGE**

## 现场

按正式顺序门启动了全新台架：后端、`ssetap`、`llmtap`、真实 macOS Anselm App 和窗口录屏均由同一
conductor 归属，`RIG_SEED=0` 保留真实 onboarding。App 已显示 `Create a workspace`，没有进入
marketplace，也没有输入租户 URL 或点击 `Connect & authorize`。

## 阻塞原因

`rig-check.sh` 在 channel 1 拒绝 session：一个在台架启动前已存在的 macOS `SecurityAgent` 进程
（PID `39701`，窗口 bounds=`(503,188,434,202)`，layer=`1000`）覆盖 Anselm 录制区域。该系统高层
窗口在等待约 3 分钟后仍存在，Computer Use 读取的 Anselm 窗口中不可见，向 Anselm 发送 `Escape`
也未消退。根据台架规则，系统遮挡未被解释或绕过前不得把录屏作为逐帧证据。

`rig-check` 其余通道均通过：backend D1、health、ssetap、llmtap、真实 App 归属及 recorder
lifecycle 均正常。随后执行 `rig-down.sh` 正常收台，录屏封口为 `120.931667s`，owned processes
全部停止，日志仍保存在 session 目录。

## 后续

先清除或由用户处理该遗留系统授权代理，再从全新 session 重跑 EDGE-168。此记录不构成 L2-L5 的
`na` 或 `fail`，也不改变顺序门；不得用 focused/API-only 证据越过真实授权动作。
