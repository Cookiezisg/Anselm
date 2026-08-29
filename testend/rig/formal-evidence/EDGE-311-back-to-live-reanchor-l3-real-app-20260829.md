# EDGE-311 归队重钉贴底：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-091845`
- data: `/private/tmp/anselm-data-edge310-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_9b56dd0fba1a7efe`
- recording: `screen.mov`, `66.156667s`, 60fps
- stable frames: `evidence/EDGE-311-l3-return-stable.png`, `evidence/EDGE-311-l3-return-late.png`
- L2 foundation: `testend/rig/formal-evidence/EDGE-311-back-to-live-reanchor-real-app-20260828.md`

## Product path

1. 在真实 App 的长对话中从 Scenes 深跳到当前窗口之外的老消息。
2. 确认历史窗口显示目标消息和 `Jump to present`，然后由用户立即点击归队。
3. 归队后窗口恢复最新 head，`Jump to present` 消失，最新内容回到尾部，滚动视口贴近底部。

## Frame review and measurement

对同一份真实录屏在归队动作后抽取 1fps 样本，并使用
`(cd testend && go run ./cmd/measure diff ...)`，通道容差为 8、阈值为 `0.0005`：

- `000052→000053` 的 `changedFrac=0.06599`，bbox=`(1049,150)-(2652,1496)`；这是用户点击归队后历史窗口替换为现场窗口的预期大变化。
- `000053→000054` 的 `changedFrac=0.00131`，bbox=`(204,126)-(2652,1603)`；这是同一次归队重拉的收尾帧，不是静止期的自动跳变。
- 从 `000055` 到 `000065` 的连续稳定样本没有任何超过 `0.0005` 的变化输出；稳定期没有二次重建、视口回弹、旧窗口叠加或 `Jump to present` 反复出现。
- `EDGE-311-l3-return-stable.png` 与 `EDGE-311-l3-return-late.png` 均显示最新 head、入口消失和贴底视口；两张帧之间未观察到非用户位移。

## Five-channel cross-check

- **frames / Computer Use**: 原 session 的深跳帧和归队帧确认用户动作边界；新增稳定帧覆盖归队后约 `10s` 的静止期，且未见非用户变化。
- **backend**: session 的 backend journal 共 `129` 行；真实导航和消息读取完成，没有 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: ssetap 连接 `messages`、`entities`、`notifications` 三条流并正常 EOF 收台；本格只是历史窗口导航，没有伪造消息或业务事件。
- **frontend**: frontend journal 共 `4` 行，仅有 Dart VM 启动和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主提示；没有 Flutter、RenderFlex、Unhandled 或应用级异常。
- **LLM wire**: llmtap 已记录真实受管配置的生命周期；本格不触发 LLM completion，不把空 completion 冒充产品证据。
- **durable truth**: L2 证据中的真实 REST/SQLite 与 AX 状态确认归队前后没有新增或修改持久化消息，最新 head 和滚动状态由窗口重拉结果驱动。
- **rig lifecycle**: `rig-check`/`rig-down` 均通过；录屏可读，App、backend、ssetap、llmtap 收台后无残留进程。

## Judgment

- **L3 `pass (B2)`**: 用户主动归队造成的整窗替换被明确排除在零跳变判定之外；替换完成后连续稳定样本无超阈值变化，归队后的 head、入口和贴底视口保持稳定。
- 本证据只覆盖归队动作的稳定性，不把历史窗口视觉 craft、入口文案质量或盲走可发现性冒充 L4/L5。
