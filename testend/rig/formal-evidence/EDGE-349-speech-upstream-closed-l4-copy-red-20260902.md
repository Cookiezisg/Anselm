# EDGE-349 | 语音流中上游断线 | L4 文案红场

## 发现

正式台架 session=`/private/tmp/anselm-rig-formal-20260902-26/sessions/20260902-051220` 中，真实 App 在本地麦克风没有产生可转写文字时遭遇上游 WebSocket 断线。Composer 内的“语音输入中断”重试卡是完整的，但顶部通知仍显示“Voice input disconnected. I kept the text that was already transcribed.”。画面中没有任何已转写文字，这句话会让用户误以为草稿被保留，语义不诚实。

## Stop-and-fix

停止将该场景判绿。新增空文字分支 `voiceInputConnectionLostNoText`，明确告知没有转写文字且本地录音可以重试；已有转写文字的分支保持原文案。增加 Composer widget regression，分别锁定两种语义。修复后重新构建真实 App，并以新的正式 session 重跑，不覆盖本红证据。

## 证据

- 红场真实录屏：`/private/tmp/anselm-rig-formal-20260902-26/sessions/20260902-051220/screen.mov`。
- llmtap 记录首个音频帧后注入 `speech-upstream-closed`；红场不是本地 fixture 猜测。
- 红场未进入 `judge.py`，不计为通过。
