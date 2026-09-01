# EDGE-346 | 音色库存 2 槽上限 | L4 真实 App 视觉证据

## 判定

L4 通过，法典 `C4`：圆角遵循尺度阶梯，胶囊使用 pill；同心嵌套保持内半径与内缩关系。

## 视觉复核

同一真实 App session `/private/tmp/anselm-rig-formal-20260902-18/sessions/20260902-041857/` 中逐帧复核了：

- Chat 的语音附件卡、用户消息、工具状态行和底部 Composer；三次登记之间没有输入区跳变或残留 live 行。
- 危险确认卡的红色边界、标题、参数、Allow/Deny 操作和失败后的工具卡；内容没有裁切、重叠或层级歧义。
- Models & keys 的 Free tier、Cloned voices 和 Model keys 卡片；两条音色行在相同基线，满库存提示与列表保持稳定间距。
- 删除确认层的同心内缩、输入框和按钮；删除一条后 `1 of 2 slots free`，删除第二条后空态和 `2 of 2 slots free` 均无空白残片。

## 五通道对证

- 录屏已封存为 `h264 / 3104x1848 / 60fps / 626.266667s`，窗口录制器正常结束。
- backend 无 panic/fatal；唯一 WARN 是预期库存拒绝。frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线。
- SSE durable messages `1..51`、notifications `1..2` 均唯一单调；LLM wire 仅有两次登记成功和两次删除成功。

本判定针对真实窗口的完整状态切换，不用单张截图或工具 wire 替代逐帧观察，也没有降低 `C4` 标准。
