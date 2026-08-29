# EDGE-316 · 账本与统计警报复核

- 新增裁决：`EDGE-316 行内代码 CJK 断盒` Level 2 `pass`，法典引用 `F1`，真实五通道证据见 `EDGE-316-inline-code-cjk-real-app-20260828.md`。
- `discovery-collapse` 因最近 50 个裁决 fail 占比为 0% 打开；不降低阈值，不把连续绿灯解释为产品无缺陷。
- 写账前重新运行 `anchors.py check`：10/10 通过，anchor set hash 未变。
- 本轮有真实 App 关键帧、录屏、精确 AX 文本、backend、SSE、frontend console、LLM wire 和收台记录；没有用静态测试替代视觉实机证据。
- 结论：按既有规则 ack；保持原阈值、算法、法典与 sequence gate，继续下一 atomic cell。
