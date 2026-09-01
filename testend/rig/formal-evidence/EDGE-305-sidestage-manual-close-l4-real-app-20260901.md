# EDGE-305 侧幕尊重手动关：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-161202`
- data: `/private/tmp/anselm-data-edge305-l4-real-20260901`
- workspace: `ws_f6c1b6f80f1f60d1`
- app/window: `27730/13163`
- backend/ssetap/llmtap: `27265/27314/27230`
- screen: `screen.mov`, 1440x810 window capture, 60fps, 117.396667s
- final frame: `evidence/EDGE-305-manual-close-final.png`

## Product path

1. 在真实 App 的 `First per chat` 模式下，从干净 Chat 创建 `EDGE305 first activity`，首个 Activity 活动自动打开侧幕。
2. 点击真实 `Toggle panel` 手动关闭侧幕；关闭后入口保留，中心对话不发生横向跳变。
3. 在同一对话再次创建 `EDGE305 second activity`；第二个活动完成后侧幕保持关闭，不强行抢回视口，`Toggle panel` 仍可用。
4. 两次工具结果和正文都留在中心 transcript，LLM wire 保留 `first body` 与 `second body`，没有重复调用或补偿性 edit。

## Visual craft judgment

- 手动关闭后的收敛态保持稳定三栏结构：中心内容不重排、不留白带、不被侧幕再次挤压；第二轮新增消息自然落在原位置。
- `Toggle panel` 仍位于右上入口位置，图标与窗口边距、顶栏基线和主内容区的留白连续，没有因关闭状态变成不可发现或漂移控件。
- 两轮用户气泡、工具卡、助手结果和输入框的间距、对齐、对比度与圆角保持同一层级；第二轮长结果没有裁切、溢出或覆盖。
- 手动关闭不是把数据抹掉：Activity 内容仍由可见入口控制，Transcript 的两次结果和文档正文完整保留。

## Five-channel cross-check

- frames: Computer Use 观察首个活动打开、手动关闭、第二个活动完成后的稳定态；最终截图和窗口录屏归属于同一 session。
- backend: `backend.log` 460 行；未发现应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 199 行；三流 tap 记录两次 document activity 的 durable 事件，未出现第二次自动展开对应的错误状态。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled 红线，唯一 error 是已分类的 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断。
- LLM wire: `llm.jsonl` 25 行；managed challenge/install/models/chat 均成功，两个正文均原样进入请求。

## Judgment

- L4 `pass (C4)`: 用户手动关闭后的真实稳定态通过布局连续性、入口保留、间距层级、对齐、对比度、圆角和内容完整性检查；第二次活动没有强制重开造成视觉打扰。
- 本证据只判视觉 craft，不把已有 L3 行为或 L5 入口发现性重复计算为本格结论。
