# EDGE-245 discovery-collapse 告警复审

日期：2026-08-31

本次 L2 写账后，`alarms.py` 按既有 5% floor 打开 `discovery-collapse`。复审重新检查了最近窗口的裁决 journal、EDGE-244 保留的真实红证据与修复后证据，以及 EDGE-245 session `20260831-182639-edge245` 的 manifest、封口录屏、backend、三路 SSE、frontend、LLM tap、proxy 和 `rig-check` 结果。

结论：本窗口的低 fail-share 是真实复验后得到的统计信号，不是跳过负向证据，也没有把本次修复前的错误日志删除。EDGE-245 的新绿格有同一 sealed session 的五通道证据，且先因 session 归属不合规被 gate 拒绝，随后才按正式账本路径重试。锚点重新校验为 `10/10`。未修改告警阈值、曲线算法、CODEX、锚点、五级标准、顺序 gate 或任何产品 verdict；仅按既有协议关闭本次已复审的告警。

L3 写账后复审：重新核对 `measure latency`、10fps 抽帧与 `frame-0048 → frame-0049` 的语义切换，并确认骨架在等待期间持续提供反馈；没有把首个骨架 shimmer 误报成业务完成。`A4` 的 >1s 状态反馈要求得到满足，未修改时延门槛或判断标准。

L4 写账后复审：重新目视检查稳定尾帧与语义切换帧，核对侧栏局部替换的边界、圆角、间距和主内容区域未发生塌陷；`C4` 的现有几何标准继续适用。没有以“最终能用”替代视觉检查，也未修改视觉标准。

L5 写账后复审：重新读取 Computer Use 的最终可访问树与稳定尾帧；用户直接看到 `Chat`、`Recents`、`演示对话` 和 workspace 名称，无需知道 `UNAUTH_NO_WORKSPACE` 或任何内部恢复步骤。自动恢复不制造额外用户动作，且不影响入口可发现性。`G1` 继续适用，未修改发现性标准。
