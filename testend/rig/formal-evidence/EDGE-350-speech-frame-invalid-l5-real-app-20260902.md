# EDGE-350 | 语音帧越界 | L5 真实 App 证据

## 判定

L5 通过，法典 `G1`：普通用户可以从自然入口理解错误并找到恢复路径。

## 可发现性复核

用户只需点击 Composer 的 `Voice input`，无需知道语音帧、WebSocket 或内部错误码。错误提示用用户语言解释语音
无法理解且尚未产生文字；重试卡直接给出 `Retry transcription` 和 `Delete voice draft`。点击重试后页面恢复可用，
没有要求用户去设置页、重启 App 或阅读技术日志。

正式 session=`/private/tmp/anselm-rig-formal-20260902-29/sessions/20260902-053042` 的 Computer Use AX 和录屏均确认
入口、解释、动作和最终 Composer 可见；没有隐藏动作、内部 ID 或模糊的“稍后再试”。

## 结论

从普通用户目标“语音输入失败后继续工作”出发，入口、原因和下一步均可发现且可执行；五通道和收台证据完整。
