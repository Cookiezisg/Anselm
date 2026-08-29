# EDGE-316 · 行内代码 CJK 断盒真实 App L2

## 台架

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-231212`
- data: `/private/tmp/anselm-data-edge316-physical-20260828-r1`
- App/window: conductor-owned macOS App PID 8497, window 5691, recorded bounds `80,40,1280,792`
- recording: `98.760000s`, finalized by `rig-down.sh`
- fixture: `EDGE-316 inline code fixture`, containing `中文注释：计算总数并返回结果` inside an inline-code run, with ordinary Chinese text on both sides
- keyframes: session evidence `edge316-cjk-inline-code.jpeg` and `edge316-cjk-reopened.jpeg`

## 用户可见结果

1. 真实 App 打开文档后，行内代码显示为灰色圆角背景，CJK 文本的多个 script-run 之间没有白缝或断裂。
2. 灰色背景覆盖完整代码文字并保留左右内距；前后普通中文文字没有被背景遮挡或粘连。
3. 离开文档并重新打开后，AX 树仍返回完整行内代码文本，右侧仍为 `44 chars`、`130 B`，视觉结果保持一致。

## 五通道证据

- **Frame / Computer Use**: 每次打开/重开后重新读取 AX 树并保存关键帧；录屏覆盖真实 App 的代码背景和重开结果。
- **Backend**: fixture 创建成功，重开后文档内容与原始 Markdown 一致；无应用 WARN/ERROR/panic/fatal。
- **SSE**: 三路 workspace 流均连接；notifications durable seq `16` 记录 document.created，无 gap。
- **Frontend console**: 无 Flutter/Dart exception、RenderFlex/overflow、null-check 或未处理错误。
- **LLM wire**: challenge/install/models 全部 `200`；本格是本地编辑器视觉路径，不伪造模型请求。
- **Rig**: App 运行期间 `rig-check.sh` 五通道通过，`rig-down.sh` 停止所有归属进程并封口录屏。

## 判定

- CODEX: `F1`（五通道事实一致性）
- Level 1: 已有行内代码转换、NBSP padding 和 presenter differential 测试
- Level 2: 本证据支持真实 App 通过
- Level 3-5: 未测首反馈、像素 ROI 阈值和从零盲走，保持 `na`
