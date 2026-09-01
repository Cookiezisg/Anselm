# EDGE-350 L3 账本与警报独立复审

- 裁决：`EDGE-350|语音帧越界` L3=`pass`，法条 `A4`。
- 正式证据：`EDGE-350-speech-frame-invalid-l3-real-app-20260902.md`；修复前卡片文案红场独立保存。
- 复审确认真实上游 upgrade、音频帧、闭集错误、重试收尾和五通道日志均绑定同一 conductor session。
- 写账后的 `discovery-collapse` 按原阈值复核并 ack，未修改阈值、算法、锚点或五级标准。
