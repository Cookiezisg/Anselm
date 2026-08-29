# EDGE-312 账本与警报复审

- target: `EDGE-312 / 版本组走 retryOf / L2`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-092651`
- primary evidence: `EDGE-312-retry-version-groups-real-app-20260828.md`

本格在真实 App 录屏收台、五通道 journal 齐全、`rig-check` 通过、关键帧和持久化版本链相互对齐后，才由 `judge.py` 写入 `L2 pass (F1)`。独立运行 `anchors.py check anchor-answers.json` 得到 `10/10`，覆盖生成器保持 `848/848/0`；没有修改法典、阈值、锚点或覆盖清册规则。

本次 `discovery-collapse` 仅表示尾部 50 条裁决的 fail 占比为 `0.0%`，并不否定本格证据。复审重新核对了三版 durable `retryOf` 链、App 中 `3/3 → 2/3 → 1/3 → 3/3` 的 AX 与关键帧、单行渲染、backend/SSE/frontend/LLM tap journal 和完整 lifecycle；L3-L5 仍诚实保持 `na`。本次独立复审后按既有机制销账，最终警报应为 clean。
