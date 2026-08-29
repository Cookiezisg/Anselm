# EDGE-324 · 窗角半径 swizzle 失效 · 真实 App L2

## 结论

`L2=pass`。通过一次临时故障注入构建，将 `NSThemeFrame` 的四个私有 getter 替换为不存在的 selector，真实 macOS App 仍启动、显示并可持续导航；`patch` 的 nil 守卫使平台私有 API 失效时回落系统窗口圆角，没有启动崩溃或不可见窗口。

本次只证明故障降级和产品可用性，不把当前窗口圆角的像素精度冒充 L4，也不把未做盲走实验冒充 L5；L3-L5 保持 `na`。

## Session

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-140606`
- data: `/private/tmp/anselm-data-edge324-fault-20260829-r1`
- workspace: `ws_1a9705b29c913e3b`
- App PID/window: `28082` / `6017`
- backend PID: `27542`; ssetap PID: `27593`; llmtap PID: `27519`
- recording: `screen.mov`, `30.895000s`; fixed frame: `evidence/EDGE-324-missing-selectors-visible.jpeg`

## 故障注入与产品路径

1. 仅为该临时 acceptance build 将 `_cornerRadius`、`_getCachedWindowCornerRadius`、`_topCornerSize`、`_bottomCornerSize` 改为不存在的 selector，模拟未来 macOS 改名；未改变最终源码，收台后已恢复并确认该文件无 diff。
2. 真实 App 成功启动并显示完整 Library 空选区草稿态，AX 树包含 Library、Documents、Skills 和正文引导。
3. 使用真实 Computer Use 从 Library 切换到 Chat，再切回 Library；两次页面均可见且无崩溃、黑屏、白屏或启动卡死。
4. `rig-check` 在 App 存活期间确认窗口归属和录制区域；固定帧保留降级构建仍可见的完整窗口内容。

## 五通道证据

- **Channel 1 · Computer Use/帧**：`@oai/sky` 读取启动、Chat、Library 三个状态；降级构建仍有完整 AX 树和窗口画面。
- **Channel 2 · backend journal**：健康检查为 `200`；无 `WARN`、`ERROR`、`panic`、`FATAL`。
- **Channel 3 · SSE witness**：ssetap 连接 `notifications`、`messages`、`entities` 三流；当前确定性平台路径无业务 durable 帧，不虚构产品事件。
- **Channel 4 · frontend console**：真实 App/window 归属通过；无 Flutter、Dart、RenderFlex、Unhandled 或应用异常。仅有已知 macOS IMK 宿主诊断 `IMKCFRunLoopWakeUpReliable`。
- **Channel 5 · managed LLM wire**：llmtap 归属通过；`/v1/proof/challenge`、`/v1/install`、`/v1/models` 均为 `200`，没有绕过 recording tap。

## 收台与回归

- `rig-check.sh`：五通道全部通过，录制区域无外部遮挡。
- `rig-down.sh`：录屏正常结束，App/backend/ssetap/llmtap 均停止，无残留。
- `mise exec -- flutter test test/core/design/window_corner_guard_test.dart test/core/ui/an_shell_test.dart`：通过。
- 临时故障注入已恢复；`git diff -- frontend/macos/Runner/MainFlutterWindow.swift` 为空。

## 判定映射

- L1: `C4`，既有静态守卫和 token 对齐证据保留。
- L2: `F1`，本文件及同 session 五通道证据。
- L3-L5: `na`，没有独立动作到首反馈测量、ROI craft 测量或从零盲走实验。
