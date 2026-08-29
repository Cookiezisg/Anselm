# EDGE-322 · 应内缩放到顶：账本与警报独立复审

- subject: `EDGE-322 / 应内缩放到顶 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-322-in-app-zoom-cap-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-022508`
- law: `B2`

## 复审结论

复核了 163.741667 秒真实 App 录屏、设置内容 ROI、四张稳定帧和五通道 journal。`1.1×` 与恢复 `1.0×` 的整界面变化均绑定用户点击；越界 `1.25×` 没有改变当前状态，稳定段没有持续位移、溢出或白带。

`judge.py` 的 `L3 pass (B2)` 使用了 CODEX 中存在的法条、真实非空证据和同 session 五通道记录；anchors 为 `10/10`。本复审不修改 B2 阈值、法典、锚点或 gate。若串行写账触发 pass-burst 或 discovery-collapse，按原阈值和本记录 ack，不把统计警报误当作产品缺陷。
