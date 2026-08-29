# EDGE-324 · 窗角半径 swizzle 失效：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-231353`
- data: `/tmp/anselm-data-edge324-live-20260829-r2`
- workspace: `ws_3c9bce5ff5c3c373`
- law: `B2`
- verdict: `pass` for L3; L4/L5 `na`

## Product path

在真实 macOS App 中创建临时工作区，然后依次往返 Chat、Entities、Library 和 Settings，观察窗口外壳、圆角边缘和内容区是否在页面切换或等待期间发生非用户触发的位移、黑屏、白屏或重挂。Settings 页最后保持打开并静置 5 秒，确认降级后的窗口仍可继续使用。

本次 session 是正常产品构建，用于补齐真实 App 的动态稳定性层；私有 `NSThemeFrame` getter 改名/缺失的故障注入已经在 L2 证据中独立完成，见 `testend/rig/formal-evidence/EDGE-324-window-corner-swizzle-fallback-real-app-20260829.md`。本次不篡改正式源码，也不把正常构建冒充故障注入构建。

## Frame evidence

正式窗口绑定录像 `screen.mov` 为 `105.198333s / 3104x1846`，以 `1fps` 抽取到 `evidence/frames-1fps/`。代表稳定帧覆盖：

- `evidence/frames-1fps/f-001.png`: onboarding 空态，窗口外圆角和内容完整可见；
- `evidence/frames-1fps/f-060.png`: 工作区创建后的 Chat 空态，左岛、正文和 composer 均稳定；
- `evidence/frames-1fps/f-100.png`: Settings → Chat 稳定态，窗口边缘、设置导航和控件均完整。

Computer Use AX 逐页确认了 Entities、Library、Chat 和 Settings 的可见树；页面切换后的新树均有完整导航和内容，没有崩溃、黑屏、白屏、窗口消失或不可操作状态。5 秒静置复查保持同一 Settings 状态。

对 `screen.mov` 执行 `blackdetect=d=0.1:pix_th=0.10` 没有输出黑段。1fps 样本未发现用户动作之外的持续内容位移；不存在 B2 所定义的静止期既有内容跳变。圆角故障降级的“回到系统默认”由 L2 故障注入证据确认，L3 在真实正常 App 中确认该降级路径不会污染后续导航和稳定画面。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 启动、创建工作区并往返四个海洋；AX 与录屏均正常，105 个 1fps 样本已留存。
- **backend**: `backend.log` 为 `175` 行；无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: `sse.jsonl` 连接 notifications/entities/messages 三流并在收台时 EOF；本路径的 durable 状态与页面切换一致，没有异常缺口。
- **frontend console**: `frontend.log` 为 `5` 行；唯一 `IMKCFRunLoopWakeUpReliable` 是已分类的 macOS 宿主诊断，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 红线。
- **LLM wire**: `llm.jsonl` 仅记录 challenge/install/models 的台架生命周期；本格不触发聊天，不伪造 completion。
- **rig lifecycle**: startup gate、窗口录制归属、App/backend/ssetap/llmtap 归属和 `rig-down.sh` 均通过，收台无残留。

## Judgment boundary

L3 `pass (B2)` 只判断真实 App 的窗口降级路径经过多页导航后的动态稳定性和可继续操作性；L2 的 fault injection 结论继续保留。L4 不宣称当前圆角像素几何已完成，L5 不宣称用户能从零发现该平台降级路径，因此均为 `na`。
