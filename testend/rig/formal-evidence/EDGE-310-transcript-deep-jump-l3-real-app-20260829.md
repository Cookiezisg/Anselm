# EDGE-310 深跳 `?around=` 整窗替换：L3 真实录屏测量证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-062450`
- data: `/private/tmp/anselm-data-edge310-20260828-r1`
- recording: `screen.mov`, `80.973333s`, 60fps
- primary real-app evidence: `testend/rig/formal-evidence/EDGE-310-transcript-deep-jump-real-app-20260828.md`
- frame samples: `sessions/20260828-062450/evidence/EDGE-310-l3-deep-stable.png`, `EDGE-310-l3-present-stable.png`

## Product path

1. 真实 App 打开包含 64 条消息的长对话，通过场次条选择一条不在当前窗口的老消息。
2. App 通过真实 `?around=` 请求整窗替换 transcript；目标消息只出现一次并处于目标锚位，画面提供 `Jump to present` 入口。
3. 用户点击 `Jump to present` 后回到最新窗口；历史窗口和现场窗口各自保持稳定，不因后台时钟或无关重建再次移动。

## Frame review and measurement

对同一真实录屏抽取 1fps 样本，并用 `testend/cmd/measure diff` 审查相邻帧：

- 深跳动作前后的整窗变化是用户触发的预期整窗替换；落定后的 `t≈39..60s` 连续 `22` 个样本，在 `threshold=0.0005` 下无变化输出。
- 回到现场动作前后的整窗变化同样是用户触发的预期替换；落定后的 `t≈65..79s` 连续 `15` 个样本，在 `threshold=0.0005` 下无变化输出。
- 用户动作期间出现的较大变化不被伪报成零像素：深跳阶段最高观测到 `changedFrac=0.14556`，回现场阶段最高 `0.06756`；这些变化与明确的历史窗口/现场窗口切换同时发生。
- 稳定帧中目标消息、`Jump to present` 状态、滚动位置和 composer 几何保持不变；没有自动二次跳转、旧窗口与新窗口叠加或回现场入口反复出现。

## Five-channel cross-check

- **frames**: 真实窗口专属录屏和既有 Computer Use 关键帧覆盖深跳、历史态、回现场及落定态；新增稳定帧已复制进 session evidence。
- **backend**: 同一 session 的 backend journal 记录真实 messages/anchors/touchpoints/workdir/todos 与场次导航请求；既有证据核对无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: 独立 witness 在同一 workspace 建立三路连接并正常收台；导航本身不产生虚假的 LLM 回合，未把无关 SSE 缺帧写成产品失败。
- **frontend**: frontend journal 只有 Dart VM 启动和已知 macOS IMK 宿主诊断，没有 Flutter、Dart、RenderFlex、Unhandled 或应用级错误。
- **LLM wire**: llmtap 生命周期在同一 session 中成立；该格是历史窗口导航，不需要模型调用，因此没有虚构 completion 证据。
- **durable truth**: 既有正式证据确认真实 `?around=` 返回目标窗口、目标 id 恰出现一次、回现场状态由窗口真相驱动；L3 只在此基础上增加录屏稳定性测量。
- **rig lifecycle**: 原 session 的 `rig-check`/`rig-down`、录屏可读性、App/backend/ssetap/llmtap 归属和进程收台均通过。

## Judgment

- **L3 `pass (B2)`**: 深跳与回现场在用户明确动作后完成整窗切换，切换落定后连续采样稳定；没有非用户触发的二次移动、窗口叠加、自动回跳或视口抖动。
- 本证据明确把用户触发的整窗替换与非用户跳变分开，不把历史窗口的视觉 craft、目标入口的盲走可发现性或回现场文案质量冒充为 L4/L5。
