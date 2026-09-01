# EDGE-298 · 未读徽标绝不据帧 +1：真实 App L5

## 判定范围

本证据判定 CODEX `G1`：新用户不读文档，能否从默认 App 画面发现未读通知入口、理解提示并进入通知中心。它不把后端事件名称或内部 unread-count 当作用户入口。

## 从零路径

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051`，默认画面为真实 App 的
  Chat 空态；左岛底部同时可见设置齿轮和通知铃铛，铃铛右上角出现红色未读点。
- 用户无需知道 `memory.updated`、Emit/Broadcast、SSE 或 REST。红点是标准的“有未读内容”视觉提示，铃铛是
  通知入口；入口位于固定左岛底栏，不会随当前 Chat 内容消失。
- 进入后，通知托盘立即提供搜索框、Today 分组计数和可读的实体/动作行；唯一持久未读项可与已读历史行
  区分，点击该行会进入来源并同时清除已读状态。入口、提示含义和下一步均不依赖内部文档。
- 真实 App 的 Computer Use 现场与录屏验证了从默认 Chat 到通知中心的完整路径；稳定帧没有空入口、不可点击
  的红点、隐藏在设置里的通知列表或需要记忆内部名称的操作。

## 五通道交叉核对

- **Channel 1 / Computer Use + 录屏**：默认 Chat 画面可见铃铛和未读点，通知中心打开后显示 Today、搜索和
  通知行；入口位置稳定，用户路径没有额外引导步骤。
- **Channel 2 / backend journal**：通知 create/update/pin/mark-read 的真实持久状态与画面对应，无应用级
  WARN/ERROR/panic。
- **Channel 3 / SSE tap**：持久 Emit 才触发 inbox candidate，Broadcast 不增加 unread；因此用户看到的一个
  红点和一个未读事实与流的分流一致。
- **Channel 4 / frontend 错误面**：同场 frontend journal 与 `rig-check` 无 Flutter/Dart/RenderFlex/Unhandled
  红线，打开托盘后没有空白、失焦或错误态残留。
- **Channel 5 / LLM wire**：本场不调用 LLM；managed challenge/install/models 为 `200`，入口发现不依赖模型
  生成一段解释。

## 结论

从默认 Chat 画面，红点解释“有未读”、铃铛解释“去通知中心”，进入后 Today、搜索、实体/动作行继续解释下一步；
入口位置与 accessibility label 也由真实 App 的固定 footer 提供。因此 L5=`G1` 通过。
