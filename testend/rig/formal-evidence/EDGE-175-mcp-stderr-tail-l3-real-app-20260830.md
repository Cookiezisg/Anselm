# EDGE-175 · MCP 失败附 stderr 尾 · real App L3

## 判定

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-182257`
- 判定等级：L3（顺滑）
- 法条：`B2`（零跳变律）
- 结论：`pass`

## 测量与视觉复核

本格只判断失败路径的反馈是否稳定、是否让既有内容发生非用户触发的位移，不把 L2
的错误事实和 stderr 持久化重复计为顺滑。

- 原始 `screen.mov` 经 `ffprobe` 验证为 `3104x1844`、`60fps`、`99.998333s`。
- 从 `t=36s` 开始以 `10fps` 抽样，正文 ROI=`0,120,2400,1380`，从录屏动作锚点到
  首个可见状态变化约 `100ms`，`changedFrac=0.00086`；失败工具卡和 Activity 反馈
  没有静默等待。
- 将最终收尾后真正稳定的 `t=66..75s` 以 `2fps` 取样，同一正文 ROI 运行
  `measure diff`，没有任何帧间变化。`t=55..62s` 另有一次标题/内容收尾变化，已从
  稳定窗口排除，不能被误算成稳定态，也没有被隐藏。
- 复读关键帧确认：失败工具卡、EOF 文案、assistant 解释和 Activity rail 在状态收口
  后保持原位；Composer、历史消息和右侧活动岛没有被错误结果推动、覆盖或重排。

## 五通道交叉核对

- **Frame**：同一 session 的 `screen.mov` 可读，原始 60fps 录像与上述抽样均来自该
  session；失败卡片和 Activity 行无明显裁切或重叠。
- **Backend**：manifest 归属的 listener PID=`32738`；backend journal 捕获失败路径，
  无 panic、FATAL 或未解释的应用级错误。
- **SSE**：独立 `ssetap` 记录同一工具调用的 messages `tool_result close(status=error)`
  与 entities run error 终态，durable seq 单调。
- **Frontend console**：无 Flutter、Dart、RenderFlex、overflow、Unhandled、assertion
  或应用错误；仅有已知 macOS IMK 宿主诊断。
- **LLM wire**：同一 manifest 下 managed challenge、install、models 和三次 streamed
  chat completion 均为 HTTP `200`。

## 边界

本格证明失败反馈在真实 App 中及时出现，且最终稳定态没有检测到既有内容的非用户触发
位移。它不证明完整 stderr 尾在聊天卡片内联展示，也不证明该详情路径的视觉 craft 或
陌生用户 discoverability；L4、L5 继续开放。
