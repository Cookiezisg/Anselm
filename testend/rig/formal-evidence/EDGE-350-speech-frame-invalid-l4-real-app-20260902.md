# EDGE-350 | 语音帧越界 | L4 真实 App 证据

## 判定

L4 通过，法典 `C4`：错误通知、重试卡和 Composer 在错误、恢复和重试状态间达到视觉 craft bar。

## 视觉复核

修复后 Computer Use 在真实窗口中观察到顶部错误通知与 Composer 卡片同时出现，文本完整、无省略号、无异常换行；
卡片标题、空文字说明、两个动作和 Composer 输入区对齐稳定。`Retry transcription` 后短暂状态正常消失，最终回到
普通空 Composer，未出现白屏、残留错误卡、按钮漂移、焦点跳变或重复布局。

修复前错误卡误称“保留草稿”的真实红场保留在独立文件中，没有被最终绿场覆盖。focused Flutter tests 共 `60` 项通过，
包含 connection/frame-invalid 的有文字与无文字分支，以及 retry body 的准确性。

## 五通道与台架

- 录屏=`/private/tmp/anselm-rig-formal-20260902-29/sessions/20260902-053042/screen.mov`，`68.185000s / 3104x1848 / 60fps`。
- llmtap 一次真实 `101`、首个音频帧 `3200` 字节、闭集错误 `52` 字节；重试请求未消费注入预算。
- backend、三路 SSE、frontend console 均无应用级红线；`rig-check`/`rig-down` 通过且 owned processes 已收台。

## 结论

最终视觉状态与真实数据状态一致，修复没有通过缩短文字或删除错误态来掩盖问题。
