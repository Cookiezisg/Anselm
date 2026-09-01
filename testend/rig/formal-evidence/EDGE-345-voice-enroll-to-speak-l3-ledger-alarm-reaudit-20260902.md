# EDGE-345 L3 账本与警报独立复审

- 本次只新增 `EDGE-345|音色登记→指名说话全链` 的 L3=`A4`，正式证据为
  `testend/rig/formal-evidence/EDGE-345-voice-enroll-to-speak-l3-real-app-20260902.md`。
- 写账前用原有 `anchor-answers.json` 重新校准锚点，结果为 `10/10`；没有修改锚点集、CODEX、阈值、五级标准或顺序策略。
- 正式真实 App session 的录屏、backend、SSE、frontend console 和 LLM wire 均已封存并逐项复核；L3 的 `A4` 证据是登记期间持续出现的确认/执行/合成状态，而不是只凭最终成功文本。
- 新增裁决后 `alarms.py check` 按原始阈值打开 `discovery-collapse`：近 50 条裁决的 fail share 为 `4.0%`，低于 `5%`。该信号已被保留并复核，不能解释为“产品更干净”。本次有新鲜五通道证据、锚点校准和完整法条引用，确认不是证据缺失或橡皮章，按原脚本 ack；未调宽任何门禁。

