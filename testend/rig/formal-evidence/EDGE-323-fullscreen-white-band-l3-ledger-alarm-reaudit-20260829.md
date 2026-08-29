# EDGE-323 · 账本与警报独立复审

- subject: `EDGE-323 / 进全屏白带 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-323-fullscreen-white-band-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-230609`
- law: `B2`

## 复审结论

本次使用用户已完成 Keychain 授权后的干净 session。`rig-check` 在动作前后均通过五通道物理观测门；启动门记录 screen recording permission、backend healthy、ssetap、App window 和 recorder 全部就绪，收台记录 App、backend、ssetap、llmtap 和录屏均正常停止。

独立整屏录像没有黑段；窗口绑定录像只在原生 window ID 过渡期间出现一个 `0.666667s` 黑段。两者的时间段和尺寸均保留在源证据中。这个差异归因于窗口级采集在原生全屏/Space 切换时暂时失去有效窗口内容，不归因于 Flutter 重绘；Computer Use AX 状态和整屏可见画面都没有对应产品黑屏或白带。该仪器限制不被静默抹除，后续若要求单一录像源覆盖原生 transition，应改进 recorder，但不阻断本格产品结论。

`judge.py` 应使用 CODEX 中存在的 `B2` 法条、上述非空证据和同一 session 的五通道记录写入 `EDGE-323 L3 pass`。本复审不修改 B2 阈值、法典、锚点或账本 gate；统计警报若因串行写账触发，必须按本记录逐条复核后 ack，不能通过调高阈值消除。
