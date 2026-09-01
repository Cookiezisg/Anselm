# EDGE-349 | 语音流中上游断线 | L5 真实 App 证据

## 判定

L5 通过，法典 `G1`：普通用户不需要知道 WebSocket、上游网关或内部错误码，即可找到入口、理解失败并选择下一步。

## 可发现性复核

从真实 onboarding 创建 workspace 后，普通用户只看到 Composer 的 `Voice input` 入口。点击后无需阅读内部资料即可理解语音被中断；提示明确区分“没有转写文字”和“本地录音可重试”。重试卡直接提供 `Retry transcription` 与 `Delete voice draft`，第二次失败仍保持同一动作集合，没有把用户带到隐藏设置或技术日志。

正式 session=`/private/tmp/anselm-rig-formal-20260902-27/sessions/20260902-051714` 的 Computer Use AX 与录屏确认入口、错误说明、重试动作和可继续使用的 Composer 均可见；没有内部 ID、provider 名称或需要用户猜测的下一步。

## 互证与结论

录屏为 `151.935000s / 3104x1848 / 60fps`；backend 三次 speech 请求、三路 SSE、frontend console、LLM wire 均与真实断线路径一致，`rig-check` 和 `rig-down` 通过，owned processes 已收台。用户可以从自然入口完成“录音失败后的恢复”目标，故 L5 通过。
