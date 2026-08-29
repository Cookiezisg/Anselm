# EDGE-319 · 大纲下标不变式：账本与警报独立复审

- subject: `EDGE-319 / 大纲下标不变式 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-319-outline-heading-invariant-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-002006`
- law: `B2`

## 复审结论

复核了 165.106667 秒真实 App 录屏、ROI 代表性变化、三张稳定帧和五通道 journal。文档打开与 Outline 点击产生的变化均绑定到明确用户动作；稳定态保持 8 项目录、h1-h6 顺序和后续 h3 位置，没有自发滚动或目录重建。

`judge.py` 的 `L3 pass (B2)` 使用了 CODEX 中存在的法条、真实非空证据和同 session 五通道记录；anchors 为 `10/10`。本复审不修改 B2 阈值、法典、锚点或 gate。若串行写账触发 pass-burst 或 discovery-collapse，按原阈值和本记录 ack，不把统计警报误当作产品缺陷。
