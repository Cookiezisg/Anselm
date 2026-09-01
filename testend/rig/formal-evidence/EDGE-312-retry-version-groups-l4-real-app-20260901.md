# EDGE-312 版本组走 retryOf：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-195310`
- data: `/private/tmp/anselm-data-edge312-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_edge312_retryof`
- recording: `screen.mov`, `89.363333s`, 60fps
- frame samples: `evidence/edge312-l4-png/f018.png` ... `f066.png`

## Product path

1. 真实 App 打开 `EDGE-312 retryOf 版本组`，默认显示当前回答 `3/3`，一个逻辑回合只有一个 assistant 容器。
2. 用户点击 `Previous version` 两次，依次查看 `2/3` 和 `1/3`；旧版内容可读，并显示线程后续基于第 3 版。
3. 用户点击 `Next version` 两次回到 `3/3`；当前内容恢复，关系说明消失，没有把三个答案渲染成三轮对话。

## Visual craft review

- 当前版、中间版、最旧版和恢复当前版均保持同一回合几何：正文、操作图标、pager 和版本计数在同一水平结构中，没有因文本长度变化导致抖动或重复容器。
- `1/3`、`2/3`、`3/3` 的位置和左右切换箭头稳定，旧版关系说明与 pager 保持可读间距；回到当前版后说明准确消失。
- 版本切换中的变化均与用户点击绑定。整窗 diff（通道容差 8、阈值 `0.0005`）记录 `f018→f019=0.02709`、`f019→f020=0.01599`，以及切换收尾 `f030→f031=0.00070`、`f055→f056=0.00103`、`f060→f061=0.00103`、`f065→f066=0.00070`；没有动作外的自动变化。
- `f066` 至录屏结束没有超过 `0.0005` 的变化输出；稳定态无自动回跳、二次构建、旧版残留、重复回合或视口重排。ROI `760,120,2200,1450` 的结论一致，微小变化仅落在 pager/版本关系反馈区域。

## Five-channel cross-check

- **frames / Computer Use**: AX 依次确认 `3/3`、`2/3`、`1/3`、`3/3`，且每个状态只有一个 assistant 回合；关键帧保存于同一录屏。
- **backend**: backend journal 共 331 行，无 WARN、ERROR、panic 或 fatal；版本浏览未写入新回合。
- **SSE**: ssetap 连接 `notifications`、`entities`、`messages` 三条流并全部以 EOF 正常断开。
- **frontend**: frontend journal 只有 Flutter 启动信息和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断；没有 Flutter、RenderFlex、RenderBox、Unhandled 或应用级异常。
- **LLM wire**: llmtap 已真实接管受管 key 生命周期；本格是 durable 历史版本浏览，不触发 completion，不虚构模型请求。
- **durable truth**: retryOf/superseded_by 版本链与既有 REST/SQLite 证据一致；导航只改变当前读取版本，不新增或修改持久化消息。
- **rig lifecycle**: `rig-check.sh` 在操作前全项通过；`rig-down.sh` 封口录屏并停止 App、backend、ssetap、llmtap，session journal 完整。

## Verdict

- **L4 `pass (C4)`**: 版本组在四种用户可见状态下保持单回合、稳定几何、清晰关系层级和可控切换反馈，达到视觉 craft bar。
- 本证据不替代 L5 可发现性判断；L5 仍按既有顺序门单独处理。
