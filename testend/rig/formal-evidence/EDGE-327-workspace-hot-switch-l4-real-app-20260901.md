# EDGE-327 workspace 热切换三拍：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260901-12/sessions/20260901-231217`
- recording: `screen.mov`, `248.018333s`, 60fps；窗口录制区域 `1440x812`
- source workspace: `演示工作台`，打开已有对话 `演示对话`
- target workspace: `EDGE327 UI Target`，由 App 的 `New workspace` 流程创建
- law: `C2`（语义间距层）
- verdict: `pass` for L4；L5 仍按顺序门处理

## Product path

1. 在真实 App 中进入 Chat，打开 source workspace 的既有对话深链；正文、对话列表和 workspace 菜单均稳定可见。
2. 打开 workspace 菜单，确认 source、另一个 API 创建的 workspace 和 target 均有清晰的列表层级，当前项有明确选中态。
3. 点击 `EDGE327 UI Target`。切换是用户主动触发；旧深链先离开，随后目标 workspace 名称生效，最后落到目标 workspace 的空 Chat landing。
4. 目标 landing 稳定观察约 `6s`，没有旧正文、旧对话、旧右侧活动岛或旧 workspace 标题残留。

## Visual craft review

- 三拍的最终布局保持同一产品几何：左侧导航、workspace 标识、空态标题和 composer 的相对关系一致；目标空态没有出现临时占位、白屏或错位。
- 菜单态的 workspace 名称、当前勾选和列表间距可读；切换后菜单收起，目标空态的标题与 composer 之间保持稳定语义间距，没有因旧深链卸载而挤压或突然拉开。
- 对 `screen.mov` 从 `202s` 开始抽取的 `479` 个 60fps 帧运行：
  `go run ./cmd/measure diff -dir evidence/edge327-l4-frames60 -roi 0,0,1440,800 -threshold 0.001`
  仅记录用户点击菜单/切换窗口附近的变化（最大 `changedFrac=0.03201`）；动作完成后的稳定窗口没有超过阈值的变化。动作窗口内的变化属于用户请求本身，不是 B2 所禁止的非用户位移。
- 全录像 `blackdetect` 无黑段；录屏结束前目标 landing 保持稳定。未观察到二次布局构建、旧内容回流、右岛幽灵或视口抢夺。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 完成 source 深链、workspace 菜单、用户点击切换、目标空 Chat landing 和稳定等待；关键状态在同一封口录屏中连续出现。
- **backend**: `backend.log` 共 `793` 行；source/target workspace、conversation 和 activation 读取均正常；无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: `sse.jsonl` 共 `69` 帧，覆盖 `entities`、`messages`、`notifications` 三条流；`messages` durable seq 为 `1..8`，单调无重复，三条流均成功连接。
- **frontend console**: `frontend.log` 共 `3` 行；仅有 Flutter VM service 和已知 macOS 宿主启动诊断，没有 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 错误。
- **LLM wire**: `llm.jsonl` 记录真实 managed gateway 的 challenge/install/models 和 source 对话 completion，HTTP 状态均为 `200`；workspace 切换本身不应产生 LLM 请求，未发现伪造或多余 completion。
- **durable truth**: source 对话内容只在 source workspace 可见；目标 workspace 初始为空。切换不新增消息、不复制 source 内容，和画面中的隔离结果一致。
- **rig lifecycle**: `rig-check.sh` 在操作前通过屏幕权限、D1、App/backend/ssetap/llmtap 归属及遮挡检查；`rig-down.sh` 正常封口并停止全部台架进程，session journals 和录屏保留。

## Verdict

`L4 pass (C2)`。workspace 切换后的空态、导航和 composer 组成稳定、间距关系一致，达到视觉 craft bar；本格不重复宣称 L3 的动态稳定性，也不把 L5 的普通用户发现性提前结算。
