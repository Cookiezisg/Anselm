# EDGE-304 侧幕跟随三档：L3 真实帧顺滑证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-160712`
- data: `/private/tmp/anselm-data-edge304-l3-20260829-r1`
- screen: `screen.mov`, 2784x1808, 60fps, 321.863333s
- frame samples: `/private/tmp/edge304-first-hi-20260829`, `/private/tmp/edge304-every-hi-20260829`, 696x452, 60fps

## Product path

1. 在真实 App 的 Chat 设置中选择 `Never`，在新会话创建文档；活动完成后右侧不自动抢屏，只保留 `Toggle panel`。
2. 选择 `First per chat`，新建会话并用明确字段创建文档；首个活动完成后 Activity 侧幕自动打开，显示 `1 touched` 与刚创建的文档。
3. 选择 `Every time`，再次新建会话并创建另一篇文档；活动完成后侧幕同样打开，条目与文档名称一致。

## Frame measurement

- `First per chat` 的高帧采样从视频 `t=246s` 开始。右侧 ROI `x=500..696` 在侧幕揭示期间持续出现由右缘向左的窄条变化；主要揭示段为 `frame-0082→0087`（约 `100ms` 的采样窗口），没有收回再展开。
- `Every time` 的高帧采样从视频 `t=284s` 开始。右侧 ROI 的揭示由 `frame-0063` 开始，连续到 `frame-0076`，约 `233.3ms`，与 `AnMotion.mid=240ms` 对齐。
- 低阈值测量没有发现第二次结构性大变更：`First` 的后续变化是正文/侧幕内容进入后的局部变化；`Every` 的后续变化是侧幕从右缘连续揭示。两档都没有“打开→关闭→再次打开”或闪烁。
- `Never` 没有自动揭示，这是产品契约而非缺失动画；其屏幕保持空 Chat 布局，侧幕入口可用。

## Five-channel cross-check

- frames: 同一正式 session 的窗口专属录屏与 Computer Use 观察覆盖三档；`Never` 不抢屏，`First`/`Every` 的 Activity 内容分别匹配对应文档。
- backend: `backend.log` 462 行；无应用级 `WARN`、`ERROR`、`panic`、`FATAL`。
- SSE: `sse.jsonl` 620 行；`messages` durable seq=`1..54`、`notifications` durable seq=`1..10` 单调且无 gap；收台 disconnect 为台架正常收尾。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled 红线，唯一 error 文本为已分类 macOS IMK 宿主诊断。
- LLM wire: `llm.jsonl` 40 行；managed challenge/install/models 与 10 次 chat continuation 均为 HTTP `200`。

## Judgment

- L3 `pass (B2)`: 三档真实路径均有稳定的状态反馈；`Never` 的“不自动打开”是确定行为，`First`/`Every` 的自动揭示均为单次连续过渡，没有额外跳变、重复布局或闪烁。
- 本证据只判定跟随模式的真实行为与过渡稳定性，不把创建文档的语义正确性或 Activity 的视觉 craft 冒充为 L4/L5；本轮使用明确字段分隔的话术，排除了上一条自然语言字段歧义。
