# EDGE-174 · MCP 进度关联 · real App L3

## 判定

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-181342`
- 判定等级：L3（顺滑）
- 法条：`B2`（零跳变律）
- 结论：`pass`

## 测量方法

本证据复用同一正式 session 的原始 `screen.mov`，不把 L2 的路由正确性重复计为
L3。原始录像由 `ffprobe` 验证为 `3104x1844`、`60fps`、`85.225000s`。

- 将进度反馈区间裁成 10fps 样本，动作锚点为样本索引 `20`；`measure latency`
  在正文 ROI `0,120,2400,1380` 找到首个可见变化为索引 `24`，即约 `400ms`，
  `changedFrac=0.02105`，变化框为 `(716,140)-(2400,1500)`。这是从录屏采样得到的
  约值，不冒充 60fps 级别的输入事件精度。
- 将完成后的稳定尾段 `t=50..75s` 以 2fps 取 50 帧，在同一正文 ROI、阈值
  `0.0005` 下运行 `measure diff`；没有报告任何帧间变化。顶部标题区被排除，避免
  将与正文无关的标题微动画误判为既有内容跳变。
- 关键帧复读确认：`t≈42s` 的调用中状态、`t≈44.5s` 的 alpha 进度行和
  `t≈50s` 的双结果态之间，composer、transcript 与 Activity rail 没有被进度更新
  推动、覆盖或重排；进度文案没有裁切或重叠。

## 五通道交叉核对

- **Frame**：同一 `screen.mov` 可读，60fps 原始录像及上述局部测量均来自该 session。
- **Backend**：manifest 记录 listener PID=`31663`；`backend.log` 有内容但无应用级
  WARN、ERROR、panic 或 FATAL。
- **SSE**：独立 `ssetap` 记录 messages/entities/notifications 三流；本回合的
  alpha、beta progress 均在其各自调用的生命周期内，持续序号单调。
- **Frontend console**：录制的 frontend log 无 Flutter、Dart、RenderFlex、overflow、
  unhandled、assertion 或应用错误；仅保留已知 macOS IMK 宿主诊断。
- **LLM wire**：同一 manifest 下 managed challenge、install、models 与 chat 请求均
  返回 HTTP `200`。

## 边界

本格证明真实 App 在该 MCP progress 场景中有及时的可见反馈，且稳定尾段没有检测到
非用户触发的既有内容位移。MCP 投递在本 session 中实际观察为串行，因此不证明并行
吞吐；也不证明长时 progress 的美学质量或陌生用户 discoverability。L4、L5 继续开放。
