# EDGE-349 | 语音流中上游断线 | L4 真实 App 证据

## 判定

L4 通过，法典 `C4`：错误态的视觉层级、几何、反馈和过渡达到产品 craft bar。

## 视觉复核

同一正式 session=`/private/tmp/anselm-rig-formal-20260902-27/sessions/20260902-051714` 中，Computer Use 逐帧观察到：首次断线时顶部通知与 Composer 内重试卡同时出现，卡片标题、解释、两个动作和 Composer 输入区均完整；点击重试后 Composer 进入单一 `Finishing 00:00` 状态，随后稳定回到错误卡。顶部通知在其生命周期结束后消退，不遮挡卡片或输入区。

空转写分支的通知改为 `Voice input disconnected. No text was transcribed; your local recording is ready to retry.`，最终画面无省略号、截断、重叠、异常换行、按钮漂移、焦点跳变或残留录音态。卡片间距、按钮高度、边框和蓝色 Composer focus halo 在录音、收尾、错误三态之间保持稳定。

## 五通道与测量

- 录屏封口：`151.935000s / 3104x1848 / 60fps`，由 conductor-owned recorder 生成。
- llmtap：三次 `status=101`，三次 `speech_audio_forwarded size=3200`，三次断线注入。
- backend：三次 speech 请求正常收口；frontend 无应用级红线；SSE 三流 clean EOF。
- focused Flutter tests：Composer、speech provider、notice capsule 共 `59` 项通过，包含空文字文案分支与已有文字文案分支。

## 结论

错误反馈在信息量增加和恢复动作发生时没有造成 reflow、遮挡或不可用状态；修复前错误语义已作为独立红场保留。
