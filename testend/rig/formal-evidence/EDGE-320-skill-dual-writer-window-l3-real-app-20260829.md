# EDGE-320 · skill 双写者竞态：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-134830`
- data: `/private/tmp/anselm-data-edge320-physical-20260829-r3`
- workspace: `ws_6f16fe1504cd83a4`
- recording: `screen.mov`, `94.406667s`, `2784x1808`, `60fps`
- L2 foundation: `testend/rig/formal-evidence/EDGE-320-skill-dual-writer-window-real-app-20260829.md`
- stable frames: `EDGE-320-l3-before-writes-stable.png`, `EDGE-320-l3-after-writes-stable.png`, `EDGE-320-l3-reopened-stable.png`, `EDGE-320-l3-final-stable.png`

## Product path

在真实 Library App 中打开 `edge320-race` skill。中心 body 编辑器写入 `BODYCLEAN`，右侧 Properties 的 Arguments 写入 `cleanarg`，让两个独立的 600ms 防抖写入者在同一轮内先后落盘；等待收敛，离开到 `commit-helper`，再返回 `edge320-race`，观察正文、属性面板和焦点状态。

## Frame review and measurement

对 `screen.mov` 抽取全程 `1fps`，用 `threshold=0.0005` 对 body+Properties ROI `760,250,1850,950` 复核。代表性变化为：

- `000037→000038=0.00632`、`000038→000039=0.02604` 是进入 skill 和双写操作中的真实局部 UI 变化；
- `000056→000057=0.00140`、`000057→000058=0.00533` 对应正文和参数写入的收敛，不是后台二次覆盖；
- `000076→000077=0.02017`、`000081→000082=0.02010` 是离开/返回 skill 的用户导航窗口；
- `000082` 与最终 `000094` 稳定帧均同时显示正文 `BODYCLEAN` 和参数 `cleanarg`。返回后没有旧正文、参数 chip 消失、空白恢复、焦点丢失或页面重挂。

变化均落在打开、输入、写入收敛或用户导航窗口；这些窗口之外没有持续的晚到重绘。L2 已用 REST body/frontmatter 证明持久化真相，本格 L3 只判断双写 UI 的动态收敛和返回后的视觉连续性，不把已知 600ms read-modify-write 竞态窗口偷换成严格事务合并。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 录屏覆盖 skill 打开、中心正文写入、右侧参数写入、离开和返回；四张稳定帧已封存。
- **backend**: journal `199` 行；两次完整 skill PUT 为 HTTP `200`，无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: messages/entities/notifications 三流均连接；notifications durable `seq=16..18` 单调，对应 skill.created 与两次 skill.updated；收台为 conductor 主动关闭后的 EOF。
- **frontend console**: `5` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception 应用级红线；仅有已分类 macOS IMK/Caps Lock 宿主诊断。
- **LLM wire**: llmtap proof challenge/install/models 全部 HTTP `200`；本格是 skill 编辑路径，不伪造 completion 调用。
- **rig lifecycle**: startup gate、`rig-check` 和 `rig-down.sh` 收台通过，App、backend、ssetap、llmtap、录屏归属一致，无残留。

## Judgment boundary

- **L3 `pass (B2)`**：双写防抖后的 body/Arguments UI 能稳定收敛，离开/返回不发生旧快照覆盖、局部消失或页面重挂。
- L4/L5：`na`。本证据不宣称双写界面的视觉精修完成，也不宣称用户无需任何引导即可理解两个写入入口。
