# EDGE-223 · 账本与警报独立复审

- 本次新增裁决：`EDGE|视频轮询超时诚实话|L2|pass|F2`。
- 正式现场：`/private/tmp/anselm-rig-formal-20260905-edge236d/sessions/20260905-054731`；录屏、manifest、backend、frontend、SSE 与 LLM tap 均已封口并相互对应。
- `pass-burst` 是连续写入同一真实 session 后由既定速率曲线打开的机制警报；它不降低 F2，也不替代证据复核。
- 复审重新核对 session 身份、三路 SSE durable close、真实 gateway submit/poll 线缆、前端最终画面和收台无残留；没有重复执行或跨 session 拼证据。
- 仅按 `alarms.py ack` 销账，不修改阈值、算法、法典、锚点或产品裁决标准。
- 随后新增的 `L3 pass A4` 复核了同一录屏中的 2s、5s、10s、16s 状态提示和 25s 终态下一步，不把等待时长或模型线缆误当成反馈证据。
- 随后新增的 `L4 pass C4` 重新核对最终错误卡、工具卡、回合提示和 Composer 的几何、层级、留白与稳定帧；没有用警报清洁代替视觉观察。
- `L5 pass G1` 也绑定同一最终画面，确认失败状态、Retry 和下一步说明在用户不读协议时可找到；本级没有另造成功生成证据。
