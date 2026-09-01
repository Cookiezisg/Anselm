# EDGE-174 · MCP 进度关联 · real App L4

## 判定

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-181342`
- 判定等级：L4（视觉 craft）
- 法条：`C4`（圆角五档尺度阶梯）
- 结论：`pass`

## 视觉复核

本格只审查进度呈现的视觉成品，不把 L2 的无串台或 L3 的稳定性重复计入。
复读同一正式 session 的关键帧：

- `edge174-frames/t44.5.png`：alpha progress live、beta 调用和 Activity 岛同时
  可见；进度内容落在白面 `AnWindow` 内，边框、圆角、内缩和等宽字族一致，三条
  progress 行的基线与行距稳定。
- `edge174-frames/t46.png`：alpha/beta 的调用态并列，状态点和工具目标的层级清楚；
  长工具名在活动岛的单行槽内按既有省略规则收束，未挤压状态或溢出容器，完整
  `edge174/progress_alpha` 与 `edge174/progress_beta` 仍在主 transcript 中可读。
- `edge174-frames/t48.png` 与 `t50.png`：settling 到完成态的过渡保留同一工具行、
  Activity 岛与主内容节奏；最终两个结果以相同的代码 inline 样式呈现，层级、圆角
  和留白没有突变。

## 五通道边界

该判断绑定 session 内同一 `screen.mov`、backend journal、三路 SSE、frontend log 和
managed LLM wire。各通道均已在 L2/L3 证据中核对，未发现应用级错误、布局溢出或
进度内容交叉污染。

本格证明该场景的 progress UI 达到当前仓内窗口与圆角 craft 规则；不证明陌生用户
是否能自行发现 MCP progress 归属入口，L5 继续开放。
