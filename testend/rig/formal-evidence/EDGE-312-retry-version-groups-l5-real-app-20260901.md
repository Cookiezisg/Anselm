# EDGE-312 版本组走 retryOf：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-200323`
- data: `/private/tmp/anselm-data-edge312-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_edge312_retryof`
- recording: `screen.mov`, `62.473333s`, 60fps
- frame samples: `/private/tmp/edge312-l5-frames-20260901.bWBsyV/f001.png` ... `f062.png`

## Blind product goal

本次不向用户解释 `retryOf`、`superseded_by`、版本组或内部数据结构。普通用户目标是：
“我刚刚重试了一个回答，想看看之前的回答并确认现在用的是哪一版。”

## Discoverability path

1. 用户从 Recents 打开已有对话，不需要打开设置、Scenes、开发者面板或输入内部 ID。
2. 助手回答下方直接出现版本计数 `3/3`，左右版本导航箭头与其他回答操作处在同一操作行；AX 同时暴露为 `Previous version` 与 `Next version`，不是无标签的不可访问图标。
3. 用户点击 Previous version 后看到 `2/3` 和上一版内容，再点一次看到 `1/3`；旧版本同时给出“后续基于第 3 版”的关系说明，用户能理解当前版本不是孤立复制品。
4. 用户点击 Next version 两次回到 `3/3`；当前回答恢复，关系说明消失，仍只有一个逻辑 assistant 回合。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App AX 依次确认 `3/3`、`2/3`、`1/3`、`2/3`、`3/3`；屏幕录制包含打开对话、两次向前、两次向后的完整路径。关键稳定帧为 `f022`，显示当前版 `3/3`、左右箭头和回答操作行。
- **backend**: backend journal 共 244 行；无 WARN、ERROR、panic 或 fatal。版本浏览没有创建新消息，也没有写入第二个 assistant 回合。
- **SSE**: ssetap 连接 `notifications`、`entities`、`messages` 三条流；session 共有 9 条 SSE journal 行，正常完成并封口。
- **frontend**: frontend journal 共 4 行；无 Flutter、RenderFlex、RenderBox、Unhandled 或应用级异常。
- **LLM wire**: llmtap 已真实接管受管 key 生命周期；历史版本浏览不需要新的模型请求，没有伪造 completion 证据。
- **durable truth**: retryOf/superseded_by 版本链与当前 durable 历史一致；导航只改变读取中的版本，不新增或修改持久化消息。
- **rig lifecycle**: `rig-check.sh` 操作前五通道全项通过；`rig-down.sh` 封口录屏并停止 App、backend、ssetap、llmtap，session journal 完整。

## Visual and timing guard

- 1fps PNG 共 62 帧；`measure diff` 在 `0.01` 阈值下仅报告动作窗口 `f021→f022=0.03515`，其余相邻帧没有显著变化。
- 动作结束后没有自动回跳、版本关系残留、重复回答容器或视口重排；稳定态持续到录屏结束。
- 本次没有发现需要停下来修复的产品问题。

## Verdict

- **L5 `pass (G1)`**：普通用户无需内部术语即可从对话中发现版本计数和前后导航，能查看旧回答、理解版本关系并回到当前版；五通道证据一致。
