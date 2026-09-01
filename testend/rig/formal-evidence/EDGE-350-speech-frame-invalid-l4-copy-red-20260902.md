# EDGE-350 | 语音帧越界 | L4 文案红场

## 发现

正式 session=`/private/tmp/anselm-rig-formal-20260902-28/sessions/20260902-052809` 中，真实 App 收到
受控上游 `SPEECH_AUDIO_FRAME_INVALID` 后，顶部通知已经准确说明没有转写文字，但 Composer 内重试卡仍显示
`I kept the draft and can replay the local recording once to transcribe it again.`。当前输入框为空，用户会把“draft”
误解为已有文字草稿，状态语义不一致。

## Stop-and-fix

停止将该场景判绿。新增 `voiceRetryBodyNoText`，空文字时改为明确说明本地录音仍可重试；已有转写文字的旧分支
保持不变。补充 Composer widget regression，并在新的真实 session 中复验通知、重试卡和重试收尾。

## 证据

- 红场录屏：`/private/tmp/anselm-rig-formal-20260902-28/sessions/20260902-052809/screen.mov`。
- llmtap 已完成真实上游 upgrade、转发真实音频帧并返回闭集错误；红场未进入 `judge.py`。
