# EDGE-320 · skill 双写者竞态：账本与警报独立复审

- subject: `EDGE-320 / skill 双写者竞态 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-320-skill-dual-writer-window-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-134830`
- law: `B2`

## 复审结论

复核了 94.406667 秒真实 App 录屏、body+Properties ROI 代表性变化、四张稳定帧和五通道 journal。正文与 Arguments 的变化均绑定到明确用户输入或导航；返回 skill 后 `BODYCLEAN` 与 `cleanarg` 同时存在，稳定态没有旧快照覆盖、页面重挂或晚到二次重绘。

`judge.py` 的 `L3 pass (B2)` 使用了 CODEX 中存在的法条、真实非空证据和同 session 五通道记录；anchors 为 `10/10`。本复审不修改 B2 阈值、法典、锚点或 gate。若串行写账触发 pass-burst 或 discovery-collapse，按原阈值和本记录 ack，不把统计警报误当作产品缺陷。
