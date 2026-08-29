# EDGE-317 L3 账本与警报独立复审

- subject: `EDGE-317 / 选区跨块缝隙 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-317-selection-block-gaps-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-235053`
- laws: `B2`, `C1`

## 复审结论

逐项复核了历史白缝红证据、修复后二进制的 60fps 录屏、1fps/ROI diff、`regions` 连通组件、两张稳定帧和五通道 journal。较大变化都落在打开、导航、重开或用户拖选窗口；重开后选区稳定帧的主色区域为单一跨块组件，未发现白缝或晚一帧重建。

`judge.py` 的 `L3 pass (B2)` 具备现存法条、真实 evidence 文件和同 session 的五通道证据；anchors 为 `10/10`。本复审不修改 B2/C1 阈值、法典、锚点或 gate；若串行写账触发统计警报，按本记录和原阈值 ack，不将“无 fail”解释成产品全面变干净。
